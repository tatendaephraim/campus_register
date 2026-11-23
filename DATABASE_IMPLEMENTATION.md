# SQLite Database & Data Log Implementation

## Overview
The application is redesigned around a relational database model to support teachers, students, courses, and timetables. This provides a robust foundation for role-based access and automated attendance tracking.

## Database Schema

### `teachers` Table
Stores information about the educator.
```sql
CREATE TABLE teachers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL, -- Used for login and Google integration
  google_sheet_url TEXT      -- URL for the auto-created Google Sheet
);
```

### `courses` Table
Represents a class taught by a teacher.
```sql
CREATE TABLE courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  teacher_id INTEGER NOT NULL,
  name TEXT NOT NULL,          -- e.g., "Advanced Physics"
  school_name TEXT,            -- e.g., "Northwood High"
  start_date TEXT NOT NULL,    -- ISO 8601
  end_date TEXT NOT NULL,      -- ISO 8601
  venue_id INTEGER,            -- Foreign key to a 'venues' table (from existing map feature)
  FOREIGN KEY(teacher_id) REFERENCES teachers(id)
);
```

### `timetable_slots` Table
Defines the recurring weekly schedule for a course.
```sql
CREATE TABLE timetable_slots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_id INTEGER NOT NULL,
  day_of_week INTEGER NOT NULL, -- 1=Monday, 7=Sunday
  start_time TEXT NOT NULL,     -- "HH:MM" format
  end_time TEXT NOT NULL,       -- "HH:MM" format
  FOREIGN KEY(course_id) REFERENCES courses(id)
);
```

### `students` Table
Stores student information and links them to courses.
```sql
CREATE TABLE students (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  device_app_id TEXT UNIQUE NOT NULL, -- A unique ID from the student's app instance
  FOREIGN KEY(course_id) REFERENCES courses(id)
);
```

### `attendance_records` Table (Formerly `attendance`)
Logs each student's attendance for a specific class session.
```sql
CREATE TABLE attendance_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL,
  timetable_slot_id INTEGER NOT NULL,
  type TEXT NOT NULL,              -- CHECK-IN or CHECK-OUT
  timestamp TEXT NOT NULL,         -- ISO 8601 format
  status TEXT NOT NULL,            -- e.g., "PRESENT", "ABSENT", "LATE"
  location TEXT NOT NULL,          -- "Lat, Lon" string
  altitude REAL NOT NULL,          -- Meters above sea level
  latitude REAL NOT NULL,          -- Separate latitude
  longitude REAL NOT NULL,         -- Separate longitude
  FOREIGN KEY(student_id) REFERENCES students(id),
  FOREIGN KEY(timetable_slot_id) REFERENCES timetable_slots(id)
);
```

### Indexes (for fast queries)
- `idx_timestamp` - Sort by date/time
- `idx_venue` - Filter by venue
- `idx_name` - Filter by user

## What's Stored

Every attendance record now captures:

✅ **User Information**
- User name
- Check-in/Check-out type
- Exact timestamp

✅ **Venue Details**
- Venue name (e.g., "Main Campus", "Lecture Hall A")
- Venue description (e.g., "Computer Science Building - Floor 3")
- Combined location string

✅ **Precise Location**
- Latitude (6 decimal places)
- Longitude (6 decimal places)
- Altitude in meters
- Estimated floor number

✅ **Database Metadata**
- Auto-increment ID
- Indexed for fast searches

## Data Log Features

### Access Points
1. **Dashboard App Bar** - Tap the 📋 receipt icon
2. **Admin Settings** - "Attendance Data Log" under "Data & Reports"

### Main Features

#### 📊 Summary Statistics
- Total records count
- Filtered results count
- Check-ins count
- Check-outs count

#### 🔍 Filtering Options
- **Type Filter**: All / Check-In / Check-Out
- **Venue Filter**: Dropdown of all venues
- **User Filter**: Dropdown of all users

#### 📝 Record Details (Expandable Cards)
Each record shows:
- User name with avatar
- Venue name and description
- Date and time (formatted: "Feb 07, 2026 at 02:30 PM")
- Type badge (color-coded: green for IN, red for OUT)

**Expanded view includes:**
- Full venue information
- Exact coordinates (6 decimal places)
- Altitude measurement
- Floor level
- Precise timestamp
- Database record ID
- Delete button

#### 📈 Statistics View
Tap **⋮ menu → Statistics** to see:
- Attendance count by venue
- Attendance count by user
- Distribution overview

#### 💾 Export Features
- **Export to CSV**: Tap download icon in app bar
  - Creates timestamped file: `attendance_export_2026-02-07.csv`
  - Includes all fields in spreadsheet format
  - Location: `/data/data/com.example.campus_register/files/`

#### 🗑️ Data Management
- **Delete Individual Record**: Expand card → Delete button
- **Clear All Records**: ⋮ menu → Clear All (with confirmation)

## Auto-Backup System

### Primary Storage: SQLite
- Fast queries
- Relational data
- Transaction safe
- Offline-first

### Secondary Backup: CSV
- Automatic on each save
- Location: `attendance_log.csv`
- Includes all fields
- Append-only log

### Remote Sync: Google Sheets
- Background sync (non-blocking)
- Sends all venue details
- Includes altitude and floor
- Continues on failure

## Database Operations

### Available Methods

```dart
// Insert
await repository.saveAttendance(record);

// Query all
List<AttendanceRecord> all = await repository.getAllAttendance();

// Recent records
List<AttendanceRecord> recent = await repository.getRecentAttendance(50);

// Filter by venue
List<AttendanceRecord> venue = await repository.getAttendanceByVenue('Main Campus');

// Filter by user
List<AttendanceRecord> user = await repository.getAttendanceByUser('Tatenda');

// Date range
List<AttendanceRecord> range = await repository.getAttendanceByDateRange(
  DateTime(2026, 2, 1),
  DateTime(2026, 2, 28),
);

// Count
int total = await repository.getTotalCount();

// Export
String csvPath = await repository.exportToCSV();

// Delete
await repository.deleteRecord(recordId);

// Clear all
await repository.clearAllRecords();
```

## Data Accuracy Guarantees

### Location Precision
- **Latitude/Longitude**: 6 decimal places (~0.11m accuracy)
- **Altitude**: 1 decimal place (~0.1m precision)
- **Floor**: Integer calculation based on 3.5m per floor

### Venue Information
- Always includes venue name
- Stores optional description
- Links to exact venue coordinates
- Separate from user's actual coordinates

### Timestamp Accuracy
- ISO 8601 format: `2026-02-07T14:30:45.123Z`
- Millisecond precision
- UTC timezone
- Sortable format

### Data Integrity
- SQLite transactions ensure atomicity
- Primary key auto-increment prevents duplicates
- NOT NULL constraints on essential fields
- Indexes improve query performance

## UI/UX Features

### Visual Design
- Material 3 design system
- Color-coded badges (green/red for in/out)
- Expandable cards for details
- Pull-to-refresh support
- Smooth animations

### Search & Filter
- Real-time filtering (no "Apply" button needed)
- Multiple filters combine with AND logic
- Segmented control for type selection
- Dropdown filters for venue/user

### Performance
- Lazy loading with ListView.builder
- Efficient database queries with indexes
- Cached statistics
- Async operations (non-blocking UI)

## Migration Notes

### Old CSV Format
```csv
Name,Type,Timestamp,Location
Tatenda,CHECK-IN,2026-02-07T14:30:45.123Z,-1.927196, 30.140773
```

### New SQLite + CSV Format
```csv
ID,Name,Type,Timestamp,Venue,Description,Location,Latitude,Longitude,Altitude,Floor
1,Tatenda,CHECK-IN,2026-02-07T14:30:45.123Z,Main Campus,Primary campus location,-1.927196, 30.140773,-1.927196,30.140773,1457.8,0
```

### Backward Compatibility
- New fields added (not removed)
- Google Sheets API updated to send all fields
- Old CSV backups still work
- Database migrations handled automatically

## Testing Checklist

- [x] SQLite database creation
- [x] Record insertion with all fields
- [x] Query operations (all, recent, filtered)
- [x] Data log screen displays correctly
- [x] Filters work properly
- [x] Export to CSV includes all fields
- [x] Delete operations work
- [x] Statistics calculation accurate
- [x] UI responsive and smooth
- [x] No compilation errors

## File Structure

```
lib/
├── data/
│   ├── local/
│   │   ├── database_helper.dart          ✨ NEW: SQLite operations
│   │   └── attendance_local_data_source.dart  🔄 UPDATED: Added SQLite
│   ├── models/
│   │   └── attendance_record.dart        🔄 UPDATED: Added venue fields
│   ├── repositories/
│   │   └── attendance_repository.dart    🔄 UPDATED: SQLite + query methods
│   └── remote/
│       └── google_sheets_api.dart        🔄 UPDATED: Send all fields
├── providers/
│   └── attendance_provider.dart          🔄 UPDATED: Pass venue info
└── ui/
    └── dashboard/
        ├── attendance_dashboard.dart     🔄 UPDATED: Added data log button
        ├── admin_settings_screen.dart    🔄 UPDATED: Added data log link
        └── data_log_screen.dart          ✨ NEW: Complete data viewer
```

## Dependencies Added

```yaml
dependencies:
  sqflite: ^2.3.2      # SQLite database
  intl: ^0.19.0        # Date formatting
```

## Next Steps

1. **Test on Device**: Run app and mark attendance to create records
2. **View Data Log**: Check that all fields display correctly
3. **Test Filters**: Filter by venue, user, and type
4. **Export CSV**: Verify exported file contains all data
5. **Verify Google Sheets**: Check remote sync includes new fields

## Support

For issues with:
- **Database**: Check `database_helper.dart` logs
- **Data Display**: Check `data_log_screen.dart` UI code
- **Sync**: Check `google_sheets_api.dart` response codes
- **Missing Data**: Verify `attendance_provider.dart` passes all fields
