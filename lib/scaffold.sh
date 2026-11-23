#!/bin/bash

# Create Directory Structure
mkdir -p data/local
mkdir -p data/remote
mkdir -p data/models
mkdir -p data/repositories
mkdir -p providers
mkdir -p services
mkdir -p ui/dashboard
mkdir -p ui/theme
mkdir -p utils

# Create Data Layer Files
touch data/local/attendance_local_data_source.dart
touch data/remote/google_sheets_api.dart
touch data/models/attendance_record.dart
touch data/repositories/attendance_repository.dart

# Create Provider/ViewModel Files
touch providers/attendance_provider.dart

# Create Service Files
touch services/biometric_service.dart
touch services/location_service.dart

# Create UI Files
touch ui/dashboard/attendance_dashboard.dart
touch ui/theme/app_theme.dart

# Create Utils and Main
touch utils/utils.dart
touch main.dart

echo "✅ Professional project structure created successfully in lib/"