#!/usr/bin/env python3
"""Remove every comment from a Pascal source, preserving line numbers.

An audit reader is allowed to open the compiler's source "where it is necessary
to see what a check does".  The *code* is behaviour; the *comments* are the
implementer's reasoning, and in this tree they are the densest such text there
is -- 791 ADR citations and 1755 clause citations in one file, which is 41% of
what all of doc/adr/ holds.  A reader auditing a clause will find the reading
pre-formed in the comment above the check.

So the sandbox ships the code without the commentary.  Newlines inside a
comment are kept, so a line number in the stripped copy is the line number in
the real file and a finding can be cited back.

ISO 7185 6.1.8: a comment opens with `{` or `(*` and closes with `}` or `*)`,
and the two forms correspond -- `*)` closes a `{` comment.  Comments do not
nest.  A `{` inside a character-string is not a comment.
"""
import sys


def strip(src: str) -> str:
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "'":                      # character-string: copy verbatim
            out.append(c)
            i += 1
            while i < n:
                out.append(src[i])
                if src[i] == "'":
                    # '' inside a string is one quote, not a terminator
                    if i + 1 < n and src[i + 1] == "'":
                        out.append(src[i + 1])
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue
        if c == '{' or (c == '(' and i + 1 < n and src[i + 1] == '*'):
            i += 1 if c == '{' else 2
            while i < n:
                if src[i] == '}':
                    i += 1
                    break
                if src[i] == '*' and i + 1 < n and src[i + 1] == ')':
                    i += 2
                    break
                if src[i] == '\n':
                    out.append('\n')      # keep the line numbering
                i += 1
            continue
        out.append(c)
        i += 1
    # a line that held only a comment is now blank; leave it blank rather than
    # closing it up, for the same reason
    return ''.join(out)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('usage: strip_comments.py IN.pas OUT.pas')
    with open(sys.argv[1], encoding='utf-8', newline='') as f:
        text = f.read()
    with open(sys.argv[2], 'w', encoding='utf-8', newline='') as f:
        f.write(strip(text))
