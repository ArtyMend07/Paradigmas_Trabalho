module CaosTest exposing (suite)

import Caos
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Caos"
        [ test "o código de cada efeito volta para o mesmo efeito" <|
            \_ ->
                List.map (Caos.codigo >> Caos.efeitoDeTexto) Caos.todos
                    |> Expect.equal (List.map Just Caos.todos)
        , test "efeito desconhecido não vira efeito" <|
            \_ ->
                Caos.efeitoDeTexto "chuva_de_meteoros"
                    |> Expect.equal Nothing
        ]
