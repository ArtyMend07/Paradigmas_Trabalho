module Api exposing
    ( Sugestao
    , buscarCandidatas
    , candidatasDecoder
    , corDecoder
    , encodeHistorico
    , encodePalavra
    , jogarSozinho
    , mensagemDeErro
    , palpiteDecoder
    , passosDecoder
    , post
    , semResposta
    , sugerir
    , sugestaoDecoder
    )

{-| Comunicação com o backend (FastAPI + Prolog).

Este módulo é o CONTRATO entre o Elm e o backend (#7). Cada rota recebe e
devolve JSON:

    POST /api/candidatas
        envia  {"historico": [["barra", ["gray","green","green","green","gray"]], ...]}
        recebe {"palavras": ["carro", "jarro", ...]}

    POST /api/sugestao
        envia  {"historico": [...]}             (mesmo formato acima)
        recebe {"palavra": "corvo", "motivo": "restam 6 palavras; ..."}

    POST /api/autoplay
        envia  {"palavra": "carro"}
        recebe {"passos": [["serao", ["gray", ...]], ..., ["carro", ["green", ...]]]}

    Erros: status 422 com {"detail": "mensagem"}.

Um palpite é um par `[palavra, cores]` (lista, não objeto) porque é esse o
formato que os predicados Prolog usam: o janus não converte termos
compostos, então o backend repassa as listas como vieram.

Assim como no template, nenhuma função aqui "faz" a requisição: elas
devolvem um `Cmd msg`, que o runtime do Elm executa. A resposta volta ao
`update` sempre como `Result String a`.

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Termo exposing (Cor(..), Palpite)



-- TIPOS


type alias Sugestao =
    { palavra : String
    , motivo : String
    }



-- REQUISIÇÕES


{-| Tempo máximo de espera por uma resposta do backend, em milissegundos. Sem
ele, um backend que aceita a conexão mas nunca responde deixa a tela em
"Consultando o Prolog..." para sempre.
-}
tempoLimite : Float
tempoLimite =
    15000


{-| Igual ao `Http.post`, mas com `tempoLimite`. Todas as requisições do
frontend passam por aqui, inclusive as do modo caos.
-}
post : { url : String, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
post { url, body, expect } =
    Http.request
        { method = "POST"
        , headers = []
        , url = url
        , body = body
        , expect = expect
        , timeout = Just tempoLimite
        , tracker = Nothing
        }


{-| Palavras da base compatíveis com todos os palpites do histórico.
-}
buscarCandidatas : List Palpite -> (Result String (List String) -> msg) -> Cmd msg
buscarCandidatas historico toMsg =
    post
        { url = "/api/candidatas"
        , body = Http.jsonBody (encodeHistorico historico)
        , expect = expectJson toMsg candidatasDecoder
        }


{-| Próximo palpite escolhido pelo Prolog (minimax), com a justificativa.
-}
sugerir : List Palpite -> (Result String Sugestao -> msg) -> Cmd msg
sugerir historico toMsg =
    post
        { url = "/api/sugestao"
        , body = Http.jsonBody (encodeHistorico historico)
        , expect = expectJson toMsg sugestaoDecoder
        }


{-| O Prolog joga sozinho até acertar `palavra`. Devolve um palpite por
tentativa; o último é todo verde.
-}
jogarSozinho : String -> (Result String (List Palpite) -> msg) -> Cmd msg
jogarSozinho palavra toMsg =
    post
        { url = "/api/autoplay"
        , body = Http.jsonBody (encodePalavra palavra)
        , expect = expectJson toMsg passosDecoder
        }



-- ENCODERS


corParaString : Cor -> String
corParaString cor =
    case cor of
        Verde ->
            "green"

        Amarelo ->
            "yellow"

        Cinza ->
            "gray"


{-| Um palpite vira `["barra", ["gray", "green", ...]]`.
-}
encodePalpite : Palpite -> Encode.Value
encodePalpite palpite =
    Encode.list identity
        [ Encode.string palpite.palavra
        , Encode.list (corParaString >> Encode.string) palpite.cores
        ]


encodeHistorico : List Palpite -> Encode.Value
encodeHistorico historico =
    Encode.object [ ( "historico", Encode.list encodePalpite historico ) ]


encodePalavra : String -> Encode.Value
encodePalavra palavra =
    Encode.object [ ( "palavra", Encode.string palavra ) ]



-- DECODERS
--
-- Os decoders são estritos de propósito: uma cor desconhecida ou um palpite
-- com número errado de cores vira erro de decodificação, em vez de um valor
-- que o resto do programa teria que conferir de novo.


{-| `Decode.andThen` olha o valor já lido e decide o próximo decoder: aqui,
sucesso com a cor certa ou falha com uma mensagem.
-}
corDecoder : Decoder Cor
corDecoder =
    Decode.string
        |> Decode.andThen
            (\texto ->
                case texto of
                    "green" ->
                        Decode.succeed Verde

                    "yellow" ->
                        Decode.succeed Amarelo

                    "gray" ->
                        Decode.succeed Cinza

                    _ ->
                        Decode.fail ("Cor desconhecida: " ++ texto)
            )


{-| Lê `["barra", [cores]]`. `Decode.index` pega uma posição da lista.
-}
palpiteDecoder : Decoder Palpite
palpiteDecoder =
    Decode.map2 Palpite
        (Decode.index 0 Decode.string)
        (Decode.index 1 (Decode.list corDecoder |> Decode.andThen exigirCincoCores))


exigirCincoCores : List Cor -> Decoder (List Cor)
exigirCincoCores cores =
    if List.length cores == 5 then
        Decode.succeed cores

    else
        Decode.fail ("Esperava 5 cores, vieram " ++ String.fromInt (List.length cores) ++ ".")


candidatasDecoder : Decoder (List String)
candidatasDecoder =
    Decode.field "palavras" (Decode.list Decode.string)


sugestaoDecoder : Decoder Sugestao
sugestaoDecoder =
    Decode.map2 Sugestao
        (Decode.field "palavra" Decode.string)
        (Decode.field "motivo" Decode.string)


passosDecoder : Decoder (List Palpite)
passosDecoder =
    Decode.field "passos" (Decode.list palpiteDecoder)



-- TRATAMENTO DE ERROS


{-| Igual ao `Http.expectJson`, mas lê o corpo das respostas de erro para
mostrar a mensagem do backend em vez de só o código HTTP.
-}
expectJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    Decode.decodeString decoder body
                        |> Result.mapError (\_ -> "Resposta inesperada do servidor.")

                Http.BadStatus_ metadata body ->
                    Err (mensagemDeErro metadata.statusCode body)

                Http.BadUrl_ url ->
                    Err ("URL inválida: " ++ url)

                Http.Timeout_ ->
                    Err semResposta

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


{-| Mensagem para quando o backend não responde a tempo, ou quando o proxy do
Vite não consegue falar com ele (502, 503 ou 504).
-}
semResposta : String
semResposta =
    "O backend não respondeu. Confira se ele está rodando (make backend) e o que aparece no terminal dele."


{-| Extrai a mensagem do corpo de um erro. O `detail` chega em dois formatos:

  - erro nosso (422 lançado nas rotas): `{"detail": "Nenhuma palavra ..."}`
  - erro de validação do Pydantic: `{"detail": [{"msg": "...", ...}, ...]}`

`Decode.oneOf` tenta cada decoder em ordem e fica com o primeiro que dá
certo. Se nenhum servir, a mensagem genérica traz o código HTTP.

-}
mensagemDeErro : Int -> String -> String
mensagemDeErro status body =
    let
        detail =
            Decode.field "detail"
                (Decode.oneOf
                    [ Decode.string
                    , Decode.index 0 (Decode.field "msg" Decode.string)
                    ]
                )
    in
    case Decode.decodeString detail body of
        Ok mensagem ->
            mensagem

        Err _ ->
            if List.member status [ 502, 503, 504 ] then
                semResposta

            else
                "Erro no servidor (código " ++ String.fromInt status ++ ")."
