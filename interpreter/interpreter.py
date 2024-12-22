from typing import Union, Type, List, Any, Dict
from abc import ABC, abstractmethod
from interpreter.tokenizer import TokenTypes as TT
from interpreter.ast import (
    AST,
    Program,
    Num,
    Var,
    BinOp,
    UnaryOp,
    NoOp,
    Assign,
    Function,
    FunctionCall,
    ReturnVal,
    String,
    IfCondition,
    ElseCondition,
)
from interpreter.exceptions import InterpreterError
from copy import copy


class FunctionFrame:
    def __init__(self, func: Function):
        self.func: Function = func
        self.locals: dict = {}

    def __repr__(self):
        return f"{FunctionFrame.__name__}({self.func})"

    def __str__(self):
        return str(self)


class ASTVisitor:
    def __init__(self, program_node: Program):
        self._program: Program = program_node
        self._main_function = None
        self._globals: dict = {}
        self._call_stack: List[FunctionFrame] = []
        self._ret = None

    @property
    def globals(self):
        return self._globals

    @property
    def scope(self):
        if self._call_stack:
            return self._call_stack[-1].locals
        else:
            return self._globals

    def _resolve_var(self, var_name):
        if var_name in self.scope:
            return self.scope[var_name]

        if var_name in self._globals:
            return self._globals[var_name]

        raise InterpreterError(f"no such variable {var_name}")

    @property
    def program(self):
        return self._program

    @property
    def main_function(self):
        return self._main_function

    @property
    def global_scope(self):
        return self._globals

    def visit_string(self, node: Num):
        return node.token.value

    def visit_binop(self, node: BinOp):
        if node._op.type == TT.PLUS:
            return self.visit(node.left) + self.visit(node.right)
        elif node._op.type == TT.MINUS:
            return self.visit(node.left) - self.visit(node.right)
        elif node._op.type == TT.MUL:
            return self.visit(node.left) * self.visit(node.right)
        elif node._op.type == TT.DIV:
            return self.visit(node.left) / self.visit(node.right)

    def visit_unaryop(self, node: UnaryOp):
        op = node.token.type
        if op == TT.PLUS:
            return +self.visit(node.expr)
        elif op == TT.MINUS:
            return -self.visit(node.expr)

    def visit_var(self, node: Var):
        return self._resolve_var(node.value)

    def visit_assign(self, node: Assign):
        var_name = node.left.value
        if var_name in self._globals:
            scope = self._globals
        else:
            scope = self.scope
        scope[var_name] = self.visit(node.right)

    # def visit_statements(self, statements: List[AST]):
    #     for stmt in statements:
    #         visited_node = self.visit(stmt)
    #         if type(visited_node) == ReturnVal:
    #             _ = self._call_stack.pop()
    #             return_
    #             break

    #     _ = self._call_stack.pop()

    # FIXME: useless, could simply pass main node, handle os.exit() in caller func
    # TODO: parse stdin args
    def visit_main(self, node: Function):
        print(f"{self.visit_main.__name__}:\t\t{node}")
        self._call_stack.append(FunctionFrame(node))
        return self.visit_statements(node.statements)

    def visit_stmt(self, node: AST):
        print(f"visit_statement:\t{node}")
        if type(node) is NoOp:
            return NoOp
        elif type(node) is Function:
            return self.visit_statements(node.statements)
        elif type(node) is FunctionCall:
            return self.visit_function_call(node)
        elif type(node) is BinOp:
            return self.visit_binop(node)
        elif type(node) is UnaryOp:
            return self.visit_unaryop(node)
        elif type(node) is Assign:
            return self.visit_assign(node)
        elif type(node) is Var:
            return self.visit_var(node)
        elif type(node) is Num:
            return self.visit_string(node)
        elif type(node) is String:
            return self.visit_string(node)
        elif type(node) is ReturnVal:
            return self.visit_returnval(node)
        elif type(node) is IfCondition:
            return self.visit_if_condition(node)

    def visit_statements(self, statements: List[AST]):
        print(
            f"visit_stmts:\t{[str(stmt) for stmt in statements] if statements else "None"}"
        )
        for stmt in statements:
            visited_node = self.visit_stmt(stmt)
            if type(visited_node) == ReturnVal:
                return visited_node

    def visit_function_call(self, node: FunctionCall):
        print(f"{self.visit_function_call.__name__}:\t{node}")
        # builtins = ["print"]
        # if node.func.value in builtins:
        #     for arg in node.args:
        #         if type(arg) == Num:
        #             print(arg.token.value, end=" ")
        #         elif type(arg) == Var:
        #             print(self.scope[arg.token.value], end=" ")
        #     return

        locals: Dict[String, Any] = {}
        func_token = node.func
        callee_func = self._globals[func_token.value]
        # TODO: replace with visit expr
        # for i, callee_arg in enumerate(callee_func.args):
        #     callee_arg_name = callee_arg.value
        #     locals[callee_arg_name] = self.visit(node.args[i])
        #     pass

        self._call_stack.append(FunctionFrame(callee_func))
        self._call_stack[-1].locals = locals
        self.visit_statements(callee_func.statements)
        saved_ret = self._ret
        self._ret = None
        return saved_ret

    def visit_returnval(self, node: ReturnVal):
        print(f"{self.visit_returnval.__name__}:\t{node}")
        self._ret = self.visit_stmt(node._return_val)
        print(f"\t\t{node}")
        return node

    def visit_if_condition(self, node: IfCondition):
        print(f"{self.visit_if_condition.__name__}:\t{node}")
        result = self.visit(node.expr)
        print(f"*result*:\t\t{result}")
        if result:
            return self.visit_statements(node.statements)
        elif node.follow_else:
            return self.visit_statements(node.follow_else)

    def visit_num(self, node: Num) -> int:
        print(f"{self.visit_num.__name__}:\t{node}")
        return node.token.value

    def visit(self, node: AST) -> Any:
        print(f"len={len(self._call_stack)}")
        if type(node) is NoOp:
            return
        elif type(node) is Function:
            return self.visit_statements(node.statements)
        elif type(node) is FunctionCall:
            return self.visit_function_call(node)
        elif type(node) is BinOp:
            return self.visit_binop(node)
        elif type(node) is UnaryOp:
            return self.visit_unaryop(node)
        elif type(node) is Assign:
            return self.visit_assign(node)
        elif type(node) is Var:
            return self.visit_var(node)
        elif type(node) is Num:
            return self.visit_num(node)
        elif type(node) is String:
            return self.visit_string(node)
        elif type(node) is ReturnVal:
            return self.visit_returnval(node)
        elif type(node) is IfCondition:
            return self.visit_if_condition(node)
        # elif
        #     raise NotImplementedError("unknown token:", type(node))

    def visit_program(self):
        print(self.visit_program.__name__)
        # check if duplicate function names
        func_names = [f.id.value for f in self.program.functions]
        if len(func_names) != len(set(func_names)):
            raise InterpreterError(
                "duplicate function names"
            )  # TODO: explicit duplicates

        # check entrypoint 'main'
        main_func = list(filter(lambda x: x.id.value == "main", self.program.functions))
        if not main_func:
            raise InterpreterError("main function not found")
        self._main_function = main_func[0]

        # import os

        # print(self.program.functions)
        # os._exit(42)
        for func in self.program.functions:
            if func.id.value == "main":
                continue
            self._globals[func.id.value] = func

        # execute global code
        for stmt in self._program.statements:
            print(f"global_statement:\t{stmt}")
            if type(stmt) == NoOp:
                continue
            if type(stmt) == FunctionCall:
                print(stmt)
                raise InterpreterError("no function call allowed in global scope")
            self.visit_stmt(stmt)

        # execute main()
        self.visit_main(self._main_function)
        return self._ret
