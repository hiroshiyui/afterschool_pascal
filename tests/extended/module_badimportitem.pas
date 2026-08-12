{ §6.11.3: an import-list holds constituent-identifiers. }
module m;
  export i = (v);
  var v: integer;
end;
end.
program P(output);
import i only (, v);
begin writeln(1) end.
