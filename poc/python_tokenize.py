import tokenize
from io import BytesIO

code = """
42+aaa++
"""

# Convert the code string into bytes
code_bytes = code.encode('utf-8')

# Create a BytesIO object to simulate a file-like object
code_stream = BytesIO(code_bytes)

# Tokenize the code
tokens = tokenize.tokenize(code_stream.readline)

# Iterate through the tokens and print their details
for token in tokens:
    print(token)
