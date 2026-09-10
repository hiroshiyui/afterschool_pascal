#!/usr/bin/env python3
"""Is every cell role legible, and is every cell role drawn? (ADR-0393)

Two claims about `tui/`'s colour, neither of which any other oracle here can
reach.  A session golden holds the **role plane** -- one letter per cell --
and never a colour, which is deliberate (`tui/run.py` compares what the model
decided, and the shell that turns a role into an escape sequence is a
`doc/sop.md` §7 row).  What that leaves uncovered is exactly what a person
looking at the screen sees first.

**Claim one: a role that nothing draws is not a role.**  `crPrompt` was
declared, mapped to a colour, given a letter by `tui/session.pas` and written
on no screen for the whole life of ADR-0392, which turned the prompt from a
bottom line into a framed box and had the box draw its contents in its own
role.  Every golden agreed, because a golden holds what was drawn.  So the
enum is compared against the letters the goldens actually contain, in both
directions: a role no session draws fails, and a letter no role explains fails
just as loudly.

**Claim two: every pairing is legible on a palette nobody here chose.**
`PasTerm` offers the eight ANSI colours and `clDefault`, and what a terminal
makes of the eight is its own business -- so the ratios below are computed
against xterm's own palette, which is the most widely implemented reading of
those eight, and the rule that survives a *different* reading is the
structural one: one side of every pair is black or white.  A colour on a
colour is what a muted theme flattens.

`crText` is exempt from both halves of claim two and from neither of claim
one: the document is the terminal's own text in the terminal's own colours,
and painting it would be this editor overriding a choice the person made.

Run it directly, or as the `tui-palette` case.
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent

# xterm's own eight, which is what `SetColour` writes SGR 30-37/40-47 for.
# `clDefault` is SGR 39/49 and has no value here by construction.
RGB = {
    'clBlack': (0x00, 0x00, 0x00),
    'clRed': (0xcd, 0x00, 0x00),
    'clGreen': (0x00, 0xcd, 0x00),
    'clYellow': (0xcd, 0xcd, 0x00),
    'clBlue': (0x00, 0x00, 0xee),
    'clMagenta': (0xcd, 0x00, 0xcd),
    'clCyan': (0x00, 0xcd, 0xcd),
    'clWhite': (0xe5, 0xe5, 0xe5),
}
EXTREMES = ('clBlack', 'clWhite')

# WCAG 2.1 AAA for body text.  It is a floor and not a target: the point is
# that a pairing cannot drift below it without this failing.
FLOOR = 7.0

# WCAG 2.1's non-text threshold, applied to two *backgrounds* that a person
# sees at once.  A pairing can be perfectly legible and still leave a screen
# unusable: a menu title drawn black-on-white on a black-on-cyan bar is 16.7:1
# to read and 1.6:1 away from the bar it is meant to stand out from, so
# nothing tells you which menu is open.  That defect was written and shipped
# between ADR-0393 and ADR-0394 and found by carrying the analysis further,
# not by looking.
APART = 3.0

# Which roles a person sees at once and must be able to tell apart, as pairs
# rather than as sets -- the three bars along the bottom are adjacent in the
# order (message, status, hint), and the message and the hint have the status
# between them, so requiring all three to differ from each other is a rule
# the eight ANSI colours cannot satisfy at all.  Measured: with black or white
# on one side of every pair, no three of the eight are mutually 3:1 apart.
COVISIBLE = (
    ('crMessage', 'crStatus'),    # the two lowest bars, one above the other
    ('crStatus', 'crHint'),
    ('crMenu', 'crChosen'),       # which menu is open
    ('crFrame', 'crChosen'),      # which item in the drop-down
    ('crFrame', 'crPrompt'),      # the field inside the dialog
)


def luminance(rgb):
    def chan(v):
        c = v / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (chan(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(RGB[a]), luminance(RGB[b])
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def roles():
    """The `CellRole` constants, in the order `tui/apedit.pas` declares them."""
    src = (ROOT / 'tui' / 'apedit.pas').read_text(encoding='utf-8')
    m = re.search(r'CellRole\s*=\s*\(([^)]*)\)', src)
    if not m:
        sys.exit('tui-palette: no CellRole enumeration in tui/apedit.pas')
    return [w.strip() for w in m.group(1).split(',') if w.strip()]


def letters():
    """The role letters `tui/session.pas` prints, as {role: letter}."""
    src = (ROOT / 'tui' / 'session.pas').read_text(encoding='utf-8')
    m = re.search(r'function RoleChar.*?\bcase\b(.*?)\bend\b', src, re.S)
    if not m:
        sys.exit('tui-palette: no RoleChar dispatch in tui/session.pas')
    out = {}
    for role, ch in re.findall(r"(cr\w+)\s*:\s*RoleChar\s*:=\s*'(.)'", m.group(1)):
        out[role] = ch
    return out


def palette():
    """The `RoleColour` arms, as {role: (fg, bg)} of `cl` names."""
    src = (ROOT / 'tui' / 'apide.pas').read_text(encoding='utf-8')
    m = re.search(r'procedure RoleColour.*?\bcase\b(.*?)\n  end\b', src, re.S)
    if not m:
        sys.exit('tui-palette: no RoleColour dispatch in tui/apide.pas')
    out = {}
    for role, fg, bg in re.findall(
            r'(cr\w+)\s*:\s*begin\s*fg\s*:=\s*(cl\w+)\s*;\s*bg\s*:=\s*(cl\w+)',
            m.group(1)):
        out[role] = (fg, bg)
    return out


def rgb_palette():
    """The `RoleRgb` arms, as {role: (fg hex, bg hex)}.

    The procedure assigns the commonest pair before the `case` and each arm
    overrides what it differs in, which is how a language with no record
    literal writes a table -- so the arms are read *in order* over a running
    default, exactly as the program executes them.  An arm that is bare (`;`)
    takes the default, and that is a value like any other: reading it as
    "unset" would let the commonest pair in the table go unchecked.
    """
    src = (ROOT / 'tui' / 'apide.pas').read_text(encoding='utf-8')
    m = re.search(r'procedure RoleRgb.*?\bbegin\b(.*?)\n  end\b', src, re.S)
    if not m:
        sys.exit('tui-palette: no RoleRgb dispatch in tui/apide.pas')
    body = m.group(1)
    head, _, arms = body.partition('case k of')

    def channels(text):
        got = {}
        for var, val in re.findall(r'\b(f[rgb]|b[rgb])\s*:=\s*16#([0-9A-Fa-f]{2})',
                                   text):
            got[var] = val.upper()
        return got

    base = channels(head)
    if len(base) != 6:
        sys.exit('tui-palette: RoleRgb has no six-channel default before its '
                 'case, so an arm that overrides nothing means nothing')
    out = {}
    for role, arm in re.findall(r'(cr\w+)\s*:\s*(begin.*?end|)\s*;', arms, re.S):
        got = dict(base)
        got.update(channels(arm))
        out[role] = (got['fr'] + got['fg'] + got['fb'],
                     got['br'] + got['bg'] + got['bb'])
    return out


def rgb_contrast(a, b):
    def val(h):
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    la, lb = luminance(val(a)), luminance(val(b))
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def drawn(known):
    """The role letters that appear in a role plane of some golden.

    A `.screen` file prints the characters, then the roles, then the runs,
    each block inside a `+---+` border.  A role-plane row is a bordered row
    made only of role letters -- which is why the letters are taken from
    `RoleChar` rather than guessed: a row of document text saying `hush`
    would otherwise be read as four roles.
    """
    seen = set()
    body = re.compile(r'^\|([' + re.escape(''.join(known)) + r']+)\|$')
    for path in sorted((ROOT / 'tui' / 'sessions').glob('*.screen')):
        for line in path.read_text(encoding='utf-8').splitlines():
            m = body.match(line)
            if m and len(set(m.group(1))) >= 1:
                seen.update(m.group(1))
    return seen


def main():
    bad = []
    names = roles()
    letter = letters()
    colours = palette()

    # Every role is declared once, mapped to a letter once and coloured once.
    for role in names:
        if role not in letter:
            bad.append(f'{role} has no letter in tui/session.pas RoleChar')
        if role not in colours:
            bad.append(f'{role} has no arm in tui/apide.pas RoleColour')
    for role in letter:
        if role not in names:
            bad.append(f'RoleChar names {role}, which is not a CellRole')
    for role in colours:
        if role not in names:
            bad.append(f'RoleColour names {role}, which is not a CellRole')
    if bad:
        for b in bad:
            print('tui-palette: ' + b)
        return 1

    # Claim one: every role is drawn by some session, and every letter a
    # golden holds is a role.  Both directions.
    known = sorted(set(letter.values()))
    seen = drawn(known)
    for role in names:
        if letter[role] not in seen:
            bad.append(f"{role} ('{letter[role]}') is drawn by no session -- "
                       'a role nothing draws is a colour nobody sees')
    for ch in sorted(seen):
        if ch not in known:
            bad.append(f"the goldens hold role letter '{ch}', which RoleChar "
                       'does not write')

    # Claim two: an extreme against a colour, and the ratio to prove it.
    ratios = []
    for role in names:
        fg, bg = colours[role]
        if role == 'crText':
            if (fg, bg) != ('clDefault', 'clDefault'):
                bad.append('crText is the terminal\'s own text and must stay '
                           f'clDefault on clDefault, not {fg} on {bg}')
            continue
        if 'clDefault' in (fg, bg):
            bad.append(f'{role} is {fg} on {bg}: clDefault is whatever the '
                       'terminal chose, so this pair has no contrast ratio')
            continue
        if fg not in EXTREMES and bg not in EXTREMES:
            bad.append(f'{role} is {fg} on {bg}: a colour on a colour, which '
                       'a muted theme flattens -- one side must be black or '
                       'white')
            continue
        r = contrast(fg, bg)
        ratios.append((role, fg, bg, r))
        if r < FLOOR:
            bad.append(f'{role} is {fg} on {bg} at {r:.1f}:1, under the '
                       f'{FLOOR:.0f}:1 floor')

    if bad:
        for b in bad:
            print('tui-palette: ' + b)
        return 1

    # Claim three: the twenty-four-bit table, held to the same floor.  A
    # fallback nobody looks at is exactly where an unreadable pair survives,
    # and this is the table most people will actually see.
    rgb = rgb_palette()
    rgb_ratios = []
    for role in names:
        if role == 'crText':
            continue
        if role not in rgb:
            bad.append(f'{role} has no arm in tui/apide.pas RoleRgb')
            continue
        fg, bg = rgb[role]
        r = rgb_contrast(fg, bg)
        rgb_ratios.append((role, fg, bg, r))
        if r < FLOOR:
            bad.append(f'{role} is #{fg} on #{bg} at {r:.1f}:1 in RoleRgb, '
                       f'under the {FLOOR:.0f}:1 floor')
    for role in rgb:
        if role not in names:
            bad.append(f'RoleRgb names {role}, which is not a CellRole')

    # Claim four: two regions a person sees at once are told apart by their
    # backgrounds, in **both** tables.  Legible and indistinguishable is a
    # real state and this project shipped it once.
    for a, b in COVISIBLE:
        if a in colours and b in colours:
            fa, ba = colours[a]
            fb, bb = colours[b]
            if 'clDefault' not in (ba, bb):
                r = contrast(ba, bb)
                if r < APART:
                    bad.append(f'{a} and {b} are seen at once and their '
                               f'backgrounds are {ba} and {bb} at {r:.1f}:1, '
                               f'under the {APART:.0f}:1 they must differ by')
        if a in rgb and b in rgb:
            r = rgb_contrast(rgb[a][1], rgb[b][1])
            if r < APART:
                bad.append(f'{a} and {b} are seen at once and their RoleRgb '
                           f'backgrounds are #{rgb[a][1]} and #{rgb[b][1]} at '
                           f'{r:.1f}:1, under the {APART:.0f}:1 they must '
                           'differ by')

    if bad:
        for b in bad:
            print('tui-palette: ' + b)
        return 1

    worst = min(ratios, key=lambda t: t[3])
    wrgb = min(rgb_ratios, key=lambda t: t[3])
    print(f'tui-palette: {len(names)} cell role(s), each drawn by a session '
          f'and each legible; {len(ratios)} ANSI pair(s) at {worst[3]:.1f}:1 '
          f'or better ({worst[0]} is {worst[1]} on {worst[2]}) and '
          f'{len(rgb_ratios)} direct-colour pair(s) at {wrgb[3]:.1f}:1 or '
          f'better ({wrgb[0]} is #{wrgb[1]} on #{wrgb[2]}); '
          f'{len(COVISIBLE)} co-visible pair(s) told apart in both')
    return 0


if __name__ == '__main__':
    sys.exit(main())
