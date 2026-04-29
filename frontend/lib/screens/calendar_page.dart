import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event.dart';
import '../services/event_service.dart';
import '../utils/date_utils.dart';
import '../widgets/app_page_container.dart';
import '../widgets/error_state.dart';
import '../widgets/settings_action.dart';
import 'event_create_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = dateOnly(DateTime.now());

  List<Event> _events = [];
  Map<DateTime, List<Event>> _eventsByDay = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadEvents);
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final eventService = context.read<EventService>();
      final events = await eventService.getEvents();

      if (!mounted) return;

      setState(() {
        _events = events;
        _eventsByDay = groupEventsByDate(events);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _eventsByDay[dateOnly(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: const [SettingsAction()],
      ),
      body: AppPageContainer(
        maxWidth: 900,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEventCreator,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadEvents,
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final rowHeight = math.min(
      96.0,
      math.max(74.0, (screenHeight - 230.0) / 6.0),
    );

    return _MonthCalendar(
      focusedMonth: _focusedMonth,
      selectedDay: _selectedDay,
      events: _events,
      eventsByDay: _eventsByDay,
      rowHeight: rowHeight,
      onPreviousMonth: () {
        setState(() {
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
        });
      },
      onNextMonth: () {
        setState(() {
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
        });
      },
      onToday: () {
        final today = dateOnly(DateTime.now());
        setState(() {
          _focusedMonth = DateTime(today.year, today.month);
          _selectedDay = today;
        });
      },
      onDayTap: (day) {
        setState(() {
          _selectedDay = dateOnly(day);
          _focusedMonth = DateTime(day.year, day.month);
        });
        _showDayEventsSheet(day);
      },
    );
  }

  Future<void> _openEventCreator({DateTime? initialDate}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreatePage(initialDate: initialDate),
      ),
    );

    if (result == true) {
      await _loadEvents();
    }
  }

  Future<void> _openEventEditor(Event event) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreatePage(event: event),
      ),
    );

    if (result == true) {
      await _loadEvents();
    }
  }

  Future<void> _showDayEventsSheet(DateTime day) async {
    final selected = dateOnly(day);
    final events = _getEventsForDay(selected);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatMonthDay(selected)}の予定',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _openEventCreator(initialDate: selected);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: events.isEmpty
                        ? Center(
                            child: Text(
                              'この日の予定はありません',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return _EventCard(
                                event: event,
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _openEventEditor(event);
                                },
                                onEdit: () async {
                                  Navigator.pop(context);
                                  await _openEventEditor(event);
                                },
                                onDelete: () async {
                                  Navigator.pop(context);
                                  await _deleteEvent(event);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(Event event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('イベントを削除しますか？'),
          content: Text('「${event.title}」を削除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await context.read<EventService>().deleteEvent(event.id);
      await _loadEvents();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.eventsByDay,
    required this.rowHeight,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onDayTap,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<Event> events;
  final Map<DateTime, List<Event>> eventsByDay;
  final double rowHeight;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onDayTap;

  static const double _weekdayHeight = 28;
  static const double _dayNumberHeight = 24;
  static const double _eventBarHeight = 17;
  static const double _eventBarGap = 3;
  static const List<String> _weekdays = ['日', '月', '火', '水', '木', '金', '土'];

  DateTime get _firstVisibleDay {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysFromSunday = firstOfMonth.weekday % 7;
    return firstOfMonth.subtract(Duration(days: daysFromSunday));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstVisibleDay = _firstVisibleDay;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '前の月',
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${focusedMonth.year}年${focusedMonth.month}月',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: onToday,
                    child: const Text('今日'),
                  ),
                  IconButton(
                    tooltip: '次の月',
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _weekdayHeight,
              child: Row(
                children: [
                  for (final weekday in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cellWidth = width / 7;
                final totalHeight = rowHeight * 6;

                return SizedBox(
                  height: totalHeight,
                  child: Stack(
                    children: [
                      _CalendarGridLines(
                        rowHeight: rowHeight,
                        color: colorScheme.outlineVariant.withOpacity(0.9),
                      ),
                      for (var index = 0; index < 42; index++)
                        _DayTapAndNumber(
                          day: firstVisibleDay.add(Duration(days: index)),
                          focusedMonth: focusedMonth,
                          selectedDay: selectedDay,
                          row: index ~/ 7,
                          column: index % 7,
                          cellWidth: cellWidth,
                          rowHeight: rowHeight,
                          onTap: onDayTap,
                        ),
                      for (var weekIndex = 0; weekIndex < 6; weekIndex++)
                        ..._buildWeekEventBars(
                          context: context,
                          weekIndex: weekIndex,
                          weekStart: firstVisibleDay.add(Duration(days: weekIndex * 7)),
                          cellWidth: cellWidth,
                          rowHeight: rowHeight,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeekEventBars({
    required BuildContext context,
    required int weekIndex,
    required DateTime weekStart,
    required double cellWidth,
    required double rowHeight,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final segments = _buildWeekSegments(weekStart, weekEnd);

    return segments.map((segment) {
      final top = weekIndex * rowHeight +
          _dayNumberHeight +
          3 +
          segment.lane * (_eventBarHeight + _eventBarGap);
      final left = segment.startColumn * cellWidth + 4;
      final width = (segment.endColumn - segment.startColumn + 1) * cellWidth - 8;

      return Positioned(
        top: top,
        left: left,
        width: math.max(18, width),
        height: _eventBarHeight,
        child: _CalendarEventBar(
          event: segment.event,
          startsBeforeWeek: segment.startsBeforeWeek,
          endsAfterWeek: segment.endsAfterWeek,
        ),
      );
    }).toList();
  }

  List<_WeekEventSegment> _buildWeekSegments(DateTime weekStart, DateTime weekEnd) {
    final overlapping = events.where((event) {
      return eventOverlapsDateRange(event, weekStart, weekEnd);
    }).toList()
      ..sort((a, b) {
        final aStart = dateOnly(a.startTime);
        final bStart = dateOnly(b.startTime);
        final startCompare = aStart.compareTo(bStart);
        if (startCompare != 0) return startCompare;

        final aLength = visibleEventEndDay(a).difference(aStart).inDays;
        final bLength = visibleEventEndDay(b).difference(bStart).inDays;
        final lengthCompare = bLength.compareTo(aLength);
        if (lengthCompare != 0) return lengthCompare;

        return a.id.compareTo(b.id);
      });

    final lanes = <int>[];
    final segments = <_WeekEventSegment>[];

    for (final event in overlapping) {
      final eventStart = dateOnly(event.startTime);
      final eventEnd = visibleEventEndDay(event);
      final clippedStart = eventStart.isBefore(weekStart) ? weekStart : eventStart;
      final clippedEnd = eventEnd.isAfter(weekEnd) ? weekEnd : eventEnd;
      final startColumn = clippedStart.difference(weekStart).inDays.clamp(0, 6);
      final endColumn = clippedEnd.difference(weekStart).inDays.clamp(0, 6);

      var lane = 0;
      while (lane < lanes.length && startColumn <= lanes[lane]) {
        lane++;
      }
      if (lane == lanes.length) {
        lanes.add(endColumn);
      } else {
        lanes[lane] = endColumn;
      }

      if (lane >= 3) continue;

      segments.add(
        _WeekEventSegment(
          event: event,
          startColumn: startColumn,
          endColumn: endColumn,
          lane: lane,
          startsBeforeWeek: eventStart.isBefore(weekStart),
          endsAfterWeek: eventEnd.isAfter(weekEnd),
        ),
      );
    }

    return segments;
  }
}

class _CalendarGridLines extends StatelessWidget {
  const _CalendarGridLines({
    required this.rowHeight,
    required this.color,
  });

  final double rowHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _CalendarGridPainter(
          rowHeight: rowHeight,
          color: color,
        ),
      ),
    );
  }
}

class _CalendarGridPainter extends CustomPainter {
  const _CalendarGridPainter({
    required this.rowHeight,
    required this.color,
  });

  final double rowHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final cellWidth = size.width / 7;

    for (var col = 1; col < 7; col++) {
      final x = cellWidth * col;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var row = 1; row < 6; row++) {
      final y = rowHeight * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarGridPainter oldDelegate) {
    return oldDelegate.rowHeight != rowHeight || oldDelegate.color != color;
  }
}

class _DayTapAndNumber extends StatelessWidget {
  const _DayTapAndNumber({
    required this.day,
    required this.focusedMonth,
    required this.selectedDay,
    required this.row,
    required this.column,
    required this.cellWidth,
    required this.rowHeight,
    required this.onTap,
  });

  final DateTime day;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final int row;
  final int column;
  final double cellWidth;
  final double rowHeight;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOutsideMonth = day.month != focusedMonth.month;
    final isToday = isSameDate(day, DateTime.now());
    final isSelected = isSameDate(day, selectedDay);

    return Positioned(
      top: row * rowHeight,
      left: column * cellWidth,
      width: cellWidth,
      height: rowHeight,
      child: InkWell(
        onTap: () => onTap(day),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : isToday
                        ? colorScheme.primaryContainer
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : isOutsideMonth
                          ? colorScheme.onSurfaceVariant.withOpacity(0.42)
                          : colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEventBar extends StatelessWidget {
  const _CalendarEventBar({
    required this.event,
    required this.startsBeforeWeek,
    required this.endsAfterWeek,
  });

  final Event event;
  final bool startsBeforeWeek;
  final bool endsAfterWeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = '${startsBeforeWeek ? '← ' : ''}${event.title}${endsAfterWeek ? ' →' : ''}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.horizontal(
          left: startsBeforeWeek ? Radius.zero : const Radius.circular(5),
          right: endsAfterWeek ? Radius.zero : const Radius.circular(5),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 10,
              height: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekEventSegment {
  const _WeekEventSegment({
    required this.event,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    required this.startsBeforeWeek,
    required this.endsAfterWeek,
  });

  final Event event;
  final int startColumn;
  final int endColumn;
  final int lane;
  final bool startsBeforeWeek;
  final bool endsAfterWeek;
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(formatTime(event.startTime).substring(0, 2)),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(formatEventRange(event)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '編集',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
