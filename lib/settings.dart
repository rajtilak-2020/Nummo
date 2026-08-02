import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final bool isLocalAuthEnabled;
  final List<String> tags;
  final VoidCallback onSecuritySetupTap;
  final Future<void> Function() onResetApp;
  final Future<void> Function(List<String> updatedTags) onTagsUpdated;

  const SettingsScreen({
    super.key,
    required this.isLocalAuthEnabled,
    required this.tags,
    required this.onSecuritySetupTap,
    required this.onResetApp,
    required this.onTagsUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _resetClickCount = 0;
  DateTime? _lastResetClickTime;
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = List.from(widget.tags);
  }

  void _handleResetTap() {
    final now = DateTime.now();
    if (_lastResetClickTime == null ||
        now.difference(_lastResetClickTime!) > const Duration(seconds: 2)) {
      _resetClickCount = 1;
    } else {
      _resetClickCount++;
    }
    _lastResetClickTime = now;

    if (_resetClickCount >= 5) {
      HapticFeedback.heavyImpact();
      _resetClickCount = 0;
      _showResetAppDialog(context);
    } else {
      HapticFeedback.selectionClick();
      final remaining = 5 - _resetClickCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'YOU ARE NOW $remaining CLICK${remaining > 1 ? 'S' : ''} AWAY FROM RESETTING.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.debit(context), width: 1.5),
          ),
        ),
      );
    }
  }

  void _showAddTagDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF000000),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFF333333), width: 1.5),
          ),
          title: const Text(
            'CREATE NEW TAG',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'TAG NAME',
                labelStyle: TextStyle(color: Color(0xFF888888), fontFamily: 'monospace'),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF444444))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              validator: (value) {
                final tag = value?.trim().toUpperCase();
                if (tag == null || tag.isEmpty) {
                  return 'TAG NAME CANNOT BE EMPTY';
                }
                if (_currentTags.contains(tag)) {
                  return 'TAG "$tag" ALREADY EXISTS';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF888888), fontFamily: 'monospace')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.credit(context),
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  HapticFeedback.mediumImpact();
                  final newTag = controller.text.trim().toUpperCase();
                  setState(() {
                    _currentTags.add(newTag);
                  });
                  await widget.onTagsUpdated(_currentTags);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('TAG "$newTag" ADDED', style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.credit(context),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('ADD TAG', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteTagDialog(BuildContext context, String tagToDelete) {
    final debitColor = AppColors.debit(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF000000),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFF333333), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: debitColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'DELETE TAG "$tagToDelete"',
                  style: TextStyle(
                    color: debitColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete tag "$tagToDelete"?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This tag will be removed from new transaction options. Past transactions tagged as "$tagToDelete" will retain their category info in history & analytics.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF888888), fontFamily: 'monospace')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: debitColor,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                setState(() {
                  _currentTags.remove(tagToDelete);
                });
                await widget.onTagsUpdated(_currentTags);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('TAG "$tagToDelete" DELETED', style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: debitColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        );
      },
    );
  }

  void _showResetAppDialog(BuildContext context) {
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isConfirmEnabled =
                confirmationController.text.trim().toLowerCase() == 'yes delete';
            final debitColor = AppColors.debit(context);

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: debitColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'RESET APP DATA',
                    style: TextStyle(
                      color: debitColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Are you sure you want to completely delete all of your finance logs and settings?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: confirmationController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'TYPE "yes delete" TO CONFIRM',
                        hintText: 'yes delete',
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      validator: (value) {
                        if (value == null ||
                            value.trim().toLowerCase() != 'yes delete') {
                          return 'CONFIRMATION TEXT MISMATCH';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConfirmEnabled
                            ? debitColor
                            : Theme.of(context).disabledColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isConfirmEnabled
                          ? () async {
                              final navigator = Navigator.of(context);
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              await widget.onResetApp();
                              navigator.pop(); // Pop dialog
                              navigator.pop(); // Pop Settings screen
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ALL FINANCE DATA ERASED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: debitColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      child: const Text(
                        'RESET',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, currentMode, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // APPEARANCE SECTION
              _buildSectionHeader(context, 'APPEARANCE'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Theme',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose light, dark, or follow device settings.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {currentMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          HapticFeedback.selectionClick();
                          themeController.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // CATEGORIES & TAGS SECTION
              _buildSectionHeader(context, 'CATEGORIES & TAGS'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Expense Tags',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentTags.length} Active Tags',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: theme.colorScheme.primary, width: 1),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: () => _showAddTagDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'ADD TAG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentTags.map((tag) {
                          return GestureDetector(
                            onLongPress: () => _showDeleteTagDialog(context, tag),
                            child: Chip(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                                side: BorderSide(color: Color(0xFF444444), width: 1),
                              ),
                              backgroundColor: const Color(0xFF111111),
                              label: Text(
                                tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tip: Long press tag chip to delete.',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // SECURITY SECTION
              _buildSectionHeader(context, 'SECURITY'),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.isLocalAuthEnabled
                          ? AppColors.creditFill(context)
                          : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.isLocalAuthEnabled
                          ? Icons.lock_outlined
                          : Icons.lock_open_outlined,
                      color: widget.isLocalAuthEnabled
                          ? AppColors.credit(context)
                          : AppColors.textSecondary(context),
                    ),
                  ),
                  title: const Text(
                    'App Security & PIN Lock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    widget.isLocalAuthEnabled
                        ? (kIsWeb
                            ? 'PIN Protection Active.'
                            : 'PIN Protection Active (Fingerprint fallback enabled).')
                        : 'Protect Nummo with a compulsory 4-digit PIN.',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSecuritySetupTap();
                  },
                ),
              ),

              const SizedBox(height: 28),

              // DANGER ZONE SECTION
              _buildSectionHeader(context, 'DANGER ZONE', isDanger: true),
              const SizedBox(height: 10),
              Card(
                color: AppColors.debitFill(context),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.debit(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.debit(context),
                    ),
                  ),
                  title: Text(
                    'RESET ALL APP DATA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.debit(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  subtitle: Text(
                    'Tap 5 times to confirm reset and erase all transactions & tags.',
                    style: TextStyle(
                      color: AppColors.debit(context).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  onTap: _handleResetTap,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {bool isDanger = false}) {
    final color = isDanger
        ? AppColors.debit(context)
        : AppColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: color,
        ),
      ),
    );
  }
}
