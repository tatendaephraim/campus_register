import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course.dart';
import 'teacher.dart';
import 'venue.dart';
import 'course_repository.dart';
import 'venue_repository.dart';
import 'teacher_repository.dart';
import 'organization_repository.dart';
import 'ui/design_tokens.dart';

/// A screen for teachers to create a new course.
class CreateCourseScreen extends StatefulWidget {
  final Teacher teacher;

  const CreateCourseScreen({super.key, required this.teacher});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _courseRepo = CourseRepository();
  final _venueRepo = VenueRepository();
  final _teacherRepo = TeacherRepository();
  final _orgRepo = OrganizationRepository();

  late Future<List<Venue>> _venuesFuture;
  int? _selectedVenueId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoadingOrg = true;

  @override
  void initState() {
    super.initState();
    _venuesFuture = _venueRepo.getAllVenues();
    _loadOrganizationName();
  }

  Future<void> _loadOrganizationName() async {
    setState(() => _isLoadingOrg = true);
    
    final orgId = widget.teacher.organizationId;
    if (orgId == null) {
      if (mounted) setState(() => _isLoadingOrg = false);
      return;
    }

    try {
      // 1. Try to get the organization name from the local database or Supabase via Repository
      final org = await _orgRepo.getOrganizationById(orgId);
      if (org != null && mounted) {
        if (_schoolNameController.text.isEmpty || _schoolNameController.text == 'Your Organization Name') {
          setState(() {
            _schoolNameController.text = org.name;
          });
        }
        setState(() => _isLoadingOrg = false);
        return;
      }

      // 2. Fallback: Try teacher profile
      final orgName = await _teacherRepo.getTeacherOrganizationName(widget.teacher.id!);
      if (orgName != null && mounted) {
        if (_schoolNameController.text.isEmpty || _schoolNameController.text == 'Your Organization Name') {
          setState(() {
            _schoolNameController.text = orgName;
          });
        }
        setState(() => _isLoadingOrg = false);
        return;
      }
      
      if (mounted) setState(() => _isLoadingOrg = false);
    } catch (e) {
      debugPrint('DEBUG: Error loading org name: $e');
      if (mounted) setState(() => _isLoadingOrg = false);
    }
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
      setState(() => _isLoadingOrg = true); // Use this to show a loading state on the button
      
      try {
        // Ensure we have the most up-to-date teacher ID from the server
        final teacherRepo = TeacherRepository();
        final refreshedTeacher = await teacherRepo.getTeacherByEmail(widget.teacher.email);
        final teacherId = refreshedTeacher.id ?? widget.teacher.id;

        if (teacherId == null) throw 'Could not resolve teacher identity. Please sign out and back in.';

        final newCourse = Course(
          teacherId: teacherId,
          name: _courseNameController.text.trim(),
          schoolName: _schoolNameController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          venueId: _selectedVenueId,
        );

        final savedCourse = await _courseRepo.createCourse(newCourse);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${savedCourse.name}" created successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingOrg = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Course'),
      ),
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
                          validator: (value) => value!.isEmpty
                              ? 'Please enter a course name'
                              : null,
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextFormField(
                          controller: _schoolNameController,
                          enabled: false, // Locked for better UX; managed by Admin
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'School name',
                            hintText: _isLoadingOrg ? 'Syncing...' : 'School name',
                            prefixIcon: const Icon(Icons.account_balance_rounded),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: AppRadius.mdR,
                              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                            suffixIcon: _isLoadingOrg
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                          ),
                          validator: (value) => value!.isEmpty
                              ? 'School name not found. Contact Admin.'
                              : null,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg, vertical: AppSpace.sm),
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
                  child: const Text('Save course'),
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
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.xs),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label,
          style: AppType.body(context,
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
              weight: FontWeight.w600)),
      subtitle: Text(
        date == null ? 'Not set' : DateFormat.yMMMd().format(date),
        style: AppType.data(context,
            fontSize: 14.5,
            color: AppColors.textPrimary(isDark),
            weight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildVenueDropdown(BuildContext context) {
    return FutureBuilder<List<Venue>>(
      future: _venuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.location_off_rounded, color: AppColors.slate400),
            title: Text('No venues created',
                style: AppType.body(context,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark))),
            subtitle: Text(
                'Please contact your administrator to set up venues first.',
                style: AppType.body(context,
                    fontSize: 12.5, color: AppColors.textSecondary(isDark))),
          );
        }

        // Ensure venue items are unique to prevent dropdown builder errors.
        final venues = snapshot.data!;
        final uniqueVenueIds = <int>{};
        final uniqueVenues = venues.where((venue) {
          return venue.id != null && uniqueVenueIds.add(venue.id!);
        }).toList();

        return DropdownButtonFormField<int>(
          initialValue: _selectedVenueId,
          decoration: const InputDecoration(
            labelText: 'Venue',
            prefixIcon: Icon(Icons.spatial_tracking_rounded),
            border: InputBorder.none,
          ),
          items: uniqueVenues.map((venue) {
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
