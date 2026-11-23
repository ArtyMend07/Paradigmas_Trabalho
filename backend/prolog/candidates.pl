:- module(candidates, [consistent/2, candidates/2]).

:- encoding(utf8).

:- use_module(feedback).
:- use_module(words).

% consistent(+Candidata, +Historico)
% a candidata ainda pode ser a resposta se, pra cada [Palpite, Cores] do
% historico, feedback(Palpite, Candidata, Cores) da as mesmas cores.
% quem confere e o proprio feedback/3.
consistent(Candidata, Historico) :-
    consistente(Historico, Candidata).

% historico no primeiro argumento pra indexacao nao deixar choicepoints.
consistente([], _).
consistente([[Palpite, Cores]|Resto], Candidata) :-
    maplist(como_atomo, Cores, CoresAtomos),
    feedback(Palpite, Candidata, CoresAtomos),
    consistente(Resto, Candidata).

% candidates(+Historico, -Palavras)
% todas as palavras da base (word/1) que batem com o historico, na ordem
% da base. historico vazio devolve a base inteira.
candidates(Historico, Palavras) :-
    findall(W, ( word(W), consistent(W, Historico) ), Palavras).

% o janus manda as cores como string ("green") e o feedback/3 usa atomo
% (green). atom_string/2 aceita os dois.
como_atomo(X, A) :-
    atom_string(A, X).
