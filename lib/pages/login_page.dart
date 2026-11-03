import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import '../utils/api.dart';
import '../services/auth_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/surfaces.dart';
import '../features/faq/models/faq.dart';
import '../features/faq/faq_navigation.dart';
import '../core/destinations.dart';
import 'profile_setup_page.dart';
import '../design/motion.dart';
import '../ui/otp_code_field.dart';

// Форматирует ввод номера в +7 700 123 45 67
class PhoneTextInputFormatter extends TextInputFormatter {
  static String normalize(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.isNotEmpty && !digits.startsWith('7')) {
      digits = '7$digits';
    }
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    return digits;
  }

  static String formatDigits(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer('+7');
    final localDigits = digits.length > 1 ? digits.substring(1) : '';

    if (localDigits.isNotEmpty) {
      buffer.write(' ');
      buffer.write(localDigits.substring(0, localDigits.length.clamp(0, 3)));
    }
    if (localDigits.length > 3) {
      buffer.write(' ');
      buffer.write(localDigits.substring(3, localDigits.length.clamp(3, 6)));
    }
    if (localDigits.length > 6) {
      buffer.write(' ');
      buffer.write(localDigits.substring(6, localDigits.length.clamp(6, 8)));
    }
    if (localDigits.length > 8) {
      buffer.write(' ');
      buffer.write(localDigits.substring(8, localDigits.length.clamp(8, 10)));
    }

    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalize(newValue.text);
    final formatted = formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

enum LoginCompletionMode { replaceRoot, returnAuthenticated }

class LoginPage extends StatefulWidget {
  final AppDestination? destinationAfterSignIn;

  /// Entry from an explicit "Войти" action, bypassing introductory slides.
  final bool startWithPhoneForm;

  final LoginCompletionMode completionMode;

  const LoginPage({
    super.key,
    this.destinationAfterSignIn,
    this.startWithPhoneForm = false,
    this.completionMode = LoginCompletionMode.replaceRoot,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _pageController = PageController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _showAuthForm = false;
  int _currentPage = 0;
  Map<String, dynamic>? _profileSetupUser;
  AuthSession? _profileSetupSession;

  Timer? _autoSlideTimer;
  Timer? _resumeTimer;
  Timer? _sendCodeCooldownTimer;
  bool _userInteracting = false;
  int _sendCodeCooldownSeconds = 0;
  String? _sendCodeCooldownPhone;

  /// Length of the SMS code the server sends and `verify-code` accepts.
  static const _otpLength = 6;
  final _otpBlockKey = GlobalKey();
  String _lastCodeText = '';
  String? _codeError;
  int _codeErrorShake = 0;

  static const _slides = [
    _SlideData(
      icon: AppIcons.discountShape,
      title: 'Персональные акции',
      subtitle: 'Уникальные скидки только для вас',
    ),
    _SlideData(
      icon: AppIcons.bagHappy,
      title: 'Быстрый заказ',
      subtitle: 'Оформление в пару нажатий',
    ),
    _SlideData(
      icon: AppIcons.bagTimer,
      title: 'История покупок',
      subtitle: 'Повторите любой прошлый заказ',
    ),
    _SlideData(
      icon: AppIcons.bonusStar,
      title: 'Бонусы',
      subtitle: 'Копите с каждой покупки',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codeController.addListener(_onCodeChanged);
    _showAuthForm = widget.startWithPhoneForm;
    if (_showAuthForm) _ensurePhonePrefix();
    _startAutoSlide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSlideTimer?.cancel();
    _resumeTimer?.cancel();
    _sendCodeCooldownTimer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Auto-slide carousel ───────────────────────────────────

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_showAuthForm && _pageController.hasClients) {
        final next = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });
  }

  void _onCarouselInteractionStart() {
    _userInteracting = true;
    _autoSlideTimer?.cancel();
    _resumeTimer?.cancel();
  }

  void _onCarouselInteractionEnd() {
    _userInteracting = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_userInteracting) _startAutoSlide();
    });
  }

  // ── Phone helpers ─────────────────────────────────────────

  void _ensurePhonePrefix() {
    if (_phoneController.text.trim().isNotEmpty) return;
    final value = PhoneTextInputFormatter.formatDigits('7');
    _phoneController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _normalizedPhone() {
    final digits =
        PhoneTextInputFormatter.normalize(_phoneController.text.trim());
    if (digits.isEmpty) return '';
    return '+$digits';
  }

  // ── API calls ─────────────────────────────────────────────

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _normalizedPhone();
    if (_isCooldownActiveForPhone(phone)) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.sendAuthCode(phone);
      if (!mounted) return;

      if (result.success) {
        setState(() => _codeSent = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _codeFocusNode.requestFocus();
        });
        _revealOtp();
      } else {
        if (result.cooldownSeconds != null && result.cooldownSeconds! > 0) {
          _startSendCodeCooldown(
              phone: phone, seconds: result.cooldownSeconds!);
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Не удалось отправить код. Проверьте соединение и попробуйте ещё раз.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCooldownActiveForPhone(String phone) {
    return phone.isNotEmpty &&
        _sendCodeCooldownSeconds > 0 &&
        _sendCodeCooldownPhone == phone;
  }

  void _startSendCodeCooldown({required String phone, required int seconds}) {
    final normalizedSeconds = seconds <= 0 ? 60 : seconds;
    _sendCodeCooldownTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _sendCodeCooldownPhone = phone;
      _sendCodeCooldownSeconds = normalizedSeconds;
    });

    _sendCodeCooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_sendCodeCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _sendCodeCooldownSeconds = 0;
          _sendCodeCooldownPhone = null;
        });
        return;
      }

      setState(() {
        _sendCodeCooldownSeconds -= 1;
      });
    });
  }

  String _sendCodeButtonLabel() {
    final phone = _normalizedPhone();
    if (_isCooldownActiveForPhone(phone)) {
      return 'Повторить через ${_formatCooldown(_sendCodeCooldownSeconds)}';
    }
    return 'Получить код';
  }

  String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  /// Verifies the code once: the guard covers auto-submit on the last digit,
  /// the keyboard's "done" action and the confirm button racing each other.
  Future<void> _verifyCode() async {
    if (_isLoading || _codeController.text.length != _otpLength) return;
    setState(() => _isLoading = true);
    final phone = _normalizedPhone();
    final code = _codeController.text;
    try {
      final data = await ApiService.verifyAuthCode(phone, code);
      if (data != null && mounted) {
        final session = await AuthService.captureSession();
        if (!mounted || session == null || !session.isCurrent) return;
        unawaited(NotificationService.instance.syncTokenWithServerIfNeeded());
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (widget.completionMode == LoginCompletionMode.returnAuthenticated) {
          await _continueReauthentication(session);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => AuthenticationWrapper(
                initialDestination: widget.destinationAfterSignIn,
              ),
            ),
            (route) => false,
          );
        }
      } else if (mounted) {
        // Wrong code (or a failed request): empty the boxes for a retry, shake
        // and keep the message next to them instead of in a snack bar.
        _codeController.clear();
        setState(() {
          _codeError = 'Неверный код или ошибка. Попробуйте ещё раз';
          _codeErrorShake++;
        });
        _codeFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Не удалось проверить код. Проверьте соединение и попробуйте ещё раз.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitCode() {
    if (_codeSent && _codeController.text.length == _otpLength) _verifyCode();
  }

  /// Reacts to every change of the code, whether typed, pasted, autofilled or
  /// inserted by "Вставить код": the old error goes away and a complete code is
  /// submitted once.
  void _onCodeChanged() {
    final code = _codeController.text;
    if (code == _lastCodeText) return;
    _lastCodeText = code;
    if (!mounted) return;
    setState(() => _codeError = null);
    _submitCode();
  }

  void _resetCodeEntry() {
    _codeController.clear();
    _codeError = null;
  }

  /// Scrolls the boxes and the confirm button above the keyboard.
  void _revealOtp() {
    if (!_codeSent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _otpBlockKey.currentContext;
      if (!mounted || context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void didChangeMetrics() => _revealOtp();

  Future<void> _continueReauthentication(AuthSession session) async {
    final userInfo =
        await ApiService.getFullInfo(credentialToken: session.token);
    if (!mounted ||
        !session.isCurrent ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final user = userInfo?['user'];
    if (user is! Map) {
      throw StateError('Не удалось подтвердить профиль. Повторите вход.');
    }
    await AuthService.refreshIdentity(verifiedInfo: userInfo);
    if (!mounted ||
        !session.isCurrent ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (ProfileSetupPage.isRequiredFor(userInfo)) {
      _profileSetupSession = session;
      setState(() => _profileSetupUser = Map<String, dynamic>.from(user));
    } else {
      Navigator.of(context).pop<bool>(true);
    }
  }

  Future<void> _completeProfileSetup(
      Map<String, dynamic>? refreshedUserInfo) async {
    final session = _profileSetupSession;
    if (!mounted ||
        session == null ||
        !session.isCurrent ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (refreshedUserInfo?['user'] is Map &&
        !ProfileSetupPage.isRequiredFor(refreshedUserInfo)) {
      await AuthService.refreshIdentity(verifiedInfo: refreshedUserInfo);
      if (!mounted ||
          !session.isCurrent ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      Navigator.of(context).pop<bool>(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Не удалось подтвердить заполненный профиль. Повторите сохранение.'),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final profileSetupUser = _profileSetupUser;
    if (profileSetupUser != null) {
      return ProfileSetupPage(
        initialUser: profileSetupUser,
        onCompleted: _completeProfileSetup,
      );
    }
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showAuthForm ? _authFormView() : _onboardingView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canClose = !_showAuthForm && Navigator.of(context).canPop();
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppIcon(
            key: const ValueKey('auth-wordmark'),
            dark ? AppIcons.wordmark : AppIcons.wordmarkLight,
            width: 164,
            height: 38,
          ),
          if (_showAuthForm)
            Positioned(
              left: 16,
              child: AppIconButton(
                asset: AppIcons.back,
                tooltip: 'Назад',
                onTap: () {
                  if (widget.startWithPhoneForm &&
                      Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    _resetCodeEntry();
                    setState(() {
                      _showAuthForm = false;
                      _codeSent = false;
                    });
                  }
                },
              ),
            )
          else if (canClose)
            Positioned(
              left: 16,
              child: AppIconButton(
                asset: AppIcons.back,
                tooltip: 'Назад',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _onboardingView() {
    final palette = context.palette;
    return Column(
      key: const ValueKey('onboarding'),
      children: [
        Expanded(
          child: Listener(
            onPointerDown: (_) => _onCarouselInteractionStart(),
            onPointerUp: (_) => _onCarouselInteractionEnd(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (_, index) => _slidePage(_slides[index]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? palette.accent
                      : palette.textSecondary.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        Text(
          'Войдите, чтобы не упустить выгоду',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _primaryButton(
                key: const ValueKey('open-auth-button'),
                label: 'Войти или зарегистрироваться',
                onPressed: () => setState(() {
                  _showAuthForm = true;
                  _ensurePhonePrefix();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _phoneFocusNode.requestFocus();
                  });
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _slidePage(_SlideData slide) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const AppIcon(AppIcons.cartFab, size: 100),
                      AppIcon(slide.icon, size: 54, color: palette.accent),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline.copyWith(
                    color: palette.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.body.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _authFormView() {
    final palette = context.palette;
    return LayoutBuilder(
      key: const ValueKey('auth'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedPadding(
                // The code step starts higher: the keyboard is already up, and
                // the boxes and the confirm button must stay above it.
                duration: AppMotion.of(context, AppMotion.slide),
                curve: AppMotion.out,
                padding: EdgeInsets.fromLTRB(16, _codeSent ? 24 : 112, 16, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _codeSent ? 400 : 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _codeSent ? 'Введите код' : 'Вход по номеру телефона',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _codeSent
                            ? 'СМС отправлено на ${_phoneController.text}'
                            : 'Отправим короткий код подтверждения',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => openFaqPage(
                            context,
                            initialSection: FaqSection.profile,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: Text(
                            _codeSent
                                ? 'Проблемы с кодом? Открыть FAQ'
                                : 'Не приходит SMS-код?',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.accent,
                            textStyle: AppTypography.body,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            minimumSize: const Size(44, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!_codeSent) ...[
                              _phoneInput(),
                              const SizedBox(height: 12),
                              _primaryButton(
                                key: const ValueKey('request-code-button'),
                                label: _sendCodeButtonLabel(),
                                onPressed: _isLoading ||
                                        _isCooldownActiveForPhone(
                                          _normalizedPhone(),
                                        )
                                    ? null
                                    : _sendCode,
                              ),
                            ] else ...[
                              AutofillGroup(
                                // A code is never a credential to save.
                                onDisposeAction: AutofillContextAction.cancel,
                                child: Column(
                                  key: _otpBlockKey,
                                  children: [
                                    _otpInput(),
                                    const SizedBox(height: AppSpacing.xxxl),
                                    _primaryButton(
                                      key:
                                          const ValueKey('confirm-code-button'),
                                      label: 'Подтвердить',
                                      onPressed: _isLoading ||
                                              _codeController.text.length !=
                                                  _otpLength
                                          ? null
                                          : _verifyCode,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 17),
                              TextButton(
                                onPressed: () {
                                  _resetCodeEntry();
                                  setState(() => _codeSent = false);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _phoneFocusNode.requestFocus();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.accent,
                                  textStyle: AppTypography.body,
                                  minimumSize: const Size(
                                    AppSpacing.touchTarget,
                                    AppSpacing.touchTarget,
                                  ),
                                ),
                                child: const Text('Изменить номер'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _phoneInput() {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? palette.surface : palette.background;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      borderSide:
          BorderSide(color: dark ? palette.divider : Colors.transparent),
    );
    return AppSurface(
      fill: fill,
      shadow: AppShadows.control(palette),
      child: TextFormField(
        key: const ValueKey('auth-phone-input'),
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [PhoneTextInputFormatter()],
        onTap: _ensurePhonePrefix,
        validator: (value) {
          final normalized = PhoneTextInputFormatter.normalize(value ?? '');
          if (normalized.isEmpty || normalized == '7') {
            return 'Введите номер телефона';
          }
          if (normalized.length != 11) return 'Неверный формат номера';
          return null;
        },
        style: AppTypography.titleRegular.copyWith(color: palette.textPrimary),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: '+7 700 123 45 67',
          hintStyle: AppTypography.titleRegular.copyWith(
            color: palette.textSecondary.withValues(alpha: .55),
          ),
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide:
                BorderSide(color: palette.textSecondary.withValues(alpha: .45)),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: palette.error),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: palette.error, width: 1.5),
          ),
          errorStyle: AppTypography.label.copyWith(color: palette.error),
        ),
      ),
    );
  }

  Widget _otpInput() {
    return OtpCodeField(
      fieldKey: const ValueKey('auth-code-input'),
      controller: _codeController,
      focusNode: _codeFocusNode,
      length: _otpLength,
      busy: _isLoading,
      errorText: _codeError,
      errorShake: _codeErrorShake,
      onSubmitted: (_) => _submitCode(),
    );
  }

  Widget _primaryButton({
    required String label,
    VoidCallback? onPressed,
    Key? key,
  }) {
    final palette = context.palette;
    final foreground =
        onPressed == null ? palette.textSecondary : palette.textOnAccent;
    return SizedBox(
      key: key,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          // Solid accent: the design's 75 % orange glass fails contrast for
          // white 16 px text, and nothing is behind this button to blur.
          backgroundColor: palette.accent,
          foregroundColor: palette.textOnAccent,
          disabledBackgroundColor:
              Color.alphaBlend(palette.accentFaint, palette.surface),
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                _showAuthForm ? AppRadii.lg : AppRadii.pill),
          ),
          elevation: 4,
          shadowColor: palette.shadow,
          textStyle: AppTypography.titleMedium,
        ),
        child: _isLoading
            ? SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: foreground,
                ),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _SlideData {
  final String icon;
  final String title;
  final String subtitle;
  const _SlideData(
      {required this.icon, required this.title, required this.subtitle});
}
