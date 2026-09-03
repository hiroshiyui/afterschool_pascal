{ AP 6.7.8.1: a task is handed a socket (ADR-0302).

  ADR-0268's own list of what two threads of control left open opened with
  this row, and ADR-0267 -- a handle moves -- was landed *for* it one
  increment early. What was missing was the position: AP 6.4.14.6 admitted
  `take` on the right of an assignment and nowhere else, so a socket could be
  moved from one variable to another and not into a task.

  A handle crossing into a task is **moved**, where a channel is lent, and the
  difference is what makes each safe. A channel is the one object two
  activations may name and it has a lock in it; a socket has not, so what
  crosses is ownership. The spelling says so: `spawn Serve(take(conn), back)`,
  and `conn` is empty from that point on.

  **This talks to itself**, for `lib_net.pas`'s reason: a test that needed a
  second machine would be a test of the environment. The port is service `'0'`
  and never printed. The task reads a line the main activation wrote, sends
  what it read back through a channel, and closes that channel -- which is
  AP 6.4.16.4, the other half of this change, and what lets the reader's loop
  end. The connection is closed by the *task's* block, the handle having been
  released where the variable holding it ceased to exist. }
program task_handle(output);

import PasError; PasNet;

type Reply = channel [4] of NetLine;

{ The task owns the connection. Nothing here releases it: the value is
  released when this block's activation ends, which is the ordinary rule for
  a handle-variable and needs nothing said. }
task Serve(conn: Socket; back: Reply);
var line: NetLine; e: ErrorCode; k: integer;
begin
  e := NetReadLine(conn, line);
  if e = errNone then send(back, 'the task read: ' + line);
  e := NetWriteLine(conn, 'answered by the task');
  if e = errNone then send(back, 'the task wrote back');
  k := release(back)
end;

var srv, cli, conn: Socket;
    port: ServiceName;
    e: ErrorCode;
    back: Reply;
    line, got: NetLine;

begin
  e := NetListen(srv, 'localhost', '0');
  writeln('listening     : ', e = errNone);
  e := NetService(srv, port);
  e := NetConnect(cli, 'localhost', port);
  writeln('connected     : ', e = errNone);
  e := NetWriteLine(cli, 'hello from the program');
  e := NetAccept(srv, conn);
  writeln('accepted      : ', (e = errNone) and (conn <> nil));

  { The move. The variable is emptied before the activation commences, so at
    no moment do two activations hold one socket. }
  spawn Serve(take(conn), back);
  writeln('source emptied: ', conn = nil);

  while receive(back, got) do writeln(got);

  e := NetReadLine(cli, line);
  writeln('client read   : ', line);
  NetClose(cli);
  NetClose(srv)
end.
