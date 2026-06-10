package app.lumbarhythm.lumbar_rhythm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PostureAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when {
            PostureAlarmScheduler.isDueAction(intent?.action) -> {
                PostureAlarmScheduler.onAlarmDue(context)
                PostureCountdownService.markDue(context)
            }
            PostureAlarmScheduler.isRestAction(intent?.action) ||
                PostureAlarmScheduler.isHandledAction(intent?.action) -> {
                PostureAlarmScheduler.markHandled(context)
                PostureCountdownService.stopCountdown(context)
            }
        }
    }
}
