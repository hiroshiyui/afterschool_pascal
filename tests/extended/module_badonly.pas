{ ISO/IEC 10206:1991 §6.11.3: `only` is a selective-import-option and the
  option is on the list — it says the list is exhaustive rather than a set of
  renamings, so there has to be one. }
module m;
  export i = (v);
  var v: integer;
end;
end.
program BadOnly(output);
import i only;
begin writeln(v:1) end.
