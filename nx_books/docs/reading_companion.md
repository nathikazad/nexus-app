# Reading companion

Tap the bottom-right sparkle button while reading a book or chapter. Type a
question, or hold the microphone and release to send a recorded question.
Enable the speaker to hear replies. Both input methods use the same backend
document transcript. The app restores the latest 60 messages when opened.

Text questions can include a selected passage (up to 6,000 characters). Voice
questions use the current document context. No whole-library search, note/card
mutations, live Realtime conversation, or paragraph citation navigation is
implemented in this first version. The shelf button asks the reader to open a
book so that context is explicit.

The panel expands, stays above the keyboard, and retains the draft/conversation
when closed. Closing, changing documents/accounts, or backgrounding the app
stops microphone capture and playback. Recording is limited to 60 seconds.
Network errors retain the draft; a reply times out after 90 seconds.

## Deployment order

Deploy the server changes first: `nexus/socket/agents/nx_books.py`, agent routing,
and the Book fallbacks in reference-context and transcript resolution. The
mobile client requests `X-Agent-Id: nx_books` with authenticated headers and
`X-Document-Id`. Do not install against an older server: unknown agent IDs on
that server fall back to its default assistant.

Then build/install the Android release. Microphone permission is requested only
when recording starts. This version targets Android tablets; Apple microphone
entitlements/permission descriptions and desktop plugin setup still need work
before shipping voice there.

The reusable document socket session lives in `nx_voice`. Nx Docs retains its
existing names through type aliases, and its connection tests exercise the same
implementation. Backend credentials and model calls remain server-owned.
