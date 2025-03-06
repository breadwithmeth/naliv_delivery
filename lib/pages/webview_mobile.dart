import 'package:flutter/material.dart';

class WebViewWidget extends StatelessWidget {
  final String url;
  
  const WebViewWidget({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(); // Пустой контейнер для мобильной версии
  }
}