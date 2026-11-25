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
import Festa
import Html exposing (Html, button, div, kbd, p, span, text)
import Html.Attributes exposing (attribute, class, classList, disabled, type_)
import Html.Events exposing (onClick)
import Html.Keyed
import Json.Decode as Decode exposing (Decoder)
import Process
import Random
import Rascunho exposing (Rascunho)
import Task
import Teclado exposing (Tecla(..))
import Termo exposing (Cor(..), Remoto(..))


{-| `tremor` conta os palpites recusados seguidos e `rodada` conta as respostas
do servidor. A view alterna entre duas classes CSS conforme a paridade desses
contadores, porque trocar o nome da animação é o que faz o navegador rodá-la de
novo.
-}
type alias Model =
    { partida : Remoto Partida
    , rascunho : Rascunho
    , erro : Maybe String
    , enviando : Bool
    , tela : EfeitosNaTela
    , tremor : Int
    , rodada : Int
    , avisos : List Aviso
    , proximoAviso : Int
    , pedido : Int
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


{-| Aviso lateral de efeito, que some sozinho depois de `duracaoDoAviso`.
-}
type alias Aviso =
    { id : Int
    , titulo : String
    , texto : String
    , tom : Tom
    }


type Tom
    = Ajuda
    | Atrapalha
    | Anuncio


duracaoDoAviso : Float
duracaoDoAviso =
    6000


maximoDeAvisos : Int
maximoDeAvisos =
    4


semEfeitosNaTela : EfeitosNaTela
semEfeitosNaTela =
    { furos = [], apagada = Nothing, explodidas = [], limpas = [] }


type Msg
    = NovaPartida
    | RecebeuPartida Int (Result String Partida)
    | TeclaPressionada Tecla
    | Atirou (List ( Int, Int ))
    | Explodiu (List Char)
    | CasaEscolhida Int
    | AvisoExpirou Int


inicial : Model
inicial =
    { partida = NaoPedido
    , rascunho = Rascunho.vazio
    , erro = Nothing
    , enviando = False
    , tela = semEfeitosNaTela
    , tremor = 0
    , rodada = 0
    , avisos = []
    , proximoAviso = 0
    , pedido = 0
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
    ( { model
        | partida = Carregando
        , rascunho = Rascunho.vazio
        , erro = Nothing
        , enviando = False
        , tela = semEfeitosNaTela
        , tremor = 0
        , avisos = []
        , pedido = model.pedido + 1
      }
    , CaosApi.novaPartida (RecebeuPartida (model.pedido + 1))
    )


{-| Cada requisição leva o número do pedido. Uma resposta de pedido que já foi
substituído (por exemplo, um palpite enviado antes de clicar em "Nova
partida") é descartada.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RecebeuPartida pedido _ ->
            if pedido == model.pedido then
                atualizar msg model

            else
                ( model, Cmd.none )

        _ ->
            atualizar msg model


atualizar : Msg -> Model -> ( Model, Cmd Msg )
atualizar msg model =
    case msg of
        NovaPartida ->
            iniciarPartida model

        RecebeuPartida _ (Ok partida) ->
            let
                ( tela, cmdTela ) =
                    atualizarTela partida model.tela

                ( comAvisos, cmdAvisos ) =
                    adicionarAvisos (avisosDaResposta model.partida partida) model
            in
            ( { comAvisos
                | partida = Chegou partida
                , rascunho = Rascunho.vazio
                , erro = Nothing
                , enviando = False
                , tela = tela
                , tremor = 0
                , rodada = model.rodada + 1
              }
            , Cmd.batch [ cmdTela, cmdAvisos ]
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

        RecebeuPartida _ (Err erro) ->
            case model.partida of
                Chegou _ ->
                    ( { model | erro = Just erro, enviando = False, tremor = model.tremor + 1 }, Cmd.none )

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

        CasaEscolhida posicao ->
            if emAndamento model then
                ( { model | rascunho = Rascunho.posicionar posicao model.rascunho }, Cmd.none )

            else
                ( model, Cmd.none )

        AvisoExpirou id ->
            ( { model | avisos = List.filter (\aviso -> aviso.id /= id) model.avisos }, Cmd.none )


emAndamento : Model -> Bool
emAndamento model =
    case model.partida of
        Chegou partida ->
            Caos.emAndamento partida

        _ ->
            False


{-| O efeito que aconteceu agora e o efeito anunciado para o próximo palpite.
O anúncio só vira aviso quando é novo, para não repetir a cada resposta.
-}
avisosDaResposta : Remoto Partida -> Partida -> List ( String, String, Tom )
avisosDaResposta anterior partida =
    let
        jaAnunciado =
            case anterior of
                Chegou antes ->
                    antes.proximo /= Nothing && antes.proximo == partida.proximo

                _ ->
                    False

        anuncio =
            if jaAnunciado then
                Nothing

            else
                Maybe.map (\efeito -> ( "No próximo palpite: " ++ Caos.nome efeito, Caos.descricao efeito, Anuncio )) partida.proximo
    in
    List.filterMap identity [ Maybe.map avisoDoEvento partida.evento, anuncio ]


avisoDoEvento : Evento -> ( String, String, Tom )
avisoDoEvento evento =
    case evento of
        Instantaneo efeito ->
            ( Caos.nome efeito, Caos.descricao efeito, tomDoEfeito efeito )

        LetraRevelada dica ->
            ( Caos.nome Caos.DicaDeLetra, textoDaDica dica, Ajuda )


textoDaDica : { letra : Char, presente : Bool } -> String
textoDaDica dica =
    let
        onde =
            if dica.presente then
                " está na palavra."

            else
                " não está na palavra."
    in
    "A letra " ++ String.toUpper (String.fromChar dica.letra) ++ onde


tomDoEfeito : Efeito -> Tom
tomDoEfeito efeito =
    if Caos.ajuda efeito then
        Ajuda

    else
        Atrapalha


adicionarAvisos : List ( String, String, Tom ) -> Model -> ( Model, Cmd Msg )
adicionarAvisos novos model =
    let
        criados =
            List.indexedMap
                (\i ( titulo, texto, tom ) -> { id = model.proximoAviso + i, titulo = titulo, texto = texto, tom = tom })
                novos

        expirar aviso =
            Process.sleep duracaoDoAviso |> Task.perform (\_ -> AvisoExpirou aviso.id)
    in
    ( { model
        | avisos = List.take maximoDeAvisos (List.reverse criados ++ model.avisos)
        , proximoAviso = model.proximoAviso + List.length criados
      }
    , Cmd.batch (List.map expirar criados)
    )


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
        Termo.corDasLetras (Caos.palpitesComCores partida) letra


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
            ( editar (Rascunho.digitar letra) model, Cmd.none )

        Apagar ->
            ( editar Rascunho.apagar model, Cmd.none )

        Esquerda ->
            ( editar Rascunho.recuar model, Cmd.none )

        Direita ->
            ( editar Rascunho.avancar model, Cmd.none )

        Enter ->
            case Rascunho.palavra model.rascunho of
                Nothing ->
                    ( { model | erro = Just "A palavra precisa ter 5 letras.", tremor = model.tremor + 1 }, Cmd.none )

                Just palavra ->
                    ( { model | enviando = True, erro = Nothing, pedido = model.pedido + 1 }
                    , CaosApi.jogar partida.id palavra (RecebeuPartida (model.pedido + 1))
                    )


editar : (Rascunho -> Rascunho) -> Model -> Model
editar mudanca model =
    { model | rascunho = mudanca model.rascunho, erro = Nothing, tremor = 0 }


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
            div [ classList (( "caos-jogo", True ) :: alternar "caos-jogo--abalo" model.rodada (abala partida)) ]
                [ viewArma model.tela
                , viewImpacto model.rodada partida.evento
                , div [ class "grade", attribute "role" "grid", attribute "aria-label" "Grade do modo caos" ]
                    (linhasDaGrade model partida)
                , Teclado.viewTecladoCom TeclaPressionada (corDaTecla partida model.tela) (teclaAparece partida model.tela)
                , if partida.situacao == Venceu then
                    Festa.confete

                  else
                    text ""
                ]

        _ ->
            div [ class "grade" ] []


{-| Classe `<base>-a` ou `<base>-b` conforme a paridade do contador, para a
animação rodar de novo a cada vez (ver `Model`).
-}
alternar : String -> Int -> Bool -> List ( String, Bool )
alternar base contador ativo =
    [ ( base ++ "-a", ativo && modBy 2 contador == 0 )
    , ( base ++ "-b", ativo && modBy 2 contador == 1 )
    ]


abala : Partida -> Bool
abala partida =
    case partida.evento of
        Just (Instantaneo efeito) ->
            not (Caos.ajuda efeito)

        _ ->
            False


{-| A arma entra, atira e sai pela animação do CSS, que roda uma vez quando o
elemento aparece.
-}
viewArma : EfeitosNaTela -> Html Msg
viewArma tela =
    if List.isEmpty tela.furos then
        text ""

    else
        div [ class "caos-arma", attribute "aria-hidden" "true" ] [ text "🔫" ]


{-| Carimbo com o nome do efeito por cima da grade. A chave muda a cada
resposta, então o elemento é recriado e a animação de entrada roda de novo.
-}
viewImpacto : Int -> Maybe Evento -> Html Msg
viewImpacto rodada evento =
    Html.Keyed.node "div"
        [ class "caos-impactos", attribute "aria-hidden" "true" ]
        (case evento of
            Just (Instantaneo efeito) ->
                [ ( String.fromInt rodada, carimbo (Caos.codigo efeito) (Caos.nome efeito) ) ]

            Just (LetraRevelada dica) ->
                [ ( String.fromInt rodada, carimbo (Caos.codigo Caos.DicaDeLetra) (String.toUpper (String.fromChar dica.letra)) ) ]

            Nothing ->
                []
        )


carimbo : String -> String -> Html Msg
carimbo codigo rotulo =
    div [ class ("caos-impacto caos-impacto--" ++ codigo) ]
        [ span [ class "caos-impacto-onda" ] []
        , span [ class "caos-impacto-nome" ] [ text rotulo ]
        ]


linhasDaGrade : Model -> Partida -> List (Html Msg)
linhasDaGrade model partida =
    let
        ultima =
            List.length partida.linhas - 1

        jogadas =
            List.indexedMap
                (\numero linha -> viewLinha model.tela (partida.situacao == Venceu && numero == ultima) numero linha)
                partida.linhas

        atual =
            if Caos.emAndamento partida then
                [ viewRascunho model partida.proximo ]

            else
                []

        vazias =
            List.repeat (partida.maxLinhas - List.length jogadas - List.length atual) viewLinhaVazia
    in
    jogadas ++ atual ++ vazias


viewLinha : EfeitosNaTela -> Bool -> Int -> Linha -> Html Msg
viewLinha tela vitoria numero linha =
    let
        apagada =
            Maybe.map .linha tela.apagada == Just numero

        casas classeDe =
            List.indexedMap
                (\posicao letra ->
                    viewCasa (List.member ( numero, posicao ) tela.furos)
                        (classeDe posicao letra)
                        (if apagada then
                            ""

                         else
                            String.fromChar (Char.toUpper letra)
                        )
                )
                (String.toList linha.palavra)

        classes extra =
            classList
                (( "linha", True )
                    :: ( extra, True )
                    :: ( "linha--vitoria", vitoria )
                    :: List.map (\efeito -> ( "linha--efeito-" ++ Caos.codigo efeito, True )) (List.filterMap identity [ linha.efeito ])
                )
    in
    case linha.exibicao of
        Cores cores ->
            div [ classes "linha--cores", attribute "role" "row" ]
                (casas (\posicao letra -> classeDaCasa tela letra (List.head (List.drop posicao cores))))

        Contagem contagem ->
            div [ classes "linha--caos", attribute "role" "row" ]
                (casas (\_ _ -> "casa--sem-cor")
                    ++ [ span [ class "linha-contagem" ]
                            [ text (String.fromInt contagem.verdes ++ "V " ++ String.fromInt contagem.amarelas ++ "A") ]
                       ]
                )

        Oculta ->
            div [ classes "linha--caos", attribute "role" "row" ]
                (casas (\_ _ -> "casa--oculta"))


{-| Letra explodida perde a cor também na grade. Sem isso o jogador olharia a
linha em vez do teclado e a explosão não atrapalharia (#19).
-}
classeDaCasa : EfeitosNaTela -> Char -> Maybe Cor -> String
classeDaCasa tela letra cor =
    if List.member letra tela.explodidas then
        "casa--queimada"

    else
        Maybe.withDefault "" (Maybe.map classeDaCor cor)


{-| Uma casa furada pelo tiroteio esconde a letra e a cor.
-}
viewCasa : Bool -> String -> String -> Html Msg
viewCasa furada classe letra =
    if furada then
        div [ class "casa casa--confirmada casa--furada", attribute "role" "gridcell", attribute "aria-label" "casa furada" ] []

    else
        div [ class ("casa casa--confirmada " ++ classe), attribute "role" "gridcell" ] [ text letra ]


{-| A linha em edição brilha quando há efeito anunciado para ela: vermelha se
atrapalha, azul se ajuda.
-}
viewRascunho : Model -> Maybe Efeito -> Html Msg
viewRascunho model proximo =
    div
        [ classList
            ([ ( "linha", True )
             , ( "linha--amaldicoada", Maybe.map Caos.ajuda proximo == Just False )
             , ( "linha--protegida", Maybe.map Caos.ajuda proximo == Just True )
             ]
                ++ alternar "linha--tremor" model.tremor (model.tremor > 0)
            )
        , attribute "role" "row"
        ]
        (List.indexedMap (viewCasaRascunho (Rascunho.cursor model.rascunho)) (Rascunho.casas model.rascunho))


viewCasaRascunho : Int -> Int -> Maybe Char -> Html Msg
viewCasaRascunho cursor posicao letra =
    button
        ([ type_ "button"
         , classList
            [ ( "casa casa--edicao", True )
            , ( "casa--preenchida", letra /= Nothing )
            , ( "casa--cursor", posicao == cursor )
            ]
         , attribute "aria-label" ("Casa " ++ String.fromInt (posicao + 1))
         ]
            ++ Teclado.apertarSemFoco (CasaEscolhida posicao)
        )
        [ text (Maybe.withDefault "" (Maybe.map (Char.toUpper >> String.fromChar) letra)) ]


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
    , div [ class "caos-painel" ] (viewEstado model)
    , Html.Keyed.node "div"
        [ class "caos-avisos", attribute "aria-live" "polite" ]
        (List.map (\aviso -> ( String.fromInt aviso.id, viewAviso aviso )) model.avisos)
    ]


viewEstado : Model -> List (Html Msg)
viewEstado model =
    case model.partida of
        NaoPedido ->
            []

        Carregando ->
            [ mensagem "message--loading" "Sorteando a palavra..." ]

        Falhou erro ->
            [ mensagem "message--error" erro ]

        Chegou partida ->
            List.filterMap identity
                [ Just (viewSituacao partida)
                , Maybe.map viewPendente partida.proximo
                , Maybe.map (mensagem "message--error") model.erro
                ]


viewSituacao : Partida -> Html Msg
viewSituacao partida =
    case partida.situacao of
        EmAndamento ->
            viewLinhasRestantes partida

        Venceu ->
            mensagem "message--success" "Acertou, apesar do caos!"

        Perdeu resposta ->
            mensagem "message--error" ("A palavra era " ++ String.toUpper resposta ++ ".")


{-| Uma bolinha por linha da partida, apagada quando a linha já foi usada.
-}
viewLinhasRestantes : Partida -> Html Msg
viewLinhasRestantes partida =
    let
        restantes =
            Caos.linhasRestantes partida
    in
    div
        [ class "caos-vidas"
        , attribute "role" "status"
        , attribute "aria-label" ("Linhas restantes: " ++ String.fromInt restantes)
        ]
        [ span [ class "panel-label" ] [ text ("Linhas restantes: " ++ String.fromInt restantes) ]
        , div [ class "caos-vidas-bolinhas" ]
            (List.map
                (\i -> span [ classList [ ( "caos-vida", True ), ( "caos-vida--usada", i >= restantes ) ] ] [])
                (List.range 0 (partida.maxLinhas - 1))
            )
        ]


viewPendente : Efeito -> Html Msg
viewPendente efeito =
    div
        [ classList
            [ ( "caos-pendente", True )
            , ( "caos-pendente--ajuda", Caos.ajuda efeito )
            ]
        , attribute "role" "status"
        ]
        [ span [ class "caos-pendente-rotulo" ] [ text "No próximo palpite" ]
        , span [ class "caos-pendente-nome" ] [ text (Caos.nome efeito) ]
        ]


viewAviso : Aviso -> Html Msg
viewAviso aviso =
    div
        [ class ("caos-aviso caos-aviso--" ++ classeDoTom aviso.tom)
        , attribute "style" ("--duracao:" ++ String.fromFloat duracaoDoAviso ++ "ms")
        , attribute "role" "status"
        ]
        [ p [ class "caos-aviso-titulo" ] [ text aviso.titulo ]
        , p [ class "caos-aviso-texto" ] [ text aviso.texto ]
        , span [ class "caos-aviso-tempo" ] []
        ]


classeDoTom : Tom -> String
classeDoTom tom =
    case tom of
        Ajuda ->
            "ajuda"

        Atrapalha ->
            "atrapalha"

        Anuncio ->
            "anuncio"


mensagem : String -> String -> Html Msg
mensagem tipo conteudo =
    div [ class ("message " ++ tipo), attribute "role" "status" ] [ text conteudo ]


viewRodape : List (Html msg)
viewRodape =
    [ text "A cada 2 palpites um efeito é sorteado. "
    , kbd [] [ text "A–Z" ]
    , text " digita, "
    , kbd [] [ text "←" ]
    , kbd [] [ text "→" ]
    , text " ou um clique escolhem a casa, "
    , kbd [] [ text "⌫" ]
    , text " apaga, "
    , kbd [] [ text "Enter" ]
    , text " confirma."
    ]
