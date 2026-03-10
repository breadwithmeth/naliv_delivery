import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/api.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

// Форматирует ввод номера в +7XXXXXXXXXX
class PhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Замена ведущей 8 на 7
    if (digits.startsWith('8')) {
      digits = '7' + digits.substring(1);
    }
    // Добавить ведущую 7, если отсутствует и есть цифры
    if (!digits.startsWith('7') && digits.isNotEmpty) {
      digits = '7' + digits;
    }
    // Ограничить 11 цифрами (7 + 10 цифр номера)
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }
    final formatted = '+$digits';
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
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    try {
      final sent = await ApiService.sendAuthCode(phone);
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Код отправлен на номер $phone')),
        );
        setState(() => _codeSent = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить код')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    try {
      final data = await ApiService.verifyAuthCode(phone, code);
      if (data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Авторизация успешна')),
        );
        // После успешной авторизации переходим на BottomMenu через AuthenticationWrapper
        // и очищаем стек, чтобы нельзя было вернуться на экран логина
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => AuthenticationWrapper(
                    initialTabIndex: widget.redirectTabIndex,
                  )),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный код или ошибка')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppColors.card,
      labelStyle: const TextStyle(color: AppColors.textMute),
      hintStyle: const TextStyle(color: AppColors.textMute),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.orange, width: 1.4),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Авторизация', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.card(radius: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _codeSent ? 'Введите код из СМС' : 'Вход по номеру телефона',
                          style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Мы отправим короткий код подтверждения',
                          style: TextStyle(color: AppColors.textMute, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        if (!_codeSent) ...[
                          TextFormField(
                            controller: _phoneController,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Номер телефона',
                              hintText: '+77001234567',
                              prefixIcon: const Icon(Icons.phone_iphone, color: AppColors.textMute),
                            ),
                            style: const TextStyle(color: AppColors.text),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhoneTextInputFormatter()],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите номер телефона';
                              }
                              if (!RegExp(r"^\+7\d{10}").hasMatch(value.trim())) {
                                return 'Неверный формат номера';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text('Получить код', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _codeController,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Код из СМС',
                              hintText: 'Введите код',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMute),
                            ),
                            style: const TextStyle(color: AppColors.text),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text('Подтвердить код', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
