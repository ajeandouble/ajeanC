class UnknownSymbolError(Exception):
    def __init__(self, symbol):
        self.symbol = symbol
        self.message = f"Unknown symbol {symbol}"


class ParserError(Exception):
    def __init__(self, msg):
        self.message = f"Parser error: {msg}"


class InterpreterError(Exception):
    def __init__(self, msg):
        self.message = f"Interpreter error: {msg}"

# TODO: specialize errors