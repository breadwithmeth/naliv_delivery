import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_number_input/intl_phone_number_input_test.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/createOrder.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

class findCreateUserPage extends StatefulWidget {
  const findCreateUserPage({super.key});

  @override
  State<findCreateUserPage> createState() => _findCreateUserPageState();
}

class _findCreateUserPageState extends State<findCreateUserPage> {
  final TextEditingController _phone_number = TextEditingController();
  Map<String, dynamic> client = {};
  bool isClientReady = false;
  bool isSearchInProgress = false;
  String realNumber = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: ElevatedButton(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Продолжить",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              )
            ],
          ),
          onPressed: isClientReady
              ? () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return PickAddressPage(client: client,);
                    },
                  ));
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) {
                  //       return CreateOrderPage(client: client);
                  //     },
                  //   ),
                  // );
                }
              : null,
        ),
      ),
      appBar: AppBar(
        title: Text("Укажите клиента"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: IntlPhoneField(
                  controller: _phone_number,
                  dropdownIconPosition: IconPosition.trailing,
                  showCountryFlag: true,
                  decoration: const InputDecoration(
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
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Найти",
                        style: TextStyle(
                          fontSize: 20,
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
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          )
                        ],
                      ),
                    )
                  : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
