# Dwell implementation

Completed:

1. SQLite API: accounts, hashed expiring sessions, household membership, invites, chore CRUD, recurring completion and request limits.
2. Responsive Flutter Android/web client: custom icon, dashboard, chore management, household switching/invites and tested server settings.
3. Verification: 9 backend tests and 8 Flutter tests pass; analysis clean; Android and web release builds complete; APK signature and exact host ZIP verified.
4. Deliverables: Android APK, phone/desktop rendered previews, prebuilt host ZIP and verification/setup guide.

Deployment verified on 2026-10-15: host target `dwell`, job `ceebef41-736a-442b-889a-4618909a9d93` succeeded. Container `dwell-dwell-1` is healthy and publishes `0.0.0.0:8081` to container port 8080. Real HTTP checks through the host mapping returned health 200, HTML/JavaScript matching the release build, and 401 for unauthenticated account access. Persistent SQLite storage and the container health check are configured.
