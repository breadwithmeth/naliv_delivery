import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/pages/faq_page.dart'
    show FaqEntry, FaqRepository, FaqSection, FaqSectionData;
import 'package:naliv_delivery/ui/app_search_field.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';

/// Rebuilt FAQ, matching the two design frames (`FAQ` and `FAQ - Не удалось загрузить`).
///
/// The copy is the app's own — the design is silent on which questions to ask, and the rule for a
/// silent design is "build what the app needs". So the 44 real entries in 7 sections come from
/// [FaqRepository], the same frozen source the legacy screen read; only the chrome is rebuilt.
///
/// One deliberate omission: the design's "Не удалось загрузить FAQ" frame has no honest trigger
/// here. That content is a local constant, so it cannot fail to load, and inventing a failure state
/// to match a frame would be fabricating a state the user can never reach. Recorded in
/// `docs/redesign/STATUS.md` rather than faked.
class FaqPage extends StatefulWidget {
  const FaqPage({this.initialSection, super.key});

  /// When a shortcut (profile, checkout, order details, help chat) asks for one section, the list
  /// opens scrolled to it — the behaviour the legacy screen had, preserved on cutover.
  final FaqSection? initialSection;

  static const String routeName = '/faq';

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  /// The design shows the first answer already open, so the screen does not read as a wall of
  /// closed rows. Keyed `section:entry` because numbers are only unique within a section.
  late String _openKey = _keyOf(
      FaqRepository.sections.first, FaqRepository.sections.first.entries.first);

  static String _keyOf(FaqSectionData section, FaqEntry entry) =>
      '${section.number}:${entry.number}';

  final Map<int, GlobalKey> _sectionKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    final target = widget.initialSection;
    if (target != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSection(target));
    }
  }

  void _scrollToSection(FaqSection section) {
    final target = _sectionKeys[section.number]?.currentContext;
    if (target == null || !mounted) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Sections narrowed by the query. A section whose entries all miss is dropped entirely, so the
  /// list never shows an empty heading.
  List<FaqSectionData> get _visibleSections {
    final query = FaqRepository.normalizeForSearch(_query).trim();
    if (query.isEmpty) return FaqRepository.sections;

    final result = <FaqSectionData>[];
    for (final section in FaqRepository.sections) {
      final entries = section.entries
          .where((entry) => FaqRepository.normalizeForSearch(
                '${section.title} ${entry.question} ${entry.answer}',
              ).contains(query))
          .toList();
      if (entries.isNotEmpty) result.add(section.copyWith(entries: entries));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sections = _visibleSections;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(title: 'FAQ'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl,
                0,
                AppSpacing.xxxl,
                AppSpacing.xl,
              ),
              child: AppSearchField(
                controller: _searchController,
                hint: 'Найти вопрос или ответ',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: sections.isEmpty
                  ? const AppEmptyState(
                      title: 'Ничего не найдено',
                      subtitle: 'Попробуйте изменить запрос',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxxl,
                        0,
                        AppSpacing.xxxl,
                        AppSpacing.huge,
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) => _Section(
                        key: _sectionKeys.putIfAbsent(
                          sections[index].number,
                          () => GlobalKey(),
                        ),
                        section: sections[index],
                        openKey: _openKey,
                        onToggle: (entry) {
                          final key = _keyOf(sections[index], entry);
                          setState(() => _openKey = _openKey == key ? '' : key);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.openKey,
    required this.onToggle,
    super.key,
  });

  final FaqSectionData section;
  final String openKey;
  final ValueChanged<FaqEntry> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Text(
            section.title,
            style: AppTypography.label.copyWith(color: palette.textSecondary),
          ),
        ),
        for (final entry in section.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _EntryCard(
              entry: entry,
              isOpen: openKey == _FaqPageState._keyOf(section, entry),
              onTap: () => onToggle(entry),
            ),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.isOpen,
    required this.onTap,
  });

  final FaqEntry entry;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      expanded: isOpen,
      label: entry.question,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        Text(entry.question, style: AppTypography.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  entry.answer,
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
