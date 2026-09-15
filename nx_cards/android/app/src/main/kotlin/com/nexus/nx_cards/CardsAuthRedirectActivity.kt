package com.nexus.nx_cards

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.bdayadev.oidc.OidcPlugin

/** Returns from browsers that open authentication as an ordinary activity. */
class CardsAuthRedirectActivity : Activity() {
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
        // Keep redirect matching and state/PKCE validation in the OIDC stack.
        // Unsolicited links must not bring the main activity forward.
        if (intent?.data?.let { OidcPlugin.handleRedirect(it) } == true) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            })
        }
        finish()
    }
}
