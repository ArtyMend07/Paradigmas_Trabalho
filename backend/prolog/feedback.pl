:- module(feedback, [feedback/3]).

:- encoding(utf8).

feedback(Palpite, Resposta, Cores) :-
    atom_chars(Palpite, LetrasPalpite),
    atom_chars(Resposta, LetrasResposta),
    verdes(LetrasPalpite, LetrasResposta, Marcas, Sobras),
    amarelos(Marcas, Sobras, Cores).

verdes([], [], [], []).
verdes([Letra|Ps], [Letra|Rs], [green|Marcas], Sobras) :-
    !,
    verdes(Ps, Rs, Marcas, Sobras).
verdes([P|Ps], [R|Rs], [pendente(P)|Marcas], [R|Sobras]) :-
    verdes(Ps, Rs, Marcas, Sobras).

amarelos([], _, []).
amarelos([green|Marcas], Sobras, [green|Cores]) :-
    amarelos(Marcas, Sobras, Cores).
amarelos([pendente(Letra)|Marcas], Sobras, [Cor|Cores]) :-
    (   selectchk(Letra, Sobras, Restantes)
    ->  Cor0 = yellow
    ;   Cor0 = gray,
        Restantes = Sobras
    ),
    Cor = Cor0,
    amarelos(Marcas, Restantes, Cores).
