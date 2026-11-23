# Google Sheets Sync Debug Guide

## Changes Made

I've added detailed logging to help us see exactly what's happening during sync. The app will now show:

1. ✅ When data is saved to SQLite
2. ✅ When CSV backup is created
3. ☁️ When Google Sheets sync starts
4. 📤 The exact data being sent
5. 📥 The response from Google Sheets
6. ✅ Success or failure status

## How to Debug

### Step 1: Run the App and Check Logs

1. Run the app: `flutter run`
2. Mark attendance (with biometric authentication)
3. Watch the console output

You should see something like:

```
💾 Saving attendance record...
📊 Saved attendance record to database: ID=1, ...
✅ Saved to SQLite database
📄 Backup to CSV completed
✅ Backed up to CSV
☁️ Syncing to Google Sheets...
📤 Starting Google Sheets sync...
🔗 URL: https://script.google.com/.../exec
📊 Data to send:
  Name: Tatenda
  Type: CHECK-IN
  Venue: Main Campus
  Description: Primary campus location
  Location: -1.927196, 30.140773
  Latitude: -1.927196
  Longitude: 30.140773
  Altitude: 1500.0m
  Floor: Floor 0
📥 Response status: 200 (or 302)
📥 Response body: Success
✅ Sync Successful: Tatenda at Main Campus
✅ Successfully synced to Google Sheets
```

### Step 2: Identify the Problem

#### Problem: "Request timed out"
**Cause**: Network issue or script taking too long  
**Fix**: 
- Check internet connection
- Try again in a few seconds
- Script might be slow - check Apps Script execution log

#### Problem: "Response status: 302"
**Cause**: Redirect (common with Google Apps Script)  
**Fix**: This is actually NORMAL and means success - the script redirects after processing

#### Problem: "Response body: Error: No parameters received"
**Cause**: Google Apps Script not receiving the data  
**Fix**:
1. Check the deployment URL is correct
2. Make sure you deployed as "Web app" not "API executable"
3. Set access to "Anyone" in deployment settings

#### Problem: "Response status: 404"
**Cause**: Wrong URL or deployment deleted  
**Fix**:
1. Go to Apps Script → Deploy → Manage deployments
2. Copy the Web app URL
3. Update `_url` in `google_sheets_api.dart`

#### Problem: "Response status: 401 or 403"
**Cause**: Permission issue  
**Fix**:
1. Apps Script → Deploy → Manage deployments → Edit
2. "Who has access" should be: **Anyone**
3. Redeploy

#### Problem: "Sync Failed (returned false)"
**Cause**: Script received data but returned error  
**Fix**:
1. Check Apps Script execution logs: Apps Script → Executions
2. Look for errors in the log
3. Common issues:
   - Spreadsheet deleted or moved
   - "Attendance" sheet has wrong permissions
   - Script timeout

#### Problem: No logs appear at all
**Cause**: Function not being called  
**Fix**:
1. Check if you're inside campus boundary
2. Check if biometric authentication succeeded
3. Look for earlier error messages

### Step 3: Verify Google Apps Script

1. Go to your Google Sheet
2. Check if new rows are appearing
3. If not, test the script manually:
   - Apps Script editor
   - Select `testDoPost` function
   - Click Run ▶️
   - Check if test row appears in sheet

### Step 4: Check Deployment Settings

Your deployment MUST have these settings:

```
Execute as: Me (your email)
Who has access: Anyone
```

To check:
1. Apps Script → Deploy → Manage deployments
2. Click ✏️ Edit on your deployment
3. Verify settings above
4. If you change anything, click "Deploy"

### Step 5: Common Issues & Quick Fixes

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|----------|
| "Connection Error" | No internet | Check WiFi/data |
| Status 302 | Normal redirect | This is success! |
| Status 404 | Wrong URL | Update URL in code |
| Status 403 | Permission denied | Set access to "Anyone" |
| "No parameters" | Wrong deployment type | Deploy as Web app |
| Sync shows success but no data | Script error | Check Executions log |
| Timeout | Slow script/network | Try again, check internet |

## Test the Sync Manually

If you want to test just the Google Sheets sync without the full app:

1. Open `google_sheets_api.dart`
2. Temporarily add this test function:

```dart
Future<void> testSync() async {
  final testRecord = AttendanceRecord(
    name: 'Test User',
    type: 'CHECK-IN',
    timestamp: DateTime.now(),
    location: '-1.927196, 30.140773',
    altitude: 1500.0,
    estimatedFloor: 0,
    venueName: 'Main Campus',
    venueDescription: 'Test location',
    latitude: -1.927196,
    longitude: 30.140773,
  );
  
  final result = await syncRecord(testRecord);
  print('Test sync result: $result');
}
```

3. Call it from somewhere in your code
4. Check the logs and Google Sheets

## Expected Google Sheets Format

After successful sync, your sheet should have:

| Timestamp | User Name | Type | Venue | Description | Combined Location | Latitude | Longitude | Altitude | Floor | Verifier |
|-----------|-----------|------|-------|-------------|-------------------|----------|-----------|----------|-------|----------|
| 2026-02-07T14:30:45.123Z | Tatenda | CHECK-IN | Main Campus | Primary campus location | -1.927196, 30.140773 | -1.927196 | 30.140773 | 1500.0m | Floor 0 | Biometric_Success |

## Still Not Working?

Send me these details:

1. **Console logs** (copy everything between "💾 Saving attendance record..." and the end)
2. **Apps Script Executions** (Apps Script → Executions tab, screenshot)
3. **Deployment URL** (the one in your code)
4. **Deployment settings** (screenshot of "Who has access")
5. **Google Sheet name** and whether "Attendance" sheet exists

## Quick Verification Checklist

Before asking for help, verify:

- [ ] Biometric authentication succeeded
- [ ] Inside campus boundary (location check passed)
- [ ] Internet connection active
- [ ] Apps Script URL is correct
- [ ] Apps Script deployed with "Anyone" access
- [ ] Google Sheet exists and is accessible
- [ ] "Attendance" sheet exists (or script can create it)
- [ ] Console shows "📤 Starting Google Sheets sync..."
- [ ] Response status is 200 or 302
- [ ] Response body contains "Success"

## Next Steps

Run the app again and **copy the console output**. The detailed logs will tell us exactly what's failing.
