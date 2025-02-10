import 'dart:convert';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/permissionPage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../globals.dart' as globals;
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: "https://chorenn.naliv.kz",
  sendTimeout: Duration(seconds: 10),
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
));

//var URL_API = '10.8.0.3';

// var URL_API = '192.168.0.164:8080';
String URL_API = 'chorenn.naliv.kz';
String PAYMENT_URL = "chorenn.naliv.kz";
var client = http.Client();

Future<Position> determinePosition(BuildContext ctx) async {
  LocationPermission permission;

  // Test if location services are enabled.
  await Geolocator.isLocationServiceEnabled().then((value) {
    if (!value) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      Navigator.push(ctx, CupertinoPageRoute(
        builder: (context) {
          return PermissionPage();
        },
      ));

      Geolocator.openLocationSettings().whenComplete(() {
        Navigator.pop(ctx);
      });
      return Future.error('Location services are disabled.');
    }
  });

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

Future<String?> getToken() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == "000" || token == null) {
    return null;
  }
  globals.setToken(token);
  print(token);
  return token;
}

Future<bool> setToken(Map data) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', data['token']);
  final token = prefs.getString('token') ?? false;
  print(token);
  return token == false ? false : true;
}

Future<bool> setAgreement() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_agree', true);
  final token = prefs.getBool('is_agree') ?? false;
  print(token);
  return token == false ? false : true;
}

Future<bool> getAgreement() async {
  final prefs = await SharedPreferences.getInstance();
  bool? token = prefs.getBool('is_agree');
  print(123);

  print(token);
  if (token == true) {
    return true;
  } else {
    return false;
  }
}

Future<bool> register(String login, String password, String name) async {
  var url = Uri.https(URL_API, 'api/user/register');
  var response = await client.post(
    url,
    body: json.encode({'login': login, 'password': password, 'name': name}),
    headers: {"Content-Type": "application/json"},
  );
  jsonDecode(response.body);
  print(response.statusCode);
  if (response.statusCode == 201) {
    return true;
  } else {
    return false;
  }
}

Future<bool> login(String login, String password) async {
  var url = Uri.https(URL_API, 'api/user/login');
  var response = await client.post(
    url,
    body: json.encode({'login': login, 'password': password}),
    headers: {"Content-Type": "application/json"},
  );
  var data = jsonDecode(response.body);
  if (response.statusCode == 202) {
    await SharedPreferences.getInstance();
    setToken(data);
    print(data['token']);

    return true;
  } else {
    return false;
  }
}

Future<bool> setCityAuto(double lat, double lon) async {
  //   WidgetsFlutterBinding.ensureInitialized();String? token = globals.currentToken;

  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/setCityAuto');
  var response = await client.post(
    url,
    body: json.encode({'lat': lat, 'lon': lon}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  jsonDecode(response.body);
  print(response.statusCode);
  if (response.statusCode == 201) {
    return true;
  } else {
    return false;
  }
}

Future<Map<String, dynamic>?> getLastSelectedBusiness() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/business/getLastSelectedBusiness');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<List> getBusinesses() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  // var url = Uri.https(URL_API, 'api/item/getBusinesses2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  // );

  // // List<dynamic> list = json.decode(response.body);
  // List<Map> data = List.from(json.decode(utf8.decode(response.bodyBytes)));
  // print(data);
  Response response = await dio.post('/api/item/getBusinesses2',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ));
  List data = response.data;
  return data;
}

Future<bool> setCurrentStore(String businessId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/business/setCurrentBusiness');
  var response = await client.post(
    url,
    body: json.encode({'business_id': businessId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (data == true) {
    return true;
  } else {
    return false;
  }
}

Future<List> getCategories(String business_id,
    [bool parent_category = false]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  // var url = Uri.https(URL_API, 'api/category/get');
  // var response = await client.post(url,
  //     headers: {"Content-Type": "application/json", "AUTH": token},
  //     body: json.encode({"business_id": business_id, "all": "true"}));

  // // List<dynamic> list = json.decode(response.body);
  // List data = json.decode(utf8.decode(response.bodyBytes));
  // print(data);

  Response response = await dio.post('/api/category/get',
      data: {"business_id": business_id, "all": "true"},
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ));
  List data = response.data;
  return data;
}

Future<Map?> getItemsMain(int page, String business_id,
    [String? search, String? categoryId]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  http.Response response;
  var url = Uri.https(URL_API, 'api/item/get');

  Map<String, String> queryBody = {};

  if (search!.isNotEmpty) {
    queryBody.addAll({'search': search, 'business_id': business_id});
  }
  if (categoryId != null && categoryId.isNotEmpty) {
    queryBody.addAll({'category_id': categoryId, 'business_id': business_id});
  }
  queryBody.addAll({'page': page.toString()});
  var jsonBody = jsonEncode(queryBody);

  if (categoryId != "") {
    response = await client.post(
      url,
      encoding: Encoding.getByName('utf-8'),
      headers: {"Content-Type": "application/json", "AUTH": token},
      body: jsonBody,
    );
  } else {
    response = await client.post(
      url,
      encoding: Encoding.getByName('utf-8'),
      headers: {"Content-Type": "application/json", "AUTH": token},
      body: jsonBody,
    );
  }

  print(jsonBody);
  print(queryBody);

  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  if (utf8.decode(response.bodyBytes) == "") {
    return {};
  } else {
    Map data = json.decode(utf8.decode(response.bodyBytes));
    return data;
  }
}

Future<Map> getItemsMain3(String business_id, [String? categoryId]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  // http.Response response;
  // var url = Uri.https(URL_API, 'api/item/get2');

  // Map<String, String> queryBody = {};

  Response response = await dio.post('/api/item/get3',
      data: {'category_id': categoryId, 'business_id': business_id},
      options: Options(
          headers: {"Content-Type": "application/json", "AUTH": token}));

  // if (categoryId != null && categoryId.isNotEmpty) {
  //   queryBody.addAll({'category_id': categoryId, 'business_id': business_id});
  // }
  // var jsonBody = jsonEncode(queryBody);

  // if (categoryId != "") {
  //   response = await client.post(
  //     url,
  //     encoding: Encoding.getByName('utf-8'),
  //     headers: {"Content-Type": "application/json", "AUTH": token},
  //     body: jsonBody,
  //   );
  // } else {
  //   response = await client.post(
  //     url,
  //     encoding: Encoding.getByName('utf-8'),
  //     headers: {"Content-Type": "application/json", "AUTH": token},
  //     body: jsonBody,
  //   );
  // }

  // print(jsonBody);
  // print(queryBody);

  // List<dynamic> list = json.decode(response.body);
  // print(utf8.decode(response.bodyBytes));
  Map data = response.data;
  return data;
}

Future<Map?> getItemsMain2(int page, String business_id,
    [String? search, String? categoryId]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  http.Response response;
  var url = Uri.https(URL_API, 'api/item/get');

  Map<String, String> queryBody = {};

  if (search!.isNotEmpty) {
    queryBody
        .addAll({'search': search, 'business_id': business_id, 'all': "true"});
  }
  if (categoryId != null && categoryId.isNotEmpty) {
    queryBody.addAll(
        {'category_id': categoryId, 'business_id': business_id, 'all': "true"});
  }
  queryBody.addAll({'page': page.toString()});
  var jsonBody = jsonEncode(queryBody);

  if (categoryId != "") {
    response = await client.post(
      url,
      encoding: Encoding.getByName('utf-8'),
      headers: {"Content-Type": "application/json", "AUTH": token},
      body: jsonBody,
    );
  } else {
    response = await client.post(
      url,
      encoding: Encoding.getByName('utf-8'),
      headers: {"Content-Type": "application/json", "AUTH": token},
      body: jsonBody,
    );
  }

  print(jsonBody);
  print(queryBody);

  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  if (utf8.decode(response.bodyBytes) == "") {
    return {};
  } else {
    Map data = json.decode(utf8.decode(response.bodyBytes));
    return data;
  }
}

Future<List> getItems(String categoryId, int page, {Map? filters}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    encoding: Encoding.getByName('utf-8'),
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: filters == null
        ? json.encode({'category_id': categoryId, "page": page})
        : json.encode(
            {'category_id': categoryId, 'filters': filters, "page": page}),
  );
  print(json
      .encode({'category_id': categoryId, 'filters': filters, "page": page}));
  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  List data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map> getFilters(String categoryId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getFilters');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'category_id': categoryId}),
  );
  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  Map data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map<String, dynamic>> getItem(dynamic itemId, String business_id,
    {List? filter}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(
        {'item_id': itemId, 'business_id': business_id, 'filter': filter}),
  );
  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  if (data.isEmpty) {
    return {};
  } else {
    return data;
  }
}

Future<List?> changeCartItem(dynamic itemId, double amount, String businessId,
    {List options = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  print("ADD TO CARD");
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/addToCart');

  late var response;
  List options_selected_ids = [];
  for (Map option in options) {
    if (option["selection"] == "SINGLE") {
      if (option["selected_relation_id"] != null) {
        options_selected_ids.add(option["selected_relation_id"]);
      }
    } else {
      if (option["selected_relation_id"] != null) {
        for (int selected_id in option["selected_relation_id"]) {
          options_selected_ids.add(selected_id);
        }
      }
    }
  }
  print(options);
  if (options.length == 0) {
    response = await client.post(
      url,
      body: json.encode({
        'item_id': itemId,
        'amount': amount.toString(),
        'business_id': businessId,
      }),
      headers: {"Content-Type": "application/json", "AUTH": token},
    );
  } else {
    print(options);
    response = await client.post(
      url,
      body: json.encode({
        'item_id': itemId,
        'amount': amount.toString(),
        'business_id': businessId,
        'options': options_selected_ids
      }),
      headers: {"Content-Type": "application/json", "AUTH": token},
    );
  }

  List? data = [];
  if (jsonDecode(response.body) == null && response.body == "[]") {
    data = [];
  } else {
    if (jsonDecode(response.body)["cart"] != null) {
      data = jsonDecode(response.body)["cart"];
    }
    // if (jsonDecode(response.body) is Map) {
    //   data = [jsonDecode(response.body)];
    //   data[0]["amount"] = 0;
    // } else {
    //   data = jsonDecode(response.body);
    // }
  }
  return data;
}

Future<String?> removeFromCart(String itemId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/removeFromCart');
  var response = await client.post(
    url,
    body: json.encode({'item_id': itemId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["amount"];
  } else {
    data = null;
  }
  print(response.statusCode);
  return data;
}

Future<Map<String, dynamic>> getCart(String businessId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getCart');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': businessId}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.bodyBytes);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "DATA FROM GETCART IN API.DART__ DATA FROM GETCART IN API.DART__ DATA FROM GETCART IN API.DART");
  return data;
}

Future<Map<String, dynamic>?> getCartInfo() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getCartInfo');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<String?> dislikeItem(String itemId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/dislikeItem');
  var response = await client.post(
    url,
    body: json.encode({'item_id': itemId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["like_id"];
  } else {
    data = null;
  }
  print(response.statusCode);
  return data;
}

Future<String?> likeItem(String itemId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/likeItem');
  var response = await client.post(
    url,
    body: json.encode({'item_id': itemId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["like_id"];
  } else {
    data = null;
  }
  print(response.statusCode);
  return data;
}

Future<List> getLiked() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getLiked');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );
  print(utf8.decode(response.bodyBytes));
  // List<dynamic> list = json.decode(response.body);
  List data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<Map<String, dynamic>?> getUser() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  // var url = Uri.https(URL_API, 'api/user/get');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  // );

  // // List<dynamic> list = json.decode(response.body);
  // Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  // print(data);
  Response response = await dio.post('/api/user/get',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ));
  Map<String, dynamic> data = response.data;

  return data;
}

Future<List> getAddresses() async {
  // WidgetsFlutterBinding.ensureInitialized();

  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  // var url = Uri.https(URL_API, 'api/user/getAddresses');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({}),
  // );
  // print(utf8.decode(response.bodyBytes));
  // // List<dynamic> list = json.decode(response.body);
  // List data = json.decode(utf8.decode(response.bodyBytes));

  Response response = await dio.post('/api/user/getAddresses',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ));
  List data = response.data ?? [];

  return data;
}

Future<List> createAddress(Map address) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/user/createAddress');
  var response = await client.post(
    url,
    body: json.encode(address),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  List? data = json.decode(utf8.decode(response.bodyBytes));
  if (data == null) {
    return [];
  } else {
    return data;
  }
}

Future<bool> selectAddress(String addressId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/selectAddress');
  var response = await client.post(
    url,
    body: json.encode({"address_id": addressId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  if (data == null) {
    return false;
  } else {
    if (data["result"] == true) {
      return true;
    } else {
      return false;
    }
  }
}

Future<Map<String, dynamic>?> getCity() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/business/getCity');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map<String, dynamic>> createOrder(
    String businessId, String? addressId, int? delivery, int? card_id) async {
  // Returns null in two situations, token is null or wrong order (406)
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'business_id': businessId,
    'card_id': card_id,
  };

  // if (addressId != null) {
  //   body.addAll({"address_id": addressId});
  // }
  if (delivery != null) {
    body.addAll({"delivery": delivery});
  }

  var url = Uri.https(URL_API, 'api/item/createOrder');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(body),
  );

  // List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  if (data == 200) {
    return {"status": true, "data": utf8.decode(response.bodyBytes)};
  } else if (data == 400) {
    return {
      "status": false,
      "data": json.decode(utf8.decode(response.bodyBytes))
    };
  } else {
    return {"status": null};
  }
}

Future<List<dynamic>> getOrders([String orderId = ""]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getOrder');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: orderId != "" ? json.encode({"order_id": orderId}) : null,
  );

  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  if (json.decode(response.body) is List) {
    if (data == 200) {
      return json.decode(response.body);
    } else if (data == 400) {
      return [];
    } else {
      return [];
    }
  } else {
    if (data == 200) {
      return [json.decode(response.body)];
    } else if (data == 400) {
      return [];
    } else {
      return [];
    }
  }
}

Future<bool?> deleteFromCart(String itemId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/deleteFromCart');
  var response = await client.post(
    url,
    body: json.encode({'item_id': itemId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  bool? data = jsonDecode(response.body);

  return data;
}

Future<bool> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('token', "000");
  final token = prefs.getString('token') ?? false;
  print(token);
  return token == false ? false : true;
}

Future<bool?> deleteAccount() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/user/deleteAccount');
  var response = await client.post(
    url,
    body: json.encode({}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  Map? data = jsonDecode(response.body);

  return data!["result"];
}

Future<bool> getOneTimeCode(String phoneNumber) async {
  //   WidgetsFlutterBinding.ensureInitialized();String? token = globals.currentToken;

  // if (token == null) {
  //   return false;
  // }
  var url = Uri.https(URL_API, 'api/user/sendOneTimeCode');
  var response = await client.post(
    url,
    body: json.encode({"phone_number": phoneNumber}),
    headers: {"Content-Type": "application/json"},
  );
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  if (data == null) {
    return false;
  } else {
    if (data["result"] == true) {
      return true;
    } else {
      return false;
    }
  }
}

Future<bool> verify(String phoneNumber, String code) async {
  //   WidgetsFlutterBinding.ensureInitialized();String? token = globals.currentToken;

  // if (token == null) {
  //   return false;
  // }
  var url = Uri.https(URL_API, 'api/user/verify');
  var response = await client.post(
    url,
    body: json.encode({"phone_number": phoneNumber, "code": code}),
    headers: {"Content-Type": "application/json"},
  );
  // Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  var data = jsonDecode(response.body);

  print(data);
  if (data == null) {
    return false;
  } else {
    bool isset = await setToken(data);
    return isset;
  }
}

Future<List> getGeoData(String search) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  List<dynamic> list = [];
  var url = Uri.https(URL_API, 'api/user/getAddressGeoData');

  var response = await client.post(
    url,
    body: json.encode({"search": search}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  ).timeout(Duration(seconds: 2), onTimeout: () {
    return http.Response('Time out!', 500);

    /// here is the response if api call time out
    /// you can show snackBar here or where you handle api call
  });
  print(response.body);
  list = json.decode(response.body);

  return list;

  // List<dynamic> list = json.decode(response.body);
  // Map data = json.decode(utf8.decode(response.bodyBytes));
}

Future<List> getGeoDataByCoord(double lat, double lon) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/user/getAddressGeoData');
  var response = await client.post(
    url,
    body: json.encode({"lat": lat, "lon": lon}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  List<dynamic> list = json.decode(response.body);
  return list;
}

Future<List?> getActiveOrders() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }
  // var url = Uri.https(URL_API, 'api/item/getActiveOrder');
  // var response = await client.post(
  //   url,
  //   headers: {
  //     "Content-Type": "application/json",
  //     "AUTH": token,
  //   },
  // );
  try {
    Response response = await dio.post('/api/item/getActiveOrder',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "AUTH": token,
          },
        ));

    List? result = response.data;

    return result ?? [];
  } catch (e) {
    return [];
  }
}

Future<Map<String, dynamic>> getCreateUser(String phoneNumber) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/user/getClient');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({"phone_number": phoneNumber}),
  );

  Map<String, dynamic> result = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<List<dynamic>> getUserAddresses(String userID) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/user/getAddressesPerUser');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({"user_id": userID}),
  );

  List<dynamic> result = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<bool> selectAddressClient(String addressId, String user_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/selectAddress');
  var response = await client.post(
    url,
    body: json.encode({"address_id": addressId, "user_id": user_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  if (data == null) {
    return false;
  } else {
    if (data["result"] == true) {
      return true;
    } else {
      return false;
    }
  }
}

Future<List<dynamic>> getCities() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/user/getCities');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    // body: json.encode({"user_id": userID}),
  );

  List<dynamic> result = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<bool> changeName(String name) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/changeName');
  var response = await client.post(
    url,
    body: json.encode({'name': name}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (data["result"] == "true") {
    return true;
  } else {
    return false;
  }
}

Future<String> getPaymentHTML() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return "";
  }
  var url = Uri.https(PAYMENT_URL, '/api/payment/getPaymentPage');
  var response = await client.post(
    url,
    // body: json.encode({'business_id': businessId}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  // var data = json.decode(utf8.decode(response.bodyBytes));
  print(response.statusCode);
  return utf8.decode(response.bodyBytes);
}

Future<Map> getBonuses() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/user/getBonuses');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({}),
  );

  Map<String, dynamic> result = json.decode(response.body) ?? {};
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<Map> getOrderDetails(String order_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getOrderDetails');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({"order_id": order_id}),
  );

  Map<String, dynamic> result = json.decode(response.body) ?? {};
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<Map<String, dynamic>> getPaymentPageForUnpaidOrder(
    String order_id) async {
  // Returns null in two situations, token is null or wrong order (406)
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'order_id': order_id,
  };

  var url = Uri.https(URL_API, '/api/item/getPaymentPageForUnpaidOrder');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(body),
  );

  // List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  if (data == 200) {
    return {"status": true, "data": utf8.decode(response.bodyBytes)};
  } else if (data == 400) {
    return {
      "status": false,
      "data": json.decode(utf8.decode(response.bodyBytes))
    };
  } else {
    return {"status": null};
  }
}

Future<bool> setIdOneSignal(String id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/setId');
  var response = await client.post(
    url,
    body: json.encode({'id': id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (data["result"] == "true") {
    return true;
  } else {
    return false;
  }
}

Future<Map<String, dynamic>> getItems2(String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  Response response = await dio.post('api/item/geti2',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {'business_id': business_id});
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  // print(response.bodyBytes);
  Map<String, dynamic> data = json.decode(utf8.decode(response.data));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsPopular(String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': business_id, 'popular': true}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsNew(String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': business_id, 'new': true}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsRecs(
    String business_id, String item_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': business_id, 'rec_item_id': item_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsSearch(
    String business_id, String keyword) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': business_id, 'search': keyword}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsCategory(
    String business_id, String category_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'business_id': business_id, 'category_id': category_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<bool> finishProfile(String name, String date, String first_name,
    String last_name, String sex) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/finishProfile');
  var response = await client.post(
    url,
    body: json.encode({
      'name': name,
      'first_name': first_name,
      'last_name': last_name,
      'sex': sex,
      'date_of_birth': date
    }),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (data["result"] == true) {
    return true;
  } else {
    return false;
  }
}

Future<Map<String, dynamic>?> getCourierLocation(String order_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getCourierLocation');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'order_id': order_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.bodyBytes);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));

  return data;
}

Future<List<dynamic>> getSavedCards() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getSavedCards');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    // body: json.encode({"user_id": userID}),
  );

  List<dynamic> result = json.decode(response.body) ?? [];
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<List<dynamic>> getProperties(String item_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getProperties');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({"item_id": item_id}),
  );

  List<dynamic> result = json.decode(response.body) ?? [];
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<Map<String, dynamic>?> getPropertiesForCategory(
    String category_id, String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getPropertiesForCategory');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'category_id': category_id, 'business_id': business_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.bodyBytes);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));

  return data;
}

Future<List<dynamic>> getItemsByPropertiesValues(List values) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getItemsByPropertiesValues');
  var response = await client.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "AUTH": token,
    },
    body: json.encode({"values": values}),
  );

  List<dynamic> result = json.decode(response.body) ?? [];
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}

Future<Map<String, dynamic>> getItemsCart(String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getCart2');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({
      'business_id': business_id,
    }),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map> changeCartItemByCartItemId(
  dynamic cart_item_id,
  double amount,
  String businessId,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  print("ADD TO CARD");
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/addToCart');

  late var response;
  response = await client.post(
    url,
    body: json.encode({
      'cart_item_id': cart_item_id,
      'amount': amount.toString(),
      'business_id': businessId,
    }),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  Map data = jsonDecode(response.body);
  return data;
}

Future<Map> getStories(
  String businessId,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  print("ADD TO CARD");
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getStories');

  late var response;
  response = await client.post(
    url,
    body: json.encode({
      'business_id': businessId,
    }),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  Map data = jsonDecode(response.body);
  return data;
}

Future<Map<String, dynamic>> getItemsPromotion(
    String business_id, String promotion_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body:
        json.encode({'business_id': business_id, 'promotion_id': promotion_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemsCollection(
    String business_id, String collection_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json
        .encode({'business_id': business_id, 'collection_id': collection_id}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getAdditions(
    String business_id, String comp_category_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get3');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({
      'business_id': business_id,
      'comp_category_id': comp_category_id,
      "page": 1,
      "all": "true"
    }),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> addNewCard() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/addNewCard');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );

  // List<dynamic> list = json.decode(response.body);
  print(response.body);
  Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));

  return data;
}

Future<Map<String, dynamic>> createOrder2(String businessId, String? addressId,
    int? delivery, int? card_id, bool useBonuses) async {
  // Returns null in two situations, token is null or wrong order (406)
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'business_id': businessId,
    'card_id': card_id,
    'bonus': useBonuses
  };

  // if (addressId != null) {
  //   body.addAll({"address_id": addressId});
  // }
  if (delivery != null) {
    body.addAll({"delivery": delivery});
  }

  var url = Uri.https(URL_API, 'api/item/createOrder2');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(body),
  );

  // List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  Map<String, dynamic> d = json.decode(utf8.decode(response.bodyBytes));
  return d;
}

Future<Map<String, dynamic>> pay(String order_id, String card_id) async {
  // Returns null in two situations, token is null or wrong order (406)
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'order_id': order_id,
    'card_id': card_id,
  };

  // if (addressId != null) {
  //   body.addAll({"address_id": addressId});
  // }

  var url = Uri.https(URL_API, 'api/item/pay');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(body),
  );

  // List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  int data = response.statusCode;
  Map<String, dynamic> d = json.decode(utf8.decode(response.bodyBytes));
  print(d);
  return d;
}

Future<Map> getDeliveyPrice(String business_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  Response response = await dio.post('/api/item/getDeliveryPrice',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {'business_id': business_id});
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  print(response.data);
  Map data = response.data;

  return data;
}

Future<bool?> isLiked(int item_id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return null;
  }

  Response response = await dio.post('/api/item/getLiked',
      data: {'item_id': item_id},
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ));
  Map? data = response.data;
  if (data == null) {
    return false;
  } else {
    return true;
  }
}

Future<Map<String, dynamic>> createOrder3(String businessId, String? delivery,
    String? card_id, List items, bool useBonus, String extra) async {
  // Returns null in two situations, token is null or wrong order (406)
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'business_id': businessId,
    'card_id': card_id,
    'items': items,
    'bonus': useBonus,
    'extra': extra
  };

  // if (addressId != null) {
  //   body.addAll({"address_id": addressId});
  // }
  if (delivery != null) {
    body.addAll({"delivery": delivery});
  }

  var url = Uri.https(URL_API, 'api/item/createOrder3');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode(body),
  );

  // List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  Map<String, dynamic> d = json.decode(utf8.decode(response.bodyBytes));
  return d;
}

Future<Map<String, dynamic>> getItemsRescByItems(
    String business_id, String ids) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  Response response = await dio.post('/api/item/get3',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {'business_id': business_id, "comp_item_id": ids});
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  // print(response.bodyBytes);
  print("============================================");
  print(response.data);
  Map<String, dynamic> data = response.data;
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<bool?> deleteAddress(String addressId) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/selectAddress');
  var response = await client.post(
    url,
    body: json.encode({"address_id": addressId, "delete": true}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  bool? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map<String, dynamic>> getGigaCats(
  String business_id,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  Response response = await dio.post('/api/item/getGigaCatetories',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {
        'business_id': business_id,
      });
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  // print(response.bodyBytes);
  print("============================================");
  print(response.data);
  Map<String, dynamic> data = response.data;
  print(
      "не ну это пиздец какой то конечно оно грузит 10 секунд за то как грузит");
  return data;
}

Future<Map<String, dynamic>> getItemDetails(
  String item_id,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return {};
  }
  Response response = await dio.post('/api/item/getItemDetails',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {
        'item_id': item_id,
      });
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  // print(response.bodyBytes);
  print("============================================");
  print(response.data);
  Map<String, dynamic> data = response.data;

  return data;
}

Future<List> getCartPrice(
  List items,
) async {
  print(items);
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == null) {
    return [];
  }
  Response response = await dio.post('/api/item/getCartPrice',
      options: Options(
        headers: {"Content-Type": "application/json", "AUTH": token},
      ),
      data: {
        'items': items,
      });
  // var url = Uri.https(URL_API, 'api/item/geti2');
  // var response = await client.post(
  //   url,
  //   headers: {"Content-Type": "application/json", "AUTH": token},
  //   body: json.encode({'business_id': business_id}),
  // );

  // List<dynamic> list = json.decode(response.body);
  // print(response.bodyBytes);
  print("============================================");
  print(response.data);
  List data = response.data;

  return data;
}
