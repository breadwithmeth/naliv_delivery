import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewCardPayPage extends StatefulWidget {
  const WebViewCardPayPage({super.key});

  @override
  State<WebViewCardPayPage> createState() => _WebViewCardPayPageState();
}

class _WebViewCardPayPageState extends State<WebViewCardPayPage> {
  late final WebViewController controller;
  int loadingPercentage = 0;

  @override
  void initState() {
    controller = WebViewController()
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            loadingPercentage = 0;
          });
        },
        onProgress: (progress) {
          setState(() {
            loadingPercentage = progress;
          });
        },
        onPageFinished: (url) {
          setState(() {
            loadingPercentage = 100;
          });
        },
      ))
      ..loadRequest(
        Uri.parse('https://flutter.dev'),
      );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата картой'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: controller,
                ),
                if (loadingPercentage < 100)
                  LinearProgressIndicator(
                    value: loadingPercentage / 100.0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
