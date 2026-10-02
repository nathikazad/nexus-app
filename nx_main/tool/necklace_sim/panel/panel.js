const $ = id => document.getElementById(id);
let context, stream, micNode, source, sink, enabled = false, holding = false, busy = false;
let sessionId, networkError = false;
let playbackAt = 0, lastEvent = 0, sendQueue = Promise.resolve(), queued = 0, connected = false;
const playing = new Set();
let buttonQueue = Promise.resolve(), flushComplete;
async function flushMic() {
  if (!enabled || !micNode) return;
  await new Promise(resolve => {
    const timeout = setTimeout(() => { flushComplete = null; resolve(); }, 250);
    flushComplete = () => { clearTimeout(timeout); flushComplete = null; resolve(); };
    micNode.port.postMessage('flush');
  });
}
async function post(path, body) {
  const response = await fetch(path, {method: 'POST', body});
  if (!response.ok) throw new Error(`Device connection failed (${response.status}).`);
}
function error(e) { $('error').textContent = e.message || String(e); }
async function disableMic() {
  enabled = false;
  await release().catch(error);
  micNode?.disconnect(); source?.disconnect(); sink?.disconnect();
  stream?.getTracks().forEach(track => track.stop());
  await sendQueue;
  await post('/microphone/off').catch(error);
  $('mic').textContent = 'Enable microphone'; $('talk').disabled = true;
  $('level').style.width = '0%'; $('hint').textContent = 'Microphone off.';
}
$('mic').onclick = async () => {
  if (busy) return;
  busy = true; $('error').textContent = '';
  try {
    if (enabled) { await disableMic(); return; }
    context ??= new AudioContext({sampleRate: 16000});
    await context.resume();
    if (context.sampleRate !== 16000) throw new Error('This browser cannot use a 16 kHz microphone. Try Chrome.');
    stream = await navigator.mediaDevices.getUserMedia({audio: {channelCount: 1, echoCancellation: true, noiseSuppression: true}});
    await context.audioWorklet.addModule('/mic-worklet.js');
    source = context.createMediaStreamSource(stream);
    micNode = new AudioWorkletNode(context, 'necklace-mic');
    sink = context.createGain(); sink.gain.value = 0;
    await post('/microphone/on');
    enabled = true;
    micNode.port.onmessage = ({data}) => {
      if (data.flushed) { flushComplete?.(); return; }
      if (!enabled) return;
      const pcm = new Int16Array(data);
      let energy = 0; for (const value of pcm) energy += value * value;
      $('level').style.width = `${Math.min(100, Math.sqrt(energy / pcm.length) / 100)}%`;
      if (queued >= 5) { error(new Error('Audio connection is too slow. Microphone stopped.')); void disableMic(); return; }
      queued++;
      sendQueue = sendQueue.then(() => enabled ? post('/pcm', data) : null)
        .catch(e => { error(e); if (enabled) void disableMic(); }).finally(() => queued--);
    };
    source.connect(micNode); micNode.connect(sink); sink.connect(context.destination);
    $('mic').textContent = 'Turn microphone off'; $('talk').disabled = !connected;
    $('hint').textContent = 'Hold the touch pad above the camera to record. Release to send. Space bar works too.';
  } catch(e) { error(e); stream?.getTracks().forEach(track => track.stop()); }
  finally { busy = false; }
};
function stopPlayback() { for (const node of playing) { try { node.stop(); } catch {} } playing.clear(); playbackAt = 0; }
async function press() {
  if (!enabled || !connected || holding) return;
  holding = true; stopPlayback(); $('talk').classList.add('active'); $('talk').setAttribute('aria-pressed', 'true');
  try {
    buttonQueue = buttonQueue.then(async () => { await context.resume(); await post('/press'); });
    await buttonQueue;
  }
  catch(e) { error(e); await release(); }
}
async function release() {
  if (!holding) return;
  holding = false; $('talk').classList.remove('active'); $('talk').setAttribute('aria-pressed', 'false');
  // Flush submitted microphone chunks before releasing the simulated GPIO.
  buttonQueue = buttonQueue.catch(() => {}).then(async () => { await flushMic(); await sendQueue; await post('/release'); });
  await buttonQueue;
}
$('talk').onpointerdown = e => { e.preventDefault(); $('talk').setPointerCapture(e.pointerId); void press(); };
$('talk').onpointerup = () => { void release().catch(error); };
$('talk').onpointercancel = () => { void release().catch(error); };
window.addEventListener('keydown', e => { if (e.code === 'Space' && !e.repeat && !['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName) && !e.target.isContentEditable) { e.preventDefault(); void press(); } });
window.addEventListener('keyup', e => { if(e.code === 'Space') { e.preventDefault(); void release().catch(error); } });
window.addEventListener('blur', () => { void release().catch(error); });
window.addEventListener('pagehide', () => { stream?.getTracks().forEach(t => t.stop()); navigator.sendBeacon('/microphone/off'); });
document.querySelectorAll('[data-action]').forEach(button => button.onclick = () => post('/' + button.dataset.action).catch(error));
function play(encoded) {
  if (!encoded || !context || holding) return;
  const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
  const view = new DataView(bytes.buffer), buffer = context.createBuffer(1, bytes.length / 2, 16000);
  const pcm = buffer.getChannelData(0);
  for (let i = 0; i < pcm.length; i++) pcm[i] = view.getInt16(i * 2, true) / 32768;
  const node = context.createBufferSource(); node.buffer = buffer; node.connect(context.destination);
  playbackAt = Math.max(context.currentTime + .06, playbackAt);
  node.start(playbackAt); playbackAt += buffer.duration;
  playing.add(node); node.onended = () => playing.delete(node);
}
async function poll() {
  try {
    const response = await fetch('/state'); if (!response.ok) throw new Error('Simulator stopped.');
    const s = await response.json(); connected = s.relay_connected;
    if (s.session_id !== sessionId) {
      if(sessionId && cameraStream) void disableCamera().catch(error);
      sessionId = s.session_id; lastEvent = 0; handledFrame = 0; photoVersion = 0; $('photo').hidden = true; $('events').replaceChildren();
      $('error').textContent = ''; stopPlayback();
    }
    if (networkError) { $('error').textContent = ''; networkError = false; }
    $('connection').textContent = connected ? '● Hetzner connected' : '○ Server disconnected';
    $('talk').disabled = !enabled || !connected;
    $('stage').classList.toggle('listening', !!s.mic);
    $('recording').textContent = s.background_enabled ? (s.background_sd ? 'Recording' : 'Starting…') : (s.background_state ? 'Finishing…' : 'Off');
    $('recording-detail').textContent = `State ${s.background_state} · file ${s.background_id}`;
    $('esp').textContent = s.sleep_requested ? 'Sleeping' : s.ready ? 'Awake' : 'Waking…';
    $('esp-detail').textContent = `${s.sleep_holds} sleep holds · mic ${s.mic ? 'running' : 'idle'}`;
    $('sd').textContent = `${(s.sd_bytes / 1024).toFixed(1)} KB`;
    $('sd-detail').textContent = s.sd_writing ? 'Writing audio' : `${s.sd_errors} errors · local storage`;
    $('camera').textContent = s.camera_active ? 'Capturing' : s.camera_auto ? 'Auto capture' : 'Idle';
    $('camera-detail').textContent = `${s.camera_done} completed · ${s.camera_failed} failed`;
    $('packets').textContent = `${s.uplink} audio packets sent · ${s.speaker_samples} speaker samples`;
    if (holding) $('hint').textContent = s.mic ? 'Microphone is running. Speak now.' : 'Waking the device…';
    else if(enabled) $('hint').textContent = 'Hold the touch pad above the camera to record. Release to send. Space bar works too.';
    for(const event of s.events) if(event.id > lastEvent) {
      const row = document.createElement('li'), time = document.createElement('time');
      time.textContent = new Date(event.at).toLocaleTimeString(); row.append(time, document.createTextNode(event.text));
      $('events').prepend(row); lastEvent = event.id;
      while($('events').children.length > 80) $('events').lastChild.remove();
    }
    if(s.camera_request) void supplyCameraFrame(s.camera_request);
    if(s.photo_version !== photoVersion) {
      photoVersion = s.photo_version;
      if(photoVersion) {
        $('photo').src = '/photo.jpg?v='+s.session_id+'-'+photoVersion;
        $('photo').hidden = false;
        $('photo-status').textContent = 'Photo received through nRF / BLE · forwarded to server';
      }
    }
    play(s.speaker_pcm);
  } catch(e) { networkError = true; connected = false; $('connection').textContent = '○ Simulator disconnected'; $('talk').disabled = true; error(e); }
  setTimeout(poll, 150);
}
void poll();

// The webcam is a sensor input; its JPEG still travels through the firmware
// camera/SD/BLE transfer path before appearing as the received photo below.
let cameraStream, cameraBusy = false, frameInFlight = false, handledFrame = 0, photoVersion = 0;
async function enableCamera() {
  if (cameraStream) return;
  $('photo-status').textContent = 'Waiting for webcam permission…';
  const media = await navigator.mediaDevices.getUserMedia({audio:false, video:{width:{ideal:640},height:{ideal:480}}});
  try {
    $('webcam').srcObject = media; $('webcam').hidden = false;
    $('photo-status').textContent = 'Starting computer webcam…';
    await Promise.race([$('webcam').play(), new Promise((_, reject) => setTimeout(() => reject(new Error('Webcam did not start. Try enabling it again.')), 8000))]);
    await post('/camera/on'); cameraStream = media;
    $('webcam').hidden = false; $('enable-camera').textContent = 'Turn webcam off';
    $('photo-status').textContent = 'Live computer webcam · ready for capture';
  } catch(e) { media.getTracks().forEach(t=>t.stop()); $('webcam').hidden = true; throw e; }
}
async function disableCamera() {
  cameraStream?.getTracks().forEach(t=>t.stop()); cameraStream = null;
  $('webcam').srcObject = null; $('webcam').hidden = true;
  $('enable-camera').textContent = 'Enable webcam';
  await post('/camera/off');
  $('photo-status').textContent = 'Webcam off · last received photo kept below';
}
$('enable-camera').onclick = async () => {
  if(cameraBusy) return; cameraBusy = true;
  try { if(cameraStream) await disableCamera(); else await enableCamera(); }
  catch(e) { error(e); $('photo-status').textContent = 'Webcam unavailable: '+e.message; } finally { cameraBusy = false; }
};
$('take-photo').onclick = async () => {
  if(cameraBusy) return; cameraBusy = true; $('take-photo').disabled = true;
  try {
    $('error').textContent = ''; await enableCamera();
    $('photo-status').textContent = 'Phone requesting a photo from the necklace…';
    await post('/take_photo');
  } catch(e) { error(e); $('photo-status').textContent = 'Photo capture failed. Check webcam permission.'; }
  finally { cameraBusy = false; $('take-photo').disabled = false; }
};
async function supplyCameraFrame(id) {
  if(frameInFlight || handledFrame === id || !cameraStream) return;
  frameInFlight = true; handledFrame = id;
  try {
    const video = $('webcam'), canvas = document.createElement('canvas');
    if(!video.videoWidth) throw new Error('Webcam is not ready yet. Try taking the photo again.');
    let blob;
    for(const width of [640,480,320,240]) {
      canvas.width = Math.min(width,video.videoWidth);
      canvas.height = Math.round(canvas.width * video.videoHeight/video.videoWidth);
      canvas.getContext('2d').drawImage(video,0,0,canvas.width,canvas.height);
      blob = await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',.7));
      if(blob && blob.size <= 32000) break;
    }
    if(!blob || blob.size > 32000) throw new Error('Camera image exceeds the simulated BLE photo limit.');
    await post('/camera/frame?id='+id,blob);
    $('photo-status').textContent = 'Captured webcam frame · waiting for necklace photo transfer…';
  } catch(e) { error(e); }
  finally { frameInFlight = false; }
}
window.addEventListener('pagehide',()=>{
  cameraStream?.getTracks().forEach(t=>t.stop()); navigator.sendBeacon('/camera/off');
});
