:- module(feedback, [feedback/3]).

:- encoding(utf8).

% feedback(+Palpite, +Resposta, ?Cores)
% calcula as cores (green, yellow, gray) do palpite pra essa resposta.
% se Cores ja vier preenchido, so confere se bate. faz em duas passadas: primeiro os verdes, que gastam a letra da resposta,
% depois os amarelos com o que sobrou. nao ganha amarelo a mais.
feedback(Palpite, Resposta, Cores) :-
    atom_chars(Palpite, LetrasPalpite),
    atom_chars(Resposta, LetrasResposta),
    verdes(LetrasPalpite, LetrasResposta, Marcas, Sobras),
    amarelos(Marcas, Sobras, Cores).

% verdes(+Palpite, +Resposta, -Marcas, -Sobras)
% letra igual na mesma posicao vira green, o resto fica pendente(Letra).
% Sobras = letras da resposta que nao foram verdes. o corte e pra letra verde nao cair tambem na clausula de pendente.
verdes([], [], [], []).
verdes([Letra|Ps], [Letra|Rs], [green|Marcas], Sobras) :-
    !,
    verdes(Ps, Rs, Marcas, Sobras).
verdes([P|Ps], [R|Rs], [pendente(P)|Marcas], [R|Sobras]) :-
    verdes(Ps, Rs, Marcas, Sobras).

% amarelos(+Marcas, +Sobras, ?Cores)
% pendente vira yellow se a letra ainda ta nas Sobras (e tira uma), senao gray.
amarelos([], _, []).
amarelos([green|Marcas], Sobras, [green|Cores]) :-
    amarelos(Marcas, Sobras, Cores).
amarelos([pendente(Letra)|Marcas], Sobras, [Cor|Cores]) :-
    (   selectchk(Letra, Sobras, Restantes)
    ->  Cor0 = yellow
    ;   Cor0 = gray,
        Restantes = Sobras
    ),
% decide a cor em Cor0 e so depois unifica com Cor.
    Cor = Cor0,
    amarelos(Marcas, Restantes, Cores).
