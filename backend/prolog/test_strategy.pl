:- use_module(strategy).
:- use_module(feedback).
:- use_module(candidates).
:- use_module(words).
:- use_module(library(plunit)).

:- encoding(utf8).

:- dynamic arquivo_palavras/1.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '../data/palavras.txt', Arquivo),
   assertz(arquivo_palavras(Arquivo)).

carrega_base :-
    arquivo_palavras(Arquivo),
    load_words(Arquivo).

%   rapido(:Objetivo): Objetivo é executado em menos de 2 s de CPU.
:- meta_predicate rapido(0).
rapido(Objetivo) :-
    statistics(cputime, T0),
    once(Objetivo),
    statistics(cputime, T1),
    Tempo is T1 - T0,
    assertion(Tempo < 2.0).

%   joga(+Resposta, -Passos): mesmo laço do autoplay/2 (#2), usado aqui
%   enquanto autoplay.pl não está disponível.
joga(Resposta, Passos) :-
    joga(Resposta, [], Passos).

joga(Resposta, Historico, Passos) :-
    best_guess(Historico, Palpite, _),
    feedback(Palpite, Resposta, Cores),
    append(Historico, [[Palpite, Cores]], Historico1),
    (   Palpite == Resposta
    ->  Passos = Historico1
    ;   length(Historico1, L),
        L < 10,
        joga(Resposta, Historico1, Passos)
    ).

:- begin_tests(strategy, [setup(carrega_base)]).

test(abertura_definida_e_na_base) :-
    abertura(W),
    assertion(word(W)).

test(historico_vazio_retorna_abertura) :-
    best_guess([], W, Motivo),
    abertura(A),
    assertion(W == A),
    assertion(string(Motivo)).

test(sem_candidatas_falha, [fail]) :-
    best_guess([[barra, [green, green, green, green, green]],
                [carro, [green, green, green, green, green]]], _, _).

test(uma_candidata_retorna_ela) :-
    best_guess([[papai, [green, green, gray, yellow, gray]],
                [sessa, [gray, gray, green, gray, green]]], W, Motivo),
    assertion(W == pasta),
    assertion(Motivo == "resta 1 palavra; este palpite é a resposta").

test(exemplo_barra) :-
    H = [[barra, [gray, green, green, green, gray]]],
    rapido(best_guess(H, W, Motivo)),
    candidates(H, Cs),
    length(Cs, N),
    assertion(word(W)),
    format(string(Inicio), "restam ~d palavras; ", [N]),
    assertion(sub_string(Motivo, 0, _, _, Inicio)).

test(minimax_separa_todas_as_candidatas) :-
    % O "máximo" informado no motivo é de fato o maior grupo do palpite.
    H = [[barra, [gray, green, green, green, gray]]],
    best_guess(H, W, Motivo),
    candidates(H, Cs),
    findall(C, ( member(X, Cs), feedback(W, X, C) ), Grupos),
    msort(Grupos, Ordenados),
    clumped_pairs(Ordenados, Maior),
    format(string(Esperado), "sobram no máximo ~d", [Maior]),
    assertion(sub_string(Motivo, _, _, 0, Esperado)).

test(aceita_strings_vindas_do_python) :-
    best_guess([["barra", ["gray", "green", "green", "green", "gray"]]], W, _),
    assertion(atom(W)).

test(rapido_apos_abertura_ruim) :-
    % palpite com só cinzas deixa milhares de candidatas: caso mais caro.
    abertura(A),
    feedback(A, xxxxx, Cores),
    rapido(best_guess([[A, Cores]], _, _)).

test(rapido_apos_abertura) :-
    abertura(A),
    forall(member(R, [carro, termo, pasta, sorte, mundo]),
           ( feedback(A, R, Cores),
             rapido(best_guess([[A, Cores]], _, _)) )).

test(acerta_em_ate_6_tentativas) :-
    forall(member(R, [carro, termo, pasta, sorte, mundo, papai, jarro]),
           ( joga(R, Passos),
             last(Passos, [Ultimo, Cores]),
             assertion(Ultimo == R),
             assertion(Cores == [green, green, green, green, green]),
             length(Passos, L),
             assertion(L =< 6) )).

:- end_tests(strategy).

clumped_pairs(Ordenados, Maior) :-
    clumped(Ordenados, Pares),
    aggregate_all(max(N), member(_-N, Pares), Maior).
