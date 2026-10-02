import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/app_icon.dart';

import 'app_loading_screen_web_stub.dart'
    if (dart.library.js_interop) 'app_loading_screen_web_real.dart' as web_splash;

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key, this.message});

  final String? message;

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) web_splash.removeHtmlSplash();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.huge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          image: true,
                          label: 'Градусы24',
                          child: AppIcon(
                            AppIcons.wordmark,
                            width: 200,
                            height: 64,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.huge),
                        Text(
                          widget.message ?? 'Загружаем магазин',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium
                              .copyWith(color: palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
