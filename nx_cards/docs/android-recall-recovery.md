# Android recall input diagnostics and recovery

The recorder retains up to one minute / 2,048 bounded events, a recent snapshot,
the preceding session, and five incident captures under the app's external files
`input-diagnostics` directory. It records no card text, audio bytes, or pen
coordinates. File writes run on a worker; pen moves only update counters.

Two heartbeats distinguish synchronous queue starvation from a UI thread that
cannot execute even asynchronous messages. A single Choreographer probe is
requested only when input or synchronous work appears stuck. Reflection of
ViewRoot input fields is read-only and best-effort; missing fields are not proof
of failure. Android's own error-state API is also checked off the UI thread,
for this process only. A new ANR is remembered even if its app-side queue looks
empty. Each recreated window starts with the current ANR generation, preventing
an old report from immediately triggering another recovery.

Recovery requires sustained evidence (six seconds after the blocked condition),
a responsive UI thread, window focus, and no pending save, card transition,
ink edit, exit, or modal confirmation. A quiet page alone is not evidence.
One automatic recreation is allowed per native session. A subsequent incident
offers standard drawing in a separate dialog; it never starts a restart loop.
Declining the offer does not repeatedly prompt on the same screen.

Activity recreation keeps the prepared queue, current index, reveal/timestamp,
answer visibility, and last completed-stroke checkpoint in memory. The existing
Flutter session and durable review writes are not restarted or replayed. Strokes
are captured after pen-up, normalized for restoring across renderers, and updated
on undo/erase. Recovery uses the cached checkpoint, not a call into potentially
stalled pen firmware. This is in-process recovery, not a process-death restore.
The last unfinished or not-yet-checkpointed stroke may be lost. A fully blocked
UI thread cannot be safely restarted by this mechanism; diagnostics still run.

Relevant Android contracts:
- https://developer.android.com/reference/android/os/Handler#createAsync(android.os.Looper)
- https://developer.android.com/reference/android/app/Activity#recreate()
- https://developer.android.com/reference/android/app/ActivityManager#getProcessesInErrorState()

## Verification before device rollout

Run `:app:testDebugUnitTest` from `android/` with the configured JDK. Tests cover
idle/hidden screens, frame probe evidence, system ANRs with empty app queues,
transient stalls, save gating, the one-restart budget, and detached completed
stroke checkpoints. Build the release APK with the app's usual Dart defines.

On the tablet, verify normal writing, erasing, undo, reveal, grading, and opening
card details first. For a real incident, capture logcat, `dumpsys activity lastanr`,
`dumpsys input`, Dropbox ANR traces and the recorder directory before restarting.
Confirm `recovery_begin` / `recovery_complete` preserve card/reveal position and
that the next grade produces exactly one history entry. For a repeat incident,
verify the standard-renderer offer and restored drawing. Device behavior remains
unverified until the new APK is installed and exercised; unit tests cannot
simulate the tablet firmware or Android's input dispatcher.

## Targeted follow-up after the October 9 ANR

Each snapshot identifies its process and anchors wall time, uptime (excludes
sleep), and elapsed realtime (includes sleep). A worker records power-state
transitions and measured suspend time, including while the UI cannot respond.
This distinguishes a tablet suspend/wake from a main-thread queue stall. Resume
records the window's keep-screen-on flag. Standby near the last ANR is a lead,
not an established cause.

Two-second UI samples summarize delivered MOVE count, dispatch depth, maximum
input age at delivery and maximum dispatch duration. No per-MOVE log or disk
write is added. Read-only receiver/batching fields remain best-effort. These
counts describe app delivery; only a contemporaneous `dumpsys input` capture
shows Android's unacknowledged event queue. Three watchdog stack samples remain
in the bounded recorder. A newly detected system ANR always gets an incident
file, even if a UI-stall capture was written in the preceding fifteen seconds.

Recovery logs explain save/edit/modal/focus gates. Focus remains required:
Android's ANR dialog can prevent automatic recovery, and we do not recreate a
window over another app. Pressing Close kills the process; its subsequent launch
must not be interpreted as successful automatic recovery. Incident files survive
that restart. Capture them before repeated launches overwrite recent snapshots.
