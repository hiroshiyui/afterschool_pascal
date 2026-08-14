{ ISO 7185 §6.2.2.9 applied to a required identifier. ADR-0088 enforced the
  rule -- a name used in a block may not then be declared in it -- but only
  where the earlier use resolved to a *symbol*, because the check works by
  stamping the symbol it found. A required identifier was recognised by name
  and was no symbol, so the three shapes below went unreported.

  They are the BSI suite's DEV112, DEV264 and DEV265. §6.2.2.10 puts the
  required identifiers' defining-points in "a region enclosing the program",
  which is what makes them the *outer* declaration §6.2.2.9 compares against;
  since ADR-0097 they are ordinary symbols in an ordinary outermost scope, so
  this needed no rule of its own.

  tests/required_shadow.pas is the half that must still work: declaring a
  required identifier a block has *not* used is exactly what §6.2.2.10 allows,
  and a check that reported it would be worse than no check. }
program DefiningPointRequired(output);
var i : integer;

{ Legal: the required `ord` is applied here, and this block declares nothing
  of that name. }
procedure user;
begin
  i := ord('a')
end;

{ §6.2.2.9, DEV112's shape: the applied occurrence is inside a nested block
  and the declaration is in the block containing it, so the fault is only
  visible once `holder`'s own declarations are reached. }
procedure holder;
  procedure caller;
  begin
    i := ord('b')
  end;
  function ord(c : char) : integer;
  begin
    ord := 0
  end;
begin
  caller
end;

procedure clashType;
type
  alias = integer;
  integer = char;
var
  v : alias;
begin
  v := 1
end;

begin
  user;
  holder;
  clashType
end.
