#!/usr/bin/env python3
"""Synthesise the click voices for Detent.

Every voice is built from the same two ingredients a real mechanical detent
makes: a broadband noise transient (the strike) and a handful of decaying
resonant modes (the body ringing afterwards). Stdlib only.
"""

import math
import os
import random
import struct
import wave

SR = 48000


def biquad_bandpass(x, f0, q):
    """Constant-skirt bandpass, peak gain = Q."""
    w0 = 2 * math.pi * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for s in x:
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, s
        y2, y1 = y1, y
        out.append(y)
    return out


def highpass_1pole(x, fc):
    """Keeps the speaker from flapping on the low voices."""
    rc = 1.0 / (2 * math.pi * fc)
    a = rc / (rc + 1.0 / SR)
    out = []
    prev_x = prev_y = 0.0
    for s in x:
        y = a * (prev_y + s - prev_x)
        out.append(y)
        prev_x, prev_y = s, y

    return out


def noise_burst(n, tau_ms, seed):
    rng = random.Random(seed)
    tau = tau_ms / 1000.0
    return [(rng.random() * 2 - 1) * math.exp(-(i / SR) / tau) for i in range(n)]


def mode(n, f0, tau_ms, amp, f1=None):
    """A decaying sine. If f1 is given the pitch glides f0 -> f1."""
    tau = tau_ms / 1000.0
    dur = n / SR
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 if f1 is None else f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * f / SR
        out.append(amp * math.sin(phase) * math.exp(-t / tau))
    return out


def mix(n, *layers):
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def finish(buf, fade_ms=2.0, peak=0.89):
    """Fade the tail to zero, block DC, normalise."""
    n = len(buf)
    fade = min(n, int(SR * fade_ms / 1000.0))
    for i in range(fade):
        w = 0.5 * (1 + math.cos(math.pi * i / fade))
        buf[n - fade + i] *= w
    buf = highpass_1pole(buf, 55.0)
    m = max(abs(s) for s in buf) or 1.0
    return [s * peak / m for s in buf]


def write_wav(path, buf):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(
            b"".join(
                struct.pack("<h", max(-32768, min(32767, int(s * 32767))))
                for s in buf
            )
        )


def n_of(ms):
    return int(SR * ms / 1000.0)


def v_detent():
    n = n_of(20)
    strike = biquad_bandpass(noise_burst(n, 0.7, 1), 2500, 2.0)
    return mix(n, [s * 1.0 for s in strike], mode(n, 2400, 3.5, 0.30),
               mode(n, 5200, 1.2, 0.14))


def v_wood():
    n = n_of(30)
    strike = biquad_bandpass(noise_burst(n, 0.9, 2), 1200, 1.4)
    return mix(n, [s * 0.55 for s in strike], mode(n, 780, 11.0, 0.42),
               mode(n, 1180, 7.0, 0.26), mode(n, 2350, 3.5, 0.13))


def v_plop():
    n = n_of(28)
    strike = biquad_bandpass(noise_burst(n, 0.5, 3), 900, 1.0)
    return mix(n, [s * 0.22 for s in strike],
               mode(n, 340, 7.0, 0.75, f1=130), mode(n, 690, 3.0, 0.16))


def v_blip():
    n = n_of(13)
    strike = biquad_bandpass(noise_burst(n, 0.4, 4), 4200, 2.5)
    return mix(n, [s * 0.35 for s in strike], mode(n, 3200, 2.6, 0.55),
               mode(n, 6300, 1.0, 0.12))


def v_tick():
    n = n_of(16)
    strike = biquad_bandpass(noise_burst(n, 1.1, 5), 5200, 1.2)
    return mix(n, [s * 1.0 for s in strike], mode(n, 430, 4.0, 0.10))


def v_snap():
    n = n_of(24)
    strike = biquad_bandpass(noise_burst(n, 2.2, 6), 900, 3.0)
    return mix(n, [s * 0.8 for s in strike],
               mode(n, 620, 8.5, 0.40, f1=470), mode(n, 1500, 3.0, 0.12))


def v_pop():
    n = n_of(22)
    strike = biquad_bandpass(noise_burst(n, 0.6, 7), 1800, 1.6)
    return mix(n, [s * 0.30 for s in strike],
               mode(n, 180, 5.5, 0.70, f1=900), mode(n, 1250, 2.5, 0.14))


VOICES = {
    "detent": v_detent,   # crisp mechanical notch
    "wood":   v_wood,     # warm wooden tok
    "plop":   v_plop,     # low, round drop
    "blip":   v_blip,     # tight and high
    "tick":   v_tick,     # dry vinyl tick
    "snap":   v_snap,     # rubbery snap
    "pop":    v_pop,      # gluey upward pop
}


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "Resources", "sounds")
    out_dir = os.path.normpath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in VOICES.items():
        buf = finish(fn())
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, buf)
        print("%-7s %5d frames  %5.1f ms  ->  %s"
              % (name, len(buf), len(buf) / SR * 1000, path))


if __name__ == "__main__":
    main()
