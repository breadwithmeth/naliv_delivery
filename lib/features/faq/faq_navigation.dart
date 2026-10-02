import 'package:flutter/material.dart';

import 'models/faq.dart';
import 'ui/faq_page.dart';

Future<void> openFaqPage(
  BuildContext context, {
  FaqSection? initialSection,
}) {
  return Navigator.of(context).pushNamed(
    FaqPage.routeName,
    arguments: initialSection,
  );
}
