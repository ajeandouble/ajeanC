# THE ISSUE COMES FROM GLOBALS
from typing import List, Union, Optional
from interpreter.lexer import Lexer
from interpreter.tokenizer import Token as Token, TokenTypes as TT
from interpreter.exceptions import ParserError
from interpreter.ast import (
    AST,
    FunctionCall,
    Program,
    BinOp,
    UnaryOp,
    Num,
    Var,
    Assign,
    Function,
    NoOp,
    String,
    ReturnVal,
    IfCondition,
    ElseCondition,
)


class ASTParser:
    def __init__(self, tokens: List[Token]):
        self._tokens = tokens
        self._tok_idx = 0
        self._unary_multiplier = 1

    @property
    def current_token(self):
        return self._tokens[self._tok_idx]

    def _peek(self, offset=1) -> AST:
        if offset < 1:
            raise IndexError(
                f"{ASTParser.__name__}.{ASTParser._peek.__name__}() can only peek forward"
            )
        if self._tok_idx + offset >= len(self._tokens):
            return None
        return self._tokens[self._tok_idx + offset]

    def _eat(self, type: TT, skip_eols=False) -> None:
        import inspect

        print(
            f"\t{self._eat.__name__} from {inspect.stack()[1][3]}: {self.current_token} [{self._tok_idx}]"
        )
        if self.current_token.type != type:
            raise ParserError(
                f"trying to eat token type of {type}. Current token type is {self.current_token}"
            )
        else:
            self._tok_idx += 1
        if skip_eols:
            self._skip_eols()

    def _skip_eols(self):
        while self.current_token.type == TT.EOL:
            self._eat(TT.EOL)

    def return_value(self) -> AST:
        self._skip_eols()
        self._eat(TT.RETURN)
        self._skip_eols()
        return ReturnVal(self.expr())

    def factor(self) -> AST:
        print(f"{self.factor.__name__}:\t\t{self.current_token} [{self._tok_idx}]")

        self._skip_eols()
        curr_token = self.current_token
        print(self.current_token)
        if curr_token.type == TT.LPAREN:
            self._eat(TT.LPAREN)
            node = self.expr()
            self._eat(TT.RPAREN)
            return node
        elif curr_token.type == TT.PLUS:
            self._eat(TT.PLUS)
            node = UnaryOp(curr_token, self.factor())
            return node
        elif curr_token.type == TT.MINUS:
            self._eat(TT.MINUS)
            node = UnaryOp(curr_token, self.factor())
            return node
        elif curr_token.type == TT.INTEGER:
            self._eat(TT.INTEGER)
            return Num(Token(TT.INTEGER, curr_token.value * self._unary_multiplier))
        elif curr_token.type == TT.STRING:
            self._eat(TT.STRING)
            return String(curr_token)
        elif curr_token.type == TT.ID:
            self._skip_eols()
            if self._peek().type == TT.LPAREN:
                return self.function_call()
            else:
                return self.variable()

        self._skip_eols()
        raise ParserError(f"parsing was stopped due to invalid token {curr_token.type}")

    def term(self) -> AST:
        print(f"{self.term.__name__}:\t\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()
        node = self.factor()
        while self.current_token.type in (TT.MUL, TT.DIV):
            saved_token = self.current_token
            if self.current_token.type == TT.MUL:
                self._eat(TT.MUL)
                node = BinOp(saved_token, node, self.factor())
            elif self.current_token.type == TT.DIV:
                self._eat(TT.DIV)
                node = BinOp(saved_token, node, self.factor())
        self._skip_eols()
        return node

    def arithmetic(self) -> AST:
        print(f"{self.arithmetic.__name__}:\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()
        node = self.term()
        while self.current_token.type in (TT.PLUS, TT.MINUS):
            saved_token = self.current_token
            if self.current_token.type in (TT.PLUS, TT.MINUS):
                self._eat(self.current_token.type, skip_eols=True)
            node = BinOp(saved_token, node, self.term())
        self._skip_eols()
        return node

    def expr(self) -> AST:
        print(f"{self.expr.__name__}:\t\t{self.current_token} [{self._tok_idx}]")

        self._skip_eols()
        node = self.arithmetic()
        while self.current_token.type in (TT.LT, TT.LE, TT.EQ, TT.GE, TT.GT):
            saved_token = self.current_token
            self._eat(self.current_token.type, skip_eols=True)
            node = BinOp(saved_token, node, self.arithmetic())
        self._skip_eols()
        return node

    def variable(self):
        self._skip_eols()
        node = Var(self.current_token)
        self._eat(TT.ID)
        self._skip_eols()
        return node

    def assignment_statement(self):
        self._skip_eols()
        left = self.variable()
        token = self.current_token
        self._eat(TT.ASSIGN)
        right = self.expr()
        self._skip_eols()
        return Assign(token, left, right)

    def call_args(self):
        print(f"{self.call_args.__name__}:\t{self.current_token} [{self._tok_idx}]")
        args = []
        while self.current_token.type in (TT.ID, TT.INTEGER):
            if self.current_token.type == TT.ID:
                args.append(Var(self.current_token))
            elif self.current_token.type == TT.INTEGER:
                args.append(Num(self.current_token))
            self._eat(self.current_token.type)
            self._skip_eols()
            if self.current_token.type == TT.RPAREN:
                break
            self._eat(TT.COMMA)
        return args

    def function_call(self) -> FunctionCall:
        print(f"{self.function_call.__name__}:\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()
        token = self.current_token
        self._eat(TT.ID, skip_eols=True)
        self._skip_eols()
        args = []
        self._eat(TT.LPAREN, skip_eols=True)
        args = self.call_args()
        self._eat(TT.RPAREN, skip_eols=True)
        return FunctionCall(token, args)

    def statement(self) -> AST | NoOp:
        print(f"{self.statement.__name__}:\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()
        # stand-alone expressions e.g. `2 + 2;`, `;` or `my_var;`
        if self.current_token.type in (
            TT.INTEGER,
            TT.LPAREN,
            TT.PLUS,
            TT.MINUS,
        ) or (
            self.current_token.type == TT.ID
            and self._peek().type not in (TT.ASSIGN, TT.LPAREN)
        ):
            node = self.expr()
            self._eat(TT.SEMI, skip_eols=True)
        elif self.current_token.type == TT.ID:
            if self._peek().type == TT.LPAREN:
                node = self.function_call()
            elif self._peek().type == TT.ASSIGN:
                node = self.assignment_statement()
            self._eat(TT.SEMI, skip_eols=True)
        elif self.current_token.type == TT.RETURN:
            node = self.return_value()
            self._eat(TT.SEMI, skip_eols=True)
        elif self.current_token.type == TT.IF:
            node = self.if_condition()
        elif self.current_token.type == TT.SEMI:
            self._eat(TT.SEMI, skip_eols=True)
            node = NoOp()
        else:
            raise ParserError(f"Bad statement token {self.current_token.type}")
        self._skip_eols()
        return node

    def statements_list(self):
        print(
            f"stmts_lst:\t{self.current_token} [{self._tok_idx}]",
            self.current_token.type,
        )
        self._skip_eols()
        stmt_node = None
        statements_nodes = []
        while self.current_token.type != TT.RBRACE:
            stmt_node = self.statement()
            print(f"*stmt_node*:\t{stmt_node}")
            if stmt_node:
                statements_nodes.append(stmt_node)
        self._skip_eols()
        return statements_nodes

    def global_statements_lists(self):
        print(f"global_stmts_lst:\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()
        curr_node = None
        stmt_nodes = []
        while (
            self.current_token.type != TT.FUNCTION and self.current_token.type != TT.EOF
        ):
            curr_node = self.statement()
            print(f"*stmt_node*:\t{curr_node}")
            if curr_node:
                stmt_nodes.append(curr_node)
        self._skip_eols()
        return stmt_nodes

    def decl_args(self):
        args_nodes = []
        while self.current_token.type in (TT.ID, TT.INTEGER):
            args_nodes.append(Var(self.current_token))
            self._eat(self.current_token.type)
            if self.current_token.type == TT.RPAREN:
                break
            self._eat(TT.COMMA)
        return args_nodes

    def compound_statements(self):
        print(
            f"{self.compound_statements.__name__}:\t{self.current_token} [{self._tok_idx}]"
        )
        self._eat(TT.LBRACE, skip_eols=True)
        statements = self.statements_list()
        self._eat(TT.RBRACE, skip_eols=True)
        return statements

    def function(self):
        print(f"{self.function.__name__}:\t{self.current_token} [{self._tok_idx}]")
        self._skip_eols()

        self._eat(TT.FUNCTION, skip_eols=True)
        token = self.current_token
        self._eat(TT.ID, skip_eols=True)

        self._eat(TT.LPAREN, skip_eols=True)
        args_nodes = self.decl_args()
        self._eat(TT.RPAREN, skip_eols=True)

        statements = self.compound_statements()

        self._skip_eols()
        return Function(token, args_nodes, statements)

    def else_condition(self):
        self._skip_eols()
        self._eat(TT.ELSE)
        self._skip_eols()
        self._eat(TT.LBRACE)
        statements = self.statements_list()
        self._eat(TT.RBRACE)
        self._skip_eols()
        return ElseCondition(statements)

    def if_condition(self):
        self._skip_eols()
        self._eat(TT.IF, skip_eols=True)
        self._eat(TT.LPAREN, skip_eols=True)
        expr = self.expr()
        self._eat(TT.RPAREN, skip_eols=True)
        self._eat(TT.LBRACE, skip_eols=True)
        statements = self.statements_list()
        self._eat(TT.RBRACE, skip_eols=True)
        self._skip_eols()
        follow_else = None
        if self.current_token.type == TT.ELSE:
            follow_else = self.else_condition()
        return IfCondition(expr, statements, follow_else)

    def program(self):
        self._skip_eols()
        global_stmts = self.global_statements_lists()
        functions = [self.function()]
        while self.current_token.type == TT.FUNCTION:
            print("--------FUNCTION--------")
            functions.append(self.function())
            print(self.current_token.type)
        # print("\nProgram:")
        return Program(functions, global_stmts)
