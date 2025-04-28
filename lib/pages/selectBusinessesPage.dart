import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/shared/bonus.dart';

class SelectBusinessesPage extends StatefulWidget {
  const SelectBusinessesPage(
      {super.key, required this.businesses, required this.currentAddress});

  final Map currentAddress;
  final List businesses;

  @override
  State<SelectBusinessesPage> createState() => _SelectBusinessesPageState();
}

class _SelectBusinessesPageState extends State<SelectBusinessesPage> {
  Map _closestBusiness = {};
  bool _isLoading = false;

  findBusinessWithMinDistance() {
    if (widget.businesses.isEmpty) return {};

    Map closestBusiness = widget.businesses[0];
    double minDistance = double.parse(closestBusiness["distance"]);

    for (var business in widget.businesses) {
      double distance = double.parse(business["distance"]);
      if (distance < minDistance) {
        minDistance = distance;
        closestBusiness = business;
      }
    }

    setState(() {
      _closestBusiness = closestBusiness;
    });
  }

  routeToMainPage(Map<dynamic, dynamic> business) async {
    setState(() {
      _isLoading = true;
    });
    await getUser().then((user) {
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(
          builder: (context) {
            return MainPage(
                businesses: widget.businesses,
                currentAddress: widget.currentAddress,
                user: user!,
                business: business);
          },
        ),
        (Route<dynamic> route) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    findBusinessWithMinDistance();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // enableBackgroundFilterBlur: false,
        // automaticBackgroundVisibility: false,
        middle: Text(
          'Выбор магазина',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: null,
      ),
      child: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        Container(
                          margin: EdgeInsets.only(bottom: 24),
                          child: Text(
                            "Бар-Маркеты\nНалив/Градусы24",
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),

                        // Карточка ближайшего магазина
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    CupertinoColors.systemGrey.withOpacity(0.1),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Изображение магазина
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Image.network(
                                        _closestBusiness["img"],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.activeGreen,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.time,
                                            color: CupertinoColors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "Быстрая доставка",
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Информация о магазине
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBackground
                                      .resolveFrom(context),
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _closestBusiness["name"],
                                                style: GoogleFonts.manrope(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _closestBusiness["address"],
                                                style: GoogleFonts.manrope(
                                                  fontSize: 14,
                                                  color: CupertinoColors
                                                      .systemGrey
                                                      .resolveFrom(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "${(double.parse(_closestBusiness["delivery_price"]).toInt())}₸",
                                              style: GoogleFonts.manrope(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    CupertinoColors.activeBlue,
                                              ),
                                            ),
                                            Text(
                                              "~${(double.parse(_closestBusiness["distance"]).toInt())}м",
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                color:
                                                    CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    CupertinoButton.filled(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 15),
                                      borderRadius: BorderRadius.circular(12),
                                      onPressed: () =>
                                          routeToMainPage(_closestBusiness),
                                      child: Text(
                                        "Продолжить",
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Разделитель с другими магазинами
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            children: [
                              Expanded(child: Container()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "Другие магазины",
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: CupertinoColors.systemGrey
                                        .resolveFrom(context),
                                  ),
                                ),
                              ),
                              Expanded(child: Container()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Список других магазинов
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.builder(
                    itemCount: widget.businesses.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  CupertinoColors.systemGrey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.all(12),
                          onPressed: () =>
                              routeToMainPage(widget.businesses[index]),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.businesses[index]["img"],
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.businesses[index]["name"],
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      widget.businesses[index]["address"],
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${(double.parse(widget.businesses[index]["delivery_price"]).toInt())}₸",
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.activeBlue,
                                    ),
                                  ),
                                  Text(
                                    "~${(double.parse(widget.businesses[index]["distance"]).toInt())}м",
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
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

          // Индикатор загрузки
          if (_isLoading)
            Container(
              color: CupertinoColors.black.withOpacity(0.5),
              child: Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
