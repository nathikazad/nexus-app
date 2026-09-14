# NX Voice

## Background recording playback

`background_audio.dart` exports `NxBackgroundAudioPlayer` for apps using
`just_audio`, alongside `NxStoredAudioRemoteControls`. Initialize once at startup
with the app's Android notification channel, then call `prepare` with each track's
ID/title/album. Apps select their source and use `player` for playback; the shared
bridge owns audio-session configuration and updates system controls. Stop/dispose
unbinds controls only when this player still owns them. The existing
`NxStoredAudioPlayer` uses the same remote-control handler.

Consuming iOS apps must enable background audio. Android apps must declare
AudioService's service/receiver/foreground permissions and use its activity.
These native integration changes require a new release, not an OTA Dart patch.
