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
      // navigationBar: CupertinoNavigationBar(
      //   trailing: BonusWidget(),
      // ),
      child: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(left: 30, right: 30, top: 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          child: FittedBox(
                            child: Text(
                              "Бар-Маркеты \nНалив/Градусы24",
                              style: GoogleFonts.manrope(
                                fontSize: 1000,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  _closestBusiness["img"],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 15,
                              left: 15,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: CupertinoColors.activeGreen,
                                    borderRadius: BorderRadius.circular(15)),
                                child: Text(
                                  "Быстрая доставка",
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _closestBusiness["name"],
                                    style: GoogleFonts.manrope(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _closestBusiness["address"],
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${(double.parse(_closestBusiness["delivery_price"]).toInt())}₸",
                                    style: GoogleFonts.manrope(
                                      fontSize: 24,
                                    ),
                                  ),
                                  Text(
                                    "~${(double.parse(_closestBusiness["distance"]).toInt())}м",
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ]),
                        SizedBox(height: 16),
                        CupertinoButton.filled(
                          onPressed: () => routeToMainPage(_closestBusiness),
                          child: Text(
                            "Продолжить",
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Scroll to list
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Другие отделения",
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_down,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(30),
                  sliver: SliverList.builder(
                    itemCount: widget.businesses.length,
                    itemBuilder: (context, index) {
                      return CupertinoListTile(
                        onTap: () => routeToMainPage(widget.businesses[index]),
                        trailing: Text(
                          "${(double.parse(widget.businesses[index]["delivery_price"]).toInt())}₸",
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                          ),
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            widget.businesses[index]["img"],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          widget.businesses[index]["name"],
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                          ),
                        ),
                        subtitle: Text(
                          widget.businesses[index]["address"],
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: CupertinoColors.black.withOpacity(0.5),
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
