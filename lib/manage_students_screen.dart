import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'course.dart';
import 'student.dart';
import 'student_repository.dart';

class ManageStudentsScreen extends StatefulWidget {
  final Course course;
  const ManageStudentsScreen({super.key, required this.course});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final _studentRepo = StudentRepository();
  late Future<List<Student>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    setState(() {
      _studentsFuture = _studentRepo.getStudentsForCourse(widget.course.id!);
    });
  }

  Future<void> _showAddStudentDialog() async {
    final studentNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final studentName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Student'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: studentNameController,
            decoration: const InputDecoration(labelText: 'Student Name'),
            validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(studentNameController.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (studentName != null && studentName.isNotEmpty) {
      await _studentRepo.addStudent(studentName, widget.course.id!);
      _loadStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students in ${widget.course.name}')),
      body: FutureBuilder<List<Student>>(
        future: _studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No students added yet.'));
          }
          final students = snapshot.data!;
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(student.name),
                  subtitle: Text('Code: ${student.deviceAppId}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: student.deviceAppId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Registration code copied!'),
                      ));
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        tooltip: 'Add Student',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
