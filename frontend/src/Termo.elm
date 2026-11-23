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
    , ehLetra
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

ehLetra : Char -> Bool
ehLetra c =
    c >= 'a' && c <= 'z'


type alias Palpite =
    { palavra : String
    , cores : List Cor
    }


{-| Estado de uma partida. É opaco (o construtor não é exportado), então
quem usa o módulo não consegue montar um jogo inválido: só dá pra mexer
nele pelas funções deste módulo (`digitar`, `apagar`, `confirmar`...).
-}
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
    List.any (\palpite -> palpite.cores == List.repeat tamanhoPalavra Verde) jogo.palpites


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
    if ehLetra minuscula && cabe && not (terminou todo) then
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
        Err ("A palavra precisa ter " ++ String.fromInt tamanhoPalavra ++ " letras.")

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


{-| Cor que a tecla da letra deve mostrar, considerando todos os palpites.

Uma letra pode receber cores diferentes ao longo da partida, inclusive no
mesmo palpite. A melhor cor é mostrada (verde > amarelo > cinza) porque, se a letra já
apareceu verde ou amarela, ela com certeza está na palavra, e a letra no local certo (verde)
tem prioridade maior que letra certa na posição errada (amarela) ou cinza

-}
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
