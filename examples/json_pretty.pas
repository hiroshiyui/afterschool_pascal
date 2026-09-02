{ Read a JSON document from standard input and print it indented.

  PasJson parses into a tree of `JsonPtr` nodes and answers questions about
  one -- its kind, how many members, the member with a name, the item at
  an index -- and every reader answers something sensible for a node that
  is not there, so a missing member is `nil` and never a trap. The
  document is gathered into a `JsonChars`, a growable byte vector, because
  a whole file rarely fits one `string(n)`. Scalars are printed by handing
  them back to `JsonRender`, which knows the escapes. Run it as

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
  JsonCharsNew(out);
  JsonRender(v, out);
  e := JsonCharsInto(out, s);
  if Failed(e) then write('"..."') else write(s);
  JsonCharsFree(out)
end;

procedure Pretty(v: JsonPtr; depth: integer);
var k, n: integer;
begin
  n := JsonCount(v);
  case JsonKindOf(v) of
    jsArray:
      if n = 0 then write('[]')
      else begin
        writeln('[');
        for k := 1 to n do begin
          Indent(depth + 2);
          Pretty(JsonAt(v, k), depth + 2);
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
          write('"', JsonNameAt(v, k), '": ');
          Pretty(JsonAt(v, k), depth + 2);
          if k < n then writeln(',') else writeln
        end;
        Indent(depth); write('}')
      end;
    otherwise Scalar(v)
  end
end;

begin
  JsonCharsNew(buf);
  while not eof do begin
    readln(line);
    JsonCharsAddLine(buf, line)
  end;
  at := 1;
  r := JsonParseChars(buf, at);
  if r.ok then begin
    Pretty(r.val, 0);
    writeln;
    writeln('-- ', JsonCount(r.val):1, ' top-level members, "name" is ',
            JsonIntegerOr(JsonMember(JsonMember(r.val, 'name'), 'length'), -1):1,
            ' (absent members read as the default)');
    JsonFree(r.val)
  end
  else
    writeln('not JSON: ', ErrorText(r.cause), ' at byte ', at:1);
  JsonCharsFree(buf)
end.
