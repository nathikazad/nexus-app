#!/usr/bin/env python3
"""Create a headphone preview with lighter bass and softly joined long pauses.

Only existing long quiet gaps are extended. Speech and breaths are retained;
80 ms cosine fades around each quiet midpoint avoid hard silence boundaries.
Requires FFmpeg; no ElevenLabs request or production update is performed.
"""
import argparse
from array import array
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if not args.source.is_file() or args.output.exists():
        parser.error('Source must exist; output must be a new file.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='hypnosis-refine-') as temp:
        slow, smooth = [Path(temp)/name for name in ('slow.wav', 'smooth.wav')]
        filters = 'highpass=f=75,bass=g=-4.5:f=180:t=q:w=0.7,atempo=0.75'
        subprocess.run(['ffmpeg','-v','error','-i',str(args.source),'-af',filters,
                        '-ac','1','-ar','44100','-c:a','pcm_s16le',str(slow)],check=True)
        result = subprocess.run(['ffmpeg','-hide_banner','-i',str(slow),'-af',
                                 'silencedetect=noise=-42dB:d=1.95','-f','null','-'],
                                check=True,capture_output=True,text=True)
        gaps = [(float(end)-float(duration), float(end)) for end,duration in re.findall(
            r'silence_end: ([\d.]+) \| silence_duration: ([\d.]+)', result.stderr)]
        with wave.open(str(slow),'rb') as stream:
            rate = stream.getframerate()
            samples = array('h',stream.readframes(stream.getnframes()))
        if sys.byteorder != 'little': samples.byteswap()
        fade = round(0.08*rate)
        edits = []
        for start,end in gaps:
            extra = round(max(0,4.0-(end-start))*rate)
            if not extra: continue
            mid = round((start+end)*rate/2)
            for i in range(fade):
                factor = (1+math.cos(math.pi*i/(fade-1)))/2
                samples[mid-fade+i] = round(samples[mid-fade+i]*factor)
                samples[mid+i] = round(samples[mid+i]*(1-factor))
            assert samples[mid-1] == samples[mid] == 0
            edits.append((mid,extra))
        # Smooth the beginning/end as well, before adding short framing silence.
        for i in range(fade):
            factor=(1-math.cos(math.pi*i/(fade-1)))/2
            samples[i]=round(samples[i]*factor)
            samples[-i-1]=round(samples[-i-1]*factor)
        peak=max(abs(x) for x in samples)
        assert peak < 32767, 'Clipped output'
        if sys.byteorder != 'little': samples.byteswap()
        with wave.open(str(smooth),'wb') as stream:
            stream.setparams((1,2,rate,0,'NONE','not compressed'))
            stream.writeframes(b'\0'*(round(.8*rate)*2))
            cursor=0
            for mid,extra in edits:
                stream.writeframes(samples[cursor:mid].tobytes())
                stream.writeframes(b'\0'*(extra*2))
                cursor=mid
            stream.writeframes(samples[cursor:].tobytes())
            stream.writeframes(b'\0'*(2*rate*2))
        subprocess.run(['ffmpeg','-v','error','-n','-i',str(smooth),'-c:a','libmp3lame',
                        '-b:a','192k',str(args.output)],check=True)
        report = {'source':str(args.source.resolve()),'tempo':0.75,
                  'highpass_hz':75,'bass_shelf_hz':180,'bass_gain_db':-4.5,
                  'fade_ms':80,'extended_pauses':len(edits),
                  'duration_seconds':round((len(samples)+sum(n for _,n in edits))/rate+2.8,3),
                  'peak_dbfs':round(20*math.log10(peak/32768),2),
                  'join_endpoints_zero':True}
        args.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))


if __name__=='__main__':main()
