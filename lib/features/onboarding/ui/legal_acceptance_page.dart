import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../ui/app_top_bar.dart';

import '../legal_acceptance.dart';

class LegalAcceptancePage extends StatefulWidget {
  const LegalAcceptancePage({
    required this.accepted,
    required this.onAccepted,
    super.key,
  });

  final Map<String, int> accepted;
  final VoidCallback onAccepted;

  @override
  State<LegalAcceptancePage> createState() => _LegalAcceptancePageState();
}

class _LegalAcceptancePageState extends State<LegalAcceptancePage> {
  late final _choices = <String, bool>{
    for (final entry in LegalAcceptance.current.entries)
      entry.key: widget.accepted[entry.key] == entry.value,
  };
  Map<String, String>? _documents;
  String? _error;
  bool _saving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _documents = null;
      _error = null;
    });
    try {
      final bundle = DefaultAssetBundle.of(context);
      final documents = <String, String>{};
      for (final entry in LegalAcceptance.assets.entries) {
        final text = await bundle.loadString(entry.value, cache: false);
        if (text.trim().isEmpty) throw StateError('Empty legal document');
        documents[entry.key] = text;
      }
      if (mounted) setState(() => _documents = documents);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось открыть документы. Повторите загрузку.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _documents == null || _choices.values.any((value) => !value)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LegalAcceptance.accept();
      if (mounted) widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить согласия. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(String id, String title) {
    final text = _documents?[id];
    if (text == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppTopBar(title: title),
                ),
                Expanded(
                  child: Markdown(
                    data: text,
                    selectable: true,
                    padding: const EdgeInsets.all(20),
                    // Bundled texts are self-contained; never fetch remote attachments.
                    imageBuilder: (_, __, ___) =>
                        const Text('Внешнее изображение недоступно офлайн'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _document(String id, String label, String title) {
    final already = widget.accepted[id] == LegalAcceptance.current[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: ValueKey('legal-$id-choice'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _choices[id],
          onChanged: already || _saving || _documents == null
              ? null
              : (value) => setState(() => _choices[id] = value ?? false),
          title: Text(label),
          subtitle: already
              ? Text('Уже принято · редакция ${LegalAcceptance.current[id]}')
              : null,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: ValueKey('legal-$id-document'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
            onPressed: _documents == null ? null : () => _open(id, title),
            child: Text(title),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Условия использования',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Перед продолжением ознакомьтесь с документами и подтвердите каждый выбор. Документы доступны без интернета.',
                    ),
                    const SizedBox(height: 24),
                    if (_documents == null && _error == null)
                      const Center(child: CircularProgressIndicator()),
                    _document(
                      'offer',
                      'Принимаю условия публичной оферты',
                      'Публичная оферта',
                    ),
                    const SizedBox(height: 12),
                    _document(
                      'privacy',
                      'Даю согласие на обработку персональных данных',
                      'Политика конфиденциальности',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_documents == null)
                        TextButton(
                          onPressed: _loadDocuments,
                          child: const Text('Повторить'),
                        ),
                    ],
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('legal-continue'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 52),
                        ),
                        onPressed: _saving ||
                                _documents == null ||
                                _choices.values.any((value) => !value)
                            ? null
                            : _save,
                        child: Text(_saving ? 'Сохраняем…' : 'Продолжить'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
