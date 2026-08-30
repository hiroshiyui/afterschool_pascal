{ AP 6.4.13: what a fallible-type refuses, and each refusal's reason
  (ADR-0176). Sema accumulates, so one file. }
program fallible_errors(input, output);

type
  Code = (none_, syntax);
  IntResult = integer ! Code;
  H = handle external 'fclose';
  { neither side may itself be fallible: one tag answers for one outcome }
  Nested = IntResult ! Code;
  { AP 6.4.13.5 (ADR-0256) admits these three: the *value* side may be affine,
    and the two arms are then laid beside one another rather than over one
    another, so there is no shared storage for a cause to overwrite. They are
    here to produce no diagnostic. What is refused is the **cause** side,
    below: a cause is carried out of a function by `try`, which is a copy, and
    an affine value has none. }
  Filed = text ! Code;
  Handled = H ! Code;
  FileRec = record n: integer; f: text end;
  RecFiled = FileRec ! Code;
  { and the cause side, for the reason the value side is admitted }
  CauseFiled = integer ! H;
  HandleResult = H ! Code;
  { an optional already answers whether there is a value }
  Opt = ?IntResult;
  { a type whose sides overlap is legal -- what it cannot take is the
    shorthand, which is refused where it is written }
  Both = integer ! 1..5;

  { and an anonymous one, so that a diagnostic has to spell the type rather
    than name it }
var r: IntResult; b: Both; x: real; ok2: boolean;
    anon: integer ! Code;
    { AP 6.4.13.5's own two refusals. }
    h1, h2: HandleResult; n: integer;

begin
  { a value of neither side }
  r := 3.5;
  { and out of one: the value and the reason are two arms, so there is no
    plain integer to take without asking the tag }
  x := r;
  { the tag says which outcome was written and is not the program's to set }
  r.ok := true;
  read(r.ok);
  { both sides admit a 3, so this assignment names no outcome }
  b := 3;
  { the type has no name, so the message must write `integer ! code` out }
  anon := 'text';
  ok2 := r.ok;
  { AP 6.4.13.5: the value side is owned, so the record has no copy and the
    one assignment admitted is a call of a function of its own type. }
  h1 := h2;
  { and `try` cannot yield it: 6.8.9.4 makes the expression denote the value,
    and denoting an owned value would be copying it. }
  n := try(h1);
  writeln(ok2, n:1)
end.
