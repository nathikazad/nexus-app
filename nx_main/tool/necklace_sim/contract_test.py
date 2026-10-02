"""Run real phone + firmware against a local server protocol peer (no AI calls).

Usage: servers/venv/bin/python contract_test.py --workspace /path/to/Nexus
Requires the firmware simulator already built under tmp/firmware-sim/build.
"""
import argparse
import asyncio
import json
import os
from pathlib import Path
import secrets
import sys
import threading
import socket
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import uuid


async def run(root):
    sys.path.insert(0, str(root / 'servers'))
    from nexus.devices.registry import verify_proof
    from nexus.socket.messages.packets import (parse_packet, AudioChunk, AudioEOF,
        DeviceResponse, ImageChunk, serialize_audio_chunk, serialize_audio_eof, serialize_device_request)
    from websockets.asyncio.server import serve
    output = root / 'tmp/live-necklace' / ('contract-' + uuid.uuid4().hex[:8])
    output.mkdir(parents=True, mode=0o700)
    device = str(uuid.uuid4())
    secret, nonce, token = secrets.token_hex(32), secrets.token_hex(32), 'nd1_' + secrets.token_hex(32)
    auth_ok = False

    class Auth(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def do_POST(self):
            nonlocal auth_ok
            body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            try:
                assert body['device_id'] == device
                if self.path == '/v1/devices/challenge':
                    result = {'nonce': nonce, 'expires_in': 30}
                elif self.path == '/v1/devices/token':
                    assert not auth_ok and body['nonce'] == nonce and body['pairing_secret'] == secret
                    verify_proof(device, nonce, body['public_key'], body['signature'])
                    auth_ok = True
                    result = {'access_token': token, 'expires_in': 3600}
                else: raise ValueError('Unknown endpoint')
                encoded = json.dumps(result).encode()
                self.send_response(200)
            except Exception:
                encoded = b'{}'
                self.send_response(403)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

    http = ThreadingHTTPServer(('127.0.0.1', 0), Auth)
    threading.Thread(target=http.serve_forever, daemon=True).start()
    received, replies, failures = [], {}, []
    image_parts = []
    fixture = Path(__file__).parent / 'fixtures/camera.jpg'
    with socket.socket() as available:
        available.bind(('127.0.0.1', 0))
        panel_port = available.getsockname()[1]
    async def camera_sensor():
        def call(path, data=None):
            with urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:{panel_port}'+path, data=data), timeout=2) as r:
                body=r.read()
                return json.loads(body) if path=='/state' else body
        for _ in range(200):
            try:
                await asyncio.to_thread(call, '/camera/on', b'')
                break
            except OSError: await asyncio.sleep(.1)
        for _ in range(200):
            state=await asyncio.to_thread(call, '/state')
            if state['camera_request']:
                await asyncio.to_thread(call, '/camera/frame?id='+str(state['camera_request']), fixture.read_bytes())
                return
            await asyncio.sleep(.05)
        raise AssertionError('No webcam frame request')
    eof = False
    async def peer(ws):
        nonlocal eof
        try:
            assert auth_ok and ws.request.headers['Authorization'] == 'Bearer ' + token
            assert ws.request.headers['X-Client-Id'] == 'necklace'
            async for message in ws:
                packet = parse_packet(message) if isinstance(message, bytes) else None
                if isinstance(packet, AudioChunk): received.append(packet)
                elif isinstance(packet, AudioEOF):
                    eof = True
                    assert received
                    for i, chunk in enumerate(received):
                        await ws.send(serialize_audio_chunk(chunk.data, packet_index=i))
                        await asyncio.sleep(.02)
                    await ws.send(serialize_audio_eof())
                    await ws.send(serialize_device_request(1, {'action': 'audio.start'}))
                elif isinstance(packet, DeviceResponse):
                    replies[packet.request_id] = json.loads(packet.payload)
                    if packet.request_id == 3:
                        await ws.send(serialize_device_request(4, {'action': 'take_photo'}))
                    if packet.request_id in (1, 2):
                        await asyncio.sleep(.8)
                        action = 'audio.new' if packet.request_id == 1 else 'audio.stop'
                        await ws.send(serialize_device_request(packet.request_id + 1, {'action': action}))
                elif isinstance(packet, ImageChunk):
                    image_parts.append(packet.data)
        except Exception as error: failures.append(repr(error))

    try:
        async with serve(peer, '127.0.0.1', 0) as server:
            setup = output / 'setup.json'
            setup.write_text(json.dumps({'device_id': device, 'device_type': 'necklace', 'pairing_secret': secret}))
            setup.chmod(0o600)
            config = {
                'python': sys.executable, 'identity_script': str(Path(__file__).with_name('identity.py')),
                'identity_state': str(output / 'identity.json'), 'pairing_setup_file': str(setup),
                'http_url': f'http://127.0.0.1:{http.server_port}',
                'socket_url': f'ws://127.0.0.1:{server.sockets[0].getsockname()[1]}',
                'binary': str(root / 'tmp/firmware-sim/build/nexus_blackbox'),
                'output': str(output / 'firmware'), 'duration_seconds': 12, 'control_port': panel_port,
                'press_ms': 500, 'hold_ms': 1200, 'min_speaker_samples': 1000,
            }
            config_file = output / 'config.json'
            config_file.write_text(json.dumps(config))
            with (output / 'relay.log').open('w') as log:
                process = await asyncio.create_subprocess_exec('flutter', 'test',
                    'tool/necklace_sim/live_test.dart', '--reporter', 'expanded',
                    cwd=root / 'mobile/nx_main', env={**os.environ, 'NEXUS_SIM_CONFIG': str(config_file)},
                    stdout=log, stderr=asyncio.subprocess.STDOUT)
                sensor = asyncio.create_task(camera_sensor())
                try:
                    code = await asyncio.wait_for(process.wait(), 90)
                    await sensor
                finally:
                    if not sensor.done(): sensor.cancel()
                    if process.returncode is None:
                        process.kill()
                        await process.wait()
            assert code == 0, f'Relay failed; see {output}/relay.log'
            assert auth_ok and eof and len(received) > 5
            assert not failures, failures
            assert set(replies) == {1, 2, 3, 4}, replies
            assert all(value.get('success') for value in replies.values()), replies
            state = json.loads((output / 'firmware/summary.json').read_text())
            assert state['background_enabled'] == 0 and state['sd_writing'] == 0
            assert state['sd_bytes'] > 1000
            assert b''.join(image_parts) == fixture.read_bytes(), 'Camera bytes must survive firmware/BLE/WebSocket exactly'
            print(f'PASS: signed auth, {len(received)} audio packets, EOF, speaker decode, 3 recording commands + webcam JPEG capture/transfer. {output}')
    finally:
        http.shutdown()
        http.server_close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace', type=Path, required=True)
    asyncio.run(run(parser.parse_args().workspace.resolve()))
