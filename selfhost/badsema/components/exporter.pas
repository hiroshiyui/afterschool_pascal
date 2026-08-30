{ A well-formed module, so that the client beside it is the only thing wrong.
  It exports a function *with* a parameter, which is what makes `M.f` written
  bare a mistake rather than a parameterless call. }
module exporter;

export exporter = (twice);

function twice(n: integer): integer;
end;

function twice;
begin
  twice := n * 2
end;

end.
