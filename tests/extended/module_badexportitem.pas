{ §6.11.2: an export-list holds exportable-names. }
module m;
  export i = (v, );
  var v: integer;
end;
end.
program P(output); begin writeln(1) end.
