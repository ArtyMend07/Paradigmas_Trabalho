module Main exposing (main)

{-| Interface gráfica do solver de Termo na Arquitetura Elm.

Dois modos de operação:

  - `Assistente`: o jogador digita o palpite feito no Termo, define a cor de
    cada letra (clicando nas casas ou pressionando as teclas 1 a 5) e confirma
    com Enter. O painel exibe as candidatas restantes e a sugestão do próximo
    palpite com o motivo.
  - `Automatico`: o jogador informa uma palavra de 5 letras e o solver mostra
    na grade 6×5 todos os passos até acertá-la.

As chamadas HTTP ficam no módulo `Api.elm`. Cada resposta volta ao `update`
como `Result String a` e vira um `Remoto` (`Chegou` ou `Falhou`).

-}

import Api exposing (Sugestao)
import Browser
import Browser.Events
import Html exposing (Html, aside, button, div, footer, form, h1, header, input, kbd, label, main_, p, span, text)
import Html.Attributes exposing (attribute, checked, class, classList, disabled, maxlength, placeholder, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput, onSubmit)
import Json.Decode as Decode exposing (Decoder)
import Teclado exposing (Tecla(..))
import Termo exposing (Casa(..), Cor(..), Jogo, Palpite, Remoto(..))



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


{-| Dados entregues pelo `main.js` na inicialização da página.
-}
type alias Flags =
    { darkTheme : Bool
    }


type Modo
    = Assistente
    | Automatico


type alias Model =
    { modo : Modo
    , jogo : Jogo
    , candidatas : Remoto (List String)
    , sugestao : Remoto Sugestao
    , palavraAutoplay : String
    , autoplay : Remoto (List Palpite)
    , erroLocal : Maybe String
    , temaEscuro : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { modo = Assistente
      , jogo = Termo.novoJogo
      , candidatas = NaoPedido
      , sugestao = Carregando
      , palavraAutoplay = ""
      , autoplay = NaoPedido
      , erroLocal = Nothing
      , temaEscuro = flags.darkTheme
      }
    , Api.sugerir [] (RecebeuSugestao 0)
    )



-- UPDATE


type Msg
    = ModoAlterado Modo
    | TeclaPressionada Tecla
    | CorTrocada Int
    | PalavraEscolhida String
    | NovoJogo
    | RecebeuCandidatas Int (Result String (List String))
    | RecebeuSugestao Int (Result String Sugestao)
    | PalavraAutoplayAlterada String
    | AutoplaySolicitado
    | RecebeuAutoplay String (Result String (List Palpite))
    | TemaAlterado Bool
    | ErroFechado


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ModoAlterado novoModo ->
            ( { model | modo = novoModo, erroLocal = Nothing }
            , Cmd.none
            )

        TeclaPressionada tecla ->
            if model.modo /= Assistente then
                ( model, Cmd.none )

            else
                tratarTecla tecla model

        CorTrocada coluna ->
            if model.modo /= Assistente || Termo.terminou model.jogo then
                ( model, Cmd.none )

            else
                ( { model
                    | jogo = Termo.trocarCor coluna model.jogo
                    , erroLocal = Nothing
                  }
                , Cmd.none
                )

        PalavraEscolhida palavra ->
            if model.modo /= Assistente || Termo.terminou model.jogo then
                ( model, Cmd.none )

            else
                ( { model
                    | jogo = preencherRascunho palavra model.jogo
                    , erroLocal = Nothing
                  }
                , Cmd.none
                )

        NovoJogo ->
            ( { model
                | jogo = Termo.novoJogo
                , candidatas = NaoPedido
                , sugestao = Carregando
                , erroLocal = Nothing
              }
            , Api.sugerir [] (RecebeuSugestao 0)
            )

        RecebeuCandidatas passo resultado ->
            if passo /= List.length (Termo.historico model.jogo) then
                ( model, Cmd.none )

            else
                ( { model | candidatas = deResult resultado }
                , Cmd.none
                )

        RecebeuSugestao passo resultado ->
            if passo /= List.length (Termo.historico model.jogo) then
                ( model, Cmd.none )

            else
                ( { model | sugestao = deResult resultado }
                , Cmd.none
                )

        PalavraAutoplayAlterada texto ->
            let
                limpa =
                    texto
                        |> String.toLower
                        |> String.filter ehLetraAscii
                        |> String.left Termo.tamanhoPalavra
            in
            ( { model | palavraAutoplay = limpa, erroLocal = Nothing }
            , Cmd.none
            )

        AutoplaySolicitado ->
            if String.length model.palavraAutoplay < Termo.tamanhoPalavra then
                ( { model | erroLocal = Just "Digite uma palavra de 5 letras." }
                , Cmd.none
                )

            else
                ( { model | autoplay = Carregando, erroLocal = Nothing }
                , Api.jogarSozinho model.palavraAutoplay (RecebeuAutoplay model.palavraAutoplay)
                )

        RecebeuAutoplay palavra resultado ->
            if palavra /= model.palavraAutoplay then
                ( model, Cmd.none )

            else
                ( { model | autoplay = deResult resultado }
                , Cmd.none
                )

        TemaAlterado escuro ->
            ( { model | temaEscuro = escuro }
            , Cmd.none
            )

        ErroFechado ->
            ( { model
                | erroLocal = Nothing
                , candidatas = limparFalha model.candidatas
                , sugestao = limparFalha model.sugestao
                , autoplay = limparFalha model.autoplay
              }
            , Cmd.none
            )


tratarTecla : Tecla -> Model -> ( Model, Cmd Msg )
tratarTecla tecla model =
    case tecla of
        Letra letra ->
            ( { model
                | jogo = Termo.digitar letra model.jogo
                , erroLocal = Nothing
              }
            , Cmd.none
            )

        Apagar ->
            ( { model
                | jogo = Termo.apagar model.jogo
                , erroLocal = Nothing
              }
            , Cmd.none
            )

        Enter ->
            case Termo.confirmar model.jogo of
                Err mensagem ->
                    ( { model | erroLocal = Just mensagem }
                    , Cmd.none
                    )

                Ok novoJogo ->
                    if Termo.acertou novoJogo then
                        ( { model
                            | jogo = novoJogo
                            , candidatas = NaoPedido
                            , sugestao = NaoPedido
                            , erroLocal = Nothing
                          }
                        , Cmd.none
                        )

                    else
                        let
                            hist =
                                Termo.historico novoJogo

                            passo =
                                List.length hist
                        in
                        ( { model
                            | jogo = novoJogo
                            , candidatas = Carregando
                            , sugestao = Carregando
                            , erroLocal = Nothing
                          }
                        , Cmd.batch
                            [ Api.buscarCandidatas hist (RecebeuCandidatas passo)
                            , Api.sugerir hist (RecebeuSugestao passo)
                            ]
                        )


ehLetraAscii : Char -> Bool
ehLetraAscii c =
    c >= 'a' && c <= 'z'


deResult : Result String a -> Remoto a
deResult resultado =
    case resultado of
        Ok valor ->
            Chegou valor

        Err erro ->
            Falhou erro


limparFalha : Remoto a -> Remoto a
limparFalha remoto =
    case remoto of
        Falhou _ ->
            NaoPedido

        _ ->
            remoto


{-| Substitui as letras do rascunho atual pela palavra escolhida, usando apenas
as operações públicas de `Termo`.
-}
preencherRascunho : String -> Jogo -> Jogo
preencherRascunho palavra jogo =
    let
        limpo =
            List.foldl (\_ acc -> Termo.apagar acc)
                jogo
                (List.range 1 Termo.tamanhoPalavra)
    in
    List.foldl Termo.digitar limpo (String.toList palavra)



-- SUBSCRIPTIONS


{-| O teclado físico só é capturado globalmente no modo assistente, para não
interferir na digitação dentro do `<input>` do modo automático.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.modo of
        Assistente ->
            Browser.Events.onKeyDown teclaDecoder

        Automatico ->
            Sub.none


teclaDecoder : Decoder Msg
teclaDecoder =
    Decode.map5
        (\chave ctrl alt meta tag ->
            { chave = chave
            , modificador = ctrl || alt || meta
            , emCampoTexto = tag == "INPUT" || tag == "TEXTAREA"
            , emBotao = tag == "BUTTON"
            }
        )
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        (Decode.at [ "target", "tagName" ] Decode.string |> Decode.maybe |> Decode.map (Maybe.withDefault ""))
        |> Decode.andThen interpretarEvento


interpretarEvento : { chave : String, modificador : Bool, emCampoTexto : Bool, emBotao : Bool } -> Decoder Msg
interpretarEvento evento =
    if evento.modificador || evento.emCampoTexto || (evento.emBotao && evento.chave == "Enter") then
        Decode.fail "evento ignorado"

    else
        case evento.chave of
            "1" ->
                Decode.succeed (CorTrocada 0)

            "2" ->
                Decode.succeed (CorTrocada 1)

            "3" ->
                Decode.succeed (CorTrocada 2)

            "4" ->
                Decode.succeed (CorTrocada 3)

            "5" ->
                Decode.succeed (CorTrocada 4)

            _ ->
                case Teclado.teclaFisica evento.chave of
                    Just tecla ->
                        Decode.succeed (TeclaPressionada tecla)

                    Nothing ->
                        Decode.fail "tecla ignorada"



-- VIEW


limiteCandidatas : Int
limiteCandidatas =
    48


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ h1 [ class "app-title" ] [ text "Termo" ]
                , span [ class "app-subtitle" ] [ text "Prolog + Elm" ]
                , viewThemeToggle model
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ div [ class "area-jogo" ]
                    [ viewGrade model
                    , if model.modo == Assistente then
                        Teclado.viewTeclado TeclaPressionada model.jogo

                      else
                        text ""
                    ]
                , aside [ class "side-panel" ]
                    ([ span [ class "panel-label" ] [ text "Modo" ]
                     , viewSeletorModo model.modo
                     , div [ class "message-area" ] [ viewMensagens model ]
                     ]
                        ++ viewPainelDoModo model
                    )
                ]
            ]
        , viewRodape model.modo
        ]


viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    label [ class "theme-toggle", attribute "aria-label" "Alternar tema claro/escuro" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , value "dark"
            , checked model.temaEscuro
            , onCheck TemaAlterado
            ]
            []
        , span [ class "swap-off" ] [ text "🌙" ]
        , span [ class "swap-on" ] [ text "☀" ]
        ]


viewSeletorModo : Modo -> Html Msg
viewSeletorModo atual =
    div [ class "modo-seletor" ]
        [ viewOpcaoModo atual Assistente "Assistente"
        , viewOpcaoModo atual Automatico "Automático"
        ]


viewOpcaoModo : Modo -> Modo -> String -> Html Msg
viewOpcaoModo atual modo rotulo =
    button
        [ type_ "button"
        , classList
            [ ( "modo-opcao", True )
            , ( "modo-opcao--ativo", atual == modo )
            ]
        , onClick (ModoAlterado modo)
        ]
        [ text rotulo ]


viewGrade : Model -> Html Msg
viewGrade model =
    let
        jogoExibido =
            case model.modo of
                Assistente ->
                    model.jogo

                Automatico ->
                    jogoDoAutoplay model.autoplay

        podeEditar =
            model.modo == Assistente && not (Termo.terminou model.jogo)
    in
    div [ class "grade", attribute "role" "grid", attribute "aria-label" "Grade do Termo" ]
        (List.map (viewLinha podeEditar) (Termo.grade jogoExibido))


jogoDoAutoplay : Remoto (List Palpite) -> Jogo
jogoDoAutoplay estado =
    case estado of
        Chegou passos ->
            Termo.deHistorico passos

        _ ->
            Termo.novoJogo


viewLinha : Bool -> List Casa -> Html Msg
viewLinha podeEditar casas =
    div [ class "linha", attribute "role" "row" ]
        (List.indexedMap (viewCasa podeEditar) casas)


viewCasa : Bool -> Int -> Casa -> Html Msg
viewCasa podeEditar coluna casa =
    case casa of
        Vazia ->
            div [ class "casa casa--vazia", attribute "role" "gridcell" ] []

        Rascunho letra cor ->
            let
                letraStr =
                    String.fromChar (Char.toUpper letra)

                posicao =
                    String.fromInt (coluna + 1)

                descricao =
                    "Letra "
                        ++ letraStr
                        ++ " na posição "
                        ++ posicao
                        ++ " ("
                        ++ nomeDaCor cor
                        ++ "). Clique ou aperte "
                        ++ posicao
                        ++ " para trocar a cor."
            in
            button
                [ type_ "button"
                , class ("casa casa--rascunho " ++ classeDaCor cor)
                , title ("Clique ou aperte " ++ posicao ++ " para trocar a cor")
                , attribute "aria-label" descricao
                , disabled (not podeEditar)
                , onClick (CorTrocada coluna)
                ]
                [ text letraStr ]

        Confirmada letra cor ->
            div
                [ class ("casa casa--confirmada " ++ classeDaCor cor)
                , attribute "role" "gridcell"
                , attribute "aria-label"
                    (String.fromChar (Char.toUpper letra) ++ " — " ++ nomeDaCor cor)
                ]
                [ text (String.fromChar (Char.toUpper letra)) ]


classeDaCor : Cor -> String
classeDaCor cor =
    case cor of
        Verde ->
            "casa--verde"

        Amarelo ->
            "casa--amarela"

        Cinza ->
            "casa--cinza"


nomeDaCor : Cor -> String
nomeDaCor cor =
    case cor of
        Verde ->
            "verde"

        Amarelo ->
            "amarelo"

        Cinza ->
            "cinza"


viewMensagens : Model -> Html Msg
viewMensagens model =
    case model.erroLocal of
        Just erro ->
            viewAlertaErro erro

        Nothing ->
            case erroRemotoDoModo model of
                Just erro ->
                    viewAlertaErro erro

                Nothing ->
                    if estaCarregando model then
                        div [ class "message message--loading", attribute "role" "status" ]
                            [ span [ class "spinner" ] []
                            , span [] [ text "Consultando o Prolog..." ]
                            ]

                    else
                        viewEstadoDaPartida model


viewAlertaErro : String -> Html Msg
viewAlertaErro erro =
    div [ class "message message--error", attribute "role" "alert" ]
        [ span [] [ text erro ]
        , button
            [ type_ "button"
            , class "message-close"
            , attribute "aria-label" "Fechar aviso"
            , onClick ErroFechado
            ]
            [ text "×" ]
        ]


erroRemotoDoModo : Model -> Maybe String
erroRemotoDoModo model =
    case model.modo of
        Assistente ->
            case model.sugestao of
                Falhou erro ->
                    Just erro

                _ ->
                    case model.candidatas of
                        Falhou erro ->
                            Just erro

                        _ ->
                            Nothing

        Automatico ->
            case model.autoplay of
                Falhou erro ->
                    Just erro

                _ ->
                    Nothing


estaCarregando : Model -> Bool
estaCarregando model =
    case model.modo of
        Assistente ->
            model.candidatas == Carregando || model.sugestao == Carregando

        Automatico ->
            model.autoplay == Carregando


viewEstadoDaPartida : Model -> Html Msg
viewEstadoDaPartida model =
    case model.modo of
        Assistente ->
            if Termo.acertou model.jogo then
                let
                    n =
                        List.length (Termo.historico model.jogo)
                in
                div [ class "message message--success", attribute "role" "status" ]
                    [ text ("Palavra encontrada em " ++ formatarTentativas n ++ "!") ]

            else if Termo.terminou model.jogo then
                div [ class "message message--info", attribute "role" "status" ]
                    [ text "Limite de 6 tentativas atingido. Inicie uma nova partida." ]

            else
                text ""

        Automatico ->
            case model.autoplay of
                Chegou passos ->
                    let
                        n =
                            List.length passos

                        sufixoGrade =
                            if n > Termo.maxPalpites then
                                " (a grade exibe as " ++ String.fromInt Termo.maxPalpites ++ " primeiras)"

                            else
                                ""
                    in
                    if n == 0 then
                        div [ class "message message--info", attribute "role" "status" ]
                            [ text "Nenhum passo retornado." ]

                    else if acertouNosPassos passos then
                        div [ class "message message--success", attribute "role" "status" ]
                            [ text ("Solver acertou em " ++ formatarTentativas n ++ sufixoGrade ++ "!") ]

                    else
                        div [ class "message message--info", attribute "role" "status" ]
                            [ text ("Solver terminou após " ++ formatarTentativas n ++ sufixoGrade ++ ".") ]

                _ ->
                    text ""


acertouNosPassos : List Palpite -> Bool
acertouNosPassos passos =
    List.any
        (\palpite ->
            List.length palpite.cores == Termo.tamanhoPalavra && List.all ((==) Verde) palpite.cores
        )
        passos


formatarTentativas : Int -> String
formatarTentativas n =
    if n == 1 then
        "1 tentativa"

    else
        String.fromInt n ++ " tentativas"


viewPainelDoModo : Model -> List (Html Msg)
viewPainelDoModo model =
    case model.modo of
        Assistente ->
            [ button
                [ type_ "button"
                , class "acao-nova-partida"
                , onClick NovoJogo
                ]
                [ text "Nova partida" ]
            , viewSecaoSugestao model
            , viewSecaoCandidatas model
            ]

        Automatico ->
            [ div [ class "painel-secao" ]
                [ span [ class "panel-label" ] [ text "Palavra secreta" ]
                , form [ class "autoplay-form", onSubmit AutoplaySolicitado ]
                    [ input
                        [ type_ "text"
                        , class "autoplay-input"
                        , placeholder "Ex.: carro"
                        , maxlength Termo.tamanhoPalavra
                        , value model.palavraAutoplay
                        , onInput PalavraAutoplayAlterada
                        , attribute "aria-label" "Palavra de 5 letras para o modo automático"
                        ]
                        []
                    , button
                        [ type_ "submit"
                        , class "autoplay-botao"
                        , disabled (model.autoplay == Carregando)
                        ]
                        [ text "Jogar sozinho" ]
                    ]
                , p [ class "painel-dica" ]
                    [ text "Informe uma palavra de 5 letras sem acentos para o Prolog jogar sozinho até acertá-la." ]
                ]
            ]


viewSecaoSugestao : Model -> Html Msg
viewSecaoSugestao model =
    div [ class "painel-secao" ]
        [ span [ class "panel-label" ] [ text "Sugestão de palpite" ]
        , case model.sugestao of
            NaoPedido ->
                p [ class "painel-dica" ]
                    [ text "Confirme um palpite para ver a próxima sugestão." ]

            Carregando ->
                p [ class "painel-dica" ]
                    [ text "Calculando sugestão..." ]

            Falhou _ ->
                p [ class "painel-dica" ]
                    [ text "Não foi possível obter uma sugestão." ]

            Chegou sugestao ->
                div [ class "sugestao-card" ]
                    [ div [ class "sugestao-topo" ]
                        [ button
                            [ type_ "button"
                            , class "sugestao-palavra"
                            , title "Clique para preencher no rascunho atual"
                            , disabled (Termo.terminou model.jogo)
                            , onClick (PalavraEscolhida sugestao.palavra)
                            ]
                            [ text sugestao.palavra ]
                        ]
                    , p [ class "sugestao-motivo" ] [ text sugestao.motivo ]
                    ]
        ]


viewSecaoCandidatas : Model -> Html Msg
viewSecaoCandidatas model =
    let
        titulo =
            case model.candidatas of
                Chegou palavras ->
                    "Candidatas restantes (" ++ String.fromInt (List.length palavras) ++ ")"

                _ ->
                    "Candidatas restantes"
    in
    div [ class "painel-secao" ]
        [ span [ class "panel-label" ] [ text titulo ]
        , case model.candidatas of
            NaoPedido ->
                p [ class "painel-dica" ]
                    [ text "Digite um palpite, clique nas casas (ou use 1–5) para marcar as cores e confirme com Enter." ]

            Carregando ->
                p [ class "painel-dica" ]
                    [ text "Filtrando palavras..." ]

            Falhou _ ->
                p [ class "painel-dica" ]
                    [ text "Sem candidatas disponíveis." ]

            Chegou [] ->
                p [ class "painel-dica" ]
                    [ text "Nenhuma palavra candidata restante." ]

            Chegou palavras ->
                let
                    total =
                        List.length palavras

                    visiveis =
                        List.take limiteCandidatas palavras

                    restantes =
                        total - limiteCandidatas

                    desabilitado =
                        Termo.terminou model.jogo
                in
                div [ class "painel-secao" ]
                    [ div [ class "candidatas-lista" ]
                        (List.map (viewCandidata desabilitado) visiveis)
                    , if restantes > 0 then
                        p [ class "candidatas-extras" ]
                            [ text ("+ " ++ String.fromInt restantes ++ " outras palavras") ]

                      else
                        text ""
                    ]
        ]


viewCandidata : Bool -> String -> Html Msg
viewCandidata desabilitado palavra =
    button
        [ type_ "button"
        , class "candidata"
        , title "Clique para preencher no rascunho atual"
        , disabled desabilitado
        , onClick (PalavraEscolhida palavra)
        ]
        [ text palavra ]


viewRodape : Modo -> Html Msg
viewRodape modo =
    footer [ class "app-footer" ]
        (case modo of
            Assistente ->
                [ text "Teclado: "
                , kbd [] [ text "A–Z" ]
                , text " digita, "
                , kbd [] [ text "1–5" ]
                , text " muda a cor, "
                , kbd [] [ text "⌫" ]
                , text " apaga, "
                , kbd [] [ text "Enter" ]
                , text " confirma."
                ]

            Automatico ->
                [ text "Digite uma palavra de 5 letras e pressione "
                , kbd [] [ text "Enter" ]
                , text " para ver o solver jogar sozinho."
                ]
        )
