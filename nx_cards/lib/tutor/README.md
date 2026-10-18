# Tutor

Tutor conducts a prepared study session through `nx_live_agent`. The live-agent
transport and audio mechanics stay behind this capability; card selection and
review scheduling remain owned by `study/` and `scheduling/`.

## Voice timeline capture

Build with `--dart-define=NX_CARDS_VOICE_TRACE=true` to print `NxVoiceTrace`
JSON records in debug or release. Off by default. This captures learner/model
text and tool arguments/results, but not raw audio, credentials or session
configuration. Collect stdout while reproducing; these logs are not stored on
the phone. For a release build, launch via `devicectl ... process launch
--terminate-existing --console` and redirect the console to a workspace log.

Each line is an envelope with session_id, seq, part, parts and fragment. Group
by session_id/seq, concatenate fragments in part order, then JSON-decode the
record. Every record has UTC, monotonic elapsed_us, current card ID/visit,
session and visit counters. wire_receive includes text deltas, final transcripts,
speech boundaries with server audio offsets, response generation boundaries,
playback notifications and function calls. tool_started/completed/failed bracket
actual application tool execution. send_attempt/send_completed distinguish
requested transport writes from successful writes.

`origin_card_visit` correlates response/item IDs to their first observed visit;
a response can confirm one card and ask the next, so it is not proof of which
word was audible. Visit counters count events observed during that visit.
Speech stops, response completions and playback stops are separate counters,
not interchangeable definitions of a turn. Duplicates with the same semantic
ID do not increment counters. `response.done` can precede speaker completion.

Times are client event-arrival times. WebRTC carries media separately; this
path does not expose raw PCM frames or exact physical speaker timing. Playback
notifications and periodic RTP sample/energy/jitter/buffer statistics provide
proxies, not a recording of what the learner actually heard.
