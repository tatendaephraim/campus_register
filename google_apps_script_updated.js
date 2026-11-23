// Updated Google Apps Script for Campus Register
// This handles all attendance fields including venue details and precise location

function doPost(e) {
  // Add a lock to prevent concurrent write issues
  var lock = LockService.getScriptLock();
  lock.tryLock(10000); 

  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName("Attendance");
    
    // Create the sheet if it doesn't exist
    if (!sheet) {
      sheet = ss.insertSheet("Attendance");
      // Add header row with all fields
      sheet.appendRow([
        "Timestamp",
        "User Name",
        "Type",
        "Venue",
        "Description",
        "Combined Location",
        "Latitude",
        "Longitude",
        "Altitude",
        "Floor",
        "Verifier"
      ]);
      // Format header row
      var headerRange = sheet.getRange(1, 1, 1, 11);
      headerRange.setFontWeight("bold");
      headerRange.setBackground("#4285f4");
      headerRange.setFontColor("#ffffff");
    }
    
    // Safety check: if e is undefined (manual run), exit gracefully
    if (typeof e === 'undefined' || !e.parameter) {
      return ContentService.createTextOutput("Error: No parameters received.");
    }

    var p = e.parameter;
    
    // Append row with all fields
    sheet.appendRow([
      p.timestamp || new Date().toISOString(),
      p.name || "Unknown",
      p.status || "N/A",
      p.venue || "Unknown Location",
      p.description || "",
      p.coords || "0,0",
      p.latitude || "0",
      p.longitude || "0",
      p.altitude || "0m",
      p.floor || "Floor 0",
      p.verifier || "None"
    ]);

    // Auto-resize columns for better readability
    sheet.autoResizeColumns(1, 11);

    return ContentService.createTextOutput("Success").setMimeType(ContentService.MimeType.TEXT);
    
  } catch (err) {
    Logger.log("Error: " + err.toString());
    return ContentService.createTextOutput("Error: " + err.toString());
  } finally {
    lock.releaseLock();
  }
}

// Test function - run this manually to verify the script works
function testDoPost() {
  var testEvent = {
    parameter: {
      timestamp: new Date().toISOString(),
      name: "Test User",
      status: "CHECK-IN",
      venue: "Main Campus",
      description: "Primary campus location",
      coords: "-1.927196, 30.140773",
      latitude: "-1.927196",
      longitude: "30.140773",
      altitude: "1500.0",
      floor: "Floor 0",
      verifier: "Biometric_Success"
    }
  };
  
  var result = doPost(testEvent);
  Logger.log(result.getContent());
}
