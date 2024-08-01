import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../globals.dart' as globals;

class WebViewCardPayPage extends StatefulWidget {
  const WebViewCardPayPage({super.key, required this.htmlString});

  final String htmlString;

  @override
  State<WebViewCardPayPage> createState() => _WebViewCardPayPageState();
}

class _WebViewCardPayPageState extends State<WebViewCardPayPage> {
  late final WebViewController controller;
  // int loadingPercentage = 0;
  bool pageLoaded = false;

  @override
  void initState() {
    controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              pageLoaded = false;
            });
          },
          // onProgress: (progress) {
          //   setState(() {
          //     loadingPercentage = progress;
          //   });
          // },
          onPageFinished: (url) {
            setState(() {
              pageLoaded = true;
            });
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlString);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата картой'),
        actions: [
          ElevatedButton(
            onPressed: () {
              controller.currentUrl().then(
                (value) {
                  print(value);
                },
              );
            },
            child: Text("URL"),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                alignment: Alignment.center,
                child: Text(
                  "Пожалуйста подождите",
                  style: TextStyle(
                    fontSize: 52 * globals.scaleParam,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              pageLoaded == true
                  ? Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: WebViewWidget(
                        controller: controller,
                      ),
                    )
                  : LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}
