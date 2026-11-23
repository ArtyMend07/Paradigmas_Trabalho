module CaosApi exposing (jogar, novaPartida, partidaDecoder)

import Caos exposing (Efeito, Evento(..), Exibicao(..), Linha, Partida, Situacao(..))
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Termo exposing (Cor(..))


novaPartida : (Result String Partida -> msg) -> Cmd msg
novaPartida aoReceber =
    Http.post
        { url = "/api/caos/nova"
        , body = Http.emptyBody
        , expect = expectJson aoReceber partidaDecoder
        }


jogar : Int -> String -> (Result String Partida -> msg) -> Cmd msg
jogar partida palavra aoReceber =
    Http.post
        { url = "/api/caos/palpite"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "id", Encode.int partida )
                    , ( "palavra", Encode.string palavra )
                    ]
                )
        , expect = expectJson aoReceber partidaDecoder
        }


partidaDecoder : Decoder Partida
partidaDecoder =
    Decode.map6 Partida
        (Decode.field "id" Decode.int)
        (Decode.field "linhas" (Decode.list linhaDecoder))
        (Decode.field "max_linhas" Decode.int)
        (Decode.field "proximo" efeitoOpcionalDecoder)
        (Decode.field "evento" eventoDecoder)
        situacaoDecoder


linhaDecoder : Decoder Linha
linhaDecoder =
    Decode.map3 Linha
        (Decode.field "palavra" Decode.string)
        (Decode.field "efeito" efeitoOpcionalDecoder)
        exibicaoDecoder


exibicaoDecoder : Decoder Exibicao
exibicaoDecoder =
    Decode.field "tipo" Decode.string
        |> Decode.andThen
            (\tipo ->
                case tipo of
                    "cores" ->
                        Decode.map Cores (Decode.field "cores" (Decode.list corDecoder))

                    "contagem" ->
                        Decode.map2 (\verdes amarelas -> Contagem { verdes = verdes, amarelas = amarelas })
                            (Decode.field "verdes" Decode.int)
                            (Decode.field "amarelas" Decode.int)

                    "oculta" ->
                        Decode.succeed Oculta

                    _ ->
                        Decode.fail ("Exibição desconhecida: " ++ tipo)
            )


corDecoder : Decoder Cor
corDecoder =
    Decode.string
        |> Decode.andThen
            (\cor ->
                case cor of
                    "green" ->
                        Decode.succeed Verde

                    "yellow" ->
                        Decode.succeed Amarelo

                    "gray" ->
                        Decode.succeed Cinza

                    _ ->
                        Decode.fail ("Cor desconhecida: " ++ cor)
            )


efeitoOpcionalDecoder : Decoder (Maybe Efeito)
efeitoOpcionalDecoder =
    Decode.string
        |> Decode.andThen
            (\texto ->
                if String.isEmpty texto then
                    Decode.succeed Nothing

                else
                    case Caos.efeitoDeTexto texto of
                        Just efeito ->
                            Decode.succeed (Just efeito)

                        Nothing ->
                            Decode.fail ("Efeito desconhecido: " ++ texto)
            )


eventoDecoder : Decoder (Maybe Evento)
eventoDecoder =
    Decode.map3
        (\efeito letra presente -> { efeito = efeito, letra = letra, presente = presente })
        (Decode.field "efeito" efeitoOpcionalDecoder)
        (Decode.field "letra" Decode.string)
        (Decode.field "presente" Decode.bool)
        |> Decode.andThen eventoDeCampos


eventoDeCampos : { efeito : Maybe Efeito, letra : String, presente : Bool } -> Decoder (Maybe Evento)
eventoDeCampos campos =
    case ( campos.efeito, String.uncons campos.letra ) of
        ( Nothing, _ ) ->
            Decode.succeed Nothing

        ( Just Caos.DicaDeLetra, Just ( letra, "" ) ) ->
            Decode.succeed (Just (LetraRevelada { letra = letra, presente = campos.presente }))

        ( Just Caos.DicaDeLetra, _ ) ->
            Decode.fail "Dica de letra sem letra."

        ( Just efeito, _ ) ->
            Decode.succeed (Just (Instantaneo efeito))


situacaoDecoder : Decoder Situacao
situacaoDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "situacao" Decode.string)
        (Decode.field "resposta" Decode.string)
        |> Decode.andThen
            (\( situacao, resposta ) ->
                case situacao of
                    "em_andamento" ->
                        Decode.succeed EmAndamento

                    "venceu" ->
                        Decode.succeed Venceu

                    "perdeu" ->
                        Decode.succeed (Perdeu resposta)

                    _ ->
                        Decode.fail ("Situação desconhecida: " ++ situacao)
            )


{-| O Http.expectJson descarta o corpo das respostas de erro, e o backend manda
a mensagem para a tela em detail.
-}
expectJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
expectJson aoReceber decoder =
    Http.expectStringResponse aoReceber <|
        \resposta ->
            case resposta of
                Http.GoodStatus_ _ corpo ->
                    Decode.decodeString decoder corpo
                        |> Result.mapError (\_ -> "Resposta inesperada do servidor.")

                Http.BadStatus_ metadados corpo ->
                    Err (detalheDoErro metadados.statusCode corpo)

                Http.BadUrl_ url ->
                    Err ("URL inválida: " ++ url)

                Http.Timeout_ ->
                    Err "O servidor demorou demais para responder."

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


detalheDoErro : Int -> String -> String
detalheDoErro status corpo =
    case Decode.decodeString (Decode.field "detail" Decode.string) corpo of
        Ok detalhe ->
            detalhe

        Err _ ->
            "Erro no servidor (código " ++ String.fromInt status ++ ")."
