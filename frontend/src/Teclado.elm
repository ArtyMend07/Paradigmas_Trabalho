module Teclado exposing (Tecla(..), teclaFisica, viewTeclado, viewTecladoCom)

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)
import Termo exposing (Cor(..), Jogo)


type Tecla
    = Letra Char
    | Enter
    | Apagar


teclaFisica : String -> Maybe Tecla
teclaFisica chave =
    case chave of
        "Enter" ->
            Just Enter

        "Backspace" ->
            Just Apagar

        _ ->
            case String.toList (String.toLower chave) of
                [ letra ] ->
                    if Termo.ehLetra letra then
                        Just (Letra letra)

                    else
                        Nothing

                _ ->
                    Nothing


viewTeclado : (Tecla -> msg) -> Jogo -> Html msg
viewTeclado aoApertar jogo =
    viewTecladoCom aoApertar (Termo.corDoTeclado jogo) (always True)


{-| Teclado com a cor de cada letra e quais letras aparecem decididas por fora.
O modo caos usa para apagar cores e esconder teclas.
-}
viewTecladoCom : (Tecla -> msg) -> (Char -> Maybe Cor) -> (Char -> Bool) -> Html msg
viewTecladoCom aoApertar corDaLetra aparece =
    let
        letras =
            String.toList >> List.map (\letra -> viewLetra aoApertar (corDaLetra letra) (aparece letra) letra)
    in
    div [ class "teclado" ]
        [ viewLinha (letras "qwertyuiop")
        , viewLinha (letras "asdfghjkl")
        , viewLinha
            (viewEspecial aoApertar Enter "Enter" "Confirmar palpite"
                :: letras "zxcvbnm"
                ++ [ viewEspecial aoApertar Apagar "⌫" "Apagar letra" ]
            )
        ]


viewLinha : List (Html msg) -> Html msg
viewLinha teclas =
    div [ class "teclado-linha" ] teclas


viewLetra : (Tecla -> msg) -> Maybe Cor -> Bool -> Char -> Html msg
viewLetra aoApertar cor aparece letra =
    if aparece then
        button
            [ type_ "button"
            , class (classesDaTecla cor)
            , onClick (aoApertar (Letra letra))
            ]
            [ text (String.fromChar (Char.toUpper letra)) ]

    else
        button
            [ type_ "button"
            , class "tecla tecla--sumida"
            , disabled True
            , attribute "aria-hidden" "true"
            ]
            []


viewEspecial : (Tecla -> msg) -> Tecla -> String -> String -> Html msg
viewEspecial aoApertar tecla rotulo descricao =
    button
        [ type_ "button"
        , class "tecla tecla--larga"
        , attribute "aria-label" descricao
        , onClick (aoApertar tecla)
        ]
        [ text rotulo ]


classesDaTecla : Maybe Cor -> String
classesDaTecla cor =
    case cor of
        Nothing ->
            "tecla"

        Just Verde ->
            "tecla tecla--verde"

        Just Amarelo ->
            "tecla tecla--amarela"

        Just Cinza ->
            "tecla tecla--cinza"
