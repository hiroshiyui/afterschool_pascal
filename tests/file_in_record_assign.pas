{ §6.4.6 a): a value of type T2 is assignment-compatible with T1 when "T1 and
  T2 are the same type, AND that type is permissible as the component-type of a
  file-type". §6.4.3.5 makes that second condition "neither a file-type nor a
  structured-type having any component whose type-denoter is not permissible",
  which is a file at any depth.

  ISO/IEC 10206:1991 §6.4.6 a) is the same sentence against its own §6.4.3.6, so
  this is one rule under both standards.

  It went unread for a long time: the check asked only whether either side *was*
  a file, so two records holding one were assignable to each other. The copy is
  a memcpy of the file's own storage, so both variables then name one open file
  and the block closes it twice -- a double free from a program a conforming
  processor must reject at compile time. BSI's DEV102 is this program and had
  been recorded TRAPPED, the one DEVIANCE test of 266 this compiler did not
  reject (ADR-0150). }
program file_in_record_assign(output);
type
  holder = record f: text; n: integer end;
  outer = record h: holder end;
  files = array [1..2] of text;
var
  a, b: holder;
  p, q: outer;
  u, v: files;
  f, g: text;
begin
  { the fault the rule is about }
  b := a;
  { at any depth: a record inside a record }
  q := p;
  { and through an array's component-type. A variant is not tried here: a file
    may not be a field of one at all (ADR-0070), so the declaration is refused
    before an assignment could reach the rule. }
  v := u;
  { a bare file was always refused, and by its own message -- the two are one
    rule and the words differ because the advice does }
  g := f
end.
