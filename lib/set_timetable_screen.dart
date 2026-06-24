import 'package:flutter/material.dart';

import 'course.dart';
import 'timetable.dart';
import 'timetable_repository.dart';
import 'live_attendance_screen.dart';

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
              title: const Text('Add New Class Time'),
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
                    decoration: const InputDecoration(labelText: 'Day of Week'),
                  ),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(startTime?.format(context) ?? 'Not set'),
                    onTap: () async {
                      final time = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (time != null) setDialogState(() => startTime = time);
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(endTime?.format(context) ?? 'Not set'),
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
                      ? () {
                          final slot = TimetableSlot(
                            courseId: widget.course.id!,
                            dayOfWeek: dayOfWeek!,
                            startTime:
                                '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                            endTime:
                                '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                          );
                          Navigator.of(context).pop(slot);
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
    return Scaffold(
      appBar: AppBar(title: Text('Timetable for ${widget.course.name}')),
      body: FutureBuilder<List<TimetableSlot>>(
        future: _slotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No class times set yet.'));
          }
          final slots = snapshot.data!;
          return ListView.builder(
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

              return ListTile(
                title: Text('$day: ${slot.startTime} - ${slot.endTime}'),
                subtitle:
                    isToday ? const Text('Tap to view live attendance') : null,
                tileColor: isToday ? Colors.blue.withOpacity(0.1) : null,
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await _timetableRepo.deleteTimetableSlot(slot.id!);
                    _loadSlots();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSlot,
        child: const Icon(Icons.add),
      ),
    );
  }
}
