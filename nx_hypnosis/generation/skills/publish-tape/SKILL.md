---
name: nx-hypnosis-upload
description: Upload an approved NX Hypnosis recording to the production database and private recording storage, either replacing an existing tape's audio or creating a new tape linked to a desire.
---

Use this for a user-requested upload, new tape, or replacement of an existing tape's audio. Merely generating a preview does not imply publication. An explicit upload/overwrite request is sufficient authorization for that scope; do not ask again when the recording and target are unambiguous.

## Resolve the operation

Identify the exact approved local audio from the conversation and its sidecar settings. “The one before this” means the preceding candidate, not the newest file by modification time. If ambiguous, ask before any database mutation.

- **Replace audio:** resolve the existing tape ID through the user's collection. Keep its ID, title, desire link, prompt, and story unchanged. A transcript change is separate and needs to be requested or clearly part of the replacement brief.
- **Create tape:** obtain a title, the exact spoken transcript, the creation prompt/brief, and an existing desire ID belonging to the user. Infer these from the approved conversation when possible. Never invent a historical generation prompt; label a reconstructed brief as such. Do not delete other tapes unless requested.

Read the repository's [deployment skill](../../../../../servers/skills/deploy/SKILL.md) before accessing the server. Default target is Hetzner production via `hetzner-personal`; announce it before remote commands. Resolve the live checkout, service, container, and storage configuration. Data-only uploads do not require source deployment or a restart. Preserve unrelated dirty files; never reset, stash, or deploy them. Do not access the Pi unless requested.

The established backend contract is in:

- [Hypnosis repository](../../../../../servers/nexus/hypnosis/repository.py)
- [Recording routes](../../../../../servers/nexus/http/routes/hypnosis.py)

Re-read these when carrying out the upload, since the deployed interfaces can evolve. There is currently no binary-upload HTTP endpoint; transfer the approved MP3 to a unique temporary staging directory over SSH, then use a narrowly scoped Python operation inside the running Nexus container.

## Inspect and prepare

1. Decode the complete local file with FFmpeg and obtain actual duration, MP3 codec, byte size, and SHA-256. Do not take duration from its filename or a previous version. Do not re-encode an approved MP3 as part of upload.
2. Identify the intended user from existing account context, then verify `users.person_model_id` and `personal_domain_id`. Use `nexus.hypnosis.repository.collection` to resolve desires and tapes. Never choose an arbitrary first user or hardcode IDs from a prior run.
3. For replacement, record the currently observed audio SHA-256 (including an absent value). This becomes the expected-old value checked again under the write lock. For creation, assign a unique operation token and preserve it in the local upload receipt so an uncertain result can be reconciled without creating duplicates.
4. Save a local receipt under the shared Git-ignored `../../receipts/` directory with operation, user, tape/desire, source path, checksum, duration, and intended title where applicable. Do not include credentials. Stage only the chosen MP3 and necessary metadata/transcript; do not copy `.env` or entire output folders.

## Publish atomically

Use the container's existing runtime credentials; never print or copy them. The established execution pattern is `docker exec -e PYTHONPATH=/app nexus-server /usr/local/bin/entrypoint-with-secrets nexus python <staged-script>`. Verify those names on the selected deployment before use.

Inside one `connect(user_id=resolved_user_id)` transaction:

1. Acquire `SELECT pg_advisory_xact_lock(73421,%s)` with the resolved user ID.
2. Use `require_item` to verify the existing tape or destination desire belongs to this user's Person and domain. On replacement, compare the current audio checksum to the expected-old value; stop if another operation changed it.
3. For creation, use `save(cur,user_id,'tapes',body)` with `title`, `desire_id`, `prompt`, and `story`. Record the operation token in the new model's metadata in the same transaction, preserving other metadata. On retry, first search for that token scoped to this user/domain and verify the existing result instead of creating another tape.
4. Resolve the storage directory with `nexus.http.routes.hypnosis.recording_dir()`. Name the recording `tape-<tape-id>-<sha256-first-16>.mp3`. Write a uniquely staged file as the runtime user, flush/fsync it, and atomically rename it into place before committing the database reference. If the final name already exists, reuse only after verifying its complete checksum. Do not overwrite bytes at an old recording filename.
5. Use `mutate(cur,user_id,{'id':tape_id,'attributes':[{'key':'audio','value':metadata}]})`. Metadata includes `link` (`/hypnosis/recordings/<id>`), `filename`, `sha256`, `size`, `format` (`mp3`), and measured `duration_seconds`. Add known voice ID/settings and postprocessing details from the chosen recording's sidecars; never carry over another voice's settings.
6. Re-read through `require_item` and check metadata, ownership, desire link, and unchanged fields for replacement. For creation, verify stored story and prompt against the supplied strings. The existing KGQL string writer has previously escaped newline characters: if observed, correct only the new tape's affected `attributes.value_text` using bound SQL parameters, clear its `value_json`, and re-read. Do not apply a global unescape or mutate unrelated data.

This file-first, transaction-second ordering prevents a committed tape from pointing to a missing recording. If a failure occurs, reconcile committed state before cleanup. Retain old referenced recording files until the replacement is verified; superseded files may remain for recovery. Physical deletion is not required to replace the active audio reference. Remove only this operation's temporary files or verified unreferenced artifacts.

## Verify and report

After commit, use a fresh connection to verify the collection and `load_recording(user_id,str(tape_id))`. Confirm the resolved file matches the source checksum and measured size. Verify the affected endpoint's authentication boundary; an unauthenticated 401 is expected but alone does not establish successful playback. When an authenticated app session is available, refresh its collection and verify the new recording loads. Cached clients may need to refresh/download the changed checksum.

For uncertain SSH/transaction results, inspect the tape metadata or creation token before retrying. Do not regenerate audio, blindly repeat creation, or delete a potentially committed recording.

Remove temporary staging files after verification and update the local receipt with the final tape ID, filename, checksum, and verification result. Report the tape title, duration, and whether created or replaced. State the production target and relevant verification. Do not claim listening quality or on-device playback was checked unless it actually was.

## Audio schema and playback timing

The canonical audio JSON schema lives in `servers/pgdb/core_schema/models/Digital_Nouns/hypnosis_tapes.json`, under the audio attribute’s `metadata.json_schema`; production stores it in `attribute_definitions.metadata.json_schema`. Audio is optional/null, and `audio.timeline` is optional for legacy recordings. The current database trigger warns on mismatches rather than rejecting them, so validate before publishing.

For a timed recording, load the matching `.timeline.json`, verify its `audio_sha256` and `script_sha256`, and store it inside `audio.timeline`, renaming the local `turns` array to `segments`. Each segment keeps its ID, speaker, exact spoken text, and start/end seconds. Preserve clip-end and sample offsets when supplied. Check ordered, nonoverlapping intervals, nonnegative times, end within duration, and matching audio checksum; JSON schema alone cannot enforce these relationships. Publish audio and timeline in the same transaction. When replacing with an untimed recording, omit the old timeline rather than carrying stale timings forward. If the editable story changes independently, retain the recording’s spoken-text snapshot; do not apply its timestamps to changed prose.
