"""İki Türk hoca için tam hizalama (sure başına iki hedef, ortak referanslar).

Çıktı: words_<ad>_w<i>.json  {sure: {"b": [başla, bitir] | yok,
                                     "v": [[ayet_başı, ayet_sonu, [kelime_ofsetleri]]]}}
Kelime ofsetleri ayet başından ms; sıra Quran.com kelime sırasıdır.
"""
import json
import os
import sys
import time

import numpy as np

import align as A
import batch
import dtw_align as D
from consensus import ref_timing, word_lists
from fit_weights import feats

REFS = (6, 9, 7)
THR = 250.0
BETA = np.array(json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'beta_tuned.json'))))
TARGETS = {
    'danis': 'https://archive.org/download/ishak_danish/{:03d}.mp3',
    'collak': 'https://archive.org/download/rabieaaa2015_yahoo_002132432/{:03d}.mp3',
}
SKIP = {('collak', 38), ('collak', 52)}  # bozuk dosyalar


def words_text(surah):
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'qtext', f'{surah}.json')
    if not os.path.exists(p):
        import urllib.request
        os.makedirs(os.path.dirname(p), exist_ok=True)
        req = urllib.request.Request(
            f'https://api.quran.com/api/v4/quran/verses/uthmani?chapter_number={surah}',
            headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=60) as r:
            open(p, 'wb').write(r.read())
    import wordsync
    return [wordsync.arabic_tokens(v['text_uthmani'])
            for v in json.load(open(p, encoding='utf-8'))['verses']]


def process(surah, refs_data, name):
    url = TARGETS[name].format(surah)
    db = batch.envelope_stream(url)
    A.envelope = lambda x: x
    _, intro = A.align_intro(db, batch.ref_durations(surah), surah)
    T, _ = D.mfcc_stream(url)
    off = int(intro[1] * 50) if intro else 0           # girişi kes
    Tsub = T[off:]
    total = len(Tsub) * 0.02
    ref_durs = np.array(batch.ref_durations(surah), float)
    cum = np.concatenate([[0], np.cumsum(ref_durs)]) / ref_durs.sum() * total
    guess = [(cum[i], cum[i + 1]) for i in range(len(ref_durs))]
    per_ref = []
    for R, wl in refs_data:
        res = D.align_surah(R, Tsub, [(a, b, s) for a, b, s, _ in wl], guess, band_s=20.0)
        per_ref.append((res, wl))
    toks = words_text(surah)
    n = len(ref_durs)
    verses = []
    for k in range(n):
        starts = [res[k][0][0] for res, _ in per_ref if res[k][0]]
        vs = float(np.median(starts))
        words = {}
        for res, wl in per_ref:
            for wno, t in zip(wl[k][3], res[k][0]):
                words.setdefault(wno, []).append(t)
        verses.append([vs, words])
    out_v = []
    base = off * 20
    for k in range(n):
        vs = verses[k][0]
        if k > 0:
            vs = max(vs, out_v[-1][0] - base + 200)
        ve = verses[k + 1][0] if k + 1 < n else total * 1000
        ve = max(ve, vs + 300)
        nw = max(len(toks[k]), max(verses[k][1]) if verses[k][1] else 1)
        X = np.array([feats(toks[k][i] if i < len(toks[k]) else 'ا', i == nw - 1) for i in range(nw)])
        w = np.maximum(X @ BETA, 0.2)
        anchors = [(0, vs)]
        for i in range(1, nw):
            ts = verses[k][1].get(i + 1)
            if ts and len(ts) > 1 and np.ptp(ts) < THR:
                t = float(np.median(ts))
                if anchors[-1][1] < t < ve:
                    anchors.append((i, t))
        anchors.append((nw, ve))
        starts = []
        for (i0, t0), (i1, t1) in zip(anchors, anchors[1:]):
            ww = w[i0:i1]
            c = np.concatenate([[0], np.cumsum(ww)])[:-1] / ww.sum()
            starts += list(t0 + c * (t1 - t0))
        starts = np.maximum.accumulate(starts[:nw])
        out_v.append([round(vs + base), round(ve + base),
                      [int(round(s - vs)) for s in starts]])
    rec = {'v': out_v}
    if intro:
        rec['b'] = [round(intro[0] * 1000), round(intro[1] * 1000)]
    return rec


def main(worker, workers):
    here = os.path.dirname(os.path.abspath(__file__))
    outs = {}
    for name in TARGETS:
        p = os.path.join(here, f'words_{name}_w{worker}.json')
        outs[name] = (p, json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {})
    for surah in range(1, 115):
        if (surah - 1) % workers != worker:
            continue
        todo = [n for n in TARGETS if str(surah) not in outs[n][1] and (n, surah) not in SKIP]
        if not todo:
            continue
        t0 = time.time()
        try:
            refs_data = []
            for r in REFS:
                f = ref_timing(r, surah)
                R, _ = D.mfcc_stream(f['audio_url'])
                refs_data.append((R, word_lists(f)))
            for name in todo:
                for attempt in range(3):
                    try:
                        outs[name][1][str(surah)] = process(surah, refs_data, name)
                        break
                    except Exception as e:
                        print(f'{name} {surah} hata {e}, tekrar', flush=True)
                        time.sleep(5)
                p, d = outs[name]
                json.dump(d, open(p, 'w', encoding='utf-8'), separators=(',', ':'))
            del refs_data
        except Exception as e:
            print(f'{surah} referans hatasi {e}', flush=True)
            continue
        print(f'sure {surah:3d} bitti {time.time() - t0:5.0f} sn', flush=True)
    print(f'w{worker} BITTI', flush=True)


if __name__ == '__main__':
    main(int(sys.argv[1]), int(sys.argv[2]))
