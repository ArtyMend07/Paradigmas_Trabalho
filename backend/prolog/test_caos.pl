:- use_module(caos).
:- use_module(feedback).
:- use_module(words).
:- use_module(autoplay).
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
    load_respostas(Respostas),
    set_random(seed(14)).

linha_de(Resposta, Palpite, linha(Palpite, Cores, nenhum, cores(Cores))) :-
    feedback(Palpite, Resposta, Cores).

estado_com(Resposta, Palpites, Max, estado(Resposta, Linhas, nenhum, Max)) :-
    maplist(linha_de(Resposta), Palpites, Linhas).

partida_de_teste(Id, Estado) :-
    Id = teste,
    retractall(caos:partida(Id, _)),
    assertz(caos:partida(Id, Estado)).

diferencas([], [], 0).
diferencas([A|As], [B|Bs], Total) :-
    diferencas(As, Bs, Resto),
    ( A == B -> Total = Resto ; Total is Resto + 1 ).

:- begin_tests(caos_partida, [setup(carrega_bases)]).

test(nova_partida_sorteia_resposta_valida) :-
    nova_partida(Id),
    partida(Id, estado(Resposta, Linhas, Pendente, Max)),
    assertion(resposta(Resposta)),
    assertion(word(Resposta)),
    assertion(Linhas == []),
    assertion(Pendente == nenhum),
    assertion(Max == 6).

test(palavra_fora_da_base, Resultado == erro(palavra_invalida)) :-
    estado_com(carro, [], 6, Estado),
    partida_de_teste(Id, Estado),
    jogar(Id, xyzwq, Resultado).

test(partida_inexistente, Resultado == erro(partida_inexistente)) :-
    jogar(nao_existe, carro, Resultado).

test(acerto_encerra_a_partida) :-
    estado_com(carro, [], 6, Estado),
    partida_de_teste(Id, Estado),
    jogar(Id, carro, ok(Novo, Evento)),
    assertion(acertou(Novo)),
    assertion(encerrada(Novo)),
    assertion(Evento == nenhum),
    jogar(Id, termo, Depois),
    assertion(Depois == erro(partida_encerrada)).

test(sem_efeito_depois_de_um_palpite) :-
    estado_com(carro, [], 6, Estado),
    partida_de_teste(Id, Estado),
    jogar(Id, termo, ok(estado(_, _, Pendente, _), Evento)),
    assertion(Pendente == nenhum),
    assertion(Evento == nenhum).

test(efeito_sorteado_a_cada_dois_palpites) :-
    estado_com(carro, [termo], 6, Estado),
    partida_de_teste(Id, Estado),
    jogar(Id, pulha, ok(_, Evento)),
    assertion(Evento \== nenhum).

test(escudo_devolve_a_linha_do_erro) :-
    partida_de_teste(Id, estado(carro, [], escudo, 6)),
    jogar(Id, termo, ok(estado(_, _, _, Max), _)),
    assertion(Max == 7).

test(escudo_nao_muda_nada_no_acerto) :-
    partida_de_teste(Id, estado(carro, [], escudo, 6)),
    jogar(Id, carro, ok(estado(_, _, _, Max), _)),
    assertion(Max == 6).

:- end_tests(caos_partida).

:- begin_tests(caos_exibicao, [setup(carrega_bases)]).

test(cor_mentirosa_muda_exatamente_uma_casa, forall(between(1, 30, _))) :-
    feedback(barra, carro, Cores),
    exibicao(cor_mentirosa, Cores, cores(Mentira)),
    diferencas(Cores, Mentira, Total),
    assertion(Total == 1).

test(cores_invertidas_trocam_verde_e_cinza,
     Exibida == cores([green, yellow, gray, gray, yellow])) :-
    feedback(terra, barre, Cores),
    exibicao(cores_invertidas, Cores, Exibida).

test(so_contagem_mostra_verdes_e_amarelas, Exibida == contagem(2, 2)) :-
    feedback(terra, barre, Cores),
    exibicao(so_contagem, Cores, Exibida).

test(sem_efeito_mostra_as_cores_reais, Exibida == cores(Cores)) :-
    feedback(barra, carro, Cores),
    exibicao(nenhum, Cores, Exibida).

:- end_tests(caos_exibicao).

:- begin_tests(caos_solucao, [setup(carrega_bases)]).

test(atrapalhar_exige_uma_linha_limpa_depois, forall(member(Efeito, [cor_mentirosa, cores_invertidas, so_contagem, tempo_parado]))) :-
    estado_com(carro, [termo, pulha, sabia, nuvem, fosco], 6, Estado),
    assertion(\+ efeito_possivel(Efeito, Estado)).

test(atrapalhar_permitido_com_linhas_sobrando) :-
    estado_com(carro, [termo], 6, Estado),
    assertion(efeito_possivel(cor_mentirosa, Estado)).

test(sorteio_respeita_as_linhas_restantes, forall(between(1, 30, _))) :-
    estado_com(carro, [termo, pulha, sabia, nuvem], 6, Estado),
    partida_de_teste(Id, Estado),
    jogar(Id, fosco, ok(estado(_, _, Pendente, _), _)),
    assertion(\+ memberchk(Pendente, [cor_mentirosa, cores_invertidas, so_contagem, tempo_parado])).

test(troca_mantem_as_cores_ja_mostradas) :-
    estado_com(carro, [termo, barra], 6, Estado),
    Estado = estado(_, Linhas, _, _),
    findall(Outra, outra_resposta(Estado, Outra), Outras),
    assertion(Outras \== []),
    forall(( member(Outra, Outras), member(linha(Palpite, Cores, _, _), Linhas) ),
           assertion(feedback(Palpite, Outra, Cores))).

test(troca_impossivel_quando_so_sobra_a_resposta) :-
    estado_com(carro, [carro], 6, Estado),
    assertion(\+ efeito_possivel(troca_de_palavra, Estado)).

test(voltar_no_tempo_exige_um_palpite) :-
    estado_com(carro, [], 6, Estado),
    assertion(\+ efeito_possivel(voltar_no_tempo, Estado)).

test(dica_e_letra_ainda_nao_jogada) :-
    estado_com(carro, [termo], 6, Estado),
    dica_de_letra(Estado, Letra),
    assertion(\+ memberchk(Letra, [t, e, r, m, o])).

test(dica_diz_se_a_letra_esta_na_resposta) :-
    estado_com(carro, [termo], 6, Estado),
    caos:aplicar_efeito(dica_de_letra, Estado, _, dica(Letra, Presenca)),
    atom_chars(carro, Letras),
    ( memberchk(Letra, Letras) -> Esperada = presente ; Esperada = ausente ),
    assertion(Presenca == Esperada).

test(efeito_so_na_tela_nao_muda_a_partida,
     forall(member(Efeito, [tiroteio, letras_apagadas, explosao_no_teclado, limpeza_do_teclado]))) :-
    estado_com(carro, [termo, pulha], 6, Estado),
    assertion(efeito_possivel(Efeito, Estado)),
    caos:aplicar_efeito(Efeito, Estado, Novo, Evento),
    assertion(Novo == Estado),
    assertion(Evento == instantaneo(Efeito)).

:- end_tests(caos_solucao).
