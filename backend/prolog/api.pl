:- module(api, [api_candidatas/2, api_sugestao/3, api_autoplay/2]).
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
