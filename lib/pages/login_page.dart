import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/api.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import '../utils/responsive.dart';

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

class LoginPage extends StatefulWidget {
  final int? redirectTabIndex;
  const LoginPage({super.key, this.redirectTabIndex});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
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

  late final AnimationController _iconPulse;

  Timer? _autoSlideTimer;
  Timer? _resumeTimer;
  bool _userInteracting = false;

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
        _pageController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
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
    final digits = PhoneTextInputFormatter.normalize(_phoneController.text.trim());
    if (digits.isEmpty) return '';
    return '+$digits';
  }

  // ── API calls ─────────────────────────────────────────────

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final phone = _normalizedPhone();
    try {
      final sent = await ApiService.sendAuthCode(phone);
      if (mounted && sent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Код отправлен на $phone'),
          backgroundColor: AppColors.card,
        ));
        setState(() => _codeSent = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось отправить код'),
          backgroundColor: AppColors.card,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.card));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) return;
    setState(() => _isLoading = true);
    final phone = _normalizedPhone();
    final code = _codeController.text.trim();
    try {
      final data = await ApiService.verifyAuthCode(phone, code);
      if (data != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthenticationWrapper(initialTabIndex: widget.redirectTabIndex)),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Неверный код или ошибка'),
          backgroundColor: AppColors.card,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.card));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _showAuthForm ? _authFormView() : _onboardingView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 0),
      child: Row(
        children: [
          if (_showAuthForm)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: AppColors.text,
              onPressed: () => setState(() {
                _showAuthForm = false;
                _codeSent = false;
                _codeController.clear();
              }),
            )
          else if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          const Spacer(),
          SvgPicture.asset('assets/logo_new.svg', height: 25.s),
          const Spacer(),
          const SizedBox(width: 48), // balance for logo centering
        ],
      ),
    );
  }

  // ── Onboarding view ───────────────────────────────────────

  Widget _onboardingView() {
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
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                _iconPulse.forward(from: 0.0);
              },
              itemBuilder: (_, i) => _slidePage(_slides[i]),
            ),
          ),
        ),
        // Dots
        Padding(
          padding: EdgeInsets.only(bottom: 20.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 4.s),
                width: active ? 20.s : 6.s,
                height: 6.s,
                decoration: BoxDecoration(
                  color: active ? AppColors.orange : AppColors.textMute.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        Text(
          'Войдите, чтобы не упустить выгоду',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 13.sp, height: 1.3),
        ),
        SizedBox(height: 16.s),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.s),
          child: _primaryButton(
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
        SizedBox(height: 26.s),
      ],
    );
  }

  // ── Slide page ────────────────────────────────────────────

  Widget _slidePage(_SlideData slide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28.s, 22.s, 28.s, 0),
      child: Column(
        children: [
          const Spacer(flex: 1),
          _glowIcon(slide.icon),
          SizedBox(height: 28.s),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.15, letterSpacing: -0.5)),
          SizedBox(height: 8.s),
          Text(slide.subtitle,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, color: AppColors.textMute.withValues(alpha: 0.6), height: 1.4)),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // ── Auth form view ────────────────────────────────────────

  Widget _glowIcon(IconData icon) {
    return AnimatedBuilder(
      animation: _iconPulse,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_iconPulse.value);
        final scale = 0.85 + 0.15 * t;
        final glowOpacity = 0.18 + 0.12 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 88.s,
            height: 88.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.orange.withValues(alpha: glowOpacity),
                  AppColors.orange.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Center(
              child: Icon(icon, size: 52.s, color: AppColors.orange),
            ),
          ),
        );
      },
    );
  }

  Widget _authFormView() {
    return SingleChildScrollView(
      key: const ValueKey('auth'),
      padding: EdgeInsets.fromLTRB(22.s, 14.s, 22.s, 28.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28.s),
          Icon(Icons.phone_iphone_rounded, size: 40.s, color: AppColors.orange),
          SizedBox(height: 18.s),
          Text(
            _codeSent ? 'Введите код' : 'Вход по номеру телефона',
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.15),
          ),
          SizedBox(height: 6.s),
          Text(
            _codeSent ? 'СМС отправлено на ${_phoneController.text}' : 'Отправим короткий код подтверждения',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textMute.withValues(alpha: 0.6), height: 1.4),
          ),
          SizedBox(height: 24.s),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (!_codeSent) ...[
                  _phoneInput(),
                  SizedBox(height: 18.s),
                  _primaryButton(label: 'Получить код', onPressed: _isLoading ? null : _sendCode),
                ] else ...[
                  _otpInput(),
                  SizedBox(height: 18.s),
                  _primaryButton(label: 'Подтвердить', onPressed: _isLoading || _codeController.text.trim().length != 6 ? null : _verifyCode),
                  SizedBox(height: 14.s),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _codeSent = false;
                        _codeController.clear();
                      }),
                      child: Text('Изменить номер', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.orange)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone input ───────────────────────────────────────────

  Widget _phoneInput() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      autofocus: true,
      keyboardType: TextInputType.phone,
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
      style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w600),
      cursorColor: AppColors.orange,
      decoration: InputDecoration(
        hintText: '+7 700 123 45 67',
        hintStyle: TextStyle(color: AppColors.textMute.withValues(alpha: 0.3)),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 12.s, right: 8.s),
          child: Icon(Icons.phone_iphone_rounded, color: AppColors.orange, size: 20.s),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 42.s),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.s), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.s), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.s), borderSide: const BorderSide(color: AppColors.orange, width: 1)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.s), borderSide: const BorderSide(color: AppColors.red)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14.s), borderSide: const BorderSide(color: AppColors.red, width: 1)),
        errorStyle: TextStyle(color: AppColors.red, fontSize: 11.sp),
      ),
    );
  }

  // ── OTP input ─────────────────────────────────────────────

  Widget _otpInput() {
    return GestureDetector(
      onTap: () => _codeFocusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(6, (index) {
              final code = _codeController.text;
              final hasValue = index < code.length;
              final isActive = _codeFocusNode.hasFocus && code.length == index;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 5 ? 0 : 8.s),
                  height: 54.s,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12.s),
                    border: Border.all(
                      color: isActive
                          ? AppColors.orange
                          : hasValue
                              ? AppColors.orange.withValues(alpha: 0.4)
                              : Colors.transparent,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      hasValue ? code[index] : '',
                      style: TextStyle(color: AppColors.text, fontSize: 22.sp, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: TextFormField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                autofocus: true,
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
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                maxLength: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary button ────────────────────────────────────────

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 48.s,
      child: Material(
        color: onPressed != null ? AppColors.orange : AppColors.orange.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.s),
          onTap: onPressed,
          child: Center(
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.black)),
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
  const _SlideData({required this.icon, required this.title, required this.subtitle});
}
