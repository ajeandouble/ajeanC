from pytest import raises
from interpreter.tokenizer import Token, TokenTypes as TT


def test_token_instanciation():
    Token(TT.EOF)


def test_token_types():
    with raises(TypeError):
        s = 42
        assert Token(s)._type

    with raises(TypeError):
        s = ""
        assert Token(s)._type

    with raises(TypeError):
        s = "WRONG_TYPE"
        assert Token(s)._type

    with raises(ValueError):
        Token(TT.EOF, 42)

    with raises(ValueError):
        Token(TT.EOL, 42)

    with raises(ValueError):
        Token(TT.PROGRAM, 42)

    with raises(ValueError):
        Token(TT.FUNCTION, 42)

    with raises(ValueError):
        Token(TT.FUNCTION_CALL, 42)

    with raises(ValueError):
        Token(TT.RETURN, 42)

    with raises(ValueError):
        Token(TT.LBRACE, 42)

    with raises(ValueError):
        Token(TT.RBRACE, 42)

    with raises(ValueError):
        Token(TT.COMMA, 42)

    with raises(ValueError):
        Token(TT.IF, 42)

    with raises(ValueError):
        Token(TT.ELSE, 42)

    with raises(ValueError):
        Token(TT.INTEGER)
    with raises(TypeError):
        Token(TT.INTEGER, "42")

    with raises(ValueError):
        Token(TT.STRING)
    with raises(TypeError):
        Token(TT.STRING, 42)

    with raises(ValueError):
        Token(TT.PLUS, 42)

    with raises(ValueError):
        Token(TT.MINUS, 42)

    with raises(ValueError):
        Token(TT.MUL, 42)

    with raises(ValueError):
        Token(TT.DIV, 42)

    with raises(ValueError):
        Token(TT.EQ, 42)

    with raises(ValueError):
        Token(TT.LT, 42)

    with raises(ValueError):
        Token(TT.LE, 42)

    with raises(ValueError):
        Token(TT.GT, 42)

    with raises(ValueError):
        Token(TT.GE, 42)

    with raises(ValueError):
        Token(TT.LPAREN, 42)

    with raises(ValueError):
        Token(TT.RPAREN, 42)

    with raises(ValueError):
        Token(TT.SEMI, 42)

    with raises(ValueError):
        Token(TT.ASSIGN, 42)

    with raises(ValueError):
        Token(TT.ID)
    with raises(TypeError):
        Token(TT.ID, "42name")
    with raises(TypeError):
        Token(TT.ID, 42)


def test_token_types_enum():
    """
    Verify that TokenTypes types variables have the same name as their values
    """
    TokenTypes_dict = {type.name: type.value for type in TT}
    for name, val in TokenTypes_dict.items():
        assert name == val[0]
        assert type(val[1]) == bool
