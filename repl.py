from interpreter.lexer import Lexer
from interpreter.parser import ASTParser
from interpreter.interpreter import ASTVisitor


class Interpreter:
    def __init__(self, tokens):
        self._tokens = tokens

    def _error(self, msg):
        raise Exception(msg)


def main():
    input = """a = 42;
    function main() {
        if (42 - 41) { return 43; }
        return 40;
    }"""
    lexer = Lexer(input)
    tokens = lexer.get_tokens()
    print(tokens)
    parser = ASTParser(tokens)
    program_node = parser.program()
    print(program_node)
    ASTVisitor(program_node).visit_Program()


if __name__ == "__main__":
    main()
