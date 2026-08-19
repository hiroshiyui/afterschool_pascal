{ ADR-0123's type-denoter in the dumps. It nests, unlike a pointer, so the
  sub-denoter is printed indented under it and --dump-sema names the type
  it resolved to. }
program optional_dump(output);
type OptInt = ?integer;
     OptName = ?string(8);
var a: OptInt;
    b: OptName;
    c: ?char;
begin
  a := nil;
  b := 'x';
  c := 'z';
  writeln((a = nil), b^, c^)
end.
