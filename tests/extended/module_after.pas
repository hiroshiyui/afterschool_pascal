{ ISO/IEC 10206:1991 §6.13 constrains the order of program-components only by
  §6.2.2.9's partial ordering, so a module-declaration may follow the
  main-program-declaration. Such a module can supply nothing — nothing written
  before it can name an interface it exports — and §6.2.3.6 therefore never
  activates it: neither of its `to` parts runs.

  It is still *compiled*, which is the point of the file. An unactivated module
  is not an unchecked one. }
module before(output);
  export b = (mark);
  procedure mark;
end;
  procedure mark;
  begin writeln('before was activated') end;
  to begin do writeln('before commences');
  to end do writeln('before finalises');
end.

program ModuleAfter(output);
import b;
begin
  mark;
  writeln('program body')
end.

{ Written after the main-program-declaration. Its interface is exported and
  never imported, its body is checked, and none of it ever runs. }
module after(output);
  export a = (unreachable);
  const limit = 3;
  var n: integer;
  function unreachable: integer;
end;
  function unreachable;
  var i: integer;
  begin
    n := 0;
    for i := 1 to limit do n := n + i;
    unreachable := n
  end;
  to begin do writeln('after commences');
  to end do writeln('after finalises');
end.
