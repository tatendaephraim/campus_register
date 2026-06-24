import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/script/v1.dart' as script;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

/// A service to automate the creation and deployment of a Google Sheet
/// and its corresponding Google Apps Script for attendance logging.
class GoogleSheetsAutomationService {
  /// The content of the Google Apps Script to be deployed.
  /// In a real app, this would be loaded from an asset file.
  final String _scriptContent = r'''
    function doPost(e) {
      var lock = LockService.getScriptLock();
      lock.tryLock(10000);
      try {
        var ss = SpreadsheetApp.getActiveSpreadsheet();
        var sheet = ss.getSheetByName("Attendance");
        if (!sheet) {
          sheet = ss.insertSheet("Attendance");
          sheet.appendRow(["Timestamp", "User Name", "Status", "Venue", "Description", "Coords", "Latitude", "Longitude", "Altitude", "Floor", "Verifier"]);
          var header = sheet.getRange(1, 1, 1, 11);
          header.setFontWeight("bold").setBackground("#4285f4").setFontColor("#ffffff");
        }
        var p = e.parameter;
        sheet.appendRow([p.timestamp, p.name, p.status, p.venue, p.description, p.coords, p.latitude, p.longitude, p.altitude, p.floor, p.verifier]);
        sheet.autoResizeColumns(1, 11);
        return ContentService.createTextOutput("Success");
      } catch (err) {
        return ContentService.createTextOutput("Error: " + err.toString());
      } finally {
        lock.releaseLock();
      }
    }
  ''';

  /// Creates a new Google Sheet, an Apps Script, deploys it, and returns the URL.
  ///
  /// - [googleUser]: The authenticated Google Sign-In user.
  /// - [courseName]: The name of the course, used for the Sheet title.
  Future<String?> createAndDeploy(
      GoogleSignInAccount googleUser, String courseName) async {
    try {
      // 1. Get authenticated HTTP client
      final authHeaders = await googleUser.authHeaders;
      final client = auth.authenticatedClient(
          http.Client(),
          auth.AccessCredentials(
            auth.AccessToken(
              'Bearer',
              authHeaders['Authorization']!.substring(7), // Remove 'Bearer '
              DateTime.now().toUtc().add(const Duration(hours: 1)),
            ),
            null,
            ['https://www.googleapis.com/auth/drive.file'],
          ));

      final driveApi = drive.DriveApi(client);
      final scriptApi = script.ScriptApi(client);

      // 2. Create the Google Sheet
      final sheetFile = drive.File()
        ..name = '$courseName - Attendance Register'
        ..mimeType = 'application/vnd.google-apps.spreadsheet';

      final newSheet = await driveApi.files.create(sheetFile);
      print('✅ Google Sheet created: ${newSheet.id}');

      // 3. Create the Google Apps Script project bound to the sheet
      final createScriptRequest = script.CreateProjectRequest()
        ..title = '$courseName - Attendance Script'
        ..parentId = newSheet.id; // Bind script to the sheet

      final scriptProject =
          await scriptApi.projects.create(createScriptRequest);
      print('✅ Apps Script project created: ${scriptProject.scriptId}');

      // 4. Update the script with our code
      final content = script.Content()
        ..files = [
          script.File()
            ..name = 'Code'
            ..type = 'SERVER_JS'
            ..source = _scriptContent,
        ];
      await scriptApi.projects.updateContent(content, scriptProject.scriptId!);

      // 5. Deploy the script as a web app
      final deploymentConfig = script.DeploymentConfig()
        ..scriptId = scriptProject.scriptId
        ..versionNumber = 1
        ..manifestFileName = 'appsscript.json'; // Default manifest

      final deployment = await scriptApi.projects.deployments
          .create(deploymentConfig, scriptProject.scriptId!);

      print(
          '✅ Script deployed. URL: ${deployment.entryPoints![0].webApp!.url}');
      return deployment.entryPoints![0].webApp!.url;
    } catch (e) {
      print('❌ Automation failed: $e');
      return null;
    }
  }
}
