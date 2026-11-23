:- module(autoplay, [resposta/1, load_respostas/1, autoplay/2]).

:- encoding(utf8).

:- use_module(feedback).
:- use_module(candidates).

:- dynamic resposta/1.

% load_respostas(+Arquivo)
% igual ao load_words/1, mas cria fatos resposta/1. apaga os que ja tinha
% antes, entao carregar de novo nao duplica.
load_respostas(Arquivo) :-
    retractall(resposta(_)),
    read_file_to_string(Arquivo, Texto, [encoding(utf8)]),
    split_string(Texto, "\n", "\r ", Linhas),
    forall(( member(Linha, Linhas), Linha \== "" ),
           ( atom_string(Palavra, Linha), assertz(resposta(Palavra)) )).

:- if(( prolog_load_context(directory, Dir),
        directory_file_path(Dir, 'strategy.pl', Arquivo),
        exists_file(Arquivo) )).
:- use_module(strategy).
:- else.
best_guess(Historico, Palavra, "provisorio: primeira candidata") :-
    candidates(Historico, [Palavra|_]).
:- endif.

% autoplay(+Resposta, -Passos)
% o solver joga sozinho ate acertar. na ordem em que foram jogados, e o ultimo e a resposta toda green.
% falha se a palavra nao for resposta/1.
autoplay(Resposta, Passos) :-
    atom_string(R, Resposta),   % aceita atomo ou string (vindo do python)
    resposta(R),
    joga(R, [], Passos).

joga(Resposta, Historico, [[Palpite, Cores]|Resto]) :-
    once(best_guess(Historico, Palpite, _)),
    % se o best_guess repetir palpite o jogo nunca acaba, entao falha
    \+ memberchk([Palpite, _], Historico),
    feedback(Palpite, Resposta, Cores),
    (   Palpite == Resposta
    ->  Resto = []
    ;   append(Historico, [[Palpite, Cores]], Historico1),
        joga(Resposta, Historico1, Resto)
    ).
