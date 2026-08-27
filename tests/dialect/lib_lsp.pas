{ PasLsp: the Language Server Protocol's framing, read off standard input and
  written back to standard output.

  Everything this case prints goes through `PasIO.WriteText` and not through
  `writeln`. That is not a style choice: `output` is a buffered Pascal text
  file and a descriptor write is not, so a program using both emits them in an
  order that depends on when the buffer happens to flush. A case comparing
  bytes has to pick one, and a case about a *descriptor* protocol picks that
  one.

  The golden therefore contains real carriage returns, in the two lines the
  reply's header occupies. That is the point of them: what this module accepts
  is lenient about `<CR>` and what it writes is not, and a golden with the
  bytes in it is the only thing that can say so. }
program lib_lsp(output);

import PasError; PasIO; PasJson; PasLsp;

var r: LspReader;
    body, out: JsonChars;
    e: ErrorCode;
    seen: integer;
    res: JsonResult;
    at: integer;
    line: IOLine;
    reply, params: JsonPtr;
    ignore: ErrorCode;

procedure Say(s: IOLine);
var junk: ErrorCode;
begin
  junk := WriteText(StdOut, s + chr(10))
end;

begin
  LspOpen(r, StdIn);
  seen := 0;
  repeat
    JsonCharsNew(body);
    e := LspRead(r, body);
    if e = errNone then begin
      seen := seen + 1;
      res := JsonParseChars(body, at);
      if not res.ok then begin
        writestr(line, 'message ', seen:1, ' bytes=', JsonCharsLen(body):1,
                 ' not JSON: ', ErrorText(res.cause));
        Say(line)
      end
      else begin
        ignore := JsonTextInto(JsonMember(res.val, 'method'), line);
        writestr(line, 'message ', seen:1, ' bytes=', JsonCharsLen(body):1,
                 ' id=', JsonIntegerOr(JsonMember(res.val, 'id'), -1):1);
        Say(line);
        ignore := JsonTextInto(JsonMember(res.val, 'method'), line);
        Say('  method=' + line);
        JsonFree(res.val)
      end
    end;
    JsonCharsFree(body)
  until e <> errNone;

  { `errAbsent` is how a server's loop ends and is not a failure -- the client
    closed the pipe. Every other code is. }
  writestr(line, 'ended after ', seen:1, ' with ', ErrorText(e));
  Say(line);

  { And one message written back, which is the half of the module a reader of
    the input cannot see. The header is <CR><LF> twice over, always. }
  reply := JsonNewObject;
  JsonPut(reply, 'jsonrpc', JsonNewText('2.0'));
  JsonPut(reply, 'id', JsonNewInteger(1));
  params := JsonNewObject;
  JsonPut(params, 'capabilities', JsonNewObject);
  JsonPut(reply, 'result', params);
  JsonCharsNew(out);
  JsonRender(reply, out);
  e := LspWrite(StdOut, out);
  JsonCharsFree(out);
  JsonFree(reply);
  Say('');
  writestr(line, 'write code=', ErrorText(e));
  Say(line)
end.
