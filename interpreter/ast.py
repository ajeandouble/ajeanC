from typing import Union, Type, List, Dict, Any
from abc import ABC, abstractmethod
from interpreter.tokenizer import Token, TokenTypes


# TODO: don't do shit with tokens.. no useless token.. token is only useful if it is useful
# lapalisse si c'est rugueux c'est pas lisse


class AST(object):
    def __str__(self):
        return f"AST()"

    def __repr__(self):
        return str(self)


class Num(AST):
    def __init__(self, integer: Token):
        if integer.type not in (TokenTypes.INTEGER,):
            raise TypeError(f"invalid token type {integer.type} for {Num.__name__}")
        super().__init__()
        self._token = self._integer = integer

    @property
    def integer(self):
        return self._id

    @integer.setter
    def id(self, new_integer):
        self._id = new_integer
        self._token = new_integer

    @property
    def token(self):
        return self._token

    def __str__(self):
        return f"{Num.__name__}({self.token})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if self.token != other.token:
            return False
        return True


class String(AST):
    def __init__(self, string: Token):
        if string.type != TokenTypes.STRING:
            raise TypeError(f"invalid token type {string.type} for {Num.__name__}")
        super().__init__()
        self._token = self._string = string

    @property
    def string(self):
        return self._string

    @string.setter
    def string(self, new_string):
        self._string = new_string
        self._token = new_string

    @property
    def token(self):
        return self._token

    def __str__(self):
        return f"{String.__name__}({self._string})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if self._token != other.token:
            return False
        return True


class BinOp(AST):
    def __init__(self, op: Token, left: AST, right: AST):
        if op.type not in (
            TokenTypes.PLUS,
            TokenTypes.MINUS,
            TokenTypes.MUL,
            TokenTypes.DIV,
        ):
            raise TypeError(f"invalid token type {op.type} for {BinOp.__name__}")
        # ADD += and so on
        super().__init__()
        self._token = self._op = op
        self.left, self.right = left, right

    @property
    def op(self):
        return self._op

    @op.setter
    def op(self, new_op):
        self._op = new_op
        self._token = new_op

    @property
    def token(self):
        return self._token

    # ADD SETTER AND GETTER

    def __str__(self):
        return f"{BinOp.__name__}({self._token}, {self.left}, {self.right})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if (self._token, self.left, self.right) != (
            other.token,
            other.left,
            other.right,
        ):
            return False
        return True


class UnaryOp(AST):
    def __init__(self, op: Token, expr: AST):
        if op.type not in (TokenTypes.PLUS, TokenTypes.MINUS):
            raise TypeError(f"invalid token type {op.type} for {UnaryOp.__name__}")
        super().__init__()
        self._token = self._op = op
        self.expr = expr

    @property
    def op(self):
        return self._op

    @op.setter
    def op(self, new_string):
        self._op = self._token = new_string

    @property
    def token(self):
        return self._token

    def __str__(self):
        return f"{UnaryOp.__name__}({self.token}, {self.expr})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if (self.token, self.expr) != (other.token, other.expr):
            return False
        return True


class Var(AST):
    def __init__(self, id: Token):
        if id.type not in (TokenTypes.ID,):
            raise TypeError(f"invalid token type {id.type} for {Var.__name__}")
        super().__init__()
        self._id = self._token = id

    @property
    def id(self):
        return self._id

    @id.setter
    def id(self, new_id):
        self._id = new_id
        self._token = new_id

    @property
    def token(self):
        return self._token

    @token.setter
    def token(self, new_id):
        self._id = self._token = new_id

    @property
    def value(self):
        return self._id.value

    def __str__(self):
        return f"{Var.__name__}({self._id})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if (self._id, self.value) != (other.id, other.value):
            return False
        return True


class Assign(AST):
    def __init__(self, token: Token, left: Var, right: AST):
        super().__init__()
        self.token = token
        self.left, self.right = left, right

    def __str__(self):
        return f"{Assign.__name__}({self.token}, {self.left}, {self.right})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if (self.token, self.left, self.right) != (
            other.token,
            other.left,
            other.right,
        ):
            return False
        return True


class NoOp:
    def __str__(self):
        return f"{NoOp.__name__}()"

    def __repr__(self):
        return str(self)


class Function(AST):
    def __init__(self, token: Token, args: List[Var], statements: List[AST]):
        if token.type not in (TokenTypes.ID,):
            raise
        super().__init__()
        self._id = self._token = token
        self.args: List[Var] = args or []
        self.statements: List[AST] = statements
        self.locals: Dict[str, Any] = {}

    @property
    def id(self):
        return self._id

    @id.setter
    def id(self, new_string):
        self._id = self._token = new_string

    @property
    def token(self):
        return self._token

    def __str__(self):
        return f"{Function.__name__}({self.id}, {self.args}, {[str(stmt) for stmt in self.statements] if self.statements else "None"})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if (self.token, self.args, self.statements, self.locals) != (
            other.token,
            other.args,
            other.statements,
            other.locals,
        ):
            return False
        return True


class ReturnVal(AST):
    def __init__(self, return_val: AST):
        super().__init__()
        self._return_val = self._token = return_val

    # FIXME: what is the use for those getters/setters???
    @property
    def return_val(self):
        return self._return_val

    @return_val.setter
    def return_val(self, new_return_val):
        self._return_val = new_return_val
        self._token = new_return_val

    @property
    def token(self):
        return self._token

    @token.setter
    def token(self, new_return_val):
        self._return_val = self._token = new_return_val

    def __str__(self):
        return f"{ReturnVal.__name__}({self._return_val})"

    def __repr__(self):
        return str(self)


class FunctionCall(AST):
    def __init__(self, func_id: Token, args: List[Union[Var, Num]]):
        super().__init__()
        self.func = func_id
        self.args = args

    @property
    def token(self):
        return self.func

    def __str__(self):
        # return f"{FunctionCall.__name__}({self.func}, {self.args})"
        # FIXME: __str__ error
        return f"{FunctionCall.__name__}({self.func}, {self.args})"

    def __repr__(self):
        str(self)


class Program(AST):
    def __init__(self, functions: List[Function], statements: List[AST]):
        super().__init__()
        self.functions = functions
        self.statements = statements

    def __str__(self):
        return f"{Program.__name__}({self.functions}, {[str(stmt) for stmt in self.statements] if self.statements else "None"})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        if self.main_compound != other.main_compound:
            return False
        return True


# TODO: class else if
class ElseCondition(AST):
    def __init__(self, statements: List[Var]):
        self.statements = statements

    def __str__(self):
        return f"{ElseCondition.__name__}({self.statements})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        return type(self) == type(other) and self.statements == other.statements


class IfCondition(AST):
    def __init__(
        self, expr: AST, statements: List[AST], follow_else: ElseCondition | None
    ):
        super().__init__()
        self.expr = expr
        self.statements = statements
        self.follow_else = follow_else

    def __str__(self):
        statements_str = (
            ", ".join(str(stmt) for stmt in self.statements)
            if self.statements
            else "None"
        )
        follow_else_str = str(self.follow_else) if self.follow_else else "None"
        return f"{IfCondition.__name__}({self.expr}, [{statements_str}], {follow_else_str})"

    def __repr__(self):
        return str(self)

    def __eq__(self, other):
        return type(self) == type(other) and (
            self.expr,
            self.statements,
            self.follow_else,
        ) == (other.expr, other.statements, other.follow_else)
