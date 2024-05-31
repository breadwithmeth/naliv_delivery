import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';

class OrganizationSelectPage extends StatefulWidget {
  OrganizationSelectPage(
      {super.key,
      required this.addresses,
      required this.currentAddress,
      required this.user});
  final List addresses;
  final Map currentAddress;
  final Map<String, dynamic> user;
  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage>
    with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> bars = [
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List widget.addresses = [];

  // Map currentAddress = {};

  // Map<String, dynamic> user = {};

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  // Future<void> _getAddresses() async {
  //   List addresses = await getAddresses();
  //   print(addresses);
  //   setState(() {
  //     widget.addresses = addresses;
  //     widget.currentAddress = widget.addresses.firstWhere(
  //       (element) => element["is_selected"] == "1",
  //       orElse: () {
  //         return null;
  //       },
  //     );
  //   });
  // }

  // void _getUser() async {
  //   await getUser().then((value) {
  //     setState(() {
  //       if (value != null) {
  //         user = value;
  //       }
  //     });
  //   });
  // }

  void _initData() {
    setState(() {
      // widget.currentAddress = widget.currentAddress;
      // user = widget.user;
      // widget.addresses = widget.addresses;
    });
  }

  @override
  void initState() {
    super.initState();
    // Future.delayed(Duration.zero).then((value) async {
    //   _getUser();
    // });
    // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    //   _getAddresses();
    // });
    // _initData();
  }

  ScrollController _sc = ScrollController();
  bool isCollapsed = false;
  bool isStartingToCollapse = false;
  double scrollExtent = 0;
  bool isMenuOpen = false;
  @override
  Widget build(BuildContext context) {
    const collapsedBarHeight = 100.0;
    const expandedBarHeight = 200.0;
    double screenSize = MediaQuery.of(context).size.width;

    TextStyle titleStyle = TextStyle(
      fontSize: 50 * (screenSize / 720),
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
    );

    TextStyle plainStyle = TextStyle(
      fontSize: 32 * (screenSize / 720),
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
    );

    // final scrollController = useScrollController();
    // final isCollapsed = useState(false);

    return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // if (expandedBarHeight - collapsedBarHeight <
          //     notification.metrics.atEdge) {
          //   print(true);
          // } else {
          //   print(false);
          // }
          if (notification.metrics.minScrollExtent + 200 <
              notification.metrics.pixels) {
            if (!isCollapsed) {
              setState(() {
                isCollapsed = true;
              });
            }
          } else {
            if (isCollapsed) {
              _sc.animateTo(0,
                  duration: Durations.medium1, curve: Curves.easeIn);
              setState(() {
                isCollapsed = false;
              });
            }
          }
          if (notification.metrics.minScrollExtent + 10 <
              notification.metrics.pixels) {
            if (!isStartingToCollapse) {
              _sc.animateTo(scrollExtent + collapsedBarHeight * 2,
                  duration: Durations.medium1, curve: Curves.easeIn);
              setState(() {
                isMenuOpen = false;
                isStartingToCollapse = true;
              });
            }
          } else {
            if (isStartingToCollapse) {
              setState(() {
                isStartingToCollapse = false;
              });
            }
          }

          /// 2
          // isCollapsed.value = scrollController.hasClients &&
          //     scrollController.offset >
          //         (expandedBarHeight - collapsedBarHeight);
          return false;
        },
        child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
                child: CustomScrollView(
              controller: _sc,
              slivers: <Widget>[
                SliverAppBar(
                  shadowColor: !isCollapsed
                      ? const Color(0xFFef8354)
                      : Colors.transparent,
                  backgroundColor: !isCollapsed
                      ? const Color(0xFFef8354)
                      : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  // scrolledUnderElevation: collapsedBarHeight,
                  toolbarHeight: collapsedBarHeight,
                  snap: true,
                  centerTitle: false,
                  // stretch: true,
                  // Provide a standard title.
                  // title: ,
                  pinned: true,
                  // Allows the user to reveal the app bar if they begin scrolling
                  // back up the list of items.
                  floating: true,
                  expandedHeight: 0,
                  flexibleSpace: Container(),
                  title: AnimatedSwitcher(
                      duration: Durations.medium1,
                      child: isCollapsed
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.blueGrey.shade200,
                                        offset: const Offset(5, 5),
                                        blurRadius: 5)
                                  ],
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(20))),
                              child: TextButton(
                                  onPressed: () {},
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.currentAddress["address"],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      const Icon(Icons.edit_outlined),
                                    ],
                                  )))
                          : Container(
                              alignment: Alignment.center,
                              color: const Color(0xFFef8354),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      TextButton(
                                          onPressed: () {},
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    widget.currentAddress[
                                                        "city_name"],
                                                    style: const TextStyle(
                                                        fontSize: 24,
                                                        color: Colors.white),
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_drop_down,
                                                    color: Colors.white,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )),
                                      IconButton(
                                          onPressed: () {
                                            setState(() {
                                              isMenuOpen =
                                                  isMenuOpen ? false : true;
                                            });
                                          },
                                          icon: Icon(
                                            !isMenuOpen
                                                ? Icons.menu
                                                : Icons.close,
                                            color: Colors.white,
                                          )),

                                      // IconButton(
                                      //     onPressed: () {},
                                      //     icon: Icon(Icons.settings, color: Colors.black,)),
                                    ],
                                  )
                                ],
                              ),
                            )),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      AnimatedCrossFade(
                          crossFadeState: isMenuOpen
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: Durations.medium1,
                          firstChild: Container(
                            key: ValueKey<int>(0),
                            alignment: Alignment.centerRight,
                            color: Colors.white,
                            child: Container(
                              key: ValueKey<int>(3),
                              padding: EdgeInsets.all(10),
                              margin:
                                  const EdgeInsets.only(top: 10, bottom: 10),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(30),
                                    bottomLeft: Radius.circular(30)),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TextButton(

                                      // style: ElevatedButton.styleFrom(
                                      //     backgroundColor: Colors.white,
                                      //     foregroundColor: Colors.black),
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "История заказов",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 48 *
                                                    (MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        720)),
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          Icon(Icons.list_alt)
                                        ],
                                      )),
                                  TextButton(

                                      // style: ElevatedButton.styleFrom(
                                      //     backgroundColor: Colors.white,
                                      //     foregroundColor: Colors.black),
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "Адреса доставки",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 48 *
                                                    (MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        720)),
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          Icon(Icons.list_alt)
                                        ],
                                      )),
                                  TextButton(

                                      // style: ElevatedButton.styleFrom(
                                      //     backgroundColor: Colors.white,
                                      //     foregroundColor: Colors.black),
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "Выйти",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 48 *
                                                    (MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        720)),
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          Icon(Icons.list_alt)
                                        ],
                                      ))
                                ],
                              ),
                            ),
                          ),
                          secondChild: Container(
                            key: ValueKey<int>(1),
                            color: const Color(0xFFef8354),
                          ))
                    ],
                  ),
                ),
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    if (scrollExtent == 0) {
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        setState(() {
                          scrollExtent = constraints.precedingScrollExtent;
                        });
                      });
                    }
                    return SliverToBoxAdapter(
                      child: AnimatedContainer(
                          duration: Durations.medium2,
                          color: !isStartingToCollapse
                              ? const Color(0xFFef8354)
                              : Colors.white,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              AnimatedContainer(
                                duration: Durations.medium1,
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    boxShadow: [
                                      !isStartingToCollapse
                                          ? const BoxShadow(
                                              offset: Offset(0, -10),
                                              color: Colors.black26,
                                              blurRadius: 20)
                                          : const BoxShadow(color: Colors.white)
                                    ],
                                    color: Colors.white,
                                    borderRadius: !isCollapsed
                                        ? const BorderRadius.only(
                                            topLeft: Radius.elliptical(100, 50),
                                            topRight:
                                                Radius.elliptical(100, 50))
                                        : const BorderRadius.all(Radius.zero)),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    foregroundDecoration: BoxDecoration(
                                        color: !isStartingToCollapse
                                            ? const Color(0xFFef8354)
                                                .withOpacity(0)
                                            : Colors.white),
                                    duration: Durations.medium1,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        AnimatedContainer(
                                            duration: Durations.medium1,
                                            // foregroundDecoration: BoxDecoration(color: isCollapsed ? Color(0xFFef8354) : Colors.transparent),
                                            width: double.infinity,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height /
                                                4,
                                            margin: const EdgeInsets.all(15),
                                            decoration: const BoxDecoration(
                                                // color: Colors.pinkAccent,

                                                ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Spacer(
                                                      flex: 2,
                                                    ),
                                                    CircleAvatar(
                                                      radius:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height /
                                                              16,
                                                    ),
                                                    const Spacer(),
                                                    Flexible(
                                                        flex: 3,
                                                        child: Text(
                                                          widget.user["name"],
                                                          style: const TextStyle(
                                                              fontSize: 24,
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                        )),
                                                    const Spacer(
                                                      flex: 2,
                                                    )
                                                  ],
                                                ),
                                                const Spacer(),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    TextButton(
                                                        onPressed: () {},
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: [
                                                            Text(
                                                              widget.currentAddress[
                                                                  "address"],
                                                              style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .white),
                                                            ),
                                                            const SizedBox(
                                                              width: 10,
                                                            ),
                                                            const Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ],
                                                        ))
                                                  ],
                                                ),
                                                const Spacer(
                                                  flex: 2,
                                                )
                                              ],
                                            ))
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height:
                                        MediaQuery.of(context).size.height / 5,
                                    margin: const EdgeInsets.all(15),
                                    padding: const EdgeInsets.all(30),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueGrey,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                      boxShadow: [
                                        BoxShadow(
                                            offset: Offset(0, -1),
                                            color: Colors.black26,
                                            blurRadius: 5)
                                      ],
                                    ),
                                    child: const Text(
                                        "здесь будет какой то баннер, возможно надо будет марджины везде одинаковые сделать"),
                                  )
                                ],
                              )
                            ],
                          )),
                    );
                  },
                ),
                SliverToBoxAdapter(
                    child: Container(
                  color: Colors.white,
                  child: GridView.builder(
                    primary: false,
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    itemCount: 16,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return const HomePage(); //! TOOD: Change to redirect page to a different organizations or do this right here.
                              },
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 550 * (screenSize / 720),
                          child: Column(
                            children: [
                              Flexible(
                                flex: 3,
                                fit: FlexFit.tight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Картинка бизнеса",
                                        style: plainStyle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                color: Colors.black,
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        bars[index]["name"],
                                        style: plainStyle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ))
              ],
            ))));
  }
}
