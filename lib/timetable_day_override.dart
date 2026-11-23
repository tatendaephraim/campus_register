/// Represents a per-day scheduling override for an organisation.
///
/// Allows admins to mark specific days as non-working (weekends, sports days,
/// public holidays, etc.) and optionally set custom working hours per day.
///
/// [dayOfWeek] follows Dart's [DateTime.weekday] convention:
///   1 = Monday, 2 = Tuesday, … 7 = Sunday
class TimetableDayOverride {
  final int? id;
  final int organizationId;

  /// 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  final int dayOfWeek;

  /// Whether classes/work can be scheduled on this day.
  final bool isWorkingDay;

  /// Optional custom start time (HH:mm). Null → use org global default.
  final String? customStartTime;

  /// Optional custom end time (HH:mm). Null → use org global default.
  final String? customEndTime;

  /// Optional label, e.g. "Weekend", "Sports Day", "Public Holiday".
  final String? label;

  const TimetableDayOverride({
    this.id,
    required this.organizationId,
    required this.dayOfWeek,
    this.isWorkingDay = true,
    this.customStartTime,
    this.customEndTime,
    this.label,
  });

  /// Human-readable day name from [dayOfWeek].
  String get dayName {
    const names = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayOfWeek >= 1 && dayOfWeek <= 7 ? names[dayOfWeek] : 'Unknown';
  }

  /// Short day abbreviation (Mon, Tue …)
  String get dayShort {
    const shorts = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayOfWeek >= 1 && dayOfWeek <= 7 ? shorts[dayOfWeek] : '?';
  }

  factory TimetableDayOverride.fromMap(Map<String, dynamic> map) {
    return TimetableDayOverride(
      id: map['id'] as int?,
      organizationId: map['organization_id'] as int,
      dayOfWeek: map['day_of_week'] as int,
      isWorkingDay: (map['is_working_day'] as int? ?? 1) == 1,
      customStartTime: map['custom_start_time'] as String?,
      customEndTime: map['custom_end_time'] as String?,
      label: map['label'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'organization_id': organizationId,
      'day_of_week': dayOfWeek,
      'is_working_day': isWorkingDay ? 1 : 0,
      'custom_start_time': customStartTime,
      'custom_end_time': customEndTime,
      'label': label,
    };
  }

  TimetableDayOverride copyWith({
    int? id,
    int? organizationId,
    int? dayOfWeek,
    bool? isWorkingDay,
    String? customStartTime,
    String? customEndTime,
    String? label,
    bool clearCustomStart = false,
    bool clearCustomEnd = false,
    bool clearLabel = false,
  }) {
    return TimetableDayOverride(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
      customStartTime: clearCustomStart ? null : (customStartTime ?? this.customStartTime),
      customEndTime: clearCustomEnd ? null : (customEndTime ?? this.customEndTime),
      label: clearLabel ? null : (label ?? this.label),
    );
  }
}
