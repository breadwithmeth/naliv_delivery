import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/activeOrdersButton.dart';
import 'package:naliv_delivery/misc/header.dart';
import 'package:naliv_delivery/pages/bonusesPage.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import 'package:naliv_delivery/pages/finishProfilePage.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/storePage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';

//сервис геолокации

class OrganizationSelectPage extends StatefulWidget {
  const OrganizationSelectPage(
      {super.key,
      required this.addresses,
      required this.currentAddress,
      required this.user,
      required this.businesses});
  final List addresses;
  final Map currentAddress;
  final Map<String, dynamic> user;
  final List<Map> businesses;
  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  double _lat = 0;
  double _lon = 0;
  String? _currentAddressName;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  List orders = [];

  Future<void> _getActiveOrders() async {
    List? _orders = await getActiveOrders();
    setState(() {
      orders = _orders!;
    });
  }

  late Timer periodicTimer;

  bool isExpanded = false;

  // ! TODO: TAKE THIS DATA FROM BACKEND
  List<Map> _carouselItems = [
    {
      "name": "Алкоголь",
      "image":
          "https://status-k.ru/wp-content/uploads/2021/06/alkogol-440x440.png"
    },
    {
      "name": "Восточная кухня",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Какая-то еще кухня",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Надо будет написать бэк для этого",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Потому что здесь",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "просто массив",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
  ];
  late final _controller;

  void _initData() {
    setState(() {
      print(widget.businesses);
      // widget.currentAddress = widget.currentAddress;
      // user = widget.user;
      // widget.addresses = widget.addresses;
    });
  }

  double collapsedBarHeight = 200 * globals.scaleParam;
  double expandedBarHeight = 200.0;
  _scrollListener() {
    if (_sc.position.minScrollExtent + collapsedBarHeight / 2 < _sc.offset) {
      if (!isCollapsed) {
        setState(() {
          isCollapsed = true;
        });
      }
    } else {
      if (isCollapsed) {
        // _sc.animateTo(0, duration: Durations.medium1, curve: Curves.easeIn);
        setState(() {
          isCollapsed = false;
        });
      }
    }
    if (_sc.position.minScrollExtent + 10 < _sc.offset) {
      if (!isStartingToCollapse) {
        // _sc.animateTo(scrollExtent + collapsedBarHeight * 2,
        //     duration: Durations.medium1, curve: Curves.easeIn);
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
  }

  Future<void> searchGeoData(double lon, double lat) async {
    await getGeoData(lon.toString() + "," + lat.toString()).then((value) {
      print(value);
      if (value != null) {
        List objects = value;

        double lat = objects[0]["lat"];
        double lon = objects[0]["lon"];
        if (mounted) {
          setState(() {
            _currentAddressName = objects.first["GeoObject"]["name"] ?? "";
            _lat = lat;
            _lon = lon;
          });
        }
      }
    });
  }

  Future<void> _getPosition() async {
    await determinePosition(context).then((v) {
      if (globals.addressSelectPopUpDone == false) {
        searchGeoData(v.longitude, v.latitude).then((vv) {
          if (_currentAddressName != widget.currentAddress["address"]) {
            bool isAddressAlreadyExist = false;
            for (var address in widget.addresses) {
              print(address["name"]);
              if (address["address"] == _currentAddressName) {
                isAddressAlreadyExist = true;
                showModalBottomSheet(
                  backgroundColor: Colors.white,
                  context: context,
                  builder: (context) {
                    return Container(
                      padding: EdgeInsets.all(50 * globals.scaleParam),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                    child: Text(
                                  "Изменить адрес доставки?",
                                  style: TextStyle(
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 800)
                                      ],
                                      fontSize: 76 * globals.scaleParam,
                                      color: Colors.black),
                                )),
                                SizedBox(
                                  height: 10 * globals.scaleParam,
                                ),
                                Flexible(
                                    child: Text(
                                  _currentAddressName!,
                                  style: TextStyle(
                                      fontVariations: <FontVariation>[
                                        FontVariation('wght', 600)
                                      ],
                                      fontSize: 48 * globals.scaleParam,
                                      color: Colors.black),
                                )),
                                SizedBox(
                                  height: 10 * globals.scaleParam,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Подъезд/Вход: ",
                                        style: TextStyle(
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 600)
                                            ],
                                            fontSize: 32 * globals.scaleParam),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["entrance"] ?? "-",
                                        style: TextStyle(
                                            fontVariations: <FontVariation>[
                                              FontVariation('wght', 600)
                                            ],
                                            fontSize: 32 * globals.scaleParam),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Этаж: ",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["floor"] ?? "-",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Квартира/Офис: ",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["apartment"] ?? "-",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        address["other"] ?? "-",
                                        style: TextStyle(
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 600)
                                          ],
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.tealAccent.shade700,
                                      padding: EdgeInsets.all(
                                          20 * globals.scaleParam)),
                                  onPressed: () {
                                    selectAddressClient(address["address_id"],
                                            widget.user["user_id"])
                                        .then((q) {
                                      Navigator.pushAndRemoveUntil(context,
                                          MaterialPageRoute(
                                        builder: (context) {
                                          return PreLoadDataPage(
                                              // business: widget.business,
                                              // client: widget.client,
                                              // customAddress: _addresses[index],
                                              );
                                        },
                                      ), (Route<dynamic> route) => false);
                                    });
                                  },
                                  icon: Icon(
                                    Icons.done_sharp,
                                    size: 76 * globals.scaleParam,
                                    color: Colors.white,
                                  )),
                              SizedBox(
                                height: 10 * globals.scaleParam,
                              ),
                              IconButton(
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.redAccent.shade700,
                                      padding: EdgeInsets.all(
                                          20 * globals.scaleParam)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: Icon(
                                    Icons.close_sharp,
                                    size: 76 * globals.scaleParam,
                                    color: Colors.white,
                                  )),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              }
            }
            if (!isAddressAlreadyExist) {
              showModalBottomSheet(
                backgroundColor: Colors.white,
                context: context,
                builder: (context) {
                  return Container(
                    padding: EdgeInsets.all(50 * globals.scaleParam),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                  child: Text(
                                "Изменить адрес доставки?",
                                style: TextStyle(
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 800)
                                    ],
                                    fontSize: 76 * globals.scaleParam,
                                    color: Colors.black),
                              )),
                              SizedBox(
                                height: 10 * globals.scaleParam,
                              ),
                              Flexible(
                                  child: Text(
                                _currentAddressName!,
                                style: TextStyle(
                                    fontVariations: <FontVariation>[
                                      FontVariation('wght', 600)
                                    ],
                                    fontSize: 48 * globals.scaleParam,
                                    color: Colors.black),
                              )),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.tealAccent.shade700,
                                    padding: EdgeInsets.all(
                                        20 * globals.scaleParam)),
                                onPressed: () {
                                  globals.addressSelectPopUpDone = true;

                                  showModalBottomSheet(
                                    backgroundColor: Colors.white,
                                    barrierColor: Colors.black45,
                                    isScrollControlled: true,
                                    context: context,
                                    useSafeArea: true,
                                    builder: (context) {
                                      return CreateAddressPage(
                                        lat: _lat,
                                        lon: _lon,
                                        addressName: _currentAddressName!,
                                        isFromCreateOrder: false,
                                      );
                                    },
                                  );
                                },
                                icon: Icon(
                                  Icons.done_sharp,
                                  size: 76 * globals.scaleParam,
                                  color: Colors.white,
                                )),
                            SizedBox(
                              height: 10 * globals.scaleParam,
                            ),
                            IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent.shade700,
                                    padding: EdgeInsets.all(
                                        20 * globals.scaleParam)),
                                onPressed: () {
                                  globals.addressSelectPopUpDone = true;
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  Icons.close_sharp,
                                  size: 76 * globals.scaleParam,
                                  color: Colors.white,
                                )),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            }
          } else {}
        });
      }
    });
  }

  bool hasSecondLine(String text, TextStyle style, double maxWidth) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1, // You can set this to any number of lines you want to check.
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }

  String _debugLabelString = "";
  String? _emailAddress;
  String? _smsNumber;
  String? _externalUserId;
  String? _language;
  String? _liveActivityId;
  bool _enableConsentButton = false;
  bool _requireConsent = true;

  double newAppBarHeight = 0;

  Future<void> initPlatformState() async {
    if (!mounted) return;

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    OneSignal.consentRequired(_requireConsent);

    // NOTE: Replace with your own app ID from https://www.onesignal.com
    OneSignal.initialize("f9a3bf44-4a96-4859-99a9-37aa2b579577");

    OneSignal.LiveActivities.setupDefault();
    // OneSignal.LiveActivities.setupDefault(options: new LiveActivitySetupOptions(enablePushToStart: false, enablePushToUpdate: true));

    // AndroidOnly stat only
    // OneSignal.Notifications.removeNotification(1);
    // OneSignal.Notifications.removeGroupedNotifications("group5");

    OneSignal.Notifications.clearAll();

    OneSignal.User.pushSubscription.addObserver((state) {
      print(OneSignal.User.pushSubscription.optedIn);
      print(OneSignal.User.pushSubscription.id);
      print(OneSignal.User.pushSubscription.token);

      print(state.current.jsonRepresentation());
    });

    OneSignal.User.addObserver((state) {
      var userState = state.jsonRepresentation();
      print('OneSignal user changed: $userState');
    });

    OneSignal.Notifications.addPermissionObserver((state) {
      print("Has permission " + state.toString());
    });

    OneSignal.Notifications.addClickListener((event) {
      print('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
      this.setState(() {
        _debugLabelString =
            "Clicked notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print(
          'NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}');

      /// Display Notification, preventDefault to not display
      event.preventDefault();

      /// Do async work

      /// notification.display() to display after preventing default
      event.notification.display();

      this.setState(() {
        _debugLabelString =
            "Notification received in foreground notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });

    OneSignal.InAppMessages.addClickListener((event) {
      this.setState(() {
        _debugLabelString =
            "In App Message Clicked: \n${event.result.jsonRepresentation().replaceAll("\\n", "\n")}";
      });
    });
    OneSignal.InAppMessages.addWillDisplayListener((event) {
      print("ON WILL DISPLAY IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addDidDisplayListener((event) {
      print("ON DID DISPLAY IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addWillDismissListener((event) {
      print("ON WILL DISMISS IN APP MESSAGE ${event.message.messageId}");
    });
    OneSignal.InAppMessages.addDidDismissListener((event) {
      print("ON DID DISMISS IN APP MESSAGE ${event.message.messageId}");
    });

    this.setState(() {
      _enableConsentButton = _requireConsent;
    });

    // Some examples of how to use In App Messaging public methods with OneSignal SDK
    oneSignalInAppMessagingTriggerExamples();

    // Some examples of how to use Outcome Events public methods with OneSignal SDK
    oneSignalOutcomeExamples();

    OneSignal.InAppMessages.paused(true);
  }

  void _handleSendTags() {
    print("Sending tags");
    OneSignal.User.addTagWithKey("test2", "val2");

    print("Sending tags array");
    var sendTags = {'test': 'value', 'test2': 'value2'};
    OneSignal.User.addTags(sendTags);
  }

  void _handleRemoveTag() {
    print("Deleting tag");
    OneSignal.User.removeTag("test2");

    print("Deleting tags array");
    OneSignal.User.removeTags(['test']);
  }

  void _handleGetTags() async {
    print("Get tags");

    var tags = await OneSignal.User.getTags();
    print(tags);
  }

  void _handlePromptForPushPermission() {
    print("Prompting for Permission");
    OneSignal.Notifications.requestPermission(true);
  }

  void _handleSetLanguage() {
    if (_language == null) return;
    print("Setting language");
    OneSignal.User.setLanguage(_language!);
  }

  void _handleSetEmail() {
    if (_emailAddress == null) return;
    print("Setting email");

    OneSignal.User.addEmail(_emailAddress!);
  }

  void _handleRemoveEmail() {
    if (_emailAddress == null) return;
    print("Remove email");

    OneSignal.User.removeEmail(_emailAddress!);
  }

  void _handleSetSMSNumber() {
    if (_smsNumber == null) return;
    print("Setting SMS Number");

    OneSignal.User.addSms(_smsNumber!);
  }

  void _handleRemoveSMSNumber() {
    if (_smsNumber == null) return;
    print("Remove smsNumber");

    OneSignal.User.removeSms(_smsNumber!);
  }

  void _handleConsent() {
    print("Setting consent to true");
    OneSignal.consentGiven(true);

    print("Setting state");
    this.setState(() {
      _enableConsentButton = false;
    });
  }

  void _handleSetLocationShared() {
    print("Setting location shared to true");
    OneSignal.Location.setShared(true);
  }

  void _handleGetExternalId() async {
    var externalId = await OneSignal.User.getExternalId();
    print('External ID: $externalId');
  }

  void _handleLogin() {
    print("Setting external user ID");
    if (_externalUserId == null) return;
    OneSignal.login(_externalUserId!);
  }

  void _handleLogout() {
    OneSignal.logout();
    OneSignal.User.removeAlias("fb_id");
  }

  Future<String?> _handleGetOnesignalId() async {
    String? onesignalId = await OneSignal.User.getOnesignalId();
    print('OneSignal ID: $onesignalId');
    return onesignalId;
  }

  oneSignalInAppMessagingTriggerExamples() async {
    /// Example addTrigger call for IAM
    /// This will add 1 trigger so if there are any IAM satisfying it, it
    /// will be shown to the user
    OneSignal.InAppMessages.addTrigger("trigger_1", "one");

    /// Example addTriggers call for IAM
    /// This will add 2 triggers so if there are any IAM satisfying these, they
    /// will be shown to the user
    Map<String, String> triggers = new Map<String, String>();
    triggers["trigger_2"] = "two";
    triggers["trigger_3"] = "three";
    OneSignal.InAppMessages.addTriggers(triggers);

    // Removes a trigger by its key so if any future IAM are pulled with
    // these triggers they will not be shown until the trigger is added back
    OneSignal.InAppMessages.removeTrigger("trigger_2");

    // Create a list and bulk remove triggers based on keys supplied
    List<String> keys = ["trigger_1", "trigger_3"];
    OneSignal.InAppMessages.removeTriggers(keys);

    // Toggle pausing (displaying or not) of IAMs
    OneSignal.InAppMessages.paused(true);
    var arePaused = await OneSignal.InAppMessages.arePaused();
    print('Notifications paused $arePaused');
  }

  oneSignalOutcomeExamples() async {
    OneSignal.Session.addOutcome("normal_1");
    OneSignal.Session.addOutcome("normal_2");

    OneSignal.Session.addUniqueOutcome("unique_1");
    OneSignal.Session.addUniqueOutcome("unique_2");

    OneSignal.Session.addOutcomeWithValue("value_1", 3.2);
    OneSignal.Session.addOutcomeWithValue("value_2", 3.9);
  }

  void _handleOptIn() {
    OneSignal.User.pushSubscription.optIn();
  }

  void _handleOptOut() {
    OneSignal.User.pushSubscription.optOut();
  }

  void _handleStartDefaultLiveActivity() {
    if (_liveActivityId == null) return;
    print("Starting default live activity");
    OneSignal.LiveActivities.startDefault(_liveActivityId!, {
      "title": "Welcome!"
    }, {
      "message": {"en": "Hello World!"},
      "intValue": 3,
      "doubleValue": 3.14,
      "boolValue": true
    });
  }

  void _handleEnterLiveActivity() {
    if (_liveActivityId == null) return;
    print("Entering live activity");
    OneSignal.LiveActivities.enterLiveActivity(_liveActivityId!, "FAKE_TOKEN");
  }

  void _handleExitLiveActivity() {
    if (_liveActivityId == null) return;
    print("Exiting live activity");
    OneSignal.LiveActivities.exitLiveActivity(_liveActivityId!);
  }

  void _handleSetPushToStartLiveActivity() {
    if (_liveActivityId == null) return;
    print("Setting Push-To-Start live activity");
    OneSignal.LiveActivities.setPushToStartToken(
        _liveActivityId!, "FAKE_TOKEN");
  }

  void _handleRemovePushToStartLiveActivity() {
    if (_liveActivityId == null) return;
    print("Setting Push-To-Start live activity");
    OneSignal.LiveActivities.removePushToStartToken(_liveActivityId!);
  }

  Future<void> startDialogWelcome() async {
    await Future.delayed(const Duration(seconds: 15), () async {
      _handleConsent();
      _handlePromptForPushPermission();
      _handleGetOnesignalId();
      _handleOptIn();
      _handleLogin();
      initPlatformState();
      OneSignal.User.pushSubscription.optIn();

      await Future.delayed(const Duration(seconds: 15), () async {
        await _handleGetOnesignalId().then((v) {
          setEID();
          initExternalId();
        });
      });
    });
  }

  setEID() async {
    setState(() async {
      _externalUserId = await getToken();
    });
  }

  @override
  void initState() {
    super.initState();
    // Permission.notification.request();
    startDialogWelcome();
    print(widget.businesses);
    initPlatformState();
    _handleGetOnesignalId();
    _sc.addListener(_scrollListener);
    // periodicTimer = Timer.periodic(
    //   const Duration(seconds: 10),
    //   (timer) {
    //     _getActiveOrders();
    //   },
    // );
    // _getPosition();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      OneSignal.InAppMessages.paused(false);
      // OneSignal.InAppMessages.removeTrigger("regbonus");
      OneSignal.InAppMessages.addTrigger("regbonus", "true");
      if (widget.user["name"].toString().isEmpty) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
          builder: (context) {
            Map<String, dynamic> user = widget.user;
            return Finishprofilepage(user: user);
          },
        ), (route) => false);
      }
    });
    // initExternalId();
    // _initData();
  }

  @override
  void dispose() {
    // Remove a callback to receive data sent from the TaskHandler.
    super.dispose();
  }

  initExternalId() async {
    await OneSignal.User.getOnesignalId().then(
      (value) {
        print("=========================");
        print(value);
        setIdOneSignal(value!);
      },
    );
  }

  setHeight(double height) {
    setState(() {
      newAppBarHeight = height;
    });
  }

  ScrollController _sc = ScrollController();
  bool isCollapsed = false;
  bool isStartingToCollapse = false;
  double scrollExtent = 0;
  bool isMenuOpen = false;
  final GlobalKey<ScaffoldState> _key = GlobalKey(
      debugLabel:
          "вот это ключ, всем ключам ключ, надеюсь он тут не потеряется"); // lol, за что он отвечает?
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // TextStyle titleStyle = TextStyle(
    //   fontSize: 50 * globals.scaleParam,
    //   fontVariations: <FontVariation>[FontVariation('wght', 600)],
    //   color: Theme.of(context).colorScheme.onSurface,
    // );

    // TextStyle plainStyle = TextStyle(
    //   fontSize: 32 * globals.scaleParam,
    //   fontVariations: <FontVariation>[FontVariation('wght', 600)],
    //   color: Theme.of(context).colorScheme.onSurface,
    // );

    // final scrollController = useScrollController();
    // final isCollapsed = useState(false);

    return Scaffold(
      key: _key,
      drawerEnableOpenDragGesture: false,
      drawerScrimColor: Colors.white,
      bottomSheet: context.mounted ? BottomBar() : Container(),
      endDrawer: SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        _key.currentState!.closeEndDrawer();
                      },
                      icon: Container(
                        padding: EdgeInsets.all(20 * globals.scaleParam),
                        child: Icon(
                          Icons.close,
                          size: 48 * globals.scaleParam,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                fit: FlexFit.tight,
                child: Container(
                  alignment: Alignment.center,
                  height: 275 * globals.scaleParam,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "НАЛИВ/ГРАДУСЫ24",
                          // "закажи",
                          style: TextStyle(fontVariations: <FontVariation>[
                            FontVariation('wght', 800)
                          ], fontSize: 72 * globals.scaleParam),
                        ),
                      ),
                      // Icon(
                      //   Icons.local_dining_outlined,
                      //   color: Colors.black,
                      //   size: 48 * globals.scaleParam,
                      // )
                    ],
                  ),
                ),
              ),
              Flexible(
                flex: 8,
                fit: FlexFit.tight,
                child: GridView.count(
                  padding: EdgeInsets.all(
                      MediaQuery.of(context).size.aspectRatio > 1
                          ? 50
                          : 20 * globals.scaleParam),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2 / 1,
                  crossAxisCount:
                      MediaQuery.of(context).size.aspectRatio > 1 ? 4 : 2,
                  children: [
                    const DrawerMenuItem(
                      name: "История заказов",
                      icon: Icons.book_outlined,
                      route: OrderHistoryPage(),
                    ),
                    DrawerMenuItem(
                      name: "Адреса доставки",
                      icon: Icons.map_outlined,
                      route: PickAddressPage(
                        client: widget.user,
                        addresses: widget.addresses,
                        fromDrawer: true,
                      ),
                    ),
                    DrawerMenuItem(
                      name: "Поддержка",
                      icon: Icons.support_agent_rounded,
                      route: SupportPage(
                        user: widget.user,
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Бонусы",
                      icon: Icons.card_membership_rounded,
                      route: BonusesPage(),
                    ),
                    const DrawerMenuItem(
                      name: "Оферта",
                      icon: Icons.list_alt,
                      route: OfferPage(
                        path: "assets/agreements/offer.md",
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Управление аккаунтом",
                      icon: Icons.settings_outlined,
                      route: SettingsPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      // !isCollapsed ?      globals.mainColor : Colors.white,
      body: SafeArea(
          maintainBottomViewPadding: false,
          bottom: false,
          top: true,
          child: CustomScrollView(
            controller: _sc,
            slivers: <Widget>[
              // AdaptiveHeightSliverPersistentHeader(
              //     needRepaint: true,
              //     floating: true,
              //     pinned: true,
              //     child: Stack(
              //       clipBehavior: Clip.none,
              //       children: [
              //         GestureDetector(
              //           onTap: () {},
              //           child: Container(
              //             clipBehavior: Clip.antiAlias,
              //             decoration: BoxDecoration(
              //               color: Colors.black,
              //               borderRadius: BorderRadius.only(
              //                 bottomLeft: Radius.circular(15),
              //                 bottomRight: Radius.circular(15),
              //               ),
              //             ),
              //             child: Container(
              //                 child: Container(
              //               padding: EdgeInsets.only(
              //                   top: MediaQuery.of(context).viewPadding.top,
              //                   bottom: 10 * globals.scaleParam),
              //               child: Row(
              //                 mainAxisAlignment: MainAxisAlignment.center,
              //                 children: [
              //                   Flexible(
              //                     child: Container(),
              //                   ),
              //                   Flexible(
              //                       flex: 3,
              //                       child: Column(
              //                         mainAxisAlignment:
              //                             MainAxisAlignment.center,
              //                         crossAxisAlignment:
              //                             CrossAxisAlignment.center,
              //                         children: [
              //                           Text(
              //                             widget.currentAddress["city_name"] ??
              //                                 "",
              //                             textAlign: TextAlign.start,
              //                             style: TextStyle(
              //                               fontVariations: <FontVariation>[
              //                                 FontVariation('wght', 700)
              //                               ],
              //                               fontSize: 36 * globals.scaleParam,
              //                               color: Colors.white,
              //                               height: 1.1,
              //                             ),
              //                           ),
              //                           Text(
              //                             widget.currentAddress.isNotEmpty
              //                                 ? widget.currentAddress["address"]
              //                                 : "Нет адреса",
              //                             style: TextStyle(
              //                               color: Colors.white,
              //                               fontVariations: <FontVariation>[
              //                                 FontVariation('wght', 600)
              //                               ],
              //                             ),
              //                           )
              //                         ],
              //                       )),
              //                   Flexible(
              //                       fit: FlexFit.tight,
              //                       child: LayoutBuilder(
              //                           builder: (context, constraints) {
              //                         WidgetsBinding.instance
              //                             .addPostFrameCallback((_) {
              //                           setHeight(context.size?.height ?? 0);
              //                         });
              //                         return Row(
              //                           mainAxisAlignment:
              //                               MainAxisAlignment.end,
              //                           children: [
              //                             IconButton(
              //                               onPressed: () {
              //                                 print(newAppBarHeight);
              //                                 // _key.currentState!.openEndDrawer();
              //                               },
              //                               icon: Icon(
              //                                 Icons.menu,
              //                                 size: 48 * globals.scaleParam,
              //                                 color: Colors.white,
              //                               ),
              //                             )
              //                           ],
              //                         );
              //                       })),
              //                 ],
              //               ),
              //             )),
              //           ),
              //         ),
              //         // Positioned(
              //         //     top: newAppBarHeight + 0,
              //         //     width: MediaQuery.of(context).size.width * 0.7,
              //         //     child: ActiveOrdersButton()),
              //       ],
              //     )),
              SliverAppBar(
                actions: [Container()],
                automaticallyImplyLeading: false,
                elevation: 0,
                forceElevated: true,
                shape: const LinearBorder(bottom: LinearBorderEdge(size: 1)),
                shadowColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.transparent,
                // scrolledUnderElevation: collapsedBarHeight,
                toolbarHeight: collapsedBarHeight,
                snap: true,
                centerTitle: false,
                titleSpacing: 0,
                // stretch: true,
                // Provide a standard title.
                // title: ,
                pinned: true,
                // Allows the user to reveal the app bar if they begin scrolling
                // back up the list of items.
                floating: true,
                expandedHeight: 0,
                // flexibleSpace: Container(),
                title: AnimatedSwitcher(
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, -1),
                                end: const Offset(0, -0.1))
                            .animate(animation),
                        child: child,
                      );
                    },
                    duration: Durations.medium1,
                    child: isCollapsed
                        ? Container(
                            key: ValueKey(isCollapsed),
                            height: 160 * globals.scaleParam,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20 * globals.scaleParam),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(20)),
                              // color: Colors.amber,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) {
                                          return PickAddressPage(
                                            client: widget.user,
                                            addresses: widget.addresses,
                                          );
                                        },
                                      ));
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          top: 10 * globals.scaleParam),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(15)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 3,
                                            offset: Offset(-0.5, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.15,
                                                child: Icon(
                                                  Icons.location_on_rounded,
                                                  size: 48 * globals.scaleParam,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.7,
                                                child: LayoutBuilder(
                                                  builder:
                                                      (context, constraints2) {
                                                    double cityNameHeight =
                                                        constraints.maxHeight *
                                                            0.5;
                                                    double addressNameHeight =
                                                        constraints.maxHeight *
                                                            0.5;
                                                    if (hasSecondLine(
                                                        widget.currentAddress
                                                                .isNotEmpty
                                                            ? widget.currentAddress[
                                                                "address"]
                                                            : "Нет адреса",
                                                        TextStyle(
                                                          fontSize: 32 *
                                                              globals
                                                                  .scaleParam,
                                                          fontVariations: <FontVariation>[
                                                            FontVariation(
                                                                'wght', 600)
                                                          ],
                                                          color: isCollapsed
                                                              ? Colors.white
                                                              : Colors
                                                                  .transparent,
                                                          height: 1.1,
                                                        ),
                                                        constraints.maxWidth *
                                                            0.7)) {
                                                      cityNameHeight =
                                                          constraints
                                                                  .maxHeight *
                                                              0.42;
                                                      addressNameHeight =
                                                          constraints
                                                                  .maxHeight *
                                                              0.58;
                                                    }

                                                    // return Container(
                                                    // width: constraints.maxWidth * 0.7,
                                                    //   color: Colors.red,
                                                    // );

                                                    return Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          height:
                                                              cityNameHeight,
                                                          alignment: Alignment
                                                              .bottomLeft,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  widget.currentAddress[
                                                                          "city_name"] ??
                                                                      "",
                                                                  textAlign:
                                                                      TextAlign
                                                                          .start,
                                                                  style:
                                                                      TextStyle(
                                                                    fontVariations: <FontVariation>[
                                                                      FontVariation(
                                                                          'wght',
                                                                          700)
                                                                    ],
                                                                    fontSize: 36 *
                                                                        globals
                                                                            .scaleParam,
                                                                    color: Colors
                                                                        .white,
                                                                    height: 1.1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              addressNameHeight,
                                                          alignment:
                                                              Alignment.topLeft,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  widget.currentAddress
                                                                          .isNotEmpty
                                                                      ? widget.currentAddress[
                                                                          "address"]
                                                                      : "Нет адреса",
                                                                  style:
                                                                      TextStyle(
                                                                    fontFamily:
                                                                        "Raleway",
                                                                    fontSize: 32 *
                                                                        globals
                                                                            .scaleParam,
                                                                    fontVariations: <FontVariation>[
                                                                      FontVariation(
                                                                          'wght',
                                                                          600)
                                                                    ],
                                                                    color: isCollapsed
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .transparent,
                                                                    height: 1.1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.15,
                                                child: const Icon(
                                                  Icons.arrow_drop_down,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(
                                  flex: 3,
                                )
                              ],
                            ),
                          )
                        : Container(
                            height: 160 * globals.scaleParam,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20 * globals.scaleParam),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      // backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(15)),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) {
                                          return PickAddressPage(
                                            client: widget.user,
                                            addresses: widget.addresses,
                                          );
                                        },
                                      ));
                                    },
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SizedBox(
                                          height: 160 * globals.scaleParam,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.15,
                                                child: Icon(
                                                  Icons.location_on_rounded,
                                                  size: 48 * globals.scaleParam,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.7,
                                                child: LayoutBuilder(
                                                  builder:
                                                      (context, constraints2) {
                                                    double cityNameHeight =
                                                        constraints.maxHeight *
                                                            0.5;
                                                    double addressNameHeight =
                                                        constraints.maxHeight *
                                                            0.5;
                                                    if (hasSecondLine(
                                                        widget.currentAddress
                                                                .isNotEmpty
                                                            ? widget.currentAddress[
                                                                "address"]
                                                            : "Нет адреса",
                                                        TextStyle(
                                                          fontSize: 32 *
                                                              globals
                                                                  .scaleParam,
                                                          fontVariations: <FontVariation>[
                                                            FontVariation(
                                                                'wght', 700)
                                                          ],
                                                          color: isCollapsed
                                                              ? Colors.white
                                                              : Colors
                                                                  .transparent,
                                                          height: 1.1,
                                                        ),
                                                        constraints.maxWidth *
                                                            0.7)) {
                                                      cityNameHeight =
                                                          constraints
                                                                  .maxHeight *
                                                              0.42;
                                                      addressNameHeight =
                                                          constraints
                                                                  .maxHeight *
                                                              0.58;
                                                    }

                                                    // return Container(
                                                    // width: constraints.maxWidth * 0.7,
                                                    //   color: Colors.red,
                                                    // );

                                                    return Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          height:
                                                              cityNameHeight,
                                                          alignment: Alignment
                                                              .bottomLeft,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  widget.currentAddress[
                                                                          "city_name"] ??
                                                                      "",
                                                                  textAlign:
                                                                      TextAlign
                                                                          .start,
                                                                  style:
                                                                      TextStyle(
                                                                    fontVariations: <FontVariation>[
                                                                      FontVariation(
                                                                          'wght',
                                                                          700)
                                                                    ],
                                                                    fontSize: 36 *
                                                                        globals
                                                                            .scaleParam,
                                                                    color: Colors
                                                                        .black,
                                                                    height: 1.1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              addressNameHeight,
                                                          alignment:
                                                              Alignment.topLeft,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  widget.currentAddress
                                                                          .isNotEmpty
                                                                      ? widget.currentAddress[
                                                                          "address"]
                                                                      : "Нет адреса",
                                                                  style:
                                                                      TextStyle(
                                                                    fontFamily:
                                                                        "Raleway",
                                                                    fontSize: 32 *
                                                                        globals
                                                                            .scaleParam,
                                                                    fontVariations: <FontVariation>[
                                                                      FontVariation(
                                                                          'wght',
                                                                          600)
                                                                    ],
                                                                    color: !isCollapsed
                                                                        ? Colors
                                                                            .black
                                                                        : Colors
                                                                            .transparent,
                                                                    height: 1.1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    constraints.maxWidth * 0.15,
                                                child: const Icon(
                                                  Icons.arrow_drop_down,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Expanded(
                                //   flex: 3,
                                //   child: SizedBox(),
                                // ),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: IconButton(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) {
                                          return BonusesPage();
                                        },
                                      ));
                                    },
                                    icon: Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 3,
                                  fit: FlexFit.tight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.all(
                                            5 * globals.scaleParam),
                                        elevation: 0,
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent),
                                    onPressed: () {
                                      _key.currentState!.openEndDrawer();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10 * globals.scaleParam),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Flexible(
                                            flex: 3,
                                            fit: FlexFit.tight,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                              ),
                                              child: Text(
                                                widget.user["name"] ?? "",
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontFamily: "Raleway",
                                                  fontVariations: <FontVariation>[
                                                    FontVariation('wght', 600)
                                                  ],
                                                  fontSize:
                                                      30 * globals.scaleParam,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: CircleAvatar(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // IconButton(
                                //     onPressed: () {},
                                //     icon: Icon(Icons.settings, color: Colors.black,)),
                              ],
                            ),
                          )),
              ),
              // SliverToBoxAdapter(
              //     child: Padding(
              //   padding: EdgeInsets.all(30 * globals.scaleParam),
              //   child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         RichText(
              //           text: TextSpan(
              //               style: TextStyle(
              //                   color: Colors.black,
              //                   fontWeight: FontWeight.w400,
              //                   fontSize: 36),
              //               children: [
              //                 TextSpan(text: "Fast and \n"),
              //                 TextSpan(
              //                     text: "Delicious",
              //                     style:
              //                         TextStyle(fontWeight: FontWeight.w700)),
              //                 TextSpan(text: " food")
              //               ]),
              //         )
              //       ]),
              // )),
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 50 * globals.scaleParam,
                      vertical: 20 * globals.scaleParam),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          "Бар-Маркеты",
                          style: TextStyle(
                              fontSize: 48 * globals.scaleParam,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 700)
                              ],
                              color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50 * globals.scaleParam,
                ),
              ),
              BusinessSelectCarousel(
                businesses: widget.businesses,
                user: widget.user,
                currentAddress: widget.currentAddress,
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 800 * globals.scaleParam,
                ),
              ),
            ],
          )),
    );
  }
}

class DrawerMenuItem extends StatefulWidget {
  const DrawerMenuItem(
      {super.key, required this.name, required this.icon, required this.route});
  final String name;
  final IconData icon;
  final Widget route;
  @override
  State<DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<DrawerMenuItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) {
            return widget.route;
          },
        ));
      },
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                offset: Offset(5, 3), blurRadius: 5, color: Colors.black12)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.all(20 * globals.scaleParam),
                  child: Icon(
                    widget.icon,
                    size: 58 * globals.scaleParam,
                  ),
                )),
            Flexible(
              flex: 2,
              child: Text(
                widget.name,
                style: TextStyle(
                  fontVariations: <FontVariation>[FontVariation('wght', 800)],
                  fontSize: 36 * globals.scaleParam,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessItem extends StatefulWidget {
  const BusinessItem({
    super.key,
    required this.business,
    required this.user,
  });
  final Map business;
  final Map user;
  @override
  State<BusinessItem> createState() => BusinessItemState();
}

class BusinessItemState extends State<BusinessItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              // return StorePage(business: widget.business);
              return HomePage(
                business: widget.business,
                user: widget.user,
              );
            },
          ),
        );
      },
      child: Container(
        alignment: Alignment.topLeft,
        margin: EdgeInsets.all(10 * globals.scaleParam),
        // width: 650 * globals.scaleParam,
        // height: 600 * globals.scaleParam,

        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          // color: Colors.white,
          // boxShadow: [
          //   BoxShadow(
          //       offset: Offset(2, 2), blurRadius: 2, color: Colors.black12),
          // ],
          borderRadius: BorderRadius.all(
            Radius.circular(10),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(10),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.business["img"],
                  height: double.infinity,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    return const SizedBox();
                  },
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth * 0.95,
                        height: constraints.maxHeight * 0.7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 1,
                              fit: FlexFit.tight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.business["name"],
                                      style: TextStyle(
                                        fontVariations: <FontVariation>[
                                          FontVariation('wght', 700)
                                        ],
                                        fontSize: 38 * globals.scaleParam,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Text(
                                      widget.business["address"],
                                      style: TextStyle(
                                          fontFamily: "Raleway",
                                          fontVariations: <FontVariation>[
                                            FontVariation('wght', 400)
                                          ],
                                          fontSize: 30 * globals.scaleParam),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            // Flexible(
                            //   fit: FlexFit.tight,
                            //   child: Row(
                            //     mainAxisAlignment: MainAxisAlignment.start,
                            //     crossAxisAlignment: CrossAxisAlignment.center,
                            //     children: [
                            //       Flexible(
                            //         child: Text(
                            //           "Короткое описание",
                            //           style: TextStyle(
                            //               fontFamily: "Raleway",
                            //               fontVariations: <FontVariation>[
                            //                 FontVariation('wght', 600)
                            //               ],
                            //               fontSize: 30 * globals.scaleParam),
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessSelectCarousel extends StatefulWidget {
  const BusinessSelectCarousel(
      {super.key,
      required this.businesses,
      required this.user,
      required this.currentAddress});
  final List<Map> businesses;
  final Map user;
  final Map currentAddress;

  @override
  State<BusinessSelectCarousel> createState() => _BusinessSelectCarouselState();
}

class _BusinessSelectCarouselState extends State<BusinessSelectCarousel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1, childAspectRatio: 1.5),
      itemCount: widget.businesses.length,
      itemBuilder: (context, index) {
        return BusinessItem(
          business: widget.businesses[index],
          user: widget.user,
        );
      },
    );
  }
}
