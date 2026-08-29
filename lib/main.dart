import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/transaction.dart';
import 'models/category.dart';
import 'models/budget.dart';
import 'core/storage/secure_storage_repository.dart';
import 'core/storage/backup_service.dart';
import 'core/security/biometric_service.dart';
import 'core/security/app_lock_guard.dart';
import 'design_system/tokens.dart';
import 'design_system/components/animations.dart';
import 'features/ledger/home_swipe_view.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/security/lock_screen.dart';
import 'features/ledger/add_transaction_sheet.dart';
import 'features/calculator/calculator_sheet.dart';
import 'features/export/file_saver.dart';
import 'design_system/components/pin_setup_dialog.dart';
import 'design_system/components/pin_verify_dialog.dart';
import 'design_system/components/android_app_prompt_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Nummo Uncaught Framework Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Nummo Uncaught Platform Error: $error\n$stack');
    return true;
  };

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const NummoApp());
}

class NummoApp extends StatefulWidget {
  const NummoApp({super.key});

  @override
  State<NummoApp> createState() => _NummoAppState();
}

class _NummoAppState extends State<NummoApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final SecureStorageRepository _repository = SecureStorageRepository();
  final BiometricService _biometricService = BiometricService();

  void _showToast(
    String message, {
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final navState = _navigatorKey.currentState;
    final overlayState = navState?.overlay;
    final ctx = _navigatorKey.currentContext ?? navState?.context;
    if (overlayState != null && ctx != null) {
      NummoToast.showWithOverlay(
        overlayState,
        ctx,
        message: message,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      );
    } else if (ctx != null) {
      NummoToast.show(
        ctx,
        message: message,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      );
    } else {
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger != null) {
        NummoToast.showWithMessenger(
          messenger,
          message: message,
          type: type,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
        );
      }
    }
  }

  int _currentIndex = 0;
  bool _isInitializing = true;
  bool _isLocked = false;
  bool _isPinEnabled = false;
  bool _isBioEnabled = false;
  bool _isFingerprintEnabled = false;
  bool _isPrivacyMode = false;

  String _currentAccent = 'Indigo Slate';
  String _currentThemeMode = 'system';

  List<Transaction> _transactions = [];
  List<CategoryTag> _categories = CategoryTag.defaults;
  List<Budget> _budgets = [];

  AnalyticsPeriodFilter _analyticsFilter = AnalyticsPeriodFilter.thisMonth;
  DateTime _analyticsParticularDay = DateTime.now();
  DateTime _analyticsCustomStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _analyticsCustomEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isPinEnabled && !AppLockGuard.isPickerActive) {
      _dismissModalsAndLock();
    }
  }

  void _dismissModalsAndLock() {
    if (!_isPinEnabled) return;
    if (_navigatorKey.currentState != null && _navigatorKey.currentState!.canPop()) {
      _navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
    if (!_isLocked) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _initialize() async {
    try {
      await _repository.migrateLegacyStorageIfNeeded();

      final results = await Future.wait([
        _repository.isPinEnabled(),
        _repository.isFingerprintEnabled(),
        _repository.loadPrivacyMode(),
        _repository.loadAccentPreset(),
        _repository.loadThemeMode(),
        _repository.loadTransactions(),
        _repository.loadCategories(),
        _repository.loadBudgets(),
      ]);

      final pinEnabled = results[0] as bool;
      final fingerEnabled = results[1] as bool;
      final privacyMode = results[2] as bool;
      final accent = (results[3] as String?) ?? 'Indigo Slate';
      final themeMode = (results[4] as String?) ?? 'system';
      final txns = results[5] as List<Transaction>;
      final cats = results[6] as List<CategoryTag>;
      final budgets = results[7] as List<Budget>;

      if (mounted) {
        setState(() {
          _isPinEnabled = pinEnabled;
          _isFingerprintEnabled = kIsWeb ? false : fingerEnabled;
          _isBioEnabled = kIsWeb ? false : fingerEnabled;
          _isPrivacyMode = privacyMode;
          _isLocked = pinEnabled;
          _currentAccent = accent;
          _currentThemeMode = themeMode;
          _transactions = txns;
          _categories = cats;
          _budgets = budgets;
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });

        if (kIsWeb && !_isPinEnabled) {
          _checkAndPromptAndroidApp();
        }
      }
    }
  }

  Future<void> _checkAndPromptAndroidApp() async {
    if (!kIsWeb) return;
    final hasSeen = await _repository.hasSeenAndroidPrompt();
    if (!hasSeen && mounted) {
      await _repository.setHasSeenAndroidPrompt();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _navigatorKey.currentContext != null) {
          AndroidAppPromptDialog.show(_navigatorKey.currentContext!);
        }
      });
    }
  }

  // --- Async CRUD Operations ---

  Future<void> _handleAddTransaction(Transaction txn) async {
    final updated = List<Transaction>.from(_transactions)..add(txn);
    await _repository.saveTransactions(updated);
    final reloaded = await _repository.loadTransactions();
    setState(() => _transactions = reloaded);
  }

  Future<void> _handleUpdateTransaction(Transaction txn) async {
    final index = _transactions.indexWhere((t) => t.id == txn.id);
    if (index != -1) {
      final updated = List<Transaction>.from(_transactions);
      updated[index] = txn;
      await _repository.saveTransactions(updated);
      final reloaded = await _repository.loadTransactions();
      setState(() => _transactions = reloaded);
    }
  }

  Future<void> _handleDeleteTransaction(String id) async {
    final updated = _transactions.where((t) => t.id != id).toList();
    await _repository.saveTransactions(updated);
    final reloaded = await _repository.loadTransactions();
    setState(() => _transactions = reloaded);
  }

  Future<void> _handleTogglePin(BuildContext targetContext, bool enable) async {
    if (enable) {
      final pin = await PinSetupDialog.show(targetContext);
      if (pin != null && pin.length == 4) {
        await _repository.setPin(pin);
        setState(() => _isPinEnabled = true);

        // Check if biometrics is supported and prompt to enable right after PIN setup!
        final canAuth = await _biometricService.canAuthenticate();
        if (canAuth && !_isBioEnabled && targetContext.mounted) {
          await _promptEnableBiometrics(targetContext);
        }
      }
    } else {
      // Require current 4-digit PIN verification to remove PIN and biometric lock!
      final verified = await PinVerifyDialog.show(
        context: targetContext,
        onVerifyPin: (pin) => _repository.verifyPin(pin),
        title: 'Turn Off Security PIN',
        subtitle: 'Enter your current 4-digit PIN to remove app security lock',
      );

      if (verified == true) {
        await _repository.clearPin();
        await _repository.setFingerprintEnabled(false);
        await _repository.setBiometricsEnabled(false);
        setState(() {
          _isPinEnabled = false;
          _isFingerprintEnabled = false;
          _isBioEnabled = false;
          _isLocked = false;
        });
        _showToast(
          'Security PIN and Biometric unlock turned off.',
          type: ToastType.info,
          icon: Icons.lock_open_rounded,
        );
      }
    }
  }

  Future<void> _promptEnableBiometrics(BuildContext context) async {
    if (kIsWeb) return;
    HapticFeedback.lightImpact();
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: AppColors.creditGreen, size: 24),
            const SizedBox(width: 8),
            Text(
              'Enable Fingerprint Unlock?',
              style: TextStyle(color: AppColors.textPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Would you like to unlock Nummo instantly using your device Fingerprint?',
          style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.fingerprint_rounded, size: 18),
            label: const Text('Yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (enable == true) {
      await _handleToggleBio(true);
    }
  }

  Future<bool> _handleToggleFingerprint(bool enabled) async {
    if (kIsWeb) return false;
    final isAvail = await _biometricService.isFingerprintAvailable();
    if (!isAvail) {
      _showToast(
        'Fingerprint unlock is not available or enrolled on this device',
        type: ToastType.warning,
        icon: Icons.fingerprint_rounded,
      );
      return false;
    }

    final reason = enabled
        ? 'Scan fingerprint to activate Fingerprint Unlock'
        : 'Scan fingerprint to confirm disabling Fingerprint Unlock';

    final authenticated = await _biometricService.authenticateBiometricOnly(reason: reason);

    if (!authenticated) {
      _showToast(
        enabled
            ? 'Biometric verification failed. Fingerprint unlock not enabled.'
            : 'Biometric verification failed. Fingerprint unlock remains active.',
        type: ToastType.error,
        icon: Icons.fingerprint_rounded,
      );
      return false;
    }

    await _repository.setFingerprintEnabled(enabled);
    setState(() {
      _isFingerprintEnabled = enabled;
      _isBioEnabled = enabled;
    });

    _showToast(
      enabled ? 'Fingerprint unlock enabled successfully!' : 'Fingerprint unlock disabled.',
      type: enabled ? ToastType.success : ToastType.info,
      icon: Icons.fingerprint_rounded,
    );
    return true;
  }

  Future<bool> _handleToggleBio(bool enabled) async {
    return await _handleToggleFingerprint(enabled);
  }

  Future<void> _handleSelectAccent(String swatchName) async {
    setState(() => _currentAccent = swatchName);
    await _repository.saveAccentPreset(swatchName);
  }

  Future<void> _handleSelectThemeMode(String mode) async {
    setState(() => _currentThemeMode = mode);
    await _repository.saveThemeMode(mode);
  }

  Future<void> _handleCreateCategory(CategoryTag newCat) async {
    final updated = List<CategoryTag>.from(_categories);
    if (!updated.any((c) => c.name.toLowerCase() == newCat.name.toLowerCase())) {
      updated.add(newCat);
      await _handleUpdateCategories(updated);
    }
  }

  Future<void> _handleUpdateCategories(List<CategoryTag> cats) async {
    await _repository.saveCategories(cats);
    setState(() => _categories = cats);
  }

  Future<void> _handleUpdateBudgets(List<Budget> budgets) async {
    await _repository.saveBudgets(budgets);
    setState(() => _budgets = budgets);
  }

  Future<void> _handleExportPayload(String dummy) async {
    try {
      final payload = BackupService.createBackupPayload(
        transactions: _transactions,
        categories: _categories,
        budgets: _budgets,
        preferences: {
          'accent': _currentAccent,
          'themeMode': _currentThemeMode,
        },
      );

      final bytes = Uint8List.fromList(utf8.encode(payload));
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'Nummo_Export_$timestamp.json';
      final success = await downloadExportFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/json',
      );

      if (mounted) {
        _showToast(
          success ? 'Backup saved successfully!' : 'Backup export cancelled',
          type: success ? ToastType.success : ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Failed to save backup file: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleImportPayload(String rawJson, {bool isMerge = true, String? passphrase}) async {
    final restored = BackupService.parseAndValidateBackup(rawInput: rawJson, passphrase: passphrase);
    if (restored == null) {
      if (mounted) {
        _showToast(
          'Invalid or encrypted backup payload file (check passphrase)',
          type: ToastType.error,
        );
      }
      return;
    }

    final txns = restored['transactions'] as List<Transaction>;
    final cats = restored['categories'] as List<CategoryTag>;
    final budgets = restored['budgets'] as List<Budget>;
    final prefs = restored['preferences'] as Map<String, String>;

    // Deduplicate transactions by ID
    List<Transaction> finalTxns;
    if (isMerge) {
      final map = <String, Transaction>{};
      for (final t in _transactions) {
        map[t.id] = t;
      }
      for (final t in txns) {
        map[t.id] = t;
      }
      finalTxns = map.values.toList();
    } else {
      finalTxns = txns;
    }

    // Deduplicate categories by ID
    List<CategoryTag> finalCats;
    if (isMerge) {
      final map = <String, CategoryTag>{};
      for (final c in _categories) {
        map[c.id] = c;
      }
      for (final c in cats) {
        map[c.id] = c;
      }
      finalCats = map.values.toList();
    } else {
      finalCats = cats.isEmpty ? CategoryTag.defaults : cats;
    }

    // Deduplicate budgets by ID
    List<Budget> finalBudgets;
    if (isMerge) {
      final map = <String, Budget>{};
      for (final b in _budgets) {
        map[b.id] = b;
      }
      for (final b in budgets) {
        map[b.id] = b;
      }
      finalBudgets = map.values.toList();
    } else {
      finalBudgets = budgets;
    }

    await _repository.saveTransactions(finalTxns);
    await _repository.saveCategories(finalCats);
    await _repository.saveBudgets(finalBudgets);

    String newAccent = _currentAccent;
    String newThemeMode = _currentThemeMode;
    if (prefs.containsKey('accent')) {
      newAccent = prefs['accent']!;
      await _repository.saveAccentPreset(newAccent);
    }
    if (prefs.containsKey('themeMode')) {
      newThemeMode = prefs['themeMode']!;
      await _repository.saveThemeMode(newThemeMode);
    }

    final reloaded = await _repository.loadTransactions();
    setState(() {
      _transactions = reloaded;
      _categories = finalCats;
      _budgets = finalBudgets;
      _currentAccent = newAccent;
      _currentThemeMode = newThemeMode;
    });

    if (mounted) {
      _showToast(
        'Backup restored successfully! (${restored['transactionCount']} transactions, ${restored['categoryCount']} categories)',
        type: ToastType.success,
      );
    }
  }

  Future<void> _handleTogglePrivacyMode(bool isMasked) async {
    setState(() => _isPrivacyMode = isMasked);
    await _repository.savePrivacyMode(isMasked);
  }

  Future<void> _handleResetData() async {
    await _repository.clearAllData();
    setState(() {
      _transactions = [];
      _categories = CategoryTag.defaults;
      _budgets = [];
      _isPinEnabled = false;
      _isBioEnabled = false;
      _isPrivacyMode = false;
      _isLocked = false;
    });
    if (mounted) {
      _showToast(
        'All data reset successfully',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.resolveAccentColor(_currentAccent);

    ThemeMode mode = ThemeMode.system;
    if (_currentThemeMode == 'light') mode = ThemeMode.light;
    if (_currentThemeMode == 'dark' || _currentThemeMode == 'amoled') mode = ThemeMode.dark;

    final lightTheme = AppTheme.buildTheme(brightness: Brightness.light, primaryAccent: primaryColor);
    final darkTheme = AppTheme.buildTheme(
      brightness: Brightness.dark,
      primaryAccent: primaryColor,
      isAmoled: _currentThemeMode == 'amoled',
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Nummo',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Stack(
          children: [
            ?child,
            if (_isLocked && !_isInitializing)
              Positioned.fill(
                child: LockScreen(
                  isBioEnabled: _isBioEnabled,
                  biometricService: _biometricService,
                  onVerifyPin: (pin) => _repository.verifyPin(pin),
                  onSuccess: () {
                    setState(() => _isLocked = false);
                    if (kIsWeb) {
                      _checkAndPromptAndroidApp();
                    }
                  },
                ),
              ),
            if (_isInitializing)
              Positioned.fill(
                child: _NummoSplashScreen(
                  primaryColor: primaryColor,
                  isDark: isDark,
                ),
              ),
          ],
        );
      },
      home: Builder(
        builder: (scaffoldContext) {
          return Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                HomeSwipeView(
                  transactions: _transactions,
                  categories: _categories,
                  budgets: _budgets,
                  isPinEnabled: _isPinEnabled,
                  isPrivacyMode: _isPrivacyMode,
                  onTogglePrivacyMode: _handleTogglePrivacyMode,
                  onLockApp: _dismissModalsAndLock,
                  onAddTransaction: _handleAddTransaction,
                  onUpdateTransaction: _handleUpdateTransaction,
                  onDeleteTransaction: _handleDeleteTransaction,
                  onUpdateBudgets: _handleUpdateBudgets,
                  onUpdateCategories: _handleUpdateCategories,
                  onCreateCategory: _handleCreateCategory,
                ),
                AnalyticsScreen(
                  transactions: _transactions,
                  budget: _budgets.isNotEmpty ? _budgets.first : Budget(title: 'Monthly', amount: 0),
                  categories: _categories,
                  selectedFilter: _analyticsFilter,
                  particularDay: _analyticsParticularDay,
                  customStartDate: _analyticsCustomStartDate,
                  customEndDate: _analyticsCustomEndDate,
                ),
                SettingsScreen(
                  isPinEnabled: _isPinEnabled,
                  isBioEnabled: _isBioEnabled,
                  isFingerprintEnabled: _isFingerprintEnabled,
                  currentAccent: _currentAccent,
                  currentThemeMode: _currentThemeMode,
                  categories: _categories,
                  budgets: _budgets,
                  transactions: _transactions,
                  activeBudgetName: _budgets.any((b) => b.scope == 'overall')
                      ? _budgets.firstWhere((b) => b.scope == 'overall').title
                      : 'Nummo Personal Account',
                  onTogglePin: _handleTogglePin,
                  onToggleBio: _handleToggleBio,
                  onToggleFingerprint: _handleToggleFingerprint,
                  onSelectAccent: _handleSelectAccent,
                  onSelectThemeMode: _handleSelectThemeMode,
                  onUpdateCategories: _handleUpdateCategories,
                  onUpdateBudgets: _handleUpdateBudgets,
                  onImportPayload: _handleImportPayload,
                  onExportPayload: _handleExportPayload,
                  onResetData: _handleResetData,
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomNavigationBar(scaffoldContext),
          );
        },
      ),
    );
  }

  void _openCalculatorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CalculatorSheet(
        initialValue: 0.0,
        showApplyButton: false,
        onApply: (val) {},
      ),
    );
  }

  void _openAddTransactionSheet(BuildContext context, {required bool isCredit, Transaction? existingTransaction}) {
    AddTransactionSheet.show(
      context,
      existingTransaction: existingTransaction,
      initialIsCredit: isCredit,
      availableCategories: _categories,
      onCreateCategory: _handleCreateCategory,
      onUpdateCategories: _handleUpdateCategories,
      onSave: (txn) async => _handleAddTransaction(txn),
    );
  }

  void _openAnalyticsFilterSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor = AppColors.surfaceCard(context);
    final borderColor = AppColors.cardBorder(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(ctx).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Select Time Period',
                        style: TextStyle(
                          color: AppColors.textPrimary(ctx),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(ctx), size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Options List
              ...AnalyticsPeriodFilter.values.map((filter) {
                final isSelected = _analyticsFilter == filter;
                return _buildFilterTile(
                  context: ctx,
                  filter: filter,
                  isSelected: isSelected,
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleAnalyticsFilterSelected(context, filter);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTile({
    required BuildContext context,
    required AnalyticsPeriodFilter filter,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    IconData icon;
    String title;
    String subtitle;

    switch (filter) {
      case AnalyticsPeriodFilter.today:
        icon = Icons.today_rounded;
        title = 'Today';
        subtitle = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
        break;
      case AnalyticsPeriodFilter.particularDay:
        icon = Icons.calendar_today_rounded;
        title = 'Particular Day';
        subtitle = _analyticsFilter == AnalyticsPeriodFilter.particularDay
            ? DateFormat('EEE, dd MMM yyyy').format(_analyticsParticularDay)
            : 'Select a specific date';
        break;
      case AnalyticsPeriodFilter.thisWeek:
        icon = Icons.date_range_rounded;
        title = 'This Week';
        subtitle = 'Current week summary';
        break;
      case AnalyticsPeriodFilter.thisMonth:
        icon = Icons.calendar_month_rounded;
        title = 'This Month';
        subtitle = DateFormat('MMMM yyyy').format(DateTime.now());
        break;
      case AnalyticsPeriodFilter.thisYear:
        icon = Icons.event_note_rounded;
        title = 'This Year';
        subtitle = '${DateTime.now().year} overview';
        break;
      case AnalyticsPeriodFilter.allTime:
        icon = Icons.all_inclusive_rounded;
        title = 'All Time';
        subtitle = 'Complete transaction history';
        break;
      case AnalyticsPeriodFilter.customRange:
        icon = Icons.edit_calendar_rounded;
        title = 'Custom Date Range';
        subtitle = _analyticsFilter == AnalyticsPeriodFilter.customRange
            ? '${DateFormat('dd MMM').format(_analyticsCustomStartDate)} - ${DateFormat('dd MMM').format(_analyticsCustomEndDate)}'
            : 'Select start & end dates';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor.withValues(alpha: 0.35) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.2) : primaryColor.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? primaryColor : textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? primaryColor : textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isSelected ? primaryColor.withValues(alpha: 0.8) : textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAnalyticsFilterSelected(BuildContext context, AnalyticsPeriodFilter filter) async {
    if (filter == AnalyticsPeriodFilter.particularDay) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _analyticsParticularDay,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setState(() {
          _analyticsParticularDay = picked;
          _analyticsFilter = filter;
        });
      }
    } else if (filter == AnalyticsPeriodFilter.customRange) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: _analyticsCustomStartDate, end: _analyticsCustomEndDate),
      );
      if (picked != null) {
        setState(() {
          _analyticsCustomStartDate = picked.start;
          _analyticsCustomEndDate = picked.end;
          _analyticsFilter = filter;
        });
      }
    } else {
      setState(() => _analyticsFilter = filter);
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final cardColor = AppColors.surfaceCard(context);
    final borderColor = AppColors.cardBorder(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final scaffoldBg = AppColors.scaffoldBackground(context);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double bottomMargin = bottomInset > 0 ? bottomInset + 8.0 : 14.0;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldBg.withValues(alpha: 0.0),
              scaffoldBg.withValues(alpha: 0.85),
              scaffoldBg,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomMargin),
        child: Material(
          color: Colors.transparent,
          child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentIndex == 0) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      // Add Credit Button (No '+' icon)
                      Expanded(
                        child: NummoBouncy(
                          scaleFactor: 0.96,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openAddTransactionSheet(context, isCredit: true);
                          },
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.creditGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.creditGreen.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Add Credit',
                              style: TextStyle(
                                color: AppColors.creditGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Calculator Circle Pill Button (In between Credit and Debit)
                      NummoBouncy(
                        scaleFactor: 0.90,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openCalculatorSheet(context);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.calculate_rounded,
                            color: primaryColor,
                            size: 19,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Add Debit Button (No '-' icon)
                      Expanded(
                        child: NummoBouncy(
                          scaleFactor: 0.96,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openAddTransactionSheet(context, isCredit: false);
                          },
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.debitRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Add Debit',
                              style: TextStyle(
                                color: AppColors.debitRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_currentIndex == 1) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: NummoBouncy(
                    scaleFactor: 0.97,
                    onTap: () => _openAnalyticsFilterSheet(context),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: primaryColor,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AnalyticsScreen.getFilterLabel(
                                filter: _analyticsFilter,
                                particularDay: _analyticsParticularDay,
                                customStartDate: _analyticsCustomStartDate,
                                customEndDate: _analyticsCustomEndDate,
                              ),
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      context: context,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      context: context,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings_rounded,
                      label: 'Settings',
                      context: context,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required BuildContext context,
  }) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = AppColors.textSecondary(context);

    return Expanded(
      child: NummoBouncy(
        scaleFactor: 0.92,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? primaryColor : unselectedColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? primaryColor : unselectedColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal, high-end Apple/Uber-grade splash loader for instant launch transition.
class _NummoSplashScreen extends StatelessWidget {
  final Color primaryColor;
  final bool isDark;

  const _NummoSplashScreen({
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF13151B),
              Color(0xFF090A0D),
            ],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: ((scale - 0.94) / 0.06).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: Image.asset(
                          'logo/nummo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.account_balance_wallet_rounded,
                            color: primaryColor,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'NUMMO',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.0,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'TRACK EVERY RUPEE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
