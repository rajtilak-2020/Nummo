import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../core/utils/input_validators.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_button.dart';
import '../../design_system/components/category_tag_dialog.dart';
import '../calculator/calculator_sheet.dart';

/// Clean, robust top sheet dialog for creating or editing transactions with top-to-bottom entrance animation.
class AddTransactionSheet extends StatefulWidget {
  final Transaction? existingTransaction;
  final bool initialIsCredit;
  final List<CategoryTag> availableCategories;
  final Future<void> Function(Transaction txn) onSave;

  const AddTransactionSheet({
    super.key,
    this.existingTransaction,
    this.initialIsCredit = false,
    required this.availableCategories,
    required this.onSave,
  });

  /// Presents the modal as a smooth top-down sliding dialog from top to bottom.
  static Future<T?> show<T>(
    BuildContext context, {
    Transaction? existingTransaction,
    bool initialIsCredit = false,
    required List<CategoryTag> availableCategories,
    required Future<void> Function(Transaction txn) onSave,
  }) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<T>(
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
            child: AddTransactionSheet(
              existingTransaction: existingTransaction,
              initialIsCredit: initialIsCredit,
              availableCategories: availableCategories,
              onSave: onSave,
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
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late bool _isCredit;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  CategoryTag? _selectedCategory;
  late List<CategoryTag> _categories;

  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final txn = widget.existingTransaction;
    _isCredit = txn?.isCredit ?? widget.initialIsCredit;
    _amountController = TextEditingController(
      text: txn != null ? txn.amount.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: txn?.note ?? '');
    _selectedDate = txn?.timestamp ?? DateTime.now();

    _categories = List<CategoryTag>.from(
      widget.availableCategories.isNotEmpty ? widget.availableCategories : CategoryTag.defaults,
    );

    if (txn?.tag != null) {
      _selectedCategory = CategoryTag.fromIdOrName(txn!.tag);
    } else {
      _selectedCategory = null; // No tag selected by default for new entries
    }

    // Auto focus amount input after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _openCalculator() {
    final currentVal = InputValidators.parseAndValidateAmount(_amountController.text) ?? 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CalculatorSheet(
        initialValue: currentVal,
        onApply: (val) {
          setState(() {
            _amountController.text = val.toStringAsFixed(2);
          });
          _noteFocusNode.requestFocus();
        },
      ),
    );
  }

  Future<void> _submit() async {
    final amount = InputValidators.parseAndValidateAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid, positive amount';
      });
      _amountFocusNode.requestFocus();
      return;
    }

    final sanitizedNote = InputValidators.sanitizeNote(_noteController.text);
    if (sanitizedNote.isEmpty) {
      setState(() {
        _errorMessage = 'Note description is required';
      });
      _noteFocusNode.requestFocus();
      return;
    }

    if (!_isCredit && _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Please select a category tag for this expense';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final txn = Transaction(
      id: widget.existingTransaction?.id,
      amount: amount,
      isCredit: _isCredit,
      note: sanitizedNote,
      timestamp: _selectedDate,
      tag: _isCredit ? null : _selectedCategory?.id,
    );

    try {
      await widget.onSave(txn);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save transaction. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTransaction != null;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    // Dynamically calculate visible space above virtual keyboard
    final availableHeight = MediaQuery.of(context).size.height - bottomInset - topPadding - 24;
    final maxSheetHeight = availableHeight.clamp(180.0, MediaQuery.of(context).size.height * 0.85);

    return Container(
      margin: EdgeInsets.fromLTRB(12, topPadding + 8, 12, bottomInset > 0 ? bottomInset + 8 : 12),
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isCredit ? AppColors.creditGreen : AppColors.debitRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing
                            ? (_isCredit ? 'Edit Credit Entry' : 'Edit Debit Entry')
                            : (_isCredit ? 'Add Credit Entry' : 'Add Debit Entry'),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount Input Field (Keyboard action -> Next moves focus to Note)
              TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  _noteFocusNode.requestFocus();
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_rounded),
                    onPressed: _isSaving ? null : _openCalculator,
                    tooltip: 'Open Calculator',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Note Input Field (Required)
              TextField(
                controller: _noteController,
                focusNode: _noteFocusNode,
                enabled: !_isSaving,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Note * (Required)',
                  hintText: 'e.g. Groceries, Rent, Freelance Payment',
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.debitRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Category Selector (Expenses / Debit Only - Compulsory selection)
              if (!_isCredit) ...[
                Text(
                  'Category Tag * (Required)',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ..._categories.map((cat) {
                      final isSelected = _selectedCategory?.id == cat.id;
                      return FilterChip(
                        label: Text('${cat.emoji} ${cat.name}'),
                        selected: isSelected,
                        onSelected: _isSaving
                            ? null
                            : (selected) {
                                setState(() {
                                  _selectedCategory = selected ? cat : null;
                                });
                              },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create Tag'),
                      onPressed: _isSaving
                          ? null
                          : () {
                              CategoryTagDialog.show(
                                context,
                                onSave: (newCat) {
                                  setState(() {
                                    _categories.add(newCat);
                                    _selectedCategory = newCat;
                                  });
                                },
                              );
                            },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Date & Time Picker Button
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_selectedDate),
                        );
                        if (time != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormat('EEE, dd MMM yyyy — hh:mm a').format(_selectedDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Submit Button
              NummoButton(
                text: isEditing ? 'Update Entry' : 'Save Entry',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
