import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_dialog.dart';
import 'transaction_tile.dart';
import 'add_transaction_sheet.dart';

/// Main Ledger Screen showing balance summary and grouped transactions.
class LedgerScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<CategoryTag> categories;
  final Future<void> Function(Transaction txn) onAddTransaction;
  final Future<void> Function(Transaction txn) onUpdateTransaction;
  final Future<void> Function(String id) onDeleteTransaction;

  final Future<void> Function(List<CategoryTag> categories)? onUpdateCategories;
  final Future<void> Function(CategoryTag category)? onCreateCategory;

  const LedgerScreen({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    this.onUpdateCategories,
    this.onCreateCategory,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _searchQuery = '';

  void _openAddSheet([Transaction? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(
        existingTransaction: existing,
        availableCategories: widget.categories,
        onCreateCategory: widget.onCreateCategory,
        onUpdateCategories: widget.onUpdateCategories,
        onSave: (txn) async {
          if (existing != null) {
            await widget.onUpdateTransaction(txn);
          } else {
            await widget.onAddTransaction(txn);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Transaction txn) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete "${txn.note}" of ${MoneyFormatter.format(txn.amount)}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      await widget.onDeleteTransaction(txn.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalIn = 0.0;
    double totalOut = 0.0;
    for (final t in widget.transactions) {
      if (t.isCredit) {
        totalIn += t.amount;
      } else {
        totalOut += t.amount;
      }
    }
    final netBalance = totalIn - totalOut;

    final filtered = widget.transactions.where((t) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesNote = t.note.toLowerCase().contains(query);
        final matchesTag = t.tag?.toLowerCase().contains(query) ?? false;
        if (!matchesNote && !matchesTag) return false;
      }
      return true;
    }).toList();

    final Map<String, List<Transaction>> grouped = {};
    for (final t in filtered) {
      final key = DateFormat('EEE, dd MMM yyyy').format(t.timestamp);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: NummoCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      MoneyFormatter.format(netBalance),
                      style: TextStyle(
                        color: netBalance >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Income (In)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(MoneyFormatter.format(totalIn), style: const TextStyle(color: AppColors.creditGreen, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 36, color: AppColors.cardBorder(context)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Expenses (Out)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(MoneyFormatter.format(totalOut), style: const TextStyle(color: AppColors.debitRed, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  widget.transactions.isEmpty ? 'No transactions yet' : 'No matching transactions',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dateKey = grouped.keys.elementAt(index);
                  final items = grouped[dateKey]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Text(
                            dateKey,
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...items.map((txn) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: TransactionTile(
                                transaction: txn,
                                onEdit: () => _openAddSheet(txn),
                                onDelete: () => _confirmDelete(txn),
                              ),
                            )),
                      ],
                    ),
                  );
                },
                childCount: grouped.keys.length,
              ),
            ),
        ],
      ),
    );
  }
}
