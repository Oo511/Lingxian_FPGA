from pathlib import Path
import numpy as np
import json
root=Path(__file__).resolve().parent/'results'
s=np.loadtxt(root/'contest_samples.txt')
fs=48828.125
f=np.fft.rfftfreq(len(s),1/fs)
a=abs(np.fft.rfft(s*np.hanning(len(s))))
tones=[]
peak_bins=[]
for note in range(48,80):
    target=440*2**((note-69)/12)
    bins=np.where(abs(f-target)<1.5)[0]
    peak=bins[np.argmax(a[bins])]
    prominence=float(a[peak]/a.max())
    error=float(abs(f[peak]-target))
    assert prominence>.03, f'missing/weak tone {note}: {prominence:.4f}'
    assert error<1.0, f'tone {note} off pitch by {error:.3f}Hz'
    peak_bins.append(int(peak))
    tones.append({'midi':note,'expected_hz':target,'fft_hz':float(f[peak]),'prominence':prominence})
assert max(abs(s))<32767
assert len(set(peak_bins))==32, 'two notes share one FFT peak'
resolution=fs/len(s)
(root/'32_tones.json').write_text(json.dumps({'source':'RTL simulation, not board measurement','fs':fs,
 'fft_resolution_hz':resolution,'independent_peaks':len(set(peak_bins)),
 'peak':float(max(abs(s))),'tones':tones},indent=2))
print(f'PASS 32 distinct frequency peaks, <1Hz bin error and no clipping; FFT resolution {resolution:.3f}Hz')
