import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/searchButton.dart';
import '../utils/api.dart';
import 'categoryPage.dart';

class Catalog extends StatefulWidget {
  final int? businessId;

  const Catalog({
    super.key,
    this.businessId,
  });

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  // Список суперкатегорий с вложенными категориями
  List<Map<String, dynamic>> _superCategories = [];
  bool _isLoading = false;
  String? _error;
  int _selectedSuperIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didUpdateWidget(Catalog oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Перезагружаем категории если изменился businessId
    if (widget.businessId != oldWidget.businessId) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Загружаем суперкатегории
      final supercats = await ApiService.getSuperCategories();

      if (mounted) {
        setState(() {
          _superCategories = supercats ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки категорий: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        centerTitle: true,
        title: const Text('Категории', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [SearchButton()],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)),
            SizedBox(height: 16),
            Text('Загрузка каталога...', style: TextStyle(color: AppColors.text)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    if (_superCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              color: AppColors.textMute,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Категории не найдены',
              style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.businessId != null ? 'Для выбранного магазина нет категорий' : 'Выберите магазин для просмотра каталога',
              style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.9), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final tabs = _superCategories;
    final selected = tabs[_selectedSuperIndex];
    final List<Map<String, dynamic>> cats = (selected['categories'] as List<dynamic>).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _superChips(tabs),
        const SizedBox(height: 12),
        _gridHeader(title: selected['name']?.toString() ?? 'Категории'),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              return _categoryTile(cat, cats);
            },
          ),
        ),
      ],
    );
  }

  Widget _superChips(List<Map<String, dynamic>> tabs) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == _selectedSuperIndex;
          final label = tabs[index]['name']?.toString() ?? 'Раздел';
          return GestureDetector(
            onTap: () {
              if (_selectedSuperIndex != index) {
                setState(() {
                  _selectedSuperIndex = index;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFF8B1F1E), AppColors.red])
                    : const LinearGradient(colors: [AppColors.card, AppColors.cardDark]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? AppColors.orange.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isSelected ? 0.32 : 0.18), blurRadius: 12, offset: const Offset(0, 8)),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _gridHeader({required String title}) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Популярно сейчас', style: TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _categoryTile(Map<String, dynamic> cat, List<Map<String, dynamic>> cats) {
    final name = cat['name']?.toString() ?? 'Категория';
    final img = cat['img']?.toString();
    final count = cat['items_count'] ?? cat['items']?.length;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryPage(
              category: Category.fromJson(cat),
              allCategories: cats.map((c) => Category.fromJson(c)).toList(),
              businessId: widget.businessId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.cardDark,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: img != null && img.isNotEmpty
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.cardDark, child: const Icon(Icons.photo, color: AppColors.textMute)),
                    )
                  : Container(color: AppColors.cardDark, child: const Icon(Icons.photo, color: AppColors.textMute)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.65)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
                  if (count != null) ...[
                    const SizedBox(height: 4),
                    Text('$count товаров', style: const TextStyle(color: AppColors.textMute, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
