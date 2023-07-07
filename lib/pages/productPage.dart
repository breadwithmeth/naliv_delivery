import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.item_id});
  final String item_id;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Widget _image = Container();
  Map<String, dynamic>? item = {};
  int currentTab = 0;
  List<String> TabText = [
    "Виски Ballantine's 12 лет — это бленд 40 отборных солодовых и зерновых дистиллятов, минимальный срок выдержки которых составляет 12 лет. ",
    "Джордж Баллантайн (George Ballantine) – выходец из семьи простых фермеров, начал свою трудовую карьеру в возрасте девятнадцати лет в качестве подсобного рабочего в бакалейной лавке в Эдинбурге. Здесь, в 1827 году, Джордж открывает свой бакалейный магазин, в котором небольшими партиями начинает реализовывать собственный алкоголь. К 1865 году Баллантайну удается открыть еще один магазин в Глазго, куда и переезжает глава семьи, оставив торговлю в Эдинбурге старшему сыну Арчибальду. В это время виски под маркой Ballantine’s продают уже по всей Шотландии, а Джордж возглавляет компанию George Ballantine and Son, престижную репутацию которой в 1895 году подтвердил факт получения ордена Королевы Виктории.",
    "Начиная с 2005 года производством Ballantine занимается компания Pernod Ricard, которая тщательно следит за репутацией бренда, сохраняя рецепты и старинные традиции."
  ];

  Future<void> _getItem() async {
    Map<String, dynamic>? _item = await getItem(widget.item_id);
    print(_item);
    if (_item != null) {
      setState(() {
        item = _item;
        TabText = [_item["description"] ?? "", _item["b_desc"] ?? "", _item["m_desc"]??""];
        if (item != null) {
          _image = Image.network(item!["photo"].toString());
        }
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItem();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        child: Container(
          decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.all(Radius.circular(15))),
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(17),
          width: MediaQuery.of(context).size.width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "В корзину",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.black),
              ),
              Row(
                children: [
                  Text(
                    "10000",
                    style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    item!['price'] ?? "999999" + "₸",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                        fontWeight: FontWeight.w600),
                  )
                ],
              )
            ],
          ),
        ),
      ),
      backgroundColor: Color(0xAAFAFAFA),
      body: Container(
        color: Colors.white,
        child: ListView(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  _image,
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Icon(Icons.arrow_back_ios),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.share_outlined),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Арт: 1234567",
                              style: TextStyle(fontSize: 10),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.favorite_outline),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Container(
                    margin: EdgeInsets.only(right: 10),
                    padding: EdgeInsets.all(5),
                    child: Text(
                      "Новинка",
                      style: TextStyle(color: Colors.black),
                    ),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.all(Radius.circular(5))),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 10),
                    padding: EdgeInsets.all(5),
                    child: Text(
                      "Новинка",
                      style: TextStyle(color: Colors.black),
                    ),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.all(Radius.circular(5))),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 10),
                    padding: EdgeInsets.all(5),
                    child: Text(
                      "Новинка",
                      style: TextStyle(color: Colors.black),
                    ),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.all(Radius.circular(5))),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            ),
            Container(
              child: Text(
                item!["name"] ?? "",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
              ),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            ),
            SizedBox(
              height: 5,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "12",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontSize: 16),
                      ),
                      Icon(
                        Icons.percent,
                        color: Colors.grey.shade600,
                      )
                    ],
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Row(
                    children: [
                      Text(
                        "12",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontSize: 16),
                      ),
                      Icon(
                        Icons.percent,
                        color: Colors.grey.shade600,
                      )
                    ],
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Row(
                    children: [
                      Text(
                        "12",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontSize: 16),
                      ),
                      Icon(
                        Icons.percent,
                        color: Colors.grey.shade600,
                      )
                    ],
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.square,
                        color: Colors.grey.shade600,
                      ),
                      Text(
                        item!["country"] ?? "",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontSize: 16),
                      ),
                    ],
                  )
                ],
              ),
            ),
            SizedBox(
              height: 15,
            ),
            Stack(
              children: [
                Container(
                  height: 25,
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            offset: Offset(0, -1),
                            blurRadius: 15,
                            spreadRadius: 1)
                      ],
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.shade200, width: 3))),
                  child: Row(
                    children: [],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      child: Container(
                        margin: EdgeInsets.only(left: 15),
                        height: 25,
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: 3,
                                    color: currentTab == 0
                                        ? Colors.black
                                        : Colors.grey.shade200))),
                        child: Text(
                          "Описание",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          currentTab = 0;
                        });
                      },
                    ),
                    GestureDetector(
                      child: Container(
                        margin: EdgeInsets.only(left: 15),
                        height: 25,
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: 3,
                                    color: currentTab == 1
                                        ? Colors.black
                                        : Colors.grey.shade200))),
                        child: Text(
                          "О бренде",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          currentTab = 1;
                        });
                      },
                    ),
                    GestureDetector(
                      child: Container(
                        margin: EdgeInsets.only(left: 15),
                        height: 25,
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: 3,
                                    color: currentTab == 2
                                        ? Colors.black
                                        : Colors.grey.shade200))),
                        child: Text(
                          "Производитель",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          currentTab = 2;
                        });
                      },
                    ),
                  ],
                )
              ],
            ),
            Container(
              padding: EdgeInsets.all(15),
              child: Text(TabText[currentTab]),
            ),
            Container(
              padding: EdgeInsets.all(15),
              child: Table(
                children: [
                  TableRow(
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  width: 1, color: Colors.grey.shade400))),
                      children: [
                        TableCell(
                            child: Container(
                          child: Text(
                            "Литраж",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        )),
                        TableCell(
                            child: Container(
                          child: Text(
                            "0.7л",
                            style: TextStyle(
                                color: Colors.grey.shade900, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        ))
                      ]),
                  TableRow(
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  width: 1, color: Colors.grey.shade400))),
                      children: [
                        TableCell(
                            child: Container(
                          child: Text(
                            "Литраж",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        )),
                        TableCell(
                            child: Container(
                          child: Text(
                            "0.7л",
                            style: TextStyle(
                                color: Colors.grey.shade900, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        ))
                      ]),
                  TableRow(
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  width: 1, color: Colors.grey.shade400))),
                      children: [
                        TableCell(
                            child: Container(
                          child: Text(
                            "Литраж",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        )),
                        TableCell(
                            child: Container(
                          child: Text(
                            "0.7л",
                            style: TextStyle(
                                color: Colors.grey.shade900, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        ))
                      ]),
                  TableRow(
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  width: 1, color: Colors.grey.shade400))),
                      children: [
                        TableCell(
                            child: Container(
                          child: Text(
                            "Литраж",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        )),
                        TableCell(
                            child: Container(
                          child: Text(
                            "0.7л",
                            style: TextStyle(
                                color: Colors.grey.shade900, fontSize: 15),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 7),
                        ))
                      ])
                ],
              ),
            ),
            SizedBox(
              height: 100,
            )
          ],
        ),
      ),
    ));
  }
}
