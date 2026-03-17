package com.quickpost.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            finish()
            return
        }

        if (Intent.ACTION_SEND == intent.action || Intent.ACTION_SEND_MULTIPLE == intent.action) {
            val componentName = intent.component?.className ?: ""
            val sharePurpose = when {
                componentName.endsWith("ShareToCropper") -> "cropper"
                componentName.endsWith("ShareToVideoCropper") -> "video_cropper"
                componentName.endsWith("ShareToTextBox") -> "text_box"
                componentName.endsWith("ShareToPostMakerTemplates") -> "post_maker_templates"
                else -> "automation"
            }

            val mainIntent = Intent(this, MainActivity::class.java).apply {
                action = intent.action
                type = intent.type
                intent.extras?.let { putExtras(it) }
                putExtra("share_purpose", sharePurpose)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(mainIntent)
        }
        finish()
    }
}
