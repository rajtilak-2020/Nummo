import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../tokens.dart';
import 'nummo_dialog.dart';

/// Uber-grade, modern, and polished modal dialog for creating or editing financial budget targets.
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

  /// Presents the modal as a smooth, beautifully animated dialog.
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(curve);
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
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
  String? _selectedScope; // 'overall' or category id/name (null if not yet selected)
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
      text: b != null ? (b.amount == b.amount.roundToDouble() ? b.amount.toStringAsFixed(0) : b.amount.toStringAsFixed(2)) : '',
    );
    _selectedScope = b?.scope;
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
    if (rawTitle.isEmpty || rawAmount <= 0 || _selectedScope == null) {
      HapticFeedback.heavyImpact();
      return;
    }

    final budget = Budget(
      id: widget.existingBudget?.id,
      title: rawTitle,
      amount: rawAmount,
      scope: _selectedScope!,
      period: _selectedPeriod,
      startDate: _startDate,
      endDate: _endDate,
      isRecurring: _isRecurring,
    );

    HapticFeedback.mediumImpact();
    widget.onSave(budget);
    Navigator.of(context).pop();
  }

  CategoryTag? _resolveCategory(String? scope) {
    if (scope == null || scope == 'overall') return null;
    return CategoryTag.fromIdOrName(scope, widget.categories);
  }

  Widget _buildPeriodOption({
    required BuildContext context,
    required BudgetPeriod period,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedPeriod == period;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPeriod = period);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? activeColor.withValues(alpha: 0.18) : activeColor.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.6), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? activeColor : AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawTitle = _titleController.text.trim();
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final hasSelectedScope = _selectedScope != null;
    final canSave = rawTitle.isNotEmpty && rawAmount > 0 && hasSelectedScope;

    final selectedCat = _resolveCategory(_selectedScope);
    final isOverall = _selectedScope == 'overall';
    final primaryAccent = Theme.of(context).colorScheme.primary;
    final activeColor = hasSelectedScope
        ? (isOverall ? primaryAccent : (selectedCat?.color ?? primaryAccent))
        : primaryAccent;
    final activeEmoji = hasSelectedScope
        ? (isOverall ? '🌐' : (selectedCat?.emoji ?? '🎯'))
        : '🎯';

    final previewTitle = rawTitle.isEmpty ? 'Target Title' : rawTitle;
    final previewAmountText = rawAmount > 0 ? MoneyFormatter.format(rawAmount) : '${MoneyFormatter.currencySymbol} 0';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height - bottomInset - topPadding - 32;
    final maxSheetHeight = availableHeight.clamp(200.0, MediaQuery.of(context).size.height * 0.9);

    final periodLabel = _selectedPeriod == BudgetPeriod.weekly
        ? 'Weekly'
        : _selectedPeriod == BudgetPeriod.monthly
            ? 'Monthly'
            : 'Custom Period';

    return Container(
      width: 440,
      margin: EdgeInsets.fromLTRB(16, topPadding + 12, 16, bottomInset > 0 ? bottomInset + 12 : 16),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262A36) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle & Close Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.track_changes_rounded,
                            size: 17,
                            color: activeColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingBudget != null ? 'Edit Budget' : 'Add Budget',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Set a spending ceiling for your expenses',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF202330) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Live Preview Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? activeColor.withValues(alpha: 0.12)
                      : activeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: activeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: activeColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Text(
                        activeEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: activeColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(color: activeColor.withValues(alpha: 0.35), width: 0.8),
                                  ),
                                  child: Text(
                                    hasSelectedScope
                                        ? '$periodLabel • ${isOverall ? 'All Categories' : (selectedCat?.name ?? 'Category')}'
                                        : '$periodLabel • Select Category Scope',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: activeColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'LIMIT',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          previewAmountText,
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Inputs: Title & Amount in a 2-Column Responsive Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TARGET TITLE',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _amountFocusNode.requestFocus(),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            hintText: 'e.g. Monthly Limit',
                            hintStyle: TextStyle(color: AppColors.textSecondary(context).withValues(alpha: 0.6), fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            prefixIcon: Icon(Icons.bookmark_outline_rounded, color: activeColor, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIMIT AMOUNT',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary(context),
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            prefixText: '${MoneyFormatter.currencySymbol} ',
                            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Scope Selection (Horizontal Scrollable Pills)
              Text(
                'APPLICABLE CATEGORY SCOPE',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Overall Option
                    _buildScopeChip(
                      context: context,
                      scopeKey: 'overall',
                      label: '🌐 All Categories (Overall)',
                      color: primaryAccent,
                      isSelected: _selectedScope == 'overall',
                    ),
                    const SizedBox(width: 6),
                    // Category List
                    ...widget.categories.map((c) {
                      final isSelected = _selectedScope != null &&
                          (_selectedScope!.toLowerCase() == c.id.toLowerCase() ||
                              _selectedScope!.toLowerCase() == c.name.toLowerCase());
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildScopeChip(
                          context: context,
                          scopeKey: c.id,
                          label: '${c.emoji} ${c.name}',
                          color: c.color,
                          isSelected: isSelected,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Period Selector
              Text(
                'BUDGET CYCLE',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14161F) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    _buildPeriodOption(
                      context: context,
                      period: BudgetPeriod.weekly,
                      label: 'Weekly',
                      icon: Icons.calendar_view_week_rounded,
                      activeColor: activeColor,
                    ),
                    _buildPeriodOption(
                      context: context,
                      period: BudgetPeriod.monthly,
                      label: 'Monthly',
                      icon: Icons.calendar_month_rounded,
                      activeColor: activeColor,
                    ),
                    _buildPeriodOption(
                      context: context,
                      period: BudgetPeriod.custom,
                      label: 'Custom',
                      icon: Icons.date_range_rounded,
                      activeColor: activeColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Date Range Picker (Only if Custom Period)
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
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
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
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(_endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'Select', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Recurring Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14161F) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.autorenew_rounded, size: 16, color: activeColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Reset Each Cycle',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Clears spent progress at the start of next cycle',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isRecurring,
                      activeTrackColor: activeColor,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _isRecurring = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.existingBudget != null && widget.onDelete != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final confirmed = await NummoDialog.showConfirmDialog(
                          context: context,
                          title: 'Delete Budget',
                          message:
                              'Are you sure you want to delete budget "${widget.existingBudget!.title}" of ${MoneyFormatter.format(widget.existingBudget!.amount)}?',
                          confirmText: 'Delete',
                          isDestructive: true,
                        );
                        if (confirmed && context.mounted) {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        }
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: AppColors.debitRed, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: canSave
                                  ? activeColor
                                  : (isDark ? const Color(0xFF262A36) : const Color(0xFFE2E8F0)),
                              foregroundColor: canSave
                                  ? (activeColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                                  : AppColors.textSecondary(context).withValues(alpha: 0.5),
                              elevation: 0,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: canSave ? _save : null,
                            child: Text(
                              widget.existingBudget != null ? 'Update Budget' : 'Save Budget',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip({
    required BuildContext context,
    required String scopeKey,
    required String label,
    required Color color,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedScope = scopeKey);
      },
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.12))
              : (isDark ? const Color(0xFF181A24) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textPrimary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
