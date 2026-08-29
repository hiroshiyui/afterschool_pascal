{ PasLsp's *other* framing (ADR-0241): MCP's stdio transport, where "Messages
  are delimited by newlines, and MUST NOT contain embedded newlines".

  It is here rather than in tests/dialect/lib_lsp.pas because a program has one
  standard input and the two framings cannot be read from it at once. What the
  pair says together is the finding this module produced: `LspReader` is a
  buffered descriptor reader and the framing is layered over it, so the second
  transport shares everything but forty lines.

  Everything this program says goes through a descriptor write, for the reason
  lib_lsp.pas states at its own head: `output` is buffered and PasIO is not, so
  a program that used both would interleave them unpredictably. }
program lib_lsp_jsonl(output);

import PasError; PasIO; PasJson; PasLsp;

var r: LspReader;
    body, out: JsonChars;
    e: ErrorCode;
    seen: integer;
    res: JsonResult;
    at: integer;
    line: IOLine;
    reply: JsonPtr;

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
    e := JsonlRead(r, body);
    if e = errNone then begin
      seen := seen + 1;
      res := JsonParseChars(body, at);
      if not res.ok then begin
        writestr(line, 'message ', seen:1, ' did not parse at ', at:1);
        Say(line)
      end
      else begin
        writestr(line, 'message ', seen:1, ' bytes=', JsonCharsLen(body):1,
                 ' id=', JsonIntegerOr(JsonMember(res.val, 'id'), -1):1);
        Say(line);
        JsonFree(res.val)
      end
    end;
    JsonCharsFree(body)
  until e <> errNone;
  { `errAbsent` and not a failure: the end of the input is how a session ends.
    A *partial* line would be errSyntax, which is the distinction this reports
    rather than merely surviving. }
  writestr(line, 'ended after ', seen:1, ' with ', ErrorText(e));
  Say(line);

  { One message written back. No header and no count: the line is the frame. }
  reply := JsonNewObject;
  JsonPut(reply, 'jsonrpc', JsonNewText('2.0'));
  JsonPut(reply, 'id', JsonNewInteger(1));
  JsonPut(reply, 'result', JsonNewObject);
  JsonCharsNew(out);
  JsonRender(reply, out);
  e := JsonlWrite(StdOut, out);
  JsonCharsFree(out);
  JsonFree(reply);
  writestr(line, 'write code=', ErrorText(e));
  Say(line);

  { And a body holding a newline, which this framing cannot carry: refused
    rather than written, because a message containing one would be read back
    as two and neither would parse. Nothing reaches the stream. }
  JsonCharsNew(out);
  JsonCharsAdd(out, '{');
  JsonCharsAdd(out, chr(10));
  JsonCharsAdd(out, '}');
  e := JsonlWrite(StdOut, out);
  JsonCharsFree(out);
  writestr(line, 'newline in a body: ', ErrorText(e));
  Say(line)
end.
