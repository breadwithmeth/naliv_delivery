import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';

import '../legal_acceptance.dart';
import 'legal_document_page.dart';

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
        setState(() => _error = 'Не удалось открыть документы');
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
        setState(() => _error = 'Не удалось сохранить согласия');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(String id, String title) {
    final text = _documents?[id];
    if (text == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(title: title, text: text),
      ),
    );
  }

  Widget _document(String id, String title, {String? displayTitle}) {
    final palette = context.palette;
    return TextButton(
      key: ValueKey('legal-$id-document'),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: palette.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      ),
      onPressed: _documents == null ? null : () => _open(id, title),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayTitle ?? title,
              semanticsLabel: title,
              style: AppTypography.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20, color: palette.textSecondary),
        ],
      ),
    );
  }

  Widget _choice(String id, String label) {
    final already = widget.accepted[id] == LegalAcceptance.current[id];
    return CheckboxListTile(
      key: ValueKey('legal-$id-choice'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _choices[id],
      onChanged: already || _saving || _documents == null
          ? null
          : (value) => setState(() => _choices[id] = value ?? false),
      title: Text(label, style: AppTypography.bodySmall),
      subtitle: already ? const Text('Уже принято') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The longest heading word needs more room than a narrow, 2× column.
    final narrowText = MediaQuery.sizeOf(context).width - 32 <
        MediaQuery.textScalerOf(context).scale(20) * 8;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              children: [
                Center(
                  child: AppIcon(
                    dark ? AppIcons.wordmark : AppIcons.wordmarkLight,
                    width: 166,
                    height: 38,
                  ),
                ),
                SizedBox(height: narrowText ? 32 : 64),
                Semantics(
                  header: true,
                  child: Text(
                    'Условия использования',
                    textAlign: TextAlign.center,
                    style: narrowText ? AppTypography.title : AppTypography.headline,
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: palette.surface,
                  borderRadius: AppRadii.lgAll,
                  child: Column(
                    children: [
                      _document('offer', 'Публичная оферта'),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: palette.divider,
                      ),
                      _document(
                        'privacy',
                        'Политика конфиденциальности',
                        displayTitle: narrowText ? 'Политика о данных' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _choice('offer', 'Принимаю условия публичной оферты'),
                _choice('privacy', 'Даю согласие на обработку персональных данных'),
                if (_documents == null && _error == null)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: palette.error)),
                  ),
                  if (_documents == null)
                    TextButton(
                      onPressed: _loadDocuments,
                      child: const Text('Повторить'),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('legal-continue'),
                  style: FilledButton.styleFrom(minimumSize: const Size(44, 52)),
                  onPressed: _saving || _documents == null || _choices.containsValue(false)
                      ? null
                      : _save,
                  child: Text(
                    _saving
                        ? 'Сохраняем…'
                        : _error != null && _documents != null
                            ? 'Повторить'
                            : 'Продолжить',
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
