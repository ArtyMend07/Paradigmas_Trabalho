:- use_module(autoplay).
:- use_module(feedback).
:- use_module(words).
:- use_module(library(plunit)).

:- dynamic arquivo/2.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '../data/palavras.txt', Palavras),
   directory_file_path(Dir, '../data/respostas.txt', Respostas),
   assertz(arquivo(palavras, Palavras)),
   assertz(arquivo(respostas, Respostas)).

carrega_bases :-
    arquivo(palavras, Palavras),
    arquivo(respostas, Respostas),
    load_words(Palavras),
    load_respostas(Respostas).

:- begin_tests(respostas, [setup(carrega_bases)]).

test(toda_resposta_e_word) :-
    forall(resposta(R), assertion(word(R))).

test(tamanho_entre_1000_e_2500) :-
    aggregate_all(count, resposta(_), Total),
    assertion(between(1000, 2500, Total)).

test(palavras_comuns_estao_nas_respostas) :-
    assertion(resposta(carro)),
    assertion(resposta(termo)),
    assertion(resposta(mundo)).

test(nomes_proprios_nao_sao_resposta) :-
    forall(member(Nome, [maria, paulo, pedro, souza, lucas, japao, egito]),
           assertion(\+ resposta(Nome))).

test(recarregar_nao_duplica) :-
    aggregate_all(count, resposta(_), Antes),
    arquivo(respostas, Respostas),
    load_respostas(Respostas),
    aggregate_all(count, resposta(_), Depois),
    assertion(Antes == Depois).

:- end_tests(respostas).

:- begin_tests(autoplay, [setup(carrega_bases)]).

test(termina_com_tudo_green) :-
    autoplay(carro, Passos),
    last(Passos, Ultimo),
    assertion(Ultimo == [carro, [green, green, green, green, green]]).

test(so_o_ultimo_passo_e_a_resposta) :-
    autoplay(mundo, Passos),
    once(append(Antes, [[mundo, _]], Passos)),
    assertion(\+ memberchk([mundo, _], Antes)).

test(cores_de_cada_passo_batem_com_feedback) :-
    autoplay(pasta, Passos),
    forall(member([P, C], Passos), assertion(feedback(P, pasta, C))).

test(nao_repete_palpite) :-
    autoplay(termo, Passos),
    findall(P, member([P, _], Passos), Ps),
    sort(Ps, Unicos),
    length(Ps, N),
    assertion(length(Unicos, N)).

test(varias_respostas_terminam) :-
    forall(member(R, [livre, sorte, idade, caixa, jurar]),
           ( autoplay(R, Passos),
             assertion(last(Passos, [R, [green, green, green, green, green]])) )).

test(aceita_string_vinda_do_python) :-
    autoplay("carro", Passos),
    assertion(last(Passos, [carro, _])).

test(falha_para_palavra_fora_das_respostas, [fail]) :-
    % carri esta no palavras.txt mas nao no respostas.txt
    autoplay(carri, _).

test(falha_para_palavra_que_nao_existe, [fail]) :-
    autoplay(xyzwq, _).

:- end_tests(autoplay).
