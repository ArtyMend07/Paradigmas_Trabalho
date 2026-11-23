module Teclado exposing (Tecla(..), teclaFisica, viewTeclado)

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, type_)
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
    let
        letras =
            String.toList >> List.map (viewLetra aoApertar jogo)
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


viewLetra : (Tecla -> msg) -> Jogo -> Char -> Html msg
viewLetra aoApertar jogo letra =
    button
        [ type_ "button"
        , class (classesDaTecla (Termo.corDoTeclado jogo letra))
        , onClick (aoApertar (Letra letra))
        ]
        [ text (String.fromChar (Char.toUpper letra)) ]


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
