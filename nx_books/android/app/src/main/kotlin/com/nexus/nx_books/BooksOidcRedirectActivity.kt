package com.nexus.nx_books

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.bdayadev.oidc.OidcPlugin

/**
 * Delivers the OIDC callback and removes the tablet browser from the app task.
 *
 * The browser bundled with some e-ink tablets leaves its custom tab in front
 * after a transparent redirect activity finishes. Returning to MainActivity
 * with CLEAR_TOP preserves the waiting Flutter activity while closing that
 * browser activity.
 */
class BooksOidcRedirectActivity : Activity() {
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
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        }
        finish()
    }
}
