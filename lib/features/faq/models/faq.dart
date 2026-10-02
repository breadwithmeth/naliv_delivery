import 'package:flutter/material.dart';

enum FaqSection {
  profile(1, Icons.person_rounded),
  payment(2, Icons.credit_card_rounded),
  delivery(3, Icons.local_shipping_rounded),
  age(4, Icons.verified_user_rounded),
  bonuses(5, Icons.stars_rounded),
  orderChanges(6, Icons.inventory_2_rounded),
  orderProblems(7, Icons.support_agent_rounded);

  const FaqSection(this.number, this.icon);

  final int number;
  final IconData icon;

  static FaqSection? fromNumber(int? number) {
    if (number == null) return null;
    for (final section in values) {
      if (section.number == number) return section;
    }
    return null;
  }
}

class FaqEntry {
  const FaqEntry({
    required this.number,
    required this.question,
    required this.answer,
  });

  final int number;
  final String question;
  final String answer;
}

class FaqSectionData {
  const FaqSectionData({
    required this.number,
    required this.title,
    required this.entries,
  });

  final int number;
  final String title;
  final List<FaqEntry> entries;

  FaqSection? get key => FaqSection.fromNumber(number);

  FaqSectionData copyWith({
    String? title,
    List<FaqEntry>? entries,
  }) {
    return FaqSectionData(
      number: number,
      title: title ?? this.title,
      entries: entries ?? this.entries,
    );
  }
}
