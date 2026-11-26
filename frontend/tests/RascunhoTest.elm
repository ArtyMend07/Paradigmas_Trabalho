module RascunhoTest exposing (suite)

import Expect
import Rascunho exposing (Rascunho)
import Test exposing (Test, describe, test)


digitarTexto : String -> Rascunho -> Rascunho
digitarTexto texto rascunho =
    List.foldl Rascunho.digitar rascunho (String.toList texto)


suite : Test
suite =
    describe "Rascunho"
        [ test "digitar cinco letras forma a palavra" <|
            \_ ->
                Rascunho.vazio
                    |> digitarTexto "termo"
                    |> Rascunho.palavra
                    |> Expect.equal (Just "termo")
        , test "linha incompleta não forma palavra" <|
            \_ ->
                Rascunho.vazio
                    |> digitarTexto "ter"
                    |> Rascunho.palavra
                    |> Expect.equal Nothing
        , test "letra além da quinta é ignorada" <|
            \_ ->
                Rascunho.vazio
                    |> digitarTexto "termos"
                    |> Rascunho.palavra
                    |> Expect.equal (Just "termo")
        , test "posicionar e digitar troca só a partir da casa escolhida" <|
            \_ ->
                Rascunho.vazio
                    |> digitarTexto "termo"
                    |> Rascunho.posicionar 3
                    |> digitarTexto "na"
                    |> Rascunho.palavra
                    |> Expect.equal (Just "terna")
        , test "digitar avança o cursor para a casa seguinte" <|
            \_ ->
                Rascunho.vazio
                    |> Rascunho.posicionar 1
                    |> Rascunho.digitar 'a'
                    |> Rascunho.cursor
                    |> Expect.equal 2
        , test "apagar com a casa do cursor vazia apaga a anterior" <|
            \_ ->
                Rascunho.vazio
                    |> digitarTexto "ter"
                    |> Rascunho.apagar
                    |> Rascunho.casas
                    |> Expect.equal [ Just 't', Just 'e', Nothing, Nothing, Nothing ]
        , test "apagar com a casa do cursor preenchida apaga ela e não move" <|
            \_ ->
                let
                    rascunho =
                        Rascunho.vazio
                            |> digitarTexto "termo"
                            |> Rascunho.posicionar 1
                            |> Rascunho.apagar
                in
                Expect.equal ( Rascunho.casas rascunho, Rascunho.cursor rascunho )
                    ( [ Just 't', Nothing, Just 'r', Just 'm', Just 'o' ], 1 )
        , test "apagar no início da linha vazia não faz nada" <|
            \_ ->
                Rascunho.apagar Rascunho.vazio
                    |> Expect.equal Rascunho.vazio
        , test "posicionar fora da linha fica no limite" <|
            \_ ->
                Rascunho.vazio
                    |> Rascunho.posicionar 9
                    |> Rascunho.cursor
                    |> Expect.equal 4
        , test "setas movem o cursor sem sair da linha" <|
            \_ ->
                Rascunho.vazio
                    |> Rascunho.recuar
                    |> Rascunho.avancar
                    |> Rascunho.avancar
                    |> Rascunho.cursor
                    |> Expect.equal 2
        ]
