import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/lockout_manager.dart';
import '../../core/security/biometric_service.dart';
import '../../design_system/tokens.dart';

/// Extraordinary, luxury obsidian vault PIN lock screen with biometric & hardware-grade security styling.
class LockScreen extends StatefulWidget {
  final bool isBioEnabled;
  final Future<bool> Function(String pin) onVerifyPin;
  final VoidCallback onSuccess;
  final BiometricService biometricService;

  const LockScreen({
    super.key,
    required this.isBioEnabled,
    required this.onVerifyPin,
    required this.onSuccess,
    required this.biometricService,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final LockoutManager _lockoutManager = LockoutManager();
  String _enteredPin = '';
  bool _hasError = false;
  Timer? _lockoutTimer;
  int _lockoutSecondsLeft = 0;
  bool _isAuthenticating = false;
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attemptBiometrics(isAuto: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _hasAutoPrompted = false;
    } else if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _attemptBiometrics(isAuto: true);
        }
      });
    }
  }

  Future<void> _attemptBiometrics({bool isAuto = false}) async {
    if (kIsWeb ||
        !widget.isBioEnabled ||
        _isAuthenticating ||
        _lockoutManager.isLockedOut ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    if (isAuto && _hasAutoPrompted) {
      return;
    }

    if (isAuto) {
      _hasAutoPrompted = true;
    }

    final canAuth = await widget.biometricService.canAuthenticate();
    if (!canAuth) return;

    _isAuthenticating = true;
    try {
      final success = await widget.biometricService.authenticateBiometricOnly(
        reason: 'Authenticate to unlock Nummo',
      );
      if (success && mounted) {
        _lockoutManager.resetAttempts();
        HapticFeedback.mediumImpact();
        widget.onSuccess();
      }
    } finally {
      if (mounted) {
        _isAuthenticating = false;
      }
    }
  }

  void _onKeyPress(String digit) {
    if (_lockoutManager.isLockedOut) return;
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyEnteredPin();
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isEmpty || _lockoutManager.isLockedOut) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _verifyEnteredPin() async {
    final isValid = await widget.onVerifyPin(_enteredPin);
    if (isValid && mounted) {
      _lockoutManager.resetAttempts();
      HapticFeedback.mediumImpact();
      widget.onSuccess();
    } else if (mounted) {
      _lockoutManager.recordFailedAttempt();
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });

      if (_lockoutManager.isLockedOut) {
        _startLockoutCountdown();
      }
    }
  }

  void _startLockoutCountdown() {
    setState(() {
      _lockoutSecondsLeft = _lockoutManager.remainingLockoutSeconds;
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = _lockoutManager.remainingLockoutSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _lockoutManager.resetAttempts();
        setState(() {
          _lockoutSecondsLeft = 0;
          _hasError = false;
        });
      } else {
        setState(() {
          _lockoutSecondsLeft = remaining;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _lockoutManager.isLockedOut;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF050507),
        body: Stack(
          children: [
            // Atmospheric Radial Glow Background
            Positioned(
              top: -120,
              left: MediaQuery.of(context).size.width / 2 - 180,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.22),
                      primaryColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Direct Logo with Overlapping Security Lock Badge
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard(context),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.cardBorder(context),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Image.asset(
                                  'logo/nummo.png',
                                  cacheWidth: 160,
                                  cacheHeight: 160,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Image.asset(
                                    'web/favicon.png',
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Overlapping Security Lock Badge
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _hasError ? AppColors.debitRed : primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_hasError ? AppColors.debitRed : primaryColor).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _hasError ? Icons.lock_clock_rounded : Icons.lock_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Header Text
                    Text(
                      'NUMMO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLockedOut
                          ? 'Too many attempts. Try again in $_lockoutSecondsLeft seconds.'
                          : (_hasError ? 'Incorrect Security PIN. Try again.' : 'Enter your 4-digit PIN'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _hasError || isLockedOut
                            ? AppColors.debitRed
                            : const Color(0xFF8E8E93),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Subtle Minimal PIN Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hasError
                                ? AppColors.debitRed
                                : (isFilled ? primaryColor : const Color(0xFF222532)),
                          ),
                        );
                      }),
                    ),

                    const Spacer(flex: 3),

                    // Executive Vault Keypad
                    if (!isLockedOut) ...[
                      _buildExecutiveKeypad(primaryColor),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Footer Branding Line
                    const Center(
                      child: Text(
                        'Developed by K Rajtilak',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveKeypad(Color primaryColor) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) => _buildExecutiveKeyButton(digit, primaryColor)).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.isBioEnabled && !kIsWeb)
              InkWell(
                onTap: () => _attemptBiometrics(isAuto: false),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.1),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BIO',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(width: 74, height: 74),
            _buildExecutiveKeyButton('0', primaryColor),
            InkWell(
              onTap: _onDeletePress,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F1017),
                  border: Border.all(color: const Color(0xFF222534), width: 1),
                ),
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutiveKeyButton(String digit, Color primaryColor) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F1017),
          border: Border.all(color: const Color(0xFF222534), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          digit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
