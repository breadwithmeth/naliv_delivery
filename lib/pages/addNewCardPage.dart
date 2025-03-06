import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/webViewAddCard.dart';


class AddNewCardPage extends StatefulWidget {
  const AddNewCardPage({super.key, required this.createOrder});
  final bool createOrder;
  @override
  State<AddNewCardPage> createState() => _AddNewCardPageState();
}

class _AddNewCardPageState extends State<AddNewCardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.all(Radius.circular(15))),
            child: Text(
              '''При добавлении новой платежной карты с вашего счета временно будет списана сумма в размере 10 тенге в целях проверки работоспособности карты и подтверждения ее привязки к вашему аккаунту.''',
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
            ),
          ),
          Container(
            margin: EdgeInsets.all(10),
            child: ElevatedButton(
                onPressed: () {
                  addNewCard().then((v) async {
                    final url = Uri.parse(
                        "https://chorenn.naliv.kz/api/d92lj3.php?u=" +
                            v["user_uuid"]);

                    Navigator.pushReplacement(context, CupertinoPageRoute(
                        builder: (context) {
                          return WebViewScreen(
                              createOrder: widget.createOrder,
                              url: url.toString());
                        },
                      ));
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "Продолжить",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    )
                  ],
                )),
          ),
          Container(
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.all(Radius.circular(15))),
            child: Text(
              '''После нажатия кнопки "Продолжить" в вашем браузере откроется окно для проведения оплаты. В случае, если после завершения оплаты вас не вернуло в приложение, пожалуйста, откройте приложение вручную и нажмите кнопку "К списку карт".''',
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
            ),
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("К списку карт")),
          SizedBox(
            height: 100,
          )
        ],
      ),
    );
  }
}
