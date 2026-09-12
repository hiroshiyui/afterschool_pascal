{ Read a JSON document from standard input and print it indented.

  PasJson parses into a tree of `JsonPtr` nodes and answers questions about
  one -- its kind, how many members, the member with a name, the item at
  an index -- and every reader answers something sensible for a node that
  is not there, so a missing member is `nil` and never a trap. The
  document is gathered into a `JsonChars`, a growable byte vector, because
  a whole file rarely fits one `string(n)`. Scalars are printed by handing
  them back to `Render`, which knows the escapes. Run it as

      pascalcc json_pretty.pas -o pretty && ./pretty < some.json }
program json_pretty(input, output);

import PasError; PasJson;

var
  buf: JsonChars;
  line: string(4096);
  r: JsonResult;
  at: integer;

procedure Indent(n: integer);
var k: integer;
begin
  for k := 1 to n do write(' ')
end;

procedure Scalar(v: JsonPtr);
var out: JsonChars; s: string(4096); e: ErrorCode;
begin
  out.Init;
  v.Render(out);
  e := out.Into(s);
  if Failed(e) then write('"..."') else write(s);
  out.Free
end;

procedure Pretty(v: JsonPtr; depth: integer);
var k, n: integer;
begin
  n := v.Count;
  case v.Kind of
    jsArray:
      if n = 0 then write('[]')
      else begin
        writeln('[');
        for k := 1 to n do begin
          Indent(depth + 2);
          Pretty(v.At(k), depth + 2);
          if k < n then writeln(',') else writeln
        end;
        Indent(depth); write(']')
      end;
    jsObject:
      if n = 0 then write('{}')
      else begin
        writeln('{');
        for k := 1 to n do begin
          Indent(depth + 2);
          write('"', v.NameAt(k), '": ');
          Pretty(v.At(k), depth + 2);
          if k < n then writeln(',') else writeln
        end;
        Indent(depth); write('}')
      end;
    otherwise Scalar(v)
  end
end;

begin
  buf.Init;
  while not eof do begin
    readln(line);
    buf.AddText(line)
  end;
  at := 1;
  r := JsonParseChars(buf, at);
  if r.ok then begin
    Pretty(r.val, 0);
    writeln;
    writeln('-- ', r.val.Count:1, ' top-level members, "name" is ',
            r.val.Member('name').Member('length').IntegerOr(-1):1,
            ' (absent members read as the default)');
    r.val.Free
  end
  else
    writeln('not JSON: ', ErrorText(r.cause), ' at byte ', at:1);
  buf.Free
end.
