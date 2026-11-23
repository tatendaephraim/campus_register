import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../services/biometric_service.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/models/attendance_record.dart';

class AttendanceState {
  final bool isAtCampus;
  final bool isAlreadyMarked;
  final String? errorMessage;

  AttendanceState({
    this.isAtCampus = false,
    this.isAlreadyMarked = false,
    this.errorMessage,
  });

  AttendanceState copyWith({
    bool? isAtCampus,
    bool? isAlreadyMarked,
    String? errorMessage,
  }) {
    return AttendanceState(
      isAtCampus: isAtCampus ?? this.isAtCampus,
      isAlreadyMarked: isAlreadyMarked ?? this.isAlreadyMarked,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  final LocationService _locationService = LocationService();
  final BiometricService _biometricService = BiometricService();
  final AttendanceRepository _repository = AttendanceRepository();

  // Sample campus coords
  final double _campusLat = -1.927196;
  final double _campusLon = 30.140773;

  @override
  AttendanceState build() {
    refreshLocation();
    return AttendanceState();
  }

  Future<void> refreshLocation() async {
    final location = await _locationService.getCurrentLocation();
    final isAtCampus = _locationService.isWithinRange(location, _campusLat, _campusLon);
    state = state.copyWith(isAtCampus: isAtCampus);
  }

  Future<void> attemptAttendance(String userName, String type) async {
    if (!state.isAtCampus) {
      state = state.copyWith(errorMessage: 'Not on campus');
      return;
    }

    final authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      state = state.copyWith(errorMessage: 'Authentication failed');
      return;
    }

    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      state = state.copyWith(errorMessage: 'Could not get location');
      return;
    }

    final record = AttendanceRecord.create(
      name: userName,
      type: type,
      lat: location.latitude,
      lon: location.longitude,
    );

    final success = await _repository.saveAttendance(record);
    state = state.copyWith(
      isAlreadyMarked: success,
      errorMessage: success ? null : 'Sync failed',
    );
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});