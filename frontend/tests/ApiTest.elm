module ApiTest exposing (suite)

import Api exposing (Cor(..))
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Api"
        [ describe "corDecoder"
            [ test "lê as três cores" <|
                \_ ->
                    Decode.decodeString (Decode.list Api.corDecoder) """["green", "yellow", "gray"]"""
                        |> Expect.equal (Ok [ Verde, Amarelo, Cinza ])
            , test "cor desconhecida é erro" <|
                \_ ->
                    Decode.decodeString Api.corDecoder "\"blue\""
                        |> Expect.err
            ]
        , describe "candidatasDecoder"
            [ test "lê a lista de palavras" <|
                \_ ->
                    Decode.decodeString Api.candidatasDecoder """{"palavras": ["carro", "jarro"]}"""
                        |> Expect.equal (Ok [ "carro", "jarro" ])
            , test "lista vazia é válida" <|
                \_ ->
                    Decode.decodeString Api.candidatasDecoder """{"palavras": []}"""
                        |> Expect.equal (Ok [])
            ]
        , describe "sugestaoDecoder"
            [ test "lê palavra e motivo" <|
                \_ ->
                    Decode.decodeString Api.sugestaoDecoder
                        """{"palavra": "corvo", "motivo": "restam 6 palavras; com este palpite sobram no máximo 2"}"""
                        |> Expect.equal
                            (Ok
                                { palavra = "corvo"
                                , motivo = "restam 6 palavras; com este palpite sobram no máximo 2"
                                }
                            )
            , test "sem motivo é erro" <|
                \_ ->
                    Decode.decodeString Api.sugestaoDecoder """{"palavra": "corvo"}"""
                        |> Expect.err
            ]
        , describe "passosDecoder"
            [ test "lê os passos do autoplay" <|
                \_ ->
                    Decode.decodeString Api.passosDecoder
                        """{"passos": [
                            ["barra", ["gray", "green", "green", "green", "gray"]],
                            ["carro", ["green", "green", "green", "green", "green"]]
                        ]}"""
                        |> Expect.equal
                            (Ok
                                [ { palavra = "barra", cores = [ Cinza, Verde, Verde, Verde, Cinza ] }
                                , { palavra = "carro", cores = [ Verde, Verde, Verde, Verde, Verde ] }
                                ]
                            )
            , test "cor desconhecida dentro de um passo é erro" <|
                \_ ->
                    Decode.decodeString Api.passosDecoder
                        """{"passos": [["barra", ["gray", "green", "purple", "green", "gray"]]]}"""
                        |> Expect.err
            , test "palpite com menos de 5 cores é erro" <|
                \_ ->
                    Decode.decodeString Api.palpiteDecoder """["barra", ["gray", "green"]]"""
                        |> Expect.err
            ]
        , describe "encoders"
            [ test "histórico vira lista de pares [palavra, cores]" <|
                \_ ->
                    Api.encodeHistorico [ { palavra = "barra", cores = [ Cinza, Verde, Verde, Verde, Cinza ] } ]
                        |> Encode.encode 0
                        |> Expect.equal """{"historico":[["barra",["gray","green","green","green","gray"]]]}"""
            , test "histórico vazio" <|
                \_ ->
                    Api.encodeHistorico []
                        |> Encode.encode 0
                        |> Expect.equal """{"historico":[]}"""
            , test "o que o encoder escreve o decoder lê de volta" <|
                \_ ->
                    let
                        palpite =
                            { palavra = "termo", cores = [ Verde, Amarelo, Cinza, Cinza, Verde ] }
                    in
                    Api.encodeHistorico [ palpite ]
                        |> Encode.encode 0
                        |> Decode.decodeString (Decode.field "historico" (Decode.list Api.palpiteDecoder))
                        |> Expect.equal (Ok [ palpite ])
            , test "palavra do autoplay" <|
                \_ ->
                    Api.encodePalavra "carro"
                        |> Encode.encode 0
                        |> Expect.equal """{"palavra":"carro"}"""
            ]
        , describe "mensagemDeErro (corpo das respostas 422)"
            [ test "detail em texto, lançado pela rota" <|
                \_ ->
                    Api.mensagemDeErro 422 """{"detail": "Nenhuma palavra corresponde às cores informadas."}"""
                        |> Expect.equal "Nenhuma palavra corresponde às cores informadas."
            , test "detail em lista, da validação do Pydantic" <|
                \_ ->
                    Api.mensagemDeErro 422
                        """{"detail": [{"type": "string_pattern_mismatch", "loc": ["body", "palavra"], "msg": "String should match pattern '^[a-z]{5}$'"}]}"""
                        |> Expect.equal "String should match pattern '^[a-z]{5}$'"
            , test "corpo sem detail cai na mensagem genérica" <|
                \_ ->
                    Api.mensagemDeErro 500 "Internal Server Error"
                        |> Expect.equal "Erro no servidor (código 500)."
            ]
        ]
