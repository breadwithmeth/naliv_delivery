import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../shared/app_theme.dart';

class BonusHistoryPage extends StatelessWidget {
  final List<dynamic> history;

  const BonusHistoryPage({super.key, required this.history});

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('История бонусов', style: TextStyle(fontWeight: FontWeight.w800)),
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: history.isEmpty
                  ? const Center(
                      child: Text('История пуста', style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700)),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = history[index] as Map? ?? {};
                        final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
                        final ts = entry['timestamp']?.toString() ?? '';
                        final orgId = entry['organizationId']?.toString();
                        final id = entry['bonusId']?.toString();
                        final isPositive = amount >= 0;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppDecorations.card(radius: 16, color: AppColors.card.withValues(alpha: 0.95)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isPositive ? AppColors.orange : AppColors.red).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(isPositive ? Icons.add : Icons.remove, color: isPositive ? AppColors.orange : AppColors.red, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPositive ? '+${amount.toStringAsFixed(0)}' : amount.toStringAsFixed(0),
                                      style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_formatDate(ts), style: const TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w600)),
                                    if (orgId != null || id != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${id ?? '-'}  •  Организация: ${orgId ?? '-'}',
                                        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.8), fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
