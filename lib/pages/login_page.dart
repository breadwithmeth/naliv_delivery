import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/api.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';

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
      print(data.toString());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Авторизация')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_codeSent) ...[
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Номер телефона',
                    hintText: '+77001234567',
                    border: OutlineInputBorder(),
                  ),
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
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Получить код'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Код из СМС',
                    hintText: 'Введите код',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Подтвердить код'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
