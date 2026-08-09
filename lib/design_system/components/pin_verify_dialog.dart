import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

/// Tactile, sleek dialog to verify the user's current 4-digit security PIN before turning off security.
class PinVerifyDialog extends StatefulWidget {
  final Future<bool> Function(String pin) onVerifyPin;
  final String title;
  final String subtitle;

  const PinVerifyDialog({
    super.key,
    required this.onVerifyPin,
    this.title = 'Verify Current Security PIN',
    this.subtitle = 'Enter your 4-digit PIN to turn off security lock',
  });

  static Future<bool?> show({
    required BuildContext context,
    required Future<bool> Function(String pin) onVerifyPin,
    String title = 'Verify Current Security PIN',
    String subtitle = 'Enter your 4-digit PIN to turn off security lock',
  }) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: PinVerifyDialog(
              onVerifyPin: onVerifyPin,
              title: title,
              subtitle: subtitle,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return SlideTransition(position: slideAnimation, child: child);
      },
    );
  }

  @override
  State<PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<PinVerifyDialog> {
  String _currentPin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _onKeyPress(String val) {
    if (_isVerifying || _currentPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _errorMessage = null;
      _currentPin += val;
    });

    if (_currentPin.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    final isValid = await widget.onVerifyPin(_currentPin);

    if (isValid) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _errorMessage = 'Incorrect Security PIN. Try again.';
          _currentPin = '';
          _isVerifying = false;
        });
      }
    }
  }

  void _onBackspace() {
    if (_isVerifying) return;
    HapticFeedback.lightImpact();
    if (_currentPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  void _onClear() {
    if (_isVerifying) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentPin = '';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final topPadding = MediaQuery.of(context).padding.top;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      margin: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder(context), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                widget.subtitle,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 16),

              // PIN 4-Dot Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _currentPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: isFilled ? 18 : 14,
                    height: isFilled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? primaryColor : AppColors.cardBorder(context),
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.debitRed, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 16),

              // Numeric Keypad Grid
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Column(
                  children: [
                    _buildKeyRow(['1', '2', '3']),
                    const SizedBox(height: 8),
                    _buildKeyRow(['4', '5', '6']),
                    const SizedBox(height: 8),
                    _buildKeyRow(['7', '8', '9']),
                    const SizedBox(height: 8),
                    _buildKeyRow(['C', '0', '⌫']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (key == 'C') {
                    _onClear();
                  } else if (key == '⌫') {
                    _onBackspace();
                  } else {
                    _onKeyPress(key);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: key == 'C' || key == '⌫' ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: key == 'C'
                          ? AppColors.debitRed
                          : key == '⌫'
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
