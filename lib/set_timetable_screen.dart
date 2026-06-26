import 'package:flutter/material.dart';

import 'course.dart';
import 'timetable.dart';
import 'timetable_repository.dart';
import 'live_attendance_screen.dart';
import 'ui/design_tokens.dart';

class SetTimetableScreen extends StatefulWidget {
  final Course course;

  const SetTimetableScreen({super.key, required this.course});

  @override
  State<SetTimetableScreen> createState() => _SetTimetableScreenState();
}

class _SetTimetableScreenState extends State<SetTimetableScreen> {
  final _timetableRepo = TimetableRepository();
  late Future<List<TimetableSlot>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  void _loadSlots() {
    setState(() {
      _slotsFuture = _timetableRepo.getTimetableForCourse(widget.course.id!);
    });
  }

  Future<void> _addSlot() async {
    final newSlot = await _showAddSlotDialog();
    if (newSlot != null) {
      await _timetableRepo.addTimetableSlot(newSlot);
      _loadSlots();
    }
  }

  Future<TimetableSlot?> _showAddSlotDialog() async {
    int? dayOfWeek = 1;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    return showDialog<TimetableSlot>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add new class time', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Monday')),
                      DropdownMenuItem(value: 2, child: Text('Tuesday')),
                      DropdownMenuItem(value: 3, child: Text('Wednesday')),
                      DropdownMenuItem(value: 4, child: Text('Thursday')),
                      DropdownMenuItem(value: 5, child: Text('Friday')),
                      DropdownMenuItem(value: 6, child: Text('Saturday')),
                      DropdownMenuItem(value: 7, child: Text('Sunday')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => dayOfWeek = value),
                    decoration: const InputDecoration(
                      labelText: 'Day of week',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text('Start time', style: AppType.body(context, fontSize: 13, weight: FontWeight.w600)),
                    subtitle: Text(
                      startTime?.format(context) ?? 'Not set',
                      style: AppType.data(context, fontSize: 14),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (time != null) setDialogState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: Text('End time', style: AppType.body(context, fontSize: 13, weight: FontWeight.w600)),
                    subtitle: Text(
                      endTime?.format(context) ?? 'Not set',
                      style: AppType.data(context, fontSize: 14),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (time != null) setDialogState(() => endTime = time);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (dayOfWeek != null &&
                          startTime != null &&
                          endTime != null)
                      ? () async {
                          final startStr = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                          final endStr = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
                          
                          if (widget.course.venueId != null) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );
                            
                            final clashResult = await _timetableRepo.checkClash(
                              widget.course.venueId!,
                              dayOfWeek!,
                              startStr,
                              endStr,
                              excludeCourseId: widget.course.id,
                            );
                            
                            if (context.mounted) {
                              Navigator.of(context).pop(); // dismiss loading
                            }
                            
                            if (clashResult['clash'] == true) {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Timetable Clash Detected'),
                                    content: Text(clashResult['message'] as String),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return; // Keep dialog open
                            }
                          }
                          
                          final slot = TimetableSlot(
                            courseId: widget.course.id!,
                            dayOfWeek: dayOfWeek!,
                            startTime: startStr,
                            endTime: endStr,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(slot);
                          }
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Timetable for ${widget.course.name}')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.slate900, AppColors.slate800]
                : [AppColors.slate50, const Color(0xFFEEF2F6)],
          ),
        ),
        child: FutureBuilder<List<TimetableSlot>>(
          future: _slotsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xxxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 56, color: AppColors.slate400),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        'No class times set yet',
                        style: AppType.display(context, fontSize: 16, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Tap the button below to add your first weekly class slot.',
                        textAlign: TextAlign.center,
                        style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
              );
            }
            final slots = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slot = slots[index];
                final day = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday'
                ][slot.dayOfWeek - 1];
                final isToday = slot.dayOfWeek == DateTime.now().weekday;

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgR,
                    side: BorderSide(
                      color: isToday ? theme.colorScheme.primary.withOpacity(0.4) : AppColors.border(isDark),
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  color: isToday ? theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.06) : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpace.sm + 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: AppRadius.smR,
                      ),
                      child: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary, size: 20),
                    ),
                    title: Text(
                      day,
                      style: AppType.display(context, fontSize: 15, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${slot.startTime} – ${slot.endTime}',
                        style: AppType.data(context, fontSize: 13, color: AppColors.textSecondary(isDark), weight: FontWeight.w600),
                      ),
                    ),
                    onTap: isToday
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LiveAttendanceScreen(
                                  course: widget.course,
                                  slot: slot,
                                ),
                              ),
                            );
                          }
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(right: AppSpace.sm),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: AppDeco.statusPill(theme.colorScheme.primary, opacity: 0.12),
                            child: Text(
                              'LIVE TODAY',
                              style: AppType.body(context, fontSize: 9.5, weight: FontWeight.w700, color: theme.colorScheme.primary, letterSpacing: 0.3),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerDark),
                          onPressed: () async {
                            await _timetableRepo.deleteTimetableSlot(slot.id!);
                            _loadSlots();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSlot,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
