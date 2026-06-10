package app.lumbarhythm.lumbar_rhythm

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

object PostureAlarmScheduler {
    private const val ACTION_ALARM_DUE = PostureCountdownService.ACTION_ALARM_DUE
    private const val ACTION_REST = PostureCountdownService.ACTION_CANCEL
    private const val ACTION_HANDLED = PostureCountdownService.ACTION_HANDLED
    const val POSTURE_SITTING = PostureCountdownService.POSTURE_SITTING
    const val POSTURE_STANDING = PostureCountdownService.POSTURE_STANDING

    fun startAlarm(
        context: Context,
        postureType: String,
        durationSeconds: Long,
        reminderMode: String,
        startedAtMillis: Long,
    ): Map<String, Any?> {
        return PostureCountdownService.startReminder(
            context = context,
            postureType = postureType,
            durationSeconds = durationSeconds,
            reminderMode = reminderMode,
            startedAtMillis = startedAtMillis,
        )
    }

    fun canScheduleExactAlarms(context: Context): Map<String, Any> {
        val available = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            true
        } else {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        }
        return mapOf(
            "canScheduleExactAlarms" to available,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    fun cancelAlarm(context: Context) {
        PostureCountdownService.cancelSession(context)
    }

    fun markHandled(context: Context) {
        PostureCountdownService.completeSession(context)
    }

    fun onAlarmDue(context: Context) {
        PostureCountdownService.markDue(context)
    }

    fun getState(context: Context): Map<String, Any?> {
        val state = PostureCountdownService.getState(context)
        return mapOf(
            "scheduled" to (state["running"] == true),
            "postureType" to state["postureType"],
            "dueAtMillis" to state["dueAtMillis"],
            "startedAtMillis" to state["startedAtMillis"],
            "remainingSeconds" to state["remainingSeconds"],
            "status" to state["status"],
            "overdue" to state["overdue"],
        )
    }

    fun isRestAction(action: String?) = action == ACTION_REST

    fun isHandledAction(action: String?) = action == ACTION_HANDLED

    fun isDueAction(action: String?) = action == ACTION_ALARM_DUE

    fun messageFor(postureType: String?): Triple<String, String, Int> {
        return if (postureType == POSTURE_STANDING) {
            Triple(
                "该变换姿势了",
                "你已经连续站了一段时间，建议坐下或变换姿势。",
                303,
            )
        } else {
            Triple(
                "该活动一下了",
                "你已经连续坐了一段时间，建议起身活动一下。",
                302,
            )
        }
    }

    fun openExactAlarmSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (intent.resolveActivity(context.packageManager) == null) {
            return false
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
