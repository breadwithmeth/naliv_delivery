import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AddCardWebViewPage extends StatefulWidget {
  final String initialUrl;

  const AddCardWebViewPage({super.key, required this.initialUrl});

  @override
  State<AddCardWebViewPage> createState() => _AddCardWebViewPageState();
}

class _AddCardWebViewPageState extends State<AddCardWebViewPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _currentUrl;

  bool get _isWeb => kIsWeb;
  Uri? get _initialUri => Uri.tryParse(widget.initialUrl);

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;

    if (_isWeb) {
      _isLoading = false;
      return;
    }

    final uri = _initialUri;
    if (uri == null) {
      _isLoading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(uri);
  }

  Future<void> _closeAndRefresh() async {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openInBrowser() async {
    final uri = _initialUri;
    if (uri == null) return;

    final launched = await launchUrl(
      uri,
      mode: _isWeb
          ? LaunchMode.platformDefault
          : defaultTargetPlatform == TargetPlatform.iOS
              ? LaunchMode.inAppWebView
              : LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть ссылку. Попробуйте еще раз.'),
        ),
      );
    }
  }

  String _hostLabel() {
    final currentUrl = _currentUrl;
    if (currentUrl == null || currentUrl.isEmpty) {
      return 'Защищенная страница банка';
    }

    final uri = Uri.tryParse(currentUrl);
    final host = uri?.host ?? '';
    if (host.isEmpty) {
      return 'Защищенная страница банка';
    }

    return host;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Добавление карты',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!_isWeb)
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (_isWeb)
            IconButton(
              tooltip: 'Открыть в браузере',
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: _closeAndRefresh,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 10.s),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.s),
                    decoration: AppDecorations.card(
                        radius: 16.s,
                        color: AppColors.cardDark.withValues(alpha: 0.96)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Откроется защищенная форма банка для привязки карты.',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4.s),
                        Text(
                          _hostLabel(),
                          style: TextStyle(
                              color: AppColors.textMute,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 14.s),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18.s),
                      child: ColoredBox(
                        color: Colors.white,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _isWeb
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24.s),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 52,
                                              color: AppColors.orange,
                                            ),
                                            SizedBox(height: 12.s),
                                            Text(
                                              'Веб-просмотр недоступен в браузере. Откройте форму банка во внешней вкладке.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.text,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(height: 16.s),
                                            ElevatedButton(
                                              onPressed: _openInBrowser,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.orange,
                                                foregroundColor: Colors.black,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 14.s,
                                                    horizontal: 24.s),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18.s),
                                                ),
                                              ),
                                              child: const Text(
                                                  'Открыть в браузере',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : _controller != null
                                      ? WebViewWidget(controller: _controller!)
                                      : Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 24.s),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  size: 52,
                                                  color: AppColors.orange,
                                                ),
                                                SizedBox(height: 12.s),
                                                Text(
                                                  'Не удалось загрузить страницу. Попробуйте еще раз или откройте ссылку во внешнем браузере.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: AppColors.text,
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(height: 16.s),
                                                ElevatedButton(
                                                  onPressed: _openInBrowser,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.orange,
                                                    foregroundColor:
                                                        Colors.black,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 14.s,
                                                            horizontal: 24.s),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18.s),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                      'Открыть в браузере',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                            ),
                            if (_isLoading)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.orange),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 18.s),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isWeb ? _openInBrowser : _closeAndRefresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 14.s),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.s)),
                      ),
                      child: Text(
                        _isWeb
                            ? 'Открыть в браузере'
                            : 'Готово, обновить карты',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
