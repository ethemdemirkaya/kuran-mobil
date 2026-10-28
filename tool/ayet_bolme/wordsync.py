"""Ayet içinde kelime zamanlaması: duraklamalara sabitlenmiş tahmin.

Uygulamadaki words.dart ile aynı ağırlıkları kullanır. Ses seviyesinden
nefes aralarını bulur, bunları metindeki kelime sınırlarıyla (tercihen vakıf
işaretleri / noktalama) dinamik programlamayla eşleştirir. Sonuç: çapa listesi
[(kelime_sırası, ms)], kelimenin başladığı an.
"""
import math
import re

import numpy as np

HOP = 0.02
_letter = re.compile('[ء-يٱ-ۓ]')


def arabic_tokens(text):
    out, prefix = [], ''
    for part in text.split():
        if _letter.search(part):
            out.append(prefix + part)
            prefix = ''
        elif out:
            out[-1] += ' ' + part
        else:
            prefix += part + ' '
    return out


def meal_tokens(text):
    return [w for w in text.split() if w]


def arabic_weight(w):
    weight = 1.0
    for ch in w:
        r = ord(ch)
        if _letter.match(ch):
            weight += 1
        elif r == 0x0653:
            weight += 3
        elif r in (0x0670, 0x0656, 0x06E4):
            weight += 1.2
        elif r == 0x0651:
            weight += 0.5
        elif 0x06D6 <= r <= 0x06DC:
            weight += 2.5
    return weight


def meal_weight(w):
    weight = 1.2 + len(w)
    if w[-1] in ',;:':
        weight += 3
    if w[-1] in '.!?':
        weight += 5
    return weight


def arabic_break(w):
    """Bu kelimeden sonra durmak ne kadar doğal (0..1)."""
    if any(0x06D6 <= ord(c) <= 0x06DC for c in w):
        return 1.0
    return 0.0


def meal_break(w):
    if w[-1] in '.!?;:':
        return 1.0
    if w[-1] in ',)':
        return 0.8
    return 0.0


def proportional(weights, lead=0.6):
    total = lead + sum(weights)
    acc, ends = lead, []
    for w in weights:
        acc += w
        ends.append(acc / total)
    return ends


def detect(db, thr, min_pause=0.16):
    """Konuşma başı/sonu ve iç duraklamalar (saniye)."""
    speech = np.where(db >= thr)[0]
    if len(speech) == 0:
        return 0.0, len(db) * HOP, []
    head, tail = speech[0] * HOP, (speech[-1] + 1) * HOP
    quiet = db < thr
    pauses, start = [], None
    for i in range(speech[0], speech[-1] + 1):
        if quiet[i] and start is None:
            start = i
        elif not quiet[i] and start is not None:
            if (i - start) * HOP >= min_pause:
                pauses.append((start * HOP, i * HOP))
            start = None
    return head, tail, pauses


def anchors(db, thr, weights, breaks):
    """[(kelime_sırası, başlangıç_sn)] — ilk kelime konuşma başında."""
    head, tail, pauses = detect(db, thr)
    n = len(weights)
    if n <= 1 or not pauses:
        return [(0, head, head)], head, tail
    total_pause = sum(b - a for a, b in pauses)
    speech_total = max(tail - head - total_pause, 0.1)
    cumw = np.concatenate([[0], np.cumsum(weights)])
    rate = speech_total / cumw[-1]

    # her duraklamanın başına kadar geçen konuşma süresi
    before, acc, prev = [], 0.0, head
    for a, b in pauses:
        acc += a - prev
        before.append(acc)
        prev = b
    P = len(pauses)
    INF = 1e18
    # dp[p][k]: p. duraklamaya kadar, son eşleşen sınır k (kelime k'dan sonra), maliyet
    dp = np.full((P + 1, n), INF)
    back = {}
    dp[0][0] = 0.0  # k=0: henüz sınır yok (sanal)
    for p in range(1, P + 1):
        a, b = pauses[p - 1]
        plen = b - a
        for k in range(n):
            if dp[p - 1][k] >= INF:
                continue
            # 1) duraklamayı yok say (uzatma/iç nefes)
            c = dp[p - 1][k] + 2.0 * plen
            if c < dp[p][k]:
                dp[p][k] = c
                back[(p, k)] = (p - 1, k)
            # 2) duraklamayı kelime j'den sonraki sınıra bağla (j > k)
            for j in range(k + 1, n):
                exp = cumw[j] * rate
                sigma = 0.25 + 0.12 * exp
                c = dp[p - 1][k] + ((before[p - 1] - exp) / sigma) ** 2 \
                    - 1.5 * breaks[j - 1] - 0.6 * min(plen, 1.0)
                if c < dp[p][j]:
                    dp[p][j] = c
                    back[(p, j)] = (p - 1, k)
    k = int(np.argmin(dp[P]))
    p = P
    matched = []
    while p > 0:
        pp, pk = back[(p, k)]
        if pk != k:
            # kelime k, duraklama sonunda başlar; önceki parça duraklama başında biter
            matched.append((k, pauses[p - 1][1], pauses[p - 1][0]))
        p, k = pp, pk
    matched.reverse()
    return [(0, head, head)] + matched, head, tail


def word_at(t, anchor_list, tail, weights):
    """Verilen anda (sn) okunan kelime: çapalar arasında ağırlıkla dağıtılır,
    eşleşen nefes aralarında önceki kelimede kalınır."""
    n = len(weights)
    for i in range(len(anchor_list) - 1, -1, -1):
        w0, t0, _ = anchor_list[i]
        if t >= t0:
            if i + 1 < len(anchor_list):
                w1, _, t1 = anchor_list[i + 1]
            else:
                w1, t1 = n, tail
            seg = weights[w0:w1]
            if not seg:
                return w0
            if t >= t1:
                return w1 - 1
            frac = (t - t0) / max(t1 - t0, 1e-3)
            acc, tot = 0.0, sum(seg)
            for k, w in enumerate(seg):
                acc += w
                if frac < acc / tot:
                    return w0 + k
            return w1 - 1
    return -1
