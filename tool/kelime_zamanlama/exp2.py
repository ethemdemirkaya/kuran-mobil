import json
import numpy as np
import batch
from fit_weights import load, feats
from wordsync import anchors, word_at, arabic_break, HOP

beta = np.array(json.load(open('beta_tuned.json')))
old = np.array([1.0, 1.0, 3.0, 1.2, 0.5, 0.0, 0.0, 2.5, 0.0])
tot = {k: [0, 0, 0] for k in ('eski_oransal', 'yeni_oransal', 'eski_capali', 'yeni_capali')}
for r in (3, 5, 10, 4):
    for s in (36, 67, 87):
        data = load(r, s)
        if not data: continue
        url = json.load(open(f't{r}_{s}.json', encoding='utf-8'))['audio_files'][0]['audio_url']
        db = batch.envelope_stream(url)
        floor, sp = np.percentile(db, 10), np.percentile(db, 70)
        thr = floor + (sp - floor) * 0.30
        words = json.load(open(f'w{s}.json', encoding='utf-8'))['verses']
        for X, d, segs, t0, t1 in data:
            clip = db[int(t0 / 1000 / HOP):int(t1 / 1000 / HOP)]
            dur = len(clip) * HOP
            starts = [(g[1] - t0) / 1000 for g in segs]
            toks_brk = [1.0 if x[7] else 0.0 for x in X]
            for tag, b in (('eski', old), ('yeni', beta)):
                w = list(np.maximum(X @ b, 0.2))
                lead = 0.6 / (0.6 + sum(w))
                ends = lead + (1 - lead) * np.cumsum(w) / sum(w)
                anc, head, tail = anchors(clip, thr, w, toks_brk)
                for f in range(int(starts[0] / HOP), len(clip)):
                    t = f * HOP
                    tw = int(np.searchsorted(starts, t, side='right')) - 1
                    pw = min(int(np.searchsorted(ends, t / dur, side='right')), len(w) - 1)
                    aw = word_at(t, anc, tail, w)
                    for key, p in ((tag + '_oransal', pw), (tag + '_capali', aw)):
                        tot[key][0] += p == tw; tot[key][1] += abs(p - tw) <= 1; tot[key][2] += 1
        print(r, s, 'tamam', flush=True)
for k, (a, b, n) in tot.items():
    print(f'{k:13s}: tam %{100*a/n:.1f}  ±1 %{100*b/n:.1f}')
