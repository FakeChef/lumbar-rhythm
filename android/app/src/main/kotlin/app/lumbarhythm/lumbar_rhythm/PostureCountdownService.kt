package app.lumbarhythm.lumbar_rhythm

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.ceil
import kotlin.math.max

class PostureCountdownService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                cancelSession(this)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_REFRESH -> {
                refreshForegroundNotification()
                return START_STICKY
            }
        }

        val postureType = intent?.getStringExtra(EXTRA_POSTURE_TYPE) ?: POSTURE_SITTING
        val durationSeconds = intent?.getLongExtra(EXTRA_DURATION_SECONDS, 0L) ?: 0L
        val reminderMode = intent?.getStringExtra(EXTRA_REMINDER_MODE) ?: MODE_SOFT
        val startedAtMillis = intent?.getLongExtra(EXTRA_STARTED_AT_MILLIS, System.currentTimeMillis())
            ?: System.currentTimeMillis()

        if (durationSeconds <= 0L || !isTimedPosture(postureType)) {
            if (getActiveSession(this) != null) {
                refreshForegroundNotification()
                return START_STICKY
            }
            stopSelf()
            return START_NOT_STICKY
        }

        ensureChannels(this)
        val session = createSession(
            context = this,
            postureType = postureType,
            targetDurationMillis = durationSeconds * 1000L,
            reminderMode = reminderMode,
            startedAtMillis = startedAtMillis,
        )
        startForeground(
            ONGOING_NOTIFICATION_ID,
            buildOngoingNotification(this, session),
        )
        scheduleTick()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    private fun scheduleTick() {
        handler.removeCallbacks(tickRunnable)
        handler.post(tickRunnable)
    }

    private fun refreshForegroundNotification() {
        val session = getActiveSession(this)
        if (session == null || (session.status != STATUS_RUNNING && session.status != STATUS_DUE)) {
            stopSelf()
            return
        }
        startForeground(
            ONGOING_NOTIFICATION_ID,
            buildOngoingNotification(this, session),
        )
        scheduleTick()
    }

    private val tickRunnable = object : Runnable {
        override fun run() {
            val session = getActiveSession(this@PostureCountdownService)
            if (session == null || session.status != STATUS_RUNNING) {
                if (session == null || session.status != STATUS_DUE) {
                    stopSelf()
                }
                return
            }
            if (System.currentTimeMillis() >= session.expectedEndTimeMillis) {
                handleDue(this@PostureCountdownService)
                refreshForegroundNotification()
                return
            }
            notificationManager.notify(
                ONGOING_NOTIFICATION_ID,
                buildOngoingNotification(this@PostureCountdownService, session),
            )
            handler.postDelayed(this, TICK_INTERVAL_MILLIS)
        }
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        const val ACTION_ALARM_DUE = "app.lumbarhythm.lumbar_rhythm.REMINDER_ALARM_DUE"
        const val ACTION_COMPLETE_STANDING_UP = "app.lumbarhythm.lumbar_rhythm.REMINDER_COMPLETE_STANDING_UP"
        const val ACTION_COMPLETE_SITTING_DOWN = "app.lumbarhythm.lumbar_rhythm.REMINDER_COMPLETE_SITTING_DOWN"
        const val ACTION_CANCEL = "app.lumbarhythm.lumbar_rhythm.REMINDER_CANCEL"
        const val ACTION_HANDLED = "app.lumbarhythm.lumbar_rhythm.REMINDER_HANDLED"
        const val ACTION_SNOOZE_10 = "app.lumbarhythm.lumbar_rhythm.REMINDER_SNOOZE_10"
        private const val ACTION_STOP = "app.lumbarhythm.lumbar_rhythm.STOP_POSTURE_COUNTDOWN"
        private const val ACTION_REFRESH = "app.lumbarhythm.lumbar_rhythm.REFRESH_POSTURE_COUNTDOWN"
        private const val EXTRA_POSTURE_TYPE = "postureType"
        private const val EXTRA_DURATION_SECONDS = "durationSeconds"
        private const val EXTRA_REMINDER_MODE = "reminderMode"
        private const val EXTRA_STARTED_AT_MILLIS = "startedAtMillis"
        private const val PREFS = "posture_countdown"
        private const val COUNTDOWN_CHANNEL_ID = "lumbar_rhythm_posture_countdown"
        private const val SOFT_CHANNEL_ID = "lumbar_rhythm_soft_reminders_v2"
        private const val VIBRATION_CHANNEL_ID = "lumbar_rhythm_vibration_reminders_v2"
        private const val ALARM_CHANNEL_ID = "lumbar_rhythm_alarm_reminders_v2"
        const val POSTURE_SITTING = "sitting"
        const val POSTURE_STANDING = "standing"
        private const val MODE_SOFT = "soft"
        private const val MODE_VIBRATION = "vibration"
        private const val MODE_ALARM = "alarm"
        const val STATUS_RUNNING = "running"
        const val STATUS_DUE = "due"
        const val STATUS_COMPLETED = "completed"
        const val STATUS_CANCELLED = "cancelled"
        private const val ONGOING_NOTIFICATION_ID = 301
        private const val SITTING_DUE_NOTIFICATION_ID = 302
        private const val STANDING_DUE_NOTIFICATION_ID = 303
        private const val REQUEST_DUE_SITTING = 5101
        private const val REQUEST_DUE_STANDING = 5102
        private const val REQUEST_SNOOZE_SITTING = 5103
        private const val REQUEST_SNOOZE_STANDING = 5104
        private const val REQUEST_COMPLETE = 5110
        private const val REQUEST_CANCEL = 5111
        private const val REQUEST_HANDLED = 5112
        private const val REQUEST_SNOOZE = 5113
        private const val REQUEST_OPEN_APP = 5114
        private const val TICK_INTERVAL_MILLIS = 15_000L

        private val handler = Handler(Looper.getMainLooper())

        fun startCountdown(
            context: Context,
            postureType: String,
            durationSeconds: Long,
            reminderMode: String,
            startedAtMillis: Long,
        ) {
            getActiveSession(context)?.let { cancelAlarm(context, it) }
            clearNotifications(context)
            createSession(
                context = context,
                postureType = postureType,
                targetDurationMillis = durationSeconds * 1000L,
                reminderMode = reminderMode,
                startedAtMillis = startedAtMillis,
            )
            if (!refreshService(context)) {
                throw IllegalStateException("foreground_service_start_failed")
            }
        }

        fun startReminder(
            context: Context,
            postureType: String,
            durationSeconds: Long,
            reminderMode: String,
            startedAtMillis: Long = System.currentTimeMillis(),
        ): Map<String, Any?> {
            if (!isTimedPosture(postureType) || durationSeconds <= 0L) {
                return result(
                    success = false,
                    errorCode = "invalid_args",
                    message = "Missing reminder arguments.",
                    session = getActiveSession(context),
                    permission = permissionStatus(context),
                )
            }
            if (!notificationPermissionGranted(context)) {
                return result(
                    success = false,
                    errorCode = "notification_permission_denied",
                    message = "通知权限未开启，无法显示提醒。请先开启通知权限。",
                    session = getActiveSession(context),
                    permission = permissionStatus(context),
                )
            }
            return try {
                startCountdown(
                    context = context,
                    postureType = postureType,
                    durationSeconds = durationSeconds,
                    reminderMode = reminderMode,
                    startedAtMillis = startedAtMillis,
                )
                val session = getActiveSession(context)
                result(
                    success = session != null,
                    errorCode = if (session == null) "session_save_failed" else null,
                    message = if (session?.exactAlarmAvailable == false) {
                        "准时提醒权限未开启，提醒可能延迟。建议在设置中开启‘闹钟和提醒’权限。"
                    } else {
                        "倒计时已启动。"
                    },
                    session = session,
                    permission = permissionStatus(context),
                )
            } catch (error: Exception) {
                result(
                    success = false,
                    errorCode = "foreground_service_start_failed",
                    message = error.message ?: "Foreground service start failed.",
                    session = getActiveSession(context),
                    permission = permissionStatus(context),
                )
            }
        }

        fun stopCountdown(context: Context) {
            cancelSession(context)
        }

        fun cancelSession(context: Context): Map<String, Any?> {
            val session = getActiveSession(context)
            if (session != null) {
                cancelAlarm(context, session)
                saveSession(context, session.copy(status = STATUS_CANCELLED))
            }
            clearNotifications(context)
            context.stopService(Intent(context, PostureCountdownService::class.java))
            clearSession(context)
            return result(
                success = true,
                errorCode = null,
                message = "倒计时已取消。",
                session = null,
                permission = permissionStatus(context),
            )
        }

        fun completeSession(context: Context): Map<String, Any?> {
            val session = getActiveSession(context)
                ?: return result(
                    success = false,
                    errorCode = "no_active_session",
                    message = "没有正在进行的倒计时。",
                    session = null,
                    permission = permissionStatus(context),
                )
            cancelAlarm(context, session)
            saveSession(context, session.copy(status = STATUS_COMPLETED))
            clearNotifications(context)
            context.stopService(Intent(context, PostureCountdownService::class.java))
            clearSession(context)
            return result(
                success = true,
                errorCode = null,
                message = "倒计时已完成。",
                session = null,
                permission = permissionStatus(context),
            )
        }

        fun markDue(context: Context) {
            handleDue(context)
        }

        fun handleDue(context: Context): Map<String, Any?> {
            val session = getActiveSession(context)
                ?: return result(
                    success = false,
                    errorCode = "no_active_session",
                    message = "没有正在进行的倒计时。",
                    session = null,
                    permission = permissionStatus(context),
                )
            val now = System.currentTimeMillis()
            if (session.status == STATUS_DUE) {
                return result(
                    success = true,
                    errorCode = null,
                    message = "倒计时已到期。",
                    session = session,
                    permission = permissionStatus(context),
                )
            }
            if (now < session.expectedEndTimeMillis) {
                return result(
                    success = false,
                    errorCode = "alarm_not_due",
                    message = "倒计时尚未到期。",
                    session = session,
                    permission = permissionStatus(context),
                )
            }
            val dueSession = session.copy(status = STATUS_DUE, updatedAtMillis = now)
            saveSession(context, dueSession)
            showDueNotification(context, dueSession)
            refreshService(context)
            return result(
                success = true,
                errorCode = null,
                message = "倒计时已到期。",
                session = dueSession,
                permission = permissionStatus(context),
            )
        }

        fun snooze(context: Context, minutes: Int): Map<String, Any?> {
            val current = getActiveSession(context)
                ?: return result(
                    success = false,
                    errorCode = "no_active_session",
                    message = "没有正在进行的倒计时。",
                    session = null,
                    permission = permissionStatus(context),
                )
            val now = System.currentTimeMillis()
            val updated = current.copy(
                startTimeMillis = now,
                targetDurationMillis = minutes * 60_000L,
                expectedEndTimeMillis = now + minutes * 60_000L,
                status = STATUS_RUNNING,
                updatedAtMillis = now,
            )
            saveSession(context, updated)
            scheduleAlarm(context, updated, snooze = true)
            clearDueNotifications(context)
            if (!refreshService(context)) {
                return result(
                    success = false,
                    errorCode = "foreground_service_start_failed",
                    message = "Foreground service start failed.",
                    session = updated,
                    permission = permissionStatus(context),
                )
            }
            return result(
                success = true,
                errorCode = null,
                message = "已延后 $minutes 分钟。",
                session = getActiveSession(context),
                permission = permissionStatus(context),
            )
        }

        fun getState(context: Context): Map<String, Any?> {
            val session = getActiveSession(context)
            return mapOf(
                "running" to (session?.status == STATUS_RUNNING),
                "postureType" to session?.type,
                "remainingSeconds" to session?.remainingSeconds(),
                "dueAtMillis" to session?.expectedEndTimeMillis,
                "startedAtMillis" to session?.startTimeMillis,
                "status" to session?.status,
                "overdue" to (session?.isDue(System.currentTimeMillis()) ?: false),
            )
        }

        fun getActiveReminderSession(context: Context): Map<String, Any?> {
            val session = getActiveSession(context)
            return result(
                success = true,
                errorCode = null,
                message = null,
                session = session,
                permission = permissionStatus(context),
            )
        }

        fun getReminderPermissionStatus(context: Context): Map<String, Any?> {
            return mapOf(
                "notificationGranted" to notificationPermissionGranted(context),
                "exactAlarmAvailable" to exactAlarmAvailable(context),
                "sdkInt" to Build.VERSION.SDK_INT,
            )
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                return
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    COUNTDOWN_CHANNEL_ID,
                    "坐站倒计时",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "手动坐姿或站姿倒计时运行中的常驻通知"
                    setSound(null, null)
                    enableVibration(false)
                },
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    SOFT_CHANNEL_ID,
                    "轻柔坐站提醒",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    VIBRATION_CHANNEL_ID,
                    "震动坐站提醒",
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
                    "响铃坐站提醒",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 450, 180, 450)
                },
            )
        }

        fun handleAction(context: Context, action: String?) {
            when (action) {
                ACTION_COMPLETE_STANDING_UP,
                ACTION_COMPLETE_SITTING_DOWN,
                ACTION_HANDLED -> completeSession(context)
                ACTION_CANCEL -> cancelSession(context)
                ACTION_SNOOZE_10 -> snooze(context, 10)
                ACTION_ALARM_DUE -> handleDue(context)
            }
        }

        private fun createSession(
            context: Context,
            postureType: String,
            targetDurationMillis: Long,
            reminderMode: String,
            startedAtMillis: Long,
        ): ReminderSession {
            val exact = exactAlarmAvailable(context)
            val now = System.currentTimeMillis()
            val session = ReminderSession(
                hasActiveSession = true,
                type = postureType,
                startTimeMillis = startedAtMillis,
                targetDurationMillis = targetDurationMillis,
                expectedEndTimeMillis = startedAtMillis + targetDurationMillis,
                status = STATUS_RUNNING,
                exactAlarmAvailable = exact,
                notificationPermissionGranted = notificationPermissionGranted(context),
                reminderMode = reminderMode,
                createdAtMillis = now,
                updatedAtMillis = now,
            )
            saveSession(context, session)
            scheduleAlarm(context, session, snooze = false)
            return session
        }

        private fun scheduleAlarm(context: Context, session: ReminderSession, snooze: Boolean): Boolean {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = alarmIntent(context, session, snooze)
            return try {
                if (session.exactAlarmAvailable) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        session.expectedEndTimeMillis,
                        pendingIntent,
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        session.expectedEndTimeMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        session.expectedEndTimeMillis,
                        pendingIntent,
                    )
                }
                true
            } catch (_: Exception) {
                false
            }
        }

        private fun cancelAlarm(context: Context, session: ReminderSession) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(alarmIntent(context, session, snooze = false))
            alarmManager.cancel(alarmIntent(context, session, snooze = true))
        }

        private fun alarmIntent(context: Context, session: ReminderSession, snooze: Boolean): PendingIntent {
            val requestCode = when {
                snooze && session.type == POSTURE_STANDING -> REQUEST_SNOOZE_STANDING
                snooze -> REQUEST_SNOOZE_SITTING
                session.type == POSTURE_STANDING -> REQUEST_DUE_STANDING
                else -> REQUEST_DUE_SITTING
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, PostureAlarmReceiver::class.java).apply {
                    action = ACTION_ALARM_DUE
                    putExtra(EXTRA_POSTURE_TYPE, session.type)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun buildOngoingNotification(context: Context, session: ReminderSession) =
            NotificationCompat.Builder(context, COUNTDOWN_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notification)
                .setContentTitle(ongoingTitle(session))
                .setContentText(ongoingText(session))
                .setStyle(NotificationCompat.BigTextStyle().bigText(ongoingText(session)))
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(openAppIntent(context))
                .addAction(
                    0,
                    if (session.type == POSTURE_STANDING) "我已坐下" else "我已起身",
                    actionIntent(
                        context,
                        if (session.type == POSTURE_STANDING) ACTION_COMPLETE_SITTING_DOWN else ACTION_COMPLETE_STANDING_UP,
                        REQUEST_COMPLETE,
                    ),
                )
                .addAction(0, "取消提醒", actionIntent(context, ACTION_CANCEL, REQUEST_CANCEL))
                .build()

        private fun showDueNotification(context: Context, session: ReminderSession) {
            ensureChannels(context)
            val isStanding = session.type == POSTURE_STANDING
            val title = if (isStanding) "该变换姿势了" else "该活动一下了"
            val minutes = max(1, session.targetDurationMillis / 60_000L)
            val body = if (isStanding) {
                "你已经连续站了约 $minutes 分钟，建议坐下或变换姿势。"
            } else {
                "你已经连续坐了约 $minutes 分钟，建议起身活动一下。"
            }
            val id = if (isStanding) STANDING_DUE_NOTIFICATION_ID else SITTING_DUE_NOTIFICATION_ID
            val notification = NotificationCompat.Builder(context, reminderChannelId(session.reminderMode))
                .setSmallIcon(R.drawable.ic_stat_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(false)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setContentIntent(openAppIntent(context))
                .addAction(0, "我已处理", actionIntent(context, ACTION_HANDLED, REQUEST_HANDLED))
                .addAction(0, "延后 10 分钟", actionIntent(context, ACTION_SNOOZE_10, REQUEST_SNOOZE))
                .build()
            NotificationManagerCompat.from(context).notify(id, notification)
        }

        private fun countdownText(session: ReminderSession): String {
            val remainingMillis = max(0L, session.expectedEndTimeMillis - System.currentTimeMillis())
            val minutes = max(1, ceil(remainingMillis / 60000.0).toInt())
            val prefix = if (session.type == POSTURE_STANDING) "久站倒计时中" else "久坐倒计时中"
            val suffix = if (session.exactAlarmAvailable) "" else "。准时提醒权限未开启，可能延迟"
            return "$prefix，剩余 $minutes 分钟$suffix"
        }

        private fun ongoingTitle(session: ReminderSession): String {
            return if (session.status == STATUS_DUE) {
                if (session.type == POSTURE_STANDING) "久站提醒已到期" else "久坐提醒已到期"
            } else if (session.type == POSTURE_STANDING) {
                "久站倒计时"
            } else {
                "久坐倒计时"
            }
        }

        private fun ongoingText(session: ReminderSession): String {
            if (session.status != STATUS_DUE) {
                return countdownText(session)
            }
            return if (session.type == POSTURE_STANDING) {
                "久站已到提醒时间，建议现在变换姿势。"
            } else {
                "久坐已到提醒时间，建议现在活动一下。"
            }
        }

        private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, PostureAlarmReceiver::class.java).apply {
                    this.action = action
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            return PendingIntent.getActivity(
                context,
                REQUEST_OPEN_APP,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun clearNotifications(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(ONGOING_NOTIFICATION_ID)
            manager.cancel(SITTING_DUE_NOTIFICATION_ID)
            manager.cancel(STANDING_DUE_NOTIFICATION_ID)
        }

        private fun clearDueNotifications(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(SITTING_DUE_NOTIFICATION_ID)
            manager.cancel(STANDING_DUE_NOTIFICATION_ID)
        }

        private fun refreshService(context: Context): Boolean {
            val intent = Intent(context, PostureCountdownService::class.java).apply {
                action = ACTION_REFRESH
            }
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (_: Exception) {
                // The high-priority due notification remains visible even if the
                // system refuses to restart the foreground service from background.
                false
            }
        }

        private fun reminderChannelId(reminderMode: String): String {
            return when (reminderMode) {
                MODE_VIBRATION -> VIBRATION_CHANNEL_ID
                MODE_ALARM -> ALARM_CHANNEL_ID
                else -> SOFT_CHANNEL_ID
            }
        }

        private fun isTimedPosture(postureType: String?) =
            postureType == POSTURE_SITTING || postureType == POSTURE_STANDING

        private fun notificationPermissionGranted(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return true
            }
            return context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        }

        private fun exactAlarmAvailable(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                return true
            }
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }

        private fun permissionStatus(context: Context): Map<String, Any?> {
            return mapOf(
                "notificationGranted" to notificationPermissionGranted(context),
                "exactAlarmAvailable" to exactAlarmAvailable(context),
                "sdkInt" to Build.VERSION.SDK_INT,
            )
        }

        private fun result(
            success: Boolean,
            errorCode: String?,
            message: String?,
            session: ReminderSession?,
            permission: Map<String, Any?>,
        ): Map<String, Any?> {
            return mapOf(
                "success" to success,
                "errorCode" to errorCode,
                "code" to (errorCode ?: "ok"),
                "message" to message,
                "session" to session?.toMap(),
                "permission" to permission,
                "dueAtMillis" to session?.expectedEndTimeMillis,
                "mode" to when {
                    !success || session == null -> "none"
                    session.exactAlarmAvailable -> "foregroundExact"
                    else -> "foregroundInexact"
                },
            )
        }

        private fun getActiveSession(context: Context): ReminderSession? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean("hasActiveSession", false)) {
                return null
            }
            val type = prefs.getString("type", null) ?: return null
            val status = prefs.getString("status", STATUS_CANCELLED) ?: STATUS_CANCELLED
            return ReminderSession(
                hasActiveSession = true,
                type = type,
                startTimeMillis = prefs.getLong("startTimeMillis", 0L),
                targetDurationMillis = prefs.getLong("targetDurationMillis", 0L),
                expectedEndTimeMillis = prefs.getLong("expectedEndTimeMillis", 0L),
                status = status,
                exactAlarmAvailable = prefs.getBoolean("exactAlarmAvailable", false),
                notificationPermissionGranted = prefs.getBoolean("notificationPermissionGranted", false),
                reminderMode = prefs.getString("reminderMode", MODE_SOFT) ?: MODE_SOFT,
                createdAtMillis = prefs.getLong("createdAtMillis", 0L),
                updatedAtMillis = prefs.getLong("updatedAtMillis", 0L),
            )
        }

        private fun saveSession(context: Context, session: ReminderSession) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("hasActiveSession", session.hasActiveSession)
                .putString("type", session.type)
                .putLong("startTimeMillis", session.startTimeMillis)
                .putLong("targetDurationMillis", session.targetDurationMillis)
                .putLong("expectedEndTimeMillis", session.expectedEndTimeMillis)
                .putString("status", session.status)
                .putBoolean("exactAlarmAvailable", session.exactAlarmAvailable)
                .putBoolean("notificationPermissionGranted", session.notificationPermissionGranted)
                .putString("reminderMode", session.reminderMode)
                .putLong("createdAtMillis", session.createdAtMillis)
                .putLong("updatedAtMillis", session.updatedAtMillis)
                .apply()
        }

        private fun clearSession(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        }
    }
}

data class ReminderSession(
    val hasActiveSession: Boolean,
    val type: String,
    val startTimeMillis: Long,
    val targetDurationMillis: Long,
    val expectedEndTimeMillis: Long,
    val status: String,
    val exactAlarmAvailable: Boolean,
    val notificationPermissionGranted: Boolean,
    val reminderMode: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
) {
    fun remainingSeconds(now: Long = System.currentTimeMillis()): Int {
        return max(0L, (expectedEndTimeMillis - now) / 1000L).toInt()
    }

    fun isDue(now: Long): Boolean {
        return status == PostureCountdownService.STATUS_DUE ||
            (status == PostureCountdownService.STATUS_RUNNING && now >= expectedEndTimeMillis)
    }

    fun toMap(): Map<String, Any?> {
        val now = System.currentTimeMillis()
        return mapOf(
            "hasActiveSession" to hasActiveSession,
            "type" to type,
            "postureType" to type,
            "startTimeMillis" to startTimeMillis,
            "startedAtMillis" to startTimeMillis,
            "targetDurationMillis" to targetDurationMillis,
            "expectedEndTimeMillis" to expectedEndTimeMillis,
            "dueAtMillis" to expectedEndTimeMillis,
            "status" to if (isDue(now)) PostureCountdownService.STATUS_DUE else status,
            "running" to (status == PostureCountdownService.STATUS_RUNNING && now < expectedEndTimeMillis),
            "remainingSeconds" to remainingSeconds(now),
            "remainingMillis" to max(0L, expectedEndTimeMillis - now),
            "exactAlarmAvailable" to exactAlarmAvailable,
            "notificationPermissionGranted" to notificationPermissionGranted,
            "createdAtMillis" to createdAtMillis,
            "updatedAtMillis" to updatedAtMillis,
        )
    }
}
