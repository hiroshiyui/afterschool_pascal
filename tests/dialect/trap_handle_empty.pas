{ AP 6.4.12.4: lending an empty handle to a foreign routine is an error (Annex
  A.7). An empty handle is what a failed open answers, and a C routine given
  NULL where it expects a stream does not report, it crashes. }
program trap_handle_empty(output);
type InFile = handle external 'fclose';
function ExtFopen(path, mode: string): InFile; external 'fopen';
function ExtFgetc(f: InFile): integer; external 'fgetc';
var f: InFile;
begin
  f := ExtFopen('/nonexistent-apascal-dir/x', 'r');
  writeln('empty: ', f = nil);
  writeln(ExtFgetc(f))
end.
