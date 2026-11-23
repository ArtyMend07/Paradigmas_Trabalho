"""Testes das rotas do modo caos (#14). As regras ficam em prolog/test_caos.pl."""

import pytest
from fastapi.testclient import TestClient

from app.main import NAO_ENCONTRADA, PARTIDA_ENCERRADA, PARTIDA_NAO_ENCONTRADA, app

client = TestClient(app)

PALPITES_ERRADOS = ["termo", "pulha", "sabia", "nuvem", "fosco", "grito", "ninja"]


def nova_partida() -> dict:
    response = client.post("/api/caos/nova")
    assert response.status_code == 200
    return response.json()


def jogar(partida: int, palavra: str):
    return client.post("/api/caos/palpite", json={"id": partida, "palavra": palavra})


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


def test_partida_perdida_revela_a_resposta():
    partida = nova_partida()
    atual = partida
    for palavra in PALPITES_ERRADOS:
        if atual["situacao"] != "em_andamento":
            break
        resposta = jogar(partida["id"], palavra)
        assert resposta.status_code == 200
        atual = resposta.json()
    if atual["situacao"] == "perdeu":
        assert len(atual["resposta"]) == 5


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
    situacao = "em_andamento"
    tentativas = 0
    while situacao == "em_andamento":
        situacao = jogar(partida["id"], PALPITES_ERRADOS[tentativas % len(PALPITES_ERRADOS)]).json()["situacao"]
        tentativas += 1
    response = jogar(partida["id"], "termo")
    assert response.status_code == 422
    assert response.json()["detail"] == PARTIDA_ENCERRADA


def test_palavra_fora_do_formato_e_rejeitada_pelo_pydantic():
    response = client.post("/api/caos/palpite", json={"id": 0, "palavra": "abc"})
    assert response.status_code == 422
