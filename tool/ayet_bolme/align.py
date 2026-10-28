"""Sure sesini, referans hafızın ayet sürelerine göre ayetlere böler.

Aday sınırlar = sessizlikler. Dinamik programlama ile, ayet sürelerinin
referans oranlarına en iyi uyduğu ve uzun sessizliklerin tercih edildiği
sınır dizisi seçilir.
"""
import math

import numpy as np

from segment import envelope, silences, HOP


def align(path, ref_durations, allow_prefix=True):
    db = envelope(path)
    ref = np.asarray(ref_durations, float)
    # Önce sıkı ayarlar; duraklama bulunamazsa eşiği gevşet, pencereyi genişlet.
    for factor, min_len, wide in ((0.30, 0.15, False), (0.30, 0.15, True),
                                  (0.42, 0.10, True), (0.55, 0.06, True)):
        sil, total = silences(db, min_len=min_len, factor=factor)
        head = sil[0][1] if sil and sil[0][0] <= 0.05 else 0.0
        tail = sil[-1][0] if sil and sil[-1][1] >= total - 0.05 else total
        cands = [(a + (b - a) * 0.75, l) for a, b, l in sil if a > head + 0.3 and b < tail - 0.3]
        if len(cands) < len(ref) - 1:
            continue
        best = _dp(cands, head, tail, ref, allow_prefix, wide)
        if best is not None:
            b = best[1]
            # ön parça (istiaze/besmele): sesin başından 1. ayete kadar
            prefix = [round(head * 1000), round(b[0] * 1000)] if best[2] > 0 else None
            return [(b[i], b[i + 1]) for i in range(len(ref))], prefix
    # Son çare: referans oranlarına göre böl.
    sil, total = silences(db)
    head = sil[0][1] if sil and sil[0][0] <= 0.05 else 0.0
    tail = sil[-1][0] if sil and sil[-1][1] >= total - 0.05 else total
    cum = np.concatenate([[0], np.cumsum(ref / ref.sum())]) * (tail - head) + head
    return [(float(cum[i]), float(cum[i + 1])) for i in range(len(ref))], None


INF = 1e18


def _dp(cands, head, tail, ref, allow_prefix, wide):
    times = np.array([head] + [c[0] for c in cands] + [tail])
    lens = np.array([1.0] + [c[1] for c in cands] + [1.0])
    m = len(times)
    n = len(ref)
    best = None
    # baştaki istiaze/besmele için serbest ön parça: 0 ya da 1 aday atla
    starts = [0] + ([j for j in range(1, min(m - 1, 40))] if allow_prefix else [])
    for s0 in starts:
        span = tail - times[s0]
        if span <= 0:
            continue
        exp = ref / ref.sum() * span  # beklenen ayet süreleri
        cum = np.concatenate([[0], np.cumsum(exp)]) + times[s0]
        cost = np.full((n + 1, m), INF)
        back = np.zeros((n + 1, m), int)
        cost[0, s0] = 0.0
        for k in range(1, n + 1):
            # k. sınırın beklenen yeri etrafında makul pencere
            w = max(8.0, 0.35 * exp[:k].sum() ** 0.5 * 6)
            if wide:
                w = max(w * 3, span * 0.25)
            lo = np.searchsorted(times, cum[k] - w)
            hi = np.searchsorted(times, cum[k] + w)
            if k == n:
                lo, hi = m - 1, m
            prev = np.where(cost[k - 1] < INF)[0]
            if len(prev) == 0:
                break
            for j in range(max(lo, 1), min(hi, m)):
                p = prev[prev < j]
                if len(p) == 0:
                    continue
                d = times[j] - times[p]
                c = cost[k - 1, p] + 4.0 * np.log(np.maximum(d, 0.05) / exp[k - 1]) ** 2
                i = int(np.argmin(c))
                bonus = 0.0 if k == n else -0.8 * math.log(lens[j] / 0.15 + 1)
                cost[k, j] = c[i] + bonus
                back[k, j] = p[i]
        if cost[n, m - 1] >= INF:
            continue
        total_cost = cost[n, m - 1] + (0 if s0 == 0 else 1.5)
        if best is None or total_cost < best[0]:
            path_idx = [m - 1]
            for k in range(n, 0, -1):
                path_idx.append(back[k, path_idx[-1]])
            path_idx.reverse()
            best = (total_cost, [float(times[i]) for i in path_idx], s0)
    return best


ISTIAZE_MS, BESMELE_MS = 5500.0, 6090.0  # Alafasi ölçeğinde beklenen süreler


def align_intro(db, ref_durations, surah):
    """Surenin başındaki istiaze/besmeleyi açıkça modelleyerek ayetlere böler.

    Dönüş: (ayetler [(a, b)], giriş (a, b) ya da None) saniye cinsinden.
    Giriş, varsa istiaze + besmeledir (Fâtiha'da besmele 1. ayettir).
    """
    ref = list(map(float, ref_durations))
    if surah == 1 or surah == 9:
        variants = [[], [ISTIAZE_MS]]
    else:
        # Türk hocalar sure başında besmeleyi okur; istiaze isteğe bağlı.
        variants = [[BESMELE_MS], [ISTIAZE_MS, BESMELE_MS]]
    best = None
    for factor, min_len, wide in ((0.30, 0.15, False), (0.30, 0.15, True),
                                  (0.42, 0.10, True), (0.55, 0.06, True)):
        sil, total = silences(db, min_len=min_len, factor=factor)
        head = sil[0][1] if sil and sil[0][0] <= 0.05 else 0.0
        tail = sil[-1][0] if sil and sil[-1][1] >= total - 0.05 else total
        cands = [(a + (b - a) * 0.75, l) for a, b, l in sil if a > head + 0.3 and b < tail - 0.3]
        for intro in variants:
            seq = np.array(intro + ref)
            if len(cands) < len(seq) - 1:
                continue
            r = _dp(cands, head, tail, seq, False, wide)
            if r is None:
                continue
            cost = r[0] + (0.8 if ISTIAZE_MS in intro else 0.0)
            if best is None or cost < best[0]:
                best = (cost, r[1], len(intro))
        if best is not None:
            break
    if best is None:
        segs, _ = align(db, ref_durations, allow_prefix=False)
        return segs, None
    b, k = best[1], best[2]
    verses = [(b[i], b[i + 1]) for i in range(k, k + len(ref))]
    intro = (b[0], b[k]) if k > 0 else None
    return verses, intro
