:- module(candidates, [consistent/2, candidates/2]).

:- encoding(utf8).

:- use_module(feedback).
:- use_module(words).

consistent(Candidata, Historico) :-
    consistente(Historico, Candidata).

% Histórico no primeiro argumento para a indexação não deixar choicepoints.
consistente([], _).
consistente([[Palpite, Cores]|Resto], Candidata) :-
    maplist(como_atomo, Cores, CoresAtomos),
    feedback(Palpite, Candidata, CoresAtomos),
    consistente(Resto, Candidata).


candidates(Historico, Palavras) :-
    findall(W, ( word(W), consistent(W, Historico) ), Palavras).

como_atomo(X, A) :-
    atom_string(A, X).
