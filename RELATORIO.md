# Termo (Prolog + Elm)

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| João Pedro Costa | 190030801 | 16h | @johnaopedro |
| Lucas Mendonça Arruda | 231035464 | 16h | @lucasarruda9 |
| Artur Mendonça Arruda | 231037337 | 16h | @ArtyMend07 |
| Rafael Ferreira Leandro | 211041286 | 16h | @RafaelCLG0 |
| Gabriel Fernando de Jesus Silva | 222022162 | 16h | @MMcLovin |
| Maria Clara Sena de Lima | 231012281 | 16h | @mclarasenaa |
| Lucas Avelar | 200067095 | 16h | @LucasAvelar2711 |

- **Nome do projeto:** Termo (Prolog + Elm)
- **Nome do grupo:** Os Prologados
- **Repositório:** https://github.com/ArtyMend07/Paradigmas_Trabalho
- **Commit ou tag entregue:** `v1.0`
- **Ponto de partida:** Remix original
- **Slides da apresentação oral:** não há

## 2. Resumo

Assistente e jogo de Termo. No modo assistente, o jogador informa as cores que recebeu no Termo e o Prolog filtra as palavras ainda possíveis e sugere o melhor palpite por minimax. No modo automático, o solver joga sozinho até acertar uma palavra escolhida. No modo caos, o Prolog guarda a partida e, a cada 2 palpites, sorteia um efeito aleatório, mas só entre os efeitos que não deixam a partida impossível.

![Captura de tela do modo caos](docs/captura.png)

## 3. Como executar

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog 11.0.1
- Node.js 20.19.5
- uv
- `python3-dev` (Debian/Ubuntu), para compilar o `janus-swi`

O `apt` do Ubuntu 24.04 traz o SWI-Prolog 9.0.4, antigo demais para o
`janus-swi`. Instale pelo PPA, removendo antes os pacotes antigos, com os
comandos abaixo.

```sh
sudo apt remove swi-prolog swi-prolog-core swi-prolog-core-packages swi-prolog-doc swi-prolog-nox
sudo add-apt-repository ppa:swi-prolog/stable
sudo apt update
sudo apt install swi-prolog
```

**Instalação e execução:**

```sh
make install    # dependências do backend (uv) e do frontend (npm)
make dev        # sobe backend (porta 8000) e frontend (porta 5173)
```

Abra http://localhost:5173. Se o `janus-swi` foi instalado antes de
atualizar o SWI-Prolog, recompile-o com o comando abaixo.

```sh
cd backend
uv sync --reinstall-package janus-swi --no-binary-package janus-swi --no-cache
```

**Testes:**

```sh
make test
```

**Testado em:** Linux (Ubuntu 24.04 e container Docker da imagem `swipl:stable`), Google Chrome

## 4. Arquitetura

```
Elm (navegador) --HTTP/JSON--> Python (FastAPI) --janus--> Prolog
```

| Parte  | Responsabilidade | Arquivos principais |
|--------|------------------|---------------------|
| Prolog | Feedback de cores, filtro de candidatas, sugestão por minimax, autoplay e as regras e o estado das partidas do modo caos | `backend/prolog/feedback.pl`, `candidates.pl`, `strategy.pl`, `autoplay.pl`, `caos.pl`, `api.pl` |
| Elm    | Interface, estado da tela, teclado, chamadas HTTP com decoders próprios e os efeitos visuais do modo caos | `frontend/src/Main.elm`, `Termo.elm`, `Teclado.elm`, `Api.elm`, `Caos.elm`, `CaosApi.elm`, `PaginaCaos.elm`, `Rascunho.elm`, `Festa.elm` |
| Python | Expõe os predicados de `api.pl` como rotas HTTP e valida o formato da entrada | `backend/app/main.py`, `backend/app/prolog.py` |

## 5. Parte em Prolog

### 5.1 Predicados principais

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| `feedback(+Palpite, +Resposta, ?Cores)` | `backend/prolog/feedback.pl:9` | Calcula as cores, ou confere quando `Cores` já vem preenchido |
| `consistent(+Palavra, +Historico)` | `backend/prolog/candidates.pl:12` | A palavra é compatível com o histórico |
| `candidates(+Historico, -Palavras)` | `backend/prolog/candidates.pl:25` | Palavras da base compatíveis com o histórico |
| `best_guess(+Historico, -Palavra, -Motivo)` | `backend/prolog/strategy.pl:44` | Melhor palpite por minimax, com o motivo |
| `maior_grupo(+Palpite, +Candidatas, +Limite, -Maior)` | `backend/prolog/strategy.pl:124` | Pior caso de um palpite, falhando ao passar do limite |
| `autoplay(+Resposta, -Passos)` | `backend/prolog/autoplay.pl:26` | Joga com `best_guess/3` até acertar |
| `nova_partida(-Id)` | `backend/prolog/caos.pl:70` | Sorteia a resposta e cria uma partida do modo caos |
| `jogar(+Id, +Palavra, -Resultado)` | `backend/prolog/caos.pl:94` | Registra o palpite e aplica os efeitos |
| `efeito_possivel(?Efeito, +Estado)` | `backend/prolog/caos.pl:218` | Efeitos que não deixam a partida sem solução |
| `aplicar_efeito(+Efeito, +Estado, -Novo, -Evento)` | `backend/prolog/caos.pl:243` | Aplica o efeito sorteado |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Fatos e regras como base de conhecimento: `word/1` (`words.pl:7`),
  `resposta/1` (`autoplay.pl:8`), `efeito/2` (`caos.pl:44`), `so_na_tela/1`
  (`caos.pl:59`), `inverter_cor/2` (`caos.pl:174`) e `valor/2`
  (`strategy.pl:150`)
- [x] Unificação e casamento de padrões: `verdes/4` (`feedback.pl:18`), em
  que a mesma variável `Letra` nas duas listas exige letras iguais, e
  `estado(R, Linhas, _, Max)` nas cabeças de `aplicar_efeito/4`
  (`caos.pl:243`)
- [x] Recursão (inclusive sobre listas): `verdes/4`, `amarelos/3`
  (`feedback.pl:27`), `consistente/2` (`candidates.pl:16`), `joga/3`
  (`autoplay.pl:31`), `conta/6` (`strategy.pl:130`) e `melhor/6`
  (`strategy.pl:109`)
- [x] Backtracking e múltiplas soluções: `candidates/2`
  (`candidates.pl:25`), que gera com `word/1` e testa com `consistent/2`, e
  `efeito_possivel/2` (`caos.pl:218`)
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `candidates/2`,
  `palpites/3` (`strategy.pl:87`), `nova_partida/1` (`caos.pl:70`) e
  `sortear_efeito/2` (`caos.pl:212`)
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: `!` em
  `verdes/4`, para uma letra verde não ser testada como amarela;
  `\+ memberchk` em `joga/3` (`autoplay.pl:34`), contra laço infinito; e
  `\+ word(Palpite)` em `jogar_/3` (`caos.pl:105`), para recusar palavras
  fora da base
- [ ] Programação por restrições (CLP(FD) ou outra)
- [x] Predicados de ordem superior: `maplist` em `consistente/2`
  (`candidates.pl:18`), `foldl` em `codigo/2` (`strategy.pl:143`),
  `include` em `contar/3` (`caos.pl:179`) e `forall` em `load_words/1`
  (`words.pl:7`)
- [x] Outro: estado das partidas com `assertz/1` (`caos.pl:76`) e
  `retract/1` (`caos.pl:108`), e `setarg/3` no contador de
  `maior_grupo/4` (`strategy.pl:137`), por desempenho

### 5.3 Trecho em destaque

```prolog
% backend/prolog/candidates.pl
consistent(Candidata, Historico) :-
    consistente(Historico, Candidata).

consistente([], _).
consistente([[Palpite, Cores]|Resto], Candidata) :-
    maplist(como_atomo, Cores, CoresAtomos),
    feedback(Palpite, Candidata, CoresAtomos),
    consistente(Resto, Candidata).

candidates(Historico, Palavras) :-
    findall(W, ( word(W), consistent(W, Historico) ), Palavras).
```

Uma palavra é candidata se, para cada palpite do histórico, ela teria
produzido as cores que o jogador viu.

- `feedback/3` é chamado com `Cores` já preenchido. Em vez de calcular, ele
  testa. Se as cores não unificam, ele falha e a palavra é descartada. Não
  existe um predicado separado para conferir.
- `candidates/2` é gerar e testar. `word(W)` gera as palavras por
  backtracking, `consistent/2` filtra e `findall/3` junta o resultado. Não
  há laço nem lista acumulada escritos à mão.

## 6. Parte em Elm

### 6.1 Modelo e mensagens

```elm
-- frontend/src/Main.elm
type Modo
    = Assistente
    | Automatico
    | Caos

type alias Model =
    { modo : Modo
    , jogo : Jogo
    , tremor : Int
    , pedido : Int
    , candidatas : Remoto (List String)
    , sugestao : Remoto Sugestao
    , palavraAutoplay : String
    , autoplay : Remoto (List Palpite)
    , erroLocal : Maybe String
    , temaEscuro : Bool
    , caos : PaginaCaos.Model
    }

type Msg
    = ModoAlterado Modo
    | TeclaPressionada Tecla
    | CorTrocada Int
    | PalavraEscolhida String
    | NovoJogo
    | RecebeuCandidatas Int (Result String (List String))
    | RecebeuSugestao Int (Result String Sugestao)
    | PalavraAutoplayAlterada String
    | AutoplaySolicitado
    | RecebeuAutoplay String (Result String (List Palpite))
    | TemaAlterado Bool
    | ErroFechado
    | CaosMsg PaginaCaos.Msg

-- frontend/src/Termo.elm
type Cor = Verde | Amarelo | Cinza

type Jogo
    = Jogo { palpites : List Palpite, rascunho : List ( Char, Cor ) }

type Casa
    = Vazia
    | Rascunho Char Cor
    | Confirmada Char Cor

type Remoto a
    = NaoPedido
    | Carregando
    | Chegou a
    | Falhou String

-- frontend/src/Caos.elm
type Exibicao
    = Cores (List Cor)
    | Contagem { verdes : Int, amarelas : Int }
    | Oculta

type Situacao
    = EmAndamento
    | Venceu
    | Perdeu String

-- frontend/src/Rascunho.elm
type Rascunho
    = Rascunho { casas : List (Maybe Char), cursor : Int }
```

- **`Remoto a`** substitui `Bool` + `Maybe` dado + `Maybe` erro, então não
  existe "carregando e com erro" ao mesmo tempo.
- **`Casa`** não deixa uma casa vazia ter cor, e `Rascunho` e `Confirmada`
  dizem se a cor ainda pode ser trocada.
- **`Jogo`** é opaco (exportado sem construtor), então só `Termo.elm` altera
  uma partida.
- **`Rascunho`** (o tipo do modo caos) também é opaco. As funções do módulo
  mantêm sempre 5 casas e o cursor entre 0 e 5, e `Rascunho.palavra` só
  devolve `Just` com as 5 casas preenchidas.
- **`Perdeu String`** guarda a resposta, que só existe quando o jogador
  perdeu.
- **`Exibicao`** representa as três formas de mostrar uma linha no modo caos.
- **`pedido`** numera as consultas, e o `update` descarta respostas
  atrasadas de partidas anteriores.
- **`tremor`** conta os Enter recusados seguidos. A view alterna duas
  classes de animação pela paridade dele para a linha tremer de novo.
- **`CaosMsg`** liga o `Main` ao modo caos, que tem `Model`, `Msg` e
  `update` próprios em `PaginaCaos.elm`.

### 6.2 Conceitos do paradigma funcional utilizados

- [x] Arquitetura Elm (Model, update, view): `Main.elm`, `PaginaCaos.elm`
- [x] Custom types e `case` exaustivo: `Termo.elm` (`Cor`, `Casa`, `Jogo`,
  `Remoto`), `Caos.elm` (`Efeito`, `Exibicao`, `Situacao`), `Teclado.elm`
  (`Tecla`)
- [x] `Maybe` e `Result` no lugar de null e exceções: `Result String a` em
  `Api.elm` e `CaosApi.elm`, `Maybe Efeito` em `Caos.elm` e
  `Rascunho.palavra : Rascunho -> Maybe String`
- [x] Funções de ordem superior e aplicação parcial: `viewTecladoCom`
  (`Teclado.elm`) recebe `Char -> Maybe Cor` e `Char -> Bool`
- [x] Composição (`|>`, `>>`): `String.toList >> List.map ...`
  (`Teclado.elm`) e `|>` nos decoders
- [x] Decoders e encoders JSON: `Api.elm`, `CaosApi.elm` (`Decode.andThen`,
  `Decode.oneOf`)
- [x] Comandos e subscriptions (efeitos controlados): `Http.post`,
  `Random.generate` e `Process.sleep` em `PaginaCaos.elm`, e
  `Browser.Events.onKeyDown`
- [x] Imutabilidade e atualização de records: `{ model | ... }` no `update`
- [x] Outro: tipos opacos (`Jogo`, `Rascunho`) e testes com elm-test
  (`frontend/tests/`)

### 6.3 Trecho em destaque

```elm
-- frontend/src/CaosApi.elm
exibicaoDecoder : Decoder Exibicao
exibicaoDecoder =
    Decode.field "tipo" Decode.string
        |> Decode.andThen
            (\tipo ->
                case tipo of
                    "cores" ->
                        Decode.map Cores (Decode.field "cores" (Decode.list corDecoder))

                    "contagem" ->
                        Decode.map2 (\verdes amarelas -> Contagem { verdes = verdes, amarelas = amarelas })
                            (Decode.field "verdes" Decode.int)
                            (Decode.field "amarelas" Decode.int)

                    "oculta" ->
                        Decode.succeed Oculta

                    _ ->
                        Decode.fail ("Exibição desconhecida: " ++ tipo)
            )
```

O JSON de cada linha sempre traz `tipo`, `cores`, `verdes` e `amarelas`, o
que permite combinações sem sentido (`"oculta"` com cinco cores).

- `Decode.andThen` lê o `tipo` e escolhe o decoder do resto do objeto.
- Cada caso lê só os campos que usa e produz um construtor de `Exibicao`.
- Um `tipo` desconhecido vira `Decode.fail`, que chega à tela como `Err`.

Depois do decoder, o programa só vê `Exibicao`, e o compilador exige que a
`view` trate os três casos.

## 7. Integração

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| `POST /api/candidatas` | `{"historico": [["serao", ["gray", ...]], ...]}` | `{"palavras": [...]}` | `api_candidatas/2` |
| `POST /api/sugestao` | `{"historico": [...]}` | `{"palavra": "...", "motivo": "..."}` | `api_sugestao/3` |
| `POST /api/autoplay` | `{"palavra": "carro"}` | `{"passos": [["raiao", [...]], ...]}` | `api_autoplay/2` |
| `POST /api/caos/nova` | corpo vazio | a partida (`id`, `linhas`, `max_linhas`, `proximo`, `evento`, `situacao`, `resposta`) | `api_caos_nova/1` |
| `POST /api/caos/palpite` | `{"id": 1, "palavra": "carro"}` | a partida atualizada | `api_caos_palpite/3` |

Os erros voltam como `{"detail": "..."}`, com status 404 para partida
inexistente e 422 para palavra fora da base, histórico sem candidatas,
partida encerrada ou palavra fora do formato (recusada pelo Pydantic).

## 8. Testes e validação

- **Testes automatizados**, rodados com `make test`
  - plunit em `backend/prolog/test_*.pl`: 72 testes (feedback 11,
    candidates 12, strategy 12, autoplay 13 e caos 24)
  - pytest em `backend/tests/` (`test_api.py` e `test_caos.py`): 21 testes
  - elm-test em `frontend/tests/` (`ApiTest.elm`, `CaosTest.elm` e
    `RascunhoTest.elm`): 29 testes
- **Casos de borda**
  - letras repetidas no feedback (`selectchk/3` em `amarelos/3`,
    `feedback.pl:31`)
  - histórico sem candidatas (422)
  - palavra fora da base ou do formato (422)
  - partida do caos inexistente (404) ou encerrada (422)
  - respostas HTTP atrasadas (descartadas pelo `pedido`)
  - efeitos que deixariam a partida sem solução não são sorteados
  - o solver acerta as 2.000 respostas de `respostas.txt` em até 5
    tentativas, com média de 3,61 (75 em 2, 761 em 3, 1.028 em 4 e 136 em
    5), medido com `orcamento(300_000)`. O teste
    `acerta_em_ate_6_tentativas` (`test_strategy.pl`) confere 11 dessas
    palavras

## 9. Limitações e problemas conhecidos

- As partidas do modo caos ficam na memória do Prolog, então somem quando o
  servidor reinicia, e só as 1.000 mais recentes são mantidas
  (`max_partidas_guardadas/1`, `caos.pl:36`).
- Com muitas candidatas, `orcamento/1` (`strategy.pl:38`) limita o minimax,
  e o palpite pode não ser o ótimo.
- A abertura (`raiao`) é fixa, e mudar a base exige recalculá-la.
- Nos quatro efeitos só visuais do caos, as casas e teclas afetadas são
  sorteadas no Elm, não no Prolog.
- O modo caos tem 13 dos 21 efeitos planejados na issue #14. A issue #19
  (rever os efeitos de teclado que não atrapalham) está aberta: a explosão
  já apaga a cor também na grade, e a limpeza do teclado ainda não foi
  revista.
- No modo assistente, depois de clicar num botão do painel, o botão fica
  com o foco e o Enter físico não confirma o palpite até o jogador clicar
  fora dele.
- O `janus-swi` não compila no Windows sem o compilador do Visual Studio.
  No Windows, o grupo rodou o backend num container Docker.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| Artur Mendonça Arruda | (@ArtyMend07) Base de palavras e `feedback/3` (#11), modo caos com `caos.pl`, rotas e tela (#15), cursor, animações e avisos da interface (#18), ajuste do orçamento do minimax (#20), issues e revisão dos PRs |
| João Pedro Costa | (@johnaopedro) Filtro de candidatas, respostas e autoplay (#9) e autoplay usando `strategy.pl` (#17) |
| Rafael Ferreira Leandro | (@RafaelCLG0) Sugestão de palpite por minimax em `strategy.pl` (#13) |
| Lucas Mendonça Arruda | (@lucasarruda9) Tipos, regras do jogo e teclado em `Termo.elm` e `Teclado.elm` (#8), os quatro efeitos visuais do modo caos (tiroteio, letras apagadas, explosão e limpeza do teclado) e o relatório |
| Gabriel Fernando de Jesus Silva | (@MMcLovin) Interface, grade e estilo em `Main.elm` e `style-simples.css` (#10) |
| Maria Clara Sena de Lima | (@mclarasenaa) Requisições HTTP e decoders em `Api.elm`, com testes elm-test (#16), e revisão do #15 com correções (respostas atrasadas, efeitos depois de voltar no tempo, erro do backend e tempo limite das requisições) |
| Lucas Avelar | (@LucasAvelar2711) Integração Python e Prolog, com rotas FastAPI, janus e pytest (#12) |

## 11. Fontes, código de terceiros e uso de IA

**Código reaproveitado.** Partimos do template do Sudoku e mantivemos a
estrutura da integração Python (`backend/app/`), a configuração do frontend
(Vite, Tailwind, daisyUI), o `Makefile` e o validador. Os arquivos `.pl` e
os módulos Elm foram escritos pelo grupo.

**Dados.** `backend/data/palavras.txt` foi gerada por
`scripts/gerar_palavras.py` a partir do `palavras.txt` do repositório
https://github.com/pythonprobr/palavras, com licença MPL 2.0
(`backend/data/LICENSE-palavras`). `backend/data/respostas.txt` foi gerada
por `scripts/gerar_respostas.py` com a biblioteca `wordfreq`.

**Referências.** Documentação do SWI-Prolog e do janus, guia do Elm,
documentação dos pacotes `elm/json` e `elm/http` e documentação do FastAPI.

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** intensivo

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| Claude (Anthropic) | Escrita de código Prolog, Elm e Python, testes, revisão de PRs e rascunhos de texto | Testes plunit, pytest e elm-test, partidas jogadas no navegador e revisão de cada PR por outro integrante antes do merge |
| Antigravity (Google) | Usada por Gabriel Fernando de Jesus Silva na interface, grade e estilo (`Main.elm` e `style-simples.css`, #10) | Revisão do PR #10 por outro integrante antes do merge |

## 12. Apresentação oral

- **Slides:** não há
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| Contexto e objetivo | 2 min | Lucas Mendonça Arruda |
| Demonstração com modos assistente, automático e caos | 5 min | Gabriel Fernando de Jesus Silva e Artur Mendonça Arruda |
| Código Prolog | 3 min | João Pedro Costa e Rafael Ferreira Leandro |
| Código Elm | 3 min | Maria Clara Sena de Lima |
| Limitações e aprendizados | 2 min | Lucas Avelar |

## 13. Reflexão sobre os paradigmas

Em Prolog, o filtro de candidatas saiu curto porque o mesmo `feedback/3`
calcula as cores e também confere cores já dadas. `candidates/2` só gera
palavras com `word/1` e deixa o `feedback/3` falhar nas que não servem. A
parte difícil foi o desempenho do minimax em `strategy.pl`. Para responder
em menos de 2 segundos usamos `setarg/3` num contador, a contagem de
`conta/6` interrompida assim que um grupo passa do limite, um teto de
chamadas (`orcamento/1`) e uma abertura calculada antes. Essas decisões
falam da ordem de execução, coisa que o resto do código não precisou
fazer. O estado das partidas do modo caos (`assertz/1` e `retract/1`)
também fugiu do estilo declarativo do resto.

No Elm, o compilador apontou cada lugar a mudar quando o modo caos ganhou
efeitos novos: um construtor a mais em `Efeito` obriga a tratar o caso em
`nome`, `descricao` e `codigo` (`Caos.elm`), e o código não compila até
isso ser feito. O `Remoto a` e o tipo opaco `Rascunho` tiraram da tela
estados que antes dependiam de `Bool` soltos. O compilador não pegou o
problema das respostas HTTP fora de ordem: uma resposta atrasada de uma
partida antiga sobrescrevia a nova, e isso foi corrigido com o contador
`pedido` nos dois modos.

Entre as duas linguagens, a diferença mais visível no código foi onde fica
o estado. No Prolog, a regra do caos olha o estado da partida e diz quais
efeitos são possíveis (`efeito_possivel/2`). No Elm, cada mudança de tela
passa por uma mensagem no `update`, e o efeito visual de um evento do
Prolog (furos do tiroteio, letras explodidas) vira dado no `Model` com
duração controlada pelo próprio Elm.
