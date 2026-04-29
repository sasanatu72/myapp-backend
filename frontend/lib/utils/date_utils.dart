import '../models/event.dart';

DateTime dateOnly(DateTime d) {
  return DateTime(d.year, d.month, d.day);
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime visibleEventEndDay(Event event) {
  var endDay = dateOnly(event.endTime);

  final endsAtMidnight = event.endTime.hour == 0 &&
      event.endTime.minute == 0 &&
      event.endTime.second == 0 &&
      event.endTime.millisecond == 0 &&
      event.endTime.microsecond == 0;

  if (endsAtMidnight && event.endTime.isAfter(event.startTime)) {
    endDay = endDay.subtract(const Duration(days: 1));
  }

  final startDay = dateOnly(event.startTime);
  if (endDay.isBefore(startDay)) {
    return startDay;
  }

  return endDay;
}

bool eventOverlapsDateRange(Event event, DateTime rangeStart, DateTime rangeEnd) {
  final eventStart = dateOnly(event.startTime);
  final eventEnd = visibleEventEndDay(event);
  final start = dateOnly(rangeStart);
  final end = dateOnly(rangeEnd);

  return !eventEnd.isBefore(start) && !eventStart.isAfter(end);
}

Map<DateTime, List<Event>> groupEventsByDate(List<Event> events) {
  final Map<DateTime, List<Event>> map = {};

  for (final event in events) {
    final startDay = dateOnly(event.startTime);
    final endDay = visibleEventEndDay(event);

    var day = startDay;
    while (!day.isAfter(endDay)) {
      map.putIfAbsent(day, () => []);
      map[day]!.add(event);
      day = day.add(const Duration(days: 1));
    }
  }

  for (final list in map.values) {
    list.sort((a, b) {
      final startCompare = a.startTime.compareTo(b.startTime);
      if (startCompare != 0) return startCompare;
      return a.id.compareTo(b.id);
    });
  }

  return map;
}

bool isEventStartDay(Event event, DateTime day) {
  return isSameDate(event.startTime, day);
}

bool isEventEndDay(Event event, DateTime day) {
  return isSameDate(visibleEventEndDay(event), day);
}

bool isMultiDayEvent(Event event) {
  return !isSameDate(dateOnly(event.startTime), visibleEventEndDay(event));
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String formatDate(DateTime date) {
  final d = date.toLocal();
  return '${d.year}/${_twoDigits(d.month)}/${_twoDigits(d.day)}';
}

String formatMonthDay(DateTime date) {
  final d = date.toLocal();
  return '${d.month}月${d.day}日';
}

String formatTime(DateTime date) {
  final d = date.toLocal();
  return '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

String formatDateTime(DateTime date) {
  final d = date.toLocal();
  return '${formatDate(d)} ${formatTime(d)}';
}

String formatEventRange(Event event) {
  if (isSameDate(event.startTime, event.endTime)) {
    return '${formatTime(event.startTime)} - ${formatTime(event.endTime)}';
  }

  return '${formatDate(event.startTime)} ${formatTime(event.startTime)} - ${formatDate(event.endTime)} ${formatTime(event.endTime)}';
}
