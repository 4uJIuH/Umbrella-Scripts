import ast
import io
from pathlib import Path
import re
import tokenize


def strip_lua(source):
    output = []
    index = 0
    while index < len(source):
        char = source[index]
        if char in "\"'":
            end = index + 1
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source[end] == char:
                    end += 1
                    break
                else:
                    end += 1
            output.append(source[index:end])
            index = end
            continue
        comment = source.startswith("--", index)
        start = index + 2 if comment else index
        opening = re.match(r"\[(=*)\[", source[start:])
        if opening:
            closing = "]" + opening.group(1) + "]"
            found = source.find(closing, start + opening.end())
            if found < 0:
                raise ValueError("Unclosed Lua long string/comment")
            end = found + len(closing)
            text = source[index:end]
            output.append((" " + "\n" * text.count("\n")) if comment else text)
            index = end
        elif comment:
            end = source.find("\n", index)
            index = len(source) if end < 0 else end
            output.append(" ")
        else:
            output.append(char)
            index += 1
    return "".join(output)


def strip_python(source):
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    spans = []
    for token in tokenize.generate_tokens(io.StringIO(source).readline):
        if token.type == tokenize.COMMENT:
            spans.append((offsets[token.start[0] - 1] + token.start[1], offsets[token.end[0] - 1] + token.end[1]))
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and node.body:
            first = node.body[0]
            if isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant) and isinstance(first.value.value, str):
                spans.append((offsets[first.lineno - 1] + first.col_offset, offsets[first.end_lineno - 1] + first.end_col_offset))
    for start, end in sorted(spans, reverse=True):
        source = source[:start] + "\n" * source[start:end].count("\n") + source[end:]
    return source


def main():
    root = Path(__file__).resolve().parents[2]
    paths = [root / "Self Play.lua"]
    paths += [p for p in (root / "self_play").rglob("*") if p.suffix in (".lua", ".py") and "backups" not in p.parts]
    paths += [p for p in (root / "tests").glob("*self_play*") if p.suffix in (".luau", ".lua", ".py")]
    changed = 0
    for path in paths:
        source = path.read_text(encoding="utf-8")
        result = strip_python(source) if path.suffix == ".py" else strip_lua(source)
        if source != result:
            path.write_text(result, encoding="utf-8")
            changed += 1
    print(f"Removed comments from {changed} bot source files")


if __name__ == "__main__":
    main()
