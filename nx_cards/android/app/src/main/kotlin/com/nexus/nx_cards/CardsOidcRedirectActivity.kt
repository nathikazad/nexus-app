package com.nexus.nx_cards

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.bdayadev.oidc.OidcPlugin

/**
 * Delivers the OIDC callback and removes the tablet browser from the app task.
 *
 * The browser bundled with some e-ink tablets leaves its custom tab in front
 * after a transparent redirect activity finishes. Returning to MainActivity
 * with NEW_TASK, CLEAR_TOP and SINGLE_TOP reuses its existing activity even when
 * Chrome delivers the redirect in a different task. This preserves the
 * Flutter engine waiting for the authorization result.
 */
class CardsOidcRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        deliver(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliver(intent)
    }

    private fun deliver(intent: Intent?) {
        val handled = intent?.data?.let(OidcPlugin::handleRedirect) == true
        if (handled) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        }
        finish()
    }
}
