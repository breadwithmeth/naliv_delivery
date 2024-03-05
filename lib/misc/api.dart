import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

//var URL_API = '10.8.0.3';

// var URL_API = '192.168.0.164:8080';
var URL_API = 'naliv.kz';

Future<Position> determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

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
  String? token = prefs.getString('token') ?? null;
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
  bool? token = prefs.getBool('is_agree') ?? null;
  print(123);

  print(token);
  if (token == true) {
    return true;
  } else {
    return false;
  }
}

Future<bool> register(String login, String password, String name) async {
  var url = Uri.https(URL_API, 'api/user/register.php');
  var response = await http.post(
    url,
    body: json.encode({'login': login, 'password': password, 'name': name}),
    headers: {"Content-Type": "application/json"},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (response.statusCode == 201) {
    return true;
  } else {
    return false;
  }
}

Future<bool> login(String login, String password) async {
  var url = Uri.https(URL_API, 'api/user/login.php');
  var response = await http.post(
    url,
    body: json.encode({'login': login, 'password': password}),
    headers: {"Content-Type": "application/json"},
  );
  var data = jsonDecode(response.body);
  if (response.statusCode == 202) {
    final prefs = await SharedPreferences.getInstance();
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
  var url = Uri.https(URL_API, 'api/user/setCityAuto.php');
  var response = await http.post(
    url,
    body: json.encode({'lat': lat, 'lon': lon}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
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
  var url = Uri.https(URL_API, 'api/business/getLastSelectedBusiness.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<List?> getBusinesses() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/business/get.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  List? data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<bool> setCurrentStore(String business_id) async {
  String? token = await getToken();
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/business/setCurrentBusiness.php');
  var response = await http.post(
    url,
    body: json.encode({'business_id': business_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  var data = jsonDecode(response.body);
  print(response.statusCode);
  if (data = true) {
    return true;
  } else {
    return false;
  }
}

Future<List> getCategories() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/category/get.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  List data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<List> getItems(String category_id, int page,
    {Map? filters = null}) async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/get.php');
  var response = await http.post(
    url,
    encoding: Encoding.getByName('utf-8'),
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: filters == null
        ? json.encode({'category_id': category_id, "page": page})
        : json.encode(
            {'category_id': category_id, 'filters': filters, "page": page}),
  );
  print(json
      .encode({'category_id': category_id, 'filters': filters, "page": page}));
  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  List data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map> getFilters(String category_id) async {
  String? token = await getToken();
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getFilters.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'category_id': category_id}),
  );
  // List<dynamic> list = json.decode(response.body);
  print(utf8.decode(response.bodyBytes));
  Map data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<Map<String, dynamic>?> getItem(String item_id,
    {List? filter = null}) async {
  String? token = await getToken();
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/get.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({'item_id': item_id, 'filter': filter}),
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<String?> addToCart(String item_id) async {
  String? token = await getToken();
  print("ADD TO CARD");
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/addToCart.php');
  var response = await http.post(
    url,
    body: json.encode({'item_id': item_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data = null;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["amount"];
  } else {
    data = null;
  }
  return data;
}

Future<String?> removeFromCart(String item_id) async {
  String? token = await getToken();
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/removeFromCart.php');
  var response = await http.post(
    url,
    body: json.encode({'item_id': item_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data = null;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["amount"];
  } else {
    data = null;
  }
  print(response.statusCode);
  return data;
}

Future<List> getCart() async {
  String? token = await getToken();
  if (token == null) {
    return [];
  }
  var url = Uri.https(URL_API, 'api/item/getCart.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
  );

  // List<dynamic> list = json.decode(response.body);
  List data = json.decode(utf8.decode(response.bodyBytes));
  print(data);
  return data;
}

Future<Map<String, dynamic>?> getCartInfo() async {
  String? token = await getToken();
  if (token == null) {
    return {};
  }
  var url = Uri.https(URL_API, 'api/item/getCartInfo.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<String?> dislikeItem(String item_id) async {
  String? token = await getToken();
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/dislikeItem.php');
  var response = await http.post(
    url,
    body: json.encode({'item_id': item_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data = null;
  if (jsonDecode(response.body) != null) {
    data = jsonDecode(response.body)["like_id"];
  } else {
    data = null;
  }
  print(response.statusCode);
  return data;
}

Future<String?> likeItem(String item_id) async {
  String? token = await getToken();
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/likeItem.php');
  var response = await http.post(
    url,
    body: json.encode({'item_id': item_id}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  String? data = null;
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
  var url = Uri.https(URL_API, 'api/item/getLiked.php');
  var response = await http.post(
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
  var url = Uri.https(URL_API, 'api/user/get.php');
  var response = await http.post(
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
  var url = Uri.https(URL_API, 'api/user/getAddresses.php');
  var response = await http.post(
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

Future<bool> createAddress(Map address) async {
  String? token = await getToken();
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/createAddress.php');
  var response = await http.post(
    url,
    body: json.encode(address),
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

Future<bool> selectAddress(String address_id) async {
  String? token = await getToken();
  if (token == null) {
    return false;
  }
  var url = Uri.https(URL_API, 'api/user/selectAddress.php');
  var response = await http.post(
    url,
    body: json.encode({"address_id": address_id}),
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
  var url = Uri.https(URL_API, 'api/business/getCity.php');
  var response = await http.post(
    url,
    headers: {"Content-Type": "application/json", "AUTH": token},
    body: json.encode({}),
  );

  // List<dynamic> list = json.decode(response.body);
  Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes));
  return data;
}

Future<bool?> deleteFromCart(String item_id) async {
  String? token = await getToken();
  if (token == null) {
    return null;
  }
  var url = Uri.https(URL_API, 'api/item/deleteFromCart.php');
  var response = await http.post(
    url,
    body: json.encode({'item_id': item_id}),
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
  var url = Uri.https(URL_API, 'api/user/deleteAccount.php');
  var response = await http.post(
    url,
    body: json.encode({}),
    headers: {"Content-Type": "application/json", "AUTH": token},
  );
  Map? data = jsonDecode(response.body);

  return data!["result"];
}

Future<bool> getOneTimeCode(String phone_number) async {
  // String? token = await getToken();
  // if (token == null) {
  //   return false;
  // }
  var url = Uri.https(URL_API, 'api/user/sendOneTimeCode.php');
  var response = await http.post(
    url,
    body: json.encode({"phone_number": phone_number}),
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

Future<bool> verify(String phone_number, String code) async {
  // String? token = await getToken();
  // if (token == null) {
  //   return false;
  // }
  var url = Uri.https(URL_API, 'api/user/verify.php');
  var response = await http.post(
    url,
    body: json.encode({"phone_number": phone_number, "code": code}),
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
