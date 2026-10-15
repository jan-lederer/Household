FROM ghcr.io/cirruslabs/flutter:3.47.7 AS web-build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --no-web-resources-cdn

FROM python:3.12-slim AS runtime
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DWELL_PORT=8080 DWELL_DB=/data/dwell.sqlite DWELL_WEB=/app/build/web
COPY backend/server.py /app/backend/server.py
COPY --from=web-build /src/build/web /app/build/web
VOLUME ["/data"]
EXPOSE 8080
CMD ["python", "/app/backend/server.py"]
