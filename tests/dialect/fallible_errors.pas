{ AP 6.4.13: what a fallible-type refuses, and each refusal's reason
  (ADR-0176). Sema accumulates, so one file. }
program fallible_errors(input, output);

type
  Code = (none_, syntax);
  IntResult = integer ! Code;
  H = handle external 'fclose';
  { neither side may itself be fallible: one tag answers for one outcome }
  Nested = IntResult ! Code;
  { nor hold a file or a handle, which have no value to be an outcome }
  Filed = text ! Code;
  Handled = H ! Code;
  FileRec = record n: integer; f: text end;
  RecFiled = FileRec ! Code;
  { an optional already answers whether there is a value }
  Opt = ?IntResult;
  { a type whose sides overlap is legal -- what it cannot take is the
    shorthand, which is refused where it is written }
  Both = integer ! 1..5;

  { and an anonymous one, so that a diagnostic has to spell the type rather
    than name it }
var r: IntResult; b: Both; x: real; ok2: boolean;
    anon: integer ! Code;

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
  writeln(ok2)
end.
