# Campus Register - Biometric & Device Binding Security Model 🔒

This document details the security architecture of the **Campus Register** application, explaining how it enforces biometric integrity, binds a student to a device, and prevents attendance fraud (e.g., logging in with another device or delegating check-ins).

---

## 🛡️ 1. How Biometric & Device Binding Works

To prevent a student from checking in for another classmate (known as "buddy checking"), the application relies on a strict **1-to-1 hardware-to-profile binding** established during student registration.

### Step-by-Step Registration Security Flow

```mermaid
sequenceDiagram
    autonumber
    actor Teacher
    actor Student
    participant App as Mobile App
    participant DB as Supabase Database

    Teacher->>DB: 1. Create Student record (Name: "Alex")
    Note over DB: Generates random 6-digit<br/>Registration Code (e.g., 564738)<br/>saved in device_app_id
    DB-->>Teacher: Returns Registration Code
    Teacher->>Student: 2. Share Registration Code (564738)
    Student->>App: 3. Opens App on personal device & enters code
    App->>App: 4. Queries native hardware API for Device UUID
    Note over App: Android: Android ID<br/>iOS: identifierForVendor
    App->>DB: 5. Consume Code & Send Device UUID
    Note over DB: Updates device_app_id = Device UUID<br/>where device_app_id = 564738
    DB-->>App: Registration successful!
    Note over DB: Registration code is consumed.<br/>Profile is now permanently bound to Device UUID.
```

1.  **Teacher Registration Initialization:** The teacher creates the student profile on the dashboard. The system generates a single-use random 6-digit code (e.g., `564738`) and stores it temporarily in the `device_app_id` field.
2.  **Device UUID Capturing:** When the student registers, the mobile app queries the native operating system hardware API for a unique device hardware identifier:
    *   **Android:** `ANDROID_ID`, which is unique to the phone, the user and the app signing key.
    *   **iOS:** `identifierForVendor`, which is unique to the phone and app vendor.
3.  **One-Time Code Consumption:** The app sends the device ID along with the registration code to Supabase. The database **overwrites** the temporary registration code in the `device_app_id` field with the device's hardware ID.

---

## 🚫 2. Preventing Logins/Check-ins on Other Devices

The application is designed so that a student cannot sign in from another ordinary phone:

### A. Passwordless, Hardware-Locked Authentication
There are no passwords or username fields in the student portal. The student's identity is determined **exclusively** by the device ID of the phone opening the app.
When the app launches, it reads the local hardware ID and checks if that ID matches the `device_app_id` on Supabase:
*   If a student opens the app on a **different device**, the new device will have a different hardware ID.
*   The database query for that device ID returns empty, and the app defaults to the registration/role-selection screen.
*   If the student attempts to enter their registration code again on the new device, the attempt is rejected because the 6-digit code **no longer exists** in the database (having been overwritten during initial registration).

### B. One Student per Phone
Registration is refused when the phone already belongs to a student with a different name. One student may hold several course profiles on the same phone. This is checked by the app. The local schema has no `UNIQUE` constraint on `device_app_id`, because one student may have several rows.

---

## 🔑 3. Biometric Verification Security

When a student checks in:
1.  The app prompts the device's native biometric authentication module (`local_auth`).
2.  The verification is handled by the operating system and its secure hardware. A PIN is not accepted instead.
3.  The operating system verifies that the finger pressed matches one of the fingerprints enrolled on the device.
4.  **Result only:** The app receives success or failure, not a fingerprint, an image or a signed token. A modified app on a rooted phone could ignore the result, which is out of scope.

### ❓ What if a student registers a classmate's fingerprint on their phone?
*   A phone can technically store multiple fingerprints (e.g. Owner's finger + Spouse's finger).
*   However, because the account profile is locked to the physical device ID, the student would have to **give their physical phone** to their classmate to check in.
*   To check in on that phone, the classmate would have to physically walk into the classroom to pass the **3D Volumetric Geofence** (polygon check) and the **Altitude Ceiling** (floor check).
*   Therefore, a classmate would need to carry the absent student's phone into the classroom. This makes the fraud harder and more visible, but not impossible.

---

## 🌐 4. Volumetric Geofencing & GPS Lateral Tolerances

To limit location fraud and allow for sensor error, the application enforces a 3D boundary. Mocked and stale positions are refused.

### A. Vertical (Altitude) Gatekeeper
*   **Purpose:** Refuses check-in from distant floors. Adjacent floors are not reliably separated; see the README.
*   **Allowance Zone:** By default **-8 m to +12 m** around the captured floor. Each venue can be set between 2 m and 20 m. GPS altitude and the barometer are fused, and the app accepts when the probability of being inside the band is at least 50%.
*   **Enforcement:** Prevents false check-ins if the student is standing directly above or below the classroom.

### B. Lateral (Horizontal) Allowance [NEW]
*   **Purpose:** Compensates for lateral GPS triangulation errors and multipath interference (common when indoors or surrounded by large campus structures).
*   **Allowance Zone:** A **5-meter horizontal buffer** is extruded outwards from the classroom's polygon boundary lines.
*   **Enforcement:** If a student's calculated coordinates place them slightly outside the classroom area (up to 5 meters from any wall or corner), the check-in is accepted as valid. Check-ins beyond the 5-meter limit are immediately blocked.

---

## 🔒 5. Mitigating Multi-Fingerprint Enrollment (Enrolling a Friend's Fingerprint)

If a student registers a classmate's fingerprint on their device (enrolling it in the phone's system settings), the OS's native biometric manager treats both fingerprints as the "Device Owner." However, the system mitigates and prevents this exploit through three layers of security:

### A. High Personal Friction (Device Sharing Lock)
A student’s phone contains highly sensitive personal data (banking apps, private messaging, emails, and social media accounts). 
* To exploit this loophole, the absent student **must physically surrender their phone** to their friend for the day.
* Due to privacy concerns, the friction of giving away an unlocked personal phone is extremely high, making it a very rare occurrence.
* If a classmate is caught holding or scanning two active phones during class, it is a visible physical indicator of attendance spoofing.

### B. Biometric Key Invalidation (planned, not implemented)
This defence is not in the current version. A future version could generate a cryptographic key pair inside the phone's hardware **Secure Enclave / Keystore** to sign check-ins.
* When this key is generated, it would set the OS attribute `setInvalidatedByBiometricEnrollment(true)` (Android) or `SecAccessControl` policies (iOS).
* If the student enrolls a new fingerprint (e.g., their friend's) in their device settings *after* the initial registration, **the phone's operating system automatically invalidates and deletes the cryptographic keys**.
* The check-in would then fail, and the student would have to ask the teacher to reset their account, exposing the modification attempt.

### C. Secondary Front-Camera Verification (Optional Upgrade)
For high-stakes examinations or strict attendance policies, a front-camera verification step can be integrated:
* During biometric verification, the front camera captures a quick selfie of the user checking in.
* The photo is uploaded alongside the attendance record to Supabase or compared on-device.
* If a friend checks in the device, the face in the photo will not match the registered student's face, providing audit trails.

---

## 🛠️ 6. Device Recovery (If a student loses their phone)

If a student gets a new phone or loses their device, they cannot register the new device themselves because their code is already consumed.

1.  The student must report the device change to the teacher.
2.  The teacher opens the student management screen and taps **Reset device**.
3.  The server replaces the binding with a **new single-use registration code**.
4.  The old phone loses access the next time it is online.
