{ The diagnostics of labels and goto (ISO 7185 6.1.6, 6.8.1, 6.8.2.4). Sema
  accumulates, so one file carries all of them -- and the order they come out
  in matters: a goto is not resolved where it is written but when its block
  has been walked, because the label it targets may be declared before the
  statement it labels appears. }
program labels(output);
label 1, 2, 3, 4, 4, 7, 8;
var i: integer;

procedure inner;
begin
  { a label of an enclosing block, placed where 6.8.1 allows: legal, and here
    to keep the *legal* non-local case beside the illegal one }
  goto 1;
  { and one placed where 6.8.1 does not allow it }
  goto 3
end;

begin
  { a label that no block declares }
  goto 5;
  { into a compound statement }
  if i = 0 then begin 3: i := 1 end;
  goto 3;
  { into a loop }
  while i < 3 do begin 2: i := i + 1 end;
  goto 2;
  { a label on a statement of a block that never declared it }
  6: i := 0;
  { the same label twice }
  7: i := 1;
  7: i := 2;
1: i := 3
end.
