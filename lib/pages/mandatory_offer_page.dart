import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import '../services/agreement_service.dart';

class MandatoryOfferPage extends StatefulWidget {
  final VoidCallback onAccepted;

  const MandatoryOfferPage({
    super.key,
    required this.onAccepted,
  });

  @override
  State<MandatoryOfferPage> createState() => _MandatoryOfferPageState();
}

class _MandatoryOfferPageState extends State<MandatoryOfferPage> {
  bool _isAccepted = false;
  bool _isLoading = false;
  String? _offerContent;

  @override
  void initState() {
    super.initState();
    _loadOfferContent();
  }

  Future<void> _loadOfferContent() async {
    try {
      final content = await rootBundle.loadString('assets/agreements/offer.md');
      setState(() {
        _offerContent = content;
      });
    } catch (e) {
      print('Ошибка загрузки оферты: $e');
      setState(() {
        _offerContent = '''# Публичная оферта

Не удалось загрузить содержимое оферты.
Пожалуйста, проверьте подключение к интернету и перезапустите приложение.

Для продолжения использования приложения необходимо принять условия публичной оферты.''';
      });
    }
  }

  Future<void> _acceptOffer() async {
    if (!_isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Необходимо принять условия оферты для продолжения'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AgreementService.acceptOffer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оферта принята успешно'),
            backgroundColor: Colors.green,
          ),
        );

        // Небольшая задержка для показа сообщения
        await Future.delayed(const Duration(milliseconds: 500));

        widget.onAccepted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при принятии оферты: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Публичная оферта',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _offerContent == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Загружаем условия оферты...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Контент оферты
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Markdown(
                      data: _offerContent!,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white70, fontSize: 14),
                        h1: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        h2: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                        h3: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          border: Border(
                            left: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 4),
                          ),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                // Чекбокс согласия
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAccepted
                          ? Theme.of(context).primaryColor
                          : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isAccepted,
                        onChanged: (value) {
                          setState(() {
                            _isAccepted = value ?? false;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                        checkColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Я прочитал(а) и принимаю условия публичной оферты',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Кнопка принятия
                Container(
                  margin: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _acceptOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAccepted
                          ? Theme.of(context).primaryColor
                          : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _isAccepted ? 4 : 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Принять и продолжить',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // Предупреждение
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    'Для использования приложения необходимо принять условия публичной оферты',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
