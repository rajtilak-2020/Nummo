import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/category.dart';
import '../tokens.dart';
import 'nummo_dialog.dart';

/// Compact, sleek, and contrast-balanced top-down modal dialog for creating or editing custom category tags.
class CategoryTagDialog extends StatefulWidget {
  final CategoryTag? existingCategory;
  final TagScope? initialScope;
  final ValueChanged<CategoryTag> onSave;
  final VoidCallback? onDelete;

  const CategoryTagDialog({
    super.key,
    this.existingCategory,
    this.initialScope,
    required this.onSave,
    this.onDelete,
  });

  /// Presents the modal as a smooth top-down sliding dialog from top to bottom.
  static Future<void> show(
    BuildContext context, {
    CategoryTag? existingCategory,
    TagScope? initialScope,
    required ValueChanged<CategoryTag> onSave,
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
            child: CategoryTagDialog(
              existingCategory: existingCategory,
              initialScope: initialScope,
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
  State<CategoryTagDialog> createState() => _CategoryTagDialogState();
}

class _CategoryTagDialogState extends State<CategoryTagDialog> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  late int _selectedColorValue;
  late TagScope _selectedScope;

  final FocusNode _nameFocusNode = FocusNode();

  static const List<String> _quickEmojis = [
    '⛽', '🍔', '🛍️', '🚗', '🧾', '🏥', '🎬', '💼', '📈', '☕',
    '🏠', '🍿', '🎮', '🏋️', '✈️', '💡', '🐾', '🎓', '🎁', '🔧',
  ];

  static const List<String> _allEmojis = [
    '⛽', '🍔', '🛍️', '🚗', '🧾', '🏥', '🎬', '💼', '📈', '☕',
    '🏠', '🍿', '🎮', '🏋️', '✈️', '💡', '🐾', '🎓', '🎁', '🔧',
    '⚡', '💰', '📱', '🎨', '🍕', '🚴', '💊', '⚽', '🎵', '📚',
    '👔', '🛒', '🏖️', '🐕', '🥦', '🍦', '🛠️', '🎫', '💎', '🏷️',
  ];

  static const List<int> _colorOptions = [
    0xFFF59E0B, // Amber
    0xFFF43F5E, // Coral
    0xFF3B82F6, // Blue
    0xFF10B981, // Emerald
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFF4F46E5, // Indigo
    0xFF64748B, // Slate
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedEmoji = cat?.emoji ?? '🏷️';
    _selectedColorValue = cat?.colorValue ?? 0xFF4F46E5;
    _selectedScope = cat?.scope ?? widget.initialScope ?? TagScope.both;

    _nameController.addListener(_update);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  void _update() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openFullEmojiGrid() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Emoji Icon',
                  style: TextStyle(
                    color: AppColors.textPrimary(ctx),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 220,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: _allEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = _allEmojis[index];
                  final isSelected = _selectedEmoji == emoji;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedEmoji = emoji);
                      Navigator.of(ctx).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorValue).withValues(alpha: 0.2)
                            : AppColors.scaffoldBackground(ctx),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Color(_selectedColorValue), width: 2)
                            : Border.all(color: AppColors.cardBorder(ctx)),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;

    final tag = CategoryTag(
      id: widget.existingCategory?.id ?? rawName.toUpperCase(),
      name: rawName,
      emoji: _selectedEmoji,
      colorValue: _selectedColorValue,
      scope: _selectedScope,
    );
    widget.onSave(tag);
    Navigator.of(context).pop();
  }

  Widget _buildScopeOption({
    required BuildContext context,
    required TagScope scope,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedScope == scope;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedScope = scope);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? activeColor.withValues(alpha: 0.18) : activeColor.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.5), width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.08),
                      blurRadius: 6,
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
                size: 13,
                color: isSelected ? activeColor : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
    final rawName = _nameController.text.trim();
    final previewName = rawName.isEmpty ? 'Tag Preview' : rawName;
    final tagColor = Color(_selectedColorValue);

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
                      Icon(Icons.label_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.existingCategory != null ? 'Edit Category Tag' : 'Create Category Tag',
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

              // Live Tag Preview Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground(context),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                alignment: Alignment.center,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tagColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedEmoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              previewName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tagColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedScope == TagScope.debit
                            ? AppColors.debitRed.withValues(alpha: 0.12)
                            : _selectedScope == TagScope.credit
                                ? AppColors.creditGreen.withValues(alpha: 0.12)
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: _selectedScope == TagScope.debit
                              ? AppColors.debitRed.withValues(alpha: 0.3)
                              : _selectedScope == TagScope.credit
                                  ? AppColors.creditGreen.withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedScope == TagScope.debit
                                ? Icons.north_east_rounded
                                : _selectedScope == TagScope.credit
                                    ? Icons.south_west_rounded
                                    : Icons.swap_vert_rounded,
                            size: 11,
                            color: _selectedScope == TagScope.debit
                                ? AppColors.debitRed
                                : _selectedScope == TagScope.credit
                                    ? AppColors.creditGreen
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _selectedScope == TagScope.both ? 'Debit & Credit' : _selectedScope.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _selectedScope == TagScope.debit
                                  ? AppColors.debitRed
                                  : _selectedScope == TagScope.credit
                                      ? AppColors.creditGreen
                                      : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Tag Label Text Input
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Tag Label * (Required)',
                  hintText: 'e.g. Petrol, Salary, Groceries',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Tag Usability Section Switcher
              Text(
                'Usable In / Section',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground(context),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    _buildScopeOption(
                      context: context,
                      scope: TagScope.debit,
                      label: 'Debit',
                      icon: Icons.north_east_rounded,
                      activeColor: AppColors.debitRed,
                    ),
                    _buildScopeOption(
                      context: context,
                      scope: TagScope.credit,
                      label: 'Credit',
                      icon: Icons.south_west_rounded,
                      activeColor: AppColors.creditGreen,
                    ),
                    _buildScopeOption(
                      context: context,
                      scope: TagScope.both,
                      label: 'Both',
                      icon: Icons.swap_vert_rounded,
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Emoji Picker Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Emoji Icon',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: _openFullEmojiGrid,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text('More ', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.grid_view_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Quick Emoji Selector Chips
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickEmojis.length,
                  itemBuilder: (ctx, idx) {
                    final emoji = _quickEmojis[idx];
                    final isSelected = _selectedEmoji == emoji;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? tagColor.withValues(alpha: 0.25) : AppColors.scaffoldBackground(context),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: tagColor, width: 1.5) : Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Color Swatches
              Text(
                'Tag Color',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colorOptions.map((cVal) {
                  final isSel = _selectedColorValue == cVal;
                  return InkWell(
                    onTap: () => setState(() => _selectedColorValue = cVal),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(cVal),
                      child: isSel ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existingCategory != null && widget.onDelete != null)
                    TextButton(
                      onPressed: () async {
                        final confirmed = await NummoDialog.showConfirmDialog(
                          context: context,
                          title: 'Delete Category Tag',
                          message: 'Are you sure you want to delete category tag "${widget.existingCategory!.emoji} ${widget.existingCategory!.name}"?',
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
                    onPressed: rawName.isEmpty ? null : _save,
                    child: const Text('Save Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
