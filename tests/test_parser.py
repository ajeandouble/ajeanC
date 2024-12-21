from pytest import raises
from interpreter.lexer import Lexer
from interpreter.tokenizer import Token as Token, TokenTypes as TT
from interpreter.parser import ASTParser
from interpreter.ast import Function, BinOp, Num, Assign, Var, UnaryOp
from interpreter.exceptions import ParserError


def test__peek():
    input = "42"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    with raises(IndexError):
        ASTParser(tokens)._peek(0)


def test_factor():
    input = "42"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.factor()
    assert node == Num(Token(TT.INTEGER, 42))

    input = "(42)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.factor()
    assert node == Num(Token(TT.INTEGER, 42))

    input = "(-42)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.factor()
    assert node == UnaryOp(Token(TT.MINUS), Num(Token(TT.INTEGER, 42)))

    input = "(--42)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.factor()
    assert node == UnaryOp(
        Token(TT.MINUS), UnaryOp(Token(TT.MINUS), Num(Token(TT.INTEGER, 42)))
    )

    input = "(--a)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.factor()
    assert node == UnaryOp(
        Token(TT.MINUS), UnaryOp(Token(TT.MINUS), Var(Token(TT.ID, "a")))
    )


def test_term():
    input = "(--a)*42"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.term()
    assert node == BinOp(
        Token(TT.MUL),
        UnaryOp(Token(TT.MINUS), UnaryOp(Token(TT.MINUS), Var(Token(TT.ID, "a")))),
        Num(Token(TT.INTEGER, 42)),
    )


def test_expr():
    input = "39+3"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.expr()
    assert node == BinOp(
        Token(TT.PLUS), Num(Token(TT.INTEGER, 39)), Num(Token(TT.INTEGER, 3))
    )

    input = "2*7+3"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.expr()
    assert node == BinOp(
        Token(TT.PLUS),
        BinOp(Token(TT.MUL), Num(Token(TT.INTEGER, 2)), Num(Token(TT.INTEGER, 7))),
        Num(Token(TT.INTEGER, 3)),
    )
    input = "--42+3"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.expr()
    assert node == BinOp(
        Token(TT.PLUS, None),
        UnaryOp(
            Token(TT.MINUS, None),
            UnaryOp(Token(TT.MINUS, None), Num(Token(TT.INTEGER, 42))),
        ),
        Num(Token(TT.INTEGER, 3)),
    )

    input = "((((--42)))+3)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.expr()
    assert node == BinOp(
        Token(TT.PLUS, None),
        UnaryOp(
            Token(TT.MINUS, None),
            UnaryOp(Token(TT.MINUS, None), Num(Token(TT.INTEGER, 42))),
        ),
        Num(Token(TT.INTEGER, 3)),
    )


def test_assignment_statement():
    input = "a = (42+3)"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.assignment_statement()
    assert node == Assign(
        Token(TT.ASSIGN),
        Var(Token(TT.ID, "a")),
        BinOp(Token(TT.PLUS), Num(Token(TT.INTEGER, 42)), Num(Token(TT.INTEGER, 3))),
    )


def test_statement():
    input = "a = + 2;"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.statement()

    input = "a = + 2"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    with raises(ParserError) as e:
        node = parser.statement()


def test_function():
    input = "\t\nfunction\nmain\n(a,b,c){}"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.function()
    assert node == Function(
        Token(TT.ID, "main"),
        [Var(Token(TT.ID, "a")), Var(Token(TT.ID, "b")), Var(Token(TT.ID, "c"))],
        [],
    )

    input = """
        function
        main
        (a,b,c)
        {
            a
            =
            2
            ;
        }
    """

    input = """
        main function
        (a,b,c)  { a = 2; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    with raises(ParserError):
        node = parser.function()


def test_program():
    input = "\t\nfunction\nmain\n(a,b,c){}"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.function()

    input = """
        function main(a,b,c) { a = 2; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.program()

    input = """
        a = 2; b = 3; c = 3 * 2;

        function main(a,b,c) {a = 2; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.program()

    input = """
        function main(a,b,c) {
            f(1);
        }
        function f(arg) {
            return 42;
        }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.program()


def test_string():
    input = """a(a, b, c); function main(test == 32;;;)"""
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.program()


def test_string():
    input = """
    function main() {
        var = "abczd";
    }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    node = parser.program()


def test_standalone_expressions():
    input = "1+1;;;;;;;;;;;;a;"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    print(tokens)
    parser = ASTParser(tokens)
    node = parser.global_statements_lists()

    input = "1;2;3("
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    print(tokens)
    parser = ASTParser(tokens)
    with raises(ParserError):
        node = parser.global_statements_lists()


def test_conditions():
    input = "if (42) { a = 42; } else {  a = 42; b = 36 + a; if (42) { } }"
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    print(tokens)
    parser = ASTParser(tokens)
    node = parser.statement()
