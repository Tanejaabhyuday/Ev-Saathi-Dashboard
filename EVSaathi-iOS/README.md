# EV Saathi — iOS App Setup Guide

> **Stack**: SwiftUI · Firebase Auth · Firestore · MapKit  
> **Min iOS**: 16.0 · **Language**: Swift 5.9+  
> **Xcode**: 15+

---

## 1. Create the Xcode Project

1. Open **Xcode → File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   | Field | Value |
   |---|---|
   | Product Name | `EVSaathi` |
   | Bundle Identifier | `com.evosaathi.fleet` |
   | Interface | SwiftUI |
   | Language | Swift |
   | Minimum Deployments | iOS 16.0 |
4. **Uncheck** "Include Tests" for now (optional)
5. Save the project inside this folder (`EVSaathi-iOS/`)

---

## 2. Add Firebase via Swift Package Manager

1. In Xcode → **File → Add Package Dependencies…**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Choose **Up to Next Major** from version `10.0.0`
4. Add these products:
   - ✅ `FirebaseAuth`
   - ✅ `FirebaseFirestore`

---

## 3. Set Up Firebase Console

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `ev-saathi-fleet`
3. **Authentication** → Sign-in method → Enable **Email/Password**
4. **Firestore Database** → Create database → Start in **test mode**
5. **Project Settings** → **Your apps** → **Add iOS app**
   - Bundle ID: `com.evosaathi.fleet`
   - Download `GoogleService-Info.plist`
6. Drag `GoogleService-Info.plist` into the **EVSaathi/** folder in Xcode  
   *(Make sure "Copy items if needed" is checked)*

---

## 4. Apply Firestore Security Rules

1. In Firebase Console → **Firestore → Rules**
2. Replace the default rules with the contents of `firestore.rules` in this folder
3. Click **Publish**

---

## 5. Add Source Files to Xcode

Drag all files from `EVSaathi/` into your Xcode project:

```
EVSaathi/
├── App/            ← EVSaathiApp.swift, ContentView.swift
├── Auth/           ← LoginView.swift, AuthViewModel.swift
├── Models/         ← BusModel, AlertModel, ChargerModel, RouteModel, UserModel
├── ViewModels/     ← FleetViewModel.swift
├── Views/          ← All 6 tab views + AdminProfileView
├── Components/     ← MetricCardView, BusAnnotationView, AlertRowView
└── Services/       ← FirestoreService.swift, SeedService.swift
```

> **Tip**: Drag each folder in at once. In the dialog, check:
> - ✅ Copy items if needed
> - ✅ Create groups
> - ✅ Add to target: EVSaathi

**Delete the default files** Xcode created:
- `ContentView.swift` (replace with ours)
- The default `@main` App file (replace with ours)

---

## 6. Configure App Capabilities

In Xcode → Select your target → **Signing & Capabilities**:
- Ensure your **Team** is selected
- Add **Background Modes** capability → check **Background fetch** (for offline sync)

---

## 7. Run the App (First Launch)

1. Build & run on Simulator or iPhone (⌘R)
2. On the **Login screen**, tap **"Initialize Demo Data"**
   - This seeds 8 buses, 4 chargers into Firestore
   - Creates 3 demo admin accounts in Firebase Auth
3. Sign in with any of these credentials:

| Admin | Email | Password | Role |
|---|---|---|---|
| Abhyuday Taneja | `admin1@evosaathi.com` | `Admin@1234` | Super Admin |
| Priya Mehta | `admin2@evosaathi.com` | `Admin@1234` | Fleet Manager |
| Ravi Shankar | `admin3@evosaathi.com` | `Admin@1234` | Fleet Manager |

---

## 8. Verify Multi-Admin Real-Time Sync

1. Run the app on **two simulators** simultaneously (or iPhone + simulator)
2. Log in with different admin accounts on each
3. Watch the bus positions update in real time on both — powered by Firestore listeners
4. Trigger an alert on one → it appears immediately on the other

---

## Architecture Overview

```
ContentView (auth gate)
│
├── LoginView ─────────────────── AuthViewModel ─── Firebase Auth
│                                                 └── Firestore users
└── MainTabView (5 tabs)
    │
    ├── DashboardView
    ├── LiveMapView ──── MapKit (UIViewRepresentable)
    ├── FleetStatusView → BusDetailView
    ├── ChargingView
    └── AlertsView
         │
         └── FleetViewModel ─── FirestoreService ─── Firestore
                           │         ├── buses (real-time listener)
                           │         ├── chargers (real-time listener)
                           │         └── alerts (real-time listener)
                           └── Timer (2s) ── simulation tick ── writes back to Firestore
```

---

## Offline Behaviour

Firestore offline persistence is enabled in `FirestoreService.init()`:
```swift
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
```

This means:
- ✅ All Firestore data is cached on-device automatically
- ✅ Real-time listeners serve cached data when offline
- ✅ The simulation timer continues running locally
- ✅ Changes sync to Firebase as soon as connectivity is restored

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `GoogleService-Info.plist not found` | Drag it into the Xcode project, check "Copy items if needed" |
| `FirebaseApp.configure() crash` | Make sure `AppDelegate` is connected via `@UIApplicationDelegateAdaptor` |
| Login fails with "Invalid credential" | Check Firebase Console → Auth → enabled providers |
| Map shows blank | MapKit requires device/simulator location permissions + network for tiles |
| No buses on map | Tap "Initialize Demo Data" first to seed Firestore |
| "Permission denied" Firestore error | Apply the `firestore.rules` to Firebase Console |
