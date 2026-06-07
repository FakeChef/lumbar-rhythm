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
3. 今日页坐站节奏大计时器、坐/站/走/休息切换和今日摘要是否清楚。
4. 日历页状态点和当天详情是否清楚。
5. 康复页动作记录、做后反应和明显加重提示是否可用。
6. 报告页坐站节奏报告、康复记录报告和免责声明是否清楚。
7. 设置页提醒间隔、隐私说明、数据导出和删除本地数据是否可用。
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
2. On the Today tab, check the sitting/standing rhythm timer, switch between sitting, standing, walking, and resting, and review today's summary.
3. On the Calendar tab, check date status dots and open one day to review the day's details.
4. On the Rehab tab, add one action record, choose a post-action reaction, and confirm the gentle prompt appears when "明显加重" is selected.
5. On the Reports tab, check the sitting/standing rhythm report, rehabilitation record report, and disclaimer text.
6. On the Settings tab, adjust reminder intervals, open the privacy text, export local JSON data, and delete all local data.
7. Confirm report and reminder text is for personal review only and does not read like diagnosis, treatment advice, or recovery judgment.

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
今日页坐站节奏和今日摘要是否清楚：
日历回看是否清楚：
康复记录是否清楚：
设置页提醒/隐私/导出/删除是否清楚：
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
