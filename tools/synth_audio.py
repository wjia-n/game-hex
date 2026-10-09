#!/usr/bin/env python3
"""Synthesize ceramic-workshop audio for Hex (Atelier Hex design system).

All sounds are 22050 Hz mono 16-bit WAVs, generated with numpy only.
Physical identity: glazed ceramic tiles, fired clay, oak workbench.
No AI artwork, no external samples - pure synthesis.
"""
import numpy as np
import wave
import os

SR = 22050
OUT = os.path.expanduser('~/workspace/game-factory/build/hex/assets/audio')
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(42)


def save(name, samples):
    samples = np.clip(samples, -1.0, 1.0)
    pcm = (samples * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f'{name}: {len(pcm)/SR:.2f}s')


def env_exp(n, tau):
    t = np.arange(n) / SR
    return np.exp(-t / tau)


def mix(s, at, chunk):
    """Mix chunk into buffer s at sample offset at, clamped to bounds."""
    end = min(len(s), at + len(chunk))
    if end > at:
        s[at:end] += chunk[:end - at]


def clack(freq=620, body_freq=233, dur=0.35, brightness=1.0):
    """Ceramic tile clack: sharp strike transient + resonant glaze body."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    nb = int(SR * 0.004)
    noise = rng.standard_normal(nb) * env_exp(nb, 0.0012)
    transient = np.zeros(n)
    transient[:nb] = noise * 0.9 * brightness
    body = (np.sin(2 * np.pi * freq * t) * 0.55
            + np.sin(2 * np.pi * freq * 1.51 * t) * 0.28
            + np.sin(2 * np.pi * freq * 2.32 * t) * 0.12
            + np.sin(2 * np.pi * body_freq * t) * 0.25) * env_exp(n, 0.09)
    return transient + body * 0.8


def knock(freq=180, dur=0.12):
    """Soft wooden knock (menu click)."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    nb = int(SR * 0.003)
    noise = rng.standard_normal(nb) * env_exp(nb, 0.001)
    sig = np.zeros(n)
    sig[:nb] = noise * 0.5
    sig += (np.sin(2 * np.pi * freq * t) * 0.6
            + np.sin(2 * np.pi * freq * 2.7 * t) * 0.18) * env_exp(n, 0.035)
    return sig


def thud(dur=0.25):
    """Dull clay thud (invalid move)."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    nb = int(SR * 0.006)
    noise = rng.standard_normal(nb) * env_exp(nb, 0.002)
    sig = np.zeros(n)
    sig[:nb] = noise * 0.45
    sig += np.sin(2 * np.pi * 105 * t + 0.4 * np.sin(2 * np.pi * 55 * t)) * env_exp(n, 0.07) * 0.7
    return sig


def bell(freq, dur=1.2, decay=0.45):
    """Warm ceramic bell partial stack."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    e = env_exp(n, decay)
    return (np.sin(2 * np.pi * freq * t) * 0.5
            + np.sin(2 * np.pi * freq * 2.01 * t) * 0.22
            + np.sin(2 * np.pi * freq * 2.94 * t) * 0.10) * e


def pluck(freq, dur=0.9, decay=0.28):
    """Kalimba-like pluck for music loops."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    e = env_exp(n, decay)
    return (np.sin(2 * np.pi * freq * t) * 0.55
            + np.sin(2 * np.pi * freq * 3.98 * t) * 0.12
            + np.sin(2 * np.pi * freq * 9.2 * t) * 0.04) * e


# ---------------- SFX ----------------
save('click.wav', knock(190, 0.12) * 0.9)
save('place.wav', clack(640, 240, 0.38) * 0.95)
save('invalid.wav', thud(0.28) * 0.9)

# swap: two clacks, tile flipped over
s = np.zeros(int(SR * 0.45))
mix(s, 0, clack(560, 220, 0.3))
mix(s, int(SR * 0.13), clack(720, 260, 0.32) * 0.9)
save('swap.wav', s)

# start: tiles rattled out of the bag, then one settle clack
s = np.zeros(int(SR * 0.9))
for i, f in enumerate([520, 610, 480, 660, 590]):
    mix(s, int(SR * (0.05 + i * 0.09)), clack(f, 210, 0.25) * (0.5 + 0.1 * i))
mix(s, int(SR * 0.5), clack(640, 240, 0.4))
save('start.wav', s * 0.9)

# win: ascending warm ceramic bells (C major pentatonic-ish climb)
s = np.zeros(int(SR * 2.0))
for i, f in enumerate([523.25, 587.33, 659.25, 783.99, 1046.5]):
    mix(s, int(SR * i * 0.16), bell(f, 1.4, 0.5) * 0.75)
save('win.wav', s)

# lose: low descending fired-clay tones
s = np.zeros(int(SR * 1.8))
for i, f in enumerate([311.13, 261.63, 207.65, 164.81]):
    mix(s, int(SR * i * 0.22), bell(f, 1.2, 0.55) * 0.7)
save('lose.wav', s)

# ---------------- Music loops ----------------
# A-minor pentatonic warmth. Patterns are exactly periodic with loop length.
PENTA = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25]


def make_loop(name, seconds, pattern, drone_freqs, pluck_dur=1.6):
    n = int(SR * seconds)
    s = np.zeros(n)
    for at_s, deg, vol in pattern:
        f = PENTA[deg % len(PENTA)] * (2 if deg >= len(PENTA) else 1)
        mix(s, int(SR * at_s), pluck(f, pluck_dur, 0.5) * vol)
    # low kiln drone: soft sine stack, exactly periodic (integer cycles)
    t = np.arange(n) / SR
    for df in drone_freqs:
        cycles = round(df * seconds)
        f = cycles / seconds
        s += np.sin(2 * np.pi * f * t) * 0.05
    # gentle loop crossfade to hide the seam
    xf = int(SR * 0.4)
    fade = np.linspace(0, 1, xf)
    tail = s[-xf:].copy()
    s[:xf] = s[:xf] * fade + tail * (1 - fade)
    s = s / max(1e-6, np.abs(s).max()) * 0.85
    save(name, s)


# menu: slow, sparse, contemplative (16s)
menu_pattern = [
    (0.0, 0, 0.5), (2.0, 2, 0.4), (4.0, 4, 0.45), (6.0, 3, 0.35),
    (8.0, 1, 0.45), (10.0, 2, 0.35), (12.0, 4, 0.4), (14.0, 0, 0.4),
]
make_loop('music_menu.wav', 16.0, menu_pattern, [55.0, 82.5])

# game: a touch more pulse (20s)
game_pattern = [
    (0.0, 0, 0.45), (1.0, 2, 0.3), (2.0, 4, 0.4), (3.0, 2, 0.3),
    (4.0, 5, 0.42), (5.0, 4, 0.3), (6.0, 3, 0.35), (7.0, 2, 0.3),
    (8.0, 0, 0.45), (9.0, 1, 0.3), (10.0, 2, 0.35), (11.0, 4, 0.3),
    (12.0, 6, 0.4), (13.0, 5, 0.3), (14.0, 4, 0.35), (15.0, 2, 0.3),
    (16.0, 3, 0.35), (17.0, 2, 0.3), (18.0, 1, 0.35), (19.0, 0, 0.3),
]
make_loop('music_game.wav', 20.0, game_pattern, [55.0, 110.0])

print('done')
