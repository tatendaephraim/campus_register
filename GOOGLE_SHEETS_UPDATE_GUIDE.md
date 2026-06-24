# Google Sheets Integration Update Guide

## Overview
This guide will help you update your Google Apps Script to receive all the new attendance fields including venue details, precise coordinates, altitude, and floor information.

## Changes Summary

### Old Script (7 columns)
```
Timestamp | Name | Status | Coords | Altitude | Floor | Verifier
```

### New Script (11 columns)
```
Timestamp | User Name | Type | Venue | Description | Combined Location | Latitude | Longitude | Altitude | Floor | Verifier
```

## Step-by-Step Update Instructions

### 1. Open Your Google Apps Script
1. Go to your Google Sheets document
2. Click **Extensions** → **Apps Script**
3. You should see your current `doPost` function

### 2. Replace the Entire Script
1. Select ALL existing code in the script editor
2. Delete it
3. Copy the entire contents of `google_apps_script_updated.js`
4. Paste into the script editor

### 3. Save and Deploy
1. Click **💾 Save** (or Ctrl+S)
2. Click **Deploy** → **Manage deployments**
3. Click **✏️ Edit** on your existing deployment
4. Under "Version", select **New version**
5. Add description: "Added venue details and precise location fields"
6. Click **Deploy**
7. **Important**: Copy the new Web App URL if it changed

### 4. Test the Script
1. In the script editor, select **testDoPost** from the function dropdown
2. Click **▶️ Run**
3. Check your Google Sheet - you should see a test row with all 11 fields
4. If successful, the header row will be bold, blue background with white text

### 5. Update Flutter App URL (if needed)
If your Web App URL changed:
1. Open `lib/data/remote/google_sheets_api.dart`
2. Update the `_url` variable with the new URL
3. Run `flutter pub get`

## Field Mapping

### Flutter App → Google Sheets

| Flutter Field | Google Sheets Column | Example Value |
|--------------|---------------------|---------------|
| `timestamp` | Timestamp | 2026-02-07T14:30:45.123Z |
| `name` | User Name | Tatenda |
| `status` (type) | Type | CHECK-IN |
| `venue` | Venue | Main Campus |
| `description` | Description | Primary campus location |
| `coords` | Combined Location | -1.927196, 30.140773 |
| `latitude` | Latitude | -1.927196 |
| `longitude` | Longitude | 30.140773 |
| `altitude` | Altitude | 1500.0 |
| `floor` | Floor | Floor 0 |
| `verifier` | Verifier | Biometric_Success |

## New Features in Updated Script

### ✨ Auto-Create Sheet
- Automatically creates "Attendance" sheet if it doesn't exist
- Adds formatted header row with all column names
- Bold, blue background, white text for headers

### 📊 Better Data Organization
- **Venue** column shows which class/location
- **Description** provides additional context
- Separate **Latitude** and **Longitude** columns for precise mapping
- **Altitude** and **Floor** for 3D location tracking

### 🔒 Improved Error Handling
- Better logging with `Logger.log()`
- Graceful handling of missing parameters
- Lock mechanism prevents concurrent write conflicts

### 🎨 Auto-Formatting
- Columns automatically resize for readability
- Header row styled for visibility
- Timestamp in ISO 8601 format (sortable)

### 🧪 Test Function
- Includes `testDoPost()` function for manual testing
- Runs without needing Flutter app
- Verifies all fields are received correctly

## What Data Will Be Logged

After the update, each attendance record in Google Sheets will show:

```
2026-02-07T14:30:45.123Z | Tatenda | CHECK-IN | Main Campus | Primary campus location | -1.927196, 30.140773 | -1.927196 | 30.140773 | 1500.0 | Floor 0 | Biometric_Success
```

## Troubleshooting

### Issue: "Error: No parameters received"
**Cause**: Script running manually without test data  
**Fix**: Use the `testDoPost()` function instead of clicking Run on `doPost`

### Issue: Columns not appearing
**Cause**: Using old sheet without headers  
**Fix**: Delete the "Attendance" sheet and let the script recreate it with headers

### Issue: Some fields show as blank
**Cause**: Flutter app not sending all fields  
**Fix**: Verify `google_sheets_api.dart` includes all fields in the `body` parameter

### Issue: "Script has already been published"
**Cause**: Need to create new version  
**Fix**: In Deploy settings, select "New version" before deploying

### Issue: App still fails to sync
**Cause**: Need to authorize new script version  
**Fix**: 
1. Run `testDoPost()` manually
2. Click "Review permissions"
3. Select your Google account
4. Click "Advanced" → "Go to [Your Project]"
5. Click "Allow"

## Data Privacy & Permissions

The updated script requires these permissions:
- ✅ **View and manage spreadsheets** - To write attendance data
- ✅ **Connect to external service** - To receive data from Flutter app

**Note**: The script ONLY writes to your Google Sheets. It does not:
- ❌ Read your emails
- ❌ Access other Google services
- ❌ Share data with third parties
- ❌ Store data elsewhere

## Verification Checklist

After updating, verify:
- [ ] Script saved successfully
- [ ] New deployment created
- [ ] `testDoPost()` runs without errors
- [ ] Test row appears in sheet with all 11 columns
- [ ] Header row is formatted (bold, blue)
- [ ] Flutter app syncs successfully
- [ ] All fields appear in Google Sheets
- [ ] Timestamps are correctly formatted
- [ ] Venue names display properly
- [ ] Coordinates show 6 decimal places

## Advanced: Custom Formatting

### Add Conditional Formatting for Type
1. Select the **Type** column (Column C)
2. Click **Format** → **Conditional formatting**
3. Format rules:
   - **If text contains "CHECK-IN"** → Green background
   - **If text contains "CHECK-OUT"** → Red background

### Add Data Validation
1. Select the **Type** column
2. Click **Data** → **Data validation**
3. Criteria: "List of items"
4. Items: `CHECK-IN, CHECK-OUT`

### Add Formulas
You can add additional columns with formulas:

**Distance from Center** (Column L):
```
=IF(G2<>"", ACOS(COS(RADIANS(90-(-1.927196))) * COS(RADIANS(90-G2)) + SIN(RADIANS(90-(-1.927196))) * SIN(RADIANS(90-G2)) * COS(RADIANS(30.140773-H2))) * 6371000, "")
```

**Day of Week** (Column M):
```
=TEXT(A2,"dddd")
```

**Time Only** (Column N):
```
=TEXT(A2,"HH:mm:ss")
```

## Support & Resources

- **Script File**: `google_apps_script_updated.js`
- **Flutter API File**: `lib/data/remote/google_sheets_api.dart`
- **Google Apps Script Docs**: https://developers.google.com/apps-script
- **Web Apps Guide**: https://developers.google.com/apps-script/guides/web

## Migration from Old Script

If you have existing data with only 7 columns:

### Option 1: Keep Old Data
1. Rename current sheet to "Attendance_Old"
2. Run new script to create fresh "Attendance" sheet with 11 columns
3. Both datasets preserved

### Option 2: Merge Data
1. Export old data to CSV
2. Delete old sheet
3. Let new script create sheet with headers
4. Manually import old data, leaving new columns blank

### Option 3: Add Missing Columns
1. Insert 4 new columns after "Type" column
2. Name them: Venue, Description, Latitude, Longitude
3. Run script - new data will populate all columns
4. Old data will have blank cells in new columns

## Next Steps

1. ✅ Update Google Apps Script (copy from `google_apps_script_updated.js`)
2. ✅ Deploy new version
3. ✅ Test with `testDoPost()` function
4. ✅ Run Flutter app and mark attendance
5. ✅ Verify all 11 fields appear in Google Sheets
6. 🎉 Your attendance system is now fully integrated!
