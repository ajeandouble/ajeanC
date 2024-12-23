from typing import Union, Optional, List
from enum import Enum, auto
from interpreter.tokenizer import Token, TokenTypes
from interpreter.exceptions import UnknownSymbolError


res_keywords_toks = {
    "func": Token(TokenTypes.FUNCTION),
    "function": Token(TokenTypes.FUNCTION),
    "return": Token(TokenTypes.RETURN),
    "if": Token(TokenTypes.IF),
    "else": Token(TokenTypes.ELSE),
}

whitespaces_no_nl_toks = (
    " ",
    "\t",
    "\r",
    "\f",
    "\v",
)

kw_with_trailing_ws = ("function", "return")
kw_with_trailing_lparen = ("if", "return")

single_chr_toks = {
    "+": Token(TokenTypes.PLUS),
    "-": Token(TokenTypes.MINUS),
    "*": Token(TokenTypes.MUL),
    "/": Token(TokenTypes.DIV),
    "=": Token(TokenTypes.ASSIGN),
    "<": Token(TokenTypes.LT),
    ">": Token(TokenTypes.GT),
    "(": Token(TokenTypes.LPAREN),
    ")": Token(TokenTypes.RPAREN),
    "{": Token(TokenTypes.LBRACE),
    "}": Token(TokenTypes.RBRACE),
    ",": Token(TokenTypes.COMMA),
    ";": Token(TokenTypes.SEMI),
    "\n": Token(TokenTypes.EOL),
    "[": Token(TokenTypes.LBRACK),
    "]": Token(TokenTypes.RBRACK),
}

mult_chr_toks = {
    "==": Token(TokenTypes.EQ),
    "<=": Token(TokenTypes.LE),
    ">=": Token(TokenTypes.GE),
}


class Lexer:
    def __init__(self, input: str = ""):
        self._buffer = input
        self._pos = 0

    @property
    def buffer(self):
        return self._buffer

    @property
    def pos(self):
        return self._pos

    @property
    def current_char(self) -> Optional[str]:
        if self._pos >= len(self._buffer):
            return None
        return self._buffer[self._pos]

    def _advance(self, offset=1) -> None:
        if offset < 0:
            raise IndexError(f"{self._advance.__name__} can only advance forward")
        pos = self._pos
        if pos + offset > len(self._buffer):
            raise IndexError("Index out of range")
        self._pos += offset

    def _peek(self, offset=1) -> Optional[str]:
        if offset < 0:
            raise IndexError(f"{self._peek.__name__}can only peek forward")
        pos = self._pos
        if pos + offset >= len(self._buffer):
            return None
        return self._buffer[pos + offset]

    def _look_ahead(self, offset=1) -> Optional[str]:
        if offset < 0:
            raise IndexError(f"{self._look_ahead.__name__}can only peek forward")
        pos = self._pos
        if pos + offset > len(self._buffer):
            return None
        return self._buffer[pos : pos + offset]

    def _is_eof(self) -> Optional[Token]:
        if not self._buffer:
            return Token(TokenTypes.EOF)
        if self._pos >= len(self._buffer):
            return Token(TokenTypes.EOF)
        return None

    def _num(self) -> Optional[Token]:
        s = ""
        curr_char = self.current_char
        while curr_char and curr_char.isdigit():
            s += curr_char
            self._advance()
            curr_char = self.current_char
        return Token(TokenTypes.INTEGER, int(s))

    def _id(self) -> Optional[Token]:
        s = ""
        curr_char = self.current_char
        while curr_char and curr_char.isalnum():
            s += curr_char
            self._advance()
            curr_char = self.current_char
        return Token(TokenTypes.ID, s)

    def _string(self):
        self._advance()
        s = ""
        while self.current_char and self.current_char != '"':
            s += self.current_char
            self._advance()
        self._advance()
        return Token(TokenTypes.STRING, s)

    def _get_next_token(self) -> Optional[Token]:
        eof = self._is_eof()
        if eof:
            return eof

        buffer, pos = self._buffer, self._pos
        curr_char = self.current_char
        for tok in res_keywords_toks:
            if self._look_ahead(len(tok)) == tok:
                # TODO: check if it's robust enough
                following_chr = self._peek(len(tok))
                if following_chr and following_chr.isalnum():
                    continue
                # if tok in kw_with_trailing_lparen and self._peek(len(tok)) not in whitespaces_no_nl_toks
                not_res_kw = False
                # print(tok)
                # NOTE: WTF?
                # for tok2 in res_keywords_toks:
                #     if tok == tok2:
                #         continue
                #     if self._look_ahead(len(tok) + len(tok2)) == tok + tok2:
                #         not_res_kw = True
                # if not_res_kw:
                #     break
                self._advance(len(tok))
                return res_keywords_toks[tok]

        for tok in mult_chr_toks:
            if self._look_ahead(len(tok)) == tok:
                self._advance(len(tok))
                return mult_chr_toks[tok]

        if curr_char == '"':
            return self._string()

        elif curr_char in single_chr_toks.keys():
            self._advance()
            return single_chr_toks[curr_char]

        elif curr_char and curr_char.isdigit():
            return self._num()

        elif curr_char and curr_char.isalnum():
            return self._id()

        else:
            raise UnknownSymbolError({buffer[pos:].split()[0]})

        return None

    def _skip_spaces(self) -> None:
        input_len = len(self._buffer)
        while (
            self._pos < input_len and self._buffer[self._pos] in whitespaces_no_nl_toks
        ):
            self._pos += 1

    def get_tokens(self) -> List[Token]:
        tokens = []
        self._skip_spaces()
        curr_token = self._get_next_token()
        while curr_token and curr_token._type != TokenTypes.EOF:
            self._skip_spaces()
            tokens.append(curr_token)
            curr_token = self._get_next_token()
        tokens.append(Token(TokenTypes.EOF))
        return tokens
