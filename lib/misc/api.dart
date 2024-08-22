import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/permissionPage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
      Navigator.push(ctx, MaterialPageRoute(
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
  final prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  if (token == "000") {
    return null;
  }
  print(token);
  return token;
}

Future<bool> setToken(Map data) async {
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
  String? token = await getToken();
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
  String? token = await getToken();
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

Future<List<Map>?> getBusinesses() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/business/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  List<Map> data = List.from(json.decode(utf8.decode(response.bodyBytes)));
  print(data);
  return data;
}

Future<bool> setCurrentStore(String businessId) async {
  String? token = await getToken();
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
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/category/get');
  var response = await client.post(url,
      headers: {"Content-Type": "application/json", "AUTH": token},
      body: parent_category
          ? json.encode({'parent_category_only': "1"})
          : json.encode({"business_id": business_id}));

  // List<dynamic> list = json.decode(response.body);
  List data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<List?> getItemsMain(int page, String business_id,
    [String? search, String? categoryId]) async {
  String? token = await getToken();
  if (token == null) {
    return [];
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
    return [];
  } else {
    List data = json.decode(utf8.decode(response.bodyBytes));
    return data;
  }
}

Future<List> getItems(String categoryId, int page, {Map? filters}) async {
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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

Future<List?> changeCartItem(dynamic itemId, int amount, String businessId,
    {List options = const []}) async {
  String? token = await getToken();
  print("ADD TO CARD");
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/addToCart');

  late var response;
  List options_selected_ids = [];
  for (Map option in options) {
    if (option["selection"] == "SINGLE") {
      options_selected_ids.add(option["selected_relation_id"]);
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/user/get');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<List> getAddresses() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/user/getAddresses');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );
  print(utf8.decode(response.bodyBytes));
  // List<dynamic> list = json.decode(response.body);
  List data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<List> createAddress(Map address) async {
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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

Future<Map<String, dynamic>> createOrder(String businessId, String? addressId, [String user_id = ""]) async {
  // Returns null in two situations, token is null or wrong order (406)
  String? token = await getToken();
  if (token == null) {
    return {"status": null};
  }
  Map body = {
    'business_id': businessId,
  };
  if (user_id.isNotEmpty) {
    body.addAll({"user_id": user_id});
  }
  if (addressId != null) {
    body.addAll({"address_id": addressId});
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

Future<List<dynamic>> getOrders() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getOrder');
  var response = await client.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  List<dynamic> list = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  int data = response.statusCode;
  if (data == 200) {
    return list;
  } else if (data == 400) {
    return [];
  } else {
    return [];
  }
}

Future<bool?> deleteFromCart(String itemId) async {
  String? token = await getToken();
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
  String? token = await getToken();
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
  // String? token = await getToken();
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
  // String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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

Future<Map<String, dynamic>> getCreateUser(String phoneNumber) async {
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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
  String? token = await getToken();
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

  Map<String, dynamic> result = json.decode(response.body);
  print(json.encode(response.statusCode));
  print(response.body);
  return result;
}
