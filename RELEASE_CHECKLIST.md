# Release Checklist

This checklist is for preparing Lumbar Rhythm for Android review.

## Product Scope

- The app is free forever.
- The app has no ads.
- The app has no account system.
- The app has no subscription.
- The app has no cloud upload or sync.
- The app has no third-party tracking SDK.
- The app is a postoperative lumbar disc herniation recovery log app, not a medical device.

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
- Store description should describe the app as a postoperative recovery log app with local sitting and standing rhythm reminders.

## Android

- `android.permission.POST_NOTIFICATIONS` is present only for local reminders.
- No exact alarm permission is requested.
- App label is correct.
- Package id is correct.
- Debug build can be installed on an emulator or physical device.
- Notification permission flow has been checked on Android 13 or later.
- Export and delete local data have been checked on a device.
- Release signing uses `android/key.properties` when a store keystore is available.
- Keystore files and signing passwords are not committed to Git.
- Release APK or AAB can be built for Android distribution.
- Android beta testing guide is documented in `ANDROID_BETA_TESTING.md`.

## Functional QA

- Bottom navigation opens Today, Calendar, Rehab, Reports, and Settings without errors.
- Today page opens without errors.
- Current posture can switch between sitting, standing, walking, and resting.
- Posture sessions are saved when the user changes state.
- Sitting reminders are scheduled only when the current posture is sitting.
- Standing reminders are scheduled only when the current posture is standing.
- Walking and resting cancel sitting and standing reminders.
- Today page can save a rehabilitation action record and daily recovery note.
- Calendar page can review records by date.
- Rehabilitation logs can be created from built-in templates.
- Reports show day, week, and month summaries.
- Reports remain framed as personal recovery review and do not provide medical conclusions.
- Settings can save reminder intervals.
- Test notification can be triggered.
- Local JSON export contains app metadata, settings, records, posture sessions, rehabilitation actions, rehabilitation logs, recovery profile, daily recovery notes, and recovery milestones.
- Delete all local data clears records, settings, posture sessions, rehabilitation logs, recovery profile, daily recovery notes, and recovery milestones while keeping built-in rehabilitation templates available.

## Build Verification

- `dart analyze lib test` passes.
- `flutter test` passes when the local Flutter tool is healthy.
- Android debug APK builds successfully.
- Android release APK builds successfully.
- Android App Bundle builds successfully when preparing for store upload.
- Android release build steps are documented in `ANDROID_RELEASE.md`.
- Test APKs are uploaded to GitHub Releases and are not added to Git.

## Repository

- `README.md` is current.
- `PRIVACY.md` is current.
- `DISCLAIMER.md` is current.
- `AGENTS.md` is current.
- `QA.md` is current.
- Root APK files are ignored by Git and no APK is staged for commit.
- Git working tree is clean before tagging a release.
