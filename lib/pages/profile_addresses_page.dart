import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../design/theme.dart';
import '../design/typography.dart';
import '../features/faq/ui/faq_page.dart' as redesigned;
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import '../utils/address_storage_service.dart';
import '../utils/api.dart';
import '../widgets/address_selection_modal_material.dart';
import '../features/faq/models/faq.dart';
import 'map_address_page.dart';

class ProfileAddressesPage extends StatefulWidget {
  const ProfileAddressesPage({super.key, this.tileProvider, this.locate});

  final TileProvider? tileProvider;
  final Future<AddressLocateResult> Function()? locate;

  @override
  State<ProfileAddressesPage> createState() => _ProfileAddressesPageState();
}

class _ProfileAddressesPageState extends State<ProfileAddressesPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _reading = false;
  List<Map<String, dynamic>> _server = [];
  AddressBookSnapshot _book = const AddressBookSnapshot(
    localAddresses: [],
    hiddenIds: {},
    selectedAddress: null,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_busy || _reading) return;
    _reading = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await AddressStorageService.getBookSnapshot();
      if (!mounted) return;
      setState(() => _book = book);
      final data = await ApiService.getFullInfo();
      if (data == null) throw StateError('Адреса аккаунта недоступны');
      final raw = data['addresses'];
      if (raw is! List) {
        throw const FormatException('Некорректный список адресов');
      }
      final addresses = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) throw const FormatException('Некорректный адрес');
        addresses.add(Map<String, dynamic>.from(item));
      }
      if (mounted) setState(() => _server = addresses);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Не удалось обновить адреса. Сохранённые на устройстве адреса остаются доступны.');
      }
    } finally {
      _reading = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  List<({Map<String, dynamic> address, bool local})> get _visible {
    final entries = <({Map<String, dynamic> address, bool local})>[];
    final seen = <String>{};
    for (final local in [true, false]) {
      for (final address in local ? _book.localAddresses : _server) {
        final id = AddressStorageService.identity(address);
        if (_book.hiddenIds.contains(id) || !seen.add(id)) continue;
        entries.add((address: address, local: local));
      }
    }
    return entries;
  }

  String _label(Map<String, dynamic> address) {
    final label =
        (address['address'] ?? address['name'])?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    return [address['street'], address['house']]
        .where((value) =>
            value != null && '$value'.trim().isNotEmpty && value != '-')
        .join(', ');
  }

  Map<String, dynamic> _delivery(Map<String, dynamic> address) =>
      {...address, 'address': _label(address)};

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshBook() async {
    final next = await AddressStorageService.getBookSnapshot();
    if (mounted) setState(() => _book = next);
  }

  Future<void> _select(Map<String, dynamic> address) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final normalized =
          AddressStorageService.deliveryAddress(_delivery(address));
      if (normalized == null) {
        _feedback(
            'У адреса нет точных координат. Уточните его на карте перед выбором.');
        return;
      }
      final saved = await AddressStorageService.selectBookAddress(normalized);
      if (!saved) {
        _feedback(
            'Не удалось выбрать адрес. Предыдущий адрес доставки сохранён.');
        return;
      }
      await _refreshBook();
      _feedback('Адрес выбран для доставки');
    } catch (_) {
      _feedback('Не удалось выбрать адрес. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOrEdit({Map<String, dynamic>? initial}) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final picked = await AddressSelectionModalHelper.show(
        context,
        initialAddress:
            initial == null ? <String, dynamic>{} : _delivery(initial),
        openDetailsFirst: initial != null,
        tileProvider: widget.tileProvider,
        locate: widget.locate,
        detailsConfirmButtonLabel: 'Сохранить на устройстве',
      );
      if (picked == null || !mounted) return;
      final saved = await AddressStorageService.saveBookAddress(picked,
          replacing: initial == null ? null : _delivery(initial));
      if (!saved) {
        _feedback(
            'Не удалось сохранить адрес на устройстве. Предыдущие данные не изменены.');
        return;
      }
      await _refreshBook();
      _feedback('Адрес сохранён на этом устройстве');
    } catch (_) {
      _feedback('Не удалось сохранить адрес на устройстве. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> address,
      {required bool local}) async {
    if (_busy || _loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(local
            ? 'Удалить адрес с устройства?'
            : 'Скрыть адрес на устройстве?'),
        content: Text(local
            ? 'Этот адрес будет удалён только с этого устройства. Если он выбран для доставки, выбор будет сброшен.'
            : 'Адрес останется в аккаунте, но не будет показан на этом устройстве. Если он выбран для доставки, выбор будет сброшен.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена')),
          TextButton(
            key: const Key('address_remove_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child:
                Text(local ? 'Удалить с устройства' : 'Скрыть на устройстве'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved =
          await AddressStorageService.removeBookAddress(_delivery(address));
      if (!saved) {
        _feedback(
            'Не удалось изменить адреса. Адрес и текущий выбор сохранены.');
        return;
      }
      await _refreshBook();
      _feedback(local
          ? 'Адрес удалён с устройства'
          : 'Адрес скрыт на этом устройстве');
    } catch (_) {
      _feedback('Не удалось изменить адреса. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(Map<String, dynamic> address, bool local) async {
    if (_busy || _loading) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_label(address)),
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                local
                    ? 'Сохранён на этом устройстве'
                    : 'Адрес из аккаунта. Изменения сохраняются как отдельная копия только на этом устройстве.',
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Text('Изменить адрес', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.palette.error,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(dialogContext, 'remove'),
              child: Text(
                  local ? 'Удалить с устройства' : 'Скрыть на устройстве',
                  textAlign: TextAlign.center),
            ),
          ],
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'))
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _addOrEdit(initial: address);
    if (action == 'remove') await _remove(address, local: local);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visible;
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                    title: 'Мои адреса',
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _loading && entries.isEmpty
                      ? const AppLoading()
                      : Builder(builder: (bodyContext) {
                          final clearance =
                              MediaQuery.paddingOf(bodyContext).bottom;
                          return RefreshIndicator(
                            onRefresh: _load,
                            child: LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    16, 0, 16, clearance + 16),
                                children: [
                                  if (_loading)
                                    const LinearProgressIndicator(),
                                  if (_error != null) ...[
                                    AppErrorState(
                                      message: _error!,
                                      onRetry: _busy ? null : _load,
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (entries.isEmpty && _error == null) ...[
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: constraints.maxHeight > 400
                                            ? 147
                                            : 24,
                                      ),
                                      child: const AppEmptyState(
                                        title: 'Адресов пока нет',
                                        subtitle:
                                            'Добавьте адрес, чтобы мы могли подобрать ближайший магазин и ускорить доставку',
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  _faqCard(empty: entries.isEmpty),
                                  if (entries.isNotEmpty)
                                    const SizedBox(height: 24),
                                  for (final entry in entries) ...[
                                    _addressCard(entry.address, entry.local),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppGlassPanel(
              radius: 32,
              padding: const EdgeInsets.all(8),
              child: FilledButton.icon(
                key: const Key('address_book_add'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(252, 49),
                  shape: const StadiumBorder(),
                ),
                onPressed: _busy || _loading ? null : () => _addOrEdit(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Добавить адрес',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> address, bool local) {
    final palette = context.palette;
    final selected = AddressStorageService.sameAddress(
        _book.selectedAddress, _delivery(address));
    final details = [
      if ('${address['entrance'] ?? ''}'.isNotEmpty)
        'Подъезд ${address['entrance']}',
      if ('${address['floor'] ?? ''}'.isNotEmpty) 'Этаж ${address['floor']}',
      if ('${address['apartment'] ?? ''}'.isNotEmpty)
        'Кв. ${address['apartment']}',
    ].join(', ');
    final id = AddressStorageService.identity(address);
    return Semantics(
      button: true,
      enabled: !_busy && !_loading,
      selected: selected,
      child: AppSurface(
        key: ValueKey('address_select_$id'),
        onTap: _busy || _loading ? null : () => _select(address),
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    _label(address).isEmpty
                        ? 'Уточните адрес на карте'
                        : _label(address),
                    style: AppTypography.title
                        .copyWith(color: palette.textPrimary)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(details,
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary)),
                ],
                const SizedBox(height: 6),
                Text(
                    '${local ? 'На этом устройстве' : 'Из аккаунта'}${selected ? ' · Для доставки' : ''}',
                    style: AppTypography.label.copyWith(
                        color:
                            selected ? palette.accent : palette.textSecondary)),
              ])),
          IconButton(
            key: ValueKey('address_menu_$id'),
            tooltip: 'Действия с адресом ${_label(address)}',
            onPressed: _busy || _loading ? null : () => _menu(address, local),
            icon: Icon(Icons.more_horiz, color: palette.textSecondary),
          ),
        ]),
      ),
    );
  }

  Widget _faqCard({required bool empty}) {
    final palette = context.palette;
    return AppSurface(
      fill: palette.accentFaint,
      border: Border.all(color: palette.accent.withValues(alpha: .3)),
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            const redesigned.FaqPage(initialSection: FaqSection.delivery),
      )),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 16,
            backgroundColor: palette.accentFaint,
            child: Icon(Icons.question_mark, color: palette.accent, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              empty ? 'Не определяется адрес?' : 'Вопросы по адресу и доставке',
              style:
                  AppTypography.bodyBold.copyWith(color: palette.textPrimary)),
          const SizedBox(height: 8),
          Text(
              empty
                  ? 'В FAQ есть подсказки по GPS и ручному вводу адреса'
                  : 'Посмотрите ответы про GPS, ручной ввод адреса и ограничения по доставке',
              style:
                  AppTypography.label.copyWith(color: palette.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.open_in_new, color: palette.accent, size: 16),
            const SizedBox(width: 6),
            Flexible(
                child: Text('Открыть FAQ',
                    style: AppTypography.body.copyWith(color: palette.accent))),
          ]),
        ])),
      ]),
    );
  }
}
