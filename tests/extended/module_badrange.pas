{ §6.11.2: an export-range ends at a constant-name. }
module m;
  export i = (lo..);
  const lo = 1;
end;
end.
program P(output); begin writeln(1) end.
