:- use_module(candidates).
:- use_module(words).
:- use_module(library(plunit)).

:- dynamic arquivo_palavras/1.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '../data/palavras.txt', Arquivo),
   assertz(arquivo_palavras(Arquivo)).

carrega_base :-
    arquivo_palavras(Arquivo),
    load_words(Arquivo).

:- begin_tests(candidates, [setup(carrega_base)]).

test(historico_vazio_retorna_base_inteira) :-
    candidates([], Ws),
    findall(W, word(W), Base),
    assertion(Ws == Base).

test(sem_palavra_compativel, Ws == []) :-
    %nenhuma palavra pode ser barra e carro ao mesmo tempo
    candidates([[barra, [green, green, green, green, green]],
                [carro, [green, green, green, green, green]]], Ws).

test(um_palpite_exemplo_barra, Ws == [carre, carri, carro, jarro, larro,
                                      sarro, tarro, varre, zarro]) :-
    candidates([[barra, [gray, green, green, green, gray]]], Ws).

test(um_palpite_letra_repetida_no_palpite,
     Ws == [barre, barro, carre, carri, carro, jarro, larro,
            sarro, tarro, varre, zarro]) :-
    % arara tem tres "a" e carro so um, entao so o primeiro "a" fora do
    % lugar fica amarelo e os outros ficam cinza
    candidates([[arara, [yellow, yellow, gray, green, gray]]], Ws).

test(dois_palpites_letras_repetidas, Ws == [pasta]) :-
    % papai e sessa repetem letra. o "s" repetido de sessa so pinta um verde
    candidates([[papai, [green, green, gray, yellow, gray]],
                [sessa, [gray, gray, green, gray, green]]], Ws).

test(dois_palpites_amarelo_exclui_candidata) :-
    % barre daria yellow no "e" de terra, entao sai da lista
    candidates([[arara, [yellow, yellow, gray, green, gray]],
                [terra, [gray, gray, green, green, yellow]]], Ws),
    assertion(Ws == [barro, carri, carro, jarro, larro, sarro, zarro]),
    assertion(\+ memberchk(barre, Ws)).

test(tres_palpites_letras_repetidas,
     Ws == [carri, carro, jarro, larro, sarro, zarro]) :-
    candidates([[arara, [yellow, yellow, gray, green, gray]],
                [terra, [gray, gray, green, green, yellow]],
                [barra, [gray, green, green, green, gray]]], Ws).

test(tres_palpites_ate_a_resposta, Ws == [pasta]) :-
    candidates([[papai, [green, green, gray, yellow, gray]],
                [sessa, [gray, gray, green, gray, green]],
                [pasta, [green, green, green, green, green]]], Ws).

test(aceita_strings_vindas_do_python, Ws == [pasta]) :-
    candidates([["papai", ["green", "green", "gray", "yellow", "gray"]],
                ["sessa", ["gray", "gray", "green", "gray", "green"]]], Ws).

test(consistent_aceita) :-
    consistent(carro, [[barra, [gray, green, green, green, gray]]]).

test(consistent_rejeita, [fail]) :-
    consistent(barre, [[terra, [gray, gray, green, green, yellow]]]).

test(consistent_historico_vazio) :-
    consistent(qualquer, []).

:- end_tests(candidates).
