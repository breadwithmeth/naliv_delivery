import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

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
  late PlatformWebViewController _controller;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    )..loadRequest(
        LoadRequestParams(
          uri: Uri.parse(widget.url),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Новая карта"),
      ),
      body: kIsWeb
          ? PlatformWebViewWidget(
              PlatformWebViewWidgetCreationParams(controller: _controller),
            ).build(context)
          : InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(widget.url)), // Use WebUri
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

                  // Close WebView when URL changes
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


//