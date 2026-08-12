{ §6.11.3: `=>` is followed by the new identifier. }
module m;
  export i = (v);
  var v: integer;
end;
end.
program P(output);
import i (v => );
begin writeln(1) end.
