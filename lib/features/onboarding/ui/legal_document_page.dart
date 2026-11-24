import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../ui/app_top_bar.dart';

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({required this.title, required String text, super.key})
    : _text = text,
      _asset = null;

  const LegalDocumentPage.asset({
    required this.title,
    required String asset,
    super.key,
  }) : _text = null,
       _asset = asset;

  final String title;
  final String? _text;
  final String? _asset;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  AssetBundle? _bundle;
  Future<String>? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._asset == null) return;
    final bundle = DefaultAssetBundle.of(context);
    if (identical(bundle, _bundle)) return;
    _bundle = bundle;
    _loading = _readAsset();
  }

  Future<String> _readAsset() async {
    final text = await _bundle!.loadString(widget._asset!);
    if (text.trim().isEmpty) throw StateError('Empty legal document');
    return text;
  }

  void _retry() {
    _bundle!.evict(widget._asset!);
    setState(() => _loading = _readAsset());
  }

  Widget _markdown(String text) => Markdown(
    data: text,
    selectable: true,
    padding: const EdgeInsets.all(20),
    // Bundled texts are self-contained; never fetch remote attachments.
    imageBuilder: (_, __, ___) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final text = widget._text;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTopBar(title: widget.title),
            ),
            Expanded(
              child: text != null
                  ? _markdown(text)
                  : FutureBuilder<String>(
                      future: _loading,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Загружаем документ',
                            ),
                          );
                        }
                        if (snapshot.hasData) return _markdown(snapshot.data!);
                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Не удалось открыть документ',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _retry,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
