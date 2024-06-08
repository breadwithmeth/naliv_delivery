import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/pages/searchResultPage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.business, this.category_id = ""});

  final Map<dynamic, dynamic> business;
  final String category_id;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _keyword = TextEditingController();
  bool isTextInField = false;
  bool isSearchEverywhere = false;

  void _search() {
    Navigator.pushReplacement(context, CupertinoPageRoute(
      builder: (context) {
        if (isSearchEverywhere) {
          print("SEARCH EVERYWHERE");
          return SearchResultPage(
            search: _keyword.text,
            page: 0,
            business: widget.business,
          );
        } else {
          print("SEARCH INSIDE CATEGORY");
          return SearchResultPage(
            search: _keyword.text,
            page: 0,
            category_id: widget.category_id,
            business: widget.business,
          );
        }
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;


    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Поиск",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(20 * globals.scaleParam),
              padding: EdgeInsets.all(40 * globals.scaleParam),
              decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: Offset(
                          10 * globals.scaleParam, 10 * globals.scaleParam),
                      blurRadius: 10,
                    )
                  ],
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              child: Column(
                children: [
                  TextField(
                    onChanged: ((value) {
                      // This is so complex because otherway the button will flicker non-stop on any change in TextField
                      // because setState method will update isTextInField and that will trigger AnimatedSwitcher for search button to rebuild and that is causing flickering
                      if (value.isNotEmpty) {
                        if (isTextInField == true) {
                          return;
                        } else {
                          setState(() {
                            isTextInField = true;
                          });
                        }
                      } else {
                        if (isTextInField == false) {
                          return;
                        } else {
                          setState(() {
                            isTextInField = false;
                          });
                        }
                      }
                    }),
                    controller: _keyword,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: "Поиск",
                        filled: true,
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 2,
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 2,
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 5,
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10)))),
                  ),
                  SizedBox(
                    height: 10 * globals.scaleParam,
                  ),
                  widget.category_id != ""
                      ? Row(
                          children: [
                            Checkbox(
                              value: isSearchEverywhere,
                              onChanged: (value) {
                                setState(() {
                                  print("VALUE IS " +
                                      isSearchEverywhere.toString());
                                  isSearchEverywhere = value!;
                                });
                              },
                            ),
                            Text(
                              "Искать везде",
                              style: TextStyle(
                                fontSize: 28 * globals.scaleParam,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        )
                      : Container(),
                  SizedBox(
                    height: 10 * globals.scaleParam,
                  ),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 125),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: ElevatedButton(
                      key: UniqueKey(),
                      style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 32 * globals.scaleParam,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: isTextInField
                          ? () {
                              _search();
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            "Найти",
                            style: TextStyle(
                              fontSize: 48 * globals.scaleParam,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
