import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../tokens.dart';
import 'nummo_dialog.dart';

/// Compact, sleek top-down modal dialog for creating or editing multi-budgets by category tag.
class BudgetDialog extends StatefulWidget {
  final Budget? existingBudget;
  final List<CategoryTag> categories;
  final ValueChanged<Budget> onSave;
  final VoidCallback? onDelete;

  const BudgetDialog({
    super.key,
    this.existingBudget,
    required this.categories,
    required this.onSave,
    this.onDelete,
  });

  /// Presents the modal as a smooth top-down sliding dialog from top to bottom.
  static Future<void> show(
    BuildContext context, {
    Budget? existingBudget,
    required List<CategoryTag> categories,
    required ValueChanged<Budget> onSave,
    VoidCallback? onDelete,
  }) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: BudgetDialog(
              existingBudget: existingBudget,
              categories: categories,
              onSave: onSave,
              onDelete: onDelete,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
    );
  }

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedScope; // 'overall' or category id/name
  late BudgetPeriod _selectedPeriod;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _isRecurring;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final b = widget.existingBudget;
    _titleController = TextEditingController(text: b?.title ?? '');
    _amountController = TextEditingController(
      text: b != null ? b.amount.toStringAsFixed(0) : '',
    );
    _selectedScope = b?.scope ?? 'overall';
    _selectedPeriod = b?.period ?? BudgetPeriod.monthly;
    _startDate = b?.startDate ?? DateTime.now();
    _endDate = b?.endDate ?? DateTime.now().add(const Duration(days: 30));
    _isRecurring = b?.isRecurring ?? true;

    _titleController.addListener(_update);
    _amountController.addListener(_update);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocusNode.requestFocus();
      }
    });
  }

  void _update() {
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final rawTitle = _titleController.text.trim();
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (rawTitle.isEmpty || rawAmount <= 0) return;

    final budget = Budget(
      id: widget.existingBudget?.id,
      title: rawTitle,
      amount: rawAmount,
      scope: _selectedScope,
      period: _selectedPeriod,
      startDate: _startDate,
      endDate: _endDate,
      isRecurring: _isRecurring,
    );

    widget.onSave(budget);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rawTitle = _titleController.text.trim();
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final isValid = rawTitle.isNotEmpty && rawAmount > 0;

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height - bottomInset - topPadding - 24;
    final maxSheetHeight = availableHeight.clamp(180.0, MediaQuery.of(context).size.height * 0.85);

    return Container(
      margin: EdgeInsets.fromLTRB(14, topPadding + 8, 14, bottomInset > 0 ? bottomInset + 8 : 12),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder(context), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.existingBudget != null ? 'Edit Budget' : 'Add Budget',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Inline Title & Amount Inputs Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _amountFocusNode.requestFocus(),
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Petrol, Groceries',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      style: TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Limit (₹) *',
                        prefixText: '₹ ',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Category Scope Selection Dropdown
              Text(
                'Category Scope',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedScope,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                dropdownColor: AppColors.surfaceCard(context),
                items: [
                  DropdownMenuItem(
                    value: 'overall',
                    child: Text('🌐 All Categories (Overall)', style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
                  ),
                  ...widget.categories.map(
                    (cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Text('${cat.emoji} ${cat.name}', style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedScope = val);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Period Selector Segmented Button
              Text(
                'Cycle Period',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<BudgetPeriod>(
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: BudgetPeriod.weekly, label: Text('Weekly', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: BudgetPeriod.monthly, label: Text('Monthly', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: BudgetPeriod.custom, label: Text('Custom', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (val) => setState(() => _selectedPeriod = val.first),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Date Range Picker (Custom Period)
              if (_selectedPeriod == BudgetPeriod.custom) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          child: Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _endDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          child: Text(
                            _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'Select',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Recurring Toggle
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Auto-Reset Every Cycle', style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
                  subtitle: Text('Resets progress at start of new period', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                  value: _isRecurring,
                  onChanged: (val) => setState(() => _isRecurring = val),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existingBudget != null && widget.onDelete != null)
                    TextButton(
                      onPressed: () async {
                        final confirmed = await NummoDialog.showConfirmDialog(
                          context: context,
                          title: 'Delete Budget',
                          message: 'Are you sure you want to delete budget "${widget.existingBudget!.title}" of ${MoneyFormatter.format(widget.existingBudget!.amount)}?',
                          confirmText: 'Delete',
                          isDestructive: true,
                        );
                        if (confirmed && context.mounted) {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        }
                      },
                      child: const Text('Delete', style: TextStyle(color: AppColors.debitRed, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: isValid ? _save : null,
                    child: const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
