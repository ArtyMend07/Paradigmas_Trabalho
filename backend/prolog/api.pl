:- module(api, [api_candidatas/2, api_sugestao/3, api_autoplay/2,
                api_caos_nova/1, api_caos_palpite/3]).
:- encoding(utf8).

/** <module> Fachada do Prolog usada pelo Python (janus)

Este é o único arquivo .pl que o backend Python consulta. Ele carrega a base
de palavras na inicialização e expõe três predicados, um por rota HTTP.

O janus converte as strings do Python em strings do Prolog, mas os
predicados de feedback.pl, candidates.pl, strategy.pl e autoplay.pl
trabalham com átomos (`carro`, `green`). A conversão nos dois sentidos fica
toda aqui, com atom_string/2 e maplist/3, para que nenhum outro módulo
precise saber de onde os dados vieram.
*/

:- use_module(words).
:- use_module(candidates).
:- use_module(strategy).
:- use_module(autoplay).
:- use_module(caos).

/* =========================================================================
   1. CARREGAMENTO DA BASE
   ========================================================================= */

%   O caminho dos arquivos é resolvido a partir da pasta deste .pl
%   (backend/prolog), e não da pasta em que o processo foi iniciado. Assim
%   `make backend`, `uv run pytest` e `swipl backend/prolog/api.pl` acham a
%   base do mesmo jeito. Nada é baixado da rede.
:- dynamic pasta_prolog/1.
:- prolog_load_context(directory, Dir),
   retractall(pasta_prolog(_)),
   assertz(pasta_prolog(Dir)).

arquivo_de_dados(Nome, Caminho) :-
    pasta_prolog(Dir),
    atomic_list_concat([Dir, '/../data/', Nome], Caminho).

carrega_base :-
    arquivo_de_dados('palavras.txt', Palavras),
    arquivo_de_dados('respostas.txt', Respostas),
    load_words(Palavras),
    load_respostas(Respostas).

%   initialization/1 roda carrega_base/0 depois que o arquivo inteiro foi
%   lido, quando todos os predicados acima já existem.
:- initialization(carrega_base).

/* =========================================================================
   2. CONVERSÕES ENTRE STRINGS (PYTHON) E ÁTOMOS (PROLOG)
   ========================================================================= */

%   historico_atomos(+HistoricoStrings, -HistoricoAtomos)
%   Cada palpite chega como [palavra, [cor, cor, cor, cor, cor]].
historico_atomos(Historico, HistoricoAtomos) :-
    maplist(palpite_atomos, Historico, HistoricoAtomos).

palpite_atomos([Palavra, Cores], [PalavraA, CoresA]) :-
    atom_string(PalavraA, Palavra),
    maplist(atom_string, CoresA, Cores).

%   Na volta, átomos viram strings. O janus entregaria átomos como str de
%   qualquer jeito, mas três átomos são exceção (true, false e none viram
%   bool e None no Python); devolver strings evita a surpresa.
palpite_strings([Palavra, Cores], [PalavraS, CoresS]) :-
    atom_string(Palavra, PalavraS),
    maplist(atom_string, Cores, CoresS).

/* =========================================================================
   3. PREDICADOS CHAMADOS PELO PYTHON
   ========================================================================= */

%!  api_candidatas(+Historico, -Palavras) is semidet.
%
%   Palavras da base compatíveis com o histórico. Falha quando nenhuma é
%   compatível; o Python traduz a falha no erro 422.
api_candidatas(Historico, Palavras) :-
    historico_atomos(Historico, H),
    candidates(H, Atomos),
    Atomos \== [],
    maplist(atom_string, Atomos, Palavras).

%!  api_sugestao(+Historico, -Palavra, -Motivo) is semidet.
%
%   Próximo palpite pelo critério minimax (best_guess/3, #3). Falha quando
%   não há candidata compatível com o histórico.
api_sugestao(Historico, Palavra, Motivo) :-
    historico_atomos(Historico, H),
    once(best_guess(H, Atomo, Motivo0)),
    atom_string(Atomo, Palavra),
    text_to_string(Motivo0, Motivo).

%!  api_autoplay(+Palavra, -Resultado) is det.
%
%   Resultado é a lista de passos [[palpite, cores], ...] até acertar, ou o
%   átomo `nao_encontrada` quando a palavra não está em respostas.txt.
%   Como em hint/2 do template, a decisão fica no Prolog e o Python só
%   traduz cada forma de resultado numa resposta HTTP.
api_autoplay(Palavra, Resultado) :-
    atom_string(Atomo, Palavra),
    (   resposta(Atomo),
        once(autoplay(Atomo, Passos))
    ->  maplist(palpite_strings, Passos, Resultado)
    ;   Resultado = nao_encontrada
    ).

/* =========================================================================
   4. MODO CAOS (#14)
   ========================================================================= */

%!  api_caos_nova(-Partida) is det.
api_caos_nova(Partida) :-
    nova_partida(Id),
    partida(Id, Estado),
    partida_json(Id, Estado, nenhum, Partida).

%!  api_caos_palpite(+Id, +Palavra, -Resultado) is det.
%
%   Resultado é o dict da partida ou o átomo do erro (palavra_invalida,
%   partida_inexistente, partida_encerrada), que o Python traduz em HTTP.
api_caos_palpite(Id, Palavra, Resultado) :-
    atom_string(Atomo, Palavra),
    jogar(Id, Atomo, Jogada),
    resultado_json(Id, Jogada, Resultado).

resultado_json(_, erro(Motivo), Motivo).
resultado_json(Id, ok(Estado, Evento), Partida) :-
    partida_json(Id, Estado, Evento, Partida).

partida_json(Id, Estado, Evento, _{ id: Id,
                                    linhas: Linhas,
                                    max_linhas: Max,
                                    proximo: Proximo,
                                    evento: EventoJson,
                                    situacao: Situacao,
                                    resposta: Revelada }) :-
    Estado = estado(Resposta, LinhasEstado, Pendente, Max),
    linhas_json(LinhasEstado, Linhas),
    efeito_string(Pendente, Proximo),
    evento_json(Evento, EventoJson),
    situacao(Estado, Situacao),
    resposta_revelada(Situacao, Resposta, Revelada).

%   A linha jogada sob tempo_parado só mostra as cores depois do palpite seguinte.
linhas_json(Linhas, Json) :-
    length(Linhas, Total),
    findall(L, ( nth1(I, Linhas, Linha), linha_json(I, Total, Linha, L) ), Json).

linha_json(Posicao, Total, linha(Palavra, _, Efeito, Exibicao), Json) :-
    (   Efeito == tempo_parado, Posicao =:= Total
    ->  Visivel = oculta
    ;   Visivel = Exibicao
    ),
    atom_string(Palavra, PalavraS),
    efeito_string(Efeito, EfeitoS),
    exibicao_json(Visivel, PalavraS, EfeitoS, Json).

exibicao_json(cores(Cores), Palavra, Efeito,
              _{palavra: Palavra, efeito: Efeito, tipo: "cores", cores: CoresS, verdes: 0, amarelas: 0}) :-
    maplist(atom_string, Cores, CoresS).
exibicao_json(contagem(Verdes, Amarelas), Palavra, Efeito,
              _{palavra: Palavra, efeito: Efeito, tipo: "contagem", cores: [], verdes: Verdes, amarelas: Amarelas}).
exibicao_json(oculta, Palavra, Efeito,
              _{palavra: Palavra, efeito: Efeito, tipo: "oculta", cores: [], verdes: 0, amarelas: 0}).

efeito_string(nenhum, "") :- !.
efeito_string(Efeito, Texto) :-
    atom_string(Efeito, Texto).

evento_json(nenhum, _{efeito: "", letra: "", presente: false}).
evento_json(anuncio(_), _{efeito: "", letra: "", presente: false}).
evento_json(instantaneo(Efeito), _{efeito: Texto, letra: "", presente: false}) :-
    atom_string(Efeito, Texto).
evento_json(dica(Letra, Presenca), _{efeito: "dica_de_letra", letra: Texto, presente: Presente}) :-
    atom_string(Letra, Texto),
    ( Presenca == presente -> Presente = true ; Presente = false ).

situacao(Estado, "venceu") :-
    acertou(Estado),
    !.
situacao(Estado, "perdeu") :-
    encerrada(Estado),
    !.
situacao(_, "em_andamento").

resposta_revelada("perdeu", Resposta, Texto) :-
    !,
    atom_string(Resposta, Texto).
resposta_revelada(_, _, "").
