{ A separately translated component (6.13) holding a function whose result is
  written on one path and not another. Sema checks a whole imported component,
  so without `curFile = mainFile` the importer would be told about a file its
  command line never named -- ADR-0272's third guard, met a third time. }
module partial_helper(output);

export partial_helper = (Maybe);

function Maybe(n: integer): integer;

end;

function Maybe;
begin
  if n > 0 then Maybe := n
end;

end.
