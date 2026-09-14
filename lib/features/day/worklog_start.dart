/// Якорь `start` для create/update на календарном [day].
///
/// Create: 10:00. Edit: сохраняем время суток из [existingStart].
DateTime worklogStartOnDay(DateTime day, {DateTime? existingStart}) {
  return DateTime(
    day.year,
    day.month,
    day.day,
    existingStart?.hour ?? 10,
    existingStart?.minute ?? 0,
    existingStart?.second ?? 0,
    existingStart?.millisecond ?? 0,
  );
}
