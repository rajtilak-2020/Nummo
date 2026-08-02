import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final bool isLocalAuthEnabled;
  final VoidCallback onSecuritySetupTap;
  final Future<void> Function() onResetApp;

  const SettingsScreen({
    super.key,
    required this.isLocalAuthEnabled,
    required this.onSecuritySetupTap,
    required this.onResetApp,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _resetClickCount = 0;
  DateTime? _lastResetClickTime;

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
