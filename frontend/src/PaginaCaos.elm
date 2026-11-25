module PaginaCaos exposing
    ( Model
    , Msg
    , aoEntrar
    , inicial
    , subscriptions
    , update
    , viewJogo
    , viewPainel
    , viewRodape
    )

import Browser.Events
import Caos exposing (Efeito, Evento(..), Exibicao(..), Linha, Partida, Situacao(..))
import CaosApi
import Html exposing (Html, button, div, kbd, p, span, text)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)
import Json.Decode as Decode exposing (Decoder)
import Random
import Teclado exposing (Tecla(..))
import Termo exposing (Cor(..), Remoto(..))


type alias Model =
    { partida : Remoto Partida
    , rascunho : String
    , erro : Maybe String
    , enviando : Bool
    , tela : EfeitosNaTela
    }


{-| Efeitos que só mudam a tela. O Prolog sorteia o efeito e avisa no
`evento`; quanto tempo ele dura fica por conta do Elm.

  - `furos`: casas (linha, posição) que levaram tiro, até o próximo palpite.
  - `apagada`: linha que está sem letras e quantos palpites ainda faltam.
  - `explodidas`: letras sem cor no teclado até serem jogadas de novo.
  - `limpas`: letras cinzas que sumiram do teclado.

-}
type alias EfeitosNaTela =
    { furos : List ( Int, Int )
    , apagada : Maybe { linha : Int, faltam : Int }
    , explodidas : List Char
    , limpas : List Char
    }


semEfeitosNaTela : EfeitosNaTela
semEfeitosNaTela =
    { furos = [], apagada = Nothing, explodidas = [], limpas = [] }


type Msg
    = NovaPartida
    | RecebeuPartida (Result String Partida)
    | TeclaPressionada Tecla
    | Atirou (List ( Int, Int ))
    | Explodiu (List Char)


inicial : Model
inicial =
    { partida = NaoPedido
    , rascunho = ""
    , erro = Nothing
    , enviando = False
    , tela = semEfeitosNaTela
    }


aoEntrar : Model -> ( Model, Cmd Msg )
aoEntrar model =
    case model.partida of
        NaoPedido ->
            iniciarPartida model

        _ ->
            ( model, Cmd.none )


iniciarPartida : Model -> ( Model, Cmd Msg )
iniciarPartida model =
    ( { model | partida = Carregando, rascunho = "", erro = Nothing, enviando = False, tela = semEfeitosNaTela }
    , CaosApi.novaPartida RecebeuPartida
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NovaPartida ->
            iniciarPartida model

        RecebeuPartida (Ok partida) ->
            let
                ( tela, cmd ) =
                    atualizarTela partida model.tela
            in
            ( { model | partida = Chegou partida, rascunho = "", erro = Nothing, enviando = False, tela = tela }
            , cmd
            )

        Atirou furos ->
            let
                tela =
                    model.tela
            in
            ( { model | tela = { tela | furos = furos } }, Cmd.none )

        Explodiu letras ->
            let
                tela =
                    model.tela
            in
            ( { model | tela = { tela | explodidas = tela.explodidas ++ letras } }, Cmd.none )

        RecebeuPartida (Err erro) ->
            case model.partida of
                Chegou _ ->
                    ( { model | erro = Just erro, enviando = False }, Cmd.none )

                _ ->
                    ( { model | partida = Falhou erro, enviando = False }, Cmd.none )

        TeclaPressionada tecla ->
            case model.partida of
                Chegou partida ->
                    if Caos.emAndamento partida && not model.enviando then
                        tratarTecla tecla partida model

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )


{-| Roda a cada resposta do servidor: primeiro acaba o que durava só até
este palpite, depois começa o efeito novo, se veio algum.
-}
atualizarTela : Partida -> EfeitosNaTela -> ( EfeitosNaTela, Cmd Msg )
atualizarTela partida tela =
    let
        jogadas =
            ultimaLinha partida
                |> Maybe.map (.palavra >> String.toList)
                |> Maybe.withDefault []

        passou =
            { tela
                | furos = []
                , apagada =
                    tela.apagada
                        |> Maybe.map (\apagada -> { apagada | faltam = apagada.faltam - 1 })
                        |> Maybe.andThen
                            (\apagada ->
                                if apagada.faltam > 0 then
                                    Just apagada

                                else
                                    Nothing
                            )
                , explodidas = List.filter (\letra -> not (List.member letra jogadas)) tela.explodidas
            }
    in
    case partida.evento of
        Just (Instantaneo Caos.Tiroteio) ->
            ( passou, Random.generate Atirou (sortear 4 (casasJogadas partida)) )

        Just (Instantaneo Caos.LetrasApagadas) ->
            ( { passou | apagada = Just { linha = List.length partida.linhas - 1, faltam = 2 } }, Cmd.none )

        Just (Instantaneo Caos.ExplosaoNoTeclado) ->
            ( passou
            , Random.generate Explodiu (sortear 3 (List.filter (\letra -> corDaTecla partida passou letra /= Nothing) alfabeto))
            )

        Just (Instantaneo Caos.LimpezaDoTeclado) ->
            ( { passou | limpas = List.filter (\letra -> corDaTecla partida passou letra == Just Cinza) alfabeto }
            , Cmd.none
            )

        _ ->
            ( passou, Cmd.none )


ultimaLinha : Partida -> Maybe Linha
ultimaLinha partida =
    List.head (List.reverse partida.linhas)


casasJogadas : Partida -> List ( Int, Int )
casasJogadas partida =
    List.indexedMap (\linha _ -> List.map (Tuple.pair linha) (List.range 0 (Termo.tamanhoPalavra - 1))) partida.linhas
        |> List.concat


alfabeto : List Char
alfabeto =
    String.toList "abcdefghijklmnopqrstuvwxyz"


{-| Sorteia até `n` elementos diferentes da lista: dá um peso aleatório para
cada um, ordena pelos pesos e pega os `n` primeiros.
-}
sortear : Int -> List a -> Random.Generator (List a)
sortear n lista =
    Random.list (List.length lista) (Random.float 0 1)
        |> Random.map
            (\pesos ->
                List.map2 Tuple.pair pesos lista
                    |> List.sortBy Tuple.first
                    |> List.map Tuple.second
                    |> List.take n
            )


{-| Cor da tecla no modo caos: a do Termo, menos as letras que explodiram.
-}
corDaTecla : Partida -> EfeitosNaTela -> Char -> Maybe Cor
corDaTecla partida tela letra =
    if List.member letra tela.explodidas then
        Nothing

    else
        Termo.corDoTeclado (Termo.deHistorico (Caos.palpitesComCores partida)) letra


{-| A tecla some se foi limpa e continua cinza. Se a letra ganhar outra cor
depois, ela volta.
-}
teclaAparece : Partida -> EfeitosNaTela -> Char -> Bool
teclaAparece partida tela letra =
    not (List.member letra tela.limpas && corDaTecla partida tela letra == Just Cinza)


tratarTecla : Tecla -> Partida -> Model -> ( Model, Cmd Msg )
tratarTecla tecla partida model =
    case tecla of
        Letra letra ->
            if String.length model.rascunho < Termo.tamanhoPalavra && Char.isLower letra then
                ( { model | rascunho = model.rascunho ++ String.fromChar letra, erro = Nothing }, Cmd.none )

            else
                ( model, Cmd.none )

        Apagar ->
            ( { model | rascunho = String.dropRight 1 model.rascunho, erro = Nothing }, Cmd.none )

        Enter ->
            if String.length model.rascunho < Termo.tamanhoPalavra then
                ( { model | erro = Just "A palavra precisa ter 5 letras." }, Cmd.none )

            else
                ( { model | enviando = True, erro = Nothing }
                , CaosApi.jogar partida.id model.rascunho RecebeuPartida
                )


subscriptions : Sub Msg
subscriptions =
    Browser.Events.onKeyDown teclaDecoder


teclaDecoder : Decoder Msg
teclaDecoder =
    Decode.map4
        (\chave ctrl alt meta -> { chave = chave, modificador = ctrl || alt || meta })
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        |> Decode.andThen
            (\evento ->
                case ( evento.modificador, Teclado.teclaFisica evento.chave ) of
                    ( False, Just tecla ) ->
                        Decode.succeed (TeclaPressionada tecla)

                    _ ->
                        Decode.fail "tecla ignorada"
            )



-- VIEW


viewJogo : Model -> Html Msg
viewJogo model =
    case model.partida of
        Chegou partida ->
            div [ class "caos-jogo" ]
                [ viewArma model.tela
                , div [ class "grade", attribute "role" "grid", attribute "aria-label" "Grade do modo caos" ]
                    (linhasDaGrade model.tela model.rascunho partida)
                , Teclado.viewTecladoCom TeclaPressionada (corDaTecla partida model.tela) (teclaAparece partida model.tela)
                ]

        _ ->
            div [ class "grade" ] []


{-| A arma entra, atira e sai pela animação do CSS, que roda uma vez quando o
elemento aparece.
-}
viewArma : EfeitosNaTela -> Html Msg
viewArma tela =
    if List.isEmpty tela.furos then
        text ""

    else
        div [ class "caos-arma", attribute "aria-hidden" "true" ] [ text "🔫" ]


linhasDaGrade : EfeitosNaTela -> String -> Partida -> List (Html Msg)
linhasDaGrade tela rascunho partida =
    let
        jogadas =
            List.indexedMap (viewLinha tela) partida.linhas

        atual =
            if Caos.emAndamento partida then
                [ viewRascunho rascunho ]

            else
                []

        vazias =
            List.repeat (partida.maxLinhas - List.length jogadas - List.length atual) viewLinhaVazia
    in
    jogadas ++ atual ++ vazias


viewLinha : EfeitosNaTela -> Int -> Linha -> Html Msg
viewLinha tela numero linha =
    let
        letras =
            if Maybe.map .linha tela.apagada == Just numero then
                List.repeat Termo.tamanhoPalavra ""

            else
                List.map (Char.toUpper >> String.fromChar) (String.toList linha.palavra)

        casas classeDe =
            List.indexedMap (\posicao letra -> viewCasa (List.member ( numero, posicao ) tela.furos) (classeDe posicao) letra) letras
    in
    case linha.exibicao of
        Cores cores ->
            div [ class "linha", attribute "role" "row" ]
                (casas (\posicao -> List.drop posicao cores |> List.head |> Maybe.map classeDaCor |> Maybe.withDefault ""))

        Contagem contagem ->
            div [ class "linha linha--caos", attribute "role" "row" ]
                (casas (always "casa--sem-cor")
                    ++ [ span [ class "linha-contagem" ]
                            [ text (String.fromInt contagem.verdes ++ "V " ++ String.fromInt contagem.amarelas ++ "A") ]
                       ]
                )

        Oculta ->
            div [ class "linha linha--caos", attribute "role" "row" ]
                (casas (always "casa--oculta"))


{-| Uma casa furada pelo tiroteio esconde a letra e a cor.
-}
viewCasa : Bool -> String -> String -> Html Msg
viewCasa furada classe letra =
    if furada then
        div [ class "casa casa--confirmada casa--furada", attribute "role" "gridcell", attribute "aria-label" "casa furada" ] []

    else
        div [ class ("casa casa--confirmada " ++ classe), attribute "role" "gridcell" ] [ text letra ]


viewRascunho : String -> Html Msg
viewRascunho rascunho =
    let
        letras =
            List.map (\letra -> div [ class "casa casa--rascunho casa--cinza" ] [ text (String.fromChar (Char.toUpper letra)) ])
                (String.toList rascunho)

        faltam =
            List.repeat (Termo.tamanhoPalavra - String.length rascunho) (div [ class "casa casa--vazia" ] [])
    in
    div [ class "linha", attribute "role" "row" ] (letras ++ faltam)


viewLinhaVazia : Html Msg
viewLinhaVazia =
    div [ class "linha", attribute "role" "row" ]
        (List.repeat Termo.tamanhoPalavra (div [ class "casa casa--vazia" ] []))


classeDaCor : Cor -> String
classeDaCor cor =
    case cor of
        Verde ->
            "casa--verde"

        Amarelo ->
            "casa--amarela"

        Cinza ->
            "casa--cinza"


viewPainel : Model -> List (Html Msg)
viewPainel model =
    [ button [ type_ "button", class "acao-nova-partida", onClick NovaPartida, disabled (model.partida == Carregando) ]
        [ text "Nova partida" ]
    , div [ class "message-area" ] (viewMensagens model)
    ]


viewMensagens : Model -> List (Html Msg)
viewMensagens model =
    case model.partida of
        NaoPedido ->
            []

        Carregando ->
            [ mensagem "message--loading" "Sorteando a palavra..." ]

        Falhou erro ->
            [ mensagem "message--error" erro ]

        Chegou partida ->
            List.filterMap identity
                [ Maybe.map (mensagem "message--error") model.erro
                , Just (viewSituacao partida)
                , Maybe.map viewEvento partida.evento
                , Maybe.map viewProximo partida.proximo
                ]


viewSituacao : Partida -> Html Msg
viewSituacao partida =
    case partida.situacao of
        EmAndamento ->
            mensagem "message--info" ("Linhas restantes: " ++ String.fromInt (Caos.linhasRestantes partida))

        Venceu ->
            mensagem "message--success" "Acertou, apesar do caos!"

        Perdeu resposta ->
            mensagem "message--error" ("A palavra era " ++ String.toUpper resposta ++ ".")


viewEvento : Evento -> Html Msg
viewEvento evento =
    case evento of
        Instantaneo efeito ->
            viewEfeito "Aconteceu" efeito

        LetraRevelada dica ->
            let
                onde =
                    if dica.presente then
                        " está na palavra."

                    else
                        " não está na palavra."
            in
            div [ class "message message--success caos-efeito", attribute "role" "status" ]
                [ p [ class "caos-efeito-nome" ] [ text (Caos.nome Caos.DicaDeLetra) ]
                , p [] [ text ("A letra " ++ String.toUpper (String.fromChar dica.letra) ++ onde) ]
                ]


viewProximo : Efeito -> Html Msg
viewProximo efeito =
    viewEfeito "No próximo palpite" efeito


viewEfeito : String -> Efeito -> Html Msg
viewEfeito quando efeito =
    div [ class "message message--info caos-efeito", attribute "role" "status" ]
        [ p [ class "caos-efeito-nome" ] [ text (quando ++ ": " ++ Caos.nome efeito) ]
        , p [] [ text (Caos.descricao efeito) ]
        ]


mensagem : String -> String -> Html Msg
mensagem tipo conteudo =
    div [ class ("message " ++ tipo), attribute "role" "status" ] [ text conteudo ]


viewRodape : List (Html msg)
viewRodape =
    [ text "A cada 2 palpites um efeito é sorteado. "
    , kbd [] [ text "A–Z" ]
    , text " digita, "
    , kbd [] [ text "⌫" ]
    , text " apaga, "
    , kbd [] [ text "Enter" ]
    , text " confirma."
    ]
