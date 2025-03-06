import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import '../globals.dart' as globals;

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
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            width: MediaQuery.of(context).size.width * 0.7,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 28 * globals.scaleParam,
                  fontVariations: <FontVariation>[FontVariation('wght', 500)],
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => aRoute),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(height: 1),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Text(
                    "Продолжение использования нашего веб-ресурса/приложения/сервиса подразумевает ваше добровольное согласие на сбор, обработку и использование ваших персональных данных, а также подтверждение ознакомления и согласия с следующим:",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                getAgreementString(
                  "Договор оферты",
                  const OfferPage(path: "assets/agreements/offer.md"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "Я, при входе на данный ресурс, подтверждаю, что мне исполнился 21 год. Я подтверждаю, что прочитал и полностью ознакомился с вышеперечисленными документами, включая все правила, условия и политики, действующие на данном ресурсе.",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: is_agree ?? false,
                      onChanged: (value) {
                        setState(() {
                          is_agree = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                CupertinoButton.filled(
                  onPressed: is_agree!
                      ? () async {
                          bool agreed = await setAgreement();
                          if (agreed) {
                            Navigator.pushReplacement(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text(
                    "Продолжить",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
