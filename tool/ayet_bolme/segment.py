"""Sure ses dosyasındaki ayet sınırlarını sessizliklerden bulur."""
import json
import subprocess
import sys
import urllib.request

import numpy as np

SR = 8000
HOP = 0.02  # 20 ms çerçeve


def envelope(path):
    raw = subprocess.run(
        ['ffmpeg', '-v', 'quiet', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32)
    n = int(SR * HOP)
    frames = x[: len(x) // n * n].reshape(-1, n)
    rms = np.sqrt((frames ** 2).mean(axis=1) + 1e-9)
    return 20 * np.log10(rms + 1e-9)


def silences(db, min_len=0.25, factor=0.30):
    """(başlangıç, bitiş, uzunluk) saniye cinsinden sessiz aralıklar."""
    floor = np.percentile(db, 10)
    speech = np.percentile(db, 70)
    thr = floor + (speech - floor) * factor
    quiet = db < thr
    out, start = [], None
    for i, q in enumerate(np.append(quiet, False)):
        if q and start is None:
            start = i
        elif not q and start is not None:
            if (i - start) * HOP >= min_len:
                out.append((start * HOP, i * HOP, (i - start) * HOP))
            start = None
    return out, len(db) * HOP


def segment(path, n_segments):
    """En uzun n-1 sessizliği sınır sayar; (başlangıç, bitiş) listesi."""
    db = envelope(path)
    sil, total = silences(db)
    # baştaki/sondaki sessizlik sınır değil
    inner = [s for s in sil if s[0] > 0.5 and s[1] < total - 0.5]
    picked = sorted(sorted(inner, key=lambda s: -s[2])[: n_segments - 1], key=lambda s: s[0])
    cuts = [(s[0] + s[1]) / 2 for s in picked]
    head = sil[0][1] if sil and sil[0][0] <= 0.05 else 0.0
    tail = sil[-1][0] if sil and sil[-1][1] >= total - 0.05 else total
    bounds = [head] + cuts + [tail]
    gaps = sorted(inner, key=lambda s: -s[2])
    margin = (gaps[n_segments - 2][2], gaps[n_segments - 1][2]) if len(gaps) >= n_segments else None
    return [(bounds[i], bounds[i + 1]) for i in range(len(bounds) - 1)], margin


if __name__ == '__main__':
    path, n = sys.argv[1], int(sys.argv[2])
    segs, margin = segment(path, n)
    print(json.dumps({'segments': segs, 'margin': margin}))
