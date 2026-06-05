# Release Checklist

This checklist is for preparing Lumbar Rhythm for Android and iOS review.

## Product Scope

- The app is free forever.
- The app has no ads.
- The app has no account system.
- The app has no subscription.
- The app has no cloud upload or sync.
- The app has no third-party tracking SDK.
- The app is a reminder and self-recording tool, not a medical device.

## Privacy

- No login or registration is required.
- Health-related records stay on the local device.
- Reminder settings stay on the local device.
- Users can export local data.
- Users can delete all local data.
- The privacy text in the app matches `PRIVACY.md`.
- The store privacy questionnaire should not claim cloud collection or tracking.

## Medical Boundary

- The app does not provide diagnosis.
- The app does not provide treatment advice.
- The app does not judge recurrence.
- The app does not replace doctors, therapists, or other licensed professionals.
- The disclaimer text in the app matches `DISCLAIMER.md`.
- Store description should describe the app as a reminder and self-recording tool.

## Android

- `android.permission.POST_NOTIFICATIONS` is present only for local reminders.
- No exact alarm permission is requested.
- App label is correct.
- Package id is correct.
- Debug build can be installed on an emulator or physical device.
- Notification permission flow has been checked on Android 13 or later.
- Export and delete local data have been checked on a device.

## iOS

- App name is correct.
- Notification permission flow has been checked.
- Local notification test works after permission is granted.
- Export and delete local data have been checked on a device or simulator.
- App Store privacy labels match the local-only data model.

## Functional QA

- Home page opens without errors.
- Records can be created, searched, filtered, and deleted.
- Actions can be marked as completed.
- Reports show today's summary.
- Reports show the recent seven-day summary.
- Weekly report image can be saved locally as a PNG file.
- Settings can save reminder intervals.
- Test notification can be triggered.
- Local JSON export contains app metadata, settings, and records.
- Delete all local data clears records and settings.

## Build Verification

- `dart analyze lib test` passes.
- `flutter test` passes when the local Flutter tool is healthy.
- Android debug APK builds successfully.
- Release build steps are documented before publishing.

## Repository

- `README.md` is current.
- `PRIVACY.md` is current.
- `DISCLAIMER.md` is current.
- `AGENTS.md` is current.
- `QA.md` is current.
- Git working tree is clean before tagging a release.
