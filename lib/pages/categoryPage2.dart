import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/preLoadCategoryPage.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
import 'package:naliv_delivery/shared/searchWidget.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CategoryPage2 extends StatefulWidget {
  const CategoryPage2(
      {super.key,
      required this.business,
      this.categoryId,
      required this.category,
      required this.items,
      required this.subcategories,
      required this.user,
      required this.priceIncrease});
  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  final List subcategories;
  final List items;
  final bool priceIncrease;

  final Map<String, dynamic> user;

  @override
  State<CategoryPage2> createState() => _CategoryPage2State();
}

class _CategoryPage2State extends State<CategoryPage2>
    with TickerProviderStateMixin {
  // Используем ValueKey вместо GlobalObjectKey
  final List<ValueKey> keyList =
      List.generate(100, (index) => ValueKey('section_$index'));

  // Определяем контроллеры как final
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  late final TabController _tabController;

  // Кэшируем предзагруженные секции
  final List<Widget> preloadedSections = [];
  int currentIndex = 0;
  late TabController _categoryTabController;
  final List<dynamic> _tabInfoList = [];
  double currentOffset = 0;
  GlobalKey second = GlobalKey();
  double appbarheight = 120;

  List values = [];
  List properties = [];

  List? searchItems = null;
  List selectedValues = [];

  bool showFilters = false;

  int lowestPrice = 0;
  int highestPrice = 0;

  int rangeLowPrice = 0;
  int rangeHighPrice = 0;

  List items = [];

  // Добавляем контроллер для горизонтального скролла
  final ScrollController _segmentedScrollController = ScrollController();

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  //   //print("dadasdasasd");
  // }

  // @override
  // void didPopNext() {
  //   // Covering route was popped off the navigator.
  //   //print("popped");
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) {
  //       return PreLoadCategoryPage(
  //         categoryId: widget.categoryId,
  //         business: widget.business,
  //         category: widget.category,
  //         subcategories: widget.subcategories,
  //         user: widget.user,
  //       );
  //     }));
  //   });
  // }

  initPriceRange() {
    int lowestPricet = widget.items[0]["price"];
    int highestPricet = widget.items[0]["price"];
    for (var i in widget.items) {
      if (i["price"] < lowestPricet) {
        lowestPricet = i["price"];
      }
      if (i["price"] > highestPricet) {
        highestPricet = i["price"];
      }
    }

    setState(() {
      lowestPrice = lowestPricet;
      highestPrice = highestPricet;
      rangeLowPrice = lowestPricet;
      rangeHighPrice = highestPricet;
    });
  }

  _getPropertiesForCat() {
    getPropertiesForCategory(widget.categoryId!, widget.business["business_id"])
        .then((value) {
      //print(value);
      setState(() {
        values = value!["values"];
        properties = value!["properties"];
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      vsync: this,
      length: widget.subcategories.length,
      initialIndex: currentIndex,
    );

    // Предзагружаем секции после инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preloadAllSections();
        _setupScrollListener();
      }
    });

    initPriceRange();
    _getPropertiesForCat();
  }

  // Добавляем метод для предзагрузки всех секций
  void _preloadAllSections() {
    if (!mounted) return;

    setState(() {
      preloadedSections.clear(); // Очищаем старые секции

      for (int index = 0; index < widget.subcategories.length; index++) {
        List subitems = _getSubitems(index);

        if (subitems.isEmpty) {
          preloadedSections.add(SizedBox(
            key: keyList[index],
            height: 1,
          ));
          continue;
        }

        preloadedSections.add(
          Column(
            key: keyList[index],
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  widget.subcategories[index]["name"],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  key: ValueKey('grid_$index'),
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: subitems.length,
                  itemBuilder: (context, index2) => ItemCard2(
                    key: ValueKey('item_${index}_$index2'),
                    item: subitems[index2],
                    business: widget.business,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      }
    });
  }

  // Обновляем метод scrollToCategory
  void scrollToCategory(int index) {
    if (!mounted) return;

    setState(() => currentIndex = index);

    // Прокручиваем сегменты
    _scrollToSelectedSegment(index);

    // Прокручиваем список товаров
    itemScrollController.scrollTo(
      index: index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Обновляем метод _setupScrollListener
  void _setupScrollListener() {
    if (!mounted) return;

    itemPositionsListener.itemPositions.addListener(() {
      if (!mounted) return;

      final positions = itemPositionsListener.itemPositions.value.toList();
      if (positions.isEmpty) return;

      positions.sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      final firstVisibleIndex = positions.first.index;

      if (currentIndex != firstVisibleIndex && mounted) {
        setState(() {
          currentIndex = firstVisibleIndex;
          if (_tabController.index != firstVisibleIndex) {
            _tabController.animateTo(firstVisibleIndex);
            _scrollToSelectedSegment(firstVisibleIndex);
          }
        });
      }
    });
  }

  // Обновим метод _scrollToSelectedSegment
  void _scrollToSelectedSegment(int index) {
    if (!mounted) return;

    // Задержка для корректного получения размеров
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Получаем ширину экрана
      final screenWidth = MediaQuery.of(context).size.width;

      // Примерная ширина одного сегмента
      final segmentWidth = screenWidth / 3;

      // Вычисляем позицию для центрирования
      final offset =
          (segmentWidth * index) - (screenWidth / 3) + (segmentWidth / 1);

      // Безопасная анимация скролла
      if (_segmentedScrollController.hasClients) {
        _segmentedScrollController.animateTo(
          offset.clamp(0, _segmentedScrollController.position.maxScrollExtent),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _segmentedScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Убираем стандартный нижний бордер
        border: null,
        middle: Text(widget.category["c_name"]),
      ),
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Добавляем сегментированный контроль после навбара
                if (widget.subcategories.length >= 2)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          CupertinoColors.systemBackground.resolveFrom(context),
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.separator.resolveFrom(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: _segmentedScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.width / 2 - 60),
                      child: CupertinoSegmentedControl<int>(
                        selectedColor:
                            CupertinoColors.activeOrange.resolveFrom(context),
                        borderColor: CupertinoColors.transparent,
                        unselectedColor: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        onValueChanged: (index) {
                          scrollToCategory(index);
                          _scrollToSelectedSegment(index);
                        },
                        groupValue: currentIndex,
                        children: {
                          for (var i = 0; i < widget.subcategories.length; i++)
                            i: Container(
                              width: MediaQuery.of(context).size.width / 3,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                widget.subcategories[i]["name"],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                              ),
                            )
                        },
                      ),
                    ),
                  ),
                // Список товаров
                Expanded(
                  child: preloadedSections.isEmpty
                      ? Center(child: CupertinoActivityIndicator())
                      : ScrollablePositionedList.builder(
                          physics: BouncingScrollPhysics(),
                          itemScrollController: itemScrollController,
                          itemPositionsListener: itemPositionsListener,
                          itemCount: preloadedSections.length,
                          itemBuilder: (context, index) =>
                              preloadedSections[index],
                        ),
                ),
              ],
            ),
          ),
          // Кнопка корзины
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: CartButton(
              business: widget.business,
              user: {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    // return item["price"] >= rangeLowPrice && item["price"] <= rangeHighPrice
    //     ? ItemCard2(
    //         item: item,
    //         business: widget.business,
    //       )
    //     : SizedBox.shrink();
    return ItemCard2(
      item: item,
      business: widget.business,
    );
  }

  void _showSortOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _sortItems(ascending: true);
            },
            child: Text('По возрастанию цены'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _sortItems(ascending: false);
            },
            child: Text('По убыванию цены'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена'),
        ),
      ),
    );
  }

  List _getSubitems(int index) {
    return widget.items.where((item) {
      return item["category_id"].toString() ==
          widget.subcategories[index]["category_id"].toString();
    }).toList();
  }

  void _sortItems({required bool ascending}) {
    setState(() {
      items.sort((a, b) {
        if (ascending) {
          return (a["price"] as num).compareTo(b["price"] as num);
        } else {
          return (b["price"] as num).compareTo(a["price"] as num);
        }
      });
    });
  }

  Widget _buildSearchResults() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: searchItems!.length,
      itemBuilder: (context, index) => _buildItemCard(searchItems![index]),
    );
  }

  Widget _buildFiltersOverlay() {
    return Container(
      color: CupertinoColors.systemBackground,
      child: Column(
        children: [
          CupertinoNavigationBar(
            middle: Text('Фильтры'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.clear),
              onPressed: () => setState(() => showFilters = false),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Диапазон цен',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${rangeLowPrice.round()} ₸'),
                      Text('${rangeHighPrice.round()} ₸'),
                    ],
                  ),
                  CupertinoSlider(
                    min: lowestPrice.toDouble(),
                    max: highestPrice.toDouble(),
                    value: rangeHighPrice.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        rangeHighPrice = value.round();
                      });
                    },
                  ),
                  SizedBox(height: 24),
                  if (properties.isNotEmpty) ...[
                    Text(
                      'Свойства',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...properties.map((property) {
                      return _buildPropertyFilter(property);
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: CupertinoColors.separator,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: _resetFilters,
                    child: Text('Сбросить'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: _applyFilters,
                    child: Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyFilter(Map property) {
    List propertyValues = values.where((value) {
      return value["property_id"] == property["property_id"].toString();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          property["name"],
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: propertyValues.map((value) {
            bool isSelected = selectedValues.contains(value["value_id"]);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedValues.remove(value["value_id"]);
                  } else {
                    selectedValues.add(value["value_id"]);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  value["name"],
                  style: TextStyle(
                    color: isSelected
                        ? CupertinoColors.white
                        : CupertinoColors.label,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      rangeLowPrice = lowestPrice;
      rangeHighPrice = highestPrice;
      selectedValues.clear();
    });
  }

  void _applyFilters() {
    setState(() {
      showFilters = false;
      items = widget.items.where((item) {
        bool priceInRange =
            item["price"] >= rangeLowPrice && item["price"] <= rangeHighPrice;

        if (!priceInRange) return false;

        if (selectedValues.isEmpty) return true;

        return item["values"].any((value) => selectedValues.contains(value));
      }).toList();
    });
  }
}

// Добавьте этот класс для работы SliverPersistentHeader
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
