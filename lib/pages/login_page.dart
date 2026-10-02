import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import '../utils/api.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../features/faq/models/faq.dart';
import '../features/faq/faq_navigation.dart';
import '../core/destinations.dart';
import 'profile_setup_page.dart';

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

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _iconPulse;

  Timer? _autoSlideTimer;
  Timer? _resumeTimer;
  Timer? _sendCodeCooldownTimer;
  bool _userInteracting = false;
  int _sendCodeCooldownSeconds = 0;
  String? _sendCodeCooldownPhone;

  static const _slides = [
    _SlideData(
      icon: Icons.local_offer_rounded,
      title: 'Персональные акции',
      subtitle: 'Уникальные скидки только для вас',
    ),
    _SlideData(
      icon: Icons.flash_on_rounded,
      title: 'Быстрый заказ',
      subtitle: 'Оформление в пару нажатий',
    ),
    _SlideData(
      icon: Icons.history_rounded,
      title: 'История покупок',
      subtitle: 'Повторите любой прошлый заказ',
    ),
    _SlideData(
      icon: Icons.star_rounded,
      title: 'Бонусы',
      subtitle: 'Копите с каждой покупки',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _showAuthForm = widget.startWithPhoneForm;
    if (_showAuthForm) _ensurePhonePrefix();
    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _startAutoSlide();
  }

  @override
  void dispose() {
    _iconPulse.dispose();
    _autoSlideTimer?.cancel();
    _resumeTimer?.cancel();
    _sendCodeCooldownTimer?.cancel();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Код отправлен на $phone'),
          backgroundColor: context.palette.surface,
        ));
        setState(() => _codeSent = true);
      } else {
        if (result.cooldownSeconds != null && result.cooldownSeconds! > 0) {
          _startSendCodeCooldown(
              phone: phone, seconds: result.cooldownSeconds!);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message),
          backgroundColor: context.palette.surface,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: context.palette.surface,
          ),
        );
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

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) return;
    setState(() => _isLoading = true);
    final phone = _normalizedPhone();
    final code = _codeController.text.trim();
    try {
      final data = await ApiService.verifyAuthCode(phone, code);
      if (data != null && mounted) {
        await NotificationService.instance.syncTokenWithServerIfNeeded();
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (widget.completionMode == LoginCompletionMode.returnAuthenticated) {
          await _continueReauthentication();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Неверный код или ошибка'),
            backgroundColor: context.palette.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: context.palette.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueReauthentication() async {
    final userInfo = await ApiService.getFullInfo();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final user = userInfo?['user'];
    if (user is! Map) {
      throw StateError('Не удалось подтвердить профиль. Повторите вход.');
    }
    if (ProfileSetupPage.isRequiredFor(userInfo)) {
      setState(() => _profileSetupUser = Map<String, dynamic>.from(user));
    } else {
      Navigator.of(context).pop<bool>(true);
    }
  }

  Future<void> _completeProfileSetup(
      Map<String, dynamic>? refreshedUserInfo) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (refreshedUserInfo?['user'] is Map &&
        !ProfileSetupPage.isRequiredFor(refreshedUserInfo)) {
      Navigator.of(context).pop<bool>(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
          'Не удалось подтвердить заполненный профиль. Повторите сохранение.'),
      backgroundColor: context.palette.surface,
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
    final palette = context.palette;
    final canClose = !_showAuthForm && Navigator.of(context).canPop();
    return SizedBox(
      width: double.infinity,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppIcon(
            key: const ValueKey('auth-wordmark'),
            AppIcons.wordmark,
            width: 164,
            height: 51,
            color: palette.textPrimary,
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
                    setState(() {
                      _showAuthForm = false;
                      _codeSent = false;
                      _codeController.clear();
                    });
                  }
                },
              ),
            )
          else if (canClose)
            Positioned(
              left: 16,
              child: _materialCircleButton(
                tooltip: 'Закрыть',
                icon: Icons.close_rounded,
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
                _iconPulse.forward(from: 0);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
      child: Column(
        children: [
          const Spacer(),
          _glowIcon(slide.icon),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              color: palette.textPrimary,
              height: 1.15,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _glowIcon(IconData icon) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _iconPulse,
      builder: (context, child) {
        final value = Curves.easeOut.transform(_iconPulse.value);
        return Transform.scale(
          scale: .85 + .15 * value,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.accent.withValues(alpha: .18 + .12 * value),
                  palette.accent.withValues(alpha: 0),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 52, color: palette.accent),
          ),
        );
      },
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 112, 16, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
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
                            minimumSize: const Size(0, 36),
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
                              _otpInput(),
                              const SizedBox(height: 12),
                              _primaryButton(
                                key: const ValueKey('confirm-code-button'),
                                label: 'Подтвердить',
                                onPressed: _isLoading ||
                                        _codeController.text.trim().length != 6
                                    ? null
                                    : _verifyCode,
                              ),
                              const SizedBox(height: 17),
                              TextButton(
                                onPressed: () => setState(() {
                                  _codeSent = false;
                                  _codeController.clear();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _phoneFocusNode.requestFocus();
                                  });
                                }),
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.accent,
                                  textStyle: AppTypography.body,
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      borderSide: BorderSide(
        color: palette.textSecondary.withValues(alpha: .45),
      ),
    );
    return TextFormField(
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
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        errorStyle: AppTypography.label.copyWith(color: palette.error),
      ),
    );
  }

  Widget _otpInput() {
    final palette = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      borderSide: BorderSide(color: palette.divider),
    );
    return TextFormField(
      key: const ValueKey('auth-code-input'),
      controller: _codeController,
      focusNode: _codeFocusNode,
      autofocus: true,
      autofillHints: const [AutofillHints.oneTimeCode],
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onChanged: (_) {
        if (mounted) setState(() {});
        if (!_isLoading && _codeController.text.trim().length == 6) {
          _verifyCode();
        }
      },
      onFieldSubmitted: (_) {
        if (!_isLoading && _codeController.text.trim().length == 6) {
          _verifyCode();
        }
      },
      decoration: InputDecoration(
        labelText: 'Код из SMS',
        counterText: '',
        filled: true,
        fillColor: palette.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.accent, width: 1.5)),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: AppTypography.body.copyWith(color: palette.textPrimary),
      maxLength: 6,
    );
  }

  Widget _primaryButton({
    required String label,
    VoidCallback? onPressed,
    Key? key,
  }) {
    final palette = context.palette;
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 48,
      child: Material(
        color: onPressed == null ? palette.accentSoft : palette.accent,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onPressed,
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: palette.textOnAccent,
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: palette.textOnAccent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _materialCircleButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.surface.withValues(alpha: .75),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SlideData(
      {required this.icon, required this.title, required this.subtitle});
}
