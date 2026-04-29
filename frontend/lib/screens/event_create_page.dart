import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/event.dart';
import '../services/event_service.dart';
import '../utils/date_utils.dart';
import '../widgets/app_page_container.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({
    super.key,
    this.event,
    this.initialDate,
  });

  final Event? event;
  final DateTime? initialDate;

  bool get isEdit => event != null;

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  late final TextEditingController _titleController;

  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _startTime;
  late DateTime _endTime;

  bool _isSaving = false;

  static const int _minuteInterval = 5;
  static const double _timePickerHeight = 112;
  static const double _pickerItemExtent = 28;

  @override
  void initState() {
    super.initState();

    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');

    if (event != null) {
      _startDate = dateOnly(event.startTime);
      _endDate = dateOnly(event.endTime);
      _startTime = _alignToMinuteInterval(event.startTime);
      _endTime = _alignToMinuteInterval(event.endTime);
    } else {
      final now = DateTime.now();
      final roundedStart = _roundUpToMinuteInterval(now);
      final initialDay = widget.initialDate == null
          ? dateOnly(roundedStart)
          : dateOnly(widget.initialDate!);

      _startDate = initialDay;
      _endDate = initialDay;
      _startTime = DateTime(
        initialDay.year,
        initialDay.month,
        initialDay.day,
        roundedStart.hour,
        roundedStart.minute,
      );
      _endTime = _startTime.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime _roundUpToMinuteInterval(DateTime value) {
    final minute = value.minute;
    final remainder = minute % _minuteInterval;
    final additionalMinutes = remainder == 0 ? 0 : _minuteInterval - remainder;

    final rounded = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    ).add(Duration(minutes: additionalMinutes));

    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }

  DateTime _alignToMinuteInterval(DateTime value) {
    final roundedMinute = (value.minute ~/ _minuteInterval) * _minuteInterval;
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      roundedMinute,
    );
  }

  DateTime _mergeDateAndTime(DateTime date, DateTime time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get _mergedStartTime => _mergeDateAndTime(_startDate, _startTime);
  DateTime get _mergedEndTime => _mergeDateAndTime(_endDate, _endTime);

  bool get _isInvalidTimeRange => !_mergedEndTime.isAfter(_mergedStartTime);

  String get _dateRangeLabel {
    if (isSameDate(_startDate, _endDate)) {
      return formatDate(_startDate);
    }
    return '${formatDate(_startDate)} - ${formatDate(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'イベント編集' : 'イベント作成'),
      ),
      body: AppPageContainer(
        maxWidth: 640,
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                prefixIcon: Icon(Icons.event_note),
              ),
            ),
            const SizedBox(height: 16),

            _DateRangeCard(
              value: _dateRangeLabel,
              onTap: _openDateRangePicker,
            ),

            const SizedBox(height: 16),

            _PickerSection(
              title: '開始時間',
              value: formatTime(_startTime),
              icon: Icons.schedule,
              child: SizedBox(
                height: _timePickerHeight,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _startTime,
                  use24hFormat: true,
                  minuteInterval: _minuteInterval,
                  itemExtent: _pickerItemExtent,
                  changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
                  onDateTimeChanged: (value) {
                    setState(() {
                      _startTime = _alignToMinuteInterval(value);

                      if (_isInvalidTimeRange) {
                        _endDate = _startDate;
                        _endTime = _startTime.add(const Duration(hours: 1));
                      }
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            _PickerSection(
              title: '終了時間',
              value: formatTime(_endTime),
              icon: Icons.schedule_outlined,
              child: SizedBox(
                height: _timePickerHeight,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _endTime,
                  use24hFormat: true,
                  minuteInterval: _minuteInterval,
                  itemExtent: _pickerItemExtent,
                  changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
                  onDateTimeChanged: (value) {
                    setState(() {
                      _endTime = _alignToMinuteInterval(value);
                    });
                  },
                ),
              ),
            ),

            if (_isInvalidTimeRange) ...[
              const SizedBox(height: 12),
              Text(
                '終了日時は開始日時より後にしてください。',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.isEdit ? '更新する' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDateRangePicker() async {
    final pickedRange = await showModalBottomSheet<_DateRange>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        DateTime? tempStart = _startDate;
        DateTime? tempEnd = isSameDate(_startDate, _endDate) ? null : _endDate;
        DateTime focusedDay = _startDate;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final start = tempStart;
            final end = tempEnd ?? tempStart;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            start == null
                                ? '開始日を選択'
                                : end == null || isSameDate(start, end)
                                    ? '開始日: ${formatDate(start)}'
                                    : '${formatDate(start)} - ${formatDate(end)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempStart = null;
                              tempEnd = null;
                            });
                          },
                          child: const Text('リセット'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: focusedDay,
                      rangeStartDay: tempStart,
                      rangeEndDay: tempEnd,
                      rangeSelectionMode: RangeSelectionMode.toggledOn,
                      selectedDayPredicate: (day) =>
                          tempStart != null && isSameDate(tempStart!, day),
                      onPageChanged: (focused) {
                        focusedDay = focused;
                      },
                      onDaySelected: (selected, focused) {
                        setModalState(() {
                          focusedDay = focused;

                          if (tempStart == null || tempEnd != null) {
                            tempStart = dateOnly(selected);
                            tempEnd = null;
                            return;
                          }

                          final selectedDate = dateOnly(selected);
                          final currentStart = tempStart!;

                          if (selectedDate.isBefore(currentStart)) {
                            tempStart = selectedDate;
                            tempEnd = currentStart;
                          } else if (isSameDate(selectedDate, currentStart)) {
                            tempEnd = null;
                          } else {
                            tempEnd = selectedDate;
                          }
                        });
                      },
                      onRangeSelected: (start, end, focused) {
                        setModalState(() {
                          focusedDay = focused;
                          if (start == null) {
                            tempStart = null;
                            tempEnd = null;
                            return;
                          }

                          tempStart = dateOnly(start);
                          tempEnd = end == null ? null : dateOnly(end);
                        });
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: tempStart == null
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  _DateRange(
                                    start: tempStart!,
                                    end: tempEnd ?? tempStart!,
                                  ),
                                );
                              },
                        child: const Text('日付を決定'),
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

    if (pickedRange == null) return;

    setState(() {
      _startDate = pickedRange.start;
      _endDate = pickedRange.end;

      if (_endDate.isBefore(_startDate)) {
        final temp = _startDate;
        _startDate = _endDate;
        _endDate = temp;
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('タイトルを入力してください');
      return;
    }

    if (_isInvalidTimeRange) {
      _showMessage('終了日時は開始日時より後にしてください');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final eventService = context.read<EventService>();

      if (widget.isEdit) {
        await eventService.updateEvent(
          id: widget.event!.id,
          title: _titleController.text.trim(),
          startTime: _mergedStartTime,
          endTime: _mergedEndTime,
        );
      } else {
        await eventService.createEvent(
          title: _titleController.text.trim(),
          startTime: _mergedStartTime,
          endTime: _mergedEndTime,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DateRange {
  const _DateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Icon(Icons.date_range, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '日付',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.title,
    required this.value,
    required this.icon,
    required this.child,
  });

  final String title;
  final String value;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}
