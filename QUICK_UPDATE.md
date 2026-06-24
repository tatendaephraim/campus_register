# Quick Update: Google Sheets Integration

## 🎯 What Changed
Your Flutter app now sends **11 fields** instead of 7, including:
- Venue name and description
- Separate latitude/longitude (6 decimal precision)
- Formatted altitude (with "m" unit)
- Formatted floor (with "Floor" prefix)

## ⚡ Quick Update Steps

### 1. Copy the Updated Script
The new script is in: **`google_apps_script_updated.js`**

### 2. Update Your Google Apps Script
1. Open your Google Sheet
2. **Extensions** → **Apps Script**
3. **Select all** existing code → **Delete**
4. **Copy** entire contents from `google_apps_script_updated.js`
5. **Paste** into editor
6. Click **💾 Save**

### 3. Deploy New Version
1. Click **Deploy** → **Manage deployments**
2. Click **✏️ Edit**
3. Under "Version": **New version**
4. Description: `Added venue and location details`
5. Click **Deploy**
6. ✅ Done!

### 4. Test It
1. In script editor, select **`testDoPost`** from dropdown
2. Click **▶️ Run**
3. Check your sheet - should see test row with 11 columns
4. Header row should be **bold blue** with white text

## 📊 New Google Sheets Format

```
Timestamp | User Name | Type | Venue | Description | Combined Location | Latitude | Longitude | Altitude | Floor | Verifier
```

Example data:
```
2026-02-07T14:30:45.123Z | Tatenda | CHECK-IN | Main Campus | Primary campus location | -1.927196, 30.140773 | -1.927196 | 30.140773 | 1500.0m | Floor 0 | Biometric_Success
```

## ✅ What's Included

### Flutter App Changes (Already Done ✓)
- ✅ Sends venue name
- ✅ Sends venue description  
- ✅ Sends separate lat/lon with 6 decimal places
- ✅ Sends altitude with "m" unit (e.g., "1500.0m")
- ✅ Sends floor with prefix (e.g., "Floor 0")

### Google Script Changes (You Need to Update)
- 📝 Receives all 11 fields
- 📝 Auto-creates sheet with headers
- 📝 Formats header row (bold, blue background)
- 📝 Auto-resizes columns
- 📝 Includes test function

## 🔍 Verify It Works

After updating the script:

1. **Run test function**:
   - Select `testDoPost` → Click Run
   - Check sheet for test row

2. **Test with Flutter app**:
   - Open app → Mark attendance
   - Check Google Sheets
   - Verify all 11 columns populated

3. **Check formatting**:
   - Header row is bold and blue
   - Altitude shows "m" unit
   - Floor shows "Floor" prefix
   - Coordinates have 6 decimals

## 🆘 Troubleshooting

**Script shows "Error: No parameters received"**
→ Use `testDoPost()` function, not `doPost()` for testing

**Columns are blank**
→ Delete "Attendance" sheet, let script recreate it

**App sync fails**
→ Check script permissions: Run `testDoPost()` → Review permissions → Allow

**Old data has only 7 columns**
→ Rename old sheet to "Attendance_Old", let script create new one

## 📁 Files Reference

- **Updated Script**: `google_apps_script_updated.js`
- **Full Guide**: `GOOGLE_SHEETS_UPDATE_GUIDE.md`
- **Flutter API**: `lib/data/remote/google_sheets_api.dart`
- **Data Model**: `lib/data/models/attendance_record.dart`

## 🎉 That's It!

Once you update the Google Apps Script and deploy, your attendance system will log complete details including venue information, precise GPS coordinates, altitude, and floor level for every check-in and check-out.
