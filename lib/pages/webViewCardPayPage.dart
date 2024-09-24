import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:naliv_delivery/main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:naliv_delivery/misc/api.dart';
import '../globals.dart' as globals;

class WebViewCardPayPage extends StatefulWidget {
  const WebViewCardPayPage({super.key, required this.htmlString});

  final String htmlString;

  @override
  State<WebViewCardPayPage> createState() => _WebViewCardPayPageState();
}

class _WebViewCardPayPageState extends State<WebViewCardPayPage> {
  final GlobalKey webViewKey = GlobalKey();
  // int loadingPercentage = 0;
  bool pageLoaded = false;

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    // iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
  );

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  String successUrl = "https://chorenn.naliv.kz/success";
  String failureUrl = "https://chorenn.naliv.kz/failure";
  final urlController = TextEditingController();

  // What to do when payment succeeded
  void _handlePaymentSuccess() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
      builder: (context) {
        return Main();
      },
    ), (route) => false);
  }

  // What to do when payment failed
  void _handlePaymentFailure() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
      builder: (context) {
        return Main();
      },
    ), (route) => false);
  }

  @override
  void initState() {
    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(urlRequest: URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Оплата картой',
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                InAppWebView(
                  key: webViewKey,
                  initialData: InAppWebViewInitialData(data: widget.htmlString),
                  initialSettings: settings,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                  },
                  onReceivedHttpError: (controller, request, errorResponse) {
                    print(errorResponse);
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    var uri = navigationAction.request.url!;

                    if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                      if (await canLaunchUrl(uri)) {
                        // Launch the App
                        await launchUrl(
                          uri,
                        );
                        // and cancel the request
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController?.endRefreshing();
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                    if (url != null) {
                      if (url.toString() == successUrl) {
                        _handlePaymentSuccess();
                      } else if (url.toString() == failureUrl) {
                        _handlePaymentFailure();
                      }
                    }
                  },
                  onReceivedError: (controller, request, error) {
                    pullToRefreshController?.endRefreshing();
                    if (request.url.rawValue == failureUrl) {
                      _handlePaymentFailure();
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController?.endRefreshing();
                    }
                    setState(() {
                      this.progress = progress / 100;
                      urlController.text = url;
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    if (kDebugMode) {
                      print(consoleMessage);
                    }
                  },
                ),
                progress < 1.0 ? LinearProgressIndicator(value: progress) : Container(),
              ],
            );
          },
        ),
      ),
    );
  }
}
