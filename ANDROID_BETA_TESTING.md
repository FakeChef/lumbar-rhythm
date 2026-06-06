# Android Beta Testing

This guide is for a small Android beta test before public release.

## Test package

Use the signed release APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Suggested shared file name:

```text
lumbar-rhythm-0.1.0-android-release.apk
```

## Tester message

You can send this text to testers:

```text
这是“腰椎节奏”的 Android 测试版。

它是一个永久免费、无广告、无账号、无云端上传的久坐久站提醒和本地自我记录 App。

请帮忙测试：
1. 能否正常安装和打开。
2. 首页文字和布局是否正常。
3. 测试提醒是否能发出。
4. 能否新增久坐、久站、症状记录、活动/拉伸记录。
5. 报告页统计和最近 7 天趋势图是否看得懂。
6. 周报图片是否能保存到手机相册。
7. 备份 JSON 和删除全部本地数据是否可用。
8. 有没有卡顿、闪退、看不懂、容易误解或让人焦虑的地方。

注意：这个 App 不是医疗器械，不提供诊断、治疗建议或复发判断。出现明显异常或严重症状时，请及时就医。
```

## Installation notes for testers

- Android may warn that the APK is from an unknown source.
- Allow installation only if the tester trusts the package source.
- If installation is blocked, enable installation from the file manager or browser used to open the APK.
- The app does not require login or network access.
- If notification testing is needed, allow notification permission when prompted.

## Core test tasks

Ask each tester to complete these tasks:

1. Open the app and check the home page.
2. Tap "测试提醒" and confirm whether a notification appears.
3. Add one sitting record.
4. Add one standing record.
5. Add one symptom record with a short note.
6. Add one movement/stretch record.
7. Search or filter records on the records page.
8. Open the reports page and check today's counts.
9. Check the recent seven-day trend chart.
10. Save the recent seven-day report image to the gallery.
11. Export local JSON data if the tester understands it is an advanced backup feature.
12. Delete all local data and confirm that reports become empty.

## Feedback template

```text
手机型号：
Android 版本：
能否安装：
能否打开：
通知是否成功：
记录是否成功：
报告是否清楚：
最近 7 天趋势图是否清楚：
周报图片是否成功保存到相册：
备份 JSON/删除是否成功：
是否有闪退或卡顿：
哪里看不懂：
哪里让你不舒服或焦虑：
最希望增加什么：
其他建议：
```

## Suggested beta size

- Start with 3 trusted testers.
- Fix obvious install, notification, wording, and crash issues.
- Expand to 10 testers after the first round is stable.

## What to avoid during beta

- Do not describe the app as a treatment tool.
- Do not ask testers to upload personal health records.
- Do not collect exported JSON unless the tester clearly agrees.
- Do not promise prevention, cure, recovery, or recurrence judgment.
