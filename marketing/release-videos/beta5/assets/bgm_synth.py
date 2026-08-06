"""Procedural 24s music bed for the NuvioTV beta.5 release video.

Dark electronic underscore, A minor, 100 BPM, synthesized with numpy (no ML
models — deterministic and light enough for any machine). Sections follow the
video's scenes:

    0.0 -  3.2  title      : sub drone + pad swell, no percussion
    3.2 - 15.4  features   : pulse kick + hats + arp enter
   15.4 - 19.4  heads-up   : arp drops out (tension), riser into the cut
   19.4 - 24.0  outro      : full mix returns, impact hit, long fade tail
"""
import numpy as np
import soundfile as sf

SR = 44100
DUR = 24.0
N = int(SR * DUR)
BPM = 100.0
BEAT = 60.0 / BPM            # 0.6 s
BAR = BEAT * 4               # 2.4 s
t = np.arange(N) / SR

rng = np.random.default_rng(20260728)  # seeded — deterministic output


# ---------- helpers ----------

def note(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semitone = names[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    midi = 12 * (octave + 1) + semitone
    return 440.0 * 2 ** ((midi - 69) / 12)


def fir_lowpass(x, cutoff, taps=257):
    fc = cutoff / (SR / 2)
    m = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(fc * m) * fc * np.hamming(taps)
    h /= h.sum()
    return np.convolve(x, h, mode="same")


def smoothstep_gate(start, end, ramp=0.25):
    """1.0 inside [start, end], smooth 0..1 ramps at the edges."""
    up = np.clip((t - start) / ramp, 0, 1)
    down = np.clip((end - t) / ramp, 0, 1)
    return (up * up * (3 - 2 * up)) * (down * down * (3 - 2 * down))


def saw(freq):
    return 2.0 * ((freq * t) % 1.0) - 1.0


# ---------- chord schedule (one chord per bar, 10 bars) ----------
AM = ["A2", "C3", "E3", "A3"]
F_ = ["F2", "A2", "C3", "F3"]
G_ = ["G2", "B2", "D3", "G3"]
BARS = [AM, AM, F_, F_, AM, AM, G_, G_, AM, AM]
ROOTS = ["A1", "A1", "F1", "F1", "A1", "A1", "G1", "G1", "A1", "A1"]

# ---------- sidechain "pump" (dips right after every beat) ----------
beat_phase = (t % BEAT)
duck = 1.0 - 0.42 * np.exp(-beat_phase / 0.13)

# ---------- pads: detuned saw stacks, lowpassed, bar crossfades ----------
padL = np.zeros(N)
padR = np.zeros(N)
for i, chord in enumerate(BARS):
    start, end = i * BAR, min((i + 1) * BAR, DUR)
    env = smoothstep_gate(start - 0.15, end + 0.15, ramp=0.45)
    for name in chord:
        f = note(name)
        padL += env * (saw(f * 1.004) + saw(f * 0.999)) * 0.5
        padR += env * (saw(f * 0.996) + saw(f * 1.001)) * 0.5
padL = fir_lowpass(padL / len(AM), 1100)
padR = fir_lowpass(padR / len(AM), 1100)

# ---------- sub bass: chord roots, gentle pulse ----------
sub = np.zeros(N)
for i, root in enumerate(ROOTS):
    start, end = i * BAR, min((i + 1) * BAR, DUR)
    env = smoothstep_gate(start - 0.1, end + 0.1, ramp=0.3)
    sub += env * np.sin(2 * np.pi * note(root) * 2 * t)  # one octave up from written root
sub *= 0.65 + 0.35 * duck

# ---------- kick pulse (from 3.2s on) ----------
kick_len = int(0.35 * SR)
kt = np.arange(kick_len) / SR
kick_freq = 45 + 75 * np.exp(-kt / 0.045)
one_kick = np.sin(2 * np.pi * np.cumsum(kick_freq) / SR) * np.exp(-kt / 0.11)
kick = np.zeros(N)
for b in np.arange(0, DUR, BEAT):
    if b < 3.2 - 1e-9 or b > DUR - 2.0:
        continue
    i0 = int(b * SR)
    seg = min(kick_len, N - i0)
    kick[i0:i0 + seg] += one_kick[:seg]

# ---------- hats: filtered noise ticks on offbeats (features + outro) ----------
hat_len = int(0.07 * SR)
ht = np.arange(hat_len) / SR
noise = rng.standard_normal(hat_len)
one_hat = (noise - fir_lowpass(noise, 6000, taps=129)) * np.exp(-ht / 0.018)
hats = np.zeros(N)
for b in np.arange(BEAT / 2, DUR, BEAT):
    if b < 3.2 or b > DUR - 2.2:
        continue
    i0 = int(b * SR)
    seg = min(hat_len, N - i0)
    hats[i0:i0 + seg] += one_hat[:seg]

# ---------- arp: 16th plucks, A-minor pentatonic, with echo ----------
ARP_NOTES = ["A3", "C4", "E4", "A4", "G4", "E4", "D4", "C4"]
pluck_len = int(0.28 * SR)
pt = np.arange(pluck_len) / SR
arpL = np.zeros(N)
arpR = np.zeros(N)
step = BEAT / 4
arp_gate_ranges = [(3.2, 15.4), (19.4, DUR - 1.6)]
k = 0
for b in np.arange(0, DUR, step):
    in_gate = any(s <= b < e for s, e in arp_gate_ranges)
    if not in_gate:
        k += 1
        continue
    f = note(ARP_NOTES[k % len(ARP_NOTES)])
    pluck = (np.sin(2 * np.pi * f * pt) + 0.3 * np.sin(4 * np.pi * f * pt)) * np.exp(-pt / 0.07)
    i0 = int(b * SR)
    seg = min(pluck_len, N - i0)
    arpL[i0:i0 + seg] += pluck[:seg] * 0.85
    arpR[i0:i0 + seg] += pluck[:seg] * 0.85
    iecho = int((b + step * 3) * SR)          # dotted-8th echo, ping-pong
    seg2 = min(pluck_len, N - iecho)
    if seg2 > 0:
        if (k % 2) == 0:
            arpR[iecho:iecho + seg2] += pluck[:seg2] * 0.30
        else:
            arpL[iecho:iecho + seg2] += pluck[:seg2] * 0.30
    k += 1

# ---------- riser into the outro cut (17.2 -> 19.35) + impact at 19.4 ----------
riser_noise = rng.standard_normal(N)
riser_band = fir_lowpass(riser_noise, 7000) - fir_lowpass(riser_noise, 500)
ramp = np.clip((t - 17.2) / (19.35 - 17.2), 0, 1)
riser = riser_band * (ramp ** 2.5) * (t < 19.35)

imp_len = int(1.2 * SR)
it = np.arange(imp_len) / SR
impact_wave = np.sin(2 * np.pi * (38 + 50 * np.exp(-it / 0.06)).cumsum() / SR) * np.exp(-it / 0.35)
impact = np.zeros(N)
i0 = int(19.4 * SR)
seg = min(imp_len, N - i0)
impact[i0:i0 + seg] = impact_wave[:seg]

# ---------- mix ----------
pad_gain = 0.34 * duck * (0.55 + 0.45 * smoothstep_gate(0.0, DUR, ramp=3.2))
L = padL * pad_gain + sub * 0.30 + kick * 0.50 + hats * 0.05 + arpL * 0.15 + riser * 0.10 + impact * 0.5
R = padR * pad_gain + sub * 0.30 + kick * 0.50 + hats * 0.05 + arpR * 0.15 + riser * 0.10 + impact * 0.5

mix = np.stack([L, R], axis=1)
mix = np.tanh(1.4 * mix) / np.tanh(1.4)          # gentle glue/soft clip
mix /= np.max(np.abs(mix))
mix *= 0.85

fade_in = int(0.06 * SR)
fade_out = int(2.4 * SR)
mix[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
mix[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None] ** 1.5

out = str(__import__("pathlib").Path(__file__).parent / "bgm.wav")
sf.write(out, mix.astype(np.float32), SR)
print(f"wrote {out} dur={N/SR:.1f}s peak={np.max(np.abs(mix)):.2f}")
