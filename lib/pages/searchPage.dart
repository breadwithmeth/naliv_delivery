import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:naliv_delivery/pages/searchResultPage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _keyword = TextEditingController();
  bool isTextInField = false;

  void _search() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (context) {
        return SearchResultPage(
          search: _keyword.text,
          page: 0,
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Поиск",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(5, 5),
                      blurRadius: 10)
                ],
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.all(Radius.circular(3))),
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
                              const BorderRadius.all(Radius.circular(3))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              width: 2,
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3))),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                              width: 5,
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3)))),
                ),
                const SizedBox(
                  height: 10,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 125),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: ElevatedButton(
                    key: UniqueKey(),
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: isTextInField
                        ? () {
                            _search();
                          }
                        : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          "Найти",
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
    );
  }
}
