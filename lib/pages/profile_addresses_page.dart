import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';
import '../widgets/address_selection_modal_material.dart';

class ProfileAddressesPage extends StatefulWidget {
  const ProfileAddressesPage({super.key});

  @override
  State<ProfileAddressesPage> createState() => _ProfileAddressesPageState();
}

class _ProfileAddressesPageState extends State<ProfileAddressesPage> {
  static const _hiddenKey = 'profile_hidden_addresses';
  static const _localKey = 'profile_local_addresses';

  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  List<Map<String, dynamic>> _serverAddresses = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _localAddresses = <Map<String, dynamic>>[];
  Set<String> _hiddenIds = <String>{};
  int _revealedCount = 0;
  String? _hidingId;
  final Set<String> _animatedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenIds = (prefs.getStringList(_hiddenKey) ?? <String>[]).toSet();
      _localAddresses = _decodeList(prefs.getStringList(_localKey) ?? <String>[]);

      final data = await ApiService.getFullInfo();
      final addresses = (data?['addresses'] as List<dynamic>? ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      setState(() {
        _serverAddresses = addresses;
        _isLoading = false;
      });
      _revealItems();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить адреса: $e';
        _isLoading = false;
      });
    }
  }

  void _revealItems() {
    final total = _visibleAddresses.length;
    _revealedCount = 0;
    for (int i = 0; i < total; i++) {
      Future.delayed(Duration(milliseconds: 60 * i), () {
        if (mounted) setState(() => _revealedCount = i + 1);
      });
    }
    Future.delayed(Duration(milliseconds: 60 * total + 100), () {
      if (mounted && _revealedCount < 999) setState(() => _revealedCount = 999);
    });
  }

  List<Map<String, dynamic>> _decodeList(List<String> raw) {
    return raw
        .map((item) {
          try {
            final decoded = json.decode(item);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
          return <String, dynamic>{};
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_localKey, _localAddresses.map(json.encode).toList());
    await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
  }

  String _idOf(Map<String, dynamic> addr) {
    return addr['id']?.toString() ??
        addr['address_id']?.toString() ??
        addr['uuid']?.toString() ??
        addr['address']?.toString() ??
        '${addr['lat']}_${addr['lon']}_${addr['address']}';
  }

  List<Map<String, dynamic>> get _visibleAddresses {
    final seen = <String>{};
    final combined = [..._localAddresses, ..._serverAddresses];
    final filtered = <Map<String, dynamic>>[];
    for (final addr in combined) {
      final id = _idOf(addr);
      if (id.isEmpty || _hiddenIds.contains(id) || seen.contains(id)) continue;
      seen.add(id);
      filtered.add(addr);
    }
    return filtered;
  }

  Future<void> _addOrEditAddress({Map<String, dynamic>? initial}) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final picked = await AddressSelectionModalHelper.show(context, initialAddress: initial);
      if (picked == null) return;
      final newAddr = {
        ...picked,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'source': initial == null ? 'profile_add' : 'profile_edit',
        'edited_from': initial != null ? _idOf(initial) : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
      if (initial != null) {
        _hiddenIds.add(_idOf(initial));
      }
      _localAddresses.insert(0, newAddr);
      await _persistLocal();
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteAddress(Map<String, dynamic> addr) async {
    if (_isMutating) return;
    final id = _idOf(addr);
    setState(() {
      _isMutating = true;
      _hidingId = id;
    });
    await Future.delayed(const Duration(milliseconds: 350));
    _hiddenIds.add(id);
    await _persistLocal();
    if (!mounted) return;
    setState(() {
      _hidingId = null;
      _isMutating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _visibleAddresses;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Мои адреса', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _isMutating ? null : () => _addOrEditAddress(),
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.orange),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)))
          else if (_error != null)
            _errorView()
          else if (addresses.isEmpty)
            _emptyView()
          else
            ListView.builder(
              padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 80.s),
              itemCount: _revealedCount.clamp(0, addresses.length),
              itemBuilder: (_, i) => _animatedAddressTile(addresses[i]),
            ),
          if (_isMutating)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.black,
        onPressed: _isMutating ? null : () => _addOrEditAddress(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить адрес'),
      ),
    );
  }

  Widget _animatedAddressTile(Map<String, dynamic> addr) {
    final id = _idOf(addr);
    final isHiding = _hidingId == id;
    final shouldAnimate = !_animatedIds.contains(id);
    _animatedIds.add(id);

    Widget child = _addressTile(addr);

    if (shouldAnimate) {
      child = TweenAnimationBuilder<double>(
        key: ValueKey('addr_$id'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, animatedChild) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(opacity: value, child: animatedChild),
          );
        },
        child: child,
      );
    }

    return KeyedSubtree(
      key: ValueKey(id),
      child: ClipRect(
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          heightFactor: isHiding ? 0.0 : 1.0,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isHiding ? 0.0 : 1.0,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _addressTile(Map<String, dynamic> addr) {
    final entrance = addr['entrance']?.toString();
    final floor = addr['floor']?.toString();
    final apartment = addr['apartment']?.toString();
    final details = [
      if (entrance != null && entrance.isNotEmpty) 'Подъезд $entrance',
      if (floor != null && floor.isNotEmpty) 'Этаж $floor',
      if (apartment != null && apartment.isNotEmpty) 'Кв. $apartment',
    ].join(' • ');

    return Container(
      margin: EdgeInsets.only(bottom: 10.s),
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.s),
                decoration: AppDecorations.pill(color: AppColors.blue),
                child: const Icon(Icons.home_rounded, color: AppColors.orange),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  addr['address']?.toString() ?? 'Адрес без названия',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            SizedBox(height: 8.s),
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700, fontSize: 12.sp),
            ),
          ],
          SizedBox(height: 10.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionButton(
                label: 'Редактировать',
                icon: Icons.edit_location_alt_rounded,
                color: AppColors.orange,
                onPressed: _isMutating ? null : () => _addOrEditAddress(initial: addr),
              ),
              SizedBox(width: 8.s),
              _actionButton(
                label: 'Скрыть',
                icon: Icons.visibility_off_outlined,
                color: AppColors.textMute,
                onPressed: _isMutating ? null : () => _deleteAddress(addr),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 8.s),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined, color: AppColors.textMute, size: 48),
            SizedBox(height: 12.s),
            const Text('Адресов пока нет', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            SizedBox(height: 6.s),
            const Text(
              'Добавьте адрес, чтобы мы могли подобрать ближайший магазин и ускорить доставку.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMute),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red),
            SizedBox(height: 12.s),
            Text(_error ?? 'Ошибка', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            SizedBox(height: 10.s),
            ElevatedButton(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.black),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
