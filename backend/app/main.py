"""API HTTP do assistente de Termo.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs

Contrato das rotas: issue #6 (Api.elm).
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app import prolog

app = FastAPI(title="Termo (Prolog + Elm)")

# Uma palavra tem exatamente 5 letras minúsculas, sem acento (a base também
# não tem acentos). Cada palpite tem exatamente 5 cores e o jogo tem no
# máximo 6 palpites. O Pydantic rejeita (erro 422) qualquer coisa fora disso.
Palavra = Annotated[str, Field(pattern=r"^[a-z]{5}$")]
Cor = Literal["green", "yellow", "gray"]
Cores = Annotated[list[Cor], Field(min_length=5, max_length=5)]

# Um palpite vem como a lista [palavra, cores]. tuple[...] valida cada
# posição com o seu tipo e continua sendo um array no JSON.
Palpite = tuple[Palavra, Cores]
Historico = Annotated[list[Palpite], Field(max_length=6)]


class HistoricoRequest(BaseModel):
    historico: Historico


class CandidatasResponse(BaseModel):
    palavras: list[str]


class SugestaoResponse(BaseModel):
    palavra: str
    motivo: str


class AutoplayRequest(BaseModel):
    palavra: Palavra


class AutoplayResponse(BaseModel):
    passos: list[tuple[str, list[str]]]


# Mensagens que o Elm mostra na tela quando a resposta é 422 (tabela da #7).
SEM_CANDIDATAS = "Nenhuma palavra corresponde às cores informadas."
NAO_ENCONTRADA = "Palavra não encontrada na base."


def _como_listas(historico: list[Palpite]) -> list[list]:
    # O janus converte listas, mas não tuplas: devolvemos ao formato do JSON.
    return [[palavra, list(cores)] for palavra, cores in historico]


@app.post("/api/candidatas")
def candidatas(request: HistoricoRequest) -> CandidatasResponse:
    try:
        palavras = prolog.candidatas(_como_listas(request.historico))
    except prolog.SemCandidatas:
        # `from None` diz que a HTTPException SUBSTITUI a exceção original;
        # o traceback fica mais limpo.
        raise HTTPException(status_code=422, detail=SEM_CANDIDATAS) from None
    return CandidatasResponse(palavras=palavras)


@app.post("/api/sugestao")
def sugestao(request: HistoricoRequest) -> SugestaoResponse:
    try:
        palavra, motivo = prolog.sugestao(_como_listas(request.historico))
    except prolog.SemCandidatas:
        raise HTTPException(status_code=422, detail=SEM_CANDIDATAS) from None
    return SugestaoResponse(palavra=palavra, motivo=motivo)


@app.post("/api/autoplay")
def autoplay(request: AutoplayRequest) -> AutoplayResponse:
    try:
        passos = prolog.autoplay(request.palavra)
    except prolog.PalavraNaoEncontrada:
        raise HTTPException(status_code=422, detail=NAO_ENCONTRADA) from None
    return AutoplayResponse(passos=passos)
