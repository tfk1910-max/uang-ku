#!/usr/bin/env bash
# Build APK lokal; memerlukan Flutter stable, Java 17, dan Android SDK.
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter tidak ditemukan. Pasang Flutter stable dan Android SDK terlebih dahulu." >&2
  exit 1
fi

if [ ! -d android ]; then
  flutter create --platforms=android --org id.uangku --project-name uangku_offline .
fi

if [ -f android/app/src/main/AndroidManifest.xml ]; then
  sed -i 's/android:label="[^"]*"/android:label="Uangku"/' android/app/src/main/AndroidManifest.xml
fi

flutter pub get
flutter build apk --release
echo "APK berhasil dibuat di: build/app/outputs/flutter-apk/app-release.apk"
