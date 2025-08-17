import 'package:flutter/material.dart';
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

        print('✅ Загружено категорий: ${_superCategories.length}');
      }
    } catch (e) {
      print('❌ Ошибка загрузки категорий: $e');
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
      appBar: AppBar(
        title: const Text('Каталог'),
        centerTitle: true,
        elevation: 0,
        actions: [SearchButton()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Загрузка каталога...'),
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
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Категории не найдены',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.businessId != null
                  ? 'Для выбранного магазина нет категорий'
                  : 'Выберите магазин для просмотра каталога',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Отображаем суперкатегории и вложенные категории
    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            primary: false,
            shrinkWrap: true,
            padding: const EdgeInsets.all(0),
            itemCount: _superCategories.length,
            itemBuilder: (context, index) {
              final supercat = _superCategories[index];
              final List<Map<String, dynamic>> cats =
                  (supercat['categories'] as List<dynamic>)
                      .cast<Map<String, dynamic>>();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(supercat['name'] ?? '',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 24)),
                      ],
                    ),
                    SizedBox(height: 8),
                    GridView.builder(
                      padding: const EdgeInsets.all(0),
                      primary: false,
                      shrinkWrap: true,
                      itemCount: cats.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        print(cat);
                        return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CategoryPage(
                                    category: Category.fromJson(cat),
                                    allCategories: cats
                                        .map((c) => Category.fromJson(c))
                                        .toList(),
                                    businessId: widget.businessId,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Container(
                                    clipBehavior: Clip.antiAliasWithSaveLayer,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                    ),
                                    child: Image.network(cat['img'] ?? '',
                                        fit: BoxFit.cover, errorBuilder:
                                            (context, error, stackTrace) {
                                      return const Icon(Icons.error, size: 48);
                                    }),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(3),
                                  alignment: Alignment.center,
                                  child: Text(
                                    cat['name'] ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12),
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ));
                      },
                    ),
                  ],
                ),
              );

              // return ExpansionTile(
              //   title: Text(supercat['name'] ?? ''),
              //   children: cats.map((cat) {
              //     return ListTile(
              //       title: Text(cat['name'] ?? ''),
              //       onTap: () {
              //         // Навигация к странице категории
              //         Navigator.of(context).push(
              //           MaterialPageRoute(
              //             builder: (_) => CategoryPage(
              //               category: Category.fromJson(cat),
              //               allCategories:
              //                   cats.map((c) => Category.fromJson(c)).toList(),
              //               businessId: widget.businessId,
              //             ),
              //           ),
              //         );
              //       },
              //     );
              //   }).toList(),
              // );
            },
          ),
          SizedBox(height: 160),
        ],
      ),
    );
  }
}
