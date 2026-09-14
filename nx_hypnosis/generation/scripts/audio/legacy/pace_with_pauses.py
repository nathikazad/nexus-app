#!/usr/bin/env python3
"""Reach a target duration by extending existing phrase gaps, without stretching speech."""
import argparse
from array import array
import json, math, re, subprocess, sys, tempfile, wave
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path)
    p.add_argument('output',type=Path)
    p.add_argument('--seconds',type=float,default=366)
    p.add_argument('--silence-db',type=float,default=-40)
    a=p.parse_args()
    if a.output.exists(): p.error('Choose a new output file')
    with tempfile.TemporaryDirectory() as temp:
        raw=Path(temp)/'source.wav'
        out=Path(temp)/'paced.wav'
        subprocess.run(['ffmpeg','-v','error','-i',str(a.source),'-ac','1','-ar','44100',str(raw)],check=True)
        with wave.open(str(raw),'rb') as f:
            rate=f.getframerate(); samples=array('h',f.readframes(f.getnframes()))
        if sys.byteorder!='little': samples.byteswap()
        result=subprocess.run(['ffmpeg','-hide_banner','-i',str(raw),'-af',f'silencedetect=noise={a.silence_db}dB:d=0.25','-f','null','-'],check=True,capture_output=True,text=True)
        gaps=[(float(e)-float(d),float(e)) for e,d in re.findall(r'silence_end: ([\d.]+) \| silence_duration: ([\d.]+)',result.stderr)]
        gaps=[(s,e) for s,e in gaps if s>1 and e<len(samples)/rate-2]
        budget=round(a.seconds*rate)-len(samples)-2*rate
        if budget<=0 or not gaps: p.error('Target must exceed the source duration and contain phrase gaps')
        lo,hi=0,a.seconds
        for _ in range(60):
            floor=(lo+hi)/2
            if sum(max(0,floor-(e-s)) for s,e in gaps)*rate>budget: hi=floor
            else: lo=floor
        edits=[]
        for s,e in gaps:
            extra=round(max(0,lo-(e-s))*rate)
            if extra: edits.append([round((s+e)*rate/2),extra])
        edits[-1][1]+=budget-sum(n for _,n in edits)
        fade=round(.04*rate)
        for mid,_ in edits:
            for i in range(fade):
                k=(1+math.cos(math.pi*i/(fade-1)))/2
                samples[mid-fade+i]=round(samples[mid-fade+i]*k)
                samples[mid+i]=round(samples[mid+i]*(1-k))
            assert samples[mid-1]==samples[mid]==0
        if sys.byteorder!='little': samples.byteswap()
        with wave.open(str(out),'wb') as f:
            f.setparams((1,2,rate,0,'NONE','not compressed'))
            f.writeframes(b'\0'*(rate)) # Half-second opening.
            cursor=0
            for mid,n in edits:
                f.writeframes(samples[cursor:mid].tobytes()); f.writeframes(b'\0'*(n*2)); cursor=mid
            f.writeframes(samples[cursor:].tobytes()); f.writeframes(b'\0'*(3*rate))
        with wave.open(str(out),'rb') as f: assert f.getnframes()==round(a.seconds*rate)
        subprocess.run(['ffmpeg','-v','error','-n','-i',str(out),'-c:a','libmp3lame','-b:a','192k',str(a.output)],check=True)
        report=dict(source=str(a.source.resolve()),speech_speed_unchanged=True,silence_threshold_db=a.silence_db,bass_reduction=False,volume_leveling=False,extended_phrase_gaps=len(edits),minimum_phrase_pause_seconds=round(lo,3),added_pause_seconds=round(budget/rate+2,3),duration_seconds=a.seconds,join_endpoints_zero=True)
        a.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))
if __name__=='__main__': main()
