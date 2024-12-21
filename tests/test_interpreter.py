from pytest import raises
from interpreter.lexer import Lexer
from interpreter.parser import ASTParser
from interpreter.interpreter import ASTVisitor
from interpreter.exceptions import InterpreterError


def test_visitAST():
    input = """
        a = 3; z = 42;
        function main() { a = 42; b = a + 10; c = z + 42; z = 30; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    # print(program_node)
    visitor = ASTVisitor(program_node)
    visitor.visit_program()


def test_function_call():
    input = """
        function g(a, b) { print(a, b, 4); }
        function f(a, b, c) { print(a, b, c, 4); g(a, 42); }
        function main() { a = 3; f(1, a, a); a = 2 * a; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    # print(program_node)
    visitor = ASTVisitor(program_node)
    visitor.visit_program()


def test_global_function_call():
    input = """
        f();
        function f(a, b, c) { }
        function main() { f(); }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    with raises(InterpreterError):
        visitor.visit_program()


def test_no_main_func():
    input = """
        function maiz() { a = 2; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    with raises(InterpreterError):
        visitor.visit_program()

    input = """
        function main(a,b,c) { a = 2; }
        function f(a,b) { }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    node = visitor.visit_program()


def test_string():
    input = """
        function main(a,b,c) { a = 2; }
        function main(a,b,c) { a = 2; }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    with raises(InterpreterError):
        node = visitor.visit_program()


def test_string():
    input = """
        function f() { return 42; }
        function g() {
            print(42);
            ret = f();
            return f() + 100;
            print(43);
        }
        function main(a,b,c) {
            a = g();
            print(1000000, a, 100000);
        }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    node = visitor.visit_program()


def test_string():
    input = """
        function f() { return "abcd"; }
        function g() {
            print(42);
            ret = f();
            return f() + "z";
            print(43);
        }
        function main(a,b,c) {
            var = "abcd";
            a = g();
            print(1000000, a, 100000, var);
        }
    """
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program_node = parser.program()
    visitor = ASTVisitor(program_node)
    node = visitor.visit_program()
