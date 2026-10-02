import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
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
    if (state == AppLifecycleState.resumed && _flow.awaiting) _flow.refresh();
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                      title: 'Мои карты',
                      onBack: () => Navigator.of(context).maybePop()),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _flow.refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        if (_flow.message != null)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            sliver: SliverToBoxAdapter(
                                child: CardFlowFeedback(flow: _flow)),
                          ),
                        if (_flow.loading)
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 120, child: AppLoading()))
                        else ...[
                          if (_flow.error != null ||
                              _flow.partialWarning != null)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              sliver: SliverToBoxAdapter(
                                  child: CardReadFeedback(flow: _flow)),
                            )
                          else if (_flow.cards.isEmpty)
                            const SliverToBoxAdapter(
                              child: AppEmptyState(
                                title: 'Добавленных карт нет',
                                subtitle:
                                    'Добавьте карту в защищённой форме банка, и она появится здесь после обновления списка',
                              ),
                            ),
                          if (_flow.error == null && _flow.cards.isNotEmpty)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                itemCount: _flow.cards.length,
                                itemBuilder: (_, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SavedCardRow(
                                      card: _flow.cards[index],
                                      key: ValueKey(
                                          'saved-card-${_flow.cards[index].id}')),
                                ),
                              ),
                            ),
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                            sliver: SliverToBoxAdapter(child: CardFaqPanel()),
                          ),
                          if (!_flow.awaiting)
                            SliverToBoxAdapter(
                              child: Center(
                                child: TextButton(
                                  key: const ValueKey('refresh-card-list'),
                                  onPressed:
                                      _flow.preparing ? null : _flow.refresh,
                                  child: const Text('Обновить список'),
                                ),
                              ),
                            ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('add-card-button'),
                      onPressed: _flow.canAdd ? _flow.addCard : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accentSoft,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        minimumSize: const Size(44, 49),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
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
                          )),
                        ],
                      ),
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
