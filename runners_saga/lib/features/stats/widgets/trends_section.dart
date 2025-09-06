import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:runners_saga/shared/models/run_model.dart';
import 'package:runners_saga/shared/providers/run_providers.dart';
import 'package:runners_saga/core/constants/app_theme.dart';

/// Controls charts aggregation mode
enum _PeriodType { week, month }

/// Reusable trends section placed at the top of the Stats screen
class StatsTrendsSection extends ConsumerStatefulWidget {
  const StatsTrendsSection({super.key});

  @override
  ConsumerState<StatsTrendsSection> createState() => _StatsTrendsSectionState();
}

class _StatsTrendsSectionState extends ConsumerState<StatsTrendsSection> {
  _PeriodType _period = _PeriodType.month;
  int _selectedIndex = 0; // Index in the visible periods list (0 is latest)
  
  // Pace cap: ignore runs slower than this pace in Avg Pace chart (min/km)
  static const double _maxPaceMinPerKm = 12.0;

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(userCompletedRunsProvider);

    // Build UI shell even while loading so layout is stable
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          period: _period,
          onPeriodChanged: (p) => setState(() {
            _period = p;
            _selectedIndex = 0; // reset selection on mode switch
          }),
        ),
        const SizedBox(height: 8),
        _PeriodScroller(
          period: _period,
          selectedIndex: _selectedIndex,
          onSelected: (i) => setState(() => _selectedIndex = i),
        ),
        const SizedBox(height: 16),
        runsAsync.when(
          data: (runs) {
            final model = _aggregate(runs, _period);
            // index 0 is latest (current month/week). Convert to chronological for charts
            final toChrono = (List<double> values) => values.reversed.toList();
            final distance = toChrono(model.totalDistanceKm);
            final timeHours = toChrono(model.totalTimeHours);
            final longest = toChrono(model.longestDistanceKm);
            final avgPace = toChrono(model.avgPaceMinPerKm);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChartCard(
                  title: 'Total Distance (km)',
                  values: distance,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Total Time (h)',
                  values: timeHours,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Longest Distance (km)',
                  values: longest,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Avg Pace (min/km) – lower is better',
                  values: avgPace,
                  color: Theme.of(context).colorScheme.error,
                  invertYAxis: true, // smaller is better
                ),
                const SizedBox(height: 16),
                _LatestRecords(runs: runs),
              ],
            );
          },
          loading: () => const _LoadingSkeleton(),
          error: (e, _) => _ErrorCard(message: e.toString()),
        ),
      ],
    );
  }

  List<_PeriodBucket> _buildBuckets(_PeriodType type, {int count = 12}) {
    final now = DateTime.now();
    switch (type) {
      case _PeriodType.month:
        return List.generate(count, (i) {
          final d = DateTime(now.year, now.month - i, 1);
          final start = DateTime(d.year, d.month, 1);
          final end = DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1));
          return _PeriodBucket(
            label: _monthLabel(d.month),
            start: start,
            end: end,
          );
        });
      case _PeriodType.week:
        return List.generate(count, (i) {
          final monday = _startOfWeek(now.subtract(Duration(days: 7 * i)));
          final end = monday.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          final label = '${monday.day}/${monday.month}';
          return _PeriodBucket(label: label, start: monday, end: end);
        });
    }
  }

  _TrendsModel _aggregate(List<RunModel> runs, _PeriodType type) {
    final buckets = _buildBuckets(type);

    double toHours(Duration? d) => (d?.inSeconds ?? 0) / 3600.0;

    final totalDistance = List<double>.filled(buckets.length, 0);
    final totalTime = List<double>.filled(buckets.length, 0);
    final longest = List<double>.filled(buckets.length, 0);
    final avgPace = List<double>.filled(buckets.length, 0);
    final paceCount = List<int>.filled(buckets.length, 0);

    for (final run in runs) {
      final when = run.completedAt ?? run.createdAt;
      final idx = buckets.indexWhere((b) => !when.isBefore(b.start) && !when.isAfter(b.end));
      if (idx == -1) continue;

      final dist = run.totalDistance ?? 0.0;
      final timeH = toHours(run.totalTime);
      totalDistance[idx] += dist;
      totalTime[idx] += timeH;
      longest[idx] = math.max(longest[idx], dist);

      final pace = run.averagePace ?? 0; // minutes per km
      // Only include reasonable paces in the Avg Pace chart
      if (pace > 0 && pace <= _maxPaceMinPerKm) {
        avgPace[idx] += pace;
        paceCount[idx] += 1;
      }
    }

    for (int i = 0; i < avgPace.length; i++) {
      if (paceCount[i] > 0) {
        avgPace[i] = avgPace[i] / paceCount[i];
      }
    }

    return _TrendsModel(
      labels: buckets.map((b) => b.label).toList(),
      totalDistanceKm: totalDistance,
      totalTimeHours: totalTime,
      longestDistanceKm: longest,
      avgPaceMinPerKm: avgPace,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.period, required this.onPeriodChanged});
  final _PeriodType period;
  final ValueChanged<_PeriodType> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Fitness Reports',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _segButton(context, 'WEEK', period == _PeriodType.week, () => onPeriodChanged(_PeriodType.week)),
              _segButton(context, 'MONTH', period == _PeriodType.month, () => onPeriodChanged(_PeriodType.month)),
            ],
          ),
        )
      ],
    );
  }

  Widget _segButton(BuildContext context, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PeriodScroller extends StatelessWidget {
  const _PeriodScroller({
    required this.period,
    required this.selectedIndex,
    required this.onSelected,
  });
  final _PeriodType period;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets(period);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: buckets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selectedIndex;
          return InkWell(
            onTap: () => onSelected(i),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Theme.of(context).colorScheme.primary : (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
              ),
              child: Center(
                child: Text(
                  buckets[i].label,
                  style: TextStyle(
                    color: active ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_PeriodBucket> _buildBuckets(_PeriodType type) {
    final now = DateTime.now();
    const count = 12;
    switch (type) {
      case _PeriodType.month:
        return List.generate(count, (i) {
          final d = DateTime(now.year, now.month - i, 1);
          return _PeriodBucket(
            label: _monthLabel(d.month),
            start: DateTime(d.year, d.month, 1),
            end: DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1)),
          );
        });
      case _PeriodType.week:
        return List.generate(count, (i) {
          final monday = _startOfWeek(now.subtract(Duration(days: 7 * i)));
          return _PeriodBucket(
            label: '${monday.day}/${monday.month}',
            start: monday,
            end: monday.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1)),
          );
        });
    }
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.values,
    required this.color,
    this.invertYAxis = false,
  });

  final String title;
  final List<double> values; // oldest -> newest
  final Color color;
  final bool invertYAxis;

  @override
  Widget build(BuildContext context) {
    final maxY = (values.isEmpty ? 0.0 : values.reduce(math.max));
    final minY = (values.isEmpty ? 0.0 : values.reduce(math.min));
    final yHi = ((invertYAxis ? minY : maxY) * 1.2) + ((maxY == 0) ? 1.0 : 0.0);
    final yLo = invertYAxis ? ((minY == 0) ? -0.1 : 0.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Builder(
                builder: (context) {
                  final spots = List<FlSpot>.generate(
                    values.length,
                    (i) => FlSpot(i.toDouble(), values[i]),
                  );
                  return LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (values.length - 1).toDouble(),
                      minY: invertYAxis ? -yHi : yLo,
                      maxY: invertYAxis ? yLo : yHi,
                      // Ensure lines and shaded areas don't paint outside the chart
                      clipData: FlClipData.all(),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestRecords extends StatelessWidget {
  const _LatestRecords({required this.runs});
  final List<RunModel> runs;

  @override
  Widget build(BuildContext context) {
    // Show the latest 4 completed runs with simple stats
    final latest = [...runs]
      ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    final sliced = latest.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Records',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (sliced.isEmpty)
            Text(
              'Complete some runs to see records here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            ...sliced.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_run, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _recordTitle(r),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                      Text(
                        _durationFmt(r.totalTime),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _recordTitle(RunModel r) {
    final date = r.completedAt ?? r.createdAt;
    final dist = (r.totalDistance ?? 0).toStringAsFixed(2);
    return '${date.year}.${_two(date.month)}.${_two(date.day)}  •  $dist km';
  }

  String _durationFmt(Duration? d) {
    if (d == null) return '--:--:--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
          height: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
          ),
        );
    return Column(
      children: [box(), const SizedBox(height: 12), box(), const SizedBox(height: 12), box()],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendsModel {
  _TrendsModel({
    required this.labels,
    required this.totalDistanceKm,
    required this.totalTimeHours,
    required this.longestDistanceKm,
    required this.avgPaceMinPerKm,
  });
  final List<String> labels;
  final List<double> totalDistanceKm;
  final List<double> totalTimeHours;
  final List<double> longestDistanceKm;
  final List<double> avgPaceMinPerKm;
}

class _PeriodBucket {
  _PeriodBucket({required this.label, required this.start, required this.end});
  final String label;
  final DateTime start;
  final DateTime end;
}

String _monthLabel(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[(month - 1) % 12];
}

DateTime _startOfWeek(DateTime d) {
  // Monday as start of week
  final dayOffset = (d.weekday + 6) % 7; // Monday=0
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: dayOffset));
}
