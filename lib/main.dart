import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models.dart';
import 'analytics.dart';
import 'calculator.dart';
import 'settings.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Nummo by K Rajtilak',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Transaction> _transactions = [];
  double _balance = 0.0;
  bool _isLoading = true;
  List<String> _tags = ['FOOD', 'SHOPPING', 'OTHERS'];

  // Security variables
  bool _isLocalAuthEnabled = false;
  String? _savedPin;
  bool _isLocked = false;
  final LocalAuthentication _auth = LocalAuthentication();
  String _enteredPin = '';

  // Timeline Filter State
  TimelineFilter _selectedFilter = TimelineFilter.thisMonth;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1, 0, 0, 0);
  DateTime _endDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month),
      23,
      59,
      59,
      999);

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    WidgetsBinding.instance.addObserver(this);
    _loadSecuritySettings().then((_) {
      if (_isLocalAuthEnabled) {
        setState(() {
          _isLocked = true;
        });
        _authenticateDevice();
      }
    });
    _loadTags().then((_) => _loadTransactions());
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case TimelineFilter.thisMonth:
        _startDate = DateTime(now.year, now.month, 1, 0, 0, 0, 0, 0);
        final days = DateUtils.getDaysInMonth(now.year, now.month);
        _endDate = DateTime(now.year, now.month, days, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.thisYear:
        _startDate = DateTime(now.year, 1, 1, 0, 0, 0, 0, 0);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.allTime:
        _startDate = DateTime(1970, 1, 1, 0, 0, 0, 0, 0);
        _endDate = DateTime(2100, 12, 31, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.custom:
        break;
    }
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: _selectedFilter == TimelineFilter.custom
            ? _startDate
            : now.subtract(const Duration(days: 30)),
        end: _selectedFilter == TimelineFilter.custom ? _endDate : now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = TimelineFilter.custom;
        _startDate = DateTime(
            picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day,
            23, 59, 59, 999);
      });
    }
  }

  List<Transaction> _getFilteredTransactions() {
    return _transactions.where((tx) {
      final t = tx.timestamp;
      return (t.isAfter(_startDate) || t.isAtSameMomentAs(_startDate)) &&
          (t.isBefore(_endDate) || t.isAtSameMomentAs(_endDate));
    }).toList();
  }

  String _getRangeLabel() {
    if (_selectedFilter == TimelineFilter.allTime) {
      return 'All Time Ledger';
    }
    final format = DateFormat('dd MMM yyyy');
    return '${format.format(_startDate)} - ${format.format(_endDate)}';
  }

  Widget _buildFilterChip(TimelineFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (filter == TimelineFilter.custom) {
          _selectCustomRange();
        } else {
          setState(() {
            _selectedFilter = filter;
            _updateDateRange();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : AppColors.cardBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : AppColors.textSecondary(context),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isLocalAuthEnabled) {
        setState(() {
          _isLocked = true;
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isLocalAuthEnabled = prefs.getBool('local_auth_enabled') ?? false;
        _savedPin = prefs.getString('app_pin');
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _saveSecuritySettings(bool enabled, String? pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('local_auth_enabled', enabled);
      if (pin != null) {
        await prefs.setString('app_pin', pin);
      } else {
        await prefs.remove('app_pin');
      }
      setState(() {
        _isLocalAuthEnabled = enabled;
        _savedPin = pin;
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _authenticateDevice() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (_savedPin == null && (canCheck || isSupported)) {
        final bool authenticated = await _auth.authenticate(
          localizedReason: 'AUTHENTICATE TO UNLOCK NUMMO',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        if (authenticated) {
          setState(() {
            _isLocked = false;
          });
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  Widget _buildLockScreen() {
    final showPinPad = _savedPin != null;
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'logo/nummo.svg',
              height: 48,
              width: 48,
              fit: BoxFit.contain,
              placeholderBuilder: (BuildContext context) => Icon(
                Icons.account_balance_wallet,
                color: theme.colorScheme.onSurface,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NUMMO',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _savedPin != null ? 'ENTER PIN TO UNLOCK' : 'APP LOCKED',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (showPinPad) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final hasChar = _enteredPin.length > index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: hasChar
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.onSurface,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 36),
              Table(
                children: [
                  TableRow(children: [
                    _buildKeypadButton('1'),
                    _buildKeypadButton('2'),
                    _buildKeypadButton('3'),
                  ]),
                  TableRow(children: [
                    _buildKeypadButton('4'),
                    _buildKeypadButton('5'),
                    _buildKeypadButton('6'),
                  ]),
                  TableRow(children: [
                    _buildKeypadButton('7'),
                    _buildKeypadButton('8'),
                    _buildKeypadButton('9'),
                  ]),
                  TableRow(children: [
                    _buildKeypadButton('CLEAR'),
                    _buildKeypadButton('0'),
                    _buildKeypadButton('BACK'),
                  ]),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _authenticateDevice,
                icon: const Icon(Icons.fingerprint),
                label: const Text(
                  'UNLOCK WITH BIOMETRICS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String val) {
    final theme = Theme.of(context);
    final debitColor = AppColors.debit(context);

    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (val == 'CLEAR') {
                  _enteredPin = '';
                } else if (val == 'BACK') {
                  if (_enteredPin.isNotEmpty) {
                    _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
                  }
                } else {
                  if (_enteredPin.length < 4) {
                    _enteredPin += val;
                    if (_enteredPin.length == 4) {
                      if (_enteredPin == _savedPin) {
                        _isLocked = false;
                        _enteredPin = '';
                      } else {
                        _enteredPin = '';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'INCORRECT PIN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: debitColor,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    }
                  }
                }
              });
            },
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(
                val,
                style: TextStyle(
                  color: (val == 'CLEAR' || val == 'BACK')
                      ? AppColors.textSecondary(context)
                      : theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSecuritySetupDialog() {
    final debitColor = AppColors.debit(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'SECURITY SETTINGS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLocalAuthEnabled
                        ? 'Security lock is currently enabled.'
                        : 'Secure your Nummo ledger with a device lock or PIN code.',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLocalAuthEnabled) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: debitColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDisableVerificationDialog();
                      },
                      child: const Text(
                        'DISABLE SECURITY LOCK',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ] else ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        _setupDeviceBiometrics();
                      },
                      child: const Text(
                        'USE DEVICE BIOMETRICS / LOCK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showSetupPinDialog();
                      },
                      child: const Text(
                        'SET 4-DIGIT PIN CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setupDeviceBiometrics() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        _showErrorSnackBar('BIOMETRICS NOT SUPPORTED ON THIS DEVICE');
        return;
      }
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'CONFIRM IDENTITY TO ENABLE SECURITY',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        await _saveSecuritySettings(true, null);
        _showSuccessSnackBar('DEVICE LOCK ENABLED SUCCESSFULLY');
      } else {
        _showErrorSnackBar('AUTHENTICATION FAILED');
      }
    } catch (e) {
      _showErrorSnackBar('ERROR SETTING UP DEVICE LOCK: $e');
    }
  }

  void _showSetupPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'SETUP 4-DIGIT PIN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'ENTER PIN',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.length != 4) {
                      return 'PIN MUST BE 4 DIGITS';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'CONFIRM PIN',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value != pinController.text) {
                      return 'PIN DO NOT MATCH';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newPin = pinController.text;
                  await _saveSecuritySettings(true, newPin);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSuccessSnackBar('PIN SECURITY ENABLED SUCCESSFULLY');
                }
              },
              child: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDisableVerificationDialog() {
    if (_savedPin != null) {
      final pinController = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final debitColor = AppColors.debit(context);

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'VERIFY PIN TO DISABLE',
              style: TextStyle(
                color: debitColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'ENTER CURRENT PIN',
                  counterText: '',
                ),
                validator: (value) {
                  if (value != _savedPin) {
                    return 'INCORRECT PIN';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: debitColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await _saveSecuritySettings(false, null);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showSuccessSnackBar('SECURITY LOCK DISABLED');
                  }
                },
                child: const Text(
                  'DISABLE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    } else {
      _saveSecuritySettings(false, null);
      _showSuccessSnackBar('SECURITY LOCK DISABLED');
    }
  }

  void _showErrorSnackBar(String msg) {
    final debitColor = AppColors.debit(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: debitColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    final creditColor = AppColors.credit(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: creditColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _loadTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? storedTags = prefs.getStringList('custom_tags');
      if (storedTags != null) {
        setState(() {
          _tags = storedTags;
        });
      } else {
        await prefs.setStringList('custom_tags', _tags);
      }
    } catch (e) {
      // Keep defaults
    }
  }

  Future<void> _saveTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_tags', _tags);
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('transactions');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        List<Transaction> loaded =
            decoded.map((item) => Transaction.fromJson(item)).toList();

        loaded.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        _recalculateRunningBalances(loaded);
      } else {
        setState(() {
          _transactions = [];
          _balance = 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _transactions = [];
        _balance = 0.0;
        _isLoading = false;
      });
    }
  }

  void _recalculateRunningBalances(List<Transaction> list) {
    double runningBalance = 0.0;
    for (var tx in list) {
      if (tx.isCredit) {
        runningBalance += tx.amount;
      } else {
        runningBalance -= tx.amount;
      }
      tx.balanceAfter = runningBalance;
    }

    setState(() {
      _transactions = list;
      _balance = runningBalance;
      _isLoading = false;
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr =
        jsonEncode(_transactions.map((tx) => tx.toJson()).toList());
    await prefs.setString('transactions', jsonStr);
  }

  Future<void> _addTransaction(
      double amount, bool isCredit, String note, String? tag) async {
    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      isCredit: isCredit,
      note: note.trim().isEmpty ? 'Untitled' : note.trim(),
      timestamp: DateTime.now(),
      tag: isCredit ? null : tag,
    );

    List<Transaction> updated = [..._transactions, newTx];
    updated.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _recalculateRunningBalances(updated);
    await _saveTransactions();
  }

  Future<void> _editTransaction(
      String id, double amount, bool isCredit, String note, String? tag) async {
    List<Transaction> updated = _transactions.map((tx) {
      if (tx.id == id) {
        return Transaction(
          id: tx.id,
          amount: amount,
          isCredit: isCredit,
          note: note.trim().isEmpty ? 'Untitled' : note.trim(),
          timestamp: tx.timestamp,
          tag: isCredit ? null : tag,
        );
      }
      return tx;
    }).toList();

    updated.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _recalculateRunningBalances(updated);
    await _saveTransactions();
  }

  Future<void> _deleteTransaction(String id) async {
    List<Transaction> updated =
        _transactions.where((tx) => tx.id != id).toList();
    updated.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _recalculateRunningBalances(updated);
    await _saveTransactions();
  }

  void _showCreateTagDialog(BuildContext context, Function(String) onCreated) {
    final tagController = TextEditingController();
    final tagFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'CREATE NEW TAG',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          content: Form(
            key: tagFormKey,
            child: TextFormField(
              controller: tagController,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'TAG NAME',
                hintText: 'e.g. TRAVEL',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'TAG NAME REQUIRED';
                }
                final upperTag = value.trim().toUpperCase();
                if (_tags.contains(upperTag)) {
                  return 'TAG ALREADY EXISTS';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (tagFormKey.currentState!.validate()) {
                  final newTag = tagController.text.trim().toUpperCase();
                  setState(() {
                    _tags.add(newTag);
                  });
                  _saveTags();
                  onCreated(newTag);
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'CREATE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddTransactionSheet({required bool isCredit}) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedTag = isCredit ? null : (_tags.isNotEmpty ? _tags[0] : 'FOOD');
    final color = isCredit ? AppColors.credit(context) : AppColors.debit(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCredit ? 'ADD CREDIT' : 'ADD DEBIT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'AMOUNT',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'AMOUNT REQUIRED';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'ENTER A VALID AMOUNT';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'NOTE / LABEL (OPTIONAL)',
                        hintText: 'e.g. Salary, Groceries',
                      ),
                    ),
                    if (!isCredit) ...[
                      const SizedBox(height: 16),
                      Text(
                        'TAG (REQUIRED)',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._tags.map((tag) {
                            final isSelected = selectedTag == tag;
                            return ChoiceChip(
                              label: Text(tag),
                              selected: isSelected,
                              selectedColor: AppColors.debitFill(context),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.debit(context)
                                    : AppColors.textSecondary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.debit(context)
                                      : AppColors.cardBorder(context),
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedTag = tag;
                                  });
                                }
                              },
                            );
                          }),
                          ActionChip(
                            label: const Text('+ ADD TAG'),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.cardBorder(context),
                              ),
                            ),
                            onPressed: () {
                              _showCreateTagDialog(context, (newTag) {
                                setModalState(() {
                                  selectedTag = newTag;
                                });
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          if (!isCredit && selectedTag == null) {
                            _showErrorSnackBar('PLEASE SELECT A TAG');
                            return;
                          }
                          final amount = double.parse(amountController.text);
                          final note = noteController.text.trim();
                          _addTransaction(amount, isCredit, note, selectedTag);
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        isCredit ? 'SAVE CREDIT' : 'SAVE DEBIT',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTransactionSheet(Transaction tx) {
    final amountController =
        TextEditingController(text: tx.amount.toStringAsFixed(2));
    final noteController = TextEditingController(text: tx.note);
    final formKey = GlobalKey<FormState>();
    bool isCredit = tx.isCredit;
    String? selectedTag = tx.tag ?? (_tags.isNotEmpty ? _tags[0] : 'FOOD');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final color = isCredit
                ? AppColors.credit(context)
                : AppColors.debit(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EDIT TRANSACTION',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: const Text('CREDIT (IN)'),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: const Text('DEBIT (OUT)'),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                      selected: {isCredit},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setModalState(() {
                          isCredit = newSelection.first;
                          if (isCredit) {
                            selectedTag = null;
                          } else if (selectedTag == null && _tags.isNotEmpty) {
                            selectedTag = _tags[0];
                          }
                        });
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'AMOUNT',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'AMOUNT REQUIRED';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'ENTER A VALID AMOUNT';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'NOTE / LABEL (OPTIONAL)',
                        hintText: 'e.g. Salary, Groceries',
                      ),
                    ),
                    if (!isCredit) ...[
                      const SizedBox(height: 16),
                      Text(
                        'TAG (REQUIRED)',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._tags.map((tag) {
                            final isSelected = selectedTag == tag;
                            return ChoiceChip(
                              label: Text(tag),
                              selected: isSelected,
                              selectedColor: AppColors.debitFill(context),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.debit(context)
                                    : AppColors.textSecondary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.debit(context)
                                      : AppColors.cardBorder(context),
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedTag = tag;
                                  });
                                }
                              },
                            );
                          }),
                          ActionChip(
                            label: const Text('+ ADD TAG'),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.cardBorder(context),
                              ),
                            ),
                            onPressed: () {
                              _showCreateTagDialog(context, (newTag) {
                                setModalState(() {
                                  selectedTag = newTag;
                                });
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          if (!isCredit && selectedTag == null) {
                            _showErrorSnackBar('PLEASE SELECT A TAG');
                            return;
                          }
                          final amount = double.parse(amountController.text);
                          final note = noteController.text.trim();
                          _editTransaction(
                              tx.id, amount, isCredit, note, selectedTag);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationSheet(Transaction tx) {
    final debitColor = AppColors.debit(context);
    final formattedAmount =
        '${tx.isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}';

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DELETE TRANSACTION?',
                style: TextStyle(
                  color: debitColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        tx.note,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: tx.isCredit
                              ? AppColors.credit(context)
                              : debitColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: debitColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _deleteTransaction(tx.id);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'DELETE',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionRow(Transaction tx) {
    final formattedTime = DateFormat('hh:mm a').format(tx.timestamp);
    final formattedAmount =
        '${tx.isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}';
    final formattedBalance = 'BAL: ₹${tx.balanceAfter.toStringAsFixed(2)}';
    final isCredit = tx.isCredit;
    final color = isCredit ? AppColors.credit(context) : AppColors.debit(context);
    final fillColor = isCredit
        ? AppColors.creditFill(context)
        : AppColors.debitFill(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCredit ? 'CR' : 'DR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        tx.note,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isCredit) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.cardBorder(context),
                          ),
                        ),
                        child: Text(
                          (tx.tag ?? 'OTHERS').toUpperCase(),
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedBalance,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final displayedTransactions = _getFilteredTransactions().reversed.toList();
    final List<Widget> listItems = [];
    String? currentGroupDate;

    for (var i = 0; i < displayedTransactions.length; i++) {
      final tx = displayedTransactions[i];
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.timestamp);
      final headerText =
          DateFormat('EEE, dd MMM yyyy').format(tx.timestamp).toUpperCase();

      if (currentGroupDate != dateStr) {
        currentGroupDate = dateStr;
        listItems.add(
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 6.0),
            child: Text(
              headerText,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }

      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
          child: Card(
            child: SwipeableLogEntry(
              key: ValueKey(tx.id),
              transaction: tx,
              onEdit: () => _showEditTransactionSheet(tx),
              onDelete: () => _showDeleteConfirmationSheet(tx),
              child: _buildTransactionRow(tx),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _isLocked
            ? _buildLockScreen()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'logo/nummo.svg',
                          height: 28,
                          width: 28,
                          fit: BoxFit.contain,
                          placeholderBuilder: (BuildContext context) => Icon(
                            Icons.account_balance_wallet,
                            color: theme.colorScheme.onSurface,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            if (_isLocalAuthEnabled) {
                              setState(() {
                                _isLocked = true;
                                _enteredPin = '';
                              });
                              _authenticateDevice();
                            }
                          },
                          child: const Text(
                            'NUMMO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Calculator Button
                        IconButton(
                          tooltip: 'Calculator',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: AppColors.cardBorder(context),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.calculate_outlined, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CalculatorScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        // Stats Button
                        IconButton(
                          tooltip: 'Analytics',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: AppColors.cardBorder(context),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.analytics_outlined, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AnalyticsScreen(
                                  transactions: _transactions,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        // Settings Button
                        IconButton(
                          tooltip: 'Settings',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: AppColors.cardBorder(context),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  isLocalAuthEnabled: _isLocalAuthEnabled,
                                  onSecuritySetupTap: () {
                                    _showSecuritySetupDialog();
                                  },
                                  onResetApp: () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.clear();
                                    setState(() {
                                      _transactions = [];
                                      _balance = 0.0;
                                      _tags = ['FOOD', 'SHOPPING', 'OTHERS'];
                                      _isLocalAuthEnabled = false;
                                      _savedPin = null;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Timeline Filters Bar (below Navigation Header)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(TimelineFilter.thisMonth, 'THIS MONTH'),
                              const SizedBox(width: 8),
                              _buildFilterChip(TimelineFilter.thisYear, 'THIS YEAR'),
                              const SizedBox(width: 8),
                              _buildFilterChip(TimelineFilter.allTime, 'ALL TIME'),
                              const SizedBox(width: 8),
                              _buildFilterChip(TimelineFilter.custom, 'CUSTOM RANGE'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.cardBorder(context),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getRangeLabel().toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_selectedFilter == TimelineFilter.custom)
                                GestureDetector(
                                  onTap: _selectCustomRange,
                                  child: Text(
                                    'EDIT RANGE',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Analytics Hero Carousel
                  AnalyticsHeroCarousel(
                    filteredTransactions: _getFilteredTransactions(),
                    totalBalance: _balance,
                    startDate: _startDate,
                    endDate: _endDate,
                    selectedFilter: _selectedFilter,
                  ),

                  // Quick Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.credit(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () =>
                                _showAddTransactionSheet(isCredit: true),
                            icon: const Icon(Icons.arrow_downward_rounded),
                            label: const Text(
                              'ADD CREDIT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.debit(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () =>
                                _showAddTransactionSheet(isCredit: false),
                            icon: const Icon(Icons.arrow_upward_rounded),
                            label: const Text(
                              'ADD DEBIT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Transaction List Header / List
                  Expanded(
                    child: listItems.isEmpty
                        ? Center(
                            child: Text(
                              'NO TRANSACTIONS YET',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: listItems.length,
                            itemBuilder: (context, index) {
                              return listItems[index];
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SwipeableLogEntry extends StatefulWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Widget child;

  const SwipeableLogEntry({
    super.key,
    required this.transaction,
    required this.onDelete,
    required this.onEdit,
    required this.child,
  });

  @override
  State<SwipeableLogEntry> createState() => _SwipeableLogEntryState();
}

class _SwipeableLogEntryState extends State<SwipeableLogEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  double _animStart = 0.0;
  double _animEnd = 0.0;
  static const double _actionsWidth = 140.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = _controller.drive(CurveTween(curve: Curves.easeOut));
    _controller.addListener(() {
      setState(() {
        _dragOffset = _animStart + (_animEnd - _animStart) * _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateToOffset(double target) {
    _animStart = _dragOffset;
    _animEnd = target;
    _controller.reset();
    _controller.forward();
  }

  void _close() {
    _animateToOffset(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.primaryDelta!;
            if (_dragOffset < -_actionsWidth) _dragOffset = -_actionsWidth;
            if (_dragOffset > 0) _dragOffset = 0;
          });
        },
        onHorizontalDragEnd: (details) {
          if (_dragOffset < -_actionsWidth / 2) {
            _animateToOffset(-_actionsWidth);
          } else {
            _animateToOffset(0.0);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Row(
                  children: [
                    const Spacer(),
                    if (_dragOffset < 0) ..._buildActionButtons(),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Container(
                color: theme.cardColor,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final debitColor = AppColors.debit(context);
    final theme = Theme.of(context);

    return [
      _buildAction(
        label: 'EDIT',
        color: theme.colorScheme.primary,
        textColor: theme.colorScheme.onPrimary,
        onTap: () {
          _close();
          widget.onEdit();
        },
      ),
      _buildAction(
        label: 'DELETE',
        color: debitColor,
        textColor: Colors.white,
        onTap: () {
          _close();
          widget.onDelete();
        },
      ),
    ];
  }

  Widget _buildAction({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        alignment: Alignment.center,
        color: color,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
