package app.lumbarhythm.lumbar_rhythm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import kotlin.math.max

object PostureAlarmScheduler {
    private const val PREFS = "posture_alarm"
    private const val ACTION_ALARM_DUE = "app.lumbarhythm.lumbar_rhythm.POSTURE_ALARM_DUE"
    private const val ACTION_REST = "app.lumbarhythm.lumbar_rhythm.POSTURE_ALARM_REST"
    private const val ACTION_HANDLED = "app.lumbarhythm.lumbar_rhythm.POSTURE_ALARM_HANDLED"
    private const val EXTRA_POSTURE_TYPE = "postureType"
    private const val EXTRA_REMINDER_MODE = "reminderMode"
    private const val EXTRA_STARTED_AT_MILLIS = "startedAtMillis"
    private const val EXTRA_DUE_AT_MILLIS = "dueAtMillis"
    private const val REQUEST_ALARM = 4101
    private const val REQUEST_SHOW = 4102
    private const val REQUEST_REST = 4103
    private const val REQUEST_HANDLED = 4104
    private const val SITTING_DUE_NOTIFICATION_ID = 101
    private const val STANDING_DUE_NOTIFICATION_ID = 102
    private const val SOFT_CHANNEL_ID = "lumbar_rhythm_soft_reminders_v2"
    private const val VIBRATION_CHANNEL_ID = "lumbar_rhythm_vibration_reminders_v2"
    private const val ALARM_CHANNEL_ID = "lumbar_rhythm_alarm_reminders_v2"
    private const val MODE_VIBRATION = "vibration"
    private const val MODE_ALARM = "alarm"
    const val POSTURE_SITTING = "sitting"
    const val POSTURE_STANDING = "standing"

    fun startAlarm(
        context: Context,
        postureType: String,
        durationSeconds: Long,
        reminderMode: String,
        startedAtMillis: Long,
    ): Map<String, Any?> {
        cancelAlarm(context)
        ensureChannels(context)
        val dueAtMillis = startedAtMillis + durationSeconds * 1000L

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(dueAtMillis, showIntent(context, postureType)),
                alarmIntent(context),
            )
            saveState(
                context = context,
                scheduled = true,
                postureType = postureType,
                startedAtMillis = startedAtMillis,
                dueAtMillis = dueAtMillis,
                reminderMode = reminderMode,
            )
            mapOf(
                "success" to true,
                "mode" to "alarmClock",
                "code" to "ok",
                "message" to "\u7cfb\u7edf\u63d0\u9192\u5df2\u542f\u52a8",
                "dueAtMillis" to dueAtMillis,
            )
        } catch (error: SecurityException) {
            mapOf(
                "success" to false,
                "mode" to "none",
                "code" to "security_exception",
                "message" to "\u7cfb\u7edf\u6743\u9650\u9650\u5236\uff1a${error.message ?: ""}",
                "dueAtMillis" to dueAtMillis,
            )
        } catch (error: Exception) {
            mapOf(
                "success" to false,
                "mode" to "none",
                "code" to "start_alarm_failed",
                "message" to (error.message ?: "\u7cfb\u7edf\u63d0\u9192\u542f\u52a8\u5931\u8d25"),
                "dueAtMillis" to dueAtMillis,
            )
        }
    }

    fun canScheduleExactAlarms(context: Context): Map<String, Any> {
        return mapOf(
            "canScheduleExactAlarms" to canScheduleExactAlarmsValue(context),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmIntent(context))
        clearNotifications(context)
        saveState(
            context = context,
            scheduled = false,
            postureType = null,
            startedAtMillis = null,
            dueAtMillis = null,
            reminderMode = "soft",
        )
    }

    fun markHandled(context: Context) {
        cancelAlarm(context)
    }

    fun onAlarmDue(context: Context) {
        ensureChannels(context)
        val state = readState(context)
        if (!state.scheduled || state.postureType == null) {
            return
        }
        saveState(
            context = context,
            scheduled = false,
            postureType = state.postureType,
            startedAtMillis = state.startedAtMillis,
            dueAtMillis = state.dueAtMillis,
            reminderMode = state.reminderMode,
        )
        showDueNotification(context, state.postureType, state.reminderMode)
        runCatching {
            context.startActivity(
                Intent(context, PostureAlarmActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(EXTRA_POSTURE_TYPE, state.postureType)
                },
            )
        }
    }

    fun getState(context: Context): Map<String, Any?> {
        val state = readState(context)
        val dueAtMillis = state.dueAtMillis
        val remainingSeconds =
            if (state.scheduled && dueAtMillis != null) {
                max(0L, (dueAtMillis - System.currentTimeMillis()) / 1000L).toInt()
            } else {
                0
            }
        return mapOf(
            "scheduled" to state.scheduled,
            "postureType" to state.postureType,
            "dueAtMillis" to dueAtMillis,
            "startedAtMillis" to state.startedAtMillis,
            "remainingSeconds" to remainingSeconds,
        )
    }

    fun actionIntent(context: Context, action: String): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            if (action == ACTION_REST) REQUEST_REST else REQUEST_HANDLED,
            Intent(context, PostureAlarmReceiver::class.java).apply {
                this.action = action
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun isRestAction(action: String?) = action == ACTION_REST

    fun isHandledAction(action: String?) = action == ACTION_HANDLED

    fun isDueAction(action: String?) = action == ACTION_ALARM_DUE

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                SOFT_CHANNEL_ID,
                "\u8f7b\u67d4\u5750\u7ad9\u63d0\u9192",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
        manager.createNotificationChannel(
            NotificationChannel(
                VIBRATION_CHANNEL_ID,
                "\u9707\u52a8\u5750\u7ad9\u63d0\u9192",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 180, 120, 180)
                setSound(null, null)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALARM_CHANNEL_ID,
                "\u54cd\u94c3\u5750\u7ad9\u63d0\u9192",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 450, 180, 450)
            },
        )
    }

    private fun canScheduleExactAlarmsValue(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun showDueNotification(context: Context, postureType: String, reminderMode: String) {
        val (title, body, id) = messageFor(postureType)
        val notification = NotificationCompat.Builder(context, reminderChannelId(reminderMode))
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(showIntent(context, postureType))
            .addAction(0, "\u6211\u53bb\u4f11\u606f\u4e86", actionIntent(context, ACTION_REST))
            .addAction(0, "\u5df2\u5904\u7406", actionIntent(context, ACTION_HANDLED))
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }

    fun messageFor(postureType: String?): Triple<String, String, Int> {
        return if (postureType == POSTURE_STANDING) {
            Triple(
                "\u8be5\u53d8\u6362\u59ff\u52bf\u4e86",
                "\u5df2\u7ecf\u8fde\u7eed\u7ad9\u4e86\u4e00\u6bb5\u65f6\u95f4\uff0c\u5efa\u8bae\u5750\u4e0b\u6216\u8d70\u52a8\u653e\u677e\u4e00\u4e0b",
                STANDING_DUE_NOTIFICATION_ID,
            )
        } else {
            Triple(
                "\u8be5\u6d3b\u52a8\u4e00\u4e0b\u4e86",
                "\u5df2\u7ecf\u8fde\u7eed\u5750\u4e86\u4e00\u6bb5\u65f6\u95f4\uff0c\u5efa\u8bae\u8d77\u8eab\u6d3b\u52a8\u4e00\u4e0b",
                SITTING_DUE_NOTIFICATION_ID,
            )
        }
    }

    private fun clearNotifications(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(SITTING_DUE_NOTIFICATION_ID)
        manager.cancel(STANDING_DUE_NOTIFICATION_ID)
    }

    private fun alarmIntent(context: Context): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            REQUEST_ALARM,
            Intent(context, PostureAlarmReceiver::class.java).apply {
                action = ACTION_ALARM_DUE
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showIntent(context: Context, postureType: String?): PendingIntent {
        return PendingIntent.getActivity(
            context,
            REQUEST_SHOW,
            Intent(context, PostureAlarmActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(EXTRA_POSTURE_TYPE, postureType)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun reminderChannelId(reminderMode: String): String {
        return when (reminderMode) {
            MODE_VIBRATION -> VIBRATION_CHANNEL_ID
            MODE_ALARM -> ALARM_CHANNEL_ID
            else -> SOFT_CHANNEL_ID
        }
    }

    private fun readState(context: Context): AlarmState {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return AlarmState(
            scheduled = prefs.getBoolean("scheduled", false),
            postureType = prefs.getString(EXTRA_POSTURE_TYPE, null),
            startedAtMillis = prefs.getLong(EXTRA_STARTED_AT_MILLIS, 0L).takeIf { it > 0L },
            dueAtMillis = prefs.getLong(EXTRA_DUE_AT_MILLIS, 0L).takeIf { it > 0L },
            reminderMode = prefs.getString(EXTRA_REMINDER_MODE, "soft") ?: "soft",
        )
    }

    private fun saveState(
        context: Context,
        scheduled: Boolean,
        postureType: String?,
        startedAtMillis: Long?,
        dueAtMillis: Long?,
        reminderMode: String,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("scheduled", scheduled)
            .putString(EXTRA_POSTURE_TYPE, postureType)
            .putLong(EXTRA_STARTED_AT_MILLIS, startedAtMillis ?: 0L)
            .putLong(EXTRA_DUE_AT_MILLIS, dueAtMillis ?: 0L)
            .putString(EXTRA_REMINDER_MODE, reminderMode)
            .apply()
    }

    data class AlarmState(
        val scheduled: Boolean,
        val postureType: String?,
        val startedAtMillis: Long?,
        val dueAtMillis: Long?,
        val reminderMode: String,
    )
}
