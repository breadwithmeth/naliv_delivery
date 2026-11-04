import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/store_city.dart';
import '../ui/surfaces.dart';
import '../utils/address_storage_service.dart';
import '../utils/api.dart';

/// What the checkout address sheet asks the page to do once it closes.
enum CheckoutAddressAction { select, newOnMap, detailsDone }

class CheckoutAddressResult {
  const CheckoutAddressResult.select(this.address)
      : action = CheckoutAddressAction.select;
  const CheckoutAddressResult._(this.action) : address = null;

  /// The customer asked for a new address: the page runs the map picker.
  static const newOnMap =
      CheckoutAddressResult._(CheckoutAddressAction.newOnMap);

  /// The customer finished editing entrance, floor, flat and comment.
  static const detailsDone =
      CheckoutAddressResult._(CheckoutAddressAction.detailsDone);

  final CheckoutAddressAction action;

  /// The chosen saved address ([CheckoutAddressAction.select] only).
  final Map<String, dynamic>? address;
}

/// The street line of an address: street and house when known, else the
/// stored address text. Account addresses carry a name («Адрес доставки» by
/// default), which is never the address itself. Stored labels may carry the
/// «• Под. 2, Эт. 7, Кв. 45» summary, which has its own line.
String checkoutAddressTitle(Map<String, dynamic> address) {
  final street = ApiService.extractStreetName(address);
  if (street != null) {
    final house = ApiService.extractHouseNumber(address);
    return house == null ? street : '$street, $house';
  }
  final text = address['address']?.toString().trim();
  final label = text != null && text.isNotEmpty
      ? text
      : ApiService.extractAddressLabel(address) ??
          ApiService.formatAddressSummary(address);
  return label.split(' • ').first;
}

/// A name the customer gave the address («Дом», «Работа»); null for the
/// default «Адрес доставки» or a name that only repeats the address.
String? checkoutAddressName(Map<String, dynamic> address) {
  final name = address['name']?.toString().trim();
  if (name == null || name.isEmpty) return null;
  final lower = name.toLowerCase();
  if (lower == 'адрес доставки' ||
      lower == checkoutAddressTitle(address).toLowerCase()) {
    return null;
  }
  return name;
}

/// «Подъезд 2 · Этаж 7 · Кв. 45», empty when nothing is filled in.
String checkoutDetailsSummary(
        String entrance, String floor, String apartment) =>
    [
      if (entrance.trim().isNotEmpty) 'Подъезд ${entrance.trim()}',
      if (floor.trim().isNotEmpty) 'Этаж ${floor.trim()}',
      if (apartment.trim().isNotEmpty) 'Кв. ${apartment.trim()}',
    ].join(' · ');

/// Opens the delivery-address chooser: the current address, the customer's
/// other saved addresses, a way to add one on the map, and (for the current
/// address) the entrance / floor / flat / courier-comment form.
///
/// The form edits [entrance], [floor], [apartment] and [comment] directly, so
/// the order payload reads the same controllers it always did and nothing typed
/// is lost when the sheet is dismissed. Choosing an address or asking for a map
/// pick is reported through the [CheckoutAddressResult]; the page performs it.
Future<CheckoutAddressResult?> showCheckoutAddressSheet(
  BuildContext context, {
  required Map<String, dynamic>? current,
  required List<Map<String, dynamic>> saved,
  required String? storeCity,
  required TextEditingController entrance,
  required TextEditingController floor,
  required TextEditingController apartment,
  required TextEditingController comment,
}) =>
    showModalBottomSheet<CheckoutAddressResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _CheckoutAddressSheet(
        current: current,
        saved: saved,
        storeCity: storeCity,
        entrance: entrance,
        floor: floor,
        apartment: apartment,
        comment: comment,
      ),
    );

typedef _Entry = ({Map<String, dynamic> address, bool current});

class _CheckoutAddressSheet extends StatefulWidget {
  const _CheckoutAddressSheet({
    required this.current,
    required this.saved,
    required this.storeCity,
    required this.entrance,
    required this.floor,
    required this.apartment,
    required this.comment,
  });

  final Map<String, dynamic>? current;
  final List<Map<String, dynamic>> saved;
  final String? storeCity;
  final TextEditingController entrance;
  final TextEditingController floor;
  final TextEditingController apartment;
  final TextEditingController comment;

  @override
  State<_CheckoutAddressSheet> createState() => _CheckoutAddressSheetState();
}

class _CheckoutAddressSheetState extends State<_CheckoutAddressSheet> {
  /// Above this many other addresses the list gets a search field and a fixed
  /// height, so the actions above it never scroll away.
  static const _searchFrom = 6;

  bool _details = false;
  bool _showElsewhere = false;
  final _query = TextEditingController();

  late final List<_Entry> _entries = _buildEntries();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The same place: the same stored address, or the same street line at the
  /// same point (the current address carries edited details, so its identity
  /// and apartment may differ from the stored copy).
  static bool _same(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (AddressStorageService.sameAddress(a, b)) return true;
    final first = AddressStorageService.coordinates(a);
    final second = AddressStorageService.coordinates(b);
    return first != null &&
        first == second &&
        checkoutAddressTitle(a).toLowerCase() ==
            checkoutAddressTitle(b).toLowerCase();
  }

  /// The current address first, then every other saved address once.
  List<_Entry> _buildEntries() {
    final entries = <_Entry>[];
    final current = widget.current;
    if (current != null) entries.add((address: current, current: true));
    for (final address in widget.saved) {
      if (!entries.any((entry) => _same(entry.address, address))) {
        entries.add((address: address, current: false));
      }
    }
    return entries;
  }

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(CheckoutAddressResult.detailsDone);
  }

  void _openDetails() => setState(() => _details = true);

  void _backToList() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _details = false);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = insets > 0 ? 0.0 : MediaQuery.paddingOf(context).bottom;
    return Padding(
      key: const ValueKey('checkout-address-sheet'),
      padding: EdgeInsets.only(bottom: insets),
      child: _details ? _detailsPage(bottom) : _listPage(bottom),
    );
  }

  // ---- Address list ---------------------------------------------------------

  bool _inStoreCity(_Entry entry) =>
      addressMatchesCity(entry.address, widget.storeCity) != false;

  bool _matches(_Entry entry, String query) {
    if (query.isEmpty) return true;
    final haystack = [
      checkoutAddressTitle(entry.address),
      ApiService.formatAddressSummary(entry.address),
      ApiService.extractCityName(entry.address) ?? '',
    ].join(' ').toLowerCase();
    return query
        .split(RegExp(r'\s+'))
        .every((word) => haystack.contains(word.replaceAll(',', '')));
  }

  /// One scroll view: the title scrolls away, «Новый адрес на карте» (and the
  /// search field for a long book) stays pinned at the top, and the saved
  /// addresses are built lazily, so a book of hundreds opens instantly and the
  /// way to add an address is always one tap away, even at 2× text with the
  /// keyboard up. Addresses outside the store's city are folded into one row
  /// at the end instead of filling the list with rows that cannot be chosen.
  Widget _listPage(double bottom) {
    final palette = context.palette;
    _Entry? current;
    final others = <(int, _Entry)>[];
    for (final (index, entry) in _entries.indexed) {
      if (entry.current) {
        current = entry;
      } else {
        others.add((index, entry));
      }
    }
    final searchable = others.length >= _searchFrom;
    final query = searchable ? _query.text.trim().toLowerCase() : '';
    final inCity = [
      for (final other in others)
        if (_inStoreCity(other.$2) && _matches(other.$2, query)) other,
    ];
    final elsewhere = [
      for (final other in others)
        if (!_inStoreCity(other.$2) && _matches(other.$2, query)) other,
    ];
    final shownElsewhere = _showElsewhere || query.isNotEmpty;
    final rows = <Widget Function()>[
      if (current != null) () => _tile(current!, 0),
      if (_entries.isEmpty)
        () => Text(
              'Сохранённых адресов пока нет. Выберите точку на карте — '
              'адрес сохранится на этом устройстве.',
              key: const ValueKey('checkout-address-empty'),
              style: AppTypography.bodySmall
                  .copyWith(color: palette.textSecondary),
            ),
      if (others.isNotEmpty && !searchable)
        () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Сохранённые',
                  style: AppTypography.labelMedium
                      .copyWith(color: palette.textSecondary)),
            ),
      for (final (index, entry) in inCity) () => _tile(entry, index),
      if (elsewhere.isNotEmpty) () => _elsewhereToggle(elsewhere.length),
      if (elsewhere.isNotEmpty && shownElsewhere)
        for (final (index, entry) in elsewhere) () => _tile(entry, index),
      if (others.isNotEmpty && inCity.isEmpty && elsewhere.isEmpty)
        () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Ничего не найдено',
                  key: const ValueKey('checkout-address-no-match'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textSecondary)),
            ),
    ];
    final scroll = CustomScrollView(
      shrinkWrap: !searchable,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              header: true,
              child: Text('Адрес доставки',
                  style: AppTypography.headline
                      .copyWith(color: palette.textPrimary)),
            ),
          ),
        ),
        PinnedHeaderSliver(
          child: ColoredBox(
            color: palette.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _newAddressTile(),
                  if (searchable) ...[
                    const SizedBox(height: 8),
                    _searchField(),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: rows[index](),
            ),
          ),
        ),
      ],
    );
    if (!searchable) return scroll;
    // A long book takes a fixed share of the screen, so typing a query does not
    // make the sheet jump under the thumb.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.9
            : MediaQuery.sizeOf(context).height * 0.8,
        child: scroll,
      ),
    );
  }

  Widget _searchField() {
    final palette = context.palette;
    return TextField(
      key: const ValueKey('checkout-address-search'),
      controller: _query,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: AppTypography.bodySmall.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: 'Найти среди ${_entries.length} адресов',
        hintStyle:
            AppTypography.bodySmall.copyWith(color: palette.textSecondary),
        prefixIcon: Icon(Icons.search, color: palette.textSecondary),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить поиск',
                icon: Icon(Icons.close, color: palette.textSecondary),
                onPressed: () => setState(_query.clear),
              ),
        filled: true,
        fillColor: palette.background,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _elsewhereToggle(int count) {
    final palette = context.palette;
    final open = _showElsewhere || _query.text.trim().isNotEmpty;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const ValueKey('checkout-address-elsewhere'),
        borderRadius: AppRadii.pillAll,
        onTap: () => setState(() => _showElsewhere = !_showElsewhere),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'В других городах · $count',
                  style: AppTypography.labelMedium
                      .copyWith(color: palette.textSecondary),
                ),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  color: palette.textSecondary),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(_Entry entry, int index) {
    final palette = context.palette;
    final address = entry.address;
    final current = entry.current;
    final mismatch = addressMatchesCity(address, widget.storeCity) == false;
    final summary = current
        ? checkoutDetailsSummary(
            widget.entrance.text, widget.floor.text, widget.apartment.text)
        : checkoutDetailsSummary(
            '${address['entrance'] ?? ''}',
            '${address['floor'] ?? ''}',
            '${address['apartment'] ?? ''}',
          );
    final name = checkoutAddressName(address);
    final subtitle = mismatch
        ? 'Другой город — магазин доставляет по г. ${widget.storeCity}'
        : [
            if (name != null) name,
            if (summary.isNotEmpty)
              summary
            else if (current)
              'Добавьте подъезд, этаж и квартиру',
          ].join(' · ');
    final title = checkoutAddressTitle(address);
    final icon = mismatch
        ? Icons.wrong_location_outlined
        : current
            ? Icons.check_circle
            : Icons.location_on_outlined;
    // The current address is edited (its details); any other one is chosen. An
    // address outside the store's city stays visible but cannot be chosen.
    final VoidCallback? onTap = current
        ? _openDetails
        : mismatch
            ? null
            : () => Navigator.of(context).pop(CheckoutAddressResult.select(
                  address,
                ));
    return Opacity(
      opacity: !current && mismatch ? .6 : 1,
      child: Semantics(
        selected: current,
        child: AppSurface(
          key: ValueKey(current
              ? 'checkout-address-current'
              : 'checkout-address-saved-$index'),
          fill: current ? palette.accentFaint : palette.background,
          radius: AppRadii.xxl,
          border:
              current ? Border.all(color: palette.accent, width: 1.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(icon,
                    size: 24,
                    color: current ? palette.accent : palette.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium
                              .copyWith(color: palette.textPrimary)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: palette.textSecondary)),
                    ],
                  ),
                ),
                if (current) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_outlined,
                      size: 20, color: palette.textSecondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newAddressTile() {
    final palette = context.palette;
    return AppSurface(
      key: const ValueKey('checkout-address-new'),
      fill: palette.accentFaint,
      radius: AppRadii.xxl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => Navigator.of(context)
          .pop<CheckoutAddressResult>(CheckoutAddressResult.newOnMap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_outlined,
                size: 24, color: palette.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Новый адрес на карте',
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textPrimary)),
            ),
            Icon(Icons.chevron_right, size: 24, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  // ---- Details of the current address --------------------------------------

  Widget _detailsPage(double bottom) {
    final palette = context.palette;
    final address = widget.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('checkout-address-details-back'),
                tooltip: 'К списку адресов',
                onPressed: _backToList,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(44),
                  foregroundColor: palette.textPrimary,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Детали доставки',
                      style: AppTypography.headline
                          .copyWith(color: palette.textPrimary)),
                ),
              ),
            ],
          ),
        ),
        if (address != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(checkoutAddressTitle(address),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary)),
          ),
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final fields = [
                    _field('Подъезд', widget.entrance, 'checkout-entrance'),
                    _field('Этаж', widget.floor, 'checkout-floor'),
                    _field('Квартира', widget.apartment, 'checkout-apartment'),
                  ];
                  final stacked = constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, field) in fields.indexed) ...[
                              if (index > 0) const SizedBox(height: 12),
                              field,
                            ],
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (index, field) in fields.indexed) ...[
                              if (index > 0) const SizedBox(width: 12),
                              Expanded(child: field),
                            ],
                          ],
                        );
                }),
                const SizedBox(height: 12),
                _field(
                  'Комментарий курьеру',
                  widget.comment,
                  'checkout-comment',
                  hint: 'Например: домофон не работает, позвоните',
                  multiline: true,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottom),
          child: FilledButton(
            key: const ValueKey('checkout-address-details-done'),
            onPressed: _done,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: AppTypography.bodyMedium,
            ),
            child: const Text('Готово'),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String key, {
    String? hint,
    bool multiline = false,
  }) {
    final palette = context.palette;
    OutlineInputBorder border(Color color, [double width = 0]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: width == 0
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label,
                style: AppTypography.labelMedium
                    .copyWith(color: palette.textSecondary)),
          ),
          TextField(
            key: ValueKey(key),
            controller: controller,
            keyboardType:
                multiline ? TextInputType.multiline : TextInputType.text,
            minLines: multiline ? 2 : 1,
            maxLines: multiline ? 4 : 1,
            textInputAction:
                multiline ? TextInputAction.done : TextInputAction.next,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: AppTypography.bodySmall.copyWith(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodySmall
                  .copyWith(color: palette.textSecondary),
              filled: true,
              fillColor: palette.background,
              border: border(Colors.transparent),
              enabledBorder: border(Colors.transparent),
              disabledBorder: border(Colors.transparent),
              focusedBorder: border(palette.accent, 1.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
