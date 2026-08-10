{ ISO/IEC 10206:1991 §6.8.3.3's short-circuit operators. `A and then B`
  evaluates B if and only if A is true, and `A or else B` evaluates B if and
  only if A is false -- and, unlike `and` and `or`, the standard *requires*
  that rather than leaving the order implementation-dependent (§6.8.3.1).

  §6.1.2 spells each of them as one word-symbol written as two words, so
  nothing new is reserved: `and`, `or`, `then` and `else` are already
  word-symbols of ISO 7185. }
program ShortCircuit(output);
type
  link = ^node;
  node = record
    value: integer;
    next: link
  end;
var
  p: link;
  n: integer;
  calls: integer;
  b: boolean;

{ the only way to see that an operand was not evaluated is a side effect }
function Counted(answer: boolean): boolean;
begin
  calls := calls + 1;
  Counted := answer
end;

begin
  { The guard idiom, and the reason the operators exist: the right operand
    dereferences a pointer the left one has just found to be nil, and a
    dereference of nil traps. }
  p := nil;
  if (p <> nil) and then (p^.value = 5) then
    writeln('unreachable')
  else
    writeln('nil was not dereferenced');

  { and its mirror -- `or else` stops at true, so the zero divisor is never
    divided by }
  n := 0;
  if (n = 0) or else (100 div n > 1) then
    writeln('zero was not divided by');

  calls := 0;
  b := Counted(false) and then Counted(true);
  writeln('and then: ', calls:1, ' operand, ', b);
  calls := 0;
  b := Counted(true) or else Counted(false);
  writeln('or else:  ', calls:1, ' operand, ', b);

  { and when the left operand does not decide the answer, the right one is
    evaluated after all }
  calls := 0;
  b := Counted(true) and then Counted(false);
  writeln('and then: ', calls:1, ' operands, ', b);

  { §6.8.3.1 makes `and then` a multiplying-operator and `or else` an adding
    one, so `and then` binds tighter: this is true or else (false and then
    false), which stops at the first operand. Were they one precedence level
    they would associate to the left, giving (true or else false) and then
    false -- which evaluates two operands and answers false. That is the
    reading this line exists to rule out; the same expression written the
    other way round cannot, because left association happens to agree there. }
  calls := 0;
  b := Counted(true) or else Counted(false) and then Counted(false);
  writeln('precedence: ', calls:1, ' operand, ', b);

  { the short-circuit operators and the ordinary ones mix freely; this
    compiler evaluates all four the same way (ADR-0010), which the standard
    permits for `and` but only promises for `and then` }
  n := 1;
  b := (n = 1) and (p = nil) or else (n = 2);
  writeln('mixed: ', b);

  { One word-symbol, two words: what may sit between them is what may sit
    between any two tokens, so a comment and a line break are both allowed. }
  if (p = nil) or { a comment, in the middle of an operator }
     else (p^.value = 0) then
    writeln('separators between the two words');

  { the second `then` here is the if-statement's, not part of an operator }
  if (n = 1) and then (n < 2) then
    writeln('and the if still has its own then')
end.
