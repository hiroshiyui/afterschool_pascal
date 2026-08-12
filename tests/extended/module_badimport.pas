{ §6.11.3: an import-specification names an interface. }
module m;
  export i = (v);
  var v: integer;
end;
end.
program P(output);
import ;
begin writeln(1) end.
