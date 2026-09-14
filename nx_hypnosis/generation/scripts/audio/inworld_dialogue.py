#!/usr/bin/env python3
"""Render ordered speaker turns with Inworld, then join lossless audio.
Usage: python3 inworld_dialogue.py turns.json --name sample
Input: {"cast": {"Narrator": "Harold"}, "turns": [{"speaker": "Narrator", "text": "...", "pause": 0.4}]}
Existing segments are reused only when their saved request matches exactly.
"""
import argparse, array, base64, json, math, os, pathlib, subprocess, sys, urllib.request, wave
ROOT = pathlib.Path(__file__).resolve().parents[2]
def validate(config):
    if config.get('version', 1) != 1:
        raise ValueError('Unsupported script version')
    cast, turns = config.get('cast'), config.get('turns')
    if not isinstance(cast, dict) or not cast or not all(isinstance(v, str) and v.strip() for v in cast.values()):
        raise ValueError('cast must map speaker names to nonempty voice IDs')
    if not isinstance(turns, list) or not turns:
        raise ValueError('turns must be a nonempty ordered list')
    rate = config.get('speaking_rate', .9)
    if not isinstance(rate, (int, float)) or not math.isfinite(rate) or not .5 <= rate <= 1.5:
        raise ValueError('speaking_rate must be between 0.5 and 1.5')
    if config.get('delivery_mode', 'STABLE') not in ('STABLE', 'BALANCED', 'CREATIVE'):
        raise ValueError('Invalid delivery_mode')
    directions = config.get('speaker_instructions', {})
    if not isinstance(directions, dict) or not all(k in cast and isinstance(v, str) for k, v in directions.items()):
        raise ValueError('speaker_instructions must map cast members to text')
    ids = set()
    for i, turn in enumerate(turns):
        if not isinstance(turn, dict) or turn.get('speaker') not in cast:
            raise ValueError(f'Turn {i+1}: unknown speaker')
        text = turn.get('text')
        if not isinstance(text, str) or not text.strip() or len(text) > 2000:
            raise ValueError(f'Turn {i+1}: text must contain 1–2000 characters')
        pause = turn.get('pause', .4)
        if not isinstance(pause, (int, float)) or not math.isfinite(pause) or not 0 <= pause <= 10:
            raise ValueError(f'Turn {i+1}: pause must be 0–10 seconds')
        if 'instruction' in turn and not isinstance(turn['instruction'], str):
            raise ValueError(f'Turn {i+1}: instruction must be text')
        if 'id' in turn:
            if not isinstance(turn['id'], str) or not turn['id'] or turn['id'] in ids:
                raise ValueError(f'Turn {i+1}: ID must be nonempty and unique')
            ids.add(turn['id'])

def main():
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument('script',type=pathlib.Path); ap.add_argument('--name'); ap.add_argument('--validate-only', action='store_true', help='Validate without credentials, network calls, or audio generation'); ap.add_argument('--output-group', default='', help='Subfolder within generation/outputs'); args=ap.parse_args()
    config=json.loads(args.script.read_text())
    try:
        validate(config)
    except ValueError as error:
        ap.error(str(error))
    turns=config['turns']; cast=config['cast']
    if args.validate_only:
        print(f"Valid: {len(turns)} turns, {len(cast)} cast members, {sum(len(t['text']) for t in turns)} spoken characters")
        return
    if not args.name or pathlib.Path(args.name).name != args.name or args.name in ('.','..'):
        ap.error('--name must be a simple filename stem')
    key=os.environ.get('INWORLD_API_KEY')
    if not key and (ROOT/'.env').exists():
        key=next((line.split('=',1)[1].strip() for line in (ROOT/'.env').read_text().splitlines() if line.startswith('INWORLD_API_KEY=')),None)
    if not key: raise SystemExit('Set INWORLD_API_KEY in environment or generation/.env')
    output_root=(ROOT/'outputs'/args.output_group).resolve()
    if not output_root.is_relative_to((ROOT/'outputs').resolve()): ap.error('Output group must stay within outputs')
    out=output_root/args.name; out.mkdir(parents=True,exist_ok=True)
    combined=array.array('h'); rate=48000; receipts=[]
    combined.extend([0]*int(rate*0.3))
    for i,turn in enumerate(turns):
        payload={'text':turn['text'],'voiceId':cast[turn['speaker']],'modelId':'inworld-tts-2','audioConfig':{'audioEncoding':'LINEAR16','sampleRateHertz':rate,'speakingRate':config.get('speaking_rate',0.9)},'deliveryMode':config.get('delivery_mode','STABLE'),'instruction':turn.get('instruction',config.get('speaker_instructions',{}).get(turn['speaker'],'Speak naturally and gently, with understated emotion, clear words, and unhurried pauses. No whispering.')),'synthesisContext':{'previousRequests':[{'text':t['text']} for t in turns[:i]][-5:]}}
        while sum(len(t['text']) for t in payload['synthesisContext']['previousRequests'])>2000:payload['synthesisContext']['previousRequests'].pop(0)
        path=out/f'{i:02d}.wav'; meta=path.with_suffix('.json')
        if path.exists() and meta.exists():
            receipt=json.loads(meta.read_text())
            if receipt['request'] != payload: raise SystemExit('Cached request differs; use a new output name')
        else:
            print(f'Generating {i+1}/{len(turns)}: {turn["speaker"]}',flush=True)
            req=urllib.request.Request('https://api.inworld.ai/tts/v1/voice',data=json.dumps(payload).encode(),headers={'Authorization':'Basic '+key,'Content-Type':'application/json'})
            with urllib.request.urlopen(req,timeout=180) as response: result=json.load(response)
            raw=base64.b64decode(result.pop('audioContent')); path.write_bytes(raw)
            receipt={'request':payload,'response':result};meta.write_text(json.dumps(receipt,indent=2))
        with wave.open(str(path),'rb') as audio:
            assert audio.getnchannels()==1 and audio.getsampwidth()==2 and audio.getframerate()==rate
            samples=array.array('h',audio.readframes(audio.getnframes()))
        if sys.byteorder!='little':samples.byteswap()
        # Five-millisecond edge ramps prevent discontinuities at joins, without stretching speech.
        n=min(240,len(samples)//2)
        for j in range(n):
            samples[j]=round(samples[j]*j/n);samples[-1-j]=round(samples[-1-j]*j/n)
        combined.extend(samples);combined.extend([0]*round(rate*turn.get('pause',0.4)))
        receipts.append({'id':turn.get('id'), 'scene':turn.get('scene'), 'speaker':turn['speaker'],'voice':cast[turn['speaker']],'seconds':len(samples)/rate,'usage':receipt['response'].get('usage')})
    final=output_root/f'{args.name}.wav'
    if sys.byteorder!='little':combined.byteswap()
    with wave.open(str(final),'wb') as audio:audio.setparams((1,2,rate,0,'NONE','not compressed'));audio.writeframes(combined.tobytes())
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(final),'-codec:a','libmp3lame','-b:a','192k',str(final.with_suffix('.mp3'))],check=True)
    final.with_suffix('.json').write_text(json.dumps({'script':config,'segments':receipts,'duration_seconds':len(combined)/rate,'processing':'5ms edge ramps; explicit pauses; no EQ or time stretch'},indent=2))
    print(f'Created {final.with_suffix(".mp3")} ({len(combined)/rate:.1f}s)')
if __name__=='__main__':main()
