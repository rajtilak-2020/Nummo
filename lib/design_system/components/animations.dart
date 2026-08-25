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

  const NummoCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.showSign = false,
    this.isCredit,
    this.isMasked = false,
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
    if (widget.isMasked) {
      return Text(
        MoneyFormatter.format(
          widget.value,
          showSign: widget.showSign,
          isCredit: widget.isCredit ?? (widget.value >= 0),
          isMasked: true,
        ),
        style: widget.style,
      );
    }

    return Text(
      MoneyFormatter.format(
        _currentDisplayValue,
        showSign: widget.showSign,
        isCredit: widget.isCredit ?? (_currentDisplayValue >= 0),
      ),
      style: widget.style,
    );
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
