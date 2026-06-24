# Google Maps Setup Guide

## Overview
The Campus Register app now includes interactive map features for venue management:
- View venues on a real map with satellite imagery
- Create venue boundaries by tapping on the map
- Edit existing venues using interactive map interface
- Toggle between polygon and radius-based boundaries
- Automatic GPS location capture

## Getting Your Google Maps API Key

### Step 1: Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Enter project name (e.g., "Campus Register")
4. Click "Create"

### Step 2: Enable Maps SDK for Android
1. In the Cloud Console, go to "APIs & Services" → "Library"
2. Search for "Maps SDK for Android"
3. Click on it and press "Enable"

### Step 3: Create API Credentials
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "API Key"
3. Copy the generated API key
4. (Recommended) Click "Restrict Key" to configure restrictions:
   - Application restrictions: Android apps
   - Add your package name: `com.example.campus_register`
   - Add your SHA-1 certificate fingerprint (see below)

### Step 4: Get SHA-1 Certificate Fingerprint

#### Debug Certificate (for testing):
```powershell
cd C:\Users\taten\AndroidStudioProjects\campus_register\android
.\gradlew signingReport
```
Look for the SHA-1 under "debugAndroidTest" or "debug" variant.

#### Release Certificate (for production):
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### Step 5: Add API Key to Your App
1. Open `android/app/src/main/AndroidManifest.xml`
2. Find this line:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```
3. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key

## Using the Map Features

### Creating a Venue with Map
1. Open Admin Settings
2. Click **"Create with Map"** button
3. The map editor will open with:
   - **Polygon Mode** (default): Tap anywhere on the map to add boundary corners
   - **Radius Mode**: Toggle switch, then long-press to set center, adjust radius with slider
4. Use the **GPS button** (bottom-right) to jump to your current location
5. Click the **checkmark** (top-right) when done
6. Enter venue name and description
7. Click "Save"

### Viewing a Venue on Map
1. Open Admin Settings
2. Tap the **three-dot menu** on any venue card
3. Select **"View on Map"**
4. The map shows:
   - Blue marker for center
   - Orange markers for polygon corners (if polygon mode)
   - Blue shaded area for boundary
   - Your current location (blue dot)

### Editing a Venue with Map
1. Open Admin Settings
2. Tap the **three-dot menu** on any venue card
3. Select **"Edit with Map"**
4. Adjust boundaries by:
   - **Polygon**: Tap to add corners, drag markers to adjust, use "Undo" or "Clear" buttons
   - **Radius**: Toggle switch, drag center marker, adjust slider
5. Click checkmark to save

### Map Controls
- **Layers button**: Toggle between Normal, Hybrid, and Satellite views
- **Recenter button**: Return camera to venue center
- **My Location button**: Show your current position
- **Pinch/Zoom**: Use two fingers to zoom in/out
- **Drag**: Pan around the map

## Map Features

### Polygon Mode
- Tap anywhere on the map to add a corner
- Minimum 3 corners required
- Drag any marker to adjust position
- Polygon automatically closes between first and last corners
- Use "Undo" to remove last corner
- Use "Clear" to start over

### Radius Mode
- Long-press to set the center point
- Or drag the center marker
- Use slider to adjust radius (20m - 500m)
- Circle shows the boundary area

### Map Types
- **Normal**: Standard road map
- **Hybrid**: Satellite imagery with labels
- **Satellite**: Pure satellite imagery

## Troubleshooting

### Map Shows Blank Screen
- Verify API key is correct in AndroidManifest.xml
- Ensure "Maps SDK for Android" is enabled in Cloud Console
- Check internet connection
- Wait a few minutes for API key to propagate

### "This page can't load Google Maps correctly"
- API key restrictions may be too strict
- Add your app's package name and SHA-1 fingerprint
- Or temporarily remove restrictions for testing

### Location Not Updating
- Grant location permissions in Android settings
- Enable GPS/Location services on device
- Go outdoors for better GPS signal

### Altitude Not Accurate
- GPS altitude has ±10-30m accuracy indoors
- Use barometric sensors (if available) for better accuracy
- Consider adjusting vertical tolerance in venue settings

## Cost Information

Google Maps Platform has a **free tier**:
- $200 free credit per month
- Mobile Maps: First 100,000 loads per month are free
- Static Maps: First 28,000 loads per month are free

For a small campus attendance app, you should stay well within the free tier.

## Additional Resources

- [Maps SDK for Android Documentation](https://developers.google.com/maps/documentation/android-sdk)
- [Google Cloud Console](https://console.cloud.google.com/)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
