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
import Teclado exposing (Tecla(..))
import Termo exposing (Cor(..), Remoto(..))


type alias Model =
    { partida : Remoto Partida
    , rascunho : String
    , erro : Maybe String
    , enviando : Bool
    }


type Msg
    = NovaPartida
    | RecebeuPartida (Result String Partida)
    | TeclaPressionada Tecla


inicial : Model
inicial =
    { partida = NaoPedido
    , rascunho = ""
    , erro = Nothing
    , enviando = False
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
    ( { model | partida = Carregando, rascunho = "", erro = Nothing, enviando = False }
    , CaosApi.novaPartida RecebeuPartida
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NovaPartida ->
            iniciarPartida model

        RecebeuPartida (Ok partida) ->
            ( { model | partida = Chegou partida, rascunho = "", erro = Nothing, enviando = False }
            , Cmd.none
            )

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
            div []
                [ div [ class "grade", attribute "role" "grid", attribute "aria-label" "Grade do modo caos" ]
                    (linhasDaGrade model.rascunho partida)
                , Teclado.viewTeclado TeclaPressionada (Termo.deHistorico (Caos.palpitesComCores partida))
                ]

        _ ->
            div [ class "grade" ] []


linhasDaGrade : String -> Partida -> List (Html Msg)
linhasDaGrade rascunho partida =
    let
        jogadas =
            List.map viewLinha partida.linhas

        atual =
            if Caos.emAndamento partida then
                [ viewRascunho rascunho ]

            else
                []

        vazias =
            List.repeat (partida.maxLinhas - List.length jogadas - List.length atual) viewLinhaVazia
    in
    jogadas ++ atual ++ vazias


viewLinha : Linha -> Html Msg
viewLinha linha =
    let
        letras =
            String.toList linha.palavra
    in
    case linha.exibicao of
        Cores cores ->
            div [ class "linha", attribute "role" "row" ] (List.map2 viewCasaColorida letras cores)

        Contagem contagem ->
            div [ class "linha linha--caos", attribute "role" "row" ]
                (List.map (viewCasaSemCor "casa--sem-cor") letras
                    ++ [ span [ class "linha-contagem" ]
                            [ text (String.fromInt contagem.verdes ++ "V " ++ String.fromInt contagem.amarelas ++ "A") ]
                       ]
                )

        Oculta ->
            div [ class "linha linha--caos", attribute "role" "row" ]
                (List.map (viewCasaSemCor "casa--oculta") letras)


viewCasaColorida : Char -> Cor -> Html Msg
viewCasaColorida letra cor =
    div
        [ class ("casa casa--confirmada " ++ classeDaCor cor), attribute "role" "gridcell" ]
        [ text (String.fromChar (Char.toUpper letra)) ]


viewCasaSemCor : String -> Char -> Html Msg
viewCasaSemCor classe letra =
    div [ class ("casa casa--confirmada " ++ classe), attribute "role" "gridcell" ]
        [ text (String.fromChar (Char.toUpper letra)) ]


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
