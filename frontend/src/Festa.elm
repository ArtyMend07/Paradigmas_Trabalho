module Festa exposing (confete)

{-| Confete da vitória (#18). A posição, o atraso, o giro e a cor de cada peça
saem de multiplicações com resto, que espalham as peças sem precisar de
`Random`: a festa é igual toda vez e não passa pelo `update`.
-}

import Html exposing (Html, div, span)
import Html.Attributes exposing (attribute, class)


quantidadeDePecas : Int
quantidadeDePecas =
    48


confete : Html msg
confete =
    div [ class "festa", attribute "aria-hidden" "true" ]
        (List.map peca (List.range 1 quantidadeDePecas))


peca : Int -> Html msg
peca i =
    span
        [ class "festa-peca"
        , attribute "style"
            (String.join ";"
                [ "--x:" ++ String.fromInt (modBy 100 (i * 37)) ++ "%"
                , "--atraso:" ++ String.fromInt (modBy 9 (i * 4) * 90) ++ "ms"
                , "--giro:" ++ String.fromInt (modBy 720 (i * 131)) ++ "deg"
                , "--matiz:" ++ String.fromInt (modBy 360 (i * 47))
                , "--queda:" ++ String.fromInt (1400 + modBy 5 i * 250) ++ "ms"
                ]
            )
        ]
        []
