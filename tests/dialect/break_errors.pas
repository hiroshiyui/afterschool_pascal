{ AP 6.7.5.10 and 6.7.5.11: what the two loop-control procedures refuse. Sema
  accumulates, so one file.

  Both requirements are the same sentence with a different name in it -- no
  argument, and a repetitive-statement of *this* block to be executing -- and
  the compiler writes them once for that reason. Each is probed under both
  spellings anyway, because "written once" is a fact about the source and not
  about what a program is told.

  The defer lines are 6.7.5.10 NOTE 4, which is the pair worth reading: the
  clause deliberately keeps a break-statement out of 6.9.3.11.3's list, so the
  refusal has to fall out of the ordinary requirement. A deferred statement is
  run in the block's runner, where no loop of this block is executing -- so
  `defer break` names nothing and is refused, while `defer while c do break`
  names the loop it wrote and is accepted. Both are here; only the first is an
  error, and a compiler that refused the second would be caught by the case
  passing with one diagnostic too many. }
program break_errors(output);
var i: integer; c: boolean;

{ A repetitive-statement of an enclosing block is not one of this block, which
  is 6.7.5.9's "never an enclosing one" for a loop rather than for a block. }
procedure Inner;
begin
  break
end;

begin
  { outside any loop at all }
  break;
  continue;
  for i := 1 to 3 do begin
    { no argument: neither leaves anything anywhere to report }
    break(i);
    continue(i);
    { NOTE 4's first half: the runner has no loop of this block }
    defer break;
    defer continue;
    { ...and its second half, which is not an error }
    defer while c do break;
    defer while c do continue
  end;
  Inner
end.
