"""İki hafızın 114 suresini ayetlere böler; sonuç: timings_<ad>.json.

Ses diske indirilmez: ffmpeg adresten akışla çözer, yalnızca 20 ms'lik
seviye özeti bellekte tutulur. Kaldığı yerden devam eder.
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

import numpy as np

import segment
import align as A

SR = segment.SR
HOP = segment.HOP
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

RECITERS = {
    'danis': 'https://archive.org/download/ishak_danish/{:03d}.mp3',
    'collak': 'https://archive.org/download/rabieaaa2015_yahoo_002132432/{:03d}.mp3',
}


def envelope_stream(url):
    n = int(SR * HOP)
    proc = subprocess.Popen(
        ['ffmpeg', '-v', 'quiet', '-reconnect', '1', '-reconnect_streamed', '1',
         '-i', url, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        stdout=subprocess.PIPE)
    out = []
    rest = b''
    while True:
        chunk = proc.stdout.read(n * 2 * 500)
        if not chunk:
            break
        buf = rest + chunk
        usable = len(buf) // (n * 2) * (n * 2)
        x = np.frombuffer(buf[:usable], dtype=np.int16).astype(np.float32).reshape(-1, n)
        out.append(20 * np.log10(np.sqrt((x ** 2).mean(axis=1) + 1e-9) + 1e-9))
        rest = buf[usable:]
    proc.wait()
    if proc.returncode != 0 or not out:
        raise RuntimeError(f'ffmpeg {proc.returncode}')
    return np.concatenate(out)


def ref_durations(surah):
    path = os.path.join(OUT_DIR, 'ref', f'{surah}.json')
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        url = f'https://api.qurancdn.com/api/qdc/audio/reciters/7/audio_files?chapter={surah}&segments=true'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=60) as r:
            open(path, 'wb').write(r.read())
    vt = json.load(open(path, encoding='utf-8'))['audio_files'][0]['verse_timings']
    return [t['timestamp_to'] - t['timestamp_from'] for t in vt]


def main(name, worker, workers):
    out_path = os.path.join(OUT_DIR, f'timings_{name}_w{worker}.json')
    done = json.load(open(out_path, encoding='utf-8')) if os.path.exists(out_path) else {}
    base = os.path.join(OUT_DIR, f'timings_{name}.json')
    skip = set(json.load(open(base, encoding='utf-8'))) if os.path.exists(base) else set()
    A.envelope = None  # align içinde envelope'u biz veriyoruz
    for s in range(1, 115):
        if (s - 1) % workers != worker or str(s) in done or str(s) in skip:
            continue
        t0 = time.time()
        for attempt in range(3):
            try:
                db = envelope_stream(RECITERS[name].format(s))
                break
            except Exception as e:  # ağ hatası: tekrar dene
                print(f'{name} {s} hata {e}, tekrar', flush=True)
                time.sleep(5)
        else:
            continue
        A.envelope = lambda _p, db=db: db
        segs, prefix = A.align(None, ref_durations(s))
        done[str(s)] = {
            'p': prefix,
            'v': [[round(a * 1000), round(b * 1000)] for a, b in segs],
        }
        json.dump(done, open(out_path, 'w', encoding='utf-8'), separators=(',', ':'))
        print(f'{name} {s:3d} {len(segs):3d} ayet {len(db) * HOP / 60:5.1f} dk  {time.time() - t0:5.1f} sn', flush=True)
    print(f'{name} w{worker} BITTI {len(done)}', flush=True)


if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
