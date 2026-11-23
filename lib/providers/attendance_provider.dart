import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../services/biometric_service.dart';
import '../services/altitude_service.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/models/attendance_record.dart';
import '../data/models/venue.dart';

class AttendanceState {
  final bool isAtCampus;
  final bool isAlreadyMarked;
  final String? errorMessage;
  final String? userName;
  final double currentAltitude;
  final int currentFloor;
  final Venue? currentVenue;
  final List<Venue> availableVenues;
  final double? distanceToVenue;

  AttendanceState({
    this.isAtCampus = false,
    this.isAlreadyMarked = false,
    this.errorMessage,
    this.userName,
    this.currentAltitude = 0.0,
    this.currentFloor = 0,
    this.currentVenue,
    this.availableVenues = const [],
    this.distanceToVenue,
  });

  AttendanceState copyWith({
    bool? isAtCampus,
    bool? isAlreadyMarked,
    String? errorMessage,
    String? userName,
    double? currentAltitude,
    int? currentFloor,
    Venue? currentVenue,
    List<Venue>? availableVenues,
    double? distanceToVenue,
  }) {
    return AttendanceState(
      isAtCampus: isAtCampus ?? this.isAtCampus,
      isAlreadyMarked: isAlreadyMarked ?? this.isAlreadyMarked,
      errorMessage: errorMessage ?? this.errorMessage,
      userName: userName ?? this.userName,
      currentAltitude: currentAltitude ?? this.currentAltitude,
      currentFloor: currentFloor ?? this.currentFloor,
      currentVenue: currentVenue ?? this.currentVenue,
      availableVenues: availableVenues ?? this.availableVenues,
      distanceToVenue: distanceToVenue ?? this.distanceToVenue,
    );
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  final LocationService _locationService = LocationService();
  final BiometricService _biometricService = BiometricService();
  final AttendanceRepository _repository = AttendanceRepository();
  final AltitudeService _altitudeService = AltitudeService.instance;

  // Default venues - can be managed by admin
  final List<Venue> _defaultVenues = [
    Venue(
      id: 'main_campus',
      name: 'Main Campus',
      latitude: -1.927196,
      longitude: 30.140773,
      altitude: 1500.0,
      description: 'Primary campus location',
    ),
    Venue(
      id: 'lecture_hall_a',
      name: 'Lecture Hall A',
      latitude: -1.927196,
      longitude: 30.140773,
      altitude: 1510.5, // 3rd floor
      horizontalRadius: 50.0,
      description: 'Computer Science Building - Floor 3',
    ),
  ];

  @override
  AttendanceState build() {
    // Initialize with default venues and first venue selected
    return AttendanceState(
      availableVenues: _defaultVenues,
      currentVenue: _defaultVenues.first,
    );
  }

  void setUserName(String name) {
    state = state.copyWith(userName: name, errorMessage: null);
  }

  void selectVenue(Venue venue) {
    state = state.copyWith(
      currentVenue: venue,
      errorMessage: null,
      isAlreadyMarked: false,
    );
    refreshLocation();
  }

  void addVenue(Venue venue) {
    final updatedVenues = [...state.availableVenues, venue];
    state = state.copyWith(
      availableVenues: updatedVenues,
      currentVenue: venue,
    );
  }

  void removeVenue(String venueId) {
    final updatedVenues =
        state.availableVenues.where((v) => v.id != venueId).toList();
    state = state.copyWith(
      availableVenues: updatedVenues,
      currentVenue: updatedVenues.isNotEmpty ? updatedVenues.first : null,
    );
  }

  Future<void> refreshLocation() async {
    if (state.currentVenue == null) {
      state = state.copyWith(errorMessage: 'No venue selected');
      return;
    }

    final location = await _locationService.getCurrentLocation();
    final venue = state.currentVenue!;

    // Calculate distance for display (to center point)
    final distance = _locationService.calculateDistance(
      location.latitude,
      location.longitude,
      venue.latitude,
      venue.longitude,
    );

    // Verify 3D Location (with polygon support)
    final isAtCampus = _locationService.isAtVenueWithTolerance(
      location,
      venue.latitude,
      venue.longitude,
      venue.altitude,
      venue.horizontalRadius,
      venue.verticalTolerance,
      polygonCorners: venue.polygonCorners,
    );

    // Calculate current floor
    final floor =
        _altitudeService.calculateFloor(location.altitude, venue.altitude);

    state = state.copyWith(
      isAtCampus: isAtCampus,
      currentAltitude: location.altitude,
      currentFloor: floor,
      distanceToVenue: distance,
      errorMessage: null, // Clear any previous errors when refreshing location
    );
  }

  Future<void> attemptAttendance(String type) async {
    if (state.userName == null) {
      state = state.copyWith(errorMessage: 'Please set a user name first.');
      return;
    }

    if (state.currentVenue == null) {
      state = state.copyWith(errorMessage: 'No venue selected.');
      return;
    }

    await refreshLocation();

    if (!state.isAtCampus) {
      state = state.copyWith(
        errorMessage: 'You are not at ${state.currentVenue!.name}',
      );
      return;
    }

    final authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      final errorMsg =
          _biometricService.lastError ?? 'Biometric verification failed';
      state = state.copyWith(errorMessage: errorMsg);
      return;
    }

    final venue = state.currentVenue!;
    final record = AttendanceRecord(
      name: state.userName!,
      timestamp: DateTime.now(),
      type: type,
      location:
          '${venue.latitude.toStringAsFixed(6)}, ${venue.longitude.toStringAsFixed(6)}',
      altitude: state.currentAltitude,
      estimatedFloor: state.currentFloor,
      venueName: venue.name,
      venueDescription: venue.description,
      latitude: venue.latitude,
      longitude: venue.longitude,
    );

    final success = await _repository.saveAttendance(record);
    state = state.copyWith(
      isAlreadyMarked: success,
      errorMessage: success ? null : 'Data Sync Failed',
    );
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});
