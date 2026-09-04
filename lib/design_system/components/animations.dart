import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/money_formatter.dart';

/// Apple-grade physics-based bouncy press micro-interaction widget.
/// Wraps any widget to give it a tactile, springy compression on tap.
class NummoBouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final Duration reverseDuration;
  final HitTestBehavior behavior;
  final bool enableHaptic;

  const NummoBouncy({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 90),
    this.reverseDuration = const Duration(milliseconds: 180),
    this.behavior = HitTestBehavior.opaque,
    this.enableHaptic = true,
  });

  @override
  State<NummoBouncy> createState() => _NummoBouncyState();
}

class _NummoBouncyState extends State<NummoBouncy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _isPressed = true;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: () {
        if (widget.enableHaptic) {
          HapticFeedback.mediumImpact();
        }
        widget.onLongPress?.call();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Apple-style staggered slide & fade entrance animation for cards, list items, and sections.
class NummoSlideFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const NummoSlideFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 16),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<NummoSlideFade> createState() => _NummoSlideFadeState();
}

class _NummoSlideFadeState extends State<NummoSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Smooth Apple-style counting number display for currency amounts and metrics.
/// Animates digit count-up from 0 only upon initial app launch or when unmasking privacy mode.
class NummoCountUp extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final bool showSign;
  final bool? isCredit;
  final bool isMasked;
  final Alignment alignment;
  final bool autoScaleDown;

  const NummoCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.showSign = false,
    this.isCredit,
    this.isMasked = false,
    this.alignment = Alignment.centerLeft,
    this.autoScaleDown = true,
  });

  @override
  State<NummoCountUp> createState() => _NummoCountUpState();
}

class _NummoCountUpState extends State<NummoCountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _currentDisplayValue;

  @override
  void initState() {
    super.initState();
    _currentDisplayValue = widget.isMasked ? widget.value : 0.0;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: _currentDisplayValue,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _currentDisplayValue = _animation.value;
          });
        }
      });

    if (!widget.isMasked) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(NummoCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isMasked && !widget.isMasked) {
      // Unmasked: Animate digit count up from 0 to value
      _controller.duration = widget.duration;
      _animation = Tween<double>(
        begin: 0.0,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller.forward(from: 0.0);
    } else if (!oldWidget.isMasked && !widget.isMasked) {
      // Already unmasked: if value changed, smoothly update without dropping to 0
      if (oldWidget.value != widget.value) {
        _controller.duration = const Duration(milliseconds: 300);
        _animation = Tween<double>(
          begin: _currentDisplayValue,
          end: widget.value,
        ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      MoneyFormatter.format(
        widget.isMasked ? widget.value : _currentDisplayValue,
        showSign: widget.showSign,
        isCredit: widget.isCredit ?? ((widget.isMasked ? widget.value : _currentDisplayValue) >= 0),
        isMasked: widget.isMasked,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: widget.autoScaleDown ? TextOverflow.clip : TextOverflow.ellipsis,
      style: widget.style,
    );

    if (widget.autoScaleDown) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: widget.alignment,
        child: text,
      );
    }

    return text;
  }
}

/// Horizontal spring shake animation (for passcode errors, invalid inputs, etc.).
class NummoShake extends AnimatedWidget {
  final Widget child;
  final double offset;

  const NummoShake({
    super.key,
    required Animation<double> animation,
    required this.child,
    this.offset = 14.0,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    // 4-cycle damped sine wave
    final progress = animation.value;
    final dx = math.sin(progress * math.pi * 4) * offset * (1.0 - progress);

    return Transform.translate(
      offset: Offset(dx, 0),
      child: child,
    );
  }
}

/// Production-grade, low-end device optimized horizontal scrolling marquee text widget.
///
/// Features & Low-End Device Optimizations:
/// 1. Zero overhead when text fits: behaves as standard static [Text].
///    No [Ticker] or [AnimationController] allocation, zero extra repaints.
/// 2. [RepaintBoundary] isolation: layer caching ensures scrolling text never invalidates
///    or repaints parent cards, tiles, or the containing [ListView].
/// 3. Zero ellipsis: clips cleanly without '...' truncation per design specs.
/// 4. Quiescent initial delay: stays stationary for 1.8s so list flinging / scrolling
///    never triggers animation work while the user is actively scrolling.
/// 5. Adaptive reading speed: animation duration scales proportionally with text length
///    (~32 logical px/sec) so text is always comfortably readable.
/// 6. Gentle easing: uses [Curves.easeInOutCubic] for silky, organic acceleration and deceleration.
/// 7. Tab & App Lifecycle awareness: stops when tab is inactive ([TickerMode]) or app is backgrounded.
class NummoMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double scrollSpeed;
  final double returnSpeed;
  final Curve curve;

  /// For testing: set to true in widget tests if explicitly testing marquee animation.
  static bool enableInTests = false;

  const NummoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(milliseconds: 1800),
    this.scrollSpeed = 32.0,
    this.returnSpeed = 45.0,
    this.curve = Curves.easeInOutCubic,
  });

  @override
  State<NummoMarqueeText> createState() => _NummoMarqueeTextState();
}

class _NummoMarqueeTextState extends State<NummoMarqueeText>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;

  int _loopToken = 0;
  double _lastOverflow = 0.0;
  bool _isLoopRunning = false;

  // Cached text measurement
  String? _cachedText;
  TextStyle? _cachedStyle;
  TextScaler? _cachedScaler;
  double _cachedTextWidth = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopAnimation();
    } else if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(NummoMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.scrollSpeed != widget.scrollSpeed ||
        oldWidget.returnSpeed != widget.returnSpeed ||
        oldWidget.pauseDuration != widget.pauseDuration) {
      _cachedText = null;
      _cachedStyle = null;
      _stopAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loopToken++;
    _scrollController.dispose();
    super.dispose();
  }

  double _measureText(String text, TextStyle style, TextScaler scaler) {
    if (text == _cachedText && style == _cachedStyle && scaler == _cachedScaler) {
      return _cachedTextWidth;
    }
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    );
    tp.layout();
    final width = tp.width;
    tp.dispose();

    _cachedText = text;
    _cachedStyle = style;
    _cachedScaler = scaler;
    _cachedTextWidth = width;
    return width;
  }

  void _stopAnimation() {
    if (_lastOverflow > 0 || _isLoopRunning) {
      _lastOverflow = 0.0;
      _isLoopRunning = false;
      _loopToken++;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  void _startLoopIfNeeded(double overflow) {
    final isTestEnv = WidgetsBinding.instance is! WidgetsFlutterBinding;
    if (isTestEnv && !NummoMarqueeText.enableInTests) {
      return;
    }

    if (_lastOverflow == overflow && _isLoopRunning) {
      return;
    }

    _lastOverflow = overflow;
    _loopToken++;
    final token = _loopToken;
    _isLoopRunning = true;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    final scrollMs = math.max(1000, (overflow / widget.scrollSpeed * 1000).round());
    final returnMs = math.max(600, (overflow / widget.returnSpeed * 1000).round());

    _runLoop(token, scrollMs, returnMs);
  }

  Future<void> _runLoop(int token, int scrollMs, int returnMs) async {
    while (mounted && token == _loopToken && _lastOverflow > 0) {
      // 1. Initial pause at start so user can read beginning of string
      await Future.delayed(widget.pauseDuration);
      if (!mounted || token != _loopToken || _lastOverflow <= 0) return;

      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // 2. Smoothly scroll forward to show the hidden tail of string
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: scrollMs),
          curve: widget.curve,
        );
      } catch (_) {
        return;
      }
      if (!mounted || token != _loopToken || _lastOverflow <= 0) return;

      // 3. Pause at the end so user can read the tail
      await Future.delayed(widget.pauseDuration);
      if (!mounted || token != _loopToken || _lastOverflow <= 0) return;

      // 4. Smoothly scroll back to the start
      if (!_scrollController.hasClients) return;
      try {
        await _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: returnMs),
          curve: widget.curve,
        );
      } catch (_) {
        return;
      }
      if (!mounted || token != _loopToken || _lastOverflow <= 0) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = widget.style != null ? defaultStyle.merge(widget.style) : defaultStyle;

    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (!tickerEnabled) {
      _stopAnimation();
      return Text(
        widget.text,
        style: effectiveStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (!availableWidth.isFinite || availableWidth <= 0 || widget.text.isEmpty) {
          _stopAnimation();
          return Text(
            widget.text,
            style: effectiveStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          );
        }

        final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
        final textWidth = _measureText(widget.text, effectiveStyle, scaler);

        if (textWidth <= availableWidth) {
          _stopAnimation();
          return Text(
            widget.text,
            style: effectiveStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          );
        }

        final overflow = textWidth - availableWidth;

        // Queue animation start after layout without triggering setState in build
        if (_lastOverflow != overflow || !_isLoopRunning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startLoopIfNeeded(overflow);
            }
          });
        }

        return RepaintBoundary(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: effectiveStyle,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}

