import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../city_contacts.dart';

/// Keeps development/platform launch policy across replacement application routes.
class CityContactsLauncherScope extends InheritedWidget {
  const CityContactsLauncherScope({
    required this.launch, required super.child, super.key,
  });

  final Future<bool> Function(Uri)? launch;

  @override
  bool updateShouldNotify(CityContactsLauncherScope oldWidget) =>
      launch != oldWidget.launch;
}

/// Opens the support directory, recommending a hotline only for a known city.
Future<void> showCityContactsSheet(
  BuildContext context, {
  int? cityId,
  required VoidCallback onChat,
  Future<bool> Function(Uri)? launch,
}) async {
  final effectiveLaunch = launch ??
      context.dependOnInheritedWidgetOfExactType<CityContactsLauncherScope>()?.launch ??
      _launchExternally;
  final openChat = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _CityContactsSheet(
        recommended: cityContactById(cityId),
        launch: effectiveLaunch,
      ),
    ),
  );
  if (openChat == true && context.mounted) onChat();
}

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class _CityContactsSheet extends StatefulWidget {
  const _CityContactsSheet({required this.recommended, required this.launch});

  final CityContact? recommended;
  final Future<bool> Function(Uri) launch;

  @override
  State<_CityContactsSheet> createState() => _CityContactsSheetState();
}

class _CityContactsSheetState extends State<_CityContactsSheet> {
  static final _whatsAppUri = Uri.https(
    'wa.me',
    '/${supportWhatsAppNumber.substring(1)}',
  );

  bool _launching = false;

  void _openChat() => Navigator.of(context).pop(true);

  Future<void> _call(CityContact contact) =>
      _openContact(Uri(scheme: 'tel', path: contact.phone), contact.phone);

  Future<void> _openWhatsApp() =>
      _openContact(_whatsAppUri, supportWhatsAppNumber);

  Future<void> _openContact(Uri uri, String phone) async {
    if (_launching) return;
    _launching = true;
    bool opened;
    try {
      opened = await widget.launch(uri);
    } catch (_) {
      // An unavailable platform handler can throw instead of returning false.
      opened = false;
    } finally {
      _launching = false;
    }
    if (opened || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final openChat = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _ContactRecoveryDialog(
        title: uri.scheme == 'tel'
            ? 'Не удалось открыть телефон'
            : 'Не удалось открыть WhatsApp',
        phone: phone,
      ),
    );
    if (openChat == true &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      _openChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommended = widget.recommended;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text('Контакты', style: AppTypography.headline),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (recommended != null)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.lgAll,
                  ),
                  leading: const Icon(Icons.call_outlined),
                  title: Text(
                    'Позвонить · ${recommended.name}',
                    style: AppTypography.title,
                  ),
                  subtitle: Text(recommended.phone,
                    style: const TextStyle(fontSize: 12)),
                  onTap: () => _call(recommended),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Написать в чат'),
              onTap: _openChat,
            ),
            const Divider(height: 1),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              initiallyExpanded: recommended == null,
              title: const Text('Все города и телефоны'),
              children: [
                for (final contact in cityContacts)
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: Text(contact.name),
                    subtitle: Text(contact.phone,
                      style: const TextStyle(fontSize: 12)),
                    onTap: () => _call(contact),
                  ),
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('WhatsApp'),
                  subtitle: const Text(supportWhatsAppNumber,
                    style: TextStyle(fontSize: 12)),
                  onTap: _openWhatsApp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRecoveryDialog extends StatefulWidget {
  const _ContactRecoveryDialog({required this.title, required this.phone});

  final String title;
  final String phone;

  @override
  State<_ContactRecoveryDialog> createState() => _ContactRecoveryDialogState();
}

class _ContactRecoveryDialogState extends State<_ContactRecoveryDialog> {
  static final _actionStyle = TextButton.styleFrom(
    minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
    visualDensity: VisualDensity.standard,
  );

  bool _copying = false;
  String? _copyStatus;

  Future<void> _copy() async {
    if (_copying) return;
    setState(() => _copying = true);
    var status = 'Номер скопирован';
    try {
      await Clipboard.setData(ClipboardData(text: widget.phone));
    } catch (_) {
      status = 'Не удалось скопировать номер';
    }
    if (!mounted) return;
    setState(() {
      _copying = false;
      _copyStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _copyStatus;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.phone, style: const TextStyle(fontSize: 12)),
          if (status != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(liveRegion: true, child: Text(status)),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: _actionStyle,
          onPressed: _copying ? null : _copy,
          child: const Text('Скопировать'),
        ),
        TextButton(
          style: _actionStyle,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Написать в чат'),
        ),
      ],
    );
  }
}
