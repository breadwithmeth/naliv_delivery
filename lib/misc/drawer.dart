
// drawer: Drawer(
//               child: SafeArea(
//                 child: Column(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           vertical: 10, horizontal: 20),
//                       child: Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Row(
//                           children: [
//                             CircleAvatar(
//                               radius: MediaQuery.of(context).size.width * 0.10,
//                               backgroundImage: const CachedNetworkImageProvider(
//                                 "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg",
//                               ),
//                             ),
//                             const SizedBox(
//                               width: 10,
//                             ),
//                             // TODO: activate this code in production
//                             SizedBox(
//                               width: MediaQuery.of(context).size.width * 0.3,
//                               child: user != null
//                                   ? Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           user!["name"] ?? "Нет имени",
//                                           style: TextStyle(
//                                               color: Colors.black,
//                                               fontWeight: FontWeight.w500,
//                                               fontSize:
//                                                   32 * (screenSize / 720)),
//                                         ),
//                                         Text(
//                                           user!["login"] ?? "",
//                                           style: TextStyle(
//                                               color: Colors.black,
//                                               fontWeight: FontWeight.w400,
//                                               fontSize:
//                                                   28 * (screenSize / 720)),
//                                         ),
//                                         Text(
//                                           user!["user_id"] ?? "",
//                                           style: TextStyle(
//                                               color: Colors.grey.shade400,
//                                               fontWeight: FontWeight.w400,
//                                               fontSize:
//                                                   28 * (screenSize / 720)),
//                                         )
//                                       ],
//                                     )
//                                   : Container(),
//                             )
//                           ],
//                         ),
//                       ),
//                     ),
//                     const Divider(),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           vertical: 20, horizontal: 10),
//                       child: Column(
//                         children: [
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 Navigator.push(context, MaterialPageRoute(
//                                   builder: (context) {
//                                     return const OrderHistoryPage();
//                                   },
//                                 ));
//                               });
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.shopping_bag_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "История заказов",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 toggleDrawer();
//                               });
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                     builder: (context) => AddressesPage(
//                                           addresses: _addresses,
//                                           isExtended: true,
//                                         )),
//                               ).then((value) => print(_getAddresses()));
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.home_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Адреса доставки",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               toggleDrawer();
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.credit_card_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Карты оплаты",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.grey,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 Navigator.push(context, MaterialPageRoute(
//                                   builder: (context) {
//                                     return const FavPage();
//                                   },
//                                 ));
//                               });
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.favorite_border_rounded,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Избранное",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 Navigator.push(context, MaterialPageRoute(
//                                   builder: (context) {
//                                     return const SettingsPage();
//                                   },
//                                 ));
//                               });
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.settings_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Настройки",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 Navigator.pushReplacement(context,
//                                     MaterialPageRoute(
//                                   builder: (context) {
//                                     return PreLoadDataPage();
//                                   },
//                                 ));
//                               });
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Icon(
//                                     Icons.home_work_outlined,
//                                     size: 24,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                                 Flexible(
//                                   flex: 9,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "К выбору заведений",
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               setState(() {
//                                 Navigator.pushReplacement(context,
//                                     MaterialPageRoute(
//                                   builder: (context) {
//                                     return const SupportPage();
//                                   },
//                                 ));
//                               });
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.chat_bubble_outline_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Поддержка",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           TextButton(
//                             style: TextButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 20)),
//                             onPressed: () {
//                               showDialog(
//                                 context: context,
//                                 builder: (context) {
//                                   return AlertDialog.adaptive(
//                                     shape: const RoundedRectangleBorder(
//                                       borderRadius:
//                                           BorderRadius.all(Radius.circular(10)),
//                                     ),
//                                     title: Text(
//                                       "Вы точно хотите выйти из аккаунта?",
//                                       textAlign: TextAlign.center,
//                                       style: TextStyle(
//                                         color: Theme.of(context)
//                                             .colorScheme
//                                             .onBackground,
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                     actionsAlignment: MainAxisAlignment.center,
//                                     actions: [
//                                       Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Flexible(
//                                             child: Padding(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 5),
//                                               child: ElevatedButton(
//                                                 onPressed: () {
//                                                   logout();
//                                                   Navigator.pushAndRemoveUntil(
//                                                       context,
//                                                       MaterialPageRoute(
//                                                         builder: (context) =>
//                                                             const LoginPage(),
//                                                       ),
//                                                       (route) => false);
//                                                 },
//                                                 child: Row(
//                                                   mainAxisAlignment:
//                                                       MainAxisAlignment.center,
//                                                   children: [
//                                                     Flexible(
//                                                       child: Text(
//                                                         "Да",
//                                                         textAlign:
//                                                             TextAlign.center,
//                                                         style: TextStyle(
//                                                           color:
//                                                               Theme.of(context)
//                                                                   .colorScheme
//                                                                   .onPrimary,
//                                                           fontSize: 16,
//                                                           fontWeight:
//                                                               FontWeight.w700,
//                                                         ),
//                                                       ),
//                                                     )
//                                                   ],
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                           Flexible(
//                                             child: Padding(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 5),
//                                               child: ElevatedButton(
//                                                 onPressed: () {
//                                                   Navigator.pop(context);
//                                                 },
//                                                 child: Row(
//                                                   mainAxisAlignment:
//                                                       MainAxisAlignment.center,
//                                                   children: [
//                                                     Flexible(
//                                                       child: Text(
//                                                         "Нет",
//                                                         textAlign:
//                                                             TextAlign.center,
//                                                         style: TextStyle(
//                                                           color:
//                                                               Theme.of(context)
//                                                                   .colorScheme
//                                                                   .onPrimary,
//                                                           fontSize: 16,
//                                                           fontWeight:
//                                                               FontWeight.w700,
//                                                         ),
//                                                       ),
//                                                     )
//                                                   ],
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   );
//                                 },
//                               );
//                             },
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 const Flexible(
//                                   fit: FlexFit.tight,
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Flexible(
//                                         child: Icon(
//                                           Icons.logout_outlined,
//                                           size: 24,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Flexible(
//                                   child: SizedBox(),
//                                 ),
//                                 Flexible(
//                                   flex: 12,
//                                   fit: FlexFit.tight,
//                                   child: Text(
//                                     "Выйти",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w400,
//                                       fontSize: 40 * (screenSize / 720),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           // TextButton(
//                           //   style: TextButton.styleFrom(
//                           //       padding:
//                           //           const EdgeInsets.symmetric(horizontal: 20)),
//                           // onPressed: () {
//                           //   showDialog(
//                           //     context: context,
//                           //     builder: (context) {
//                           //       return AlertDialog.adaptive(
//                           //         shape: const RoundedRectangleBorder(
//                           //           borderRadius:
//                           //               BorderRadius.all(Radius.circular(10)),
//                           //         ),
//                           //         title: Text(
//                           //           "Вы точно хотите выйти из аккаунта?",
//                           //           textAlign: TextAlign.center,
//                           //           style: TextStyle(
//                           //             color: Theme.of(context)
//                           //                 .colorScheme
//                           //                 .onBackground,
//                           //             fontSize: 20,
//                           //             fontWeight: FontWeight.w700,
//                           //           ),
//                           //         ),
//                           //         actionsAlignment: MainAxisAlignment.center,
//                           //         actions: [
//                           //           Row(
//                           //             mainAxisAlignment:
//                           //                 MainAxisAlignment.spaceBetween,
//                           //             children: [
//                           //               Flexible(
//                           //                 child: Padding(
//                           //                   padding:
//                           //                       const EdgeInsets.symmetric(
//                           //                           horizontal: 5),
//                           //                   child: ElevatedButton(
//                           //                     onPressed: () {
//                           //                       logout();
//                           //                       Navigator.pushAndRemoveUntil(
//                           //                           context,
//                           //                           MaterialPageRoute(
//                           //                             builder: (context) =>
//                           //                                 const LoginPage(),
//                           //                           ),
//                           //                           (route) => false);
//                           //                     },
//                           //                     child: Row(
//                           //                       mainAxisAlignment:
//                           //                           MainAxisAlignment.center,
//                           //                       children: [
//                           //                         Flexible(
//                           //                           child: Text(
//                           //                             "Да",
//                           //                             textAlign:
//                           //                                 TextAlign.center,
//                           //                             style: TextStyle(
//                           //                               color:
//                           //                                   Theme.of(context)
//                           //                                       .colorScheme
//                           //                                       .onPrimary,
//                           //                               fontSize: 16,
//                           //                               fontWeight:
//                           //                                   FontWeight.w700,
//                           //                             ),
//                           //                           ),
//                           //                         )
//                           //                       ],
//                           //                     ),
//                           //                   ),
//                           //                 ),
//                           //               ),
//                           //               Flexible(
//                           //                 child: Padding(
//                           //                   padding:
//                           //                       const EdgeInsets.symmetric(
//                           //                           horizontal: 5),
//                           //                   child: ElevatedButton(
//                           //                     onPressed: () {
//                           //                       Navigator.pop(context);
//                           //                     },
//                           //                     child: Row(
//                           //                       mainAxisAlignment:
//                           //                           MainAxisAlignment.center,
//                           //                       children: [
//                           //                         Flexible(
//                           //                           child: Text(
//                           //                             "Нет",
//                           //                             textAlign:
//                           //                                 TextAlign.center,
//                           //                             style: TextStyle(
//                           //                               color:
//                           //                                   Theme.of(context)
//                           //                                       .colorScheme
//                           //                                       .onPrimary,
//                           //                               fontSize: 16,
//                           //                               fontWeight:
//                           //                                   FontWeight.w700,
//                           //                             ),
//                           //                           ),
//                           //                         )
//                           //                       ],
//                           //                     ),
//                           //                   ),
//                           //                 ),
//                           //               ),
//                           //             ],
//                           //           ),
//                           //         ],
//                           //       );
//                           //     },
//                           //   );
//                           //   // setState(() {
//                           //   //   toggleDrawer();
//                           //   // });
//                           //   // print(123);
//                           //   // logout();
//                           //   // Navigator.pushReplacement(context, MaterialPageRoute(
//                           //   //   builder: (context) {
//                           //   //     return const LoginPage();
//                           //   //   },
//                           //   // ));
//                           // },
//                           //   child: Row(
//                           //     crossAxisAlignment: CrossAxisAlignment.center,
//                           //     children: [
//                           //       const Icon(
//                           //         Icons.exit_to_app_outlined,
//                           //         size: 24,
//                           //         color: Colors.black,
//                           //       ),
//                           //       const SizedBox(
//                           //         width: 10,
//                           //       ),
//                           //       Text(
//                           //         "Выйти",
//                           //         style: TextStyle(
//                           //             color: Colors.black,
//                           //             fontWeight: FontWeight.w400,
//                           //             fontSize: 40 * (screenSize / 720)),
//                           //       )
//                           //     ],
//                           //   ),
//                           // ),
//                         ],
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),