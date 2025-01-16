import 'package:flutter/material.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import '../globals.dart' as globals;
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
          Text(
            "-",
            style: TextStyle(
                fontSize: 28 * globals.scaleParam,
                fontVariations: <FontVariation>[FontVariation('wght', 500)],
                color: Colors.white),
          ),
          Container(
              alignment: Alignment.centerLeft,
              width: MediaQuery.of(context).size.width * 0.7,
              child: TextButton(
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: 28 * globals.scaleParam,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', 500)
                      ],
                      color: Colors.blue.shade600),
                ),
                onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(
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
        backgroundColor: Color(0xFF121212),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Text(
                      "Уважаемый пользователь",
                      style: TextStyle(
                          fontSize: 42 * globals.scaleParam,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 600)
                          ],
                          color: Colors.white),
                    ),
                  ),
                  const Divider(),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Text(
                      "Продолжение использования нашего веб-ресурса/приложения/сервиса подразумевает ваше добровольное согласие на сбор, обработку и использование ваших персональных данных, а также подтверждение ознакомления и согласия с следующим:",
                      style: TextStyle(
                          fontSize: 32 * globals.scaleParam,
                          fontVariations: <FontVariation>[
                            FontVariation('wght', 400)
                          ],
                          color: Colors.white),
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
                              fontSize: 32 * globals.scaleParam,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 400)
                              ],
                              color: Colors.white),
                        ),
                      ),
                      Container(
                          child: Checkbox(
                        activeColor: Colors.white,
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
                              Navigator.pushReplacement(context,
                                  CupertinoPageRoute(
                                builder: (context) {
                                  return const LoginPage();
                                },
                              ));
                            }
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Продолжить",
                            style: TextStyle(
                              color: Colors.white,
                              fontVariations: <FontVariation>[
                                FontVariation('wght', 800)
                              ],
                              fontSize: 42 * globals.scaleParam,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  // Spacer(),
                ],
              ),
            ),
          ),
        ));
  }
}


//