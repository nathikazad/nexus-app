# Pi Audio Turnkey Log Check

This is a runbook for investigating a failed audio interaction when given a
turnkey such as `8:5` or `12:4`. The goal is to quickly answer:

- Did the device capture audio?
- Did nRF53 receive Opus from ESP32?
- Did `nx_main` receive it over BLE?
- Did `nx_main` forward it to MCP over WebSocket?
- If it reached the logs but not live audio, did it arrive via HTTP telemetry?

## 1. SSH Into The Pi

Use the local SSH alias first:

```sh
ssh pi
```

The current working alias is defined in `~/.ssh/config` as:

```sshconfig
Host pi
  HostName 10.0.0.156
  User nathik
```

There is also a Tailscale fallback:

```sh
ssh pi-tailscale
```

Quick sanity check:

```sh
ssh pi 'hostname; date; docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}"'
```

Expected containers include:

- `nexus-mcp`
- `nexus-graphql`
- `nexus-postgres`

## 2. Search A Turnkey In The Logs Table

The durable log source is Postgres, table `logs`, inside `nexus-postgres`.
Use exact turnkey matching against both top-level app payloads and firmware
telemetry JSON.

Replace `TURNKEY` below with the value you were given, for example `8:5`.

```sh
TURNKEY='8:5'
ssh pi "docker exec nexus-postgres psql -U postgres -d nexus_db -P pager=off -c \"
select
  id,
  to_char(time, 'YYYY-MM-DD HH24:MI:SS.MS TZ') as time,
  origin_kind,
  origin,
  severity,
  event_name,
  category,
  message,
  payload->>'turnkey' as payload_turnkey,
  payload->'upload' as upload
from logs
where
  payload::text like '%\\\"turnkey\\\": \\\"${TURNKEY}\\\"%'
  or payload::text like '%\\\"turnkey\\\":\\\"${TURNKEY}\\\"%'
  or message like '%turnkey=${TURNKEY}%'
order by time, id;
\""
```

What to look for:

- `firmware / nrf53 / turn_start_sent`: nRF detected the button and started a turn.
- `firmware / esp32 / mic_record_start`: ESP32 started recording.
- `firmware / esp32 / opus_packets_sent`: ESP32 encoded and sent Opus.
- `firmware / nrf53 / esp32_opus_received_summary`: nRF received Opus from ESP32.
- `firmware / nrf53 / nx_opus_sent_summary`: nRF sent Opus to `nx_main`.
- `app / nx_main / nrf_opus_reception_summary`: `nx_main` received Opus over BLE.
- `server / mcp / audio_received_summary`: MCP received live Opus over WebSocket.
- `server / mcp / audio_input_summary`: MCP decoded the Opus.
- `server / mcp / stt_transcript`: STT produced text.

If you see the firmware and `nx_main` rows but no `server / mcp` rows, the
device path worked and the failure is between `nx_main` and MCP, usually the
WebSocket session was missing or closed.

## 3. Get A Time Window Around The Turnkey

Once you find the matching rows, take the first and last timestamps and query
nearby context. Adjust the window as needed.

```sh
ssh pi "docker exec nexus-postgres psql -U postgres -d nexus_db -P pager=off -c \"
select
  id,
  to_char(time, 'YYYY-MM-DD HH24:MI:SS.MS TZ') as time,
  origin_kind,
  origin,
  event_name,
  category,
  message,
  payload->>'turnkey' as turnkey,
  payload->>'order_id' as order_id,
  payload->>'opus_packets' as opus_packets,
  payload->>'opus_bytes' as opus_bytes
from logs
where time between '2026-05-23 00:15:45+00' and '2026-05-23 00:16:20+00'
order by time, id;
\""
```

Use this to compare the target turn against nearby successful turns. A healthy
live path has `nx_main sent ...`, `mcp received ...`, transcript, agent logs,
and output audio.

## 4. Check MCP Docker Logs For WebSocket State

The live WebSocket server logs are in the `nexus-mcp` container. Docker stdout
is useful for connection open/close and order state.

```sh
ssh pi 'docker logs --since "2026-05-23T00:10:00Z" --until "2026-05-23T00:25:00Z" nexus-mcp 2>&1 | grep -E "ws |websocket|audio received|order|nx_main|nx_time"'
```

Useful lines:

- `[ws open] ... client_app=nx_time ...`
- `[ws close] ...`
- `order N started`
- `order N audio received: ...`
- `order N user: ...`
- `order N audio sent: ...`

If the Docker logs show `[ws close]` before the target turnkey and no later
`[ws open]` before it, the socket was not present for live audio.

## 5. Distinguish Live Audio From HTTP Telemetry

There are two separate upload paths.

### Live Audio Path

This is the real interaction path:

```text
ESP32 mic -> nRF53 -> BLE audio packets -> nx_main -> WebSocket -> MCP -> STT -> agent
```

Evidence that live audio reached MCP:

- `server / mcp / audio_received_summary`
- `server / mcp / audio_input_summary`
- `server / mcp / stt_transcript`
- `server / agent:* / agent_run_start`

### HTTP Telemetry Path

This is only diagnostic log upload:

```text
firmware JSONL on device -> nRF53 file transfer -> nx_main -> HTTP POST /telemetry/firmware/upload -> logs table
```

Evidence that rows came through telemetry:

- `payload.upload.filename`, such as `audio_263783201.jsonl`
- `payload.upload.transfer_id`
- many `origin_kind=firmware` rows inserted from one JSONL file

Relevant code:

- `lib/data/telemetry/telemetry_upload_manager.dart`
  - posts to `/telemetry/firmware/upload`
- server route `/telemetry/firmware/upload`
  - parses firmware JSONL and inserts into `logs`

The telemetry path can succeed even when the live WebSocket is gone. In that
case, the server knows the firmware captured audio, but MCP did not process the
Opus as an interaction.

### App Log HTTP Path

`nx_main` also uploads structured app logs over HTTP:

```text
nx_main app log -> HTTP POST /logs/app/upload -> logs table
```

Evidence:

- `origin_kind=app`
- `origin=nx_main`
- `event_name=nrf_opus_reception_summary`

This row means `nx_main` received Opus over BLE. It does not prove the Opus was
sent to MCP.

## 6. Common Conclusions

### Firmware Failed

You do not see `mic_record_start`, `opus_packets_sent`, or nRF summary rows.
The failure is before or inside ESP32/nRF53 audio capture.

### BLE To `nx_main` Failed

You see ESP32 and nRF firmware rows, but no `app / nx_main /
nrf_opus_reception_summary`.

The device generated audio, but `nx_main` did not log receiving it.

### WebSocket Missing Or Closed

You see:

- `esp32 opus sent ...`
- `nrf53 ... sent to nx_main`
- `app / nx_main / nrf_opus_reception_summary`

But you do not see:

- `server / mcp / audio_received_summary`
- `stt_transcript`
- agent logs

This means `nx_main` got the audio locally, but it did not reach MCP as live
audio. Check `docker logs nexus-mcp` for `[ws close]` before that time.

### HTTP Telemetry Explains Server Visibility

If firmware rows appear in the server logs with `payload.upload`, they arrived
via `/telemetry/firmware/upload`. This is not the same as live audio processing.

## 7. Handy Exact Queries

Show only app and server audio rows around a window:

```sh
ssh pi "docker exec nexus-postgres psql -U postgres -d nexus_db -P pager=off -c \"
select
  id,
  to_char(time, 'YYYY-MM-DD HH24:MI:SS.MS TZ') as time,
  origin_kind,
  origin,
  event_name,
  message,
  payload->>'turnkey' as turnkey,
  payload->>'order_id' as order_id,
  payload->>'opus_packets' as packets,
  payload->>'opus_bytes' as bytes
from logs
where time between '2026-05-22 23:55:00+00' and '2026-05-23 00:35:00+00'
  and category='audio'
  and origin_kind in ('app', 'server')
order by time, id;
\""
```

Show errors around a window:

```sh
ssh pi "docker exec nexus-postgres psql -U postgres -d nexus_db -P pager=off -c \"
select
  id,
  to_char(time, 'YYYY-MM-DD HH24:MI:SS.MS TZ') as time,
  origin_kind,
  origin,
  severity,
  event_name,
  category,
  message,
  payload
from logs
where time between '2026-05-23 00:15:45+00' and '2026-05-23 00:16:20+00'
  and (
    severity <> 'info'
    or message ilike '%error%'
    or message ilike '%fail%'
    or message ilike '%timeout%'
    or event_name ilike '%error%'
    or event_name ilike '%fail%'
  )
order by time, id;
\""
```

Show recent `nx_main` app rows:

```sh
ssh pi "docker exec nexus-postgres psql -U postgres -d nexus_db -P pager=off -c \"
select
  id,
  to_char(time, 'YYYY-MM-DD HH24:MI:SS.MS TZ') as time,
  origin,
  event_name,
  message,
  payload->>'turnkey' as turnkey,
  payload->>'opus_packets' as packets,
  payload->>'opus_bytes' as bytes
from logs
where origin='nx_main'
order by time desc
limit 80;
\""
```

## 8. Notes For Future Agents

- The Pi may not have `rg`; use `grep` remotely.
- Prefer the Postgres `logs` table over blind file searching.
- `payload.upload` means the row came from firmware telemetry JSONL upload.
- A `nrf_opus_reception_summary` row from `nx_main` is an HTTP app log, not
  proof of live WebSocket delivery.
- Always compare the target turnkey to nearby successful turns in the same time
  window.
