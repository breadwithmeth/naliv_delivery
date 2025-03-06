import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';

// Условный импорт для веб-версии
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Новая карта"),
      ),
      body: kIsWeb
          ? WebViewWidget(url: widget.url) // Кастомный виджет для веб
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                if (url != null &&
                    url.toString() == "https://chorenn.naliv.kz/failure") {
                  if (widget.createOrder) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                  }
                }
                if (url != null &&
                    url.toString() == "https://chorenn.naliv.kz/success") {
                  if (widget.createOrder) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return PaymentMethods();
                      },
                    ));
                  }
                }
              },
            ),
    );
  }
}
