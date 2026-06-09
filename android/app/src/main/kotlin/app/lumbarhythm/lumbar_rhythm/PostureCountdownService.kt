package app.lumbarhythm.lumbar_rhythm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlin.math.ceil
import kotlin.math.max

class PostureCountdownService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCountdown(this)
            stopSelf()
            return START_NOT_STICKY
        }

        val postureType = intent?.getStringExtra(EXTRA_POSTURE_TYPE) ?: POSTURE_SITTING
        val durationSeconds = intent?.getLongExtra(EXTRA_DURATION_SECONDS, 0L) ?: 0L
        val reminderMode = intent?.getStringExtra(EXTRA_REMINDER_MODE) ?: MODE_SOFT
        val startedAtMillis = intent?.getLongExtra(EXTRA_STARTED_AT_MILLIS, System.currentTimeMillis())
            ?: System.currentTimeMillis()
        val dueAtMillis = startedAtMillis + durationSeconds * 1000L

        saveState(
            context = this,
            running = true,
            postureType = postureType,
            startedAtMillis = startedAtMillis,
            dueAtMillis = dueAtMillis,
            reminderMode = reminderMode,
            reminderShown = false,
        )

        ensureChannels(this)
        startForeground(ONGOING_NOTIFICATION_ID, buildOngoingNotification(postureType, dueAtMillis))
        scheduleTick()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    private fun scheduleTick() {
        handler.removeCallbacks(tickRunnable)
        handler.post(tickRunnable)
    }

    private val tickRunnable = object : Runnable {
        override fun run() {
            val state = readState(this@PostureCountdownService)
            if (!state.running || state.postureType == null || state.dueAtMillis == null) {
                stopSelf()
                return
            }

            val now = System.currentTimeMillis()
            if (now >= state.dueAtMillis) {
                if (!state.reminderShown) {
                    showDueNotification(state.postureType, state.reminderMode)
                    saveState(
                        context = this@PostureCountdownService,
                        running = false,
                        postureType = state.postureType,
                        startedAtMillis = state.startedAtMillis,
                        dueAtMillis = state.dueAtMillis,
                        reminderMode = state.reminderMode,
                        reminderShown = true,
                    )
                }
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return
            }

            notificationManager.notify(
                ONGOING_NOTIFICATION_ID,
                buildOngoingNotification(state.postureType, state.dueAtMillis),
            )
            handler.postDelayed(this, TICK_INTERVAL_MILLIS)
        }
    }

    private fun buildOngoingNotification(postureType: String, dueAtMillis: Long) =
        NotificationCompat.Builder(this, COUNTDOWN_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(if (postureType == POSTURE_STANDING) "久站倒计时" else "久坐倒计时")
            .setContentText(countdownText(postureType, dueAtMillis))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppIntent())
            .build()

    private fun countdownText(postureType: String, dueAtMillis: Long): String {
        val remainingMillis = max(0L, dueAtMillis - System.currentTimeMillis())
        val minutes = max(1, ceil(remainingMillis / 60000.0).toInt())
        return if (postureType == POSTURE_STANDING) {
            "久站倒计时中，剩余 $minutes 分钟"
        } else {
            "久坐倒计时中，剩余 $minutes 分钟"
        }
    }

    private fun showDueNotification(postureType: String, reminderMode: String) {
        val (title, body, id) = if (postureType == POSTURE_STANDING) {
            Triple("该变换姿势了", "已经连续站了一段时间，建议坐下或走动放松一下。", STANDING_DUE_NOTIFICATION_ID)
        } else {
            Triple("该活动一下了", "已经连续坐了一段时间，建议起身活动一下。", SITTING_DUE_NOTIFICATION_ID)
        }
        val channelId = reminderChannelId(reminderMode)
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openAppIntent())
            .build()
        notificationManager.notify(id, notification)
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        private const val ACTION_STOP = "app.lumbarhythm.lumbar_rhythm.STOP_POSTURE_COUNTDOWN"
        private const val EXTRA_POSTURE_TYPE = "postureType"
        private const val EXTRA_DURATION_SECONDS = "durationSeconds"
        private const val EXTRA_REMINDER_MODE = "reminderMode"
        private const val EXTRA_STARTED_AT_MILLIS = "startedAtMillis"
        private const val TICK_INTERVAL_MILLIS = 15_000L
        private const val PREFS = "posture_countdown"
        private const val COUNTDOWN_CHANNEL_ID = "lumbar_rhythm_posture_countdown"
        private const val SOFT_CHANNEL_ID = "lumbar_rhythm_soft_reminders_v2"
        private const val VIBRATION_CHANNEL_ID = "lumbar_rhythm_vibration_reminders_v2"
        private const val ALARM_CHANNEL_ID = "lumbar_rhythm_alarm_reminders_v2"
        private const val POSTURE_SITTING = "sitting"
        private const val POSTURE_STANDING = "standing"
        private const val MODE_SOFT = "soft"
        private const val MODE_VIBRATION = "vibration"
        private const val MODE_ALARM = "alarm"
        private const val ONGOING_NOTIFICATION_ID = 301
        private const val SITTING_DUE_NOTIFICATION_ID = 101
        private const val STANDING_DUE_NOTIFICATION_ID = 102

        private val handler = Handler(Looper.getMainLooper())

        fun startCountdown(
            context: Context,
            postureType: String,
            durationSeconds: Long,
            reminderMode: String,
            startedAtMillis: Long,
        ) {
            val intent = Intent(context, PostureCountdownService::class.java).apply {
                putExtra(EXTRA_POSTURE_TYPE, postureType)
                putExtra(EXTRA_DURATION_SECONDS, durationSeconds)
                putExtra(EXTRA_REMINDER_MODE, reminderMode)
                putExtra(EXTRA_STARTED_AT_MILLIS, startedAtMillis)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopCountdown(context: Context) {
            val current = readState(context)
            saveState(
                context = context,
                running = false,
                postureType = current.postureType,
                startedAtMillis = current.startedAtMillis,
                dueAtMillis = current.dueAtMillis,
                reminderMode = current.reminderMode,
                reminderShown = current.reminderShown,
            )
            val intent = Intent(context, PostureCountdownService::class.java).apply {
                action = ACTION_STOP
            }
            context.stopService(intent)
        }

        fun getState(context: Context): Map<String, Any?> {
            val state = readState(context)
            val remainingSeconds = if (state.running && state.dueAtMillis != null) {
                max(0L, (state.dueAtMillis - System.currentTimeMillis()) / 1000L).toInt()
            } else {
                0
            }
            return mapOf(
                "running" to state.running,
                "postureType" to state.postureType,
                "remainingSeconds" to remainingSeconds,
                "dueAtMillis" to state.dueAtMillis,
                "startedAtMillis" to state.startedAtMillis,
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

        private fun reminderChannelId(reminderMode: String): String {
            return when (reminderMode) {
                MODE_VIBRATION -> VIBRATION_CHANNEL_ID
                MODE_ALARM -> ALARM_CHANNEL_ID
                else -> SOFT_CHANNEL_ID
            }
        }

        private fun readState(context: Context): CountdownState {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val postureType = prefs.getString(EXTRA_POSTURE_TYPE, null)
            val startedAtMillis = prefs.getLong(EXTRA_STARTED_AT_MILLIS, 0L)
                .takeIf { it > 0L }
            val dueAtMillis = prefs.getLong("dueAtMillis", 0L).takeIf { it > 0L }
            return CountdownState(
                running = prefs.getBoolean("running", false),
                postureType = postureType,
                startedAtMillis = startedAtMillis,
                dueAtMillis = dueAtMillis,
                reminderMode = prefs.getString(EXTRA_REMINDER_MODE, MODE_SOFT) ?: MODE_SOFT,
                reminderShown = prefs.getBoolean("reminderShown", false),
            )
        }

        private fun saveState(
            context: Context,
            running: Boolean,
            postureType: String?,
            startedAtMillis: Long?,
            dueAtMillis: Long?,
            reminderMode: String,
            reminderShown: Boolean,
        ) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("running", running)
                .putString(EXTRA_POSTURE_TYPE, postureType)
                .putLong(EXTRA_STARTED_AT_MILLIS, startedAtMillis ?: 0L)
                .putLong("dueAtMillis", dueAtMillis ?: 0L)
                .putString(EXTRA_REMINDER_MODE, reminderMode)
                .putBoolean("reminderShown", reminderShown)
                .apply()
        }
    }
}

data class CountdownState(
    val running: Boolean,
    val postureType: String?,
    val startedAtMillis: Long?,
    val dueAtMillis: Long?,
    val reminderMode: String,
    val reminderShown: Boolean,
)
