{ AP 6.4.12.7: a handle moves.

  `take` was an owned pointer's alone (AP 6.4.14.6, ADR-0182) and the refusal
  said why in as many words -- *nothing else has a value one variable can stop
  holding*. That was true of a file and is not true of a handle: a handle is
  one word of the runtime's, exactly as an owned pointer is one word of the
  heap, and the reason neither may be copied is the reason both need a move.

  ADR-0201 named this as the prerequisite for a concurrency construct: a task
  cannot be **given** a socket until a handle can move.

  Every handle here is `/dev/null` opened for writing, so the program prints
  through `writeln` alone and the golden holds no interleaving of two
  buffers. What `ExtFputs` answers is what says the handle is live: a closed
  or empty one would not accept a write. }
program handle_move(output);

type Stream = handle external 'fclose';

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(text: string; f: Stream): integer; external 'fputs';

var a, b, c: Stream; k: integer;

{ A handle crossing into a routine that will own it -- which is the shape the
  move exists for. The formal is a `var` parameter and the actual is emptied,
  so at no moment do two variables hold it. }
procedure TakeOver(var from, into: Stream);
begin
  into := take(from)
end;

begin
  a := ExtFopen('/dev/null', 'w');
  writeln('opened        : ', a <> nil);

  { The move: what a stops holding, b takes. }
  b := take(a);
  writeln('source emptied: ', a = nil);
  writeln('target holds  : ', b <> nil);
  writeln('and it is live: ', ExtFputs('x', b) >= 0);

  { A self-move is a no-op and not a close, which is the property the order of
    the two runtime calls buys: the source is emptied before the target is
    released, so the release finds nothing. }
  b := take(b);
  writeln('self-move     : ', b <> nil, ' ', ExtFputs('x', b) >= 0);

  { The target's own handle is released first, as every handle assignment
    does -- so this closes what c held and there is no leak and no second
    close of what b held. }
  c := ExtFopen('/dev/null', 'w');
  c := take(b);
  writeln('target closed : ', (c <> nil) and (b = nil));
  writeln('and it is live: ', ExtFputs('x', c) >= 0);

  { Across a call, through two var parameters. }
  a := ExtFopen('/dev/null', 'w');
  TakeOver(a, b);
  writeln('across a call : ', (a = nil) and (b <> nil));

  { `nil` is still the other assignment, and releases. }
  b := nil;
  writeln('nil releases  : ', b = nil);

  { Moving an empty handle is legal and moves nothing: `take` of an empty
    variable answers the empty value, as `dispose` of nil is refused but
    assigning nil is not. }
  a := take(b);
  writeln('empty moves   : ', (a = nil) and (b = nil));
  k := 0;
  writeln('done          : ', k = 0)
end.
