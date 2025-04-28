import 'package:flutter/cupertino.dart'; // Используем Cupertino
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';

// Условный импорт для веб-версии (оставляем как есть)
import 'webview_web.dart' if (dart.library.io) 'webview_mobile.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final bool createOrder;
  const WebViewScreen(
      {super.key, required this.url, required this.createOrder});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0; // Добавляем состояние для прогресса загрузки

  @override
/*************  ✨ Windsurf Command ⭐  *************/
  /// Builds a [CupertinoPageScaffold] with a [CupertinoNavigationBar] and a
  /// [SafeArea] containing a [Column] with a [LinearProgressIndicator] and a
  /// [WebViewWidget] or [InAppWebView].
  ///
  /// The [LinearProgressIndicator] shows the progress of the WebView loading.
  /// The [WebViewWidget] is used for the web version and the [InAppWebView] is
  /// used for the mobile version.
  ///
  /// The [InAppWebView] handles the navigation and shows an error message if
  /// the page cannot be loaded.
  ///
  /// The [CupertinoNavigationBar] has a 'Back' button and a title.
  ///
/*******  4ed3e4fa-72ad-443c-abfe-dc3c658c28ce  *******/  Widget build(BuildContext context) {
    // Используем CupertinoPageScaffold вместо Scaffold
    return CupertinoPageScaffold(
      // Используем CupertinoNavigationBar вместо AppBar
      navigationBar: CupertinoNavigationBar(
        middle: Text("Добавление карты"),
        // Кнопка "Назад" будет добавлена автоматически
        previousPageTitle: 'Назад', // Можно указать текст для кнопки "Назад"
      ),
      // Оборачиваем тело в SafeArea для корректных отступов
      child: SafeArea(
        child: Column(
          // Используем Column для добавления индикатора прогресса
          children: [
            // Индикатор прогресса загрузки
            if (_progress < 1.0)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor:
                    CupertinoColors.systemGrey5.resolveFrom(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                    CupertinoTheme.of(context).primaryColor),
                minHeight: 2, // Делаем его тонким
              ),
            Expanded(
              child: kIsWeb
                  ? WebViewWidget(url: widget.url) // Кастомный виджет для веб
                  : InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() {
                          _progress = progress / 100; // Обновляем прогресс
                        });
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) {
                        // Логика навигации остается прежней
                        if (url != null &&
                            url.toString() ==
                                "https://chorenn.naliv.kz/failure") {
                          // Показываем сообщение об ошибке перед возвратом
                          _showResultDialog(
                              context, 'Ошибка', 'Не удалось добавить карту.');
                        }
                        if (url != null &&
                            url.toString() ==
                                "https://chorenn.naliv.kz/success") {
                          if (widget.createOrder) {
                            _showResultDialog(
                                context, 'Успешно', 'Карта успешно добавлена.',
                                popCurrent: true);
                          } else {
                            // Заменяем текущий экран на PaymentMethods после успеха
                            Navigator.pushAndRemoveUntil(context,
                                CupertinoPageRoute(
                              // Используем CupertinoPageRoute
                              builder: (context) {
                                return PaymentMethods();
                              },
                            ),
                                (route) => route
                                    .isFirst); // Удаляем все до первого экрана
                          }
                        }
                      },
                      // Можно добавить обработку ошибок загрузки страницы
                      onLoadError: (controller, url, code, message) {
                        print("WebView Error: Code $code - $message");
                        // Можно показать пользователю сообщение об ошибке
                        _showResultDialog(context, 'Ошибка загрузки',
                            'Не удалось загрузить страницу оплаты. Проверьте интернет-соединение.');
                      },
                      onLoadHttpError:
                          (controller, url, statusCode, description) {
                        print(
                            "WebView HTTP Error: Status $statusCode - $description");
                        // Можно показать пользователю сообщение об ошибке
                        _showResultDialog(context, 'Ошибка загрузки',
                            'Не удалось загрузить страницу оплаты (Код: $statusCode).');
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательная функция для показа диалога
  void _showResultDialog(BuildContext context, String title, String content,
      {bool popCurrent = false}) {
    // Проверяем, активен ли виджет
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('OK'),
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
              if (popCurrent && Navigator.canPop(context)) {
                Navigator.pop(context); // Закрываем WebViewScreen, если нужно
              }
            },
          )
        ],
      ),
    );
  }
}

// Заглушка для LinearProgressIndicator в Cupertino стиле (если нужно)
// Можно использовать CupertinoActivityIndicator или оставить Material LinearProgressIndicator
// class CupertinoLinearProgressIndicator extends StatelessWidget { ... }
