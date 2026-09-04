import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/security/app_lock_guard.dart';
import '../../core/security/biometric_service.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_button.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/category_tag_dialog.dart';
import '../../design_system/components/budget_dialog.dart';
import '../export/export_dialog.dart';
import 'budgets_screen.dart';
import 'category_tags_screen.dart';

/// Comprehensive settings screen for security, multi-budgets, categories, themes, and backups.
class SettingsScreen extends StatefulWidget {
  final bool isPinEnabled;
  final bool isBioEnabled;
  final bool isFingerprintEnabled;
  final String currentAccent;
  final String currentThemeMode;
  final String currentCurrency;
  final int autoLockDelaySeconds;
  final List<CategoryTag> categories;
  final List<Budget> budgets;
  final List<Transaction> transactions;
  final String activeBudgetName;
  final Future<void> Function(BuildContext context, bool enabled) onTogglePin;
  final Future<bool> Function(bool enabled) onToggleBio;
  final Future<bool> Function(bool enabled)? onToggleFingerprint;
  final ValueChanged<String> onSelectAccent;
  final ValueChanged<String> onSelectThemeMode;
  final ValueChanged<String>? onSelectCurrency;
  final ValueChanged<int>? onSelectAutoLockDelay;
  final Future<void> Function(List<CategoryTag> cats) onUpdateCategories;
  final Future<void> Function(List<Budget> budgets) onUpdateBudgets;
  final Future<void> Function(String rawJson, {bool isMerge, String? passphrase}) onImportPayload;
  final Future<void> Function(String rawJson) onExportPayload;
  final Future<void> Function() onResetData;

  const SettingsScreen({
    super.key,
    required this.isPinEnabled,
    required this.isBioEnabled,
    this.isFingerprintEnabled = false,
    required this.currentAccent,
    required this.currentThemeMode,
    this.currentCurrency = 'INR',
    this.autoLockDelaySeconds = 0,
    required this.categories,
    required this.budgets,
    required this.transactions,
    required this.activeBudgetName,
    required this.onTogglePin,
    required this.onToggleBio,
    this.onToggleFingerprint,
    required this.onSelectAccent,
    required this.onSelectThemeMode,
    this.onSelectCurrency,
    this.onSelectAutoLockDelay,
    required this.onUpdateCategories,
    required this.onUpdateBudgets,
    required this.onImportPayload,
    required this.onExportPayload,
    required this.onResetData,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _hasFingerprintHardware = false;
  final BiometricService _biometricService = BiometricService();

  // Cached aggregation metrics to eliminate rebuild & scroll stutters
  double _cachedTotalSpent = 0;
  double _cachedTotalLimit = 0;
  double _cachedBudgetRatio = 0;
  bool _cachedIsExceeded = false;
  double _cachedBudgetExcess = 0;
  double _cachedBudgetRemaining = 0;
  int _cachedBudgetPercentage = 0;

  int _cachedTagCount = 0;
  int _cachedDebitTagCount = 0;
  int _cachedCreditTagCount = 0;
  int _cachedBothTagCount = 0;
  List<CategoryTag> _cachedPreviewTags = const [];
  int _cachedRemainingTagsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _checkBiometricSupport();
    _recalculateMetrics();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.budgets != oldWidget.budgets ||
        widget.transactions != oldWidget.transactions ||
        widget.categories != oldWidget.categories) {
      _recalculateMetrics();
    }
  }

  void _recalculateMetrics() {
    // 1. Budget Targets calculation
    double spent = 0;
    double limit = 0;
    for (final b in widget.budgets) {
      spent += b.calculateSpent(widget.transactions);
      limit += b.amount;
    }
    _cachedTotalSpent = spent;
    _cachedTotalLimit = limit;
    _cachedBudgetRatio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    _cachedIsExceeded = spent > limit;
    _cachedBudgetExcess = _cachedIsExceeded ? (spent - limit) : 0.0;
    _cachedBudgetRemaining = !_cachedIsExceeded ? (limit - spent) : 0.0;
    _cachedBudgetPercentage = limit > 0 ? ((spent / limit) * 100).round() : 0;

    // 2. Category Tags calculation
    _cachedTagCount = widget.categories.length;
    int debit = 0;
    int credit = 0;
    int both = 0;
    for (final c in widget.categories) {
      if (c.scope == TagScope.debit) {
        debit++;
      } else if (c.scope == TagScope.credit) {
        credit++;
      } else if (c.scope == TagScope.both) {
        both++;
      }
    }
    _cachedDebitTagCount = debit;
    _cachedCreditTagCount = credit;
    _cachedBothTagCount = both;
    _cachedPreviewTags = widget.categories.take(4).toList();
    _cachedRemainingTagsCount = math.max(0, _cachedTagCount - _cachedPreviewTags.length);
  }

  Future<void> _checkBiometricSupport() async {
    if (kIsWeb) return;
    final hasFinger = await _biometricService.isFingerprintAvailable();
    if (mounted) {
      setState(() {
        _hasFingerprintHardware = hasFinger;
      });
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _packageInfo = info);
      }
    } catch (_) {}
  }

  Future<void> _confirmDeleteCategory(CategoryTag category) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Category Tag',
      message: 'Are you sure you want to delete category tag "${category.emoji} ${category.name}"?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      final updated = widget.categories.where((item) => item.id != category.id).toList();
      await widget.onUpdateCategories(updated);
      _recalculateMetrics();
      if (mounted) {
        NummoToast.success(context, message: 'Deleted category "${category.name}"');
      }
    }
  }

  void _openCategoryDialog([CategoryTag? existing]) {
    CategoryTagDialog.show(
      context,
      existingCategory: existing,
      existingCategories: widget.categories,
      onSave: (cat) async {
        final updated = List<CategoryTag>.from(widget.categories);
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
        await widget.onUpdateCategories(updated);
        _recalculateMetrics();
      },
      onDelete: existing == null ? null : () => _confirmDeleteCategory(existing),
    );
  }

  Future<void> _confirmDeleteBudget(Budget b) async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Delete Budget',
      message: 'Are you sure you want to delete budget "${b.title}" of ${MoneyFormatter.format(b.amount)}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      final updated = widget.budgets.where((item) => item.id != b.id).toList();
      await widget.onUpdateBudgets(updated);
      _recalculateMetrics();
      if (mounted) {
        NummoToast.success(context, message: 'Deleted budget "${b.title}"');
      }
    }
  }

  void _openBudgetDialog([Budget? existing]) {
    BudgetDialog.show(
      context,
      existingBudget: existing,
      categories: widget.categories,
      onSave: (b) async {
        final updated = List<Budget>.from(widget.budgets);
        if (existing != null) {
          final idx = updated.indexWhere((item) => item.id == existing.id);
          if (idx != -1) updated[idx] = b;
        } else {
          updated.add(b);
        }
        await widget.onUpdateBudgets(updated);
        _recalculateMetrics();
      },
      onDelete: existing == null ? null : () => _confirmDeleteBudget(existing),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await AppLockGuard.runWithPickerGuard(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true,
        ),
      );
      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        String rawJson = '';
        if (platformFile.bytes != null && platformFile.bytes!.isNotEmpty) {
          rawJson = utf8.decode(platformFile.bytes!);
        } else if (!kIsWeb && platformFile.path != null && platformFile.path!.isNotEmpty) {
          rawJson = await File(platformFile.path!).readAsString();
        } else {
          rawJson = await platformFile.xFile.readAsString();
        }

        if (rawJson.trim().isNotEmpty) {
          await _confirmImportDialog(rawJson.trim());
        }
      }
    } catch (e) {
      if (mounted) {
        NummoToast.show(
          context,
          message: 'Error picking file: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _confirmImportDialog(String rawJson) async {
    bool isEncrypted = false;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic> && decoded['encrypted'] == true) {
        isEncrypted = true;
      }
    } catch (_) {}

    bool isMerge = true;
    final passphraseController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceCard(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            title: const Text('Import Backup File'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEncrypted) ...[
                  const Text(
                    'This backup is password-protected. Enter passphrase:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passphraseController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Backup Passphrase',
                      prefixIcon: Icon(Icons.lock_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Choose import mode:'),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('Merge')),
                    ButtonSegment<bool>(value: false, label: Text('Replace')),
                  ],
                  selected: {isMerge},
                  onSelectionChanged: (val) => setSt(() => isMerge = val.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              NummoButton(
                text: 'Import',
                fullWidth: false,
                onPressed: () async {
                  final passphrase = passphraseController.text.trim();
                  Navigator.of(ctx).pop();
                  await widget.onImportPayload(
                    rawJson,
                    isMerge: isMerge,
                    passphrase: passphrase.isEmpty ? null : passphrase,
                  );
                  _recalculateMetrics();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await NummoDialog.showConfirmDialog(
      context: context,
      title: 'Reset All Data',
      message: 'This will permanently delete all transactions, budgets, categories, and settings. Action is irreversible.',
      confirmText: 'Reset',
      isDestructive: true,
      requireTypedText: 'RESET',
    );
    if (confirmed) {
      await widget.onResetData();
      _recalculateMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text(
                'Settings & Preferences',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).padding.bottom + AppSpacing.bottomNavClearanceCompact,
        ),
        children: [
          // 1. Security & Biometrics Section
          _buildSectionHeader('SECURITY'),
          NummoCard(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isPinEnabled
                            ? AppColors.creditGreenBg
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(
                        widget.isPinEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                        color: widget.isPinEnabled ? AppColors.creditGreen : Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '4-Digit Security PIN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: widget.isPinEnabled ? AppColors.creditGreen : AppColors.textSecondary(context),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  widget.isPinEnabled ? 'Protection Active' : 'Protection Disabled',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.isPinEnabled ? AppColors.creditGreen : AppColors.textSecondary(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isPinEnabled)
                      InkWell(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await widget.onTogglePin(context, true);
                        },
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                size: 13,
                                color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.4
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Set PIN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.4
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.creditGreenBg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.creditGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Manage',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.creditGreen,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: AppColors.creditGreen,
                              ),
                            ],
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) async {
                          if (val == 'change') {
                            await widget.onTogglePin(context, true);
                          } else if (val == 'remove') {
                            final confirmed = await NummoDialog.showConfirmDialog(
                              context: context,
                              title: 'Turn Off Security PIN',
                              message: 'Are you sure you want to remove your PIN lock? Nummo will no longer require a passcode upon app launch.',
                              confirmText: 'Remove PIN',
                              isDestructive: true,
                            );
                            if (confirmed && context.mounted) {
                              await widget.onTogglePin(context, false);
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'change',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Change PIN'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.lock_open_rounded, size: 18, color: AppColors.debitRed),
                                SizedBox(width: 8),
                                Text('Turn Off PIN', style: TextStyle(color: AppColors.debitRed, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!kIsWeb) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                  ),
                  // Fingerprint Unlock Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (widget.isPinEnabled && widget.isFingerprintEnabled)
                              ? AppColors.creditGreenBg
                              : AppColors.cardBorder(context).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: (widget.isPinEnabled && widget.isFingerprintEnabled)
                              ? AppColors.creditGreen
                              : AppColors.textSecondary(context),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fingerprint Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            const SizedBox(height: 1),
                            Text(
                              !widget.isPinEnabled
                                  ? 'Set Security PIN to activate Fingerprint'
                                  : !_hasFingerprintHardware
                                      ? 'Fingerprint not set up on device'
                                      : widget.isFingerprintEnabled
                                          ? 'Unlock app using enrolled fingerprint'
                                          : 'Use fingerprint sensor to unlock Nummo',
                              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      NummoToggleSwitch(
                        value: widget.isFingerprintEnabled,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (widget.isPinEnabled && _hasFingerprintHardware)
                            ? (val) async => await (widget.onToggleFingerprint != null
                                ? widget.onToggleFingerprint!(val)
                                : widget.onToggleBio(val))
                            : null,
                      ),
                    ],
                  ),
                ],
                if (widget.isPinEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                  ),
                  _buildAutoLockDelayTile(),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 2. Budgets Section
          _buildSectionHeader(
            'BUDGET TARGETS',
            count: widget.budgets.length,
            actionLabel: 'Add Target',
            onAction: () => _openBudgetDialog(),
          ),
          _buildBudgetsSummaryTile(),
          const SizedBox(height: AppSpacing.sm),

          // 3. Category Tags Section
          _buildSectionHeader(
            'CATEGORY TAGS',
            count: widget.categories.length,
            actionLabel: 'Add Tag',
            onAction: () => _openCategoryDialog(),
          ),
          _buildCategoryTagsSummaryTile(),
          const SizedBox(height: AppSpacing.sm),

          // 4. Appearance & Theme Studio Section
          _buildSectionHeader('APPEARANCE'),
          _buildThemeStudioCard(),
          const SizedBox(height: AppSpacing.sm),
          _buildCurrencyPreferenceCard(),
          const SizedBox(height: AppSpacing.sm),

          // 5. Data Backup & Restore Section
          _buildSectionHeader('DATA BACKUP & RESTORE'),
          NummoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '100% Offline & Private Data',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nummo operates 100% offline with zero cloud tracking. Your financial transactions and budgets remain stored exclusively on your device. Export JSON backups to transfer your data securely.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.creditGreenBg,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: const Icon(Icons.output_rounded, color: AppColors.creditGreen, size: 20),
                  ),
                  title: const Text('Export Statement (PDF & Excel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Export formatted PDF reports & Excel CSV logs', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    ExportDialog.show(
                      context,
                      transactions: widget.transactions,
                      budgetName: widget.activeBudgetName,
                    );
                  },
                ),
                Divider(height: 1, color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  title: const Text('Export JSON Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Export transactions and settings to JSON file', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () async {
                    await widget.onExportPayload('EXPORT');
                  },
                ),
                Divider(height: 1, color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.creditGreenBg,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: const Icon(Icons.upload_rounded, color: AppColors.creditGreen, size: 20),
                  ),
                  title: const Text('Import JSON Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Restore or merge transactions from JSON file', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: _pickAndImportFile,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 6. Danger Zone / Reset
          _buildSectionHeader('DANGER ZONE'),
          NummoCard(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Irreversible Data Reset',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Permanently erase all transaction logs, custom category tags, budgets, and security preferences from this device.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                NummoButton(
                  text: 'Reset All Local Data',
                  variant: NummoButtonVariant.destructive,
                  onPressed: _confirmReset,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 7. About Information Card
          _buildSectionHeader('ABOUT DEVELOPER & APP'),
          _AboutAndDeveloperCard(packageInfo: _packageInfo),
        ],
      ),
    );
  }

  Widget _buildThemeStudioCard() {
    final featuredPresets = const [
      'Sky Platinum',
      'Emerald Mint',
      'Electric Cyan',
      'Gold Amber',
      'Crimson Rose',
      'Royal Violet',
    ];

    final swatches = featuredPresets.map((name) {
      final color = AppColors.accentSwatches[name] ?? AppColors.resolveAccentColor(name);
      return MapEntry(name, color);
    }).toList();

    final primaryColor = Theme.of(context).colorScheme.primary;

    return NummoCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Segmented Theme Mode Selector (Auto, Light, Dark, Super AMOLED)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.isAmoled(context)
                  ? const Color(0xFF0D0E12)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF13151D)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: AppColors.isAmoled(context)
                  ? Border.all(color: AppColors.cardBorder(context), width: 0.8)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(child: _buildThemeModeSegment('system', 'Auto', Icons.brightness_auto_rounded)),
                Expanded(child: _buildThemeModeSegment('light', 'Light', Icons.wb_sunny_rounded)),
                Expanded(child: _buildThemeModeSegment('dark', 'Dark', Icons.dark_mode_rounded)),
                Expanded(child: _buildThemeModeSegment('amoled', 'AMOLED', Icons.nights_stay_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Accent Presets Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'ACCENT PALETTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openCustomColorPicker,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.palette_outlined, size: 13, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Custom Color',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Responsive 3-column Accent Presets Grid
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildAccentChip(swatches[0].key, swatches[0].value)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildAccentChip(swatches[1].key, swatches[1].value)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildAccentChip(swatches[2].key, swatches[2].value)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildAccentChip(swatches[3].key, swatches[3].value)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildAccentChip(swatches[4].key, swatches[4].value)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildAccentChip(swatches[5].key, swatches[5].value)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeSegment(String modeValue, String label, IconData icon) {
    final isSel = widget.currentThemeMode == modeValue;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onSelectThemeMode(modeValue);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSel ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
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
                color: isSel
                    ? (primaryColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                    : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel
                        ? (primaryColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccentChip(String swatchName, Color color) {
    final isSel = widget.currentAccent == swatchName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onSelectAccent(swatchName);
        },
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: isSel
                ? color.withValues(alpha: isDark ? 0.20 : 0.12)
                : (isDark ? const Color(0xFF181A22) : const Color(0xFFF8F9FA)),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: isSel ? color : AppColors.cardBorder(context),
              width: isSel ? 1.5 : 1.0,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSel ? Border.all(color: Colors.white, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isSel
                    ? const Center(
                        child: Icon(Icons.check, size: 7, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  swatchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? color : AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomColorPicker() {
    final initialColor = AppColors.resolveAccentColor(widget.currentAccent);
    HSVColor initialHsv = HSVColor.fromColor(initialColor);
    if (initialHsv.saturation < 0.05) initialHsv = initialHsv.withSaturation(0.8);

    final List<Color> customPalette = const [
      Color(0xFFE11D48),
      Color(0xFFDB2777),
      Color(0xFF9333EA),
      Color(0xFF7C3AED),
      Color(0xFF4F46E5),
      Color(0xFF2563EB),
      Color(0xFF0284C7),
      Color(0xFF06B6D4),
      Color(0xFF0D9488),
      Color(0xFF10B981),
      Color(0xFF16A34A),
      Color(0xFFD97706),
      Color(0xFFEA580C),
      Color(0xFFDC2626),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        HSVColor currentHsv = initialHsv;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentColor = currentHsv.toColor();
            final hexString = '#${currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

            return AlertDialog(
              backgroundColor: AppColors.surfaceCard(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Custom Color Studio',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: currentColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      hexString,
                      style: TextStyle(
                        color: currentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Interactive Canvas Color Wheel
                    Center(
                      child: SizedBox(
                        width: 190,
                        height: 190,
                        child: ColorWheelCanvas(
                          hue: currentHsv.hue,
                          saturation: currentHsv.saturation,
                          onChanged: (newHsv) {
                            setModalState(() {
                              currentHsv = newHsv.withValue(currentHsv.value);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Brightness Slider
                    Row(
                      children: [
                        Icon(Icons.light_mode_outlined, size: 16, color: AppColors.textSecondary(context)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              activeTrackColor: currentColor,
                              thumbColor: currentColor,
                            ),
                            child: Slider(
                              value: currentHsv.value,
                              min: 0.3,
                              max: 1.0,
                              onChanged: (val) {
                                setModalState(() {
                                  currentHsv = currentHsv.withValue(val);
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Quick Swatches
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: customPalette.map((c) {
                        final isSelected = currentColor.toARGB32() == c.toARGB32();
                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              currentHsv = HSVColor.fromColor(c);
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
                ),
                NummoButton(
                  text: 'Apply Accent',
                  fullWidth: false,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectAccent(hexString);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToBudgetsScreen() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BudgetsScreen(
          budgets: widget.budgets,
          categories: widget.categories,
          transactions: widget.transactions,
          onUpdateBudgets: widget.onUpdateBudgets,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _recalculateMetrics();
      });
    }
  }

  Future<void> _navigateToCategoryTagsScreen() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CategoryTagsScreen(
          categories: widget.categories,
          transactions: widget.transactions,
          onUpdateCategories: widget.onUpdateCategories,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _recalculateMetrics();
      });
    }
  }

  Widget _buildBudgetsSummaryTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (widget.budgets.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToBudgetsScreen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.cardBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                  ),
                  child: Icon(Icons.track_changes_rounded, size: 20, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Targets',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No spending ceilings configured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Setup',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Color statusColor = _cachedIsExceeded
        ? AppColors.debitRed
        : (_cachedBudgetRatio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.creditGreen);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToBudgetsScreen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _cachedIsExceeded
                  ? AppColors.debitRed.withValues(alpha: 0.35)
                  : AppColors.cardBorder(context),
              width: _cachedIsExceeded ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Title/Count + Status Pill + Chevron
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget Targets',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.budgets.length} Active Target${widget.budgets.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Text(
                      _cachedIsExceeded ? 'Exceeded ($_cachedBudgetPercentage%)' : '$_cachedBudgetPercentage% used',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle Row: Total Spent vs Total Ceiling
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL SPENT',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          MoneyFormatter.format(_cachedTotalSpent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _cachedIsExceeded ? AppColors.debitRed : AppColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL CEILING',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          MoneyFormatter.format(_cachedTotalLimit),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: _cachedBudgetRatio,
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF262A36) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 8),

              // Footer: Remaining / Exceeded status & View All
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _cachedIsExceeded
                          ? '+${MoneyFormatter.format(_cachedBudgetExcess)} over ceiling'
                          : '${MoneyFormatter.format(_cachedBudgetRemaining)} remaining',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cachedIsExceeded ? AppColors.debitRed : (_cachedBudgetRatio >= 0.85 ? const Color(0xFFF59E0B) : AppColors.creditGreen),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: primaryColor),
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

  Widget _buildCategoryTagsSummaryTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_cachedTagCount == 0) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToCategoryTagsScreen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.cardBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                  ),
                  child: const Text('🏷️', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Tags',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No category tags configured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Configure',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToCategoryTagsScreen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.cardBorder(context)),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Title + Count Pill + Chevron
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: const Text('🏷️', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Tags',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_cachedTagCount Tags ($_cachedDebitTagCount Debit, $_cachedCreditTagCount Credit${_cachedBothTagCount > 0 ? ', $_cachedBothTagCount Shared' : ''})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Text(
                      '$_cachedTagCount tags',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Preview chips row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._cachedPreviewTags.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: c.color.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_cachedRemainingTagsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262A36) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '+$_cachedRemainingTagsCount more',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer: Scope summary & "Manage All" hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Customize emojis, colors & scopes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage All',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: primaryColor),
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

  Widget _buildSectionHeader(
    String title, {
    int? count,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onAction();
              },
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoLockDelayTile() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentSeconds = widget.autoLockDelaySeconds;
    String delayLabel;
    switch (currentSeconds) {
      case 60:
        delayLabel = '1 Minute';
        break;
      case 300:
        delayLabel = '5 Minutes';
        break;
      case 900:
        delayLabel = '15 Minutes';
        break;
      case 0:
      default:
        delayLabel = 'Immediately';
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Icon(
            Icons.timer_outlined,
            color: primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Auto-Lock Delay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 1),
              Text(
                'Lock app when placed in background',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
              ),
            ],
          ),
        ),
        PopupMenuButton<int>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  delayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: primaryColor,
                ),
              ],
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onSelected: (val) {
            HapticFeedback.selectionClick();
            widget.onSelectAutoLockDelay?.call(val);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 0, child: Text('Immediately (Recommended)')),
            PopupMenuItem(value: 60, child: Text('After 1 Minute')),
            PopupMenuItem(value: 300, child: Text('After 5 Minutes')),
            PopupMenuItem(value: 900, child: Text('After 15 Minutes')),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyPreferenceCard() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final curr = CurrencyConfig.fromCodeOrSymbol(widget.currentCurrency);

    return NummoCard(
      padding: const EdgeInsets.all(12.0),
      child: InkWell(
        onTap: () => _openCurrencyPicker(context),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  curr.symbol,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Primary Currency',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      curr.name,
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      curr.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded, size: 14, color: primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCurrencyPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    final currentCode = widget.currentCurrency;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: AppColors.surfaceCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder(ctx)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(ctx).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.currency_exchange_rounded, color: Theme.of(ctx).colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Select Currency',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary(ctx),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(ctx), size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: CurrencyConfig.availableCurrencies.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, color: AppColors.cardBorder(ctx).withValues(alpha: 0.5)),
                    itemBuilder: (ctx, index) {
                      final curr = CurrencyConfig.availableCurrencies[index];
                      final isSelected = curr.code.toUpperCase() == currentCode.toUpperCase();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15)
                                : AppColors.scaffoldBackground(ctx),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : AppColors.cardBorder(ctx),
                            ),
                          ),
                          child: Text(
                            curr.symbol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isSelected ? Theme.of(ctx).colorScheme.primary : AppColors.textPrimary(ctx),
                            ),
                          ),
                        ),
                        title: Text(
                          curr.name,
                          style: TextStyle(
                            color: AppColors.textPrimary(ctx),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          curr.code,
                          style: TextStyle(
                            color: AppColors.textSecondary(ctx),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          widget.onSelectCurrency?.call(curr.code);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Interactive Canvas Color Wheel Widget
class ColorWheelCanvas extends StatelessWidget {
  final double hue;
  final double saturation;
  final ValueChanged<HSVColor> onChanged;

  const ColorWheelCanvas({
    super.key,
    required this.hue,
    required this.saturation,
    required this.onChanged,
  });

  void _handleTouch(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    double angleRad = math.atan2(dy, dx);
    double angleDeg = (angleRad * 180.0 / math.pi);
    if (angleDeg < 0) angleDeg += 360.0;

    double dist = math.sqrt(dx * dx + dy * dy);
    double sat = (dist / radius).clamp(0.0, 1.0);

    onChanged(HSVColor.fromAHSV(1.0, angleDeg, sat, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (details) => _handleTouch(details.localPosition, size),
          onPanUpdate: (details) => _handleTouch(details.localPosition, size),
          onTapDown: (details) => _handleTouch(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _ColorWheelPainter(hue: hue, saturation: saturation),
          ),
        );
      },
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;

  _ColorWheelPainter({required this.hue, required this.saturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Draw Sweep Gradient Hue Spectrum
    const sweepGradient = SweepGradient(
      colors: [
        Color(0xFFFF0000),
        Color(0xFFFFFF00),
        Color(0xFF00FF00),
        Color(0xFF00FFFF),
        Color(0xFF0000FF),
        Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ],
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    // 2. Draw Radial White Overlay for Saturation
    final radialGradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final satPaint = Paint()
      ..shader = radialGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, satPaint);

    // 3. Draw Selector Ring Thumb
    final angleRad = (hue * math.pi) / 180.0;
    final dist = saturation * radius;
    final selectorOffset = Offset(
      center.dx + dist * math.cos(angleRad),
      center.dy + dist * math.sin(angleRad),
    );

    // Shadow
    canvas.drawCircle(
      selectorOffset,
      12,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Outer Ring
    canvas.drawCircle(
      selectorOffset,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Inner Selected Color Fill
    canvas.drawCircle(
      selectorOffset,
      7,
      Paint()
        ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor()
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.saturation != saturation;
  }
}

const String _githubSvgPath = '''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path fill="currentColor" d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/>
</svg>
''';

Future<void> _launchExternalUrl(String urlString) async {
  try {
    final url = Uri.parse(urlString);
    bool launched = false;
    try {
      launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  } catch (_) {}
}

class _AboutAndDeveloperCard extends StatelessWidget {
  final PackageInfo? packageInfo;

  const _AboutAndDeveloperCard({required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF181717);

    final versionText = packageInfo != null
        ? 'Version ${packageInfo!.version} (Build ${packageInfo!.buildNumber})'
        : 'Version 1.1.5 (Build 1)';

    return NummoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Developer Info Row (First)
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: ClipOval(
                  child: Image.asset(
                    'logo/memoji.png',
                    width: 44,
                    height: 44,
                    cacheWidth: 132,
                    cacheHeight: 132,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'K Rajtilak',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creator & Developer of Nummo',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Website',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _launchExternalUrl('https://krajtilak.in');
                    },
                    icon: Image.asset(
                      'logo/website.png',
                      width: 28,
                      height: 28,
                      cacheWidth: 84,
                      cacheHeight: 84,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'GitHub (rajtilak-2020)',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _launchExternalUrl('https://github.com/rajtilak-2020');
                    },
                    icon: SvgPicture.string(
                      _githubSvgPath,
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(height: 1),
          ),
          // 2. App Info Row (Second)
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.asset(
                    'logo/nummo.png',
                    width: 44,
                    height: 44,
                    cacheWidth: 132,
                    cacheHeight: 132,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'web/favicon.png',
                      width: 44,
                      height: 44,
                      cacheWidth: 132,
                      cacheHeight: 132,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nummo',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      versionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Website',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _launchExternalUrl('https://nummo.krajtilak.in/about.html');
                    },
                    icon: Icon(
                      Icons.language_rounded,
                      size: 28,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Privacy Policy',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _launchExternalUrl('https://nummo.krajtilak.in/privacy-policy.html');
                    },
                    icon: Icon(
                      Icons.shield_outlined,
                      size: 28,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'GitHub Repository',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _launchExternalUrl('https://github.com/rajtilak-2020/Nummo');
                    },
                    icon: SvgPicture.string(
                      _githubSvgPath,
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NummoToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const NummoToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDisabled = onChanged == null;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.4 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: value
                ? activeColor
                : (isDark ? const Color(0xFF262A36) : const Color(0xFFCBD5E1)),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
