:- module(caos,
          [ nova_partida/1,
            jogar/3,
            partida/2,
            efeito/2,
            efeito_possivel/2,
            exibicao/3,
            dica_de_letra/2,
            outra_resposta/2,
            encerrada/1,
            acertou/1
          ]).

:- encoding(utf8).

:- use_module(library(random)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).
:- use_module(feedback).
:- use_module(candidates).
:- use_module(words).
:- use_module(autoplay).

% partida(Id, estado(Resposta, Linhas, EfeitoPendente, MaxLinhas))
% Linhas vai do primeiro ao ultimo palpite, cada uma
% linha(Palpite, CoresReais, Efeito, Exibicao).
:- dynamic partida/2.

% linhas_desfeitas(Id, Total): quantas linhas o voltar_no_tempo ja apagou.
% Entra na conta do efeito a cada 2 palpites, que conta palpites feitos e nao
% linhas na tela. Sem o fato, vale 0.
:- dynamic linhas_desfeitas/2.

% partidas mais antigas que isso saem da memoria quando uma nova comeca.
max_partidas_guardadas(1000).

linhas_iniciais(6).
palpites_por_efeito(2).
% um efeito que atrapalha a linha so entra se sobrar uma linha limpa depois dele.
linhas_minimas_para_atrapalhar(2).

% efeito(Nome, Tipo): linha vale para o proximo palpite, instantaneo vale na hora.
efeito(cor_mentirosa, linha).
efeito(cores_invertidas, linha).
efeito(so_contagem, linha).
efeito(tempo_parado, linha).
efeito(escudo, linha).
efeito(alarme_falso, linha).
efeito(troca_de_palavra, instantaneo).
efeito(dica_de_letra, instantaneo).
efeito(voltar_no_tempo, instantaneo).
% estes quatro só mudam a tela: o Prolog sorteia e o Elm faz o resto.
efeito(tiroteio, instantaneo).
efeito(letras_apagadas, instantaneo).
efeito(explosao_no_teclado, instantaneo).
efeito(limpeza_do_teclado, instantaneo).

so_na_tela(tiroteio).
so_na_tela(letras_apagadas).
so_na_tela(explosao_no_teclado).
so_na_tela(limpeza_do_teclado).

atrapalha_a_linha(cor_mentirosa).
atrapalha_a_linha(cores_invertidas).
atrapalha_a_linha(so_contagem).
atrapalha_a_linha(tempo_parado).

% nova_partida(-Id)
nova_partida(Id) :-
    findall(R, ( resposta(R), word(R) ), Respostas),
    random_member(Resposta, Respostas),
    linhas_iniciais(Max),
    with_mutex(caos,
               ( flag(caos_partida, Id, Id + 1),
                 assertz(partida(Id, estado(Resposta, [], nenhum, Max))),
                 esquecer_partidas_antigas
               )).

% guarda so as partidas mais recentes. As antigas sao as primeiras da base,
% porque cada partida nova entra com assertz.
esquecer_partidas_antigas :-
    max_partidas_guardadas(Limite),
    aggregate_all(count, partida(_, _), Total),
    Sobrando is Total - Limite,
    forall(( Sobrando > 0, limit(Sobrando, partida(Id, _)) ),
           ( retractall(partida(Id, _)),
             retractall(linhas_desfeitas(Id, _)) )).

% jogar(+Id, +Palpite, -Resultado)
% Resultado e ok(Estado, Evento) ou erro(Motivo).
% O mutex impede que dois palpites da mesma partida se misturem: o servidor
% atende cada requisicao numa thread.
jogar(Id, Palpite, Resultado) :-
    with_mutex(caos, jogar_(Id, Palpite, Resultado)).

jogar_(Id, _, erro(partida_inexistente)) :-
    \+ partida(Id, _),
    !.
jogar_(Id, _, erro(partida_encerrada)) :-
    partida(Id, Estado),
    encerrada(Estado),
    !.
jogar_(_, Palpite, erro(palavra_invalida)) :-
    \+ word(Palpite),
    !.
jogar_(Id, Palpite, ok(Novo, Evento)) :-
    retract(partida(Id, Estado)),
    registrar_palpite(Palpite, Estado, Registrado),
    desfeitas(Id, Desfeitas),
    proximo_efeito(Desfeitas, Registrado, Novo, Evento),
    contar_desfeita(Evento, Id, Desfeitas),
    assertz(partida(Id, Novo)).

desfeitas(Id, Total) :-
    (   linhas_desfeitas(Id, T)
    ->  Total = T
    ;   Total = 0
    ).

contar_desfeita(instantaneo(voltar_no_tempo), Id, Desfeitas) :-
    !,
    retractall(linhas_desfeitas(Id, _)),
    Total is Desfeitas + 1,
    assertz(linhas_desfeitas(Id, Total)).
contar_desfeita(_, _, _).

% A linha jogada sob tempo_parado fica oculta(Exibicao) ate o palpite seguinte.
% Depois de revelada ela nao volta a ficar oculta, nem se o voltar_no_tempo
% apagar a linha de depois.
registrar_palpite(Palpite, estado(Resposta, Linhas, Efeito, Max),
                  estado(Resposta, Linhas1, nenhum, Max1)) :-
    feedback(Palpite, Resposta, Cores),
    exibicao(Efeito, Cores, Exibicao),
    ocultar(Efeito, Exibicao, Mostrada),
    maplist(revelar, Linhas, Reveladas),
    append(Reveladas, [linha(Palpite, Cores, Efeito, Mostrada)], Linhas1),
    linhas_apos_escudo(Efeito, Palpite, Resposta, Max, Max1).

ocultar(tempo_parado, Exibicao, oculta(Exibicao)) :- !.
ocultar(_, Exibicao, Exibicao).

revelar(linha(P, C, E, oculta(Exibicao)), linha(P, C, E, Exibicao)) :- !.
revelar(Linha, Linha).

linhas_apos_escudo(escudo, Palpite, Resposta, Max, Max1) :-
    Palpite \== Resposta,
    !,
    Max1 is Max + 1.
linhas_apos_escudo(_, _, _, Max, Max).

% exibicao(+Efeito, +CoresReais, -Exibicao)
% o que o jogador ve da linha: cores(Lista) ou contagem(Verdes, Amarelas).
exibicao(cor_mentirosa, Cores, cores(Mentira)) :-
    !,
    mentir_em_uma_casa(Cores, Mentira).
exibicao(cores_invertidas, Cores, cores(Invertidas)) :-
    !,
    maplist(inverter_cor, Cores, Invertidas).
exibicao(so_contagem, Cores, contagem(Verdes, Amarelas)) :-
    !,
    contar(green, Cores, Verdes),
    contar(yellow, Cores, Amarelas).
exibicao(_, Cores, cores(Cores)).

mentir_em_uma_casa(Cores, Mentira) :-
    length(Cores, Tamanho),
    random_between(1, Tamanho, Posicao),
    nth1(Posicao, Cores, Real, Resto),
    findall(Cor, ( member(Cor, [green, yellow, gray]), Cor \== Real ), Falsas),
    random_member(Falsa, Falsas),
    nth1(Posicao, Mentira, Falsa, Resto).

inverter_cor(green, gray).
inverter_cor(gray, green).
inverter_cor(yellow, yellow).

contar(Cor, Cores, Total) :-
    include(==(Cor), Cores, Iguais),
    length(Iguais, Total).

% encerrada(+Estado)
encerrada(Estado) :-
    acertou(Estado),
    !.
encerrada(estado(_, Linhas, _, Max)) :-
    length(Linhas, Usadas),
    Usadas >= Max.

% acertou(+Estado)
acertou(estado(Resposta, Linhas, _, _)) :-
    last(Linhas, linha(Resposta, _, _, _)).

proximo_efeito(_, Estado, Estado, nenhum) :-
    encerrada(Estado),
    !.
proximo_efeito(Desfeitas, Estado, Estado, nenhum) :-
    \+ hora_do_efeito(Desfeitas, Estado),
    !.
proximo_efeito(_, Estado, Novo, Evento) :-
    sortear_efeito(Estado, Efeito),
    aplicar_efeito(Efeito, Estado, Novo, Evento).

% conta os palpites feitos, inclusive os que o voltar_no_tempo apagou. Se
% contasse so as linhas, depois de apagar uma o efeito viria a cada palpite.
hora_do_efeito(Desfeitas, estado(_, Linhas, _, _)) :-
    length(Linhas, Usadas),
    Feitos is Usadas + Desfeitas,
    palpites_por_efeito(Intervalo),
    Feitos mod Intervalo =:= 0.

sortear_efeito(Estado, Efeito) :-
    findall(E, efeito_possivel(E, Estado), Possiveis),
    random_member(Efeito, Possiveis).

% efeito_possivel(?Efeito, +Estado)
% so entram efeitos que nao deixam a partida sem solucao.
efeito_possivel(Efeito, Estado) :-
    efeito(Efeito, _),
    possivel(Efeito, Estado).

possivel(Efeito, Estado) :-
    atrapalha_a_linha(Efeito),
    !,
    linhas_restantes(Estado, Restantes),
    linhas_minimas_para_atrapalhar(Minimo),
    Restantes >= Minimo.
possivel(troca_de_palavra, Estado) :-
    !,
    once(outra_resposta(Estado, _)).
possivel(dica_de_letra, Estado) :-
    !,
    dica_de_letra(Estado, _).
possivel(voltar_no_tempo, estado(_, Linhas, _, _)) :-
    !,
    Linhas \== [].
possivel(_, _).

linhas_restantes(estado(_, Linhas, _, Max), Restantes) :-
    length(Linhas, Usadas),
    Restantes is Max - Usadas.

aplicar_efeito(troca_de_palavra, Estado,
               estado(Nova, Linhas, nenhum, Max), instantaneo(troca_de_palavra)) :-
    !,
    Estado = estado(_, Linhas, _, Max),
    outra_resposta_sorteada(Estado, Nova).
aplicar_efeito(dica_de_letra, estado(R, Linhas, _, Max),
               estado(R, Linhas, nenhum, Max), dica(Letra, Presenca)) :-
    !,
    dica_de_letra(estado(R, Linhas, _, Max), Letra),
    atom_chars(R, Letras),
    ( memberchk(Letra, Letras) -> Presenca = presente ; Presenca = ausente ).
aplicar_efeito(voltar_no_tempo, estado(R, Linhas, _, Max),
               estado(R, Anteriores, nenhum, Max), instantaneo(voltar_no_tempo)) :-
    !,
    append(Anteriores, [_], Linhas).
aplicar_efeito(Efeito, estado(R, Linhas, _, Max),
               estado(R, Linhas, nenhum, Max), instantaneo(Efeito)) :-
    so_na_tela(Efeito),
    !.
aplicar_efeito(Efeito, estado(R, Linhas, _, Max),
               estado(R, Linhas, Efeito, Max), anuncio(Efeito)).

% outra_resposta(+Estado, -Outra)
% outra resposta que daria as mesmas cores reais em todos os palpites ja feitos,
% entao nada do que o jogador viu deixa de valer.
outra_resposta(estado(Resposta, Linhas, _, _), Outra) :-
    respostas_compativeis(Linhas, Compativeis),
    member(Outra, Compativeis),
    Outra \== Resposta.

outra_resposta_sorteada(Estado, Outra) :-
    findall(O, outra_resposta(Estado, O), Outras),
    random_member(Outra, Outras).

respostas_compativeis(Linhas, Compativeis) :-
    maplist(linha_real, Linhas, Historico),
    findall(R, ( resposta(R), word(R), consistent(R, Historico) ), Compativeis).

linha_real(linha(Palpite, Cores, _, _), [Palpite, Cores]).

% dica_de_letra(+Estado, -Letra)
% letra ainda nao jogada que divide as respostas compativeis mais perto da metade.
dica_de_letra(estado(_, Linhas, _, _), Letra) :-
    respostas_compativeis(Linhas, Compativeis),
    length(Compativeis, Total),
    Total >= 2,
    letras_jogadas(Linhas, Jogadas),
    aggregate_all(max(Equilibrio, L),
                  ( letra_nova(L, Jogadas),
                    com_letra(L, Compativeis, Com),
                    Com > 0,
                    Com < Total,
                    Equilibrio is min(Com, Total - Com) ),
                  max(_, Letra)).

letras_jogadas(Linhas, Jogadas) :-
    findall(L, ( member(linha(P, _, _, _), Linhas), atom_chars(P, Ls), member(L, Ls) ), Jogadas).

letra_nova(Letra, Jogadas) :-
    atom_chars(abcdefghijklmnopqrstuvwxyz, Alfabeto),
    member(Letra, Alfabeto),
    \+ memberchk(Letra, Jogadas).

com_letra(Letra, Palavras, Total) :-
    aggregate_all(count, ( member(P, Palavras), atom_chars(P, Ls), memberchk(Letra, Ls) ), Total).
