module Termo exposing
    ( Casa(..)
    , Cor(..)
    , Jogo
    , Palpite
    , Remoto(..)
    , acertou
    , apagar
    , confirmar
    , corDoTeclado
    , deHistorico
    , digitar
    , grade
    , historico
    , maxPalpites
    , novoJogo
    , proximaCor
    , tamanhoPalavra
    , terminou
    , trocarCor
    )


type Cor
    = Verde
    | Amarelo
    | Cinza


type alias Palpite =
    { palavra : String
    , cores : List Cor
    }


type Jogo
    = Jogo
        { palpites : List Palpite
        , rascunho : List ( Char, Cor )
        }


type Casa
    = Vazia
    | Rascunho Char Cor
    | Confirmada Char Cor


type Remoto a
    = NaoPedido
    | Carregando
    | Chegou a
    | Falhou String


tamanhoPalavra : Int
tamanhoPalavra =
    5


maxPalpites : Int
maxPalpites =
    6


novoJogo : Jogo
novoJogo =
    Jogo { palpites = [], rascunho = [] }


deHistorico : List Palpite -> Jogo
deHistorico palpites =
    Jogo { palpites = List.take maxPalpites palpites, rascunho = [] }


historico : Jogo -> List Palpite
historico (Jogo jogo) =
    jogo.palpites


acertou : Jogo -> Bool
acertou (Jogo jogo) =
    List.any (\palpite -> List.all ((==) Verde) palpite.cores) jogo.palpites


terminou : Jogo -> Bool
terminou ((Jogo jogo) as todo) =
    acertou todo || List.length jogo.palpites >= maxPalpites


digitar : Char -> Jogo -> Jogo
digitar letra ((Jogo jogo) as todo) =
    let
        minuscula =
            Char.toLower letra

        cabe =
            List.length jogo.rascunho < tamanhoPalavra
    in
    if Char.isAlpha minuscula && cabe && not (terminou todo) then
        Jogo { jogo | rascunho = jogo.rascunho ++ [ ( minuscula, Cinza ) ] }

    else
        todo


apagar : Jogo -> Jogo
apagar (Jogo jogo) =
    Jogo { jogo | rascunho = List.take (List.length jogo.rascunho - 1) jogo.rascunho }


proximaCor : Cor -> Cor
proximaCor cor =
    case cor of
        Cinza ->
            Amarelo

        Amarelo ->
            Verde

        Verde ->
            Cinza


trocarCor : Int -> Jogo -> Jogo
trocarCor coluna (Jogo jogo) =
    let
        trocar indice ( letra, cor ) =
            if indice == coluna then
                ( letra, proximaCor cor )

            else
                ( letra, cor )
    in
    Jogo { jogo | rascunho = List.indexedMap trocar jogo.rascunho }


confirmar : Jogo -> Result String Jogo
confirmar ((Jogo jogo) as todo) =
    if terminou todo then
        Err "A partida já terminou."

    else if List.length jogo.rascunho < tamanhoPalavra then
        Err "A palavra precisa ter 5 letras."

    else
        Ok
            (Jogo
                { palpites = jogo.palpites ++ [ paraPalpite jogo.rascunho ]
                , rascunho = []
                }
            )


paraPalpite : List ( Char, Cor ) -> Palpite
paraPalpite casas =
    { palavra = String.fromList (List.map Tuple.first casas)
    , cores = List.map Tuple.second casas
    }


grade : Jogo -> List (List Casa)
grade (Jogo jogo) =
    let
        confirmadas =
            List.map linhaConfirmada jogo.palpites

        atual =
            if List.length jogo.palpites < maxPalpites then
                [ completar (List.map (\( letra, cor ) -> Rascunho letra cor) jogo.rascunho) ]

            else
                []

        vazias =
            List.repeat
                (maxPalpites - List.length confirmadas - List.length atual)
                (List.repeat tamanhoPalavra Vazia)
    in
    confirmadas ++ atual ++ vazias


linhaConfirmada : Palpite -> List Casa
linhaConfirmada palpite =
    completar (List.map2 Confirmada (String.toList palpite.palavra) palpite.cores)


completar : List Casa -> List Casa
completar casas =
    casas ++ List.repeat (tamanhoPalavra - List.length casas) Vazia


corDoTeclado : Jogo -> Char -> Maybe Cor
corDoTeclado (Jogo jogo) letra =
    jogo.palpites
        |> List.concatMap (\palpite -> List.map2 Tuple.pair (String.toList palpite.palavra) palpite.cores)
        |> List.filter (\( l, _ ) -> l == letra)
        |> List.map Tuple.second
        |> List.sortBy prioridade
        |> List.reverse
        |> List.head


prioridade : Cor -> Int
prioridade cor =
    case cor of
        Verde ->
            2

        Amarelo ->
            1

        Cinza ->
            0
