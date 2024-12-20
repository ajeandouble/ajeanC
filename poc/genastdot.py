###############################################################################
#  AST visualizer - generates a DOT file for Graphviz.                        #
#                                                                             #
#  To generate an image from the DOT file run $ dot -Tpng -o ast.png ast.dot  #
#                                                                             #
###############################################################################
import argparse
import textwrap
import sys
from pathlib import Path  # if you haven't already done so
from typing import List, Dict

file = Path(__file__).resolve()
parent, root = file.parent, file.parents[1]
sys.path.append(str(root))

# Additionally remove the current file's directory from sys.path
try:
    sys.path.remove(str(parent))
except ValueError:  # Already removed
    pass

from interpreter.lexer import Lexer, single_chr_toks
from interpreter.tokenizer import Token as Token
from interpreter.parser import ASTParser
from interpreter.ast import *


class ASTVisualizer:
    def __init__(self, root_node: AST):
        self.root_node = root_node
        self.ncount = 1
        self.dot_header = [
            textwrap.dedent(
                """\
        digraph astgraph {
          node [shape=circle, fontsize=12, fontname="Courier", height=.1];
          ranksep=.3;
          edge [arrowsize=.5]

        """
            )
        ]

        self.d: Dict[int, int] = {}
        self.dot_body: List[str] = []
        self.dot_footer = ["}"]

    def visitAST(self, node: AST):
        if isinstance(node, BinOp):
            label = list(single_chr_toks.keys())[
                list(single_chr_toks.values()).index(Token(node._token.type))
            ]
            s = '  node{} [label="{}"]\n'.format(self.ncount, label)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            self.visitAST(node.left)
            self.visitAST(node.right)

            for child_node in (node.left, node.right):
                s = "  node{} -> node{}\n".format(
                    self.d[id(node)], self.d[id(child_node)]
                )
                self.dot_body.append(s)

        elif isinstance(node, Num):
            s = '  node{} [label="{}"]\n'.format(self.ncount, node.token.value)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

        elif isinstance(node, String):
            s = "  node{} [label=\"'{}'\"]\n".format(self.ncount, node.token.value)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

        elif isinstance(node, UnaryOp):
            s = '  node{} [label="unary {}"]\n'.format(self.ncount, node.token.value)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            self.visitAST(node.expr)
            s = "  node{} -> node{}\n".format(self.d[id(node)], self.d[id(node.expr)])
            self.dot_body.append(s)

        elif isinstance(node, Function):
            s = '  node{} [label="Function {}\nargs= {}"]\n'.format(
                self.ncount, node.id.value, [arg.value for arg in node.args]
            )
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            for stmt in node.statements:
                self.visitAST(stmt)
                print(stmt, type(stmt))
                s = "  node{} -> node{}\n".format(self.d[id(node)], self.d[id(stmt)])
                self.dot_body.append(s)

        elif isinstance(node, FunctionCall):
            s = '  node{} [label="{}"]\n'.format(
                self.ncount, f"Call: {node.func.value}"
            )
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            for arg in node.args:
                self.visitAST(arg)
                s = "  node{} -> node{}\n".format(self.d[id(node)], self.d[id(arg)])
                self.dot_body.append(s)

        elif isinstance(node, ReturnVal):
            s = '  node{} [label="{}"]\n'.format(self.ncount, "Return")
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            self.visitAST(node.return_val)
            s = "  node{} -> node{}\n".format(
                self.d[id(node)], self.d[id(node.return_val)]
            )
            self.dot_body.append(s)

        elif isinstance(node, Program):
            s = '  node{} [label="{}"]\n'.format(self.ncount, "Program")
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            for function in node.functions:
                self.visitAST(function)
                s = "  node{} -> node{}\n".format(
                    self.d[id(node)], self.d[id(function)]
                )
                self.dot_body.append(s)

            for statement in node.statements:
                self.visitAST(statement)
                s = "  node{} -> node{}\n".format(
                    self.d[id(node)], self.d[id(statement)]
                )
                self.dot_body.append(s)

        elif isinstance(node, Assign):
            s = '  node{} [label="="]\n'.format(self.ncount)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

            self.visitAST(node.left)
            self.visitAST(node.right)

            for child_node in (node.left, node.right):
                s = "  node{} -> node{}\n".format(
                    self.d[id(node)], self.d[id(child_node)]
                )
                self.dot_body.append(s)

        elif isinstance(node, Var):
            s = '  node{} [label="{}"]\n'.format(self.ncount, node.value)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

        elif isinstance(node, NoOp):
            s = '  node{} [label="NoOp"]\n'.format(self.ncount)
            self.dot_body.append(s)
            self.d[id(node)] = self.ncount
            self.ncount += 1

    def gendot(self):
        self.visitAST(self.root_node)
        return "".join(self.dot_header + self.dot_body + self.dot_footer)


def main():
    argparser = argparse.ArgumentParser(description="Generate an AST DOT file.")
    argparser.add_argument("text")
    args = argparser.parse_args()
    text = args.text

    lexer = Lexer(text)
    tokens = lexer.get_tokens()
    parser = ASTParser(tokens)
    program = parser.program()
    viz = ASTVisualizer(program)
    content = viz.gendot()
    print(content)


if __name__ == "__main__":
    main()
