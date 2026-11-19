module Api exposing
    ( Cor(..)
    , Palpite
    , Sugestao
    , buscarCandidatas
    , candidatasDecoder
    , corDecoder
    , encodeHistorico
    , encodePalavra
    , jogarSozinho
    , mensagemDeErro
    , palpiteDecoder
    , passosDecoder
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



-- TIPOS


{-| A cor de uma letra no Termo.

PROVISÓRIO: este tipo pertence a `Termo.elm` (#4). Quando ele existir,
apagar a definição daqui e importar de lá; o resto do módulo não muda.

-}
type Cor
    = Verde
    | Amarelo
    | Cinza


{-| Uma linha do jogo: a palavra tentada e a cor de cada uma das 5 letras.
-}
type alias Palpite =
    { palavra : String
    , cores : List Cor
    }


type alias Sugestao =
    { palavra : String
    , motivo : String
    }



-- REQUISIÇÕES


{-| Palavras da base compatíveis com todos os palpites do histórico.
-}
buscarCandidatas : List Palpite -> (Result String (List String) -> msg) -> Cmd msg
buscarCandidatas historico toMsg =
    Http.post
        { url = "/api/candidatas"
        , body = Http.jsonBody (encodeHistorico historico)
        , expect = expectJson toMsg candidatasDecoder
        }


{-| Próximo palpite escolhido pelo Prolog (minimax), com a justificativa.
-}
sugerir : List Palpite -> (Result String Sugestao -> msg) -> Cmd msg
sugerir historico toMsg =
    Http.post
        { url = "/api/sugestao"
        , body = Http.jsonBody (encodeHistorico historico)
        , expect = expectJson toMsg sugestaoDecoder
        }


{-| O Prolog joga sozinho até acertar `palavra`. Devolve um palpite por
tentativa; o último é todo verde.
-}
jogarSozinho : String -> (Result String (List Palpite) -> msg) -> Cmd msg
jogarSozinho palavra toMsg =
    Http.post
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
                    Err "O servidor demorou demais para responder."

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


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
            "Erro no servidor (código " ++ String.fromInt status ++ ")."
