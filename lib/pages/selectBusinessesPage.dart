import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/mainPage.dart';
import 'package:naliv_delivery/shared/bonus.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';
import 'package:flutter/cupertino.dart';

class SelectBusinessesPage extends StatefulWidget {
  const SelectBusinessesPage(
      {super.key, required this.businesses, required this.currentAddress});
  final Map currentAddress;

  final List<Map> businesses;
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
    // TODO: implement initState
    super.initState();
    findBusinessWithMinDistance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: BonusWidget(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        body: Stack(
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
                              style: GoogleFonts.prostoOne(
                                fontSize: 1000,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          color: Colors.transparent,
                        ),
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15))),
                                child: Image.network(
                                  _closestBusiness["img"],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  margin: EdgeInsets.all(15),
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black,
                                            offset: Offset(0, 0),
                                            blurRadius: 10)
                                      ],
                                      color: Colors.green,
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(30))),
                                  child: Text(
                                    "Быстрая доставка",
                                    style: GoogleFonts.prostoOne(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        Divider(
                          color: Colors.transparent,
                        ),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _closestBusiness["name"],
                                    style: GoogleFonts.prostoOne(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _closestBusiness["address"],
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (double.parse(_closestBusiness[
                                                    "delivery_price"])
                                                .toInt())
                                            .toString() +
                                        "₸",
                                    style: GoogleFonts.prostoOne(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    "~" +
                                        (double.parse(_closestBusiness[
                                                    "distance"])
                                                .toInt())
                                            .toString() +
                                        "м",
                                    style: GoogleFonts.prostoOne(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ]),
                        Divider(
                          color: Colors.transparent,
                        ),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15)))),
                            onPressed: () {
                              routeToMainPage(_closestBusiness);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Продолжить",
                                  style: GoogleFonts.prostoOne(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                )
                              ],
                            )),
                        Divider(
                          color: Colors.transparent,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Другие отделения",
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down,
                                color: Colors.white),
                          ],
                        )
                      ],
                    )),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.all(30),
                    sliver: SliverList.builder(
                      itemCount: widget.businesses.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          onTap: () {
                            routeToMainPage(widget.businesses[index]);
                          },
                          trailing: Text(
                            (double.parse(widget.businesses[index]
                                            ["delivery_price"])
                                        .toInt())
                                    .toString() +
                                "₸",
                            style: GoogleFonts.prostoOne(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          contentPadding: EdgeInsets.all(0),
                          leading: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5))),
                              child: Image.network(
                                widget.businesses[index]["img"],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            widget.businesses[index]["name"],
                            style: GoogleFonts.prostoOne(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            widget.businesses[index]["address"],
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            _isLoading ? LoadingScrenn() : Container()
          ],
        ));
  }
}
