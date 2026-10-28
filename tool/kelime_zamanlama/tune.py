import json, random
import numpy as np
from fit_weights import load, accuracy, NAMES
train_r, test_r = (6, 7, 9, 2), (3, 5, 10, 4)
train = [x for r in train_r for s in (2, 18) for x in load(r, s)]
random.seed(1)
train = random.sample(train, 400)
test = [x for r in test_r for s in (36, 55, 67, 87) for x in load(r, s)]
beta = np.array([1.0, 1.0, 3.0, 1.2, 0.5, 0.0, 0.0, 2.5, 0.0])  # şu anki
score = lambda b: accuracy(train, lambda X: X @ b)[0]
best = score(beta)
print('baslangic egitim', round(best, 1), flush=True)
steps = [0.5, 0.25, 0.1]
for step in steps:
    improved = True
    while improved:
        improved = False
        for i in range(len(beta)):
            for sgn in (1, -1):
                b = beta.copy(); b[i] = max(0.0, b[i] + sgn * step * (abs(b[i]) + 0.5))
                sc = score(b)
                if sc > best + 0.05:
                    best, beta, improved = sc, b, True
        print(f'adim {step}: egitim %{best:.1f}', flush=True)
print('katsayilar:', ', '.join(f'{n}={b:.2f}' for n, b in zip(NAMES, beta)))
for name, b in (('su anki', np.array([1.0, 1.0, 3.0, 1.2, 0.5, 0.0, 0.0, 2.5, 0.0])), ('ayarlanmis', beta)):
    a, n = accuracy(test, lambda X: X @ b)
    print(f'TEST {name}: tam %{a:.1f} ±1 %{n:.1f}')
json.dump(list(beta), open('beta_tuned.json', 'w'))
