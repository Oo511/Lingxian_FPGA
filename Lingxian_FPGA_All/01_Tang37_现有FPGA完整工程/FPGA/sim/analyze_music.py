"""Measure RTL PCM and create listening copies; this is not a board recording."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
FS = 50_000_000 / 1024


def wav_file(path, pcm):
    # Resample the actual fractional DAC rate to a standard WAV sample rate.
    t = np.arange(int(len(pcm) * 48000 / FS)) * FS / 48000
    out = np.interp(t, np.arange(len(pcm)), pcm) * 8
    assert np.max(np.abs(out)) < 32767
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(48000)
        f.writeframes(np.rint(out).astype('<i2').tobytes())


def measure(pcm, hz, early, late):
    n = 8192
    data = pcm[64:64+n]
    spec = np.abs(np.fft.rfft(data * np.hanning(n)))
    peak = np.argmax(spec[1:]) + 1
    # Parabolic interpolation of the FFT main lobe.
    a, b, c = np.log(np.maximum(spec[peak-1:peak+2], 1e-9))
    measured = (peak + .5*(a-c)/(a-2*b+c)) * FS/n
    rms = lambda start, end: float(np.sqrt(np.mean(pcm[int(start*FS):int(end*FS)]**2)))
    assert abs(measured-hz) < 1, (measured, hz)
    assert np.max(np.abs(pcm)) < 32767
    first, last = rms(*early), rms(*late)
    assert last < first * .4, (first, last)
    assert np.max(np.abs(pcm[-1000:])) == 0
    return {'expected_hz': hz, 'fft_hz': float(measured),
            'early_rms': first, 'late_rms': last,
            'peak': float(np.max(np.abs(pcm)))}


pcm = np.loadtxt(ROOT/'FPGA/sim/results/music_samples.txt')
result = {
    'source': 'voice_ex RTL simulation; not board audio',
    'sample_rate': FS,
    'piano': measure(pcm[:, 0], 261.625565, (.02, .08), (.65, .75)),
    'guitar': measure(pcm[:, 1], 82.406889, (.005, .03), (.25, .30)),
    'wav_gain': 8,
}
for label, samples in [('after', pcm), ('before', np.loadtxt(ROOT/'reports/music_before.txt'))]:
    for i, instrument in enumerate(['piano', 'guitar']):
        wav_file(ROOT/'reports'/f'{instrument}_{label}.wav', samples[:, i])
(ROOT/'reports/music_analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print('PASS C4/E2 pitch, natural decay, silence and unclipped PCM; four WAV previews written')
