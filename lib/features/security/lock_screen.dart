import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/lockout_manager.dart';
import '../../core/security/biometric_service.dart';
import '../../design_system/tokens.dart';

/// Extraordinary, luxury obsidian vault PIN lock screen with Telegram-style
/// reactive turbulent long-wave displacement fluid mesh & hardware-grade security styling.
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
  bool _hasSuccess = false;
  Timer? _lockoutTimer;
  int _lockoutSecondsLeft = 0;
  bool _isAuthenticating = false;
  bool _hasAutoPrompted = false;

  int _pulseTriggerCount = 0;
  String? _lastKeyPressed;

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

  Future<void> _handleSuccessUnlock() async {
    if (!mounted) return;
    _lockoutManager.resetAttempts();
    HapticFeedback.mediumImpact();
    setState(() {
      _hasSuccess = true;
      _hasError = false;
      _pulseTriggerCount++;
      _lastKeyPressed = 'OK';
    });

    // Brief smooth transition to let user experience the emerald green success glow
    await Future.delayed(const Duration(milliseconds: 280));
    if (mounted) {
      widget.onSuccess();
    }
  }

  Future<void> _attemptBiometrics({bool isAuto = false}) async {
    if (kIsWeb ||
        !widget.isBioEnabled ||
        _isAuthenticating ||
        _hasSuccess ||
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
    setState(() {
      _pulseTriggerCount++;
      _lastKeyPressed = 'BIO';
    });

    try {
      final success = await widget.biometricService.authenticateBiometricOnly(
        reason: 'Authenticate to unlock Nummo',
      );
      if (success && mounted) {
        await _handleSuccessUnlock();
      }
    } finally {
      if (mounted) {
        _isAuthenticating = false;
      }
    }
  }

  void _onKeyPress(String digit) {
    if (_lockoutManager.isLockedOut || _hasSuccess) return;
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _hasSuccess = false;
      _enteredPin += digit;
      _pulseTriggerCount++;
      _lastKeyPressed = digit;
    });

    if (_enteredPin.length == 4) {
      _verifyEnteredPin();
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isEmpty || _lockoutManager.isLockedOut || _hasSuccess) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _hasSuccess = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _pulseTriggerCount++;
      _lastKeyPressed = 'DEL';
    });
  }

  Future<void> _verifyEnteredPin() async {
    final isValid = await widget.onVerifyPin(_enteredPin);
    if (isValid && mounted) {
      await _handleSuccessUnlock();
    } else if (mounted) {
      _lockoutManager.recordFailedAttempt();
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _hasSuccess = false;
        _enteredPin = '';
        _pulseTriggerCount++;
        _lastKeyPressed = 'ERR';
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
            // Long Wave Reactive Turbulent Displace + Fast Box Blur Background
            Positioned.fill(
              child: TurbulentDisplaceBackground(
                accentColor: primaryColor,
                hasError: _hasError,
                hasSuccess: _hasSuccess,
                pulseTrigger: _pulseTriggerCount,
                lastKeyPressed: _lastKeyPressed,
                pinLength: _enteredPin.length,
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Direct Clean Logo (Zero border artifacts, zero subpixel gap)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'logo/nummo.png',
                          width: 72,
                          height: 72,
                          cacheWidth: 216,
                          cacheHeight: 216,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'web/favicon.png',
                            width: 72,
                            height: 72,
                            cacheWidth: 216,
                            cacheHeight: 216,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Refined Professional Typography
                    const Text(
                      'Nummo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        color: _hasSuccess
                            ? const Color(0xFF10B981)
                            : (_hasError || isLockedOut
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF94A3B8)),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                      child: Text(
                        isLockedOut
                            ? 'Try again in ${_lockoutSecondsLeft}s'
                            : (_hasSuccess
                                ? 'Unlocked'
                                : (_hasError ? 'Incorrect PIN' : 'Enter Passcode')),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Pure Solid Minimalist PIN Dots (iOS / Telegram Style)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.symmetric(horizontal: 9),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hasSuccess
                                ? const Color(0xFF10B981)
                                : (_hasError
                                    ? const Color(0xFFEF4444)
                                    : (isFilled ? Colors.white : const Color(0xFF282C38))),
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
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
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
            padding: const EdgeInsets.only(bottom: 8),
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
                borderRadius: BorderRadius.circular(38),
                splashColor: primaryColor.withValues(alpha: 0.20),
                highlightColor: primaryColor.withValues(alpha: 0.08),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: primaryColor,
                        size: 28,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BIO',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(width: 76, height: 76),
            _buildExecutiveKeyButton('0', primaryColor),
            InkWell(
              onTap: _onDeletePress,
              borderRadius: BorderRadius.circular(38),
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              child: const SizedBox(
                width: 76,
                height: 76,
                child: Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    color: Color(0xFF94A3B8),
                    size: 24,
                  ),
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
      borderRadius: BorderRadius.circular(38),
      splashColor: Colors.white.withValues(alpha: 0.12),
      highlightColor: Colors.white.withValues(alpha: 0.06),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w400,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

/// Telegram-style full-screen reactive rotational fluid mesh.
/// Stays completely static when idle (0% CPU/GPU), and smoothly rotates the minimal monochrome
/// (Black, Grey, White) ambient light field across the screen whenever a button is pressed.
/// Automatically switches to a warning alert colour scheme when a wrong PIN is entered,
/// and to a vibrant Emerald Green accent upon successful unlock / biometric verification.
class TurbulentDisplaceBackground extends StatefulWidget {
  final Color accentColor;
  final bool hasError;
  final bool hasSuccess;
  final int pulseTrigger;
  final String? lastKeyPressed;
  final int pinLength;

  const TurbulentDisplaceBackground({
    super.key,
    required this.accentColor,
    this.hasError = false,
    this.hasSuccess = false,
    this.pulseTrigger = 0,
    this.lastKeyPressed,
    this.pinLength = 0,
  });

  @override
  State<TurbulentDisplaceBackground> createState() => _TurbulentDisplaceBackgroundState();
}

class _TurbulentDisplaceBackgroundState extends State<TurbulentDisplaceBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _rotationController;
  Animation<double>? _rotationAnimation;

  double _uniqueSeed = 0.0;
  double _currentAngle = 0.0;
  double _targetAngle = 0.0;
  double _previousAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (_rotationController != null) return;
    final rng = math.Random();
    _uniqueSeed = rng.nextDouble() * 2 * math.pi;

    _currentAngle = _uniqueSeed;
    _targetAngle = _uniqueSeed;
    _previousAngle = _uniqueSeed;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _rotationController = controller;
    _rotationAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant TurbulentDisplaceBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initControllers();
    if (widget.pulseTrigger != oldWidget.pulseTrigger) {
      _triggerRotationalGlide();
    }
  }

  void _triggerRotationalGlide() {
    _initControllers();
    _previousAngle = _currentAngle;

    if (widget.hasSuccess) {
      // Smooth clockwise flourish on successful unlock
      _targetAngle += math.pi * 0.50;
    } else if (widget.hasError) {
      // Snappy agitation on error
      _targetAngle += math.pi * 0.75;
    } else if (widget.lastKeyPressed == 'DEL') {
      // Anti-clockwise / counter-clockwise rotation when backspace is pressed
      _targetAngle -= math.pi / 3.0;
    } else if (widget.lastKeyPressed == 'BIO') {
      // Clockwise rotation on biometric authentication
      _targetAngle += math.pi / 3.0;
    } else {
      // Clockwise rotation when numeric digits are pressed
      final digitVal = int.tryParse(widget.lastKeyPressed ?? '') ?? 3;
      _targetAngle += (math.pi / 3.0) + (digitVal % 4) * (math.pi / 20);
    }

    _rotationController?.forward(from: 0.0).then((_) {
      if (mounted) {
        _currentAngle = _targetAngle;
      }
    });
  }

  @override
  void dispose() {
    _rotationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    final anim = _rotationAnimation;
    if (anim == null) {
      return const ColoredBox(color: Color(0xFF050507));
    }

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Deep obsidian canvas base
            const ColoredBox(color: Color(0xFF050507)),

            // High-Resolution Smooth Hardware-Filtered Rotating Ambient Mesh
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32, tileMode: TileMode.clamp),
              child: AnimatedBuilder(
                animation: anim,
                builder: (context, _) {
                  final t = anim.value;
                  // Smooth angular rotation glide between button presses
                  final angle = _previousAngle + (_targetAngle - _previousAngle) * t;

                  return CustomPaint(
                    painter: RotatingMonochromeDisplacePainter(
                      angle: angle,
                      accentColor: widget.accentColor,
                      hasError: widget.hasError,
                      hasSuccess: widget.hasSuccess,
                      pinLength: widget.pinLength,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // Ambient dark radial vignette focusing effect in central core
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.10,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF050507).withValues(alpha: 0.65),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter generating procedural unique, minimal monochrome (Black, Grey, White)
/// compact rotating ambient fields with multi-stop cubic falloff for zero pixelation.
class RotatingMonochromeDisplacePainter extends CustomPainter {
  final double angle;
  final Color accentColor;
  final bool hasError;
  final bool hasSuccess;
  final int pinLength;

  RotatingMonochromeDisplacePainter({
    required this.angle,
    required this.accentColor,
    required this.hasError,
    required this.hasSuccess,
    required this.pinLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final cx = w * 0.5;
    final cy = h * 0.46;
    final minDim = math.min(w, h);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (hasSuccess) {
      // --- Success Unlock Palette (Vibrant Emerald Green Accent) ---
      const emeraldGreen = Color(0xFF10B981);
      const mintAccent = Color(0xFF34D399);
      const deepEmerald = Color(0xFF059669);

      // Ambient Green Base Field with multi-stop cubic decay
      final ambientShader = RadialGradient(
        center: const Alignment(0.0, -0.08),
        radius: 0.85,
        colors: [
          deepEmerald.withValues(alpha: 0.16),
          deepEmerald.withValues(alpha: 0.08),
          deepEmerald.withValues(alpha: 0.02),
          const Color(0xFF050507),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      paint.shader = ambientShader;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

      // Rotating Success Node 1
      final r1 = minDim * 0.24;
      final a1 = angle;
      final x1 = cx + r1 * math.cos(a1);
      final y1 = cy + r1 * math.sin(a1);
      final rad1 = minDim * 0.65;

      paint.shader = RadialGradient(
        colors: [
          emeraldGreen.withValues(alpha: 0.26),
          emeraldGreen.withValues(alpha: 0.16),
          emeraldGreen.withValues(alpha: 0.06),
          emeraldGreen.withValues(alpha: 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: rad1));
      canvas.drawCircle(Offset(x1, y1), rad1, paint);

      // Rotating Success Node 2
      final r2 = minDim * 0.26;
      final a2 = angle + 2.094; // +120 deg
      final x2 = cx + r2 * math.cos(a2);
      final y2 = cy + r2 * math.sin(a2);
      final rad2 = minDim * 0.60;

      paint.shader = RadialGradient(
        colors: [
          mintAccent.withValues(alpha: 0.20),
          mintAccent.withValues(alpha: 0.12),
          mintAccent.withValues(alpha: 0.04),
          mintAccent.withValues(alpha: 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: rad2));
      canvas.drawCircle(Offset(x2, y2), rad2, paint);

      return;
    }

    if (hasError) {
      // --- Error Alert Palette (Crimson & Amber Warning Shift) ---
      const warningColor = Color(0xFFEF4444);
      const amberWarning = Color(0xFFF59E0B);

      // Ambient Red Base Field
      final ambientShader = RadialGradient(
        center: const Alignment(0.0, -0.08),
        radius: 0.85,
        colors: [
          warningColor.withValues(alpha: 0.16),
          warningColor.withValues(alpha: 0.08),
          warningColor.withValues(alpha: 0.02),
          const Color(0xFF050507),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      paint.shader = ambientShader;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

      // Rotating Warning Orb 1
      final r1 = minDim * 0.24;
      final a1 = angle;
      final x1 = cx + r1 * math.cos(a1);
      final y1 = cy + r1 * math.sin(a1);
      final rad1 = minDim * 0.65;

      paint.shader = RadialGradient(
        colors: [
          warningColor.withValues(alpha: 0.24),
          warningColor.withValues(alpha: 0.14),
          warningColor.withValues(alpha: 0.05),
          warningColor.withValues(alpha: 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: rad1));
      canvas.drawCircle(Offset(x1, y1), rad1, paint);

      // Rotating Warning Orb 2
      final r2 = minDim * 0.26;
      final a2 = angle + 2.094; // +120 deg
      final x2 = cx + r2 * math.cos(a2);
      final y2 = cy + r2 * math.sin(a2);
      final rad2 = minDim * 0.60;

      paint.shader = RadialGradient(
        colors: [
          amberWarning.withValues(alpha: 0.18),
          amberWarning.withValues(alpha: 0.10),
          amberWarning.withValues(alpha: 0.04),
          amberWarning.withValues(alpha: 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: rad2));
      canvas.drawCircle(Offset(x2, y2), rad2, paint);

      return;
    }

    // --- Minimal Monochrome Palette (Black, Grey, Silver-White) ---
    const charcoalSlate = Color(0xFF1E2230);
    const deepCharcoal = Color(0xFF282E40);
    const softWhite = Colors.white;

    // Ambient Base Field with smooth multi-step cubic falloff
    final ambientShader = RadialGradient(
      center: const Alignment(0.0, -0.08),
      radius: 0.85,
      colors: [
        charcoalSlate.withValues(alpha: 0.16),
        charcoalSlate.withValues(alpha: 0.08),
        charcoalSlate.withValues(alpha: 0.02),
        const Color(0xFF050507),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    paint.shader = ambientShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Rotating Node 1: Soft Misty Silver / Ethereal White Body
    final r1 = minDim * 0.22;
    final a1 = angle;
    final x1 = cx + r1 * math.cos(a1);
    final y1 = cy + r1 * math.sin(a1);
    final rad1 = minDim * 0.58;

    paint.shader = RadialGradient(
      colors: [
        softWhite.withValues(alpha: 0.07),
        softWhite.withValues(alpha: 0.04),
        softWhite.withValues(alpha: 0.015),
        softWhite.withValues(alpha: 0.004),
        Colors.transparent,
      ],
      stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: rad1));
    canvas.drawCircle(Offset(x1, y1), rad1, paint);

    // Rotating Node 2: Rich Charcoal Slate Body
    final r2 = minDim * 0.26;
    final a2 = angle + 2.094; // +120 deg
    final x2 = cx + r2 * math.cos(a2);
    final y2 = cy + r2 * math.sin(a2);
    final rad2 = minDim * 0.68;

    paint.shader = RadialGradient(
      colors: [
        deepCharcoal.withValues(alpha: 0.18),
        deepCharcoal.withValues(alpha: 0.11),
        deepCharcoal.withValues(alpha: 0.04),
        deepCharcoal.withValues(alpha: 0.01),
        Colors.transparent,
      ],
      stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: rad2));
    canvas.drawCircle(Offset(x2, y2), rad2, paint);

    // Rotating Node 3: Deep Obsidian Slate Tint Body
    final r3 = minDim * 0.20;
    final a3 = angle + 4.188; // +240 deg
    final x3 = cx + r3 * math.cos(a3);
    final y3 = cy + r3 * math.sin(a3);
    final rad3 = minDim * 0.60;

    paint.shader = RadialGradient(
      colors: [
        charcoalSlate.withValues(alpha: 0.14),
        charcoalSlate.withValues(alpha: 0.08),
        charcoalSlate.withValues(alpha: 0.03),
        charcoalSlate.withValues(alpha: 0.008),
        Colors.transparent,
      ],
      stops: const [0.0, 0.30, 0.60, 0.85, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(x3, y3), radius: rad3));
    canvas.drawCircle(Offset(x3, y3), rad3, paint);
  }

  @override
  bool shouldRepaint(covariant RotatingMonochromeDisplacePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.hasError != hasError ||
        oldDelegate.hasSuccess != hasSuccess ||
        oldDelegate.pinLength != pinLength;
  }
}
