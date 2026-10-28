import json, random
import numpy as np
from fit_weights import load
beta = np.array(json.load(open('beta_tuned.json')))
random.seed(2)
train = random.sample([x for r in (6, 7, 9, 2) for s in (2, 18) for x in load(r, s)], 400)
test = [x for r in (3, 5, 10, 4) for s in (36, 55, 67, 87) for x in load(r, s)]

def acc(data, lead, tail):
    hit = near = n = 0
    for X, d, segs, t0, t1 in data:
        w = np.maximum(X @ beta, 0.2)
        tot = lead + w.sum() + tail
        ends = (lead + np.cumsum(w)) / tot
        dur = t1 - t0
        starts = [g[1] - t0 for g in segs]
        for t in range(int(starts[0]), int(dur), 20):
            tw = int(np.searchsorted(starts, t, side='right')) - 1
            pw = min(int(np.searchsorted(ends, t / dur, side='right')), len(w) - 1)
            n += 1; hit += pw == tw; near += abs(pw - tw) <= 1
    return 100 * hit / n, 100 * near / n

best = None
for lead in (0, 1, 2, 4, 6):
    for tail in (0, 1, 2, 4, 6):
        a = acc(train, lead, tail)[0]
        if best is None or a > best[0]: best = (a, lead, tail)
print('en iyi egitim', best, flush=True)
print('TEST lead=0.6 tail=0:', acc(test, 0.6, 0))
print(f'TEST lead={best[1]} tail={best[2]}:', acc(test, best[1], best[2]))
