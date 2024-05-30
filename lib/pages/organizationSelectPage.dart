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
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List _addresses = [];

  Map _currentAddress = {};

  Map<String, dynamic>? user;

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
        user = value;
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

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      toggleDrawer();
                    },
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: const Text("Заведения")),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: const SizedBox(),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: MediaQuery.of(context).size.width * 0.10,
                        backgroundImage: const CachedNetworkImageProvider(
                          "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg",
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      // TODO: activate this code in production
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: user != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user!["name"] ?? "Нет имени",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 32 * (screenSize / 720)),
                                  ),
                                  Text(
                                    user!["login"] ?? "",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 28 * (screenSize / 720)),
                                  ),
                                  Text(
                                    user!["user_id"] ?? "",
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 28 * (screenSize / 720)),
                                  )
                                ],
                              )
                            : Container(),
                      )
                    ],
                  ),
                ),
              ),
              const Divider(),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                child: Column(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return const OrderHistoryPage();
                            },
                          ));
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "История заказов",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          toggleDrawer();
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddressesPage(
                                    addresses: _addresses,
                                    isExtended: true,
                                  )),
                        ).then((value) => print(_getAddresses()));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.home_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Адреса доставки",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        toggleDrawer();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.credit_card_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Карты оплаты",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return const FavPage();
                            },
                          ));
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.favorite_border_rounded,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Избранное",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return const SettingsPage();
                            },
                          ));
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.settings_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Настройки",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) {
                              return const SupportPage();
                            },
                          ));
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.chat_bubble_outline_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Поддержка",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog.adaptive(
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              title: Text(
                                "Вы точно хотите выйти из аккаунта?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            logout();
                                            Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const LoginPage(),
                                                ),
                                                (route) => false);
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  "Да",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  "Нет",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                            fit: FlexFit.tight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Icon(
                                    Icons.logout_outlined,
                                    size: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SizedBox(),
                          ),
                          Flexible(
                            flex: 12,
                            fit: FlexFit.tight,
                            child: Text(
                              "Выйти",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 40 * (screenSize / 720),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemCount: 4,
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
      ),
    );
  }
}
