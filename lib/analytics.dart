import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models.dart';

enum TimelineFilter { thisMonth, thisYear, allTime, custom }

class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const AnalyticsScreen({super.key, required this.transactions});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimelineFilter _selectedFilter = TimelineFilter.thisMonth;
  late DateTime _startDate;
  late DateTime _endDate;
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
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
        // Keep existing custom dates, or default to last 30 days if not set
        break;
    }
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: _selectedFilter == TimelineFilter.custom ? _startDate : now.subtract(const Duration(days: 30)),
        end: _selectedFilter == TimelineFilter.custom ? _endDate : now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
            datePickerTheme: const DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = TimelineFilter.custom;
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999, 999);
      });
    }
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
      spentPercentageOfCredits = 100.0; // Overspent/No credits
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '// ANALYTICS',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Timeline Selector
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(TimelineFilter.thisMonth, 'THIS MONTH'),
                        const SizedBox(width: 8),
                        _buildFilterChip(TimelineFilter.thisYear, 'THIS YEAR'),
                        const SizedBox(width: 8),
                        _buildFilterChip(TimelineFilter.allTime, 'ALL TIME'),
                        const SizedBox(width: 8),
                        _buildFilterChip(TimelineFilter.custom, 'CUSTOM RANGE'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Current selection range preview
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF111111),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF808080), width: 1),
                        top: BorderSide(color: Color(0xFF808080), width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getRangeLabel().toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedFilter == TimelineFilter.custom)
                          GestureDetector(
                            onTap: _selectCustomRange,
                            child: const Text(
                              '[EDIT RANGE]',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                children: [
                  // Ratio Card
                  _buildRatioBlock(totalCredits, totalSpends, spentPercentageOfCredits),
                  const SizedBox(height: 24),

                  // Spend Pie Chart Section
                  _buildPieChartSection(tagSpends, totalSpends),
                  const SizedBox(height: 24),

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

  Widget _buildFilterChip(TimelineFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        if (filter == TimelineFilter.custom) {
          _selectCustomRange();
        } else {
          setState(() {
            _selectedFilter = filter;
            _updateDateRange();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black,
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF808080),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFFAAAAAA),
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 11,
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

  Widget _buildRatioBlock(double credit, double debit, double percent) {
    final isOverspent = debit > credit && credit > 0;
    final displayPercent = percent > 100 ? 100.0 : percent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF808080), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CREDIT TO SPEND RATIO',
                style: TextStyle(
                  color: Color(0xFF888888),
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
                  fontSize: 11,
                  color: isOverspent ? const Color(0xFFFF1E1E) : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final filledWidth = width * (displayPercent / 100);
                return Row(
                  children: [
                    if (filledWidth > 0)
                      Container(
                        width: filledWidth - 3, // account for border
                        color: isOverspent ? const Color(0xFFFF1E1E) : const Color(0xFF00FF66),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IN: ₹${credit.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF00FF66),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'OUT: ₹${debit.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF1E1E),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(Map<String, double> tagSpends, double totalSpends) {
    if (tagSpends.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF808080), width: 1.5),
        ),
        child: const Text(
          '// NO SPENDING DATA IN TIMELINE',
          style: TextStyle(
            color: Color(0xFF888888),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final colors = [
      const Color(0xFFFF1E1E), // Red
      const Color(0xFF00FF66), // Green
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFFCC00), // Yellow
      const Color(0xFF0066FF), // Blue
      const Color(0xFFFF6600), // Orange
      const Color(0xFF9900FF), // Purple
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
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'monospace',
          ),
          badgeWidget: null,
          showTitle: entry.value / totalSpends > 0.08, // only show if > 8%
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF808080), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SPEND BY CATEGORY',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          // Pie Chart
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
                      _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: sections,
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
              swapAnimationCurve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 16),
          // Legend Table
          const Divider(),
          const SizedBox(height: 8),
          ...List.generate(sortedEntries.length, (index) {
            final entry = sortedEntries[index];
            final color = colors[index % colors.length];
            final percentage = (entry.value / totalSpends) * 100;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '₹${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFF888888),
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
    );
  }

  Widget _buildTrendGraphSection(List<Transaction> filteredTransactions) {
    // Generate trend data points
    final Map<String, double> graphPoints = {};
    final List<String> orderedKeys = [];

    // Filter to Debits only
    final debits = filteredTransactions.where((tx) => !tx.isCredit).toList();

    if (debits.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF808080), width: 1.5),
        ),
        child: const Text(
          '// NO SPEND TREND IN TIMELINE',
          style: TextStyle(
            color: Color(0xFF888888),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final int daysInRange = _endDate.difference(_startDate).inDays + 1;

    if (daysInRange <= 31) {
      // Group by Day (daily spends)
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
    } else {
      // Group by Month (monthly spends)
      // Get all months in range
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
    }

    // Build BarGroups
    double maxVal = 0.0;
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < orderedKeys.length; i++) {
      final key = orderedKeys[i];
      final val = graphPoints[key]!;
      if (val > maxVal) maxVal = val;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFFFF1E1E),
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              borderSide: const BorderSide(color: Colors.white, width: 1),
            ),
          ],
        ),
      );
    }

    if (maxVal == 0) {
      maxVal = 100.0; // default range boundary
    }

    // Horizontal Scrollable BarChart view
    final double chartContentWidth = orderedKeys.length * 36.0 + 40.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF808080), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SPENDING TREND',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartContentWidth > MediaQuery.of(context).size.width - 64
                  ? chartContentWidth
                  : MediaQuery.of(context).size.width - 64,
              height: 220,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 12.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.15,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.white,
                        tooltipBorder: const BorderSide(color: Colors.black, width: 1.5),
                        tooltipRoundedRadius: 4,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final key = orderedKeys[groupIndex];
                          String label = '';
                          if (daysInRange <= 31) {
                            final parsedDate = DateFormat('yyyy-MM-dd').parse(key);
                            label = DateFormat('dd MMM').format(parsedDate);
                          } else {
                            final parsedDate = DateFormat('yyyy-MM').parse(key);
                            label = DateFormat('MMM yy').format(parsedDate);
                          }
                          return BarTooltipItem(
                            '$label\n',
                            const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: '₹${rod.toY.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFFF1E1E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            // Show concise money values (e.g. 5k, 10k)
                            String text = '';
                            if (value >= 1000) {
                              text = '₹${(value / 1000).toStringAsFixed(0)}K';
                            } else {
                              text = '₹${value.toStringAsFixed(0)}';
                            }
                            return Text(
                              text,
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= orderedKeys.length) {
                              return const SizedBox();
                            }
                            final key = orderedKeys[index];
                            String text = '';
                            if (daysInRange <= 31) {
                              text = key.substring(8); // Day number
                            } else {
                              // Month (e.g. "2026-07" -> "JUL")
                              final monthInt = int.parse(key.substring(5));
                              const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                              text = months[monthInt - 1];
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 9,
                                  fontFamily: 'monospace',
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
                      horizontalInterval: maxVal / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFF222222),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFF808080), width: 1.5),
                        left: BorderSide(color: Color(0xFF808080), width: 1.5),
                      ),
                    ),
                    barGroups: barGroups,
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 300),
                  swapAnimationCurve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
