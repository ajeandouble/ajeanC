from typing import Union, Optional, Any
from enum import Enum, auto


class AutoName(Enum):
    def _generate_next_value_(name, start, count, last_values):
        return name


whitespaces = (" ", "\t", "\n")


class TokenTypes(AutoName):
    """
    Token Types
    Enum of Token names and booleans indicating if there is value associated with it (non-keyword)
    """

    PROGRAM = (auto(), False)

    EOF = (auto(), False)  # TODO: add type e.g. OP - followed by zpc
    EOL = (auto(), False)

    FUNCTION = (auto(), False, whitespaces)
    FUNCTION_CALL = (auto(), False)
    RETURN = (auto(), False)
    LBRACE = (auto(), False)
    RBRACE = (auto(), False)

    COMMA = (auto(), False)

    IF = (auto(), False)
    ELSE = (auto(), False)

    INTEGER = (auto(), True)
    STRING = (auto(), True)

    PLUS = (auto(), False)
    MINUS = (auto(), False)
    MUL = (auto(), False)
    DIV = (auto(), False)

    EQ = (auto(), False)
    LT = (auto(), False)
    LE = (auto(), False)
    GT = (auto(), False)
    GE = (auto(), False)

    LPAREN = (auto(), False)
    RPAREN = (auto(), False)

    # DOT = (auto(), False)
    SEMI = (auto(), False)

    ID = (auto(), True)
    ASSIGN = (auto(), False)


class Token:
    def __init__(self, type: TokenTypes, value: Optional[Union[int, str, None]] = None):
        try:
            TokenTypes(type)
        except:
            raise TypeError(f"invalid token type: {type}")
        if type.value[1] == (value is None):
            raise ValueError(
                f"value should" + "n't"
                if type.value[1]
                else "" + f"be {None} for {type}"
            )

        if value:
            self._validate_value(type, value)

        self._type = type
        self._value = value

    def _validate_value(self, token_type: TokenTypes, value: Union[int, str, None]):
        if token_type == TokenTypes.ID and (
            not isinstance(value, str) or not value.isalnum() or value[0].isnumeric()
        ):
            raise TypeError("value for ID must be an alphanumeric string'")
        elif token_type == TokenTypes.INTEGER and not isinstance(value, int):
            raise TypeError("value for INTEGER token must be an integer")
        elif token_type == TokenTypes.STRING and not isinstance(value, str):
            raise TypeError("value for STRING token must be a string")

    @property
    def type(self):
        return self._type

    @property
    def value(self):
        return self._value

    def __str__(self) -> str:
        return f"Token({self._type}, {self._value})"

    def __repr__(self) -> str:
        return self.__str__()

    def __eq__(self, other):
        if not isinstance(other, type(self)):
            return False
        if (self._type, self._value) != (other._type, other._value):
            return False
        return True
