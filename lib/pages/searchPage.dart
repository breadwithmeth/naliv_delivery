import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/searchResultPage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _keyword = TextEditingController();

  void _search() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (context) {
        return SearchResultPage(
          search: _keyword.text,
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
                borderRadius: const BorderRadius.all(Radius.circular(10))),
            child: Column(
              children: [
                TextField(
                  controller: _keyword,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: "Поиск",
                      filled: true,
                      fillColor: Colors.white,
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(width: 2, color: Colors.amber),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(width: 2, color: Colors.grey),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(width: 5, color: Colors.black),
                          borderRadius: BorderRadius.all(Radius.circular(10)))),
                ),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                        Theme.of(context).colorScheme.secondary),
                    shape: const MaterialStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                    ),
                    elevation: const MaterialStatePropertyAll(0.0),
                  ),
                  onPressed: () {
                    _search();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [Text("Найти")],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
