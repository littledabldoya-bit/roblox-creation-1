#!/usr/bin/env python3
"""Render an original 152 BPM sci-fi instrumental; requires numpy and ffmpeg.

No samples, external recordings, or third-party melodies are used. The arrangement
changes across 128 bars instead of repeating one short loop.
"""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

RATE = 32000
BPM = 152
BEAT = 60 / BPM
BARS = 128
ROOT = Path(__file__).resolve().parents[1]

def render():
    rng = np.random.default_rng(20261020)
    mix = np.zeros((round((BARS * 4 * BEAT + 2) * RATE), 2), dtype=np.float32)

    def add(signal, beat, volume=1, pan=0):
        start = round(beat * BEAT * RATE)
        end = min(len(mix), start + len(signal))
        if start < 0 or end <= start:
            return
        signal = signal[:end-start] * volume
        mix[start:end, 0] += signal * np.sqrt((1-pan)/2)
        mix[start:end, 1] += signal * np.sqrt((1+pan)/2)

    def note(midi, beats, voice='lead'):
        length = max(1, round(beats * BEAT * RATE))
        t = np.arange(length) / RATE
        frequency = 440 * 2 ** ((midi - 69) / 12)
        phase = 2 * np.pi * frequency * t
        if voice == 'bass':
            tone = np.sin(phase) + .22*np.sin(2*phase) + .09*np.sin(3*phase)
            envelope = (1-np.exp(-t*150)) * np.exp(-t*4)
        elif voice == 'pad':
            tone = np.sin(phase) + .24*np.sin(phase*1.003) + .12*np.sin(2*phase)
            envelope = np.minimum(1,t/.18) * np.minimum(1,(beats*BEAT-t)/.3)
        else:
            tone = np.sin(phase) + .32*np.sin(2*phase) + .13*np.sin(3*phase)
            envelope = (1-np.exp(-t*250)) * np.exp(-t*7)
        return (tone * envelope * np.minimum(1, (length-np.arange(length))/200)).astype(np.float32)

    t = np.arange(round(.26*RATE))/RATE
    kick = np.sin(2*np.pi*(44*t+9*(1-np.exp(-t*25))))*np.exp(-t*19)
    t = np.arange(round(.18*RATE))/RATE
    noise = rng.normal(0,1,len(t))
    snare = (.27*(noise-np.roll(noise,1)) + .4*np.sin(2*np.pi*185*t))*np.exp(-t*24)
    t = np.arange(round(.065*RATE))/RATE
    noise = rng.normal(0,1,len(t))
    hat = (noise-np.roll(noise,1))*np.exp(-t*80)*.2
    motif_a = [76,79,83,79,78,76,74,71,76,78,79,83,86,83,79,78]
    motif_b = [83,81,79,76,78,79,83,86,88,86,83,81,79,78,76,74]
    motif_c = [72,76,79,83,81,79,76,74,71,74,78,81,79,78,74,71]
    for bar in range(BARS):
        # Intro, first drop, airy bridge, new lead, tension break, final drop, outro.
        section = 0 if bar<8 else 1 if bar<32 else 2 if bar<48 else 3 if bar<80 else 4 if bar<88 else 5 if bar<112 else 6
        root = [40,36,43,38][(bar//2)%4]
        minor = root in (40,)
        if section == 4:
            root = [45,36,40,35][(bar//2)%4]
            minor = root in (45,40)
        energy = {0:.55,1:1,2:.45,3:.95,4:.35,5:1,6:.55}[section]
        for interval in (0,3 if minor else 4,7):
            add(note(root+24+interval,3.9,'pad'),bar*4,.036,-.4+interval*.1)
        if section not in (2,4) or bar%2==0:
            for beat in ([0,1.5,2.5,3.25] if bar%4<2 else [0,.75,2,3.5]):
                add(note(root+(12 if beat==3.5 else 0),.45,'bass'),bar*4+beat,.25*energy)
        if section not in (2,4):
            kicks = [0,1.5,2.75] if bar%2==0 else [0,.75,2,3.5]
            for beat in kicks:
                add(kick,bar*4+beat,.62*energy)
            for beat in (1,3):
                add(snare,bar*4+beat,.33*energy)
            for tick in range(8 if section!=5 else 16):
                step=.5 if section!=5 else .25
                add(hat,bar*4+tick*step,.18 if tick%2==0 else .11,(-1 if tick%2==0 else 1)*.45)
        if section in (1,3,5):
            motif = motif_a if section==1 else motif_b if section==3 else (motif_a if bar%8<4 else motif_c)
            for tick in range(8):
                if (bar+tick)%7==0:
                    continue
                midi = motif[((bar%2)*8+tick+(4 if bar%8>=4 else 0))%16]
                sound = note(midi,.4)
                when=bar*4+tick*.5
                add(sound,when,.13 if section!=5 else .15, .12 if tick%2 else -.12)
                add(sound,when+.75,.027,-.55)
                add(sound,when+1.5,.014,.55)
        elif bar%2==0:
            for tick in range(4):
                add(note(root+36+[0,7,12,10][tick],.8),bar*4+tick,.09,(-.3 if tick%2 else .3))
        if bar%8==7 and section not in (2,4):
            for tick in range(4):
                add(snare,bar*4+3+tick*.25,.12+tick*.025,0)
        if bar in (7,31,47,79,87,111):
            n = round(1.4*RATE)
            sweep = rng.normal(0,1,n).astype(np.float32)
            sweep = np.convolve(sweep,np.ones(7)/7,mode='same')
            sweep *= np.linspace(0,.055,n)**1.1
            add(sweep,bar*4,.8)
    # Gentle fade at both boundaries; a full arranged track loops after ~3:24.
    fade = round(2*RATE)
    mix[:fade] *= np.linspace(0,1,fade)[:,None]
    mix[-fade:] *= np.linspace(1,0,fade)[:,None]
    mix = np.tanh(mix*1.2)
    peak = np.max(np.abs(mix))
    mix *= .92/max(float(peak),.01)
    output = ROOT / 'assets/music/NeonCircuit.mp3'
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        wav = Path(directory)/'track.wav'
        with wave.open(str(wav),'wb') as f:
            f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE)
            f.writeframes((mix*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),
                        '-af','loudnorm=I=-16:TP=-1.5:LRA=9','-ar','44100','-c:a','libmp3lame',
                        '-b:a','128k','-metadata','title=Neon Circuit',
                        '-metadata','comment=Original procedural FartNight soundtrack; 152 BPM',str(output)],check=True)
    print(f'{output}: {len(mix)/RATE:.2f}s, 152 BPM, {output.stat().st_size} bytes')

if __name__=='__main__':
    render()
