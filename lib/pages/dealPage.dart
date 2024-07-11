import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:flutter/cupertino.dart';

class DealPage extends StatefulWidget {
  const DealPage({super.key});

  @override
  State<DealPage> createState() => _DealPageState();
}

class _DealPageState extends State<DealPage> {
  bool? is_agree = false;
  Widget getAgreementString(String text, Widget aRoute) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          const Text(
            "-",
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black),
          ),
          Container(
              alignment: Alignment.centerLeft,
              width: MediaQuery.of(context).size.width * 0.7,
              child: TextButton(
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.blue.shade600),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return aRoute;
                    },
                  ));
                },
              ))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: const Text(
                  "Уважаемый пользователь",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black),
                ),
              ),
              const Divider(),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: const Text(
                  "Продолжение использования нашего веб-ресурса/приложения/сервиса подразумевает ваше добровольное согласие на сбор, обработку и использование ваших персональных данных, а также подтверждение ознакомления и согласия с следующим:",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              getAgreementString(
                  "Договор оферты",
                  const OfferPage(
                    path: "assets/agreements/offer.md",
                  )),
              // getAgreementString(
              //     "Политика конфиденциальности",
              //     const OfferPage(
              //       path: "assets/agreements/privacy.md",
              //     )),
              // getAgreementString(
              //     "Порядок возврата Товара Держателем Карточки Предприятию и порядок возврата денег, оплаченных за возвращенный Товар, Порядок и сроки поставки товара/услуг, Порядок замены Товара Предприятием Держателю Карточки в случае поставки некачественного и/или некомплектного Товара",
              //     const OfferPage(
              //       path: "assets/agreements/returnPolicy.md",
              //     )),
              // getAgreementString(
              //     "Стоимость товаров/услуг, включая расходы на поставку и НДС",
              //     const OfferPage(
              //       path: "assets/agreements/nds.md",
              //     )),
              // getAgreementString(
              //     "Почтовый адрес (юридический/фактический) и номера контактных телефонов Предприятия",
              //     const OfferPage(
              //       path: "assets/agreements/links.md",
              //     )),
              // const SizedBox(
              //   height: 10,
              // ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Я, при входе на данный ресурс, подтверждаю, что мне исполнился 21 год. Я подтверждаю, что прочитал и полностью ознакомился с вышеперечисленными документами, включая все правила, условия и политики, действующие на данном ресурсе.",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.black),
                    ),
                  ),
                  Container(
                      child: Checkbox(
                    activeColor: Colors.black,
                    value: is_agree,
                    onChanged: (value) {
                      setState(() {
                        is_agree = value;
                      });
                    },
                  )),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              ElevatedButton(
                onPressed: is_agree!
                    ? () async {
                        bool agreed = await setAgreement();
                        if (agreed) {
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) {
                              return const LoginPage();
                            },
                          ));
                        }
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Продолжить",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


//