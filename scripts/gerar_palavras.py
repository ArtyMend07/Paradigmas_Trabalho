#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Gera backend/data/palavras.txt a partir do palavras.txt de pythonprobr/palavras.

Uso, a partir da raiz do repositório:

    uv run scripts/gerar_palavras.py caminho/para/palavras-origem.txt
"""

import sys
import unicodedata
from pathlib import Path

TAMANHO_PALAVRA = 5
RAIZ = Path(__file__).resolve().parent.parent
NOMES_PROPRIOS = RAIZ / "scripts" / "nomes_proprios.txt"
SAIDA = RAIZ / "backend" / "data" / "palavras.txt"


def sem_acento(palavra: str) -> str:
    decomposta = unicodedata.normalize("NFD", palavra)
    return "".join(letra for letra in decomposta if not unicodedata.combining(letra))


def tem_formato_valido(palavra: str) -> bool:
    return (
        len(palavra) == TAMANHO_PALAVRA
        and palavra.isascii()
        and palavra.isalpha()
    )


def filtrar(origem: list[str], nomes_proprios: set[str]) -> list[str]:
    vistas: set[str] = set()
    palavras: list[str] = []
    for linha in origem:
        original = linha.strip()
        # A origem marca nomes próprios com inicial maiúscula (#1).
        if not original or original != original.lower():
            continue
        palavra = sem_acento(original)
        if not tem_formato_valido(palavra) or palavra in vistas:
            continue
        # Alguns nomes aparecem só em minúsculas na origem e foram separados à mão.
        if palavra in nomes_proprios:
            continue
        vistas.add(palavra)
        palavras.append(palavra)
    return palavras


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("uso: uv run scripts/gerar_palavras.py <palavras-origem.txt>")
    origem = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    nomes_proprios = set(NOMES_PROPRIOS.read_text(encoding="utf-8").split())
    palavras = filtrar(origem, nomes_proprios)
    SAIDA.write_text("\n".join(palavras) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(palavras)} palavras em {SAIDA.relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
