import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_number_input/intl_phone_number_input_test.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:flutter/cupertino.dart';

class FindCreateUserPage extends StatefulWidget {
  const FindCreateUserPage(
      {super.key, required this.business, required this.user});

  final Map<dynamic, dynamic> business;
  final Map user;

  @override
  State<FindCreateUserPage> createState() => _FindCreateUserPageState();
}

class _FindCreateUserPageState extends State<FindCreateUserPage> {
  final TextEditingController _phone_number = TextEditingController();
  Map<String, dynamic> client = {};
  bool isClientReady = false;
  bool isSearchInProgress = false;
  String realNumber = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Укажите клиента"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20 * globals.scaleParam),
          child: Column(
            children: [
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
                child: IntlPhoneField(
                  controller: _phone_number,
                  dropdownIconPosition: IconPosition.trailing,
                  showCountryFlag: true,
                  decoration: InputDecoration(
                    labelText: 'Номер клиента',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  initialCountryCode: 'KZ',
                  onChanged: (phone) {
                    setState(() {
                      isClientReady = false;
                      realNumber = phone.completeNumber;
                      print(phone.completeNumber);
                    });
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isSearchInProgress = true;
                  });
                  getCreateUser(realNumber).then((value) {
                    setState(() {
                      isSearchInProgress = false;
                    });
                    if (value.isEmpty) {
                      print("SOMETHING GONE WRONG");
                    } else {
                      setState(() {
                        client = value;
                        isClientReady = true;
                      });
                    }
                  });
                },
                child: SizedBox(
                  width: 450 * globals.scaleParam,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Найти",
                        style: TextStyle(
                          fontSize: 40 * globals.scaleParam,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              isSearchInProgress ? CircularProgressIndicator() : SizedBox(),
              isClientReady
                  ? Container(
                      child: Column(
                        children: [
                          Text(
                            "Клиент: ${client["name"]}. ID: ${client["user_id"]}",
                            style: TextStyle(
                              fontSize: 40 * globals.scaleParam,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          )
                        ],
                      ),
                    )
                  : SizedBox(),
              SizedBox(
                height: 200 * globals.scaleParam,
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
                child: ElevatedButton(
                  onPressed: isClientReady
                      ? () {
                          // Navigator.push(context, MaterialPageRoute(
                          //   builder: (context) {
                          //     return PickAddressPage(
                          //       client: client,
                          //       business: widget.business,
                          //     );
                          //   },
                          // ));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return CreateOrderPage(
                                  client: client,
                                  business: widget.business,
                                  finalSum: 0,
                                  user: widget.user,
                                  items: const [], // TODO: GET ITEMS FROM CART SOMWHERE BEFORE THIS PAGE, OR ON THIS PAGE LOADING SCREEN
                                  itemsAmount: 0,
                                  deliveryInfo: Map.from(
                                    {"error": 0},
                                  ), // TODO: GET DELIVERY INFO FROM CART SOMWHERE BEFORE THIS PAGE, OR ON THIS PAGE LOADING SCREEN
                                );
                              },
                            ),
                          );
                        }
                      : null,
                  child: SizedBox(
                    width: 450 * globals.scaleParam,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Продолжить",
                          style: TextStyle(
                            fontSize: 40 * globals.scaleParam,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
