"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta. Cada função `test_*` é um teste; o pytest as
encontra sozinho.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do jogo são testadas em Prolog (prolog/test_*.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

TUDO_VERDE = ["green"] * 5
BARRA = ["barra", ["gray", "green", "green", "green", "gray"]]
# Cores impossíveis: uma letra não pode ser verde e cinza na mesma posição
# de dois palpites iguais, então nenhuma palavra é compatível.
CONTRADICAO = [
    ["carro", TUDO_VERDE],
    ["carro", ["gray"] * 5],
]


# --- /api/candidatas ------------------------------------------------------


def test_candidatas_historico_vazio_devolve_a_base():
    response = client.post("/api/candidatas", json={"historico": []})
    assert response.status_code == 200
    palavras = response.json()["palavras"]
    assert len(palavras) > 8000
    assert "carro" in palavras and "termo" in palavras


def test_candidatas_com_um_palpite():
    response = client.post("/api/candidatas", json={"historico": [BARRA]})
    assert response.status_code == 200
    palavras = response.json()["palavras"]
    assert "carro" in palavras
    assert "barra" not in palavras
    assert all(p[1:4] == "arr" for p in palavras)


def test_candidatas_sem_palavra_compativel():
    response = client.post("/api/candidatas", json={"historico": CONTRADICAO})
    assert response.status_code == 422
    assert response.json()["detail"] == "Nenhuma palavra corresponde às cores informadas."


# --- /api/sugestao --------------------------------------------------------


def test_sugestao_historico_vazio_devolve_a_abertura():
    response = client.post("/api/sugestao", json={"historico": []})
    assert response.status_code == 200
    corpo = response.json()
    assert len(corpo["palavra"]) == 5
    assert corpo["motivo"]


def test_sugestao_com_um_palpite():
    response = client.post("/api/sugestao", json={"historico": [BARRA]})
    assert response.status_code == 200
    corpo = response.json()
    assert len(corpo["palavra"]) == 5
    assert "restam" in corpo["motivo"]


def test_sugestao_sem_palavra_compativel():
    response = client.post("/api/sugestao", json={"historico": CONTRADICAO})
    assert response.status_code == 422
    assert response.json()["detail"] == "Nenhuma palavra corresponde às cores informadas."


# --- /api/autoplay --------------------------------------------------------


def test_autoplay_acerta_a_palavra():
    response = client.post("/api/autoplay", json={"palavra": "carro"})
    assert response.status_code == 200
    passos = response.json()["passos"]
    assert 1 <= len(passos) <= 6
    assert passos[-1] == ["carro", TUDO_VERDE]
    for palavra, cores in passos:
        assert len(palavra) == 5
        assert len(cores) == 5
        assert set(cores) <= {"green", "yellow", "gray"}


def test_autoplay_palavra_fora_das_respostas():
    # "zzzzz" tem formato válido (passa no Pydantic), mas não está na base.
    response = client.post("/api/autoplay", json={"palavra": "zzzzz"})
    assert response.status_code == 422
    assert response.json()["detail"] == "Palavra não encontrada na base."


# --- validação (Pydantic, antes de chegar ao Prolog) ----------------------


def test_rejeita_palavra_com_tamanho_errado():
    response = client.post("/api/autoplay", json={"palavra": "carros"})
    assert response.status_code == 422


def test_rejeita_palavra_com_maiuscula_ou_acento():
    for palavra in ["Carro", "maçãs"]:
        response = client.post("/api/autoplay", json={"palavra": palavra})
        assert response.status_code == 422


def test_rejeita_cor_desconhecida():
    historico = [["barra", ["gray", "green", "green", "green", "blue"]]]
    response = client.post("/api/candidatas", json={"historico": historico})
    assert response.status_code == 422


def test_rejeita_quantidade_errada_de_cores():
    historico = [["barra", ["gray", "green", "green", "green"]]]
    response = client.post("/api/sugestao", json={"historico": historico})
    assert response.status_code == 422


def test_rejeita_mais_de_seis_palpites():
    historico = [BARRA] * 7
    response = client.post("/api/candidatas", json={"historico": historico})
    assert response.status_code == 422


def test_rotas_aparecem_na_documentacao():
    caminhos = client.get("/openapi.json").json()["paths"]
    assert {"/api/candidatas", "/api/sugestao", "/api/autoplay"} <= set(caminhos)
