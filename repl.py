from interpreter.lexer import Lexer
from interpreter.parser import ASTParser
from interpreter.interpreter import ASTVisitor


class Interpreter:
    def __init__(self, tokens):
        self._tokens = tokens

    def _error(self, msg):
        raise Exception(msg)


def main():
    # input = """function main() { a = 42; } a = 42;"""
    input = """
    a = 42;
    function main() {
        if (42) {
            return f(1);
        }
        return 42;
    }
    function g(a, b, c) { return -42; }
    function h(a) { return 12 * a; }
    function f(a) {
        if (1) { return g(1,2,3) + 5 + h(5);} else { 42; }
        if (1) { return g(1, 2, 3) ; }
    }
    """
    input = """function main() { if (0) { 43; } else if (1 - 1 + 1) { if (1) { return -44; } } else { return 45; } }"""
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    print(tokens)
    parser = ASTParser(tokens)
    program_node = parser.program()
    print(program_node)
    print("\n")
    ret = ASTVisitor(program_node).visit_program()
    print(f"ret:\t{ret}")


if __name__ == "__main__":
    main()
