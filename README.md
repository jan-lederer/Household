# Dwell

Dwell helps people in an apartment share chores, assign work to housemates, and keep recurring tasks moving. The Flutter app pairs with a small SQLite-backed API and uses a home-and-sparkle mark in warm cream, deep sage, and muted orange.

## Local setup

Install Flutter 3.47.7 (and Android SDK tools for Android builds), plus Python 3. The `scripts/flutterw` wrapper prefers a project-local SDK at `.tooling/flutter`; if it is absent, it uses `flutter` from `PATH`. Pub, Gradle, Android, and Flutter config/cache files are directed to `.tooling/`.

Build the web app, then run the API and static web host on port 8080:

```sh
./scripts/flutterw pub get
./scripts/flutterw build web --release --no-web-resources-cdn
DWELL_PORT=8080 DWELL_DB=./data/dwell.sqlite DWELL_WEB=./build/web python3 backend/server.py
```

Open `http://localhost:8080`. The browser app uses the same-origin API automatically. Check the service at `http://localhost:8080/api/health`. Secure browser storage requires HTTPS or localhost; use the Android app for plain HTTP access on your home network.

To try the interface without creating an account or starting a server, select **Explore a demo home** on the sign-in screen. Demo changes are temporary, reset when you leave, and are not shared with other users. To use real data, create an account, create a home, then share its invite code from the Household tab so housemates can join with their own accounts.

## Android

Build an installable debug APK with `./scripts/flutterw build apk --debug`, or a release APK with `./scripts/flutterw build apk --release`. The release build currently uses Flutter's development debug signing configuration; sign it with your own release key before distributing it. The APK is written to `build/app/outputs/flutter-apk/app-release.apk` for release builds.

Android emulators default to `http://10.0.2.2:8080`. To connect a phone to a home server, set Dwell's server address to the computer's LAN address, such as `http://192.168.1.20:8081` for Docker (`:8080` for direct Python); both devices need to be on the same network and the host firewall must allow the selected host port (8081 for Docker). You can also set the default at build time with `--dart-define=API_URL=http://192.168.1.20:8080`. Local HTTP is enabled for home-network use. Use HTTPS before exposing the service to the public internet; do not send passwords over public plain HTTP.

## Docker

Docker builds the Flutter web client with Flutter 3.47.7 and runs the API and web client together:

```sh
docker compose up --build -d
curl http://localhost:8081/api/health
docker compose ps
```

Open `http://HOST_ADDRESS:8081`, using the same host address as Pocket Codex. Docker explicitly publishes `0.0.0.0:8081` and forwards to container port 8080. Port 8080 on this host already belongs to Dataset Management. Set `DWELL_HOST_PORT` / `DWELL_BIND_ADDRESS` in `.env` to override the mapping. SQLite data persists in `./data/dwell.sqlite` across container recreation. Back up the `data/` directory. The container health check queries `/api/health`. Stop the service with `docker compose down`.

For internet access, put the service behind a trusted TLS reverse proxy, restrict who can reach it, and back up the database. The bundled server is intended for a small household, not as a hardened public-facing service by itself.

## Checks and icon assets

Run Flutter static analysis and widget checks with `./scripts/flutterw analyze` and `./scripts/flutterw test`. Run the backend API integration suite with `python3 -m unittest discover -s backend -p 'test_*.py'`. The vector source is `assets/dwell-mark.svg`; regenerate launcher and web PNGs with `python3 scripts/generate_icons.py`.

## Prebuilt host bundle

After building the web app, run `python3 scripts/package_host.py`. The verified `artifacts/dwell-host.zip` includes the web client, dependency-free backend, and a lightweight Docker configuration that does not need Flutter on the host.

## Expose on the Pocket Codex host

The current host Docker worker has `dwell` registered, and deployment is verified on host port 8081. Redeploy it with `pocket-docker deploy dwell`, save the returned job UUID, then check `pocket-docker job JOB_UUID` and `pocket-docker status dwell`.

For first-time registration on another host, run this on the **Docker host** from the Pocket Codex repository directory:

```sh
python3 Household/scripts/deploy_host.py
```

The script preserves existing worker targets, backs up its private configuration, adds `dwell`, restarts the idle worker, and queues its deployment. It uses `Dockerfile.host` with the existing verified `build/web` assets, so the host needs no Flutter SDK. It saves the accepted job UUID before waiting, checks the terminal result, published host port and API health, and writes results under `artifacts/deployment-result.json`. It refuses to restart the worker while jobs are queued/running. On this installation the full command is `python3 /home/jan/projects/code/Household/scripts/deploy_host.py`.

After this one-time registration, save `pocket-docker deploy dwell` in this project's Deployment settings. Future deployments can run directly from the phone. The app's server address is `http://SAME_HOST_AS_POCKET_CODEX:8081`. Host health endpoint: `http://127.0.0.1:8081/api/health`. The worker's private allowlist is outside the app container, so workspace edits alone cannot activate the port mapping.
