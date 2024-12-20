
# # Legacy expression parser. FIXME: Achtung! Dead code!

# class Parser():
#     def __init__(self, tokens: List[Tok]): # type: ignore
#         self._tokens = tokens
#         self._tok_idx = 0

#     @property
#     def curr_token(self):
#         return self._tokens[self._tok_idx]

#     def eat(self, type: TT) -> None:
#         if self.curr_token.type != type:
#             raise ParserError("parsing was stopped due to invalid token")
#         else:
#             self._tok_idx += 1

#     def factor(self) -> Union[float, int]:
#         curr_token = self._tokens[self._tok_idx]
#         if curr_token.type == TT.INTEGER:
#             self.eat(TT.INTEGER)
#             return curr_token.value
#         elif curr_token.type == TT.LPAREN:
#             self.eat(TT.LPAREN)
#             result = self.expr()
#             self.eat(TT.RPAREN)
#             return result
#         else:
#             raise ParserError("parsing was stopped due to invalid token")

#         raise ParserError("parsing was stopped due to invalid token")

#     def term(self) -> Union[float, int]:
#         result = self.factor()

#         while self.curr_token.type in (TT.MUL, TT.DIV):
#             if self.curr_token.type == TT.MUL:
#                 self.eat(TT.MUL)
#                 result *= self.factor()
#             elif self.curr_token.type == TT.DIV:
#                 self.eat(TT.DIV)
#                 result /= self.factor()
#         return result

#     def expr(self) -> Union[float, int]:
#         result = self.term()
#         while self.curr_token.type in (TT.PLUS, TT.MINUS):
#             if self.curr_token.type == TT.PLUS:
#                 self.eat(TT.PLUS)
#                 result += self.term()
#             elif self.curr_token.type == TT.MINUS:
#                 self.eat(TT.MINUS)
#                 result -= self.term()
#         return result


# def test_parser_expr():
#     lexer = Lexer("42")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 42

#     lexer = Lexer("42+3")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 45

#     lexer = Lexer("42+3-5")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 40

#     lexer = Lexer("42+3-5*2+7")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 42

#     lexer = Lexer("3*7*2")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 42


# def test_parser_expr_nested():
#     lexer = Lexer("(3*7*2)*3-84")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 42

#     lexer = Lexer("(3*7*2)*3/3")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     assert parser.expr() == 42


# def test_parser_expr_bad():
#     lexer = Lexer("42+3-")
#     Toks = lexer.get_tokens()
#     parser = Parser(Toks)
#     try:
#         parser.expr()
#     except Exception as e:
#         assert isinstance(e, ParserError)
