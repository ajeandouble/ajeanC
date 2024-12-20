from pytest import raises
from interpreter.tokenizer import Token, TokenTypes as TT
from interpreter.lexer import Lexer
from interpreter.exceptions import UnknownSymbolError


def test_Lexer():
    input, pos = "42", 0
    lexer = Lexer(input)
    assert (lexer._buffer, lexer._pos) == (input, pos)
    assert (lexer.buffer, lexer.pos) == (lexer._buffer, lexer._pos)

    assert lexer.current_char == input[0]
    lexer._pos = len(lexer._buffer) + 42
    assert lexer.current_char == None

    with raises(IndexError):
        lexer._advance(len(lexer._buffer) + 42)
    with raises(IndexError):
        lexer._advance(-1)

    assert lexer._peek(len(lexer._buffer) + 42) == None
    with raises(IndexError):
        lexer._peek(-1)

    assert lexer._look_ahead(len(lexer._buffer) + 42) == None
    with raises(IndexError):
        lexer._look_ahead(-1)


def test_get_next_token():
    input = ""
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.EOF)
    assert lexer._pos == 0

    input = "\n"
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.EOL)
    assert lexer._pos == 1

    input = "\n42"
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.EOL)
    assert lexer._pos == 1

    input = "function "
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.FUNCTION)

    input = "function{}"
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.FUNCTION)

    input = "return "
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.RETURN)

    input = "return3"
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.ID, "return3")

    input = "if"
    lexer = Lexer(input)
    print(lexer._get_next_token())
    # assert lexer._get_next_token() == Token(TT.IF, "if")

    input = "+-*/,;<<=>>===a();"
    lexer = Lexer(input)
    tokens = [lexer._get_next_token() for _ in range(0, 16)]
    assert tokens == [
        Token(TT.PLUS, None),
        Token(TT.MINUS, None),
        Token(TT.MUL, None),
        Token(TT.DIV, None),
        Token(TT.COMMA, None),
        Token(TT.SEMI, None),
        Token(TT.LT, None),
        Token(TT.LE, None),
        Token(TT.GT, None),
        Token(TT.GE, None),
        Token(TT.EQ, None),
        Token(TT.ID, "a"),
        Token(TT.LPAREN, None),
        Token(TT.RPAREN, None),
        Token(TT.SEMI, None),
        Token(TT.EOF, None),
    ]


def test_get_next_token_str():
    input = '"abcd 42"'
    lexer = Lexer(input)
    assert lexer._get_next_token() == Token(TT.STRING, "abcd 42")


def test_get_tokens():
    input = "if else function"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    assert tokens == [
        Token(TT.IF, None),
        Token(TT.ELSE, None),
        Token(TT.FUNCTION, None),
        Token(TT.EOF, None),
    ]

    input = "if else function "
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    assert tokens == [Token(TT.IF), Token(TT.ELSE), Token(TT.FUNCTION), Token(TT.EOF)]

    input = "function() main() {\na = 2; b = 2 * a; if ifi} ifi functiona"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    assert tokens == [
        Token(TT.FUNCTION),
        Token(TT.LPAREN),
        Token(TT.RPAREN),
        Token(TT.ID, "main"),
        Token(TT.LPAREN),
        Token(TT.RPAREN),
        Token(TT.LBRACE),
        Token(TT.EOL),
        Token(TT.ID, "a"),
        Token(TT.ASSIGN),
        Token(TT.INTEGER, 2),
        Token(TT.SEMI),
        Token(TT.ID, "b"),
        Token(TT.ASSIGN, None),
        Token(TT.INTEGER, 2),
        Token(TT.MUL),
        Token(TT.ID, "a"),
        Token(TT.SEMI),
        Token(TT.IF),
        Token(TT.ID, "ifi"),
        Token(TT.RBRACE),
        Token(TT.ID, "ifi"),
        Token(TT.ID, "functiona"),
        Token(TT.EOF),
    ]
