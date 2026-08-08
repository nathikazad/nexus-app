# Live Agent Burner

A disposable Flutter app for validating the shared `nx_live_agent` stack before
using it for card reviews.

It validates:

- OpenAI Realtime speech over WebRTC
- continued microphone and audio operation while the app is backgrounded
- spoken barge-in while the assistant is responding
- explicit response cancellation
- generic function-tool dispatch
- live weather lookup through Open-Meteo
- secure random-integer generation on the device

## Run

Run normally and paste a key into the session-only field:

```sh
flutter run
```

Or inject a key at build time without adding a source file:

```sh
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

The in-app field is cleared when the session starts and is never persisted.

## Manual acceptance test

1. Start the voice session and allow microphone access.
2. Say “give me a random number between 10 and 20.” Confirm the tool log.
3. Say “what is the weather in Kochi, India?” Confirm the Open-Meteo result in
   the log.
4. Ask for a long explanation and speak over the assistant. Confirm it stops and
   answers the interruption; the barge-in count should increase.
5. Lock the phone or switch apps and repeat steps 2 and 3 by voice.
6. Return to the app and confirm the transcript and lifecycle/tool log continued.
