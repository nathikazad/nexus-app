# Reading companion

Tap the bottom-right sparkle button while reading a book or chapter. Type a
question, or tap the microphone to start recording and tap stop to send.
Replies are text-only; there is no audio playback. Both input methods use the same backend
document transcript. The app restores the latest 60 messages when opened.

Selecting reader text opens the same highlight toolbar used by Nx Docs. A color
adds only a persistent highlight; the sparkle action opens the companion and
attaches that passage to the next typed question. Attached passages are sent as
clearly labelled reference text (up to 6,000 characters) and cleared after a
successful typed send. Recorded questions also send the attached passage to the
backend, where it is labelled as reference text alongside the transcription.
No whole-library search, note/card
mutations, live Realtime conversation, or paragraph citation navigation is
implemented in this first version. The shelf button asks the reader to open a
book so that context is explicit.

The layout button opens a bottom-left popup with compact, expanded, full-width
bottom, full-height right, and full-screen options. The trash button asks for
confirmation before clearing this document's saved transcript and local chat;
it is disabled during a turn and keeps local history if the database clear fails.
The panel stays above the keyboard and retains the
draft/conversation when closed. Closing or backgrounding the app stops active
microphone capture without sending, but allows a pending reply to finish saving.
Changing documents/accounts disconnects the conversation. Recording is
limited to 60 seconds. Network errors retain the draft; a reply times out after
90 seconds. Restored transcript roles are normalized so historical Agent
responses use the same Markdown renderer as live responses.

While a reply streams, the chat follows only until the reply's beginning reaches
the top of the viewport. Further text grows below without pushing that beginning
away. Manual scrolling pauses following for the turn.
This uses the actual viewport and reply position in every panel layout, not
fixed size thresholds. Older messages stay lazily rendered.

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
