{ ISO/IEC 10206:1991 §6.11.1 gives a module-block one initialization-part and
  one finalization-part, in that order — `to begin do` then `to end do`, each
  at most once. }
module m;
  export i = (v);
  var v: integer;
end;
  to end do v := 0;
  to begin do v := 1;
end.
program BadTo(output);
import i;
begin writeln(v:1) end.
