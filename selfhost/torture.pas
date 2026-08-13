program Torture(output);

{ Lexical edge cases, for the differential test rather than for ctest: this
  file is deliberately *not* a valid program. Every construct here is one the
  two lexers could plausibly disagree about, and several are ones where a
  careless port would.

  It lives in selfhost/ rather than tests/ because it is not meant to compile;
  difftest.sh lexes it and compares, which is the whole of its job. }

const
  { numbers: where a '.' or an 'e' does and does not continue the number }
  a1 = 0;
  a2 = 2147483647;          { maxint exactly, the largest accepted }
  a3 = 2147483648;          { one past it: an error, and no value to print }
  a4 = 99999999999999999999;{ far past it, where a 64-bit accumulator wraps }
  a5 = 1.5;
  a6 = 1e5;                 { exponent with no sign }
  a7 = 1e+5;                { the third character of lookahead }
  a8 = 1e-5;
  a9 = 1.5e+10;
  b1 = 1;                   { '1e' with no digit is a number then a name }

type
  { '..' after a number: the '.' must not be eaten as a fraction }
  r1 = 1..9;
  r2 = 10..20;

var
  { identifiers: case folding, underscores, digits, and near-keywords }
  Mixed_Case_42: integer;
  _leading: integer;
  BEGINNING: integer;       { starts with a keyword but is not one }
  ends: integer;            { 'end' plus a letter }
  x: real;
  b: boolean;

begin
  { operators, including every two-character one and its one-character
    prefix, adjacent so a greedy match is tested }
  x := 1;
  if (x <= 1) and (x >= 1) and (x <> 2) and (x < 3) and (x > 0) then
    x := x + 1 - 1 * 1 / 1;
  x := a5;

  { strings: empty, one character, embedded quotes, and a quote at the end }
  writeln('');
  writeln('a');
  writeln('it''s');
  writeln('''');
  writeln('trailing quote''');
  writeln('a  b   c');       { runs of blanks inside a literal are kept }

  (* the other comment form *)
  (* 6.1.8 NOTE 1: either delimiter closes a commentary whichever one opened
     it, so this comment ends at the brace on the next line and not here. }
  { and this one ends at the star-paren, not at a brace. *)
  (* which means an opening star-paren cannot occur in a commentary at all,
     NOTE 2, while a lone ) or ] or * is ordinary text. *)

  writeln(1e5:1:1);          { adjacent ':' operators after a real }
  writeln(a1..a2);           { nonsense to parse, fine to lex }

  { an unterminated string ends at the newline, and lexing recovers }
  writeln('unterminated
  );

  { A non-decimal literal is Extended Pascal's, so under ISO 7185 every one of
    these is refused -- and refused *as* one, so the base and the digits are
    still checked and the whole extended-digit sequence is still consumed. }
  x := 16#ff;
  x := 1#0;
  x := 16#fg;

  { `**` is Extended Pascal's other exponentiating operator, and there is no
    valid ISO 7185 program with two adjacent stars outside a comment or a
    string -- so it is scanned as one token and refused, rather than becoming
    a `*` and whatever the next token would then be. }
  x := 2 ** 3;

  { §6.1.2's two-word word-symbols are refused the same way and for the same
    reason: `and` followed by `then` is not a sentence of ISO 7185 either, so
    joining them costs that language nothing and buys one diagnostic instead
    of a complaint about `then` where a factor was wanted. The join is at the
    token level, so the separator between the words is any separator at all. }
  b := b and then b;
  b := b or else b;
  b := b and
       { including a comment } then b;

  { §6.11.2's `=>` is the one special-symbol modules add, and it is scanned
    under both standards for the reason `**` is: `=` cannot be followed by `>`
    in any ISO 7185 program, so maximal munch takes nothing away and the
    refusal is one token rather than a complaint about `>` after `=`. }
  x := 1 => 2;

  { an unexpected character }
  x := x @ 1;
  x := x $ 1;

  { Whitespace that is not a blank. isspace accepts the five control
    characters 9..13, and a lexer that only knows the space character
    lexes all of this differently -- a gap the corpus had until a
    deliberately broken IsSpace went undetected and put it here. }
	x	:=	1;
  x:=2;
  x:=3;
  x := 4;
		{ a comment reached only across tabs }

  writeln('done')
end.

{ An unterminated comment has to come last, because it swallows the rest of
  the file -- which is itself the behaviour being compared.
