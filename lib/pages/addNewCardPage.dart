import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/webViewAddCard.dart';

class AddNewCardPage extends StatefulWidget {
  const AddNewCardPage({super.key, required this.createOrder});
  final bool createOrder;
  @override
  State<AddNewCardPage> createState() => _AddNewCardPageState();
}

class _AddNewCardPageState extends State<AddNewCardPage> {
  bool _isLoading = false; // Добавляем состояние загрузки

  @override
  Widget build(BuildContext context) {
    // Получаем цвета темы
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color backgroundColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final Color secondaryBackgroundColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final Color labelColor = CupertinoColors.label.resolveFrom(context);
    final Color secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final Color tertiaryLabelColor =
        CupertinoColors.tertiaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor, // Используем цвет фона темы
      navigationBar: CupertinoNavigationBar(
        middle: Text('Добавление карты'),
        // Кнопка "Назад" будет добавлена автоматически, если возможно
        previousPageTitle: 'Способы оплаты',
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Размещаем контент
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Информационный блок 1
                  _buildInfoContainer(
                    context,
                    secondaryBackgroundColor,
                    labelColor,
                    '''При добавлении новой платежной карты с вашего счета временно будет списана сумма в размере 10 тенге в целях проверки работоспособности карты и подтверждения ее привязки к вашему аккаунту.''',
                    fontSize: 15, // Немного уменьшили шрифт
                    fontWeight: FontWeight.w400,
                  ),
                  SizedBox(height: 16),
                  // Информационный блок 2
                  _buildInfoContainer(
                    context,
                    secondaryBackgroundColor,
                    secondaryLabelColor, // Используем вторичный цвет текста
                    '''После нажатия кнопки "Продолжить" в вашем браузере откроется окно для проведения оплаты. В случае, если после завершения оплаты вас не вернуло в приложение, пожалуйста, откройте приложение вручную и нажмите кнопку "К списку карт".''',
                    fontSize: 13, // Уменьшили шрифт
                    fontWeight: FontWeight.w400,
                  ),
                ],
              ),
            ),
            // Нижний блок с кнопками
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Кнопки на всю ширину
                children: [
                  CupertinoButton.filled(
                    onPressed: _isLoading
                        ? null
                        : _handleAddCard, // Блокируем кнопку при загрузке
                    child: _isLoading
                        ? CupertinoActivityIndicator(
                            color: CupertinoColors.white) // Индикатор загрузки
                        : Text(
                            "Продолжить",
                            style: TextStyle(
                              fontWeight: FontWeight.w600, // Сделали жирнее
                            ),
                          ),
                  ),
                  SizedBox(height: 12),
                  CupertinoButton(
                    color:
                        secondaryBackgroundColor, // Цвет фона для вторичной кнопки
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      "К списку карт",
                      style: TextStyle(
                        color: CupertinoTheme.of(context)
                            .primaryColor, // Цвет основной темы
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный виджет для информационных контейнеров
  Widget _buildInfoContainer(
      BuildContext context, Color backgroundColor, Color textColor, String text,
      {double fontSize = 16, FontWeight fontWeight = FontWeight.w400}) {
    return Container(
      padding: EdgeInsets.all(16), // Увеличили отступы
      decoration: BoxDecoration(
          color: backgroundColor, // Используем цвет темы
          borderRadius:
              BorderRadius.all(Radius.circular(12))), // Скругление поменьше
      child: Text(
        text,
        style: TextStyle(
          fontWeight: fontWeight,
          fontSize: fontSize,
          color: textColor, // Используем цвет темы
          height: 1.4, // Улучшили межстрочный интервал
        ),
      ),
    );
  }

  // Метод для обработки нажатия кнопки "Продолжить"
  void _handleAddCard() {
    setState(() {
      _isLoading = true; // Показываем загрузку
    });
    addNewCard().then((v) async {
      // Проверяем, что виджет все еще активен
      if (!mounted) return;

      final url = Uri.parse(
          "https://chorenn.naliv.kz/api/d92lj3.php?u=" + v["user_uuid"]);

      // Используем push вместо pushReplacement, чтобы можно было вернуться
      await Navigator.push(context, CupertinoPageRoute(
        builder: (context) {
          return WebViewScreen(
              createOrder: widget.createOrder, url: url.toString());
        },
      ));

      // После возврата из WebView скрываем загрузку
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((error) {
      // Обработка ошибки
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Можно показать диалог с ошибкой
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Ошибка'),
            content: Text(
                'Не удалось инициировать добавление карты. Попробуйте позже.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      }
    });
  }
}
