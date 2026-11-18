:- module(words, [word/1, load_words/1]).

:- dynamic word/1.

load_words(Arquivo) :-
    retractall(word(_)),
    read_file_to_string(Arquivo, Texto, [encoding(utf8)]),
    split_string(Texto, "\n", "\r ", Linhas),
    forall(( member(Linha, Linhas), Linha \== "" ),
           ( atom_string(Palavra, Linha), assertz(word(Palavra)) )).
