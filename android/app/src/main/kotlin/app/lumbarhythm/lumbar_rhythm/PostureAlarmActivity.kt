package app.lumbarhythm.lumbar_rhythm

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class PostureAlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
        )

        val postureType = intent.getStringExtra("postureType")
        val message = PostureAlarmScheduler.messageFor(postureType)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        layout.addView(
            TextView(this).apply {
                text = message.first
                textSize = 28f
                gravity = Gravity.CENTER
            },
        )
        layout.addView(
            TextView(this).apply {
                text = message.second
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 32)
            },
        )
        layout.addView(
            Button(this).apply {
                text = "\u5df2\u5904\u7406"
                setOnClickListener {
                    PostureAlarmScheduler.markHandled(this@PostureAlarmActivity)
                    PostureCountdownService.stopCountdown(this@PostureAlarmActivity)
                    finish()
                }
            },
        )
        layout.addView(
            Button(this).apply {
                text = "\u6253\u5f00\u5e94\u7528"
                setOnClickListener { finish() }
            },
        )
        setContentView(layout)
    }
}