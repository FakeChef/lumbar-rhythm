package app.lumbarhythm.lumbar_rhythm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PostureAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            PostureCountdownService.ACTION_ALARM_DUE,
            PostureCountdownService.ACTION_COMPLETE_STANDING_UP,
            PostureCountdownService.ACTION_COMPLETE_SITTING_DOWN,
            PostureCountdownService.ACTION_CANCEL,
            PostureCountdownService.ACTION_HANDLED,
            PostureCountdownService.ACTION_SNOOZE_10 -> {
                PostureCountdownService.handleAction(context, intent.action)
            }
            else -> when {
                PostureAlarmScheduler.isDueAction(intent?.action) -> {
                    PostureCountdownService.markDue(context)
                }
                PostureAlarmScheduler.isRestAction(intent?.action) ||
                    PostureAlarmScheduler.isHandledAction(intent?.action) -> {
                    PostureCountdownService.completeSession(context)
                }
            }
        }
    }
}
