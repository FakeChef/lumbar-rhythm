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

它是一个永久免费、无广告、无账号、无云端上传的腰突术后康复日志 App，其中坐站节奏是核心工具之一。

请帮忙测试：
1. 能否正常安装和打开。
2. 今日、日历、康复、报告、设置五个页面是否能正常切换。
3. 测试提醒是否能发出。
4. 今日页能否切换坐着、站着、走动、休息并保存坐站记录。
5. 康复页能否新增康复记录，今日页能否保存康复小结。
6. 报告页的日、周、月汇总是否看得懂。
7. 备份 JSON 和删除全部本地数据是否可用。
8. 有没有卡顿、闪退、看不懂、容易误解或让人焦虑的地方。

注意：这个 App 不是医疗器械，不提供诊断、治疗建议、复发判断或医疗结论。出现明显异常或严重症状时，请及时就医。
```

## Installation notes for testers

- Android may warn that the APK is from an unknown source.
- Allow installation only if the tester trusts the package source.
- If installation is blocked, enable installation from the file manager or browser used to open the APK.
- The app does not require login or network access.
- If notification testing is needed, allow notification permission when prompted.

## Core test tasks

Ask each tester to complete these tasks:

1. Open the app and check the five tabs: 今日, 日历, 康复, 报告, 设置.
2. On 今日, switch between sitting, standing, walking, and resting.
3. Tap "测试提醒" in 设置 and confirm whether a notification appears.
4. Add one rehabilitation record from 康复.
5. Add one daily recovery note from 今日.
6. Open 日历 and check whether the selected day summary is understandable.
7. Open 报告 and check daily, seven-day, and monthly summaries.
8. Export local JSON data if the tester understands it is an advanced backup feature.
9. Delete all local data and confirm that reports become empty.

## Feedback template

```text
手机型号：
Android 版本：
能否安装：
能否打开：
通知是否成功：
康复记录是否成功：
报告是否清楚：
最近 7 天趋势图是否清楚：
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
