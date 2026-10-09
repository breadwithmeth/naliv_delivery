import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/ui/app_search_field.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';

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

  // Numbers are unique within a section, not across the entire repository.
  late String _openKey = _keyOf(
      FaqRepository.sections.first, FaqRepository.sections.first.entries.first);

  static String _keyOf(FaqSectionData section, FaqEntry entry) =>
      '${section.number}:${entry.number}';

  // Keep the seven local sections mounted so shortcuts can reach offscreen anchors.
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppTopBar(title: 'FAQ'),
            ),
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
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.xxxl,
                        0,
                        AppSpacing.xxxl,
                        AppSpacing.huge + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        children: [
                          for (final section in sections)
                            _Section(
                              headerKey: _sectionKeys.putIfAbsent(
                                section.number,
                                () => GlobalKey(),
                              ),
                              section: section,
                              openKey: _openKey,
                              onToggle: (entry) {
                                final key = _keyOf(section, entry);
                                setState(() =>
                                    _openKey = _openKey == key ? '' : key);
                              },
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
          ),
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
    required this.headerKey,
  });

  final FaqSectionData section;
  final String openKey;
  final ValueChanged<FaqEntry> onToggle;
  final Key headerKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: headerKey,
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            section.title,
            style: AppTypography.bodySmallSemibold
                .copyWith(color: palette.textSecondary),
          ),
        ),
        for (final entry in section.entries)
          Column(
            children: [
              _EntryCard(
              entry: entry,
              isOpen: openKey == _FaqPageState._keyOf(section, entry),
              onTap: () => onToggle(entry),
            ),
              Divider(height: 1, color: palette.divider),
            ],
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(entry.question,
                      style: AppTypography.body
                          .copyWith(color: palette.textPrimary)),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedRotation(
                  turns: isOpen ? 0.25 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right_rounded,
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
