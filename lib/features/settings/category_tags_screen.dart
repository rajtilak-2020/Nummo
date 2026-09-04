import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/animations.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/category_tag_dialog.dart';

/// Dedicated screen for managing category tags, customizing emojis/colors, and viewing tag usage.
class CategoryTagsScreen extends StatefulWidget {
  final List<CategoryTag> categories;
  final List<Transaction> transactions;
  final Future<void> Function(List<CategoryTag> categories) onUpdateCategories;

  const CategoryTagsScreen({
    super.key,
    required this.categories,
    this.transactions = const [],
    required this.onUpdateCategories,
  });

  @override
  State<CategoryTagsScreen> createState() => _CategoryTagsScreenState();
}

class _CategoryTagsScreenState extends State<CategoryTagsScreen> {
  late List<CategoryTag> _categories;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TagScope? _selectedScopeFilter; // null = All, or TagScope.debit, TagScope.credit, TagScope.both

  @override
  void initState() {
    super.initState();
    _categories = List<CategoryTag>.from(widget.categories);
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (_searchQuery != text) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CategoryTagsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _categories = List<CategoryTag>.from(widget.categories);
    }
  }

  int _getUsageCount(CategoryTag cat) {
    if (widget.transactions.isEmpty) return 0;
    final catId = cat.id.trim().toLowerCase();
    final catName = cat.name.trim().toLowerCase();
    final strippedId = catId.replaceAll('_', '');
    final strippedName = catName.replaceAll(' ', '');

    return widget.transactions.where((t) {
      if (t.tag == null || t.tag!.trim().isEmpty) return false;
      final raw = t.tag!.trim().toLowerCase();
      return raw == catId ||
          raw == catName ||
          raw.replaceAll('_', '') == strippedId ||
          raw.replaceAll(' ', '') == strippedName;
    }).length;
  }

  void _openCategoryDialog([CategoryTag? existing]) {
    CategoryTagDialog.show(
      context,
      existingCategory: existing,
      existingCategories: _categories,
      initialScope: _selectedScopeFilter,
      onSave: (cat) async {
        final updated = List<CategoryTag>.from(_categories);
        if (existing != null) {
          final idx = updated.indexWhere((c) => c.id == existing.id);
          if (idx != -1) updated[idx] = cat;
        } else {
          final clean = cat.name.trim().toLowerCase();
          if (!updated.any((c) =>
              c.name.trim().toLowerCase() == clean ||
              c.id.trim().toLowerCase() == clean ||
              c.id.replaceAll('_', '').toLowerCase() == clean.replaceAll('_', '').replaceAll(' ', ''))) {
            updated.add(cat);
          }
        }
        setState(() => _categories = updated);
        await widget.onUpdateCategories(updated);
      },
      onDelete: existing == null ? null : () => _confirmDeleteCategory(existing),
    );
  }

  Future<void> _confirmDeleteCategory(CategoryTag category) async {
    final usageCount = _getUsageCount(category);
    final usageNote = usageCount > 0
        ? '\n\nNote: Used in $usageCount transaction${usageCount == 1 ? '' : 's'}. Existing records retain their recorded tag.'
        : '';

    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Category Tag',
      message: 'Are you sure you want to delete "${category.emoji} ${category.name}"?$usageNote',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      final updated = _categories.where((item) => item.id != category.id).toList();
      setState(() => _categories = updated);
      await widget.onUpdateCategories(updated);
      if (mounted) {
        NummoToast.success(context, message: 'Deleted category "${category.name}"');
      }
    }
  }

  List<CategoryTag> get _filteredCategories {
    return _categories.where((c) {
      if (_selectedScopeFilter != null && c.scope != _selectedScopeFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchEmoji = c.emoji.contains(q);
        final matchScope = c.scope.shortLabel.toLowerCase().contains(q);
        if (!matchName && !matchEmoji && !matchScope) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildOverviewHeroCard({
    required int totalCount,
    required int debitCount,
    required int creditCount,
    required int bothCount,
    required bool isDark,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder(context)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Title + Total Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: const Text('🏷️', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Category Portfolio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$totalCount Total',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Middle: 3 Stat Blocks (Debit, Credit, Shared)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.debitRedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$debitCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.debitRed,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'DEBIT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.debitRed,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.creditGreenBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.creditGreen.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$creditCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.creditGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'CREDIT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.creditGreen,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$bothCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SHARED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom Hint
          Row(
            children: [
              Icon(
                Icons.auto_graph_rounded,
                size: 13,
                color: AppColors.textSecondary(context).withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tags organize logs, calculate category budgets, and drive analytics.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.cardBorder(context)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.15)
                : const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 13.5,
          color: AppColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: InputBorder.none,
          hintText: 'Search tags by name or emoji...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.65),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary(context),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary(context),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildScopeFilterBar({
    required int totalCount,
    required int debitCount,
    required int creditCount,
    required int bothCount,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    Widget buildPill({
      required String label,
      required int count,
      required bool isSelected,
      required Color accentColor,
      required VoidCallback onTap,
    }) {
      return NummoBouncy(
        scaleFactor: 0.94,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.15)
                : AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.cardBorder(context),
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? accentColor : AppColors.textPrimary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.25)
                      : AppColors.cardBorder(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? accentColor : AppColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            buildPill(
              label: 'All',
              count: totalCount,
              isSelected: _selectedScopeFilter == null,
              accentColor: primaryColor,
              onTap: () => setState(() => _selectedScopeFilter = null),
            ),
            buildPill(
              label: 'Debit',
              count: debitCount,
              isSelected: _selectedScopeFilter == TagScope.debit,
              accentColor: AppColors.debitRed,
              onTap: () => setState(() => _selectedScopeFilter = TagScope.debit),
            ),
            buildPill(
              label: 'Credit',
              count: creditCount,
              isSelected: _selectedScopeFilter == TagScope.credit,
              accentColor: AppColors.creditGreen,
              onTap: () => setState(() => _selectedScopeFilter = TagScope.credit),
            ),
            buildPill(
              label: 'Shared',
              count: bothCount,
              isSelected: _selectedScopeFilter == TagScope.both,
              accentColor: primaryColor,
              onTap: () => setState(() => _selectedScopeFilter = TagScope.both),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryTag c, int usageCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final Color scopeColor;
    final String scopeLabel;
    switch (c.scope) {
      case TagScope.debit:
        scopeColor = AppColors.debitRed;
        scopeLabel = 'Debit';
        break;
      case TagScope.credit:
        scopeColor = AppColors.creditGreen;
        scopeLabel = 'Credit';
        break;
      case TagScope.both:
        scopeColor = primaryColor;
        scopeLabel = 'Shared';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NummoBouncy(
        scaleFactor: 0.98,
        onTap: () => _openCategoryDialog(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.cardBorder(context)),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFF0F172A).withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji Box
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.color.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  c.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Scope / Usage Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Scope Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: scopeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: scopeColor.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            scopeLabel,
                            style: TextStyle(
                              color: scopeColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Usage indicator
                        Flexible(
                          child: Text(
                            usageCount > 0 ? '$usageCount txns' : 'Unused',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: usageCount > 0
                                  ? AppColors.textSecondary(context)
                                  : AppColors.textSecondary(context).withValues(alpha: 0.6),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Color Dot Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Popup Menu for Edit / Delete
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondary(context),
                ),
                tooltip: 'Options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openCategoryDialog(c);
                  } else if (val == 'delete') {
                    _confirmDeleteCategory(c);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit Tag', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.debitRed),
                        SizedBox(width: 10),
                        Text('Delete Tag', style: TextStyle(color: AppColors.debitRed, fontWeight: FontWeight.w600, fontSize: 13)),
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

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.isNotEmpty;
    final hasScopeFilter = _selectedScopeFilter != null;

    return NummoCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSearch ? Icons.search_off_rounded : Icons.label_off_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasSearch
                    ? 'No Matching Tags'
                    : (hasScopeFilter
                        ? 'No ${_selectedScopeFilter!.shortLabel} Tags'
                        : 'No Category Tags Configured'),
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasSearch
                    ? 'No category tags match "$_searchQuery".'
                    : (hasScopeFilter
                        ? 'You do not have any tags with scope "${_selectedScopeFilter!.shortLabel}".'
                        : 'Create category tags to organize and group your expenses and revenues.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (hasSearch) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                      },
                      child: const Text('Clear Search', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Create "$_searchQuery"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                      onPressed: () {
                        final query = _searchQuery;
                        _searchController.clear();
                        _openCategoryDialog(CategoryTag(
                          id: query.toLowerCase().replaceAll(' ', '_'),
                          name: query,
                          emoji: '🏷️',
                          colorValue: Theme.of(context).colorScheme.primary.toARGB32(),
                          scope: _selectedScopeFilter ?? TagScope.debit,
                        ));
                      },
                    ),
                  ],
                ),
              ] else ...[
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Category Tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  onPressed: () => _openCategoryDialog(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _categories.length;
    final debitCount = _categories.where((c) => c.scope == TagScope.debit).length;
    final creditCount = _categories.where((c) => c.scope == TagScope.credit).length;
    final bothCount = _categories.where((c) => c.scope == TagScope.both).length;

    final filtered = _filteredCategories;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text(
                'Category Tags',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'Add Tag',
            onPressed: () => _openCategoryDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).padding.bottom + 80,
        ),
        children: [
          _buildOverviewHeroCard(
            totalCount: totalCount,
            debitCount: debitCount,
            creditCount: creditCount,
            bothCount: bothCount,
            isDark: isDark,
          ),
          _buildSearchBar(),
          _buildScopeFilterBar(
            totalCount: totalCount,
            debitCount: debitCount,
            creditCount: creditCount,
            bothCount: bothCount,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                _selectedScopeFilter == null
                    ? 'ALL CATEGORIES'
                    : '${_selectedScopeFilter!.shortLabel.toUpperCase()} CATEGORIES',
              ),
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${filtered.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map((c) => _buildCategoryCard(c, _getUsageCount(c))),
        ],
      ),
      floatingActionButton: _categories.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openCategoryDialog(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            )
          : null,
    );
  }
}
