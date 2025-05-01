$ErrorActionPreference = "Stop"

# Set paths
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH += ";$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin"

# Clean
flutter clean
Remove-Item -Recurse -Force android/.gradle, android/build, android/app/build -ErrorAction SilentlyContinue

# Update SDK components
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "platform-tools" "build-tools;34.0.0" "ndk;27.0.12077973"

# Rebuild
flutter pub get
flutter build apk --debug --target-platform android-arm64 -v

# Verify APK
if (Test-Path "build/app/outputs/apk/debug/app-debug.apk") {
    Write-Host "SUCCESS: APK generated at build/app/outputs/apk/debug/app-debug.apk" -ForegroundColor Green
} else {
    Write-Host "ERROR: Build failed - APK not found" -ForegroundColor Red
}
