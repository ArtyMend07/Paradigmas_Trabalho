module Caos exposing
    ( Efeito(..)
    , Evento(..)
    , Exibicao(..)
    , Linha
    , Partida
    , Situacao(..)
    , descricao
    , efeitoDeTexto
    , emAndamento
    , linhasRestantes
    , nome
    , palpitesComCores
    )

import Termo exposing (Cor, Palpite)


type Efeito
    = CorMentirosa
    | CoresInvertidas
    | SoContagem
    | TempoParado
    | Escudo
    | AlarmeFalso
    | TrocaDePalavra
    | DicaDeLetra
    | VoltarNoTempo
    | Tiroteio
    | LetrasApagadas
    | ExplosaoNoTeclado
    | LimpezaDoTeclado


type Exibicao
    = Cores (List Cor)
    | Contagem { verdes : Int, amarelas : Int }
    | Oculta


type alias Linha =
    { palavra : String
    , efeito : Maybe Efeito
    , exibicao : Exibicao
    }


type Evento
    = Instantaneo Efeito
    | LetraRevelada { letra : Char, presente : Bool }


type Situacao
    = EmAndamento
    | Venceu
    | Perdeu String


type alias Partida =
    { id : Int
    , linhas : List Linha
    , maxLinhas : Int
    , proximo : Maybe Efeito
    , evento : Maybe Evento
    , situacao : Situacao
    }


emAndamento : Partida -> Bool
emAndamento partida =
    partida.situacao == EmAndamento


linhasRestantes : Partida -> Int
linhasRestantes partida =
    partida.maxLinhas - List.length partida.linhas


{-| Só as linhas que mostram cores entram no teclado. Uma cor mentirosa também
entra, porque o jogador não sabe qual casa mentiu. Numa linha de cores
invertidas o jogador sabe da troca, então o teclado desfaz a inversão.
-}
palpitesComCores : Partida -> List Palpite
palpitesComCores partida =
    List.filterMap
        (\linha ->
            case linha.exibicao of
                Cores cores ->
                    if linha.efeito == Just CoresInvertidas then
                        Just { palavra = linha.palavra, cores = List.map desinverter cores }

                    else
                        Just { palavra = linha.palavra, cores = cores }

                _ ->
                    Nothing
        )
        partida.linhas


desinverter : Cor -> Cor
desinverter cor =
    case cor of
        Termo.Verde ->
            Termo.Cinza

        Termo.Cinza ->
            Termo.Verde

        Termo.Amarelo ->
            Termo.Amarelo


efeitoDeTexto : String -> Maybe Efeito
efeitoDeTexto texto =
    case texto of
        "cor_mentirosa" ->
            Just CorMentirosa

        "cores_invertidas" ->
            Just CoresInvertidas

        "so_contagem" ->
            Just SoContagem

        "tempo_parado" ->
            Just TempoParado

        "escudo" ->
            Just Escudo

        "alarme_falso" ->
            Just AlarmeFalso

        "troca_de_palavra" ->
            Just TrocaDePalavra

        "dica_de_letra" ->
            Just DicaDeLetra

        "voltar_no_tempo" ->
            Just VoltarNoTempo

        "tiroteio" ->
            Just Tiroteio

        "letras_apagadas" ->
            Just LetrasApagadas

        "explosao_no_teclado" ->
            Just ExplosaoNoTeclado

        "limpeza_do_teclado" ->
            Just LimpezaDoTeclado

        _ ->
            Nothing


nome : Efeito -> String
nome efeito =
    case efeito of
        CorMentirosa ->
            "Cor mentirosa"

        CoresInvertidas ->
            "Cores invertidas"

        SoContagem ->
            "Só contagem"

        TempoParado ->
            "Tempo parado"

        Escudo ->
            "Escudo"

        AlarmeFalso ->
            "Efeito terrível"

        TrocaDePalavra ->
            "Troca de palavra"

        DicaDeLetra ->
            "Dica de letra"

        VoltarNoTempo ->
            "Voltar no tempo"

        Tiroteio ->
            "Tiroteio"

        LetrasApagadas ->
            "Letras apagadas"

        ExplosaoNoTeclado ->
            "Explosão no teclado"

        LimpezaDoTeclado ->
            "Limpeza do teclado"


descricao : Efeito -> String
descricao efeito =
    case efeito of
        CorMentirosa ->
            "Uma casa do próximo palpite vai mostrar a cor errada."

        CoresInvertidas ->
            "No próximo palpite, verde e cinza trocam de significado."

        SoContagem ->
            "O próximo palpite mostra só quantas verdes e amarelas teve."

        TempoParado ->
            "As cores do próximo palpite só aparecem depois do palpite seguinte."

        Escudo ->
            "Se o próximo palpite errar, a linha é devolvida."

        AlarmeFalso ->
            "Algo vai acontecer no próximo palpite. Ou não."

        TrocaDePalavra ->
            "A palavra secreta mudou para outra que combina com todas as cores já mostradas."

        DicaDeLetra ->
            "Uma letra ainda não jogada foi revelada."

        VoltarNoTempo ->
            "O último palpite foi desfeito."

        Tiroteio ->
            "Algumas casas levaram tiro e ficam furadas até o próximo palpite."

        LetrasApagadas ->
            "As letras do último palpite sumiram por 2 palpites. As cores ficaram."

        ExplosaoNoTeclado ->
            "3 letras do teclado perderam a cor até serem jogadas de novo."

        LimpezaDoTeclado ->
            "As letras cinzas sumiram do teclado."
