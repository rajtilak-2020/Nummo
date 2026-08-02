import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Transaction> _transactions = [];
  double _balance = 0.0;
  bool _isLoading = true;
  List<String> _tags = ['FOOD', 'SHOPPING', 'OTHERS'];

  // Security variables
  bool _isLocalAuthEnabled = false;
  String? _savedPin;
  bool _isBiometricsEnabled = true;
  bool _isLocked = false;
  bool _biometricPromptDismissed = false;
  final LocalAuthentication _auth = LocalAuthentication();
  String _enteredPin = '';

  // PIN Shake Animation State
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;
  bool _hasPinError = false;
  String _currentLockErrorMessage = 'ACCESS DENIED. TRY AGAIN.';

  static final List<String> _hilariousErrorMessages = [
    'NICE TRY, FBI!',
    'WRONG PIN, BRO. WHO ARE YOU?',
    'YOUR FINGERPRINT LOOKS SUS',
    'TRYING TO STEAL MY ₹0 BALANCE?',
    'OBJECTION! WRONG PIN!',
    'NEW PHONE, WHO DIS?',
    'WRONG PIN! MY MONEY IS SAFE FROM YOU',
    'ERROR 404: PIN NOT FOUND',
    'FINGERPRINT REJECTED! ARE YOU A GHOST?',
    'STAY AWAY FROM MY LEDGER!',
    'NO PEEKING AT MY SAVINGS!',
    'WRONG PIN! DID YOU EAT CHEETOS WITH THAT FINGER?',
    'SORRY, NOT TODAY HACKER!',
    'INCORRECT! IS THAT A SAUSAGE FINGER?',
    'WRONG PIN! GO ASK YOUR MOM FOR HELP',
    'BEEP BOOP! YOU SHALL NOT PASS!',
    'ARE YOU GUESSING MY BIRTHDAY AGAIN?',
    'WRONG FINGER, FAM!',
    'DENIED! EVEN MY BANK ACCOUNTS ARE LAUGHING',
    'WHO TAMPERED WITH THIS SENSOR?',
    'WRONG PIN! YOU ARE NOT THE CHOSEN ONE',
    'FAT THUMB DETECTED! TRY AGAIN',
    'FBI OPEN UP! WRONG PIN!',
    'NO ENTRY! GO BUY YOUR OWN CHAI',
    'WRONG CODE! REBOOT YOUR BRAIN AND RETRY',
    'NICE TRY, BUT NO DOUGH FOR YOU',
    'ACCESS DENIED! THUMBS ARE OVERRATED ANYWAY',
    'IS THAT YOUR THUMB OR A BANANA?',
    'WRONG PIN! ARE YOU DRUNK?',
    'INCORRECT! MY TREASURE REMAINS HIDDEN',
    'NOT YOUR MONEY, CHUM!',
    'FINGERPRINT NOT MATCHED. DID YOU WIPE IT?',
    'WRONG PIN! SYSTEM IS JUDGING YOU RIGHT NOW',
    'MISSION FAILED! WE\'LL GET \'EM NEXT TIME',
    'WRONG CODE! DANGER WILL ROBINSON!',
    'INVALID! WAS THAT YOUR TOES?',
    'REJECTED! GO GET A MANICURE',
    'ERROR: BRAIN NOT CONNECTED TO FINGERS',
    'WRONG PIN! YOU HAVE 0 ATTEMPTS AT MY RESPECT',
    'DENIED! WHO TAUGHT YOU MATH?',
    'STOP HACKING ME, BRO!',
    'WRONG PIN! TAKE A DEEP BREATH AND TRY AGAIN',
    'FINGERPRINT FAILED! ARE YOU WEARING GLOVES?',
    'ACCESS DENIED! EVEN ALEXA WOULD LAUGH',
    'WRONG COMBINATION, SHERLOCK!',
    'INCORRECT! MY RS. 50 SAVINGS ARE SECURE',
    'NICE SHOT, BUT NO CIGAR!',
    'WRONG PIN! GO GET A COFFEE FIRST',
    'DENIED! SENSOR SAYS NO.',
    'FAIL! MY LEDGER IS A FORTRESS',
  ];

  void _triggerLockError() {
    HapticFeedback.vibrate();
    _shakeController?.forward(from: 0.0);
    final randomMsg = _hilariousErrorMessages[
        math.Random().nextInt(_hilariousErrorMessages.length)];
    setState(() {
      _hasPinError = true;
      _currentLockErrorMessage = randomMsg;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _hasPinError = false;
        });
      }
    });
  }

  void _initShakeAnimation() {
    if (_shakeController == null) {
      _shakeController = AnimationController(
        duration: const Duration(milliseconds: 350),
        vsync: this,
      );
      _shakeAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -12.0, end: -8.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
      ]).animate(_shakeController!);
    }
  }

  List<Transaction> _getCurrentMonthTransactions() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final endOfMonth = DateTime(now.year, now.month, daysInMonth, 23, 59, 59, 999);

    return _transactions.where((tx) {
      final t = tx.timestamp;
      return (t.isAfter(startOfMonth) || t.isAtSameMomentAs(startOfMonth)) &&
             (t.isBefore(endOfMonth) || t.isAtSameMomentAs(endOfMonth));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initShakeAnimation();

    WidgetsBinding.instance.addObserver(this);
    _loadSecuritySettings().then((_) {
      if (_isLocalAuthEnabled) {
        setState(() {
          _isLocked = true;
          _biometricPromptDismissed = false;
        });
        if (_isBiometricsEnabled && !kIsWeb) {
          _authenticateBiometrics();
        }
      }
    });
    _loadTags().then((_) => _loadTransactions());
  }



  @override
  void dispose() {
    _shakeController?.dispose();
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
          _biometricPromptDismissed = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocalAuthEnabled && _isLocked && _isBiometricsEnabled && !_biometricPromptDismissed) {
        _authenticateBiometrics();
      }
    }
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isLocalAuthEnabled = prefs.getBool('local_auth_enabled') ?? false;
        _savedPin = prefs.getString('app_pin');
        _isBiometricsEnabled = kIsWeb
            ? false
            : (prefs.getBool('biometrics_enabled') ?? true);
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _saveSecuritySettings(bool enabled, String? pin, {bool? biometricsEnabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('local_auth_enabled', enabled);
      if (pin != null) {
        await prefs.setString('app_pin', pin);
      } else if (!enabled) {
        await prefs.remove('app_pin');
      }
      final bioState = kIsWeb ? false : (biometricsEnabled ?? _isBiometricsEnabled);
      await prefs.setBool('biometrics_enabled', bioState);

      setState(() {
        _isLocalAuthEnabled = enabled;
        if (pin != null) {
          _savedPin = pin;
        } else if (!enabled) {
          _savedPin = null;
        }
        _isBiometricsEnabled = bioState;
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _authenticateBiometrics({bool userInitiated = false}) async {
    if (kIsWeb || !_isBiometricsEnabled || !_isLocked) return;
    if (!userInitiated && _biometricPromptDismissed) return;

    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (canCheck || isSupported) {
        final bool authenticated = await _auth.authenticate(
          localizedReason: 'AUTHENTICATE TO UNLOCK NUMMO',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: false,
          ),
        );
        if (authenticated) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isLocked = false;
            _enteredPin = '';
            _hasPinError = false;
            _biometricPromptDismissed = false;
          });
        } else {
          if (!userInitiated) {
            _biometricPromptDismissed = true;
          }
          _triggerLockError();
        }
      }
    } catch (e) {
      if (!userInitiated) {
        _biometricPromptDismissed = true;
      }
      _triggerLockError();
    }
  }

  Future<void> _authenticateDevice() => _authenticateBiometrics(userInitiated: true);

  Widget _buildLockScreen() {
    _initShakeAnimation();
    final showPinPad = _savedPin != null;
    final debitColor = AppColors.debit(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Header & Branding Section
              Column(
                children: [
                  const SizedBox(height: 20),
                  SvgPicture.asset(
                    'logo/nummo.svg',
                    height: 52,
                    width: 52,
                    fit: BoxFit.contain,
                    placeholderBuilder: (BuildContext context) => const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NUMMO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: _hasPinError ? debitColor : const Color(0xFF808080),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _hasPinError
                          ? '✕ Bro What?'
                          : (_savedPin != null ? '[ LOCKED ]' : '[ APP LOCKED ]'),
                      style: TextStyle(
                        color: _hasPinError ? debitColor : const Color(0xFFAAAAAA),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),

              // PIN Indicator & Display Section
              if (showPinPad) ...[
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _shakeAnimation ?? const AlwaysStoppedAnimation(0.0),
                      builder: (context, child) {
                        final offset = _shakeAnimation?.value ?? 0.0;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final hasChar = _enteredPin.length > index;
                          final isActiveIndex = _enteredPin.length == index;

                          Color boxBg = const Color(0xFF0A0A0A);
                          Color borderColor = const Color(0xFF333333);

                          if (_hasPinError) {
                            boxBg = const Color(0xFF2A0A0A);
                            borderColor = debitColor;
                          } else if (hasChar) {
                            boxBg = Colors.white;
                            borderColor = Colors.white;
                          } else if (isActiveIndex) {
                            borderColor = const Color(0xFF808080);
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 52,
                            height: 60,
                            decoration: BoxDecoration(
                              color: boxBg,
                              border: Border.all(
                                color: borderColor,
                                width: _hasPinError || hasChar ? 2.0 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: hasChar
                                ? (_hasPinError
                                    ? Icon(Icons.close, color: debitColor, size: 24)
                                    : Container(
                                        width: 14,
                                        height: 14,
                                        color: Colors.black,
                                      ))
                                : (isActiveIndex
                                    ? Container(
                                        width: 8,
                                        height: 2,
                                        color: const Color(0xFF808080),
                                      )
                                    : null),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _hasPinError
                          ? _currentLockErrorMessage
                          : 'ENTER 4-DIGIT PIN CODE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _hasPinError ? debitColor : const Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],

              // Keypad Section or Biometric Button
              if (showPinPad) ...[
                Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildKeypadButton('1', subLabel: ''),
                          _buildKeypadButton('2', subLabel: 'ABC'),
                          _buildKeypadButton('3', subLabel: 'DEF'),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton('4', subLabel: 'GHI'),
                          _buildKeypadButton('5', subLabel: 'JKL'),
                          _buildKeypadButton('6', subLabel: 'MNO'),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton('7', subLabel: 'PQRS'),
                          _buildKeypadButton('8', subLabel: 'TUV'),
                          _buildKeypadButton('9', subLabel: 'WXYZ'),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton((!kIsWeb && _isBiometricsEnabled) ? 'BIO' : 'CLEAR', isSpecial: true),
                          _buildKeypadButton('0', subLabel: '+'),
                          _buildKeypadButton('BACK', isSpecial: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (!kIsWeb)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _authenticateDevice();
                      },
                      icon: const Icon(Icons.fingerprint, size: 24),
                      label: const Text(
                        'UNLOCK WITH BIOMETRICS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'PLEASE CONFIGURE PIN IN APP SETTINGS',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String val, {String subLabel = '', bool isSpecial = false}) {
    Widget content;
    if (val == 'BIO') {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.fingerprint, color: Colors.white, size: 22),
          SizedBox(height: 2),
          Text(
            'BIO',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    } else if (val == 'BACK') {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.backspace_outlined, color: Colors.white, size: 20),
          SizedBox(height: 2),
          Text(
            'DEL',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    } else if (val == 'CLEAR') {
      content = const Text(
        'CLEAR',
        style: TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          if (subLabel.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              subLabel,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4.0),
        height: 64,
        child: Material(
          color: const Color(0xFF0F0F0F),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFF262626), width: 1),
          ),
          child: InkWell(
            splashFactory: NoSplash.splashFactory,
            highlightColor: const Color(0xFF333333),
            onTap: () {
              if (val == 'BIO') {
                if (!kIsWeb && _isBiometricsEnabled) {
                  HapticFeedback.lightImpact();
                  _biometricPromptDismissed = false;
                  _authenticateDevice();
                }
                return;
              }

              if (!_biometricPromptDismissed) {
                _biometricPromptDismissed = true;
                try {
                  _auth.stopAuthentication();
                } catch (_) {}
              }

              if (val == 'CLEAR') {
                HapticFeedback.selectionClick();
                setState(() {
                  _enteredPin = '';
                  _hasPinError = false;
                });
                return;
              }

              if (val == 'BACK') {
                HapticFeedback.selectionClick();
                setState(() {
                  _hasPinError = false;
                  if (_enteredPin.isNotEmpty) {
                    _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
                  }
                });
                return;
              }

              // Digit pressed
              HapticFeedback.lightImpact();
              if (_enteredPin.length < 4) {
                setState(() {
                  _hasPinError = false;
                  _enteredPin += val;
                });

                if (_enteredPin.length == 4) {
                  if (_enteredPin == _savedPin) {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isLocked = false;
                      _enteredPin = '';
                      _hasPinError = false;
                    });
                  } else {
                    _triggerLockError();
                  }
                }
              }
            },
            child: Center(child: content),
          ),
        ),
      ),
    );
  }  void _openPinSetupModal(PinSetupMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color(0xFF333333), width: 1.5),
      ),
      builder: (context) {
        return PinSetupModal(
          mode: mode,
          currentSavedPin: _savedPin,
          onPinSaved: (newPin, biometricsEnabled) async {
            await _saveSecuritySettings(true, newPin, biometricsEnabled: biometricsEnabled);
          },
          onLockDisabled: () async {
            await _saveSecuritySettings(false, null);
          },
          showSuccessSnackBar: _showSuccessSnackBar,
        );
      },
    );
  }

  void _showSecuritySetupDialog() {
    final debitColor = AppColors.debit(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAppLockActive = _isLocalAuthEnabled && _savedPin != null;

            return AlertDialog(
              backgroundColor: const Color(0xFF000000),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: Color(0xFF333333), width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(
                    isAppLockActive ? Icons.lock : Icons.lock_open_outlined,
                    size: 24,
                    color: isAppLockActive ? AppColors.credit(context) : const Color(0xFF808080),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'APP LOCK SECURITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(
                        color: isAppLockActive ? AppColors.credit(context) : const Color(0xFF444444),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAppLockActive ? '[ STATUS: ACTIVE ]' : '[ STATUS: INACTIVE ]',
                          style: TextStyle(
                            color: isAppLockActive ? AppColors.credit(context) : const Color(0xFFAAAAAA),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAppLockActive
                              ? 'App Lock is ACTIVE with 4-Digit PIN protection.'
                              : 'Protect your ledger data with a compulsory 4-Digit PIN.',
                          style: const TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isAppLockActive) ...[
                    if (!kIsWeb) ...[
                      // Switch for Biometrics on native platform only
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          border: Border.all(
                            color: const Color(0xFF262626),
                            width: 1,
                          ),
                        ),
                        child: SwitchListTile(
                          value: _isBiometricsEnabled,
                          activeThumbColor: AppColors.credit(context),
                          title: const Text(
                            'Fingerprint Unlock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: const Text(
                            'Scan fingerprint sensor for quick unlock.',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                            ),
                          ),
                          onChanged: (bool value) async {
                            HapticFeedback.selectionClick();
                            await _saveSecuritySettings(true, _savedPin, biometricsEnabled: value);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.white, width: 1),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        _openPinSetupModal(PinSetupMode.change);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'CHANGE 4-DIGIT PIN',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: debitColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        _openPinSetupModal(PinSetupMode.disable);
                      },
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: const Text(
                        'DISABLE APP LOCK',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.credit(context),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        _openPinSetupModal(PinSetupMode.setup);
                      },
                      icon: const Icon(Icons.lock_outlined, size: 20),
                      label: const Text(
                        'ENABLE 4-DIGIT PIN',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  child: const Text('CLOSE', style: TextStyle(color: Color(0xFF888888), fontFamily: 'monospace')),
                ),
              ],
            );
          },
        );
      },
    );
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
      double amount, bool isCredit, String note, String? tag,
      {DateTime? customTimestamp}) async {
    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      isCredit: isCredit,
      note: note.trim().isEmpty ? 'Untitled' : note.trim(),
      timestamp: customTimestamp ?? DateTime.now(),
      tag: isCredit ? null : tag,
    );

    List<Transaction> updated = [..._transactions, newTx];
    updated.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _recalculateRunningBalances(updated);
    await _saveTransactions();
  }

  Future<void> _editTransaction(
      String id, double amount, bool isCredit, String note, String? tag,
      {DateTime? customTimestamp}) async {
    List<Transaction> updated = _transactions.map((tx) {
      if (tx.id == id) {
        return Transaction(
          id: tx.id,
          amount: amount,
          isCredit: isCredit,
          note: note.trim().isEmpty ? 'Untitled' : note.trim(),
          timestamp: customTimestamp ?? tx.timestamp,
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

  void _showDeleteTagConfirmationDialog(
    BuildContext context,
    String tagToDelete, {
    required VoidCallback onDeleted,
  }) {
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
                'Remove "$tagToDelete" from active tag options?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: Existing transactions tagged with "$tagToDelete" will retain their category info in history and analytics.',
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
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                onDeleted();
                _showSuccessSnackBar('TAG "$tagToDelete" DELETED');
              },
              child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
    DateTime selectedTimestamp = DateTime.now();
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
                            return GestureDetector(
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                _showDeleteTagConfirmationDialog(
                                  context,
                                  tag,
                                  onDeleted: () async {
                                    setState(() {
                                      _tags.remove(tag);
                                    });
                                    await _saveTags();
                                    setModalState(() {
                                      if (selectedTag == tag) {
                                        selectedTag = _tags.isNotEmpty ? _tags[0] : null;
                                      }
                                    });
                                  },
                                );
                              },
                              child: ChoiceChip(
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
                              ),
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
                    const SizedBox(height: 16),
                    Text(
                      'DATE & TIME',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedTimestamp,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                dialogTheme: const DialogThemeData(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedTimestamp),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dialogTheme: const DialogThemeData(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedTimestamp = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          border: Border.all(color: const Color(0xFF333333), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFAAAAAA)),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(selectedTimestamp).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'CHANGE',
                              style: TextStyle(
                                color: Color(0xFF00FF66),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          _addTransaction(amount, isCredit, note, selectedTag,
                              customTimestamp: selectedTimestamp);
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
    DateTime selectedTimestamp = tx.timestamp;

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
                          ...(() {
                            final displayTags = List<String>.from(_tags);
                            if (selectedTag != null && !displayTags.contains(selectedTag)) {
                              displayTags.add(selectedTag!);
                            }
                            return displayTags.map((tag) {
                              final isSelected = selectedTag == tag;
                              final isHistorical = !_tags.contains(tag);
                              return GestureDetector(
                                onLongPress: isHistorical
                                    ? null
                                    : () {
                                        HapticFeedback.heavyImpact();
                                        _showDeleteTagConfirmationDialog(
                                          context,
                                          tag,
                                          onDeleted: () async {
                                            setState(() {
                                              _tags.remove(tag);
                                            });
                                            await _saveTags();
                                            setModalState(() {
                                              if (selectedTag == tag) {
                                                selectedTag = _tags.isNotEmpty ? _tags[0] : null;
                                              }
                                            });
                                          },
                                        );
                                      },
                                child: ChoiceChip(
                                  label: Text(isHistorical ? '$tag (HISTORICAL)' : tag),
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
                                ),
                              );
                            });
                          })(),
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
                    const SizedBox(height: 16),
                    Text(
                      'DATE & TIME',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedTimestamp,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                dialogTheme: const DialogThemeData(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedTimestamp),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dialogTheme: const DialogThemeData(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedTimestamp = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          border: Border.all(color: const Color(0xFF333333), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFAAAAAA)),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(selectedTimestamp).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'CHANGE',
                              style: TextStyle(
                                color: Color(0xFF00FF66),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                              tx.id, amount, isCredit, note, selectedTag,
                              customTimestamp: selectedTimestamp);
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

    final displayedTransactions = _transactions.reversed.toList();
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
                            HapticFeedback.selectionClick();
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
                            HapticFeedback.selectionClick();
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
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  isLocalAuthEnabled: _isLocalAuthEnabled,
                                  tags: _tags,
                                  onSecuritySetupTap: () {
                                    _showSecuritySetupDialog();
                                  },
                                  onTagsUpdated: (updatedTags) async {
                                    setState(() {
                                      _tags = updatedTags;
                                    });
                                    await _saveTags();
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

                  const SizedBox(height: 6),

                  // Analytics Hero Carousel (Current Month Data - Total Balance & Spend by Category)
                  AnalyticsHeroCarousel(
                    filteredTransactions: _getCurrentMonthTransactions(),
                    totalBalance: _balance,
                    startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
                    endDate: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month),
                        23,
                        59,
                        59,
                        999),
                    selectedFilter: TimelineFilter.thisMonth,
                  ),

                  const SizedBox(height: 8),

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
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showAddTransactionSheet(isCredit: true);
                            },
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
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showAddTransactionSheet(isCredit: false);
                            },
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
            HapticFeedback.selectionClick();
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
          HapticFeedback.lightImpact();
          _close();
          widget.onEdit();
        },
      ),
      _buildAction(
        label: 'DELETE',
        color: debitColor,
        textColor: Colors.white,
        onTap: () {
          HapticFeedback.heavyImpact();
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

enum PinSetupMode { setup, change, disable }

class PinSetupModal extends StatefulWidget {
  final PinSetupMode mode;
  final String? currentSavedPin;
  final Future<void> Function(String newPin, bool biometricsEnabled) onPinSaved;
  final Future<void> Function() onLockDisabled;
  final void Function(String msg) showSuccessSnackBar;

  const PinSetupModal({
    super.key,
    required this.mode,
    required this.currentSavedPin,
    required this.onPinSaved,
    required this.onLockDisabled,
    required this.showSuccessSnackBar,
  });

  @override
  State<PinSetupModal> createState() => _PinSetupModalState();
}

class _PinSetupModalState extends State<PinSetupModal> with SingleTickerProviderStateMixin {
  late int _step;
  String _enteredPin = '';
  String? _firstPinEntered;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isProcessing = false;

  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _step = 1;

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController!);
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    super.dispose();
  }

  void _triggerError(String msg) {
    HapticFeedback.vibrate();
    _shakeController?.forward(from: 0.0);
    setState(() {
      _hasError = true;
      _errorMessage = msg;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _hasError = false;
          _isProcessing = false;
        });
      }
    });
  }

  void _handleDigitInput(String digit) {
    if (_isProcessing) return;

    if (digit == 'CLEAR') {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = '';
        _hasError = false;
      });
      return;
    }

    if (digit == 'DEL') {
      HapticFeedback.selectionClick();
      setState(() {
        _hasError = false;
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      });
      return;
    }

    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _hasError = false;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _processCompletedPin();
      }
    }
  }

  Future<void> _processCompletedPin() async {
    _isProcessing = true;

    if (widget.mode == PinSetupMode.setup) {
      if (_step == 1) {
        HapticFeedback.mediumImpact();
        _firstPinEntered = _enteredPin;
        setState(() {
          _step = 2;
          _enteredPin = '';
          _isProcessing = false;
        });
      } else if (_step == 2) {
        if (_enteredPin == _firstPinEntered) {
          HapticFeedback.mediumImpact();
          if (kIsWeb) {
            await widget.onPinSaved(_enteredPin, false);
            if (!mounted) return;
            Navigator.pop(context);
            widget.showSuccessSnackBar('PIN LOCK ACTIVATED SUCCESSFULLY');
          } else {
            setState(() {
              _step = 3;
              _isProcessing = false;
            });
          }
        } else {
          _triggerError('PINS DO NOT MATCH. RETRY.');
        }
      }
    } else if (widget.mode == PinSetupMode.change) {
      if (_step == 1) {
        if (_enteredPin == widget.currentSavedPin) {
          HapticFeedback.mediumImpact();
          setState(() {
            _step = 2;
            _enteredPin = '';
            _isProcessing = false;
          });
        } else {
          _triggerError('INCORRECT CURRENT PIN');
        }
      } else if (_step == 2) {
        HapticFeedback.mediumImpact();
        _firstPinEntered = _enteredPin;
        setState(() {
          _step = 3;
          _enteredPin = '';
          _isProcessing = false;
        });
      } else if (_step == 3) {
        if (_enteredPin == _firstPinEntered) {
          HapticFeedback.mediumImpact();
          await widget.onPinSaved(_enteredPin, true);
          if (!mounted) return;
          Navigator.pop(context);
          widget.showSuccessSnackBar('PIN UPDATED SUCCESSFULLY');
        } else {
          _triggerError('NEW PINS DO NOT MATCH. RETRY.');
        }
      }
    } else if (widget.mode == PinSetupMode.disable) {
      if (_enteredPin == widget.currentSavedPin) {
        HapticFeedback.mediumImpact();
        await widget.onLockDisabled();
        if (!mounted) return;
        Navigator.pop(context);
        widget.showSuccessSnackBar('APP LOCK DISABLED');
      } else {
        _triggerError('INCORRECT PIN');
      }
    }
  }

  Future<void> _completeSetupWithFingerprintChoice(bool enableFingerprint) async {
    HapticFeedback.mediumImpact();
    await widget.onPinSaved(_firstPinEntered!, enableFingerprint);
    if (!mounted) return;
    Navigator.pop(context);
    widget.showSuccessSnackBar(
      enableFingerprint
          ? 'PIN LOCK & FINGERPRINT SECURITY ENABLED'
          : 'PIN LOCK ENABLED (PIN ONLY)',
    );
  }

  String _getStepTitle() {
    if (widget.mode == PinSetupMode.setup) {
      if (_step == 1) return 'CREATE 4-DIGIT PIN';
      if (_step == 2) return 'CONFIRM YOUR PIN';
      return 'ENABLE FINGERPRINT?';
    } else if (widget.mode == PinSetupMode.change) {
      if (_step == 1) return 'ENTER CURRENT PIN';
      if (_step == 2) return 'CREATE NEW PIN';
      return 'CONFIRM NEW PIN';
    } else {
      return 'VERIFY PIN TO DISABLE';
    }
  }

  String _getStepSubtitle() {
    if (widget.mode == PinSetupMode.setup) {
      if (_step == 1) return 'Choose a 4-digit code to protect your ledger';
      if (_step == 2) return 'Re-enter your 4-digit PIN to verify';
      return 'Scan your fingerprint sensor to quickly unlock Nummo';
    } else if (widget.mode == PinSetupMode.change) {
      if (_step == 1) return 'Enter your existing 4-digit PIN to authorize change';
      if (_step == 2) return 'Enter a new 4-digit PIN code';
      return 'Re-enter your new 4-digit PIN to verify';
    } else {
      return 'Enter your current 4-digit PIN to disable app lock';
    }
  }

  String _getStepBadge() {
    if (widget.mode == PinSetupMode.setup) {
      return kIsWeb ? '[ STEP $_step / 2 ]' : '[ STEP $_step / 3 ]';
    } else if (widget.mode == PinSetupMode.change) {
      return '[ STEP $_step / 3 ]';
    } else {
      return '[ VERIFY ]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 20;

    return Container(
      color: const Color(0xFF000000),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag indicator bar
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: const Color(0xFF444444), width: 1),
                ),
                child: Text(
                  _getStepBadge(),
                  style: const TextStyle(
                    color: Color(0xFF00FF66),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Step Title
          Text(
            _getStepTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            _getStepSubtitle(),
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // If Step 3 in setup mode: Render Fingerprint choice buttons!
          if (widget.mode == PinSetupMode.setup && _step == 3) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border.all(color: const Color(0xFF262626), width: 1),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 52,
                    color: Color(0xFF00FF66),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'FINGERPRINT UNLOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Would you like to use your fingerprint sensor for quick access to your ledger?',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF66),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              onPressed: () => _completeSetupWithFingerprintChoice(true),
              icon: const Icon(Icons.fingerprint, size: 20),
              label: const Text(
                'YES, ENABLE FINGERPRINT',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.1,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFF666666), width: 1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _completeSetupWithFingerprintChoice(false),
              child: const Text(
                'NO, USE PIN ONLY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontFamily: 'monospace',
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            // PIN Boxes & Shake Animation
            AnimatedBuilder(
              animation: _shakeAnimation ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                final offset = _shakeAnimation?.value ?? 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final hasChar = _enteredPin.length > index;
                  final isActiveIndex = _enteredPin.length == index;

                  Color boxBg = const Color(0xFF0A0A0A);
                  Color borderColor = const Color(0xFF333333);

                  if (_hasError) {
                    boxBg = const Color(0xFF2A0A0A);
                    borderColor = const Color(0xFFFF1E1E);
                  } else if (hasChar) {
                    boxBg = Colors.white;
                    borderColor = Colors.white;
                  } else if (isActiveIndex) {
                    borderColor = const Color(0xFF808080);
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 52,
                    height: 60,
                    decoration: BoxDecoration(
                      color: boxBg,
                      border: Border.all(
                        color: borderColor,
                        width: _hasError || hasChar ? 2.0 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: hasChar
                        ? (_hasError
                            ? const Icon(Icons.close, color: Color(0xFFFF1E1E), size: 24)
                            : Container(
                                width: 14,
                                height: 14,
                                color: Colors.black,
                              ))
                        : (isActiveIndex
                            ? Container(
                                width: 8,
                                height: 2,
                                color: const Color(0xFF808080),
                              )
                            : null),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Error Message Display
            SizedBox(
              height: 20,
              child: Text(
                _hasError ? _errorMessage : '',
                style: const TextStyle(
                  color: Color(0xFFFF1E1E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Custom On-Screen Brutalist Keypad
            Container(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildModalKeypadButton('1'),
                      _buildModalKeypadButton('2', subLabel: 'ABC'),
                      _buildModalKeypadButton('3', subLabel: 'DEF'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildModalKeypadButton('4', subLabel: 'GHI'),
                      _buildModalKeypadButton('5', subLabel: 'JKL'),
                      _buildModalKeypadButton('6', subLabel: 'MNO'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildModalKeypadButton('7', subLabel: 'PQRS'),
                      _buildModalKeypadButton('8', subLabel: 'TUV'),
                      _buildModalKeypadButton('9', subLabel: 'WXYZ'),
                    ],
                  ),
                  Row(
                    children: [
                      _buildModalKeypadButton('CLEAR'),
                      _buildModalKeypadButton('0', subLabel: '+'),
                      _buildModalKeypadButton('DEL'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModalKeypadButton(String val, {String subLabel = ''}) {
    Widget content;
    if (val == 'DEL') {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.backspace_outlined, color: Colors.white, size: 20),
          SizedBox(height: 2),
          Text(
            'DEL',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    } else if (val == 'CLEAR') {
      content = const Text(
        'CLEAR',
        style: TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          if (subLabel.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              subLabel,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4.0),
        height: 60,
        child: Material(
          color: const Color(0xFF0F0F0F),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFF262626), width: 1),
          ),
          child: InkWell(
            splashFactory: NoSplash.splashFactory,
            highlightColor: const Color(0xFF333333),
            onTap: () => _handleDigitInput(val),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
