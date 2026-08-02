import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'theme.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _equation = '';
  String _operand1 = '';
  String _operator = '';
  bool _shouldReset = false;

  static const List<String> _errorMessages = [
    "Nice try, Einstein.",
    "Math.exe has stopped.",
    "Division by zero is a crime.",
    "Black hole created.",
    "A math teacher is crying.",
    "I can't do that, Dave.",
    "Error code: ID-10-T.",
    "Brain overload. Need coffee.",
    "Bold move, human.",
    "Are you testing my limits?",
    "Divide by zero? Brave.",
    "Does not compute.",
    "Kaboom! Just kidding.",
    "404: Logic Not Found.",
    "Try counting on fingers.",
    "Math laws violated.",
    "The universe collapsed.",
    "Calculator says: No.",
    "Error: Ask a human.",
    "Nice try. No cookie.",
    "Dividing by zero is illegal.",
    "My circuits hurt.",
    "Error: Go back to school.",
    "You broke the math rules.",
    "Is this a trick question?",
    "Error: Try addition.",
    "Infinite loop avoided.",
    "Calculation too spicy.",
    "Newton would be mad.",
    "Error: Logic went on vacation.",
    "Please don't do that again.",
    "Error: Quantum paradox.",
    "Zero divide? Strictly prohibited.",
    "System crash in 3, 2, 1...",
    "Error: Absolute nonsense.",
    "You broke the matrix.",
    "Error: Confused calculator.",
    "Math.random() failed.",
    "Error: Too much power.",
    "I'm a calculator, not a wizard.",
    "Divided by zero? Boom.",
    "Error: Math.err",
    "Go ask Siri.",
    "Error: User error.",
    "Error: Sarcastic calculator.",
    "Stop breaking things.",
    "Error: Math police alerted.",
    "Nice try. Try again.",
    "Error: Out of bounds.",
    "Error: Brain not found.",
    "Zero division? Not today.",
    "Error: Do math, not war.",
    "Calculations are hard.",
    "Error: Division.fail",
    "Congratulations, you broke it.",
    "Error: No logic present.",
    "Error: System confused.",
    "Math is hard, isn't it?",
    "Error: Invalid brainwave.",
    "Divide by zero? Highly illegal.",
    "Error: Computer says no.",
    "Error: Glitch in the matrix.",
    "Error: Error displaying error.",
    "Stop. Just stop.",
    "Error: Divide.error",
    "Did you fail third grade?",
    "Error: Sarcasm engaged.",
    "Error: Syntax error.",
    "Zero is not your friend.",
    "Error: Calculator on strike.",
    "Error: Math is broken.",
    "Try another number.",
    "Error: Logic.exe crashed.",
    "Division by zero? Seriously?",
    "Error: Math emergency.",
    "Error: Uncomputable.",
    "Error: Bad input.",
    "Error: Calculator fainted.",
    "Error: Math.rip",
    "Error: System meltdown.",
    "Don't push my buttons.",
    "Error: Division by zero? Nope.",
    "Error: Invalid request.",
    "Error: Try fingers.",
    "Error: Mind blown.",
    "Error: Arithmetic failure.",
    "Error: Calculation failed.",
    "Error: Too hard for me.",
    "Error: Try abacus.",
    "Error: Out of range.",
    "Error: Brain.exe not found.",
    "Error: Math rules broken.",
    "Error: Zero division error.",
    "Error: Math is too hard.",
    "Error: Try counting sheep.",
    "Error: Calculator tired.",
    "Error: Logic error.",
    "Error: Infinite stupidity.",
    "Error: Zero cannot divide.",
    "Error: Game over."
  ];

  void _showError() {
    HapticFeedback.vibrate();
    final randIndex = math.Random().nextInt(_errorMessages.length);
    setState(() {
      _display = _errorMessages[randIndex];
      _equation = '';
      _operand1 = '';
      _operator = '';
      _shouldReset = true;
    });
  }

  void _onNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_display == '0' || _shouldReset || _errorMessages.contains(_display)) {
        _display = number;
        _shouldReset = false;
      } else {
        _display += number;
      }
    });
  }

  void _onDotPressed() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_shouldReset || _errorMessages.contains(_display)) {
        _display = '0.';
        _shouldReset = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperatorPressed(String op) {
    HapticFeedback.lightImpact();
    if (_errorMessages.contains(_display)) return;
    setState(() {
      if (_operand1.isNotEmpty && _operator.isNotEmpty && !_shouldReset) {
        _evaluateInternal();
      }
      _operand1 = _display;
      _operator = op;
      _equation = '$_operand1 $_operator';
      _shouldReset = true;
    });
  }

  void _onEqualPressed() {
    HapticFeedback.mediumImpact();
    if (_operand1.isEmpty || _operator.isEmpty || _errorMessages.contains(_display)) return;
    setState(() {
      _equation = '$_operand1 $_operator $_display =';
      _evaluateInternal();
    });
  }

  void _evaluateInternal() {
    double num1 = double.tryParse(_operand1) ?? 0.0;
    double num2 = double.tryParse(_display) ?? 0.0;
    double result = 0.0;

    if (_operator == '/' && num2 == 0.0) {
      _showError();
      return;
    }

    switch (_operator) {
      case '+':
        result = num1 + num2;
        break;
      case '-':
        result = num1 - num2;
        break;
      case '*':
        result = num1 * num2;
        break;
      case '/':
        result = num1 / num2;
        break;
    }

    String resultStr = result.toString();
    if (resultStr.endsWith('.0')) {
      resultStr = resultStr.substring(0, resultStr.length - 2);
    }
    _display = resultStr;
    _operand1 = '';
    _operator = '';
    _shouldReset = true;
  }

  void _onClearPressed() {
    HapticFeedback.selectionClick();
    setState(() {
      _display = '0';
      _equation = '';
      _operand1 = '';
      _operator = '';
      _shouldReset = false;
    });
  }

  void _onToggleSignPressed() {
    HapticFeedback.lightImpact();
    if (_errorMessages.contains(_display) || _display == '0') return;
    setState(() {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
    });
  }

  void _onPercentPressed() {
    HapticFeedback.lightImpact();
    if (_errorMessages.contains(_display)) return;
    double val = double.tryParse(_display) ?? 0.0;
    setState(() {
      double result = val / 100.0;
      String resultStr = result.toString();
      if (resultStr.endsWith('.0')) {
        resultStr = resultStr.substring(0, resultStr.length - 2);
      }
      _display = resultStr;
      _shouldReset = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debitColor = AppColors.debit(context);
    final creditColor = AppColors.credit(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display Card
              Expanded(
                child: Card(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_equation.isNotEmpty)
                          Text(
                            _equation,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontFamily: 'monospace',
                              fontSize: 18,
                            ),
                          ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _display,
                            style: TextStyle(
                              color: _errorMessages.contains(_display)
                                  ? debitColor
                                  : theme.colorScheme.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Button Grid
              Column(
                children: [
                  Row(
                    children: [
                      _buildCalcBtn('C', color: debitColor, isOperator: true),
                      const SizedBox(width: 8),
                      _buildCalcBtn('+/-', isOperator: true),
                      const SizedBox(width: 8),
                      _buildCalcBtn('%', isOperator: true),
                      const SizedBox(width: 8),
                      _buildCalcBtn('/', isOperator: true, accentColor: creditColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCalcBtn('7'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('8'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('9'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('*', isOperator: true, accentColor: creditColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCalcBtn('4'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('5'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('6'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('-', isOperator: true, accentColor: creditColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCalcBtn('1'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('2'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('3'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('+', isOperator: true, accentColor: creditColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCalcBtn('0'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('.'),
                      const SizedBox(width: 8),
                      _buildCalcBtn('=', flex: 2, isOperator: true, accentColor: creditColor, isFillAccent: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalcBtn(
    String label, {
    int flex = 1,
    bool isOperator = false,
    Color? color,
    Color? accentColor,
    bool isFillAccent = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor = theme.cardColor;
    if (isFillAccent && accentColor != null) {
      bgColor = accentColor;
    } else if (isOperator) {
      bgColor = isDark ? const Color(0xFF272730) : const Color(0xFFEFEFF4);
    }

    Color textColor = theme.colorScheme.onSurface;
    if (isFillAccent) {
      textColor = Colors.white;
    } else if (color != null) {
      textColor = color;
    } else if (accentColor != null) {
      textColor = accentColor;
    } else if (isOperator) {
      textColor = AppColors.textSecondary(context);
    }

    return Expanded(
      flex: flex,
      child: SizedBox(
        height: 64,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (label == 'C') {
                _onClearPressed();
              } else if (label == '+/-') {
                _onToggleSignPressed();
              } else if (label == '%') {
                _onPercentPressed();
              } else if (label == '/' || label == '*' || label == '-' || label == '+') {
                _onOperatorPressed(label);
              } else if (label == '=') {
                _onEqualPressed();
              } else if (label == '.') {
                _onDotPressed();
              } else {
                _onNumberPressed(label);
              }
            },
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
