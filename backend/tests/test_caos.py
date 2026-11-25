"""Testes das rotas do modo caos (#14). As regras ficam em prolog/test_caos.pl."""

import pytest
from fastapi.testclient import TestClient

from app.main import NAO_ENCONTRADA, PARTIDA_ENCERRADA, PARTIDA_NAO_ENCONTRADA, app

client = TestClient(app)

PALPITES = ["termo", "pulha", "sabia", "nuvem", "fosco", "carta", "ninja"]
# Escudo e voltar no tempo devolvem linhas, então a partida pode passar de 6 palpites.
MAX_RODADAS = 40


def nova_partida() -> dict:
    response = client.post("/api/caos/nova")
    assert response.status_code == 200
    return response.json()


def jogar(partida: int, palavra: str):
    return client.post("/api/caos/palpite", json={"id": partida, "palavra": palavra})


def jogar_ate_o_fim(partida: int) -> dict:
    for rodada in range(MAX_RODADAS):
        response = jogar(partida, PALPITES[rodada % len(PALPITES)])
        assert response.status_code == 200
        estado = response.json()
        if estado["situacao"] != "em_andamento":
            return estado
    pytest.fail(f"partida não terminou em {MAX_RODADAS} palpites")


def test_nova_partida_comeca_vazia():
    partida = nova_partida()
    assert partida["linhas"] == []
    assert partida["max_linhas"] == 6
    assert partida["situacao"] == "em_andamento"
    assert partida["resposta"] == ""


def test_palpite_acrescenta_uma_linha():
    partida = nova_partida()
    response = jogar(partida["id"], "termo")
    assert response.status_code == 200
    linhas = response.json()["linhas"]
    assert len(linhas) == 1
    assert linhas[0]["palavra"] == "termo"


def test_resposta_so_aparece_quando_a_partida_e_perdida():
    final = jogar_ate_o_fim(nova_partida()["id"])
    if final["situacao"] == "perdeu":
        assert len(final["resposta"]) == 5
    else:
        assert final["resposta"] == ""


@pytest.mark.parametrize(
    ("corpo", "status", "detalhe"),
    [
        ({"id": 999999, "palavra": "termo"}, 404, PARTIDA_NAO_ENCONTRADA),
        ({"id": None, "palavra": "xyzwq"}, 422, NAO_ENCONTRADA),
    ],
)
def test_erros_do_palpite(corpo, status, detalhe):
    if corpo["id"] is None:
        corpo = {**corpo, "id": nova_partida()["id"]}
    response = client.post("/api/caos/palpite", json=corpo)
    assert response.status_code == status
    assert response.json()["detail"] == detalhe


def test_palpite_depois_do_fim_da_partida():
    partida = nova_partida()
    jogar_ate_o_fim(partida["id"])
    response = jogar(partida["id"], "termo")
    assert response.status_code == 422
    assert response.json()["detail"] == PARTIDA_ENCERRADA


def test_palavra_fora_do_formato_e_rejeitada_pelo_pydantic():
    response = client.post("/api/caos/palpite", json={"id": 0, "palavra": "abc"})
    assert response.status_code == 422
