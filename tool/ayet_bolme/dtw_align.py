"""Sesi sesle hizalama: referans hafızın kelime zamanlarını hedef hafıza taşır.

MFCC (20 ms) + ayet ayet alt-dizi DTW (numba). Bellek: ses parça parça
çözülür, yalnızca MFCC tutulur (13 x kare, float32).
"""
import subprocess

import numpy as np
from numba import njit
from scipy.fft import dct

SR = 16000
HOP = 320          # 20 ms
WIN = 400          # 25 ms
NFFT = 512
NMEL = 26
NCEP = 13


def _mel_fb():
    def hz2mel(f):
        return 2595 * np.log10(1 + f / 700)

    def mel2hz(m):
        return 700 * (10 ** (m / 2595) - 1)

    mels = np.linspace(hz2mel(60), hz2mel(7600), NMEL + 2)
    bins = np.floor((NFFT + 1) * mel2hz(mels) / SR).astype(int)
    fb = np.zeros((NMEL, NFFT // 2 + 1), np.float32)
    for m in range(1, NMEL + 1):
        a, b, c = bins[m - 1], bins[m], bins[m + 1]
        for k in range(a, b):
            fb[m - 1, k] = (k - a) / max(b - a, 1)
        for k in range(b, c):
            fb[m - 1, k] = (c - k) / max(c - b, 1)
    return fb


_FB = _mel_fb()
_WINDOW = np.hamming(WIN).astype(np.float32)


def mfcc_stream(url):
    """Adresten akışla MFCC (kare x 13) ve kare başına enerji (dB)."""
    proc = subprocess.Popen(
        ['ffmpeg', '-v', 'quiet', '-reconnect', '1', '-reconnect_streamed', '1',
         '-i', url, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        stdout=subprocess.PIPE)
    feats, energy = [], []
    buf = np.zeros(0, np.float32)
    while True:
        chunk = proc.stdout.read(SR * 2 * 30)  # 30 sn
        if not chunk:
            break
        x = np.frombuffer(chunk[: len(chunk) // 2 * 2], np.int16).astype(np.float32) / 32768
        buf = np.concatenate([buf, x])
        n = (len(buf) - WIN) // HOP + 1
        if n <= 0:
            continue
        idx = np.arange(WIN)[None, :] + HOP * np.arange(n)[:, None]
        frames = buf[idx] * _WINDOW
        spec = np.abs(np.fft.rfft(frames, NFFT)) ** 2
        mel = np.log(spec @ _FB.T + 1e-8)
        feats.append(dct(mel, type=2, axis=1, norm='ortho')[:, :NCEP].astype(np.float32))
        energy.append((10 * np.log10(frames.var(axis=1) + 1e-10)).astype(np.float32))
        buf = buf[n * HOP:]
    proc.wait()
    if not feats:
        raise RuntimeError('ses çözülemedi')
    f = np.concatenate(feats)
    f[:, 0] = 0  # enerji katsayısını at: ses düzeyi farkı hizalamayı bozmasın
    f = (f - f.mean(0)) / (f.std(0) + 1e-6)  # CMVN
    return f, np.concatenate(energy)


@njit(cache=True)
def _subseq_dtw(R, T):
    """R (n x d) tamamı, T (m x d) içinde serbest başlangıç/bitişle eşleşir.
    Dönüş: her R karesi için eşleşen ilk T karesi."""
    n, m = R.shape[0], T.shape[0]
    D = np.empty((n, m), np.float32)
    B = np.zeros((n, m), np.int8)
    for i in range(n):
        for j in range(m):
            c = 0.0
            for k in range(R.shape[1]):
                d = R[i, k] - T[j, k]
                c += d * d
            c = np.sqrt(c)
            if i == 0:
                D[i, j] = c
                B[i, j] = 0
                continue
            best = D[i - 1, j]
            b = 1  # dikey
            if j > 0:
                if D[i - 1, j - 1] <= best:
                    best = D[i - 1, j - 1]
                    b = 0  # çapraz
                if D[i, j - 1] < best:
                    best = D[i, j - 1]
                    b = 2  # yatay
            D[i, j] = best + c
            B[i, j] = b
    j = 0
    best = D[n - 1, 0]
    for jj in range(1, m):
        if D[n - 1, jj] < best:
            best = D[n - 1, jj]
            j = jj
    first = np.full(n, -1, np.int64)
    i = n - 1
    while i >= 0:
        first[i] = j
        b = B[i, j]
        if i == 0:
            break
        if b == 0:
            i -= 1
            j -= 1
        elif b == 1:
            i -= 1
        else:
            j -= 1
    return first


def map_times(R, T, t_offset_ref, t_offset_tgt, ref_times_ms):
    """Referans klibindeki zamanları (ms, mutlak) hedef zamanlara çevirir."""
    first = _subseq_dtw(R, T)
    out = []
    for t in ref_times_ms:
        i = int(round((t - t_offset_ref) / 20))
        i = min(max(i, 0), len(first) - 1)
        out.append(t_offset_tgt + int(first[i]) * 20)
    return out


@njit(cache=True)
def _banded_dtw(R, T, center, band):
    """Tüm sure: R karesi i, T içinde [center[i]-band, center[i]+band] aralığında.
    Başlangıç (0,0), bitiş (n-1,m-1). Dönüş: her R karesi için ilk T karesi."""
    n, m = R.shape[0], T.shape[0]
    W = 2 * band + 1
    INF = np.float32(1e30)
    D = np.full((n, W), INF, np.float32)
    B = np.zeros((n, W), np.int8)
    lo = np.empty(n, np.int64)
    for i in range(n):
        lo[i] = min(max(center[i] - band, 0), max(m - W, 0))
    for i in range(n):
        for w in range(W):
            j = lo[i] + w
            if j >= m:
                break
            c = 0.0
            for k in range(R.shape[1]):
                d = R[i, k] - T[j, k]
                c += d * d
            c = np.float32(np.sqrt(c))
            if i == 0 and j == 0:
                D[i, w] = c
                continue
            best = INF
            b = 0
            if i > 0:
                wd = j - 1 - lo[i - 1]
                if 0 <= wd < W and D[i - 1, wd] < best:
                    best = D[i - 1, wd]
                    b = 0
                wv = j - lo[i - 1]
                if 0 <= wv < W and D[i - 1, wv] < best:
                    best = D[i - 1, wv]
                    b = 1
            if w > 0 and D[i, w - 1] < best:
                best = D[i, w - 1]
                b = 2
            if best < INF:
                D[i, w] = best + c
                B[i, w] = b
    first = np.full(n, -1, np.int64)
    i = n - 1
    w = min(m - 1 - lo[i], W - 1)
    while True:
        j = lo[i] + w
        first[i] = j
        if i == 0 and j == 0:
            break
        b = B[i, w]
        if b == 0:
            i -= 1
            w = j - 1 - lo[i]
        elif b == 1:
            i -= 1
            w = j - lo[i]
        else:
            w -= 1
        if i < 0 or w < 0:
            break
    for k in range(n - 2, -1, -1):
        if first[k] < 0:
            first[k] = first[k + 1]
    return first


@njit(cache=True)
def _anchored_dtw(R, T, start_max):
    """Alt-dizi DTW; başlangıç yalnızca T'nin ilk start_max karesinde serbest."""
    n, m = R.shape[0], T.shape[0]
    INF = np.float32(1e30)
    D = np.full((n, m), INF, np.float32)
    B = np.zeros((n, m), np.int8)
    for i in range(n):
        for j in range(m):
            c = 0.0
            for k in range(R.shape[1]):
                d = R[i, k] - T[j, k]
                c += d * d
            c = np.float32(np.sqrt(c))
            if i == 0:
                if j < start_max:
                    D[i, j] = c
                elif D[i, j - 1] < INF:
                    D[i, j] = D[i, j - 1] + c
                    B[i, j] = 2
                continue
            best = D[i - 1, j]
            b = 1
            if j > 0:
                if D[i - 1, j - 1] <= best:
                    best = D[i - 1, j - 1]
                    b = 0
                if D[i, j - 1] < best:
                    best = D[i, j - 1]
                    b = 2
            D[i, j] = best + c
            B[i, j] = b
    j = 0
    best = D[n - 1, 0]
    for jj in range(1, m):
        if D[n - 1, jj] < best:
            best = D[n - 1, jj]
            j = jj
    first = np.full(n, -1, np.int64)
    i = n - 1
    while i >= 0:
        first[i] = j
        b = B[i, j]
        if i == 0 and (j < start_max or b != 2):
            break
        if b == 0:
            i -= 1
            j -= 1
        elif b == 1:
            i -= 1
        else:
            j -= 1
    return first


def pool(F, k=10):
    n = len(F) // k
    return F[: n * k].reshape(n, k, -1).mean(axis=1)


def align_surah(R, T, ref_verses, tgt_guess, band_s=25.0):
    """ref_verses: [(from_ms, to_ms, [kelime_başı_ms...])]; tgt_guess: [(a_sn, b_sn)].
    Dönüş: her ayet için hedefte [kelime_başı_ms...] ve ayet sonu ms."""
    # 1. aşama: 1 sn kareler, geniş bant (tempo değişimlerini yakalar)
    K0 = 50
    R0, T0 = pool(R, K0), pool(T, K0)
    rx = [0.0] + [v[0] / 1000 for v in ref_verses] + [len(R0) - 1.0]
    tx = [0.0] + [g[0] for g in tgt_guess] + [len(T0) - 1.0]
    center0 = np.interp(np.arange(len(R0)), rx, tx).astype(np.int64)
    band0 = int(max(120, 0.15 * len(T0)))
    path0 = _banded_dtw(R0, T0, center0, band0)
    # 2. aşama: 200 ms kareler, 1. aşamanın yolu etrafında dar bant
    K = 10
    Rc, Tc = pool(R, K), pool(T, K)
    center = (np.interp(np.arange(len(Rc)) / 5.0, np.arange(len(path0)), path0) * 5).astype(np.int64)
    coarse = _banded_dtw(Rc, Tc, center, int(band_s * 5))
    out = []
    for (f, t, starts) in ref_verses:
        ci = min(int(f / 200), len(coarse) - 1)
        ce = min(int(t / 200), len(coarse) - 1)
        a = max(0, coarse[ci] * K - 50)            # 1 sn önce
        b = min(len(T), coarse[ce] * K + 100)      # 2 sn sonra
        fa, fb = int(f // 20), int(t // 20)
        first = _anchored_dtw(R[fa:fb], T[a:b], 100)
        ws = []
        for s in starts:
            i = min(max(int(round((s - f) / 20)), 0), len(first) - 1)
            ws.append((a + int(first[i])) * 20)
        out.append((ws, (a + int(first[-1])) * 20))
    return out
