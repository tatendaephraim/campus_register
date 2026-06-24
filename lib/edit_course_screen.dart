import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course.dart';
import 'venue.dart';
import 'course_repository.dart';
import 'venue_repository.dart';

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
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Pop with a success flag
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Course')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(labelText: 'Course Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a course name' : null,
              ),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(labelText: 'School Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a school name' : null,
              ),
              const SizedBox(height: 20),
              _buildVenueDropdown(),
              const SizedBox(height: 20),
              _buildDatePicker(
                label: 'Start Date',
                date: _startDate,
                onTap: () => _selectDate(context, isStartDate: true),
              ),
              _buildDatePicker(
                label: 'End Date',
                date: _endDate,
                onTap: () => _selectDate(context, isStartDate: false),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveCourse,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      {required String label, DateTime? date, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle:
          Text(date == null ? 'Not set' : DateFormat.yMMMd().format(date)),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildVenueDropdown() {
    // This is identical to the one in CreateCourseScreen
    return FutureBuilder<List<Venue>>(
      future: _venuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const ListTile(title: Text('Loading venues...'));
        }
        final venues = snapshot.data!;
        return DropdownButtonFormField<int>(
          value: _selectedVenueId,
          decoration: const InputDecoration(labelText: 'Venue'),
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
