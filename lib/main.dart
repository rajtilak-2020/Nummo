import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'analytics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VITTA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
          error: Color(0xFFFF1E1E),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF808080),
          thickness: 1,
          space: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.black,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF808080), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF808080), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFFFF1E1E), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFFFF1E1E), width: 2),
          ),
          labelStyle: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'monospace'),
          hintStyle: TextStyle(color: Color(0xFF808080), fontFamily: 'monospace'),
          errorStyle: TextStyle(
            color: Color(0xFFFF1E1E),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaction> _transactions = [];
  double _balance = 0.0;
  bool _isLoading = true;
  List<String> _tags = ['FOOD', 'SHOPPING', 'OTHERS'];

  @override
  void initState() {
    super.initState();
    _loadTags().then((_) => _loadTransactions());
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

  Future<void> _addTransaction(double amount, bool isCredit, String note, String? tag) async {
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
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Colors.white, width: 2),
          ),
          title: const Text(
            'CREATE NEW TAG',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          content: Form(
            key: tagFormKey,
            child: TextFormField(
              controller: tagController,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF808080), width: 1.5),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'CREATE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
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
                            color: isCredit
                                ? const Color(0xFF00FF66)
                                : const Color(0xFFFF1E1E),
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
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
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'AMOUNT',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'NOTE / LABEL (OPTIONAL)',
                        hintText: 'e.g. Salary, Groceries',
                      ),
                    ),
                    if (!isCredit) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'TAG (REQUIRED)',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontFamily: 'monospace',
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
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedTag = tag;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF1E1E)
                                      : Colors.black,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF808080),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFAAAAAA),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () {
                              _showCreateTagDialog(context, (newTag) {
                                setModalState(() {
                                  selectedTag = newTag;
                                });
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                '+ ADD TAG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        if (formKey.currentState!.validate()) {
                          if (!isCredit && selectedTag == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PLEASE SELECT A TAG'),
                                backgroundColor: Color(0xFFFF1E1E),
                              ),
                            );
                            return;
                          }
                          final amount = double.parse(amountController.text);
                          final note = noteController.text.trim();
                          _addTransaction(amount, isCredit, note, selectedTag);
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isCredit
                              ? const Color(0xFF00FF66)
                              : const Color(0xFFFF1E1E),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: isCredit ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
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
  }  void _showEditTransactionSheet(Transaction tx) {
    final amountController =
        TextEditingController(text: tx.amount.toStringAsFixed(2));
    final noteController =
        TextEditingController(text: tx.note == 'Untitled' ? '' : tx.note);
    bool isCredit = tx.isCredit;
    String? selectedTag = tx.tag ?? (isCredit ? null : (_tags.isNotEmpty ? _tags[0] : 'FOOD'));
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
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
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                isCredit = true;
                                selectedTag = null;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isCredit
                                    ? const Color(0xFF00FF66)
                                    : Colors.black,
                                border: Border.all(
                                  color: isCredit
                                      ? const Color(0xFF00FF66)
                                      : const Color(0xFF808080),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'CREDIT (IN)',
                                style: TextStyle(
                                  color: isCredit
                                      ? Colors.black
                                      : const Color(0xFF808080),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                isCredit = false;
                                selectedTag = tx.tag ?? (_tags.isNotEmpty ? _tags[0] : 'FOOD');
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isCredit
                                    ? const Color(0xFFFF1E1E)
                                    : Colors.black,
                                border: Border.all(
                                  color: !isCredit
                                      ? const Color(0xFFFF1E1E)
                                      : const Color(0xFF808080),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'DEBIT (OUT)',
                                style: TextStyle(
                                  color: !isCredit
                                      ? Colors.white
                                      : const Color(0xFF808080),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'AMOUNT',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'NOTE / LABEL (OPTIONAL)',
                        hintText: 'e.g. Salary, Groceries',
                      ),
                    ),
                    if (!isCredit) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'TAG (REQUIRED)',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontFamily: 'monospace',
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
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedTag = tag;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF1E1E)
                                      : Colors.black,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF808080),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFAAAAAA),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () {
                              _showCreateTagDialog(context, (newTag) {
                                setModalState(() {
                                  selectedTag = newTag;
                                });
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                '+ ADD TAG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        if (formKey.currentState!.validate()) {
                          if (!isCredit && selectedTag == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PLEASE SELECT A TAG'),
                                backgroundColor: Color(0xFFFF1E1E),
                              ),
                            );
                            return;
                          }
                          final amount = double.parse(amountController.text);
                          final note = noteController.text.trim();
                          _editTransaction(tx.id, amount, isCredit, note, selectedTag);
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isCredit
                              ? const Color(0xFF00FF66)
                              : const Color(0xFFFF1E1E),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            color: isCredit ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        final formattedAmount =
            '${tx.isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DELETE TRANSACTION?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF808080), width: 1),
                ),
                child: Column(
                  children: [
                    Text(
                      tx.note,
                      style: const TextStyle(
                        color: Colors.white,
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
                            ? const Color(0xFF00FF66)
                            : const Color(0xFFFF1E1E),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border:
                              Border.all(color: const Color(0xFF808080), width: 1.5),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _deleteTransaction(tx.id);
                        Navigator.pop(context);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1E1E),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'DELETE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
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

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: tx.isCredit
                    ? const Color(0xFF00FF66)
                    : const Color(0xFFFF1E1E),
                width: 1,
              ),
            ),
            child: Text(
              tx.isCredit ? 'CR' : 'DR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: tx.isCredit
                    ? const Color(0xFF00FF66)
                    : const Color(0xFFFF1E1E),
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!tx.isCredit) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          border: Border.all(
                            color: const Color(0xFF808080),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          (tx.tag ?? 'OTHERS').toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: tx.isCredit
                      ? const Color(0xFF00FF66)
                      : const Color(0xFFFF1E1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedBalance,
                style: const TextStyle(
                  color: Color(0xFF888888),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Text(
            'LOADING...',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final displayedTransactions = _transactions.reversed.toList();
    final List<Widget> listItems = [];
    String? currentGroupDate;

    for (var i = 0; i < displayedTransactions.length; i++) {
      final tx = displayedTransactions[i];
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.timestamp);
      final headerText =
          DateFormat('EEE, dd-MM-yyyy').format(tx.timestamp).toUpperCase();

      if (currentGroupDate != dateStr) {
        currentGroupDate = dateStr;
        listItems.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              border: Border(
                bottom: BorderSide(color: Color(0xFF808080), width: 1),
                top: BorderSide(color: Color(0xFF808080), width: 1),
              ),
            ),
            child: Text(
              '// $headerText',
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      }

      listItems.add(
        SwipeableLogEntry(
          key: ValueKey(tx.id),
          transaction: tx,
          onEdit: () => _showEditTransactionSheet(tx),
          onDelete: () => _showDeleteConfirmationSheet(tx),
          child: Column(
            children: [
              _buildTransactionRow(tx),
              const Divider(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Image.asset(
                    'logo/vitta.png',
                    height: 24,
                    width: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance_wallet,
                          color: Colors.white, size: 24);
                    },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'VITTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AnalyticsScreen(transactions: _transactions),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics_outlined,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'ANALYTICS',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF808080), width: 1.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL BALANCE',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_balance >= 0 ? '+' : ''}₹${_balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: _balance >= 0
                            ? const Color(0xFF00FF66)
                            : const Color(0xFFFF1E1E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showAddTransactionSheet(isCredit: true),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF66),
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 1),
                        ),
                      ),
                      child: const Text(
                        'ADD CREDIT',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showAddTransactionSheet(isCredit: false),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF1E1E),
                      ),
                      child: const Text(
                        'ADD DEBIT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(height: 4, color: const Color(0xFF808080)),
            Expanded(
              child: listItems.isEmpty
                  ? const Center(
                      child: Text(
                        '// NO TRANSACTIONS YET',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
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
  static const double _actionsWidth = 140.0; // 2 buttons * 70px

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
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.primaryDelta!;
          if (_dragOffset < -_actionsWidth) _dragOffset = -_actionsWidth;
          if (_dragOffset > _actionsWidth) _dragOffset = _actionsWidth;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset < -_actionsWidth / 2) {
          _animateToOffset(-_actionsWidth);
        } else if (_dragOffset > _actionsWidth / 2) {
          _animateToOffset(_actionsWidth);
        } else {
          _animateToOffset(0.0);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF111111),
              child: Row(
                children: [
                  if (_dragOffset > 0) ..._buildActionButtons(),
                  const Spacer(),
                  if (_dragOffset < 0) ..._buildActionButtons(),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Container(
              color: Colors.black,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    return [
      _buildAction(
        label: 'EDIT',
        color: const Color.fromARGB(255, 33, 33, 33), // Saturated Cyan
        textColor: const Color.fromARGB(255, 255, 255, 255),
        onTap: () {
          _close();
          widget.onEdit();
        },
      ),
      _buildAction(
        label: 'DELETE',
        color: const Color(0xFFFF1E1E), // Saturated Red
        textColor: Colors.white,
        onTap: () {
          _close();
          widget.onDelete();
        },
      ),
      // _buildAction(
      //   label: 'CLOSE',
      //   color: const Color(0xFF808080), // Mid Grey
      //   textColor: Colors.white,
      //   onTap: _close,
      // ),
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
