"""Ponte entre Python e Prolog usando a biblioteca janus.

janus (pacote `janus-swi`) embute o SWI-Prolog dentro do processo Python.
Não há servidor Prolog separado nem troca de mensagens: chamamos predicados
diretamente e recebemos as respostas como valores Python.

Conversão automática de tipos (Python -> Prolog):
    str          -> string
    list         -> lista

Os predicados do jogo usam átomos; quem converte string <-> átomo é
`prolog/api.pl`. Este arquivo só chama os três predicados de lá e traduz
falhas em exceções.

Para mais detalhes: https://www.swi-prolog.org/pldoc/man?section=janus

Este é o ÚNICO arquivo do projeto que conhece o janus. O resto do backend
só chama as funções abaixo.
"""

from pathlib import Path

import janus_swi as janus

# Um palpite é [palavra, [cor x 5]]: lista, e não tupla nem termo composto,
# porque o janus não converte termos compostos.
Palpite = list
Historico = list[Palpite]

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "api.pl"

# consult/1 carrega api.pl, que carrega os demais módulos e a base de
# palavras (palavras.txt e respostas.txt) na inicialização.
janus.consult(str(PROLOG_FILE))


class SemCandidatas(Exception):
    """Nenhuma palavra da base é compatível com o histórico."""


class PalavraNaoEncontrada(Exception):
    """A palavra do autoplay não está em respostas.txt."""


def candidatas(historico: Historico) -> list[str]:
    # query_once devolve um dict com as variáveis da consulta e a chave
    # 'truth', que diz se a consulta teve sucesso.
    result = janus.query_once("api:api_candidatas(H, Ws)", {"H": historico})
    if not result["truth"]:
        raise SemCandidatas
    return result["Ws"]


def sugestao(historico: Historico) -> tuple[str, str]:
    result = janus.query_once("api:api_sugestao(H, W, M)", {"H": historico})
    if not result["truth"]:
        raise SemCandidatas
    return result["W"], result["M"]


def autoplay(palavra: str) -> list[Palpite]:
    result = janus.query_once("api:api_autoplay(P, R)", {"P": palavra})["R"]
    # api_autoplay/2 sempre tem sucesso: devolve a lista de passos ou o
    # átomo `nao_encontrada` (átomos chegam ao Python como str).
    match result:
        case "nao_encontrada":
            raise PalavraNaoEncontrada
        case list():
            return result
    raise ValueError(f"resultado inesperado de api_autoplay/2: {result!r}")


class PartidaNaoEncontrada(Exception):
    """O id não corresponde a nenhuma partida do modo caos."""


class PartidaEncerrada(Exception):
    """A partida do modo caos já terminou."""


class PalpiteInvalido(Exception):
    """O palpite não está na base de palavras."""


ERROS_DO_CAOS = {
    "partida_inexistente": PartidaNaoEncontrada,
    "partida_encerrada": PartidaEncerrada,
    "palavra_invalida": PalpiteInvalido,
}


def _resposta_do_caos(result: dict, variavel: str, predicado: str):
    # Os predicados do caos sempre deveriam ter sucesso. Se falharem, o dict
    # vem sem a variável; melhor um erro que diga qual predicado falhou do
    # que um KeyError.
    if not result["truth"]:
        raise RuntimeError(f"{predicado} falhou")
    return result[variavel]


def caos_nova() -> dict:
    result = janus.query_once("api:api_caos_nova(P)")
    return _resposta_do_caos(result, "P", "api_caos_nova/1")


def caos_palpite(partida: int, palavra: str) -> dict:
    result = _resposta_do_caos(
        janus.query_once(
            "api:api_caos_palpite(Id, W, R)", {"Id": partida, "W": palavra}
        ),
        "R",
        "api_caos_palpite/3",
    )
    # api_caos_palpite/3 devolve o dict da partida ou o átomo do erro.
    if isinstance(result, str):
        raise ERROS_DO_CAOS[result]
    return result
