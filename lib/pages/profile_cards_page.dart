import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/surfaces.dart';
import '../utils/api.dart';
import '../utils/web_window.dart';
import 'card_flow.dart';
import 'card_widgets.dart';

class ProfileCardsPage extends StatefulWidget {
  const ProfileCardsPage({super.key, this.openCardForm});

  final Future<bool> Function(Uri)? openCardForm;

  @override
  State<ProfileCardsPage> createState() => _ProfileCardsPageState();
}

class _ProfileCardsPageState extends State<ProfileCardsPage>
    with WidgetsBindingObserver {
  late final CardFlow _flow;

  @override
  void initState() {
    super.initState();
    _flow = CardFlow(
      readCards: () => ApiService.getUserCards(source: 'halyk'),
      openForm: (uri, window) => openHostedCardForm(context, uri, window,
          openCardForm: widget.openCardForm),
      requiresWindow: kIsWeb && widget.openCardForm == null,
      reserveWindow: kIsWeb && widget.openCardForm == null
          ? () => reserveWebNamedWindow(cardFormWindowName)
          : null,
      closeWindow: closeReservedWebWindow,
    )..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _flow.refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flow.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.removeListener(_changed);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
            32, 12, 32, MediaQuery.paddingOf(context).bottom + 24),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 576),
            child: AppGlassPanel(
              radius: AppRadii.pill,
              tint: _flow.canAdd ? palette.accentSoft : palette.surfaceMuted,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('add-card-button'),
                  onPressed: _flow.canAdd ? _flow.addCard : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    minimumSize: const Size(44, 52),
                    textStyle: AppTypography.title,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_flow.preparing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.add, size: 24),
                      const SizedBox(width: AppSpacing.lg),
                      Flexible(
                        child: Text(
                          _flow.preparing
                              ? 'Открываем банк…'
                              : _flow.addState == CardAddState.launchFailed
                                  ? 'Открыть форму снова'
                                  : 'Добавить новую карту',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                    title: 'Мои карты',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Builder(builder: (context) {
                    final footerSpace = MediaQuery.paddingOf(context).bottom;
                    final empty = !_flow.loading &&
                        _flow.error == null &&
                        _flow.partialWarning == null &&
                        _flow.cards.isEmpty;
                    return RefreshIndicator(
                      onRefresh: _flow.refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 24)),
                          if (_flow.message != null)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              sliver: SliverToBoxAdapter(
                                  child: CardFlowFeedback(flow: _flow)),
                            ),
                          if (!empty)
                            const SliverPadding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                              sliver:
                                  SliverToBoxAdapter(child: CardFaqPanel()),
                            ),
                          if (_flow.loading)
                            const SliverToBoxAdapter(
                              child:
                                  SizedBox(height: 120, child: AppLoading()),
                            ),
                          if (_flow.error != null ||
                              _flow.partialWarning != null)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              sliver: SliverToBoxAdapter(
                                  child: CardReadFeedback(flow: _flow)),
                            ),
                          if (_flow.cards.isNotEmpty)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                itemCount: _flow.cards.length,
                                itemBuilder: (_, index) {
                                  final card = _flow.cards[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SavedCardRow(
                                      card: card,
                                      key: ValueKey(
                                          'saved-card-${card.rowKey}'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (empty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    16, 24, 16, footerSpace + 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppEmptyState(
                                      title: 'Добавленных карт нет',
                                      subtitle:
                                          'Добавьте карту в защищённой форме банка, и она появится здесь после обновления списка',
                                    ),
                                    const SizedBox(height: 24),
                                    const CardFaqPanel(),
                                    _refreshAction(),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            if (!_flow.awaiting)
                              SliverToBoxAdapter(child: _refreshAction()),
                            SliverToBoxAdapter(
                                child: SizedBox(height: footerSpace + 16)),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _refreshAction() => Center(
        child: TextButton(
          key: const ValueKey('refresh-card-list'),
          onPressed: _flow.preparing || _flow.loading ? null : _flow.refresh,
          child: const Text('Обновить список'),
        ),
      );
}
