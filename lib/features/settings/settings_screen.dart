import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../core/utils/money_formatter.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_card.dart';
import '../../design_system/components/nummo_button.dart';
import '../../design_system/components/nummo_dialog.dart';
import '../../design_system/components/category_tag_dialog.dart';
import '../../design_system/components/budget_dialog.dart';
import '../export/export_dialog.dart';

/// Comprehensive settings screen for security, multi-budgets, categories, themes, and backups.
class SettingsScreen extends StatefulWidget {
  final bool isPinEnabled;
  final bool isBioEnabled;
  final String currentAccent;
  final String currentThemeMode;
  final List<CategoryTag> categories;
  final List<Budget> budgets;
  final List<Transaction> transactions;
  final String activeBudgetName;
  final Future<void> Function(BuildContext context, bool enabled) onTogglePin;
  final Future<void> Function(bool enabled) onToggleBio;
  final ValueChanged<String> onSelectAccent;
  final ValueChanged<String> onSelectThemeMode;
  final Future<void> Function(List<CategoryTag> cats) onUpdateCategories;
  final Future<void> Function(List<Budget> budgets) onUpdateBudgets;
  final Future<void> Function(String rawJson, {bool isMerge, String? passphrase}) onImportPayload;
  final Future<void> Function(String rawJson) onExportPayload;
  final Future<void> Function() onResetData;

  const SettingsScreen({
    super.key,
    required this.isPinEnabled,
    required this.isBioEnabled,
    required this.currentAccent,
    required this.currentThemeMode,
    required this.categories,
    required this.budgets,
    required this.transactions,
    required this.activeBudgetName,
    required this.onTogglePin,
    required this.onToggleBio,
    required this.onSelectAccent,
    required this.onSelectThemeMode,
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

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
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
    }
  }

  void _openCategoryDialog([CategoryTag? existing]) {
    CategoryTagDialog.show(
      context,
      existingCategory: existing,
      onSave: (cat) async {
        final updated = List<CategoryTag>.from(widget.categories);
        if (existing != null) {
          final idx = updated.indexWhere((c) => c.id == existing.id);
          if (idx != -1) updated[idx] = cat;
        } else {
          updated.add(cat);
        }
        await widget.onUpdateCategories(updated);
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
      },
      onDelete: existing == null ? null : () => _confirmDeleteBudget(existing),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
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
    }
  }

  Future<void> _launchUrl(String urlString) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Page Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Settings & Preferences',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 1. Security & Biometrics Section
            _buildHeader('SECURITY'),
            NummoCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('4-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: widget.isPinEnabled ? AppColors.creditGreen : AppColors.textSecondary(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.isPinEnabled ? 'Protection Active' : 'Protection Disabled',
                                    style: TextStyle(
                                      color: widget.isPinEnabled ? AppColors.creditGreen : AppColors.textSecondary(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!widget.isPinEnabled)
                        FilledButton.icon(
                          icon: const Icon(Icons.shield_rounded, size: 16),
                          label: const Text('Set PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          onPressed: () async => await widget.onTogglePin(context, true),
                        )
                      else
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
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
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.isPinEnabled ? AppColors.creditGreenBg : AppColors.cardBorder(context).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: widget.isPinEnabled ? AppColors.creditGreen : AppColors.textSecondary(context),
                          size: 20,
                        ),
                      ),
                      title: const Text('Biometric Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        !widget.isPinEnabled
                            ? 'Set Security PIN to activate Biometrics'
                            : widget.isBioEnabled
                                ? 'Fingerprint & Face Unlock Active'
                                : 'Unlock app using device biometrics',
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                      ),
                      value: widget.isBioEnabled,
                      onChanged: widget.isPinEnabled ? (val) async => await widget.onToggleBio(val) : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Budgets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader('BUDGETS BY CATEGORY'),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _openBudgetDialog(),
                ),
              ],
            ),
            if (widget.budgets.isEmpty)
              NummoCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No budgets configured. Tap + Add Budget to create one.', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                ),
              )
            else
              ...widget.budgets.map((b) {
                final cat = widget.categories.firstWhere(
                  (c) => c.id.toLowerCase() == b.scope.toLowerCase() || c.name.toLowerCase() == b.scope.toLowerCase(),
                  orElse: () => CategoryTag.defaults.last,
                );
                final isOverall = b.scope == 'overall';

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: NummoCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isOverall
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                                : cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(isOverall ? '🎯' : cat.emoji, style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                '${b.periodLabel} • ${isOverall ? 'All Categories' : cat.name}',
                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(b.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Budget',
                          onPressed: () => _openBudgetDialog(b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.debitRed),
                          tooltip: 'Delete Budget',
                          onPressed: () => _confirmDeleteBudget(b),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppSpacing.lg),

            // 3. Category Tags & Emojis Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader('CATEGORY TAGS'),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _openCategoryDialog(),
                ),
              ],
            ),
            NummoCard(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: widget.categories.map((c) {
                  return InkWell(
                    onTap: () => _openCategoryDialog(c),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: c.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            c.name,
                            style: TextStyle(color: c.color, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 4. Appearance & Theme Studio Section
            _buildHeader('APPEARANCE & THEME STUDIO'),
            _buildThemeStudioCard(),
            const SizedBox(height: AppSpacing.lg),

            // 5. Data Backup & Restore Section
            _buildHeader('DATA BACKUP & RESTORE'),
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
                            Text(
                              '100% Offline & Private Data',
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nummo operates 100% offline with zero cloud tracking. Your financial transactions and budgets remain stored exclusively on your device. Export JSON backups to transfer your data securely.',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12,
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
                    title: const Text('Export Statement (PDF & Excel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Export formatted PDF reports & Excel CSV logs', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      ExportDialog.show(
                        context,
                        transactions: widget.transactions,
                        budgetName: widget.activeBudgetName,
                      );
                    },
                  ),
                  const Divider(height: 1),
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
                    title: const Text('Export JSON Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Export transactions and settings to JSON file', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      await widget.onExportPayload('EXPORT');
                    },
                  ),
                  const Divider(height: 1),
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
                    title: const Text('Import JSON Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Restore or merge transactions from JSON file', style: TextStyle(fontSize: 12)),
                    onTap: _pickAndImportFile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 6. Danger Zone / Reset
            NummoButton(
              text: 'Reset All Local Data',
              variant: NummoButtonVariant.destructive,
              onPressed: _confirmReset,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 7. Developer Information Card
            _buildHeader('DEVELOPER INFORMATION'),
            NummoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'K Rajtilak',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 16,
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(
                        Icons.language_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    title: const Text(
                      'Website',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'krajtilak.in',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => _launchUrl('https://krajtilak.in'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(
                        Icons.code_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    title: const Text(
                      'GitHub Profile',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'rajtilak-2020',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => _launchUrl('https://github.com/rajtilak-2020'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 8. App Version & Updates (Bottom-most section)
            _buildHeader('APP VERSION & UPDATES'),
            NummoCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    ),
                    title: const Text('Nummo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      _packageInfo != null
                          ? 'Version ${_packageInfo!.version} (Build ${_packageInfo!.buildNumber})\nPackage: ${_packageInfo!.packageName}'
                          : 'Version 1.0.0 (Build 1)\nPackage: com.krajtilak.nummo',
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    ),
                    title: const Text('Check GitHub Releases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Download latest in-place release APK updates', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                    onTap: () => _launchUrl('https://github.com/rajtilak-2020/Nummo/releases'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeStudioCard() {
    final primaryColor = AppColors.resolveAccentColor(widget.currentAccent);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Live Interactive Theme Preview Card
        NummoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'THEME PREVIEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      widget.currentAccent.startsWith('#')
                          ? widget.currentAccent.toUpperCase()
                          : widget.currentAccent,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Mini mock UI card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '₹42,850.00',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.creditGreenBg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.creditGreen),
                              SizedBox(width: 2),
                              Text(
                                '₹5,000',
                                style: TextStyle(
                                  color: AppColors.creditGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.65,
                        minHeight: 6,
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🛒', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                'Shopping',
                                style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: null,
                          icon: Icon(Icons.add_rounded, size: 14, color: primaryColor.computeLuminance() > 0.4 ? Colors.black : Colors.white),
                          label: Text(
                            'Add Entry',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
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
        const SizedBox(height: AppSpacing.md),

        // Single Combined Theme Mode & Accents Card
        NummoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('THEME MODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _buildThemeModeCard('system', 'System', 'Auto OS', Icons.brightness_auto_rounded)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _buildThemeModeCard('light', 'Light', 'Warm Slate', Icons.wb_sunny_rounded)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _buildThemeModeCard('dark', 'Dark', 'Charcoal', Icons.dark_mode_rounded)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ACCENT PRESETS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3)),
                  TextButton.icon(
                    onPressed: _openCustomColorPicker,
                    icon: const Icon(Icons.color_lens_outlined, size: 16),
                    label: const Text('Custom Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
                  final swatches = AppColors.accentSwatches.entries.toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 60,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: swatches.length,
                    itemBuilder: (context, index) {
                      final e = swatches[index];
                      return _buildAccentCard(e.key, e.value);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeCard(String modeValue, String title, String subtitle, IconData icon) {
    final isSel = widget.currentThemeMode == modeValue;
    final primaryColor = AppColors.resolveAccentColor(widget.currentAccent);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectThemeMode(modeValue);
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? primaryColor.withValues(alpha: 0.1) : AppColors.surfaceCard(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSel ? primaryColor : AppColors.cardBorder(context),
            width: isSel ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: isSel ? primaryColor : AppColors.textSecondary(context)),
                if (isSel)
                  Icon(Icons.check_circle_rounded, size: 16, color: primaryColor)
                else
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder(context), width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  color: isSel ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary(context).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentCard(String swatchName, Color color) {
    final isSel = widget.currentAccent == swatchName;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectAccent(swatchName);
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.12) : AppColors.surfaceCard(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSel ? color : AppColors.cardBorder(context),
            width: isSel ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: isSel ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                swatchName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  color: isSel ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
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
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Color Studio',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
              content: Column(
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

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
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
