import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models.dart';
import 'theme.dart';

enum TimelineFilter { today, thisWeek, thisMonth, thisYear, allTime, custom }

class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const AnalyticsScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimelineFilter _selectedFilter = TimelineFilter.thisMonth;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1, 0, 0, 0);
  DateTime _endDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateUtils.getDaysInMonth(DateTime.now().year, DateTime.now().month),
      23,
      59,
      59,
      999);
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case TimelineFilter.today:
        _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0, 0, 0);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        _startDate = DateTime(monday.year, monday.month, monday.day, 0, 0, 0, 0, 0);
        _endDate = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.thisMonth:
        _startDate = DateTime(now.year, now.month, 1, 0, 0, 0, 0, 0);
        final days = DateUtils.getDaysInMonth(now.year, now.month);
        _endDate = DateTime(now.year, now.month, days, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.thisYear:
        _startDate = DateTime(now.year, 1, 1, 0, 0, 0, 0, 0);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.allTime:
        _startDate = DateTime(1970, 1, 1, 0, 0, 0, 0, 0);
        _endDate = DateTime(2100, 12, 31, 23, 59, 59, 999, 999);
        break;
      case TimelineFilter.custom:
        break;
    }
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    DateTime tempStart = _selectedFilter == TimelineFilter.custom
        ? _startDate
        : DateTime(now.year, now.month, 1);
    DateTime tempEnd = _selectedFilter == TimelineFilter.custom ? _endDate : now;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color(0xFF333333), width: 1),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateFormat = DateFormat('dd MMM yyyy');

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '// CUSTOM DATE RANGE',
                          style: TextStyle(
                            color: Color(0xFF00FF66),
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Start & End Date Selection Blocks
                    Row(
                      children: [
                        // Start Date Block
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2000),
                                lastDate: tempEnd,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF00FF66),
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF121212),
                                        onSurface: Colors.white,
                                      ),
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
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F0F),
                                border: Border.all(color: const Color(0xFF333333), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'START DATE',
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateFormat.format(tempStart).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF00FF66)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // End Date Block
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF00FF66),
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF121212),
                                        onSurface: Colors.white,
                                      ),
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
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F0F),
                                border: Border.all(color: const Color(0xFF333333), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'END DATE',
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateFormat.format(tempEnd).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(Icons.event_repeat_rounded, size: 14, color: Color(0xFF00FF66)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Quick Presets Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('LAST 7 DAYS', () {
                            setModalState(() {
                              tempEnd = DateTime.now();
                              tempStart = tempEnd.subtract(const Duration(days: 7));
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildPresetChip('LAST 30 DAYS', () {
                            setModalState(() {
                              tempEnd = DateTime.now();
                              tempStart = tempEnd.subtract(const Duration(days: 30));
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildPresetChip('LAST 90 DAYS', () {
                            setModalState(() {
                              tempEnd = DateTime.now();
                              tempStart = tempEnd.subtract(const Duration(days: 90));
                            });
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Apply Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF66),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _selectedFilter = TimelineFilter.custom;
                            _startDate = DateTime(tempStart.year, tempStart.month, tempStart.day, 0, 0, 0);
                            _endDate = DateTime(tempEnd.year, tempEnd.month, tempEnd.day, 23, 59, 59, 999);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'APPLY DATE RANGE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _getRangeLabel() {
    if (_selectedFilter == TimelineFilter.allTime) {
      return 'All Time Ledger';
    }
    final format = DateFormat('dd MMM yyyy');
    return '${format.format(_startDate)} - ${format.format(_endDate)}';
  }

  void _showFilterSelectionModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color(0xFF333333), width: 1),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TIMELINE FILTER',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFilterModalOption(TimelineFilter.today, 'TODAY', Icons.today_rounded),
                    _buildFilterModalOption(TimelineFilter.thisWeek, 'THIS WEEK', Icons.date_range_rounded),
                    _buildFilterModalOption(TimelineFilter.thisMonth, 'THIS MONTH', Icons.calendar_month_rounded),
                    _buildFilterModalOption(TimelineFilter.thisYear, 'THIS YEAR', Icons.calendar_today_rounded),
                    _buildFilterModalOption(TimelineFilter.allTime, 'ALL TIME', Icons.all_inclusive_rounded),
                    _buildFilterModalOption(TimelineFilter.custom, 'CUSTOM RANGE', Icons.edit_calendar_rounded),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterModalOption(TimelineFilter filter, String title, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E1E1E) : Colors.black,
        border: Border.all(
          color: isSelected ? const Color(0xFF00FF66) : const Color(0xFF262626),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? const Color(0xFF00FF66) : const Color(0xFFAAAAAA), size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
            fontFamily: 'monospace',
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF66), size: 20)
            : null,
        onTap: () async {
          Navigator.pop(context);
          if (filter == TimelineFilter.custom) {
            await _selectCustomRange();
          } else {
            setState(() {
              _selectedFilter = filter;
              _updateDateRange();
            });
          }
        },
      ),
    );
  }

  List<Transaction> _getFilteredTransactions() {
    return widget.transactions.where((tx) {
      final t = tx.timestamp;
      return (t.isAfter(_startDate) || t.isAtSameMomentAs(_startDate)) &&
          (t.isBefore(_endDate) || t.isAtSameMomentAs(_endDate));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _getFilteredTransactions();

    double totalCredits = 0.0;
    double totalSpends = 0.0;
    final Map<String, double> tagSpends = {};

    for (var tx in filteredTransactions) {
      if (tx.isCredit) {
        totalCredits += tx.amount;
      } else {
        totalSpends += tx.amount;
        final tag = tx.tag ?? 'OTHERS';
        tagSpends[tag] = (tagSpends[tag] ?? 0.0) + tx.amount;
      }
    }

    double spentPercentageOfCredits = 0.0;
    if (totalCredits > 0) {
      spentPercentageOfCredits = (totalSpends / totalCredits) * 100;
    } else if (totalSpends > 0) {
      spentPercentageOfCredits = 100.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ANALYTICS & STATS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filter Timeline',
            icon: const Icon(Icons.filter_alt_rounded),
            onPressed: _showFilterSelectionModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Range Display Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getRangeLabel().toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 24.0),
                children: [
                  // Ratio Card
                  _buildRatioBlock(
                      totalCredits, totalSpends, spentPercentageOfCredits),
                  const SizedBox(height: 16),

                  // Spend Pie Chart Section
                  _buildPieChartSection(tagSpends, totalSpends),
                  const SizedBox(height: 16),

                  // Spend Trend Graph Section
                  _buildTrendGraphSection(filteredTransactions),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildRatioBlock(double credit, double debit, double percent) {
    final isOverspent = debit > credit && credit > 0;
    final displayPercent = percent > 100 ? 100.0 : percent;
    final debitColor = AppColors.debit(context);
    final creditColor = AppColors.credit(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CREDIT TO SPEND RATIO',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}% SPENT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isOverspent
                        ? debitColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 14,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final filledWidth = width * (displayPercent / 100);
                    return Row(
                      children: [
                        if (filledWidth > 0)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: filledWidth,
                            color: isOverspent ? debitColor : creditColor,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IN: ₹${credit.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: creditColor,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'OUT: ₹${debit.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: debitColor,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(
      Map<String, double> tagSpends, double totalSpends) {
    if (tagSpends.isEmpty) {
      return Card(
        child: Container(
          height: 160,
          alignment: Alignment.center,
          child: Text(
            'No spending data in selected timeline',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final colors = [
      AppColors.debit(context),
      AppColors.credit(context),
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
    ];

    final sortedEntries = tagSpends.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final color = colors[i % colors.length];
      final isTouched = i == _touchedPieIndex;
      final double radius = isTouched ? 65.0 : 55.0;

      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          title: '${(entry.value / totalSpends * 100).toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
          showTitle: entry.value / totalSpends > 0.08,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SPEND BY CATEGORY',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: sections,
                ),
                swapAnimationDuration: const Duration(milliseconds: 300),
                swapAnimationCurve: Curves.easeInOut,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...List.generate(sortedEntries.length, (index) {
              final entry = sortedEntries[index];
              final color = colors[index % colors.length];
              final percentage = (entry.value / totalSpends) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _calculateNiceInterval(double maxVal) {
    if (maxVal <= 0) return 50.0;
    final targetInterval = maxVal / 3.0;
    final magnitude = math.pow(10, (math.log(targetInterval) / math.ln10).floor()).toDouble();
    final residual = targetInterval / magnitude;

    double niceResidual;
    if (residual < 1.5) {
      niceResidual = 1.0;
    } else if (residual < 3.0) {
      niceResidual = 2.0;
    } else if (residual < 7.0) {
      niceResidual = 5.0;
    } else {
      niceResidual = 10.0;
    }
    return niceResidual * magnitude;
  }

  Widget _buildTrendGraphSection(List<Transaction> filteredTransactions) {
    final Map<String, double> graphPoints = {};
    final List<String> orderedKeys = [];

    final debits = filteredTransactions.where((tx) => !tx.isCredit).toList();

    if (debits.isEmpty) {
      return Card(
        child: Container(
          height: 160,
          alignment: Alignment.center,
          child: Text(
            'No spend trend in selected timeline',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final int daysInRange = _endDate.difference(_startDate).inDays + 1;

    if (daysInRange <= 31) {
      for (int i = 0; i < daysInRange; i++) {
        final d = _startDate.add(Duration(days: i));
        final fullKey = DateFormat('yyyy-MM-dd').format(d);
        graphPoints[fullKey] = 0.0;
        orderedKeys.add(fullKey);
      }
      for (var tx in debits) {
        final key = DateFormat('yyyy-MM-dd').format(tx.timestamp);
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    } else if (daysInRange <= 365) {
      DateTime cursor = DateTime(_startDate.year, _startDate.month, 1);
      while (cursor.isBefore(_endDate)) {
        final key = DateFormat('yyyy-MM').format(cursor);
        graphPoints[key] = 0.0;
        orderedKeys.add(key);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      for (var tx in debits) {
        final key = DateFormat('yyyy-MM').format(tx.timestamp);
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    } else {
      int startYear = _startDate.year;
      int endYear = _endDate.year;

      if (_selectedFilter == TimelineFilter.allTime) {
        if (debits.isNotEmpty) {
          final years = debits.map((tx) => tx.timestamp.year).toList();
          years.sort();
          startYear = years.first;
          endYear = years.last;
        } else {
          startYear = DateTime.now().year;
          endYear = DateTime.now().year;
        }
      }

      for (int year = startYear; year <= endYear; year++) {
        final key = year.toString();
        graphPoints[key] = 0.0;
        orderedKeys.add(key);
      }

      for (var tx in debits) {
        final key = tx.timestamp.year.toString();
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    }

    double maxVal = 0.0;
    for (var val in graphPoints.values) {
      if (val > maxVal) maxVal = val;
    }

    if (maxVal == 0) maxVal = 100.0;

    final double yInterval = _calculateNiceInterval(maxVal);
    final double maxY = ((maxVal * 1.4 / yInterval).ceil()) * yInterval;

    final List<BarChartGroupData> barGroups = [];
    final debitColor = AppColors.debit(context);

    for (int i = 0; i < orderedKeys.length; i++) {
      final key = orderedKeys[i];
      final val = graphPoints[key]!;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: debitColor,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SPEND TREND',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // Fixed Y-Axis Titles on Left
                  SizedBox(
                    width: 48,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        minY: 0,
                        barTouchData: BarTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        barGroups: [],
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: yInterval,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value > maxY) {
                                  return const SizedBox();
                                }
                                String text = '';
                                if (value >= 1000) {
                                  text = '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
                                } else {
                                  text = '₹${value.toInt()}';
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 2,
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Horizontally Scrollable Bars & X-Axis Titles on Right
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minChartWidth = constraints.maxWidth;
                        final computedWidth = orderedKeys.length * 36.0;
                        final chartWidth = math.max(minChartWidth, computedWidth);

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxY,
                                minY: 0,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    tooltipMargin: 6,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    tooltipRoundedRadius: 8,
                                    getTooltipColor: (group) =>
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF272732)
                                            : const Color(0xFF1E293B),
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final key = orderedKeys[group.x.toInt()];
                                      String label = '';
                                      if (daysInRange <= 31) {
                                        final parsedDate = DateFormat('yyyy-MM-dd').parse(key);
                                        label = DateFormat('dd MMM yyyy').format(parsedDate);
                                      } else if (daysInRange <= 365) {
                                        final parsedDate = DateFormat('yyyy-MM').parse(key);
                                        label = DateFormat('MMM yyyy').format(parsedDate);
                                      } else {
                                        label = key;
                                      }
                                      return BarTooltipItem(
                                        '$label\n',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: '₹${rod.toY.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: debitColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 28,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= orderedKeys.length) {
                                          return const SizedBox();
                                        }
                                        final key = orderedKeys[index];
                                        String text = '';
                                        if (daysInRange <= 31) {
                                          text = key.substring(8);
                                        } else if (daysInRange <= 365) {
                                          final monthInt = int.parse(key.substring(5));
                                          const months = [
                                            'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                                            'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
                                          ];
                                          text = months[monthInt - 1];
                                        } else {
                                          text = key;
                                        }
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          space: 6,
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: yInterval,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: AppColors.cardBorder(context),
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 300),
                              swapAnimationCurve: Curves.easeInOut,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsHeroCarousel extends StatefulWidget {
  final List<Transaction> filteredTransactions;
  final double totalBalance;
  final DateTime startDate;
  final DateTime endDate;
  final TimelineFilter selectedFilter;

  const AnalyticsHeroCarousel({
    super.key,
    required this.filteredTransactions,
    required this.totalBalance,
    required this.startDate,
    required this.endDate,
    required this.selectedFilter,
  });

  @override
  State<AnalyticsHeroCarousel> createState() => _AnalyticsHeroCarouselState();
}

class _AnalyticsHeroCarouselState extends State<AnalyticsHeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _touchedPieIndex = -1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _calculateNiceInterval(double maxVal) {
    if (maxVal <= 0) return 50.0;
    final targetInterval = maxVal / 3.0;
    final magnitude = math.pow(10, (math.log(targetInterval) / math.ln10).floor()).toDouble();
    final residual = targetInterval / magnitude;

    double niceResidual;
    if (residual < 1.5) {
      niceResidual = 1.0;
    } else if (residual < 3.0) {
      niceResidual = 2.0;
    } else if (residual < 7.0) {
      niceResidual = 5.0;
    } else {
      niceResidual = 10.0;
    }
    return niceResidual * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    double totalCredits = 0.0;
    double totalSpends = 0.0;
    final Map<String, double> tagSpends = {};

    for (var tx in widget.filteredTransactions) {
      if (tx.isCredit) {
        totalCredits += tx.amount;
      } else {
        totalSpends += tx.amount;
        final tag = tx.tag ?? 'OTHERS';
        tagSpends[tag] = (tagSpends[tag] ?? 0.0) + tx.amount;
      }
    }

    double spentPercentageOfCredits = 0.0;
    if (totalCredits > 0) {
      spentPercentageOfCredits = (totalSpends / totalCredits) * 100;
    } else if (totalSpends > 0) {
      spentPercentageOfCredits = 100.0;
    }

    return Column(
      children: [
        SizedBox(
          height: 235,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildBalanceAndRatioCard(totalCredits, totalSpends, spentPercentageOfCredits),
              _buildCategoryPieCard(tagSpends, totalSpends),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Page Indicators (2 dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            final isSelected = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isSelected ? 20 : 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.cardBorder(context),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBalanceAndRatioCard(double credit, double debit, double percent) {
    final balanceColor = widget.totalBalance >= 0
        ? AppColors.credit(context)
        : AppColors.debit(context);
    final isOverspent = debit > credit && credit > 0;
    final displayPercent = percent > 100 ? 100.0 : percent;
    final debitColor = AppColors.debit(context);
    final creditColor = AppColors.credit(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL BALANCE',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOverspent
                        ? debitColor.withValues(alpha: 0.15)
                        : creditColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOverspent ? debitColor : creditColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${percent.toStringAsFixed(1)}% SPENT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: isOverspent
                          ? debitColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.totalBalance >= 0 ? '+' : ''}₹${widget.totalBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: balanceColor,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final filledWidth = width * (displayPercent / 100);
                        return Row(
                          children: [
                            if (filledWidth > 0)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: filledWidth,
                                color: isOverspent ? debitColor : creditColor,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'IN: ₹${credit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: creditColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'OUT: ₹${debit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: debitColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieCard(Map<String, double> tagSpends, double totalSpends) {
    if (tagSpends.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            'NO SPENDING DATA IN SELECTED TIMELINE',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final colors = [
      AppColors.debit(context),
      AppColors.credit(context),
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
    ];

    final sortedEntries = tagSpends.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final color = colors[i % colors.length];
      final isTouched = i == _touchedPieIndex;
      final double radius = isTouched ? 45.0 : 38.0;

      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          title: '${(entry.value / totalSpends * 100).toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
          showTitle: entry.value / totalSpends > 0.08,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SPEND BY CATEGORY',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'SWIPE ➔',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedPieIndex = -1;
                                return;
                              }
                              _touchedPieIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 24,
                        sections: sections,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                      swapAnimationCurve: Curves.easeInOut,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: math.min(sortedEntries.length, 5),
                      itemBuilder: (context, index) {
                        final entry = sortedEntries[index];
                        final color = colors[index % colors.length];
                        final percentage = (entry.value / totalSpends) * 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${entry.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTrendGraphCard(List<Transaction> filteredTransactions) {
    final Map<String, double> graphPoints = {};
    final List<String> orderedKeys = [];

    final debits = filteredTransactions.where((tx) => !tx.isCredit).toList();

    if (debits.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            'NO SPEND TREND IN SELECTED TIMELINE',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final int daysInRange = widget.endDate.difference(widget.startDate).inDays + 1;

    if (daysInRange <= 31) {
      for (int i = 0; i < daysInRange; i++) {
        final d = widget.startDate.add(Duration(days: i));
        final fullKey = DateFormat('yyyy-MM-dd').format(d);
        graphPoints[fullKey] = 0.0;
        orderedKeys.add(fullKey);
      }
      for (var tx in debits) {
        final key = DateFormat('yyyy-MM-dd').format(tx.timestamp);
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    } else if (daysInRange <= 365) {
      DateTime cursor = DateTime(widget.startDate.year, widget.startDate.month, 1);
      while (cursor.isBefore(widget.endDate)) {
        final key = DateFormat('yyyy-MM').format(cursor);
        graphPoints[key] = 0.0;
        orderedKeys.add(key);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      for (var tx in debits) {
        final key = DateFormat('yyyy-MM').format(tx.timestamp);
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    } else {
      int startYear = widget.startDate.year;
      int endYear = widget.endDate.year;

      if (widget.selectedFilter == TimelineFilter.allTime) {
        if (debits.isNotEmpty) {
          final years = debits.map((tx) => tx.timestamp.year).toList();
          years.sort();
          startYear = years.first;
          endYear = years.last;
        } else {
          startYear = DateTime.now().year;
          endYear = DateTime.now().year;
        }
      }

      for (int year = startYear; year <= endYear; year++) {
        final key = year.toString();
        graphPoints[key] = 0.0;
        orderedKeys.add(key);
      }

      for (var tx in debits) {
        final key = tx.timestamp.year.toString();
        if (graphPoints.containsKey(key)) {
          graphPoints[key] = graphPoints[key]! + tx.amount;
        }
      }
    }

    double maxVal = 0.0;
    for (var val in graphPoints.values) {
      if (val > maxVal) maxVal = val;
    }

    if (maxVal == 0) maxVal = 100.0;

    final double yInterval = _calculateNiceInterval(maxVal);
    final double maxY = ((maxVal * 1.4 / yInterval).ceil()) * yInterval;

    final List<BarChartGroupData> barGroups = [];
    final debitColor = AppColors.debit(context);

    for (int i = 0; i < orderedKeys.length; i++) {
      final key = orderedKeys[i];
      final val = graphPoints[key]!;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: debitColor,
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SPEND TREND',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        minY: 0,
                        barTouchData: BarTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        barGroups: [],
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: yInterval,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value > maxY) {
                                  return const SizedBox();
                                }
                                String text = '';
                                if (value >= 1000) {
                                  text = '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
                                } else {
                                  text = '₹${value.toInt()}';
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 2,
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minChartWidth = constraints.maxWidth;
                        final computedWidth = orderedKeys.length * 28.0;
                        final chartWidth = math.max(minChartWidth, computedWidth);

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxY,
                                minY: 0,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    tooltipMargin: 4,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    tooltipRoundedRadius: 6,
                                    getTooltipColor: (group) =>
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF272732)
                                            : const Color(0xFF1E293B),
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final key = orderedKeys[group.x.toInt()];
                                      String label = '';
                                      if (daysInRange <= 31) {
                                        final parsedDate = DateFormat('yyyy-MM-dd').parse(key);
                                        label = DateFormat('dd MMM').format(parsedDate);
                                      } else if (daysInRange <= 365) {
                                        final parsedDate = DateFormat('yyyy-MM').parse(key);
                                        label = DateFormat('MMM yyyy').format(parsedDate);
                                      } else {
                                        label = key;
                                      }
                                      return BarTooltipItem(
                                        '$label\n',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: '₹${rod.toY.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: debitColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 22,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= orderedKeys.length) {
                                          return const SizedBox();
                                        }
                                        final key = orderedKeys[index];
                                        String text = '';
                                        if (daysInRange <= 31) {
                                          text = key.substring(8);
                                        } else if (daysInRange <= 365) {
                                          final monthInt = int.parse(key.substring(5));
                                          const months = [
                                            'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                                            'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
                                          ];
                                          text = months[monthInt - 1];
                                        } else {
                                          text = key;
                                        }
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          space: 4,
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: yInterval,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: AppColors.cardBorder(context),
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 300),
                              swapAnimationCurve: Curves.easeInOut,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

