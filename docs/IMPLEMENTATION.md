# Dwell 1.1.0+6 implementation

Completed:

1. SQLite API: accounts, hashed expiring sessions, household membership, invites, chore CRUD, recurring completion and request limits.
2. Responsive Flutter Android/iOS/web client: green visual system, dashboard, chore management, household switching/invites and server settings. Light/dark mode toggles from the home header and remembers the choice on-device. Native iOS project uses bundle ID `com.dwell.dwell`, minimum iOS 15, and the matching green launcher icon.
3. Local offline home: chores persist on-device across restarts and can be created, edited, completed and deleted without network requests. Offline homes are separate from shared server homes.
4. Verification: 9 backend tests, 5 deployment helper tests and 11 Flutter tests pass; analysis clean; Android and web release builds complete; APK signature, iOS icon catalog, host ZIP integrity and local HTTP smoke test verified.
5. Deliverables: Android APK, Mac-ready iOS source ZIP and app icon, light and dark phone previews, desktop preview, prebuilt host ZIP and verification/setup guide.

Native iOS compilation/signing requires Xcode on macOS; this Linux workspace cannot produce an IPA. Open `ios/Runner.xcworkspace` on a Mac, choose a signing team, and run on a device or archive for distribution.

Deployment verified on 2026-10-18: host target `dwell`, job `dd920a37-ba18-4af1-9536-663db4f191a0` succeeded. Container `dwell-dwell-1` is healthy and publishes `0.0.0.0:8081` to container port 8080. The host worker's HTTP health check passed. Persistent SQLite storage and the container health check are configured.
