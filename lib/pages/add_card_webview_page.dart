import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../design/theme.dart';
import '../design/typography.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import 'card_flow.dart';

class AddCardWebViewPage extends StatefulWidget {
  const AddCardWebViewPage({super.key, required this.initialUrl});

  final String initialUrl;

  @override
  State<AddCardWebViewPage> createState() => _AddCardWebViewPageState();
}

class _AddCardWebViewPageState extends State<AddCardWebViewPage> {
  WebViewController? _controller;
  late final Uri? _uri;
  bool _loading = false;
  bool _launching = false;
  String? _error;

  bool get _supportsWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _uri = hostedCardUri(widget.initialUrl);
    if (_uri == null) {
      _error =
          'Некорректная ссылка формы банка. Вернитесь и получите новую ссылку.';
    } else if (_supportsWebView) {
      _initializeWebView();
    }
  }

  Future<void> _initializeWebView() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      _loading = true;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) => hostedCardUri(request.url) == null
            ? NavigationDecision.prevent
            : NavigationDecision.navigate,
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == false) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _error =
                  'Не удалось загрузить форму банка. Обновите страницу или откройте её в браузере.';
            });
          }
        },
      ));
      await controller.loadRequest(_uri!);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Не удалось открыть форму банка. Попробуйте открыть её в браузере.';
        });
      }
    }
  }

  Future<void> _reload() async {
    if (_uri == null || _loading) return;
    if (_controller == null) {
      await _initializeWebView();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _controller!.loadRequest(_uri!);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить форму банка. Попробуйте снова.';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_uri == null || _launching) return;
    setState(() => _launching = true);
    try {
      final opened = await launchUrl(
        _uri!,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (mounted) {
        setState(() {
          _error =
              opened ? null : 'Не удалось открыть браузер. Попробуйте снова.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Не удалось открыть браузер. Попробуйте снова.');
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                    title: 'Добавление карты',
                    onBack: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      children: [
                        AppSurface(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Форма банка', style: AppTypography.title),
                              if (_uri != null) ...[
                                const SizedBox(height: 8),
                                Text(_uri!.host,
                                    style: AppTypography.body.copyWith(
                                        color: palette.textSecondary)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Данные карты вводятся только в форме банка. После завершения вернитесь: привязку подтвердит обновлённый список карт.',
                                style: AppTypography.body
                                    .copyWith(color: palette.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          AppErrorState(
                            message: _error!,
                            onRetry: _uri != null && _supportsWebView
                                ? _reload
                                : null,
                            retryLabel: 'Обновить форму',
                          ),
                        ],
                        if (_controller != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: (constraints.maxHeight * .65)
                                .clamp(240.0, 700.0)
                                .toDouble(),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                      child: WebViewWidget(
                                          controller: _controller!)),
                                  if (_loading)
                                    const Positioned.fill(child: AppLoading()),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_uri != null) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _launching ? null : _openInBrowser,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(_launching
                                ? 'Открываем браузер…'
                                : 'Открыть в браузере'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Проверить привязку'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Отменить и вернуться'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
