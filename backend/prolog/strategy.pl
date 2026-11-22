:- module(strategy, [best_guess/3, abertura/1, calcula_abertura/2]).

:- encoding(utf8).

:- use_module(feedback).
:- use_module(words).
:- use_module(candidates).

/** <module> Sugestão de palpite pelo critério minimax

Para cada palpite avaliado, as candidatas são agrupadas pelas cores que
feedback/3 devolveria; vence o palpite cujo maior grupo é o menor.

Otimizações para responder em menos de 2 s sobre ~8.600 palavras:

  1. uma ou duas candidatas: retorna a primeira direto (o maior grupo
     já é 1, nenhum palpite faz melhor);
  2. as candidatas são avaliadas primeiro, o que fixa cedo um limite
     baixo; em empate, uma candidata vence (ela ainda pode ser a resposta);
  3. corte: a contagem de um palpite é interrompida assim que algum grupo
     alcança o tamanho do maior grupo do melhor palpite já encontrado;
  4. orçamento: o número de chamadas a feedback/3 é limitado por
     orcamento/1. Com poucas candidatas, toda a base é avaliada como
     palpite; com muitas, apenas as candidatas (ou parte delas).
*/

%!  abertura(?Palavra) is semidet.
%
%   Palpite inicial, obtido offline com calcula_abertura/2 (minimax completo
%   das 8.611 palavras contra as 8.611; ~99 s de CPU). Com raiao, o maior
%   grupo tem 407 palavras.
abertura(raiao).

%!  orcamento(-Chamadas) is det.
%
%   Máximo de chamadas a feedback/3 por best_guess/3 (~1,3 µs cada).
orcamento(600_000).

%!  best_guess(+Historico, -Palavra, -Motivo) is semidet.
%
%   Historico é uma lista de [Palpite, Cores]. Falha se não houver
%   candidatas.
best_guess([], Palavra, Motivo) :-
    !,
    abertura(Palavra),
    Motivo = "palpite de abertura, calculado previamente pelo critério minimax".
best_guess(Historico, Palavra, Motivo) :-
    candidates(Historico, Candidatas),
    Candidatas \== [],
    length(Candidatas, N),
    escolhe(N, Candidatas, Palavra, Maior),
    motivo(N, Maior, Motivo).

escolhe(N, [Palavra|_], Palavra, 1) :-
    N =< 2,
    !.
escolhe(N, Candidatas, Palavra, Maior) :-
    palpites(N, Candidatas, Palpites),
    Limite is N + 1,
    melhor(Palpites, Candidatas, nenhum, Limite, Palavra, Maior).

%   palpites(+N, +Candidatas, -Palpites)
%   Candidatas primeiro; o resto da base só entra se couber no orçamento.
palpites(N, Candidatas, Palpites) :-
    orcamento(Orc),
    aggregate_all(count, word(_), Total),
    (   Total * N =< Orc
    ->  findall(W, ( word(W), \+ memberchk(W, Candidatas) ), Outras),
        append(Candidatas, Outras, Palpites)
    ;   N * N =< Orc
    ->  Palpites = Candidatas
    ;   K is max(1, Orc // N),
        amostra(Candidatas, N, K, Palpites)
    ).

%   amostra(+Lista, +N, +K, -Amostra): K elementos espaçados por igual.
amostra(Lista, N, K, Amostra) :-
    Passo is N / K,
    findall(X,
            ( between(0, K, I0), I0 < K,
              I is floor(I0 * Passo) + 1,
              nth1(I, Lista, X) ),
            Amostra).

%   melhor(+Palpites, +Candidatas, +W0, +Maior0, -W, -Maior)
melhor(_, _, W, 1, W, 1) :-                 % não há como melhorar
    W \== nenhum,
    !.
melhor([], _, W, Maior, W, Maior).
melhor([P|Ps], Candidatas, W0, Maior0, W, Maior) :-
    Limite is Maior0 - 1,
    (   maior_grupo(P, Candidatas, Limite, M)
    ->  melhor(Ps, Candidatas, P, M, W, Maior)
    ;   melhor(Ps, Candidatas, W0, Maior0, W, Maior)
    ).

%!  maior_grupo(+Palpite, +Candidatas, +Limite, -Maior) is semidet.
%
%   Tamanho do maior grupo de candidatas com as mesmas cores. Falha assim
%   que algum grupo passa de Limite (corte).
maior_grupo(Palpite, Candidatas, Limite, Maior) :-
    length(Zeros, 243),
    maplist(=(0), Zeros),
    Contador =.. [c|Zeros],
    conta(Candidatas, Palpite, Contador, Limite, 0, Maior).

conta([], _, _, _, Maior, Maior).
conta([C|Cs], Palpite, Contador, Limite, Maior0, Maior) :-
    feedback(Palpite, C, Cores),
    codigo(Cores, K),
    arg(K, Contador, V0),
    V is V0 + 1,
    V =< Limite,
    setarg(K, Contador, V),
    Maior1 is max(Maior0, V),
    conta(Cs, Palpite, Contador, Limite, Maior1, Maior).

%   codigo(+Cores, -K): cores em base 3, de 1 a 243.
codigo(Cores, K) :-
    foldl(digito, Cores, 0, K0),
    K is K0 + 1.

digito(Cor, A0, A) :-
    valor(Cor, D),
    A is A0 * 3 + D.

valor(gray, 0).
valor(yellow, 1).
valor(green, 2).

motivo(1, _, "resta 1 palavra; este palpite é a resposta") :- !.
motivo(N, Maior, Motivo) :-
    format(string(Motivo),
           "restam ~d palavras; com este palpite sobram no máximo ~d",
           [N, Maior]).

%!  calcula_abertura(-Palavra, -Maior) is det.
%
%   Minimax completo com histórico vazio: toda a base como palpite contra
%   toda a base como candidata. Usado offline para definir abertura/1
%   (leva alguns minutos).
calcula_abertura(Palavra, Maior) :-
    findall(W, word(W), Base),
    length(Base, N),
    Limite is N + 1,
    melhor(Base, Base, nenhum, Limite, Palavra, Maior).
