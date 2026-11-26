module Rascunho exposing
    ( Rascunho
    , apagar
    , avancar
    , casas
    , cursor
    , digitar
    , palavra
    , posicionar
    , recuar
    , vazio
    )

{-| Linha em edição com cursor (#18). Clicar numa casa só move o cursor; as
letras digitadas preenchem a partir dali. O tipo é opaco para garantir que a
linha tenha sempre `Termo.tamanhoPalavra` casas e o cursor fique entre 0 e o
tamanho (o tamanho indica que a linha foi preenchida até o fim).
-}

import Termo


type Rascunho
    = Rascunho { casas : List (Maybe Char), cursor : Int }


vazio : Rascunho
vazio =
    Rascunho { casas = List.repeat Termo.tamanhoPalavra Nothing, cursor = 0 }


casas : Rascunho -> List (Maybe Char)
casas (Rascunho r) =
    r.casas


cursor : Rascunho -> Int
cursor (Rascunho r) =
    r.cursor


digitar : Char -> Rascunho -> Rascunho
digitar letra (Rascunho r) =
    if r.cursor >= Termo.tamanhoPalavra then
        Rascunho r

    else
        Rascunho { casas = trocarEm r.cursor (Just letra) r.casas, cursor = r.cursor + 1 }


{-| Apaga a casa do cursor. Se ela já estiver vazia, volta uma casa e apaga
aquela, como no Backspace de um campo de texto.
-}
apagar : Rascunho -> Rascunho
apagar (Rascunho r) =
    if casaEm r.cursor r.casas /= Nothing then
        Rascunho { r | casas = trocarEm r.cursor Nothing r.casas }

    else if r.cursor > 0 then
        Rascunho { casas = trocarEm (r.cursor - 1) Nothing r.casas, cursor = r.cursor - 1 }

    else
        Rascunho r


posicionar : Int -> Rascunho -> Rascunho
posicionar posicao (Rascunho r) =
    Rascunho { r | cursor = clamp 0 (Termo.tamanhoPalavra - 1) posicao }


avancar : Rascunho -> Rascunho
avancar (Rascunho r) =
    Rascunho { r | cursor = min Termo.tamanhoPalavra (r.cursor + 1) }


recuar : Rascunho -> Rascunho
recuar (Rascunho r) =
    Rascunho { r | cursor = max 0 (r.cursor - 1) }


{-| A palavra só existe quando todas as casas estão preenchidas.
-}
palavra : Rascunho -> Maybe String
palavra (Rascunho r) =
    List.foldr (Maybe.map2 (::)) (Just []) r.casas
        |> Maybe.map String.fromList


casaEm : Int -> List (Maybe Char) -> Maybe Char
casaEm posicao lista =
    List.drop posicao lista
        |> List.head
        |> Maybe.andThen identity


trocarEm : Int -> a -> List a -> List a
trocarEm posicao novo =
    List.indexedMap
        (\i atual ->
            if i == posicao then
                novo

            else
                atual
        )
