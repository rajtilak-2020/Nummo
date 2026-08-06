import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/nummo_button.dart';

/// Clean expense math calculator bottom sheet.
class CalculatorSheet extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onApply;
  final bool showApplyButton;

  const CalculatorSheet({
    super.key,
    required this.initialValue,
    required this.onApply,
    this.showApplyButton = true,
  });

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  String _displayValue = '0';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _expression = widget.initialValue.toStringAsFixed(2);
      _displayValue = _expression;
    }
  }

  void _onPress(String char) {
    HapticFeedback.selectionClick();
    setState(() {
      if (char == 'C') {
        _expression = '';
        _displayValue = '0';
      } else if (char == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _displayValue = _expression.isEmpty ? '0' : _expression;
        }
      } else if (char == '=') {
        _evaluate();
      } else {
        _expression += char;
        _displayValue = _expression;
      }
    });
  }

  void _evaluate() {
    try {
      final sanitized = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final double? result = _simpleEval(sanitized);
      if (result != null && result.isFinite && !result.isNaN && result >= 0) {
        setState(() {
          _displayValue = result.toStringAsFixed(2);
          _expression = _displayValue;
        });
      } else {
        setState(() {
          _displayValue = 'Invalid Calculation';
        });
      }
    } catch (_) {
      setState(() {
        _displayValue = 'Invalid Calculation';
      });
    }
  }

  double? _simpleEval(String expr) {
    try {
      // Basic split evaluation for +, -, *, /
      final tokens = RegExp(r'(\d+\.?\d*)|([\+\-\*/])').allMatches(expr).map((m) => m.group(0)!).toList();
      if (tokens.isEmpty) return 0.0;
      double current = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final next = double.parse(tokens[i + 1]);
        if (op == '+') current += next;
        if (op == '-') current -= next;
        if (op == '*') current *= next;
        if (op == '/') {
          if (next == 0) return null;
          current /= next;
        }
      }
      return current;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? parsedVal = double.tryParse(_displayValue);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculator',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Display Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground(context),
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Text(
              _displayValue,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Keypad Buttons Grid
          Column(
            children: [
              for (var row in [
                ['C', '÷', '×', '⌫'],
                ['7', '8', '9', '-'],
                ['4', '5', '6', '+'],
                ['1', '2', '3', '='],
                ['0', '.', '00'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: row.map((char) {
                      final isOp = ['C', '÷', '×', '⌫', '-', '+', '='].contains(char);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          child: InkWell(
                            onTap: () => _onPress(char),
                            borderRadius: BorderRadius.circular(AppRadius.control),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isOp
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                    : AppColors.scaffoldBackground(context),
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                border: Border.all(color: AppColors.cardBorder(context)),
                              ),
                              child: Text(
                                char,
                                style: TextStyle(
                                  color: isOp
                                      ? Theme.of(context).colorScheme.primary
                                      : AppColors.textPrimary(context),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
          if (widget.showApplyButton) ...[
            const SizedBox(height: AppSpacing.md),
            NummoButton(
              text: 'Apply Amount',
              onPressed: (parsedVal != null && parsedVal > 0)
                  ? () {
                      widget.onApply(parsedVal);
                      Navigator.of(context).pop();
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
