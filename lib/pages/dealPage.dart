import 'package:flutter/material.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';

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
      padding: EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
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
    appBar: AppBar(toolbarHeight: 0,),
        body: SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Text(
                "Уважаемый пользователь",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black),
              ),
            ),
            Divider(),
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Text(
                "Продолжение использования нашего веб-ресурса/приложения/сервиса подразумевает ваше добровольное согласие на сбор, обработку и использование ваших персональных данных, а также подтверждение ознакомления и согласия с следующим:",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black),
              ),
            ),
            SizedBox(
              height: 5,
            ),
            getAgreementString(
                "Договор оферты",
                OfferPage(
                  path: "assets/agreements/offer.md",
                )),
            getAgreementString(
                "Политика конфиденциальности",
                OfferPage(
                  path: "assets/agreements/privacy.md",
                )),
            getAgreementString(
                "Порядок возврата Товара Держателем Карточки Предприятию и порядок возврата денег, оплаченных за возвращенный Товар, Порядок и сроки поставки товара/услуг, Порядок замены Товара Предприятием Держателю Карточки в случае поставки некачественного и/или некомплектного Товара",
                OfferPage(
                  path: "assets/agreements/returnPolicy.md",
                )),
            getAgreementString(
                "Стоимость товаров/услуг, включая расходы на поставку и НДС",
                OfferPage(
                  path: "assets/agreements/nds.md",
                )),
            getAgreementString(
                "Почтовый адрес (юридический/фактический) и номера контактных телефонов Предприятия",
                OfferPage(
                  path: "assets/agreements/links.md",
                )),
            SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
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
            SizedBox(
              height: 30,
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(),
                onPressed: is_agree!
                    ? () async {
                        bool agreed = await setAgreement();
                        if (agreed) {
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) {
                              return LoginPage();
                            },
                          ));
                        }
                      }
                    : null,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Продолжить",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      )
                    ],
                  ),
                ))
          ],
        ),
      ),
    ));
  }
}


//