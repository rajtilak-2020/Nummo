import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../design_system/tokens.dart';
import '../../features/ledger/home_swipe_view.dart';
import '../storage/secure_storage_repository.dart';

/// Centralized service managing the Android OS Home Screen widget (2x1 Horizontal Rectangle).
/// Syncs transaction category breakdowns and graphical donut chart analytics without showing expense amounts.
class HomeWidgetService {
  static const String provider2x1 = 'CategoryBreakdownWidget2x1Provider';
  static final SecureStorageRepository _storage = SecureStorageRepository();

  /// Updates the 2x1 Android Home Screen Widget with graphical analytics data
  static Future<void> updateCategoryBreakdownWidget({
    required List<Transaction> transactions,
    List<CategoryTag>? categories,
    HomeCategoryPeriod? period,
    HomeCategoryPeriod? period2x1,
    bool? isMasked,
  }) async {
    // Only execute on supported native mobile platforms
    if (kIsWeb) return;

    try {
      final activePeriod = period2x1 ??
          period ??
          HomeCategoryPeriod.fromString(await _storage.loadWidget2x1Period());

      final effectiveMasked = isMasked ?? await _storage.loadPrivacyMode();

      await _syncWidgetData(
        prefix: 'widget_2x1',
        period: activePeriod,
        transactions: transactions,
        categories: categories,
        isMasked: effectiveMasked,
      );

      // Trigger native AppWidget update
      await HomeWidget.updateWidget(
        name: provider2x1,
        androidName: provider2x1,
      );
    } catch (e) {
      debugPrint('Error updating home widgets: $e');
    }
  }

  static Future<void> _syncWidgetData({
    required String prefix,
    required HomeCategoryPeriod period,
    required List<Transaction> transactions,
    List<CategoryTag>? categories,
    required bool isMasked,
  }) async {
    // 1. Sync category slices across all 5 standard periods so any widget frequency works seamlessly
    String activeChartJson = '[]';
    bool activeHasData = false;

    for (final p in HomeCategoryPeriod.values) {
      final pSpendMap = HomeCategoryBreakdownCard.calculateCategorySpendMap(
        transactions,
        p,
      );
      final pTotalExpense = pSpendMap.values.fold(0.0, (sum, val) => sum + val);
      final pHasData = pSpendMap.isNotEmpty && pTotalExpense > 0;

      final pEntries = pSpendMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<Map<String, dynamic>> pSlicesJson = [];
      for (final entry in pEntries) {
        final catTag = CategoryTag.fromIdOrName(entry.key, categories);
        final ratio = pTotalExpense > 0 ? (entry.value / pTotalExpense) : 0.0;
        final pct = (ratio * 100.0).clamp(0.0, 100.0);
        final hexColor = '#${(catTag.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

        pSlicesJson.add({
          'name': catTag.name,
          'emoji': catTag.emoji,
          'percent': double.parse(pct.toStringAsFixed(1)),
          'color': hexColor,
        });
      }

      final pJsonString = jsonEncode(pSlicesJson);
      await HomeWidget.saveWidgetData<String>('widget_data_${p.name}', pJsonString);
      await HomeWidget.saveWidgetData<bool>('widget_has_data_${p.name}', pHasData);

      if (p == period) {
        activeChartJson = pJsonString;
        activeHasData = pHasData;
      }
    }

    // 2. Save active / fallback period keys for backward compatibility
    await HomeWidget.saveWidgetData<String>('${prefix}_period', period.label);
    await HomeWidget.saveWidgetData<String>('${prefix}_period_name', period.name);
    await HomeWidget.saveWidgetData<bool>('${prefix}_has_data', activeHasData);
    await HomeWidget.saveWidgetData<String>('${prefix}_chart_json', activeChartJson);

    await HomeWidget.saveWidgetData<String>('widget_period', period.label);
    await HomeWidget.saveWidgetData<String>('widget_period_name', period.name);
    await HomeWidget.saveWidgetData<bool>('widget_has_data', activeHasData);
    await HomeWidget.saveWidgetData<String>('widget_chart_json', activeChartJson);
  }

  /// Prompts the Android launcher to pin the 2x1 Category Breakdown widget
  static Future<bool> requestPinWidget2x1() async {
    if (kIsWeb) return false;
    try {
      await HomeWidget.requestPinWidget(
        name: provider2x1,
        androidName: provider2x1,
      );
      return true;
    } catch (e) {
      debugPrint('Error requesting pin 2x1 widget: $e');
      return false;
    }
  }

  /// Default widget pin request (2x1)
  static Future<bool> requestPinWidget() async {
    return await requestPinWidget2x1();
  }

  /// Opens an interactive Bottom Sheet to customize the time range for the widget
  static Future<void> showWidgetPeriodPickerModal(
    BuildContext context, {
    required List<Transaction> transactions,
    List<CategoryTag>? categories,
    VoidCallback? onUpdated,
  }) async {
    final currentSaved = await _storage.loadWidget2x1Period();
    HomeCategoryPeriod currentPeriod = HomeCategoryPeriod.fromString(currentSaved);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard(ctx),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.cardBorder(ctx)),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder(ctx),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Widget Time Range',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(ctx),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Home Screen',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the timeframe for your Android home screen widget.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...HomeCategoryPeriod.values.map((period) {
                    final isSelected = currentPeriod == period;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          setModalState(() => currentPeriod = period);

                          await _storage.saveWidget2x1Period(period.name);
                          await updateCategoryBreakdownWidget(
                            transactions: transactions,
                            categories: categories,
                            period2x1: period,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          onUpdated?.call();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                : AppColors.scaffoldBackground(ctx),
                            borderRadius: BorderRadius.circular(AppRadius.control),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                  : AppColors.cardBorder(ctx),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getPeriodIcon(period),
                                size: 20,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : AppColors.textSecondary(ctx),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  period.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : AppColors.textPrimary(ctx),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static IconData _getPeriodIcon(HomeCategoryPeriod period) {
    switch (period) {
      case HomeCategoryPeriod.today:
        return Icons.today_rounded;
      case HomeCategoryPeriod.thisWeek:
        return Icons.date_range_rounded;
      case HomeCategoryPeriod.thisMonth:
        return Icons.calendar_month_rounded;
      case HomeCategoryPeriod.thisYear:
        return Icons.calendar_today_rounded;
      case HomeCategoryPeriod.allTime:
        return Icons.all_inclusive_rounded;
    }
  }
}
