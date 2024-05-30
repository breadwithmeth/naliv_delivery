import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';

class OrganizationSelectPage extends StatefulWidget {
  const OrganizationSelectPage({super.key});

  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage> {
  List<Map<String, dynamic>> bars = [
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List _addresses = [];

  Map _currentAddress = {};

  Map<String, dynamic> user = {};

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  Future<void> _getAddresses() async {
    List addresses = await getAddresses();
    print(addresses);
    setState(() {
      _addresses = addresses;
      _currentAddress = _addresses.firstWhere(
        (element) => element["is_selected"] == "1",
        orElse: () {
          return null;
        },
      );
    });
  }

  void _getUser() async {
    await getUser().then((value) {
      setState(() {
        if (value != null) {
          user = value;
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero).then((value) async {
      _getUser();
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _getAddresses();
    });
  }

  bool isCollapsed = false;
  bool isStartingToCollapse = false;

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
          print(notification.metrics.minScrollExtent);
          print(notification.metrics.pixels);
          if (notification.metrics.minScrollExtent + 200 <
              notification.metrics.pixels) {
            print(true);
            setState(() {
              isCollapsed = true;
            });
          } else {
            setState(() {
              isCollapsed = false;
            });
          }
          if (notification.metrics.minScrollExtent + 100 <
              notification.metrics.pixels) {
            print(true);
            setState(() {
              isStartingToCollapse = true;
            });
          } else {
            setState(() {
              isStartingToCollapse = false;
            });
          }

          /// 2
          // isCollapsed.value = scrollController.hasClients &&
          //     scrollController.offset >
          //         (expandedBarHeight - collapsedBarHeight);
          return false;
        },
        child: Scaffold(
            // appBar: AppBar(
            //   // centerTitle: true,
            //   title: Row(
            //     children: [
            //       Flexible(
            //         fit: FlexFit.tight,
            //         child: Row(
            //           mainAxisAlignment: MainAxisAlignment.start,
            //           children: [
            //             IconButton(
            //               padding: EdgeInsets.zero,
            //               onPressed: () {
            //                 toggleDrawer();
            //               },
            //               icon: const Icon(Icons.menu_rounded),
            //             ),
            //           ],
            //         ),
            //       ),
            //       Flexible(
            //           flex: 3,
            //           fit: FlexFit.tight,
            //           child: Container(
            //             padding: EdgeInsets.all(5),
            //             decoration: BoxDecoration(
            //               color: Colors.amber.withOpacity(0.1),
            //               borderRadius: BorderRadius.all(Radius.circular(20))
            //             ),
            //             child: Row(
            //               mainAxisAlignment: MainAxisAlignment.center,
            //               children: [Text("Едыге би 76",  style: TextStyle(color: Colors.amberAccent,fontSize: 16, fontWeight: FontWeight.w200),)],
            //             ),
            //           )),
            //       Flexible(
            //         fit: FlexFit.tight,
            //         child: const SizedBox(),
            //       ),
            //     ],
            //   ),
            //   automaticallyImplyLeading: false,
            // ),
            // drawer: Drawer(
            //   child: SafeArea(
            //     child: Column(
            //       children: [
            //         Container(
            //           padding:
            //               const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            //           child: Padding(
            //             padding: const EdgeInsets.all(8.0),
            //             child: Row(
            //               children: [
            //                 CircleAvatar(
            //                   radius: MediaQuery.of(context).size.width * 0.10,
            //                   backgroundImage: const CachedNetworkImageProvider(
            //                     "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg",
            //                   ),
            //                 ),
            //                 const SizedBox(
            //                   width: 10,
            //                 ),
            //                 // TODO: activate this code in production
            //                 SizedBox(
            //                   width: MediaQuery.of(context).size.width * 0.3,
            //                   child: user != null
            //                       ? Column(
            //                           crossAxisAlignment: CrossAxisAlignment.start,
            //                           children: [
            //                             Text(
            //                               user!["name"] ?? "Нет имени",
            //                               style: TextStyle(
            //                                   color: Colors.black,
            //                                   fontWeight: FontWeight.w500,
            //                                   fontSize: 32 * (screenSize / 720)),
            //                             ),
            //                             Text(
            //                               user!["login"] ?? "",
            //                               style: TextStyle(
            //                                   color: Colors.black,
            //                                   fontWeight: FontWeight.w400,
            //                                   fontSize: 28 * (screenSize / 720)),
            //                             ),
            //                             Text(
            //                               user!["user_id"] ?? "",
            //                               style: TextStyle(
            //                                   color: Colors.grey.shade400,
            //                                   fontWeight: FontWeight.w400,
            //                                   fontSize: 28 * (screenSize / 720)),
            //                             )
            //                           ],
            //                         )
            //                       : Container(),
            //                 )
            //               ],
            //             ),
            //           ),
            //         ),
            //         const Divider(),
            //         Container(
            //           padding:
            //               const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            //           child: Column(
            //             children: [
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   setState(() {
            //                     Navigator.push(context, MaterialPageRoute(
            //                       builder: (context) {
            //                         return const OrderHistoryPage();
            //                       },
            //                     ));
            //                   });
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.shopping_bag_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "История заказов",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   setState(() {
            //                     toggleDrawer();
            //                   });
            //                   Navigator.push(
            //                     context,
            //                     MaterialPageRoute(
            //                         builder: (context) => AddressesPage(
            //                               addresses: _addresses,
            //                               isExtended: true,
            //                             )),
            //                   ).then((value) => print(_getAddresses()));
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.home_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Адреса доставки",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   toggleDrawer();
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.credit_card_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Карты оплаты",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.grey,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   setState(() {
            //                     Navigator.push(context, MaterialPageRoute(
            //                       builder: (context) {
            //                         return const FavPage();
            //                       },
            //                     ));
            //                   });
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.favorite_border_rounded,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Избранное",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   setState(() {
            //                     Navigator.push(context, MaterialPageRoute(
            //                       builder: (context) {
            //                         return const SettingsPage();
            //                       },
            //                     ));
            //                   });
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.settings_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Настройки",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   setState(() {
            //                     Navigator.pushReplacement(context, MaterialPageRoute(
            //                       builder: (context) {
            //                         return const SupportPage();
            //                       },
            //                     ));
            //                   });
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.chat_bubble_outline_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Поддержка",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     )
            //                   ],
            //                 ),
            //               ),
            //               const Divider(),
            //               TextButton(
            //                 style: TextButton.styleFrom(
            //                     padding: const EdgeInsets.symmetric(horizontal: 20)),
            //                 onPressed: () {
            //                   showDialog(
            //                     context: context,
            //                     builder: (context) {
            //                       return AlertDialog.adaptive(
            //                         shape: const RoundedRectangleBorder(
            //                           borderRadius:
            //                               BorderRadius.all(Radius.circular(10)),
            //                         ),
            //                         title: Text(
            //                           "Вы точно хотите выйти из аккаунта?",
            //                           textAlign: TextAlign.center,
            //                           style: TextStyle(
            //                             color: Theme.of(context)
            //                                 .colorScheme
            //                                 .onBackground,
            //                             fontSize: 20,
            //                             fontWeight: FontWeight.w700,
            //                           ),
            //                         ),
            //                         actionsAlignment: MainAxisAlignment.center,
            //                         actions: [
            //                           Row(
            //                             mainAxisAlignment:
            //                                 MainAxisAlignment.spaceBetween,
            //                             children: [
            //                               Flexible(
            //                                 child: Padding(
            //                                   padding: const EdgeInsets.symmetric(
            //                                       horizontal: 5),
            //                                   child: ElevatedButton(
            //                                     onPressed: () {
            //                                       logout();
            //                                       Navigator.pushAndRemoveUntil(
            //                                           context,
            //                                           MaterialPageRoute(
            //                                             builder: (context) =>
            //                                                 const LoginPage(),
            //                                           ),
            //                                           (route) => false);
            //                                     },
            //                                     child: Row(
            //                                       mainAxisAlignment:
            //                                           MainAxisAlignment.center,
            //                                       children: [
            //                                         Flexible(
            //                                           child: Text(
            //                                             "Да",
            //                                             textAlign: TextAlign.center,
            //                                             style: TextStyle(
            //                                               color: Theme.of(context)
            //                                                   .colorScheme
            //                                                   .onPrimary,
            //                                               fontSize: 16,
            //                                               fontWeight: FontWeight.w700,
            //                                             ),
            //                                           ),
            //                                         )
            //                                       ],
            //                                     ),
            //                                   ),
            //                                 ),
            //                               ),
            //                               Flexible(
            //                                 child: Padding(
            //                                   padding: const EdgeInsets.symmetric(
            //                                       horizontal: 5),
            //                                   child: ElevatedButton(
            //                                     onPressed: () {
            //                                       Navigator.pop(context);
            //                                     },
            //                                     child: Row(
            //                                       mainAxisAlignment:
            //                                           MainAxisAlignment.center,
            //                                       children: [
            //                                         Flexible(
            //                                           child: Text(
            //                                             "Нет",
            //                                             textAlign: TextAlign.center,
            //                                             style: TextStyle(
            //                                               color: Theme.of(context)
            //                                                   .colorScheme
            //                                                   .onPrimary,
            //                                               fontSize: 16,
            //                                               fontWeight: FontWeight.w700,
            //                                             ),
            //                                           ),
            //                                         )
            //                                       ],
            //                                     ),
            //                                   ),
            //                                 ),
            //                               ),
            //                             ],
            //                           ),
            //                         ],
            //                       );
            //                     },
            //                   );
            //                 },
            //                 child: Row(
            //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                   crossAxisAlignment: CrossAxisAlignment.center,
            //                   children: [
            //                     const Flexible(
            //                       fit: FlexFit.tight,
            //                       child: Row(
            //                         mainAxisAlignment: MainAxisAlignment.center,
            //                         children: [
            //                           Flexible(
            //                             child: Icon(
            //                               Icons.logout_outlined,
            //                               size: 24,
            //                               color: Colors.black,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     Flexible(
            //                       child: SizedBox(),
            //                     ),
            //                     Flexible(
            //                       flex: 12,
            //                       fit: FlexFit.tight,
            //                       child: Text(
            //                         "Выйти",
            //                         textAlign: TextAlign.start,
            //                         style: TextStyle(
            //                           color: Colors.black,
            //                           fontWeight: FontWeight.w400,
            //                           fontSize: 40 * (screenSize / 720),
            //                         ),
            //                       ),
            //                     ),
            //                   ],
            //                 ),
            //               ),
            //             ],
            //           ),
            //         )
            //       ],
            //     ),
            //   ),
            // ),
            backgroundColor: Colors.white,
            body: SafeArea(
                child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  shadowColor: Colors.transparent,
                  backgroundColor: !isCollapsed
                      ? Colors.blueGrey.shade100
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
                      duration: Duration(seconds: 1),
                      child: isCollapsed
                          ? Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.blueGrey.shade200,
                                        offset: Offset(5, 5),
                                        blurRadius: 5)
                                  ],
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(20))),
                              child: TextButton(
                                  onPressed: () {},
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _currentAddress["address"],
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Icon(Icons.edit_outlined),
                                    ],
                                  )))
                          : FutureBuilder(
                              future: getAddresses(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Container(
                                    alignment: Alignment.center,
                                    color: Colors.blueGrey.shade100,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            TextButton(
                                                onPressed: () {},
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          _currentAddress[
                                                              "city_name"],
                                                          style: TextStyle(
                                                              fontSize: 24),
                                                        ),
                                                        Icon(Icons
                                                            .arrow_drop_down),
                                                      ],
                                                    ),
                                                  ],
                                                )),
                                            IconButton(
                                                onPressed: () {},
                                                icon: Icon(
                                                  Icons.menu,
                                                  color: Colors.black,
                                                )),

                                            // IconButton(
                                            //     onPressed: () {},
                                            //     icon: Icon(Icons.settings, color: Colors.black,)),
                                          ],
                                        )
                                      ],
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Center();
                                }
                                return Center(
                                    child: CircularProgressIndicator());
                              },
                            )),
                  // Display a placeholder widget to visualize the shrinking size.
                  // flexibleSpace: AnimatedSwitcher(
                  //   transitionBuilder: (Widget child, Animation<double> animation) {
                  //     return ScaleTransition(scale: animation, child: child);
                  //   },
                  //   duration: Durations.extralong1,
                  //   child: !isCollapsed
                  //       ? Container(
                  //           width: double.infinity,
                  //           decoration: BoxDecoration(
                  //             color: Colors.grey.shade100,
                  //             // borderRadius:
                  //             //     BorderRadius.all(Radius.circular(20)
                  //             // )
                  //           ),
                  //           child: Stack(
                  //             children: [
                  //               Column(
                  //                 mainAxisAlignment: MainAxisAlignment.end,
                  //                 children: [],
                  //               ),
                  //               Column(
                  //                 mainAxisAlignment: MainAxisAlignment.start,
                  //                 crossAxisAlignment: CrossAxisAlignment.start,
                  //                 children: [
                  //                   Container(
                  //                     decoration: BoxDecoration(
                  //                         color: Colors.white,
                  //                         borderRadius:
                  //                             BorderRadius.all(Radius.circular(5))),
                  //                     child: Row(
                  //                       mainAxisSize: MainAxisSize.min,
                  //                       crossAxisAlignment:
                  //                           CrossAxisAlignment.center,
                  //                       children: [
                  //                         CircleAvatar(
                  //                           radius: 24,
                  //                         ),
                  //                         // Text(
                  //                         //   user!["name"] ?? "Нет имени",
                  //                         //   style: TextStyle(
                  //                         //       fontSize: 24,
                  //                         //       fontWeight: FontWeight.w500),
                  //                         // )
                  //                       ],
                  //                     ),
                  //                   ),
                  //                   Text(
                  //                     "ЗДЕСЬ БУДЕТ ЛОГОТИП",
                  //                     style: TextStyle(
                  //                         fontWeight: FontWeight.w700,
                  //                         fontSize: 24),
                  //                   ),
                  //                   Text("title"),
                  //                   Text("title"),
                  //                 ],
                  //               ),
                  //               BackdropFilter(
                  //                 filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  //                 child: Container(
                  //                   width: double.infinity,
                  //                   height: double.infinity,
                  //                 ),
                  //               )
                  //             ],
                  //           ))
                  //       : Container(),
                  // ),
                  // Make the initial height of the SliverAppBar larger than normal.
                  // collapsedHeight: collapsedBarHeight,
                ),
                SliverToBoxAdapter(
                    child: AnimatedContainer(
                        duration: Durations.extralong1,
                        color: !isStartingToCollapse
                            ? Colors.blueGrey.shade100
                            : Colors.white,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            AnimatedContainer(
                              duration: Durations.extralong1,
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    !isStartingToCollapse
                                        ? BoxShadow(
                                            offset: Offset(0, -10),
                                            color: Colors.black26,
                                            blurRadius: 20)
                                        : BoxShadow(color: Colors.white)
                                  ],
                                  color: Colors.white,
                                  borderRadius: !isCollapsed
                                      ? BorderRadius.only(
                                          topLeft: Radius.elliptical(100, 50),
                                          topRight: Radius.elliptical(100, 50))
                                      : BorderRadius.all(Radius.zero)),
                            ),
                            Column(
                              children: [
                                AnimatedContainer(
                                  foregroundDecoration: BoxDecoration(
                                      color: !isStartingToCollapse
                                          ? Colors.blueGrey.shade100
                                              .withOpacity(0)
                                          : Colors.white),
                                  duration: Durations.extralong2,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      AnimatedContainer(
                                          duration: Durations.extralong1,
                                          // foregroundDecoration: BoxDecoration(color: isCollapsed ? Colors.grey.shade100 : Colors.transparent),
                                          width: double.infinity,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height /
                                              4,
                                          margin: EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                              // color: Colors.pinkAccent,

                                              ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Spacer(
                                                    flex: 2,
                                                  ),
                                                  CircleAvatar(
                                                    radius:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height /
                                                            16,
                                                  ),
                                                  Spacer(),
                                                  Flexible(
                                                      flex: 3,
                                                      child: Text(
                                                        user["name"],
                                                        style: TextStyle(
                                                            fontSize: 24),
                                                      )),
                                                  Spacer(
                                                    flex: 2,
                                                  )
                                                ],
                                              ),
                                              Spacer(),
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
                                                            _currentAddress[
                                                                "address"],
                                                            style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700),
                                                          ),
                                                          SizedBox(
                                                            width: 10,
                                                          ),
                                                          Icon(Icons
                                                              .edit_outlined),
                                                        ],
                                                      ))
                                                ],
                                              ),
                                              Spacer(
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
                                  margin: EdgeInsets.all(15),
                                  padding: EdgeInsets.all(30),
                                  decoration: BoxDecoration(
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
                                  child: Text(
                                      "здесь будет какой то баннер, возможно надо будет марджины везде одинаковые сделать"),
                                )
                              ],
                            )
                          ],
                        ))),
                SliverToBoxAdapter(
                  child: GridView.builder(
                    primary: false,
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                )
              ],
            ))));
  }
}
