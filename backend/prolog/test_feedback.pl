:- use_module(feedback).
:- use_module(words).
:- use_module(library(plunit)).

:- dynamic arquivo_palavras/1.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '../data/palavras.txt', Arquivo),
   assertz(arquivo_palavras(Arquivo)).

:- begin_tests(feedback).

test(exemplo_barra_carro, Cores == [gray, green, green, green, gray]) :-
    feedback(barra, carro, Cores).

test(verde_consome_letra_repetida, Cores == [gray, gray, yellow, green, green]) :-
    feedback(teste, sorte, Cores).

test(amarelo_consome_letra_repetida, Cores == [green, green, gray, yellow, gray]) :-
    feedback(papai, pasta, Cores).

test(repetida_no_palpite_uma_na_resposta, Cores == [yellow, yellow, gray, green, gray]) :-
    feedback(arara, carro, Cores).

test(acerto, Cores == [green, green, green, green, green]) :-
    feedback(termo, termo, Cores).

test(verifica_cores_instanciadas) :-
    feedback(terra, barre, [gray, yellow, green, green, yellow]).

test(rejeita_gray_onde_deveria_ser_yellow, [fail]) :-
    feedback(terra, barre, [gray, gray, green, green, yellow]).

test(nenhuma_letra_em_comum, Cores == [gray, gray, gray, gray, gray]) :-
    feedback(pulha, termo, Cores).

:- end_tests(feedback).

:- begin_tests(words).

test(carrega_base) :-
    arquivo_palavras(Arquivo),
    load_words(Arquivo),
    aggregate_all(count, word(_), Total),
    assertion(Total > 8000),
    assertion(word(carro)),
    assertion(word(termo)).

test(recarregar_nao_duplica) :-
    arquivo_palavras(Arquivo),
    load_words(Arquivo),
    aggregate_all(count, word(_), Antes),
    load_words(Arquivo),
    aggregate_all(count, word(_), Depois),
    assertion(Antes == Depois).

:- end_tests(words).
