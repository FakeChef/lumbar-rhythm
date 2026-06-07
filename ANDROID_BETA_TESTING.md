# Android Beta Testing

This guide is for a small Android beta test before public release.

## Test package

Use the signed release APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Suggested shared file name:

```text
lumbar-rhythm-v0.3.0-beta1.apk
```

## Tester message

You can send this text to testers:

```text
这是“腰椎节奏”的 Android 测试版。

它是一个永久免费、无广告、无账号、无云端上传的腰突术后康复日志 App。坐站节奏是核心工具之一，所有记录默认保存在本地设备。

请帮忙测试：
1. 能否正常安装和打开。
2. 底部导航“今日 / 日历 / 康复 / 报告 / 设置”是否都能打开。
3. 今日页坐站节奏、测试提醒、康复动作记录和今日康复小结是否可用。
4. 日历页是否可以按日期回看个人记录。
5. 康复页是否可以从内置动作模板新增康复记录。
6. 报告页日、周、月汇总是否清楚，是否没有医疗结论或疗效承诺。
7. 设置页导出 JSON 和删除全部本地数据是否可用。
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

1. Open the app and confirm the bottom navigation shows Today, Calendar, Rehab, Reports, and Settings.
2. On the Today tab, switch between sitting, standing, walking, and resting.
3. On the Today tab, tap "测试提醒" and confirm whether a local notification appears.
4. On the Today tab, add one rehabilitation action record and one daily recovery note.
5. On the Calendar tab, choose a date and confirm the day's records are shown.
6. On the Rehab tab, add one rehabilitation log from a built-in action template.
7. On the Reports tab, check the day, week, and month summaries.
8. Confirm report text is for personal review only and does not read like diagnosis, treatment advice, or recovery judgment.
9. On the Settings tab, export local JSON data if the tester understands it is an advanced backup feature.
10. On the Settings tab, delete all local data and confirm records and reports become empty.

## Feedback template

```text
手机型号：
Android 版本：
能否安装：
能否打开：
通知是否成功：
记录是否成功：
报告是否清楚：
五个底部页面是否都能正常打开：
日历回看是否清楚：
康复记录是否清楚：
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
