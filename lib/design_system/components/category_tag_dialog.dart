import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/category.dart';
import '../tokens.dart';
import 'nummo_dialog.dart';

/// Uber-grade, modern, and spacious modal dialog for creating or editing category tags.
class CategoryTagDialog extends StatefulWidget {
  final CategoryTag? existingCategory;
  final List<CategoryTag>? existingCategories;
  final TagScope? initialScope;
  final ValueChanged<CategoryTag> onSave;
  final VoidCallback? onDelete;

  const CategoryTagDialog({
    super.key,
    this.existingCategory,
    this.existingCategories,
    this.initialScope,
    required this.onSave,
    this.onDelete,
  });

  /// Presents the modal as a smooth, beautifully animated dialog.
  static Future<void> show(
    BuildContext context, {
    CategoryTag? existingCategory,
    List<CategoryTag>? existingCategories,
    TagScope? initialScope,
    required ValueChanged<CategoryTag> onSave,
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
            child: CategoryTagDialog(
              existingCategory: existingCategory,
              existingCategories: existingCategories,
              initialScope: initialScope,
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
    '⚡', '💰', '📱', '🎨', '🍕', '🚴', '💊', '⚽', '🎵', '📚',
  ];

  static const List<String> _allEmojis = [
    '⛽', '🍔', '🛍️', '🚗', '🧾', '🏥', '🎬', '💼', '📈', '☕',
    '🏠', '🍿', '🎮', '🏋️', '✈️', '💡', '🐾', '🎓', '🎁', '🔧',
    '⚡', '💰', '📱', '🎨', '🍕', '🚴', '💊', '⚽', '🎵', '📚',
    '👔', '🛒', '🏖️', '🐕', '🥦', '🍦', '🛠️', '🎫', '💎', '🏷️',
    '🛳️', '🚕', '🍼', '🐶', '🐱', '💻', '📷', '🎧', '🎸',
  ];

  static const List<int> _colorOptions = [
    0xFF10B981, // Emerald Mint
    0xFF06B6D4, // Electric Cyan
    0xFF3B82F6, // Royal Blue
    0xFF4F46E5, // Indigo Slate
    0xFF8B5CF6, // Royal Violet
    0xFFEC4899, // Magenta Pink
    0xFFF43F5E, // Coral Crimson
    0xFFF59E0B, // Amber Gold
    0xFF64748B, // Obsidian Slate
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedEmoji = cat?.emoji ?? '🏷️';
    _selectedColorValue = cat?.colorValue ?? 0xFF10B981;
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
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modalTop)),
          border: Border.all(color: AppColors.cardBorder(ctx)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(ctx).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Emoji Icon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary(ctx),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _allEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = _allEmojis[index];
                  final isSelected = _selectedEmoji == emoji;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedEmoji = emoji);
                      Navigator.of(ctx).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorValue).withValues(alpha: 0.2)
                            : AppColors.scaffoldBackground(ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Color(_selectedColorValue), width: 2)
                            : Border.all(color: AppColors.cardBorder(ctx)),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
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

  bool _isDuplicate(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final existingList = widget.existingCategories ?? CategoryTag.defaults;
    for (final cat in existingList) {
      if (widget.existingCategory != null && cat.id == widget.existingCategory!.id) {
        continue;
      }
      if (cat.name.trim().toLowerCase() == clean ||
          cat.id.trim().toLowerCase() == clean ||
          cat.id.replaceAll('_', '').toLowerCase() == clean.replaceAll('_', '').replaceAll(' ', '')) {
        return true;
      }
    }
    return false;
  }

  void _save() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;
    if (_isDuplicate(rawName)) {
      HapticFeedback.heavyImpact();
      return;
    }

    final tag = CategoryTag(
      id: widget.existingCategory?.id ?? rawName.toUpperCase(),
      name: rawName,
      emoji: _selectedEmoji,
      colorValue: _selectedColorValue,
      scope: _selectedScope,
    );
    HapticFeedback.mediumImpact();
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
              const SizedBox(width: 4),
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
    final rawName = _nameController.text.trim();
    final isDuplicate = _isDuplicate(rawName);
    final canSave = rawName.isNotEmpty && !isDuplicate;
    final previewName = rawName.isEmpty ? 'Tag Preview' : rawName;
    final tagColor = Color(_selectedColorValue);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.of(context).size.height - bottomInset - topPadding - 32;
    final maxSheetHeight = availableHeight.clamp(200.0, MediaQuery.of(context).size.height * 0.9);

    return Container(
      width: 440,
      margin: EdgeInsets.fromLTRB(16, topPadding + 16, 16, bottomInset > 0 ? bottomInset + 16 : 24),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF282C3A) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _selectedEmoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingCategory != null ? 'Edit Category Tag' : 'Create Category Tag',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Customize look & usability',
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textSecondary(context),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Hero Live Tag Preview Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14161F) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tagColor.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _selectedEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _selectedScope == TagScope.debit
                                      ? AppColors.debitRed.withValues(alpha: 0.15)
                                      : _selectedScope == TagScope.credit
                                          ? AppColors.creditGreen.withValues(alpha: 0.15)
                                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                    color: _selectedScope == TagScope.debit
                                        ? AppColors.debitRed.withValues(alpha: 0.35)
                                        : _selectedScope == TagScope.credit
                                            ? AppColors.creditGreen.withValues(alpha: 0.35)
                                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
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
                                    const SizedBox(width: 4),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Section 1: Tag Name Input
              Text(
                'TAG LABEL',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'e.g. Petrol, Salary, Freelance, Groceries',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context).withValues(alpha: 0.6), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon: Icon(
                    Icons.bookmark_outline_rounded,
                    color: isDuplicate ? AppColors.debitRed : tagColor,
                    size: 18,
                  ),
                  suffixIcon: rawName.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => _nameController.clear(),
                        )
                      : null,
                ),
              ),
              if (isDuplicate) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.debitRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Category tag "$rawName" already exists',
                        style: const TextStyle(
                          color: AppColors.debitRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Section 2: Usability Scope Switcher
              Text(
                'SECTION USABILITY',
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
              const SizedBox(height: 16),

              // Section 3: Emoji Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EMOJI ICON',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  InkWell(
                    onTap: _openFullEmojiGrid,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            'All Emojis ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickEmojis.length,
                  itemBuilder: (ctx, idx) {
                    final emoji = _quickEmojis[idx];
                    final isSelected = _selectedEmoji == emoji;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedEmoji = emoji);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tagColor.withValues(alpha: 0.22)
                                : (isDark ? const Color(0xFF14161F) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: tagColor, width: 1.8)
                                : Border.all(color: AppColors.cardBorder(context)),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Section 4: Color Palette
              Text(
                'ACCENT COLOR',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _colorOptions.map((cVal) {
                  final isSel = _selectedColorValue == cVal;
                  final color = Color(cVal);
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedColorValue = cVal);
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSel
                            ? Border.all(
                                color: isDark ? Colors.white : Colors.black87,
                                width: 2.4,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: isSel ? 0.35 : 0.15),
                            blurRadius: isSel ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSel
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.existingCategory != null && widget.onDelete != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () async {
                        final confirmed = await NummoDialog.showConfirmDialog(
                          context: context,
                          title: 'Delete Category Tag',
                          message:
                              'Are you sure you want to delete category tag "${widget.existingCategory!.emoji} ${widget.existingCategory!.name}"?',
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: tagColor,
                          foregroundColor: tagColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: canSave ? _save : null,
                        child: Text(
                          widget.existingCategory != null ? 'Update Tag' : 'Save Tag',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
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
