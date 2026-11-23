import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course.dart';
import 'venue.dart';
import 'course_repository.dart';
import 'venue_repository.dart';
import 'timetable_repository.dart';
import 'ui/design_tokens.dart';

class EditCourseScreen extends StatefulWidget {
  final Course course;

  const EditCourseScreen({super.key, required this.course});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _courseNameController;
  late TextEditingController _schoolNameController;
  final _courseRepo = CourseRepository();
  final _venueRepo = VenueRepository();

  late Future<List<Venue>> _venuesFuture;
  int? _selectedVenueId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Pre-populate the form with existing course data
    _courseNameController = TextEditingController(text: widget.course.name);
    _schoolNameController =
        TextEditingController(text: widget.course.schoolName);
    _startDate = widget.course.startDate;
    _endDate = widget.course.endDate;
    _selectedVenueId = widget.course.venueId;

    _venuesFuture = _venueRepo.getAllVenues();
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? now : (_startDate ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }
  Future<void> _saveCourse() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVenueId != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final timetableRepo = TimetableRepository();
        final slots = await timetableRepo.getTimetableForCourse(widget.course.id!);
        
        bool hasClash = false;
        for (var slot in slots) {
          final clashResult = await timetableRepo.checkClash(
            _selectedVenueId!,
            slot.dayOfWeek,
            slot.startTime,
            slot.endTime,
            excludeCourseId: widget.course.id,
          );
          if (clashResult['clash'] == true) {
            hasClash = true;
            if (mounted) {
              Navigator.of(context).pop(); // dismiss loading indicator
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Venue Timetable Clash'),
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
            break;
          }
        }
        
        if (hasClash) {
          return; // Abort saving
        }

        if (mounted) {
          Navigator.of(context).pop(); // dismiss loading indicator
        }
      }

      final updatedCourse = Course(
        id: widget.course.id, // Keep the original ID
        teacherId: widget.course.teacherId,
        name: _courseNameController.text,
        schoolName: _schoolNameController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        venueId: _selectedVenueId,
      );

      await _courseRepo.updateCourse(updatedCourse);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Pop with a success flag
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Course')),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Course details',
                  style: AppType.display(
                    context,
                    fontSize: 14,
                    weight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _courseNameController,
                          decoration: const InputDecoration(
                            labelText: 'Course name',
                            prefixIcon: Icon(Icons.menu_book_rounded),
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter a course name' : null,
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextFormField(
                          controller: _schoolNameController,
                          decoration: const InputDecoration(
                            labelText: 'School name',
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter a school name' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),

                Text(
                  'Classroom & schedule',
                  style: AppType.display(
                    context,
                    fontSize: 14,
                    weight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                    child: _buildVenueDropdown(context),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Card(
                  child: Column(
                    children: [
                      _buildDatePicker(
                        context,
                        label: 'Start date',
                        date: _startDate,
                        icon: Icons.event_rounded,
                        onTap: () => _selectDate(context, isStartDate: true),
                      ),
                      Divider(height: 1, color: AppColors.border(isDark)),
                      _buildDatePicker(
                        context,
                        label: 'End date',
                        date: _endDate,
                        icon: Icons.event_busy_rounded,
                        onTap: () => _selectDate(context, isStartDate: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xxxl + 4),
                ElevatedButton(
                  onPressed: _saveCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    BuildContext context, {
    required String label,
    DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: AppType.body(context, fontSize: 13, color: AppColors.textSecondary(isDark), weight: FontWeight.w600)),
      subtitle: Text(
        date == null ? 'Not set' : DateFormat.yMMMd().format(date),
        style: AppType.data(context, fontSize: 14.5, color: AppColors.textPrimary(isDark), weight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildVenueDropdown(BuildContext context) {
    // This mirrors the styling used in CreateCourseScreen
    return FutureBuilder<List<Venue>>(
      future: _venuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Loading venues…', style: AppType.body(context, weight: FontWeight.w600)),
          );
        }
        final venues = snapshot.data!;
        return DropdownButtonFormField<int>(
          initialValue: _selectedVenueId,
          decoration: const InputDecoration(
            labelText: 'Venue',
            prefixIcon: Icon(Icons.spatial_tracking_rounded),
            border: InputBorder.none,
          ),
          items: venues.map((venue) {
            return DropdownMenuItem<int>(
              value: venue.id,
              child: Text(venue.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedVenueId = value;
            });
          },
        );
      },
    );
  }
}
