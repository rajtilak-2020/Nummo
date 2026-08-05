import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
                Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
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

            // Security & Biometrics Section
            _buildHeader('SECURITY & APP LOCK'),
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
                              const Text('4-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
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
                                message: 'Are you sure you want to remove your PIN lock? Your ledger will no longer require a passcode upon app launch.',
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
                    title: const Text('Biometrics / Fingerprint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      !widget.isPinEnabled
                          ? 'Set Security PIN above to activate Biometrics'
                          : widget.isBioEnabled
                              ? 'Fingerprint & Face Unlock Active'
                              : 'Unlock app instantly using device biometrics',
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                    ),
                    value: widget.isBioEnabled,
                    onChanged: widget.isPinEnabled ? (val) async => await widget.onToggleBio(val) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Budgets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader('BUDGETS BY CATEGORY'),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Add Budget',
                  onPressed: () => _openBudgetDialog(),
                ),
              ],
            ),
            if (widget.budgets.isEmpty)
              NummoCard(
                child: Text('No budgets configured. Tap + to add one.', style: TextStyle(color: AppColors.textSecondary(context))),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isOverall
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                                : cat.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(isOverall ? '🌐' : cat.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                '${b.periodLabel} • ${isOverall ? 'All Categories' : cat.name}',
                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          MoneyFormatter.format(b.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 15),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _openBudgetDialog(b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.debitRed),
                          onPressed: () => _confirmDeleteBudget(b),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppSpacing.lg),

            // Categories & Emojis Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader('CATEGORY TAGS & EMOJIS'),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Create Custom Tag',
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

            // Appearance Section
            _buildHeader('APPEARANCE & THEME'),
            NummoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: widget.currentThemeMode,
                        underline: const SizedBox(),
                        dropdownColor: AppColors.surfaceCard(context),
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System Default')),
                          DropdownMenuItem(value: 'light', child: Text('Light Mode')),
                          DropdownMenuItem(value: 'dark', child: Text('Dark Mode')),
                        ],
                        onChanged: (val) {
                          if (val != null) widget.onSelectThemeMode(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Accent Swatch', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    children: AppColors.accentSwatches.entries.map((e) {
                      final isSel = widget.currentAccent == e.key;
                      return InkWell(
                        onTap: () => widget.onSelectAccent(e.key),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: e.value,
                          child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // App Version & Updates
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
                      child: Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: const Text('Nummo by K Rajtilak', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      child: Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: const Text('Check GitHub Releases', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Download latest in-place APK updates seamlessly'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () async {
                      final url = Uri.parse('https://github.com/rajtilak-2020/Nummo/releases');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Backup & Recovery
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
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
                          'Why it matters for your privacy:\nNummo operates 100% offline with zero cloud tracking. Your financial transactions and budgets remain stored exclusively on your device. Exporting JSON backups gives you complete ownership to save or transfer your ledger securely whenever you choose.',
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
                      child: const Icon(Icons.output_rounded, color: AppColors.creditGreen),
                    ),
                    title: const Text('Export Statement (PDF & Excel)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export formatted PDF reports & Excel CSV logs'),
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
                      child: Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: const Text('Export JSON Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Export ledger transactions and settings to JSON file'),
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
                      child: const Icon(Icons.upload_rounded, color: AppColors.creditGreen),
                    ),
                    title: const Text('Import JSON Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Restore or merge transactions from JSON file'),
                    onTap: _pickAndImportFile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Danger Zone / Reset
            NummoButton(
              text: 'Reset All Local Data',
              variant: NummoButtonVariant.destructive,
              onPressed: _confirmReset,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
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
