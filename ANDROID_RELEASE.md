# Android Release

This document records the Android-first release workflow for Lumbar Rhythm.

## Current package outputs

Use these commands from the repository root:

```powershell
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Successful outputs:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Do not commit APK files to Git after packaging. For direct testing
distribution, upload the APK to a GitHub Release. Local developers can rebuild
the APK from source when needed.

## Release signing

The Android Gradle config reads release signing settings from:

```text
android/key.properties
```

This file is intentionally ignored by Git because it contains signing secrets.
The keystore file is also ignored by Git.

Create `android/key.properties` with this shape:

```properties
storePassword=REPLACE_WITH_STORE_PASSWORD
keyPassword=REPLACE_WITH_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Place the matching keystore at:

```text
android/app/upload-keystore.jks
```

When `android/key.properties` exists, release APK and AAB builds use the store
keystore. When it does not exist, the project falls back to debug signing so the
release build pipeline can still be verified locally.

## Important

- Back up the keystore and passwords safely before publishing.
- Do not commit `android/key.properties` or any `.jks` / `.keystore` files.
- Do not `git add` APK files. APKs are release artifacts, not repository files.
- The same release identity must be kept for future updates.
- For Google Play, upload the AAB after signing is configured.
- For direct testing distribution, upload the APK to GitHub Releases.
