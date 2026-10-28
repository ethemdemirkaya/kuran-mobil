"""Çok referanslı hizalama: her ayet ve kelime başı için referansların ortancası.

Referans hafızların (Quran.com) ayet ve kelime zamanları bilinir. Hedef kayıt,
her referansa ayrı ayrı DTW ile hizalanır; ortanca alınır. Böylece tek bir
referansın yanılması sonucu bozmaz.
"""
import json
import os
import urllib.request

import numpy as np

import dtw_align as D
import batch

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ref_seg')


def ref_timing(reciter, surah):
    os.makedirs(CACHE, exist_ok=True)
    p = os.path.join(CACHE, f'{reciter}_{surah}.json')
    if not os.path.exists(p):
        url = (f'https://api.qurancdn.com/api/qdc/audio/reciters/{reciter}/audio_files'
               f'?chapter={surah}&segments=true')
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=60) as r:
            open(p, 'wb').write(r.read())
    return json.load(open(p, encoding='utf-8'))['audio_files'][0]


def word_lists(f):
    """Her ayet için (from, to, [kelime_başı]) — tekrarlı okumalarda ilk geçiş."""
    out = []
    for v in f['verse_timings']:
        seen, starts = set(), []
        for g in v['segments']:
            if len(g) == 3 and g[0] not in seen:
                seen.add(g[0])
                starts.append((g[0], g[1]))
        starts.sort()
        out.append((v['timestamp_from'], v['timestamp_to'], [s for _, s in starts],
                    [w for w, _ in starts]))
    return out


def consensus(T, total_s, surah, refs, intro_end=None):
    """Hedef MFCC'si T için ayet başları ve kelime başları (ms).

    Dönüş: [(ayet_başı_ms, ayet_sonu_ms, {kelime_no: başlangıç_ms}, yayılım_ms)]
    """
    ref_durs = np.array(batch.ref_durations(surah), float)
    # bant merkezi için kaba doğrusal tahmin (Alafasi oranları)
    lead = intro_end if intro_end else 0.0
    cum = np.concatenate([[0], np.cumsum(ref_durs)]) / ref_durs.sum() * (total_s - lead) + lead
    guess = [(cum[i], cum[i + 1]) for i in range(len(ref_durs))]
    per_ref = []
    for r in refs:
        f = ref_timing(r, surah)
        R, _ = D.mfcc_stream(f['audio_url'])
        wl = word_lists(f)
        res = D.align_surah(R, T, [(a, b, s) for a, b, s, _ in wl], guess, band_s=20.0)
        per_ref.append((res, wl))
    out = []
    n = len(ref_durs)
    for k in range(n):
        starts = [res[k][0][0] for res, _ in per_ref if res[k][0]]
        vs = float(np.median(starts)) if starts else guess[k][0] * 1000
        spread = float(np.max(starts) - np.min(starts)) if len(starts) > 1 else 0.0
        words = {}
        for res, wl in per_ref:
            for wno, t in zip(wl[k][3], res[k][0]):
                words.setdefault(wno, []).append(t)
        out.append([vs, None, {w: (float(np.median(ts)), float(np.ptp(ts)) if len(ts) > 1 else 9e9)
                               for w, ts in words.items()}, spread])
    if intro_end and n:
        out[0][0] = max(out[0][0], intro_end * 1000)
    # sıra ve sonlar
    for k in range(n):
        if k > 0 and out[k][0] <= out[k - 1][0]:
            out[k][0] = out[k - 1][0] + 200
    for k in range(n):
        out[k][1] = out[k + 1][0] if k + 1 < n else total_s * 1000
    return out
