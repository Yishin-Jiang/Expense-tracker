const taipeiUtcOffset = Duration(hours: 8);

DateTime toTaipeiTime(DateTime value) => value.toUtc().add(taipeiUtcOffset);

DateTime toUtcFromTaipei(DateTime value) {
  return DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  ).subtract(taipeiUtcOffset);
}

({DateTime start, DateTime end}) taipeiDayRange(DateTime date) {
  final start = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).subtract(taipeiUtcOffset);
  return (start: start, end: start.add(const Duration(days: 1)));
}

({DateTime start, DateTime end}) taipeiMonthRange(DateTime date) {
  final start = DateTime.utc(date.year, date.month).subtract(taipeiUtcOffset);
  final nextMonth = DateTime.utc(
    date.month == 12 ? date.year + 1 : date.year,
    date.month == 12 ? 1 : date.month + 1,
  ).subtract(taipeiUtcOffset);
  return (start: start, end: nextMonth);
}
