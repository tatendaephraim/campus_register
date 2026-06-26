import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'course.dart';
import 'student.dart';
import 'student_repository.dart';
import 'ui/design_tokens.dart';

class ManageStudentsScreen extends StatefulWidget {
  final Course course;
  const ManageStudentsScreen({super.key, required this.course});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final _studentRepo = StudentRepository();
  late Future<List<Student>> _studentsFuture;
  List<String> _schoolRosterNames = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadSchoolRoster();
  }

  void _loadStudents() {
    setState(() {
      _studentsFuture = _studentRepo.getStudentsForCourse(widget.course.id!);
    });
  }

  Future<void> _loadSchoolRoster() async {
    try {
      final allStudents = await _studentRepo.getAllStudents();
      final names = allStudents.map((s) => s.name.trim()).toSet().toList();

      final seedNames = [
        'Tatenda Ephraim',
        'Alex Carter',
        'Jane Smith',
        'John Doe',
        'Emily Johnson',
        'Michael Brown',
        'Sarah Davis',
        'David Miller',
        'Jessica Wilson',
        'James Taylor',
        'Amanda Thomas',
        'Robert Anderson'
      ];

      for (var seed in seedNames) {
        if (!names.contains(seed)) {
          names.add(seed);
        }
      }

      names.sort();
      setState(() {
        _schoolRosterNames = names;
      });
    } catch (_) {}
  }

  Future<void> _showCreateNewRosterStudentDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Register new student in school', style: AppType.display(context, fontSize: 16.5, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the student\'s name below to register them in the global school roster database.',
                style: AppType.body(context, color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: AppSpace.lg),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student full name',
                  prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  if (_schoolRosterNames.contains(value.trim())) {
                    return 'Student already exists in roster';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _schoolRosterNames.add(newName);
        _schoolRosterNames.sort();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$newName" added to school roster. You can now select them.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddStudentDialog() async {
    String selectedName = '';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add student from roster', style: AppType.display(context, fontSize: 16.5, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _schoolRosterNames;
                    }
                    return _schoolRosterNames.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    selectedName = selection;
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    if (selectedName.isNotEmpty && textEditingController.text.isEmpty) {
                      textEditingController.text = selectedName;
                    }
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Select student name',
                        hintText: 'Type to search registered students…',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                      onChanged: (val) {
                        selectedName = val;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select a student';
                        }
                        if (!_schoolRosterNames.contains(value.trim())) {
                          return 'Student not registered in school roster';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop('CREATE_NEW_PROFILE');
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text('Not on list? Register new student', style: AppType.body(context, weight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(selectedName.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == 'CREATE_NEW_PROFILE') {
      await _showCreateNewRosterStudentDialog();
      await _showAddStudentDialog(); // Re-open roster selection
    } else if (result != null && result.isNotEmpty) {
      await _studentRepo.addStudent(result, widget.course.id!);
      _loadStudents();
    }
  }

  Future<void> _showEditStudentDialog(Student student) async {
    final nameController = TextEditingController(text: student.name);
    final formKey = GlobalKey<FormState>();

    final updatedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit student details', style: AppType.display(context, fontSize: 16.5, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedName != null && updatedName.isNotEmpty && updatedName != student.name) {
      try {
        final updatedStudent = Student(
          id: student.id,
          courseId: student.courseId,
          name: updatedName,
          deviceAppId: student.deviceAppId,
        );
        await _studentRepo.updateStudent(updatedStudent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated student name to "$updatedName".'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadStudents();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating student: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove student', style: AppType.display(context, fontSize: 17, weight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlR),
        content: Text(
          'Are you sure you want to remove ${student.name} from this course?\n\n'
          'This will also permanently delete all attendance records associated with this student in this course.',
          style: AppType.body(context, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && student.id != null) {
      try {
        await _studentRepo.deleteStudent(student.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${student.name} and their attendance history.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadStudents();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing student: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Students in ${widget.course.name}')),
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
        child: FutureBuilder<List<Student>>(
        future: _studentsFuture,
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
                    Lottie.asset(
                      'assets/lottie/form_reg.json',
                      height: 180,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      'No students added yet',
                      style: AppType.display(context, fontSize: 16, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Tap the button below to add a student to this course.',
                      textAlign: TextAlign.center,
                      style: AppType.body(context, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            );
          }
          final students = snapshot.data!;
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.lgR,
                  side: BorderSide(color: AppColors.border(isDark), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                      child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      student.name,
                      style: AppType.display(context, fontSize: 15.5, weight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Code: ${student.deviceAppId}',
                        style: AppType.data(context, color: AppColors.textSecondary(isDark), weight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: student.deviceAppId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Registration code copied!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.sky),
                          tooltip: 'Edit name',
                          onPressed: () => _showEditStudentDialog(student),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.dangerDark),
                          tooltip: 'Remove student',
                          onPressed: () => _confirmDeleteStudent(student),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        tooltip: 'Add student',
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }
}
