import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/api.dart';
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
      final first = localDigits.substring(0, localDigits.length.clamp(0, 3));
      buffer.write(first);
    }
    if (localDigits.length > 3) {
      buffer.write(' ');
      final second = localDigits.substring(3, localDigits.length.clamp(3, 6));
      buffer.write(second);
    }
    if (localDigits.length > 6) {
      buffer.write(' ');
      final third = localDigits.substring(6, localDigits.length.clamp(6, 8));
      buffer.write(third);
    }
    if (localDigits.length > 8) {
      buffer.write(' ');
      final fourth = localDigits.substring(8, localDigits.length.clamp(8, 10));
      buffer.write(fourth);
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
  const LoginPage({Key? key, this.redirectTabIndex}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ─── Palette (mainPage) ──────────────────────────────────
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _pageController = PageController();
  bool _codeSent = false;
  bool _isLoading = false;
  bool _showAuthForm = false;
  int _currentPage = 0;

  // Onboarding slides data
  static const _slides = [
    _SlideData(
      icon: Icons.local_offer_rounded,
      title: 'Персональные\nакции и скидки',
      subtitle: 'Уникальные предложения\nтолько для вас',
    ),
    _SlideData(
      icon: Icons.flash_on_rounded,
      title: 'Быстрое\nоформление заказа',
      subtitle: 'Заказ в пару нажатий\nс сохранением адресов',
    ),
    _SlideData(
      icon: Icons.history_rounded,
      title: 'История заказов\nи повтор покупок',
      subtitle: 'Легко найти и повторить\nлюбой прошлый заказ',
    ),
    _SlideData(
      icon: Icons.star_rounded,
      title: 'Программа\nлояльности',
      subtitle: 'Накапливайте бонусы\nс каждой покупки',
    ),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    final digits = PhoneTextInputFormatter.normalize(_phoneController.text.trim());
    if (digits.isEmpty) return '';
    return '+$digits';
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final phone = _normalizedPhone();
    try {
      final sent = await ApiService.sendAuthCode(phone);
      if (sent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Код отправлен на $phone'),
              backgroundColor: _card,
            ),
          );
          setState(() => _codeSent = true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось отправить код'),
              backgroundColor: _card,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: _card),
        );
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
          MaterialPageRoute(
            builder: (_) => AuthenticationWrapper(
              initialTabIndex: widget.redirectTabIndex,
            ),
          ),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный код или ошибка'),
            backgroundColor: _card,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: _card),
        );
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
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          // Background
          _background(),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                _topBar(),

                // Main content
                Expanded(
                  child: _showAuthForm ? _authFormView() : _onboardingView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Background ──────────────────────────────────────────
  Widget _background() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgDeep],
          ),
        ),
        child: Stack(
          children: [
            // Top-left orange glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.6),
                    radius: 1.0,
                    colors: [
                      _orange.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-right subtle glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.8),
                    radius: 1.4,
                    colors: [
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 0),
      child: Row(
        children: [
          if (_showAuthForm)
            GestureDetector(
              onTap: () => setState(() {
                _showAuthForm = false;
                _codeSent = false;
                _codeController.clear();
              }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 16.s),
              ),
            )
          else if (Navigator.of(context).canPop())
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Icon(Icons.close_rounded, color: _text, size: 16.s),
              ),
            ),
          const Spacer(),
          // Logo
          SvgPicture.asset('assets/logo_new.svg', height: 25.s),
          const Spacer(),
          // Invisible balance for centering logo
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  // ─── Onboarding view ─────────────────────────────────────
  Widget _onboardingView() {
    return Column(
      children: [
        // Carousel
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _slidePage(_slides[i]),
          ),
        ),

        // Dots
        Padding(
          padding: EdgeInsets.only(bottom: 22.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 4.s),
                width: active ? 22.s : 7.s,
                height: 7.s,
                decoration: BoxDecoration(
                  color: active ? _orange : _textMute.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),

        // Subtitle
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.s),
          child: Text(
            'Войдите в аккаунт, чтобы не упустить выгоду',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: _textMute.withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ),
        SizedBox(height: 18.s),

        // CTA button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.s),
          child: SizedBox(
            width: double.infinity,
            height: 48.s,
            child: Material(
              color: _orange,
              borderRadius: BorderRadius.circular(14.s),
              child: InkWell(
                borderRadius: BorderRadius.circular(14.s),
                onTap: () => setState(() => _showAuthForm = true),
                child: Center(
                  child: Text(
                    'Войти или зарегистрироваться',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 14.s),

        // Chevron hint
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 25.s,
          color: _textMute.withValues(alpha: 0.3),
        ),
        SizedBox(height: 22.s),
      ],
    );
  }

  // ─── Slide page ──────────────────────────────────────────────────
  Widget _slidePage(_SlideData slide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28.s, 22.s, 28.s, 0),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Icon card
          _slideIllustration(slide.icon),
          SizedBox(height: 36.s),
          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25.sp,
              fontWeight: FontWeight.w900,
              color: _text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 10.s),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: _textMute.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // ─── Slide illustration ──────────────────────────────────
  Widget _slideIllustration(IconData icon) {
    return SizedBox(
      height: 144.s,
      width: 180.s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow circle
          Container(
            width: 126.s,
            height: 126.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _orange.withValues(alpha: 0.15),
                  _orange.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Icon container
          Container(
            width: 78.s,
            height: 78.s,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(25.s),
              border: Border.all(color: _orange.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: _orange.withValues(alpha: 0.1),
                  blurRadius: 28.s,
                  spreadRadius: 4.s,
                ),
              ],
            ),
            child: Icon(icon, size: 36.s, color: _orange),
          ),
          // Decorative accent dots
          Positioned(
            top: 12,
            right: 24,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Auth form view ──────────────────────────────────────
  Widget _authFormView() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22.s, 14.s, 22.s, 28.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 22.s),

          // Illustration
          Center(child: _slideIllustration(Icons.phone_iphone_rounded)),
          SizedBox(height: 28.s),

          // Title
          Text(
            _codeSent ? 'Введите код' : 'Вход по номеру\nтелефона',
            style: TextStyle(
              fontSize: 25.sp,
              fontWeight: FontWeight.w900,
              color: _text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 7.s),
          Text(
            _codeSent ? 'Мы отправили СМС на ${_phoneController.text}' : 'Мы отправим короткий код подтверждения',
            style: TextStyle(
              fontSize: 13.sp,
              color: _textMute.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          SizedBox(height: 25.s),

          // Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (!_codeSent) ...[
                  // Phone input
                  _inputField(
                    controller: _phoneController,
                    label: 'Номер телефона',
                    hint: '+7 700 123 45 67',
                    icon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    formatters: [PhoneTextInputFormatter()],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Введите номер телефона';
                      if (PhoneTextInputFormatter.normalize(value).length != 11) return 'Неверный формат номера';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _primaryButton(
                    label: 'Получить код',
                    onPressed: _isLoading ? null : _sendCode,
                  ),
                ] else ...[
                  // Code input
                  _otpInput(),
                  const SizedBox(height: 20),
                  _primaryButton(
                    label: 'Подтвердить',
                    onPressed: _isLoading || _codeController.text.trim().length != 6 ? null : _verifyCode,
                  ),
                  SizedBox(height: 14.s),
                  // Resend / change number
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _codeFocusNode.unfocus();
                      }),
                      child: Text(
                        'Изменить номер',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _orange,
                        ),
                      ),
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

  Widget _otpInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Код из СМС',
          style: TextStyle(
            color: _textMute.withValues(alpha: 0.7),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 10.s),
        GestureDetector(
          onTap: () => _codeFocusNode.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: List.generate(6, (index) {
                  final code = _codeController.text;
                  final hasValue = index < code.length;
                  final isActive = _codeFocusNode.hasFocus && code.length == index;
                  final isFilled = hasValue;

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index == 5 ? 0 : 8.s),
                      height: 58.s,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14.s),
                        border: Border.all(
                          color: isActive
                              ? _orange
                              : isFilled
                                  ? _orange.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.06),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hasValue ? code[index] : '',
                          style: TextStyle(
                            color: _text,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                          ),
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
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading && _codeController.text.trim().length == 6) {
                        _verifyCode();
                      }
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    maxLength: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.s),
        Text(
          'Можно вставить код целиком',
          style: TextStyle(
            color: _textMute.withValues(alpha: 0.45),
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }

  // ─── Input field ─────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      autofocus: autofocus,
      style: TextStyle(
        color: _text,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _orange,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: EdgeInsets.only(left: 12.s, right: 9.s),
          child: Icon(icon, color: _orange, size: 20.s),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 42.s),
        filled: true,
        fillColor: _card,
        labelStyle: TextStyle(color: _textMute.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: _textMute.withValues(alpha: 0.3)),
        contentPadding: EdgeInsets.symmetric(horizontal: 18.s, vertical: 16.s),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.s),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.s),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.s),
          borderSide: BorderSide(color: _orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.s),
          borderSide: const BorderSide(color: Color(0xFFC23B30)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.s),
          borderSide: const BorderSide(color: Color(0xFFC23B30), width: 1.5),
        ),
        errorStyle: TextStyle(color: const Color(0xFFC23B30), fontSize: 11.sp),
      ),
    );
  }

  // ─── Primary button ──────────────────────────────────────
  Widget _primaryButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48.s,
      child: Material(
        color: onPressed != null ? _orange : _orange.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.s),
          onTap: onPressed,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Slide data ────────────────────────────────────────────
class _SlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SlideData({required this.icon, required this.title, required this.subtitle});
}
