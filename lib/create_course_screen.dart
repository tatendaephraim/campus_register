import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'course.dart';
import 'teacher.dart';
import 'venue.dart';
import 'course_repository.dart';
import 'venue_repository.dart';

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

  late Future<List<Venue>> _venuesFuture;
  int? _selectedVenueId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
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
      final newCourse = Course(
        teacherId: widget.teacher.id!,
        name: _courseNameController.text,
        schoolName: _schoolNameController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        venueId: _selectedVenueId,
      );

      final savedCourse = await _courseRepo.createCourse(newCourse);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course "${savedCourse.name}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Course'),
      ),
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
                child: const Text('Save Course'),
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
    return FutureBuilder<List<Venue>>(
      future: _venuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const ListTile(
            title: Text('No venues created'),
            subtitle: Text('Please create a venue first.'),
          );
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
          // You can make this field optional or required
          // validator: (value) => value == null ? 'Please select a venue' : null,
        );
      },
    );
  }
}
