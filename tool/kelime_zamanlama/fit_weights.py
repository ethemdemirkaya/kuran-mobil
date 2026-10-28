"""Kelime süre modelini gerçek zamanlamalardan öğrenir ve sınar."""
import json
import os
import re

import numpy as np

L = re.compile('[ء-يٱ-ۓ]')


def feats(tok, last):
    letters = sum(1 for c in tok if L.match(c))
    f = [
        1.0,
        letters,
        tok.count('ٓ'),                                   # medd
        sum(tok.count(c) for c in 'ٰٖۥۦ'),  # küçük elif/vav/ye
        tok.count('ّ'),                                   # şedde
        sum(tok.count(c) for c in 'ًࣰٌࣱٍࣲ'),  # tenvin
        sum(tok.count(c) for c in 'اويىی'),  # uzun ünlü harfleri
        1.0 if any(0x06D6 <= ord(c) <= 0x06DC for c in tok) else 0.0,  # vakıf
        1.0 if last else 0.0,                                   # ayet sonu
    ]
    return f


NAMES = ['sabit', 'harf', 'medd', 'kucuk_elif', 'sedde', 'tenvin', 'uzun_unlu', 'vakif', 'ayet_sonu']


def load(r, s):
    tp = f't{r}_{s}.json'
    wp = f'w{s}.json'
    if not (os.path.exists(tp) and os.path.exists(wp)):
        return []
    tf = json.load(open(tp, encoding='utf-8'))['audio_files'][0]['verse_timings']
    words = json.load(open(wp, encoding='utf-8'))['verses']
    out = []
    for vt in tf:
        v = int(vt['verse_key'].split(':')[1])
        toks = [w['text_uthmani'] for w in words[v - 1]['words'] if w['char_type_name'] == 'word']
        segs = [g for g in vt['segments'] if len(g) == 3]
        order = [g[0] for g in segs]
        # tekrar içeren ya da eksik ayetleri atla
        if len(toks) < 2 or order != list(range(1, len(toks) + 1)):
            continue
        d = np.array([g[2] - g[1] for g in segs], float)
        if (d <= 0).any():
            continue
        X = np.array([feats(t, i == len(toks) - 1) for i, t in enumerate(toks)])
        out.append((X, d, segs, vt['timestamp_from'], vt['timestamp_to']))
    return out


def accuracy(data, weight_fn):
    hit = near = tot = 0
    for X, d, segs, t0, t1 in data:
        w = np.maximum(weight_fn(X), 0.2)
        dur = t1 - t0
        lead = 0.6 / (0.6 + w.sum())
        ends = lead + (1 - lead) * np.cumsum(w) / w.sum()
        starts = [g[1] - t0 for g in segs]
        for t in range(int(starts[0]), int(dur), 20):
            tw = int(np.searchsorted(starts, t, side='right')) - 1
            pw = int(np.searchsorted(ends, t / dur, side='right'))
            pw = min(pw, len(w) - 1)
            tot += 1
            hit += pw == tw
            near += abs(pw - tw) <= 1
    return 100 * hit / tot, 100 * near / tot


train_r, test_r = (6, 7, 9, 2), (3, 5, 10, 4)
train_s, test_s = (2, 18), (36, 55, 67, 87)
train = [x for r in train_r for s in train_s for x in load(r, s)]
test_same = [x for r in test_r for s in test_s for x in load(r, s)]
print('egitim ayet', len(train), '| test ayet', len(test_same))

# hedef: ayet içindeki göreli süre
X = np.vstack([x[0] for x in train])
y = np.concatenate([x[1] / x[1].mean() for x in train])
beta, *_ = np.linalg.lstsq(X, y, rcond=None)
print('katsayilar:', ', '.join(f'{n}={b:.3f}' for n, b in zip(NAMES, beta)))

old = lambda X: 1.0 + X[:, 1] + 3 * X[:, 2] + 1.2 * X[:, 3] + 0.5 * X[:, 4] + 2.5 * X[:, 7]
new = lambda X: X @ beta
for name, fn in (('su anki', old), ('ogrenilmis', new)):
    a, b = accuracy(test_same, fn)
    print(f'{name:11s}: tam kelime %{a:.0f}, ±1 kelime %{b:.0f}  (gormedigi hafiz + sureler)')
json.dump({'names': NAMES, 'beta': list(beta)}, open('beta.json', 'w'))
