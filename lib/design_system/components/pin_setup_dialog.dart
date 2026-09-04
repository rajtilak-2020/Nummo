import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

/// Tactile, sleek top-down modal dialog for setting up or changing 4-digit security PIN.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  /// Presents the modal as a top-down sliding dialog and returns the confirmed 4-digit PIN string.
  static Future<String?> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<String>(
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
            child: const PinSetupDialog(),
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
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  int _step = 1; // 1 = Enter New PIN, 2 = Confirm PIN
  String _firstPin = '';
  String _currentPin = '';
  String? _errorMessage;

  void _onKeyPress(String val) {
    HapticFeedback.lightImpact();
    if (_currentPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _currentPin += val;
    });

    if (_currentPin.length == 4) {
      _handleStepCompletion();
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_currentPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentPin = '';
      _errorMessage = null;
    });
  }

  void _handleStepCompletion() {
    if (_step == 1) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _firstPin = _currentPin;
            _currentPin = '';
            _step = 2;
          });
        }
      });
    } else {
      if (_currentPin == _firstPin) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            Navigator.of(context).pop(_currentPin);
          }
        });
      } else {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _errorMessage = 'PINs do not match. Try again.';
              _currentPin = '';
              _firstPin = '';
              _step = 1;
            });
          }
        });
      }
    }
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
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _step == 1 ? 'Set 4-Digit Security PIN' : 'Confirm Security PIN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                _step == 1 ? 'Choose a memorable 4-digit PIN' : 'Re-enter your 4-digit PIN to confirm',
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

              // Numeric 3x4 Keypad Grid
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
