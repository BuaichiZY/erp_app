"""Show unbalanced Swift view-builder braces without needing a local Apple SDK."""
from pathlib import Path

for path in Path(__file__).parent.joinpath("ERP").glob("*.swift"):
    depth = 0
    in_string = False
    escaped = False
    changes = []
    stack = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        previous = depth
        for column, char in enumerate(line, 1):
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char == "{":
                depth += 1
                stack.append((line_number, column))
            elif char == "}":
                depth -= 1
                if stack:
                    stack.pop()
        if depth != previous:
            changes.append((line_number, depth))
    if depth:
        print(path.name, "unbalanced", depth, "unclosed at", stack)
