#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["wordfreq==3.1.1"]
# ///
"""Gera backend/data/respostas.txt a partir de backend/data/palavras.txt.

Uso, a partir da raiz do repositório:

    uv run scripts/gerar_respostas.py

"""

import unicodedata
from collections import defaultdict
from pathlib import Path

from wordfreq import iter_wordlist, word_frequency

TOTAL = 2000
# palavra fica de fora se for pelo menos isso vezes mais frequente em
# ingles ou frances do que em portugues (paris, light, color...)
FATOR_ESTRANGEIRA = 3
PALAVROES = {
    "porra", "merda", "bosta", "foder", "fodeu", "fodia", "fodas", "fodam",
    "cagao", "cagar", "putas", "putos", "porno", "viado", "penis",
}
RAIZ = Path(__file__).resolve().parent.parent
PALAVRAS = RAIZ / "backend" / "data" / "palavras.txt"
SAIDA = RAIZ / "backend" / "data" / "respostas.txt"


def sem_acento(palavra: str) -> str:
    decomposta = unicodedata.normalize("NFD", palavra)
    return "".join(letra for letra in decomposta if not unicodedata.combining(letra))


def frequencias(base: set[str]) -> dict[str, float]:
    # soma as formas com e sem acento (e.g. "nao" e "não") na mesma palavra
    freq: dict[str, float] = defaultdict(float)
    for palavra in iter_wordlist("pt", "large"):
        if not palavra.isalpha():
            continue
        chave = sem_acento(palavra)
        if chave in base:
            freq[chave] += word_frequency(palavra, "pt", "large")
    return freq


def estrangeira(palavra: str, freq_pt: float) -> bool:
    outra = max(word_frequency(palavra, "en", "large"),
                word_frequency(palavra, "fr", "large"))
    return outra > FATOR_ESTRANGEIRA * freq_pt


def main() -> None:
    base = set(PALAVRAS.read_text(encoding="utf-8").split())
    freq = frequencias(base)
    ordem = sorted(freq, key=lambda p: (-freq[p], p))
    escolhidas = [p for p in ordem
                  if p not in PALAVROES and not estrangeira(p, freq[p])][:TOTAL]
    SAIDA.write_text("\n".join(sorted(escolhidas)) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(escolhidas)} palavras em {SAIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
