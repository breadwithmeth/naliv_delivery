import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_theme.dart';
import '../utils/responsive.dart';

enum FaqSection {
  profile(1, 'Профиль', 'Вход, карты и профиль', Icons.person_rounded),
  payment(2, 'Оплата', 'Карты, счета и списания', Icons.credit_card_rounded),
  delivery(3, 'Доставка', 'Районы, сроки и адреса', Icons.local_shipping_rounded),
  age(4, '18+', 'Возраст и документы', Icons.verified_user_rounded),
  bonuses(5, 'Бонусы', 'Промокоды и акции', Icons.stars_rounded),
  orderChanges(6, 'Заказ', 'Сборка, замены и отмена', Icons.inventory_2_rounded),
  orderProblems(7, 'Возвраты', 'Проблемы, жалобы и возвраты', Icons.support_agent_rounded);

  const FaqSection(this.number, this.shortLabel, this.description, this.icon);

  final int number;
  final String shortLabel;
  final String description;
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
}

class FaqRepository {
  static Future<List<FaqSectionData>>? _cache;

  static Future<List<FaqSectionData>> load() {
    return _cache ??= _load();
  }

  static Future<List<FaqSectionData>> _load() async {
    final raw = await rootBundle.loadString('faq.txt');
    return _parse(raw);
  }

  static List<FaqSectionData> _parse(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final sectionRegExp = RegExp(r'^(\d+):\s*(.+)$');
    final questionRegExp = RegExp(r'^(\d+)\.\s*(.+)$');
    final answerRegExp = RegExp(r'^Ответ:\s*(.+)$');

    final sections = <FaqSectionData>[];
    int? currentSectionNumber;
    String? currentSectionTitle;
    final currentEntries = <FaqEntry>[];
    int? currentQuestionNumber;
    String? currentQuestion;
    var answerBuffer = StringBuffer();

    void flushQuestion() {
      final question = currentQuestion?.trim();
      final answer = _normalizeWhitespace(answerBuffer.toString());
      if (question != null && question.isNotEmpty && answer.isNotEmpty) {
        currentEntries.add(
          FaqEntry(
            number: currentQuestionNumber ?? currentEntries.length + 1,
            question: question,
            answer: answer,
          ),
        );
      }
      currentQuestionNumber = null;
      currentQuestion = null;
      answerBuffer = StringBuffer();
    }

    void flushSection() {
      flushQuestion();
      if (currentSectionNumber != null &&
          currentSectionTitle != null &&
          currentEntries.isNotEmpty) {
        sections.add(
          FaqSectionData(
            number: currentSectionNumber!,
            title: currentSectionTitle!.trim(),
            entries: List<FaqEntry>.unmodifiable(currentEntries),
          ),
        );
      }
      currentSectionNumber = null;
      currentSectionTitle = null;
      currentEntries.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final sectionMatch = sectionRegExp.firstMatch(trimmed);
      if (sectionMatch != null) {
        flushSection();
        currentSectionNumber = int.tryParse(sectionMatch.group(1)!);
        currentSectionTitle = sectionMatch.group(2)!;
        continue;
      }

      final questionMatch = questionRegExp.firstMatch(trimmed);
      if (questionMatch != null) {
        flushQuestion();
        currentQuestionNumber = int.tryParse(questionMatch.group(1)!);
        currentQuestion = questionMatch.group(2)!;
        continue;
      }

      final answerMatch = answerRegExp.firstMatch(trimmed);
      if (answerMatch != null) {
        if (answerBuffer.isNotEmpty) answerBuffer.write(' ');
        answerBuffer.write(answerMatch.group(1)!);
        continue;
      }

      if (currentQuestion != null) {
        if (answerBuffer.isNotEmpty) answerBuffer.write(' ');
        answerBuffer.write(trimmed);
      }
    }

    flushSection();
    return sections;
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

Future<void> openFaqPage(
  BuildContext context, {
  FaqSection? initialSection,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FaqPage(initialSection: initialSection),
    ),
  );
}

class FaqShortcutCard extends StatelessWidget {
  const FaqShortcutCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.initialSection,
    this.icon = Icons.help_center_rounded,
    this.actionLabel = 'Открыть FAQ',
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final FaqSection? initialSection;
  final IconData icon;
  final String actionLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: () => openFaqPage(
          context,
          initialSection: initialSection,
        ),
        borderRadius: BorderRadius.circular(14.s),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 30.s,
                height: 30.s,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.orange, size: 16.s),
              ),
              SizedBox(width: 9.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.s),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 11.sp,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMute.withValues(alpha: 0.8),
                size: 18.s,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.s,
            height: 40.s,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.orange, size: 21.s),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.s),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.s),
                TextButton.icon(
                  onPressed: () => openFaqPage(
                    context,
                    initialSection: initialSection,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(actionLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    padding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4.s,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
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

class FaqPage extends StatefulWidget {
  const FaqPage({
    super.key,
    this.initialSection,
  });

  final FaqSection? initialSection;

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  late FaqSection? _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text(
          'FAQ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          FutureBuilder<List<FaqSectionData>>(
            future: FaqRepository.load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.s),
                    child: Text(
                      'Не удалось загрузить FAQ. Попробуйте еще раз позже.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              final allSections = snapshot.data!;
              final sections = _selectedSection == null
                  ? allSections
                  : allSections
                      .where((section) => section.key == _selectedSection)
                      .toList(growable: false);

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.s, 6.s, 16.s, 24.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroCard(),
                      SizedBox(height: 14.s),
                      _filterChips(),
                      SizedBox(height: 14.s),
                      ...sections.map(_sectionCard),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    final selected = _selectedSection;
    final title = selected == null ? 'Быстрые ответы по приложению' : selected.description;
    final subtitle = selected == null
        ? 'Собрали все частые вопросы по входу, доставке, оплате, бонусам и возвратам в одном месте.'
        : 'Откройте ответы по теме и при необходимости переключитесь на другие разделы.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.s),
      decoration: AppDecorations.card(
        radius: 24.s,
        color: AppColors.cardDark.withValues(alpha: 0.96),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52.s,
            height: 52.s,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected?.icon ?? Icons.help_center_rounded,
              color: AppColors.orange,
              size: 28.s,
            ),
          ),
          SizedBox(width: 12.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 6.s),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            label: 'Все',
            selected: _selectedSection == null,
            onTap: () => setState(() => _selectedSection = null),
          ),
          ...FaqSection.values.map(
            (section) => Padding(
              padding: EdgeInsets.only(left: 8.s),
              child: _filterChip(
                label: section.shortLabel,
                selected: _selectedSection == section,
                onTap: () => setState(() => _selectedSection = section),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 9.s),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.orange
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.orange
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.text,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(FaqSectionData section) {
    final key = section.key;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.s),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.s),
        decoration: AppDecorations.card(
          radius: 20.s,
          color: AppColors.cardDark.withValues(alpha: 0.96),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.s,
                  height: 40.s,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    key?.icon ?? Icons.help_outline_rounded,
                    color: AppColors.orange,
                    size: 21.s,
                  ),
                ),
                SizedBox(width: 10.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.s),
                      Text(
                        '${section.entries.length} вопрос(ов)',
                        style: TextStyle(
                          color: AppColors.textMute,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.s),
            ...section.entries.asMap().entries.map((entry) {
              final isLast = entry.key == section.entries.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8.s),
                child: _questionTile(entry.value),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _questionTile(FaqEntry entry) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 2.s),
          childrenPadding: EdgeInsets.fromLTRB(12.s, 0, 12.s, 12.s),
          iconColor: AppColors.orange,
          collapsedIconColor: AppColors.textMute,
          title: Text(
            '${entry.number}. ${entry.question}',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.answer,
                style: TextStyle(
                  color: AppColors.textMute,
                  fontSize: 12.sp,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
