import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

class ItemCard extends StatefulWidget {
  ItemCard(
      {super.key,
      required this.item_id,
      required this.element,
      required this.category_name,
      required this.category_id,
      required this.scroll});
  final Map<String, dynamic> element;
  final String category_name;

  final String item_id;

  final String category_id;
  final double scroll;
  int chack = 1;
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  Map<String, dynamic> element = {};
  List<InlineSpan> propertiesWidget = [];
  late BuyButton _buyButton;
  late int chack;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      element = widget.element;
      _buyButton = BuyButton(element: element);
    });
    getProperties();
  }

  void getProperties() {
    if (widget.element["properties"] != null) {
      List<InlineSpan> propertiesT = [];
      List<String> properties = widget.element["properties"].split(",");
      print(properties);
      for (var element in properties) {
        List temp = element.split(":");
        propertiesT.add(WidgetSpan(
            child: Row(
          children: [
            Text(
              temp[1],
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
            Image.asset(
              "assets/property_icons/${temp[0]}.png",
              width: 14,
              height: 14,
            ),
            const SizedBox(
              width: 10,
            )
          ],
        )));
      }
      setState(() {
        propertiesWidget = propertiesT;
      });
    }
  }

  Future<void> refreshItemCard() async {
    Map<String, dynamic>? element = await getItem(widget.element["item_id"]);
    print(element);
    setState(() {
      element!["name"] = "123";
      element = element!;
      _buyButton = BuyButton(element: element!);
    });
  }

  @override
  Widget build(BuildContext context) {
    chack = widget.chack;
    return SizedBox(
      // margin: const EdgeInsets.all(10),
      height: MediaQuery.of(context).size.width * 0.6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: CachedNetworkImage(
              imageUrl: 'https://naliv.kz/img/${element["photo"]}',
              width: MediaQuery.of(context).size.width * 0.4,
              // height: MediaQuery.of(context).size.width * 0.7,
              fit: BoxFit.fitWidth,
              placeholder: (context, url) {
                return Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: const CircularProgressIndicator(),
                );
              },
              errorWidget: (context, url, error) {
                return Container(
                  alignment: Alignment.center,
                  color: Colors.white,
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: const Expanded(
                    child: Text("Нет изображения"),
                  ),
                );
              },
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: RichText(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            textBaseline: TextBaseline.alphabetic,
                            fontSize: 20,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(text: element["name"]),
                            element["country"] != null
                                ? WidgetSpan(
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(10))),
                                      child: Text(
                                        element["country"] ?? "",
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  )
                                : const TextSpan()
                          ],
                        ),
                      ),
                    ),
                  ),
                  element["prev_price"] != null
                      ? Flexible(
                          child: Row(
                            children: [
                              Text(
                                element["prev_price"],
                                style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey.shade500,
                                    decorationThickness: 1.85,
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "₸",
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14),
                              )
                            ],
                          ),
                        )
                      : Container(),
                  Flexible(
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Text(
                            element['price'] ?? "",
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 28),
                          ),
                        ),
                        Text(
                          "₸",
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w900,
                              fontSize: 28),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Flexible(
                          flex: 5,
                          child: _buyButton,
                        ),
                        Flexible(
                          flex: 1,
                          child: LikeButton(
                            is_liked: element["is_liked"],
                            item_id: element["item_id"],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
