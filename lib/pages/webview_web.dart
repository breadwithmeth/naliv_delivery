import 'package:flutter/material.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class WebViewWidget extends StatefulWidget {
  final String url;
  
  const WebViewWidget({Key? key, required this.url}) : super(key: key);

  @override
  State<WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<WebViewWidget> {
  late PlatformWebViewController _controller;

  @override
  void initState() {
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
    return PlatformWebViewWidget(
      PlatformWebViewWidgetCreationParams(controller: _controller),
    ).build(context);
  }
}