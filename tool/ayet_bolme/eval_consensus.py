"""Gerçeği bilinen hafızda dürüst sınama: hedef kendisi referans listesinde yok."""
import json, sys
import numpy as np
import dtw_align as D
from consensus import consensus, ref_timing, word_lists
from fit_weights import feats
beta = np.array(json.load(open('beta_tuned.json')))
TGT = int(sys.argv[1]); REFS = [int(x) for x in sys.argv[2].split(',')]
verr, hit_c, hit_w, near_c, near_w, n = [], 0, 0, 0, 0, 0
hit_h = [0, 0]
THR = float(sys.argv[3]) if len(sys.argv) > 3 else 300
for s in (87, 67, 36, 18):
    tf = ref_timing(TGT, s)
    T, _ = D.mfcc_stream(tf['audio_url'])
    res = consensus(T, len(T) * 0.02, s, REFS)
    words = json.load(open(f'w{s}.json', encoding='utf-8'))['verses']
    for k, v in enumerate(tf['verse_timings']):
        segs = [g for g in v['segments'] if len(g) == 3]
        if [g[0] for g in segs] != list(range(1, len(segs) + 1)): continue
        tstarts = [g[1] for g in segs]
        vs, ve, wmap, spread = res[k]
        verr.append(abs(vs - v['timestamp_from']) / 1000)
        # uzlaşı kelime başları
        cw = [wmap.get(i + 1, (None, 9e9))[0] for i in range(len(segs))]
        if any(c is None for c in cw): continue
        cw = list(np.maximum.accumulate(cw))
        # karma: referansların uyuştuğu kelimeler çapa, arası katsayıyla
        sp = [wmap[i + 1][1] for i in range(len(segs))]
        toks0 = [w['text_uthmani'] for w in words[k]['words'] if w['char_type_name'] == 'word']
        X0 = np.array([feats(t, i == len(toks0) - 1) for i, t in enumerate(toks0)])
        w0 = np.maximum(X0 @ beta, 0.2)
        anchors = [(0, vs)] + [(i, cw[i]) for i in range(1, len(segs)) if sp[i] < THR] + [(len(segs), ve)]
        hs = []
        for (i0, t0), (i1, t1) in zip(anchors, anchors[1:]):
            if i1 <= i0: continue
            ww = w0[i0:i1]; c = np.concatenate([[0], np.cumsum(ww)])[:-1] / ww.sum()
            hs += list(t0 + c * (t1 - t0))
        hs = list(np.maximum.accumulate(hs[:len(segs)]))
        # tahmin: uzlaşı ayet sınırları + ayarlı katsayılar
        toks = [w['text_uthmani'] for w in words[k]['words'] if w['char_type_name'] == 'word']
        X = np.array([feats(t, i == len(toks) - 1) for i, t in enumerate(toks)])
        w = np.maximum(X @ beta, 0.2); ends = (0.6 + np.cumsum(w)) / (0.6 + w.sum())
        for t in range(int(tstarts[0]), int(v['timestamp_to']), 20):
            tw = int(np.searchsorted(tstarts, t, side='right')) - 1
            pc = max(int(np.searchsorted(cw, t, side='right')) - 1, 0)
            ph = max(int(np.searchsorted(hs, t, side='right')) - 1, 0)
            hit_h[0] += ph == tw; hit_h[1] += abs(ph - tw) <= 1
            frac = (t - vs) / max(ve - vs, 100)
            pw = min(max(int(np.searchsorted(ends, frac, side='right')), 0), len(w) - 1) if frac >= 0 else 0
            n += 1; hit_c += pc == tw; hit_w += pw == tw; near_c += abs(pc - tw) <= 1; near_w += abs(pw - tw) <= 1
    print(f'sure {s} tamam', flush=True)
e = np.array(verr)
print(f'HEDEF {TGT} (ref {REFS}): ayet basi hatasi medyan {np.median(e):.2f}sn, %90 {np.percentile(e,90):.2f}sn, >1.5sn %{100*(e>1.5).mean():.1f}')
print(f'   karma (esik {THR:.0f}ms): tam %{100*hit_h[0]/n:.1f} ±1 %{100*hit_h[1]/n:.1f}')
print(f'   kelime: uzlasi-DTW tam %{100*hit_c/n:.1f} ±1 %{100*near_c/n:.1f} | katsayi tahmini tam %{100*hit_w/n:.1f} ±1 %{100*near_w/n:.1f}')
