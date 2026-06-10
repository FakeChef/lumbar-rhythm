package app.lumbarhythm.lumbar_rhythm

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val galleryChannel = "lumbar_rhythm/gallery"
    private val postureCountdownChannel = "lumbar_rhythm/posture_countdown"
    private val postureAlarmChannel = "lumbar_rhythm/posture_alarm"
    private val reminderChannel = "lumbar_rhythm/reminder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            galleryChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePngToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")

                    if (bytes == null || fileName.isNullOrBlank()) {
                        result.error("invalid_args", "Missing image bytes or file name.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = savePngToGallery(bytes, fileName)
                        result.success(mapOf("saved" to (uri != null), "uri" to uri?.toString()))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            postureCountdownChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPostureCountdown" -> {
                    val postureType = call.argument<String>("postureType")
                    val durationSeconds = call.argument<Int>("durationSeconds")?.toLong()
                    val reminderMode = call.argument<String>("reminderMode") ?: "soft"
                    val startedAtMillis = call.argument<Long>("startedAtMillis")
                        ?: call.argument<Int>("startedAtMillis")?.toLong()

                    if (
                        postureType.isNullOrBlank() ||
                        durationSeconds == null ||
                        durationSeconds <= 0 ||
                        startedAtMillis == null
                    ) {
                        result.error("invalid_args", "Missing countdown arguments.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        PostureCountdownService.ensureChannels(applicationContext)
                        val response = PostureCountdownService.startReminder(
                            context = applicationContext,
                            postureType = postureType,
                            durationSeconds = durationSeconds,
                            reminderMode = reminderMode,
                            startedAtMillis = startedAtMillis,
                        )
                        result.success(response)
                    } catch (error: Exception) {
                        result.error("start_failed", error.message, null)
                    }
                }
                "stopPostureCountdown" -> {
                    try {
                        PostureCountdownService.stopCountdown(applicationContext)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("stop_failed", error.message, null)
                    }
                }
                "getPostureCountdownState" -> {
                    result.success(PostureCountdownService.getState(applicationContext))
                }
                "completePostureCountdown" -> {
                    result.success(PostureCountdownService.completeSession(applicationContext))
                }
                "snoozePostureCountdown" -> {
                    val minutes = call.argument<Int>("minutes") ?: 10
                    result.success(PostureCountdownService.snooze(applicationContext, minutes))
                }
                "openNotificationSettings" -> {
                    try {
                        openNotificationSettings()
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open_settings_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            postureAlarmChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPostureAlarm" -> {
                    val postureType = call.argument<String>("postureType")
                    val durationSeconds = call.argument<Int>("durationSeconds")?.toLong()
                    val reminderMode = call.argument<String>("reminderMode") ?: "soft"
                    val startedAtMillis = call.argument<Long>("startedAtMillis")
                        ?: call.argument<Int>("startedAtMillis")?.toLong()

                    if (
                        postureType.isNullOrBlank() ||
                        durationSeconds == null ||
                        durationSeconds <= 0 ||
                        startedAtMillis == null
                    ) {
                        result.error("invalid_args", "Missing posture alarm arguments.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val response = PostureAlarmScheduler.startAlarm(
                            context = applicationContext,
                            postureType = postureType,
                            durationSeconds = durationSeconds,
                            reminderMode = reminderMode,
                            startedAtMillis = startedAtMillis,
                        )
                        result.success(response)
                    } catch (error: Exception) {
                        val dueAtMillis = startedAtMillis + durationSeconds * 1000L
                        result.success(
                            mapOf(
                                "success" to false,
                                "mode" to "none",
                                "code" to "start_alarm_failed",
                                "message" to (error.message ?: "Alarm start failed."),
                                "dueAtMillis" to dueAtMillis,
                            ),
                        )
                    }
                }
                "cancelPostureAlarm" -> {
                    try {
                        PostureAlarmScheduler.cancelAlarm(applicationContext)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("cancel_alarm_failed", error.message, null)
                    }
                }
                "getPostureAlarmState" -> {
                    result.success(PostureAlarmScheduler.getState(applicationContext))
                }
                "canScheduleExactAlarms" -> {
                    result.success(PostureAlarmScheduler.canScheduleExactAlarms(applicationContext))
                }
                "openExactAlarmSettings" -> {
                    result.success(openExactAlarmSettings())
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            reminderChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSittingReminder", "startStandingReminder" -> {
                    val postureType = if (call.method == "startStandingReminder") "standing" else "sitting"
                    val durationSeconds = call.argument<Int>("durationSeconds")?.toLong()
                        ?: call.argument<Int>("durationMinutes")?.toLong()?.times(60L)
                    val reminderMode = call.argument<String>("reminderMode") ?: "soft"
                    val startedAtMillis = call.argument<Long>("startedAtMillis")
                        ?: call.argument<Int>("startedAtMillis")?.toLong()
                        ?: System.currentTimeMillis()
                    if (durationSeconds == null || durationSeconds <= 0L) {
                        result.success(
                            mapOf(
                                "success" to false,
                                "errorCode" to "invalid_args",
                                "message" to "Missing reminder duration.",
                                "permission" to PostureCountdownService.getReminderPermissionStatus(applicationContext),
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    result.success(
                        PostureCountdownService.startReminder(
                            context = applicationContext,
                            postureType = postureType,
                            durationSeconds = durationSeconds,
                            reminderMode = reminderMode,
                            startedAtMillis = startedAtMillis,
                        ),
                    )
                }
                "cancelReminder" -> {
                    result.success(PostureCountdownService.cancelSession(applicationContext))
                }
                "completeReminder" -> {
                    result.success(PostureCountdownService.completeSession(applicationContext))
                }
                "snoozeReminder" -> {
                    val minutes = call.argument<Int>("minutes") ?: 10
                    result.success(PostureCountdownService.snooze(applicationContext, minutes))
                }
                "getActiveReminderSession" -> {
                    result.success(PostureCountdownService.getActiveReminderSession(applicationContext))
                }
                "getReminderPermissionStatus" -> {
                    result.success(PostureCountdownService.getReminderPermissionStatus(applicationContext))
                }
                "openExactAlarmSettings" -> {
                    result.success(openExactAlarmSettings())
                }
                "openNotificationSettings" -> {
                    try {
                        openNotificationSettings()
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open_settings_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
        }
        startActivity(intent)
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (intent.resolveActivity(packageManager) == null) {
            return false
        }
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun savePngToGallery(bytes: ByteArray, fileName: String): android.net.Uri? {
        val resolver = applicationContext.contentResolver
        val imageCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Lumbar Rhythm")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(imageCollection, values) ?: return null

        resolver.openOutputStream(uri)?.use { output ->
            output.write(bytes)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri
    }
}
