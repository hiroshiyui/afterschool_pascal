{ PasNet -- a TCP connection, as a handle and a line at a time.

  **What a socket is here.** A descriptor is an integer, and AP 6.4.2.6.2
  makes an integer numeric on purpose -- so a program holding one could add to
  it, copy it and close it twice, which is exactly the door ADR-0151 records
  as open and unclosable for `int64`. So the runtime owns the object and this
  module hands out a **handle** (AP 6.4.12): no copy, no comparison but with
  `nil`, and `closedir`'s discipline -- the connection is closed when the
  variable holding it dies, or when the program says `s := nil` (ADR-0202).

  **No address, no port number, no family.** Both ends of every call are
  strings, and `getaddrinfo` decides what they mean: a host and a *service*,
  where a service is a name (`http`) or a number written out (`8080`). That is
  what keeps `<netinet/in.h>`, `htons` and the choice between IPv4 and IPv6
  out of this module and out of the runtime beneath it -- and it is what makes
  an ephemeral port expressible: ask for service `'0'`, then ask `Service`
  which one you were given, and hand that string back to `Connect`.

  **A line at a time**, because a socket delivers whatever arrived and a
  Pascal program wants a line. The buffering is in the runtime, and it is
  there rather than in `FILE *` because a stream opened for update over a
  descriptor that cannot seek may not switch between reading and writing
  without a file-positioning call -- which a socket has not got. `ReadLine`
  strips a newline and a carriage return before it, so a line written by a
  program on either side of the network reads the same.

  **This module is a binding** in lib/dialect/README.md's sense: it exports
  Pascal and keeps the `external` directive to itself. What it binds is the
  runtime's `pasx_socket_*` and not the operating system's, for ADR-0185's
  fifth decision -- `struct sockaddr` is not the same struct on two systems
  and a library may not declare one.

  **Several connections at once, in one thread of control.** `Wait` answers
  which of a list of sockets can be served without blocking, and a listening
  socket in that list is ready when a connection is waiting -- so a server is
  an ordinary loop over `Wait`, `Accept` and `ReadLine`, and needs no
  concurrency construct (ADR-0205). That closes what this comment used to say
  was the module's honest limit; ADR-0201's construct is still not here and is
  still not what this needed.

  **What it is not.** There is no datagram socket, no shutdown of one
  direction, and no TLS. A connection is served by whoever called `Wait`,
  which means a slow client is served slowly by the same thread as everyone
  else -- what `Wait` removes is *blocking on the wrong one*, not the single
  thread. }

module PasNet;

export PasNet = (HostName, ServiceName, NetLine, Socket, SocketList,
                 Connect, Listen, Accept, Service,
                 WriteText, WriteLine, ReadLine, Close, Wait);

import PasError;

const
  { POSIX's HOST_NAME_MAX is 255 and a domain name may be that long; the
    service is a name or a number and is far shorter. }
  HostMax = 255;
  ServiceMax = 63;
  { What the runtime's line buffer holds. A longer line is `errFull` and the
    line is lost, there being nothing to put it back into. }
  LineMax = 4096;

type
  HostName = string(HostMax);
  ServiceName = string(ServiceMax);
  NetLine = string(LineMax);

  { An open connection, or a socket listening for them. `pasx_socket_close`
    closes the descriptor and frees what the runtime holds. }
  Socket = handle external 'pasx_socket_close';

  { The sockets a server is watching, however many it decided on: a schema
    (ISO/IEC 10206:1991 6.4.8), so `SocketList(64)` and `SocketList(4)` are
    one type to `Wait` and the discriminant is what it reads for the count.

    An empty element is a slot nobody is using, and `Wait` skips it -- so a
    server that closes a client by `clients[k] := nil` leaves a hole and needs
    no compaction. The array **owns** what it holds (AP 6.4.12 NOTE 3): every
    element still open is closed when the variable dies. }
  SocketList(n: integer) = array [1..n] of Socket;

  { How a string stops being a C pointer (ADR-0123). Not exported: a caller
    passes a string of its own and the copy is made at the call site. }
  OptLine = ?NetLine;
  OptService = ?ServiceName;

{ Connect to `host` at `service`. `errAbsent` where neither resolved,
  `errIO` where the system refused every address they resolved to -- the
  first is a name nobody knows and the second is a machine that would not
  talk, which a caller reports differently.

  What `s` held before is released first, whichever way this answers. }
function Connect(var s: Socket; host: HostName; service: ServiceName):
  ErrorCode;

{ Listen for connections on `host` at `service`. `'0'` asks for whatever port
  is free, which `Service` then reports.

  The same two failures, and the same release of what `s` held. }
function Listen(var s: Socket; host: HostName; service: ServiceName):
  ErrorCode;

{ The next connection to a listening socket, as a socket of its own. Blocks
  until one arrives. `errIO` if the system refused.

  `srv` goes on listening and `conn` is the connection: two handles, two
  lifetimes, and closing one does not close the other. }
function Accept(var srv: Socket; var conn: Socket): ErrorCode;

{ The service this socket is bound to, as the numeric string `Connect` takes.

  It is how a program that asked for `'0'` learns which port it was given,
  which is the whole of what a test needs to talk to itself. `errFull` where
  the caller's string is shorter than the answer. }
function Service(var s: Socket; var name: string): ErrorCode;

{ The characters of `text`, nothing appended. `errIO` on a refusal -- which
  includes the far end having closed, that being a refusal a caller can act
  on rather than the signal it would otherwise be. }
function WriteText(var s: Socket; text: NetLine): ErrorCode;

{ The characters and then a newline. }
function WriteLine(var s: Socket; text: NetLine): ErrorCode;

{ The next line into `line`, without its terminator.

  `errNone` and `line` holds it; `errAbsent` when the far end has closed and
  nothing was left, which is the ordinary end of a loop; `errFull` for a line
  longer than `line` can hold or longer than the runtime buffers, whose
  characters are discarded, there being nowhere to keep them; `errIO` for a
  refusal.

  A final line the far end sent without a newline **is** a line: a socket has
  no obligation to end with one.

  `line` is set to the null-string on every answer but `errNone`. }
function ReadLine(var s: Socket; var line: string): ErrorCode;

{ Close now rather than at the block's end, and leave `s` empty. Harmless on
  an empty one, and the socket may be opened again through the same variable. }
procedure Close(var s: Socket);

{ Which of `socks` can be read, or accepted from, without blocking: `ready[k]`
  is set for each one that can, and cleared for every other -- including the
  empty slots, which are never ready.

  This is what lets one thread of control serve several connections, and it is
  the *whole* of what that needs: a listening socket in the list becomes ready
  when a connection is waiting, so `Accept` and `ReadLine` are both answered by
  the same call. A server is then a loop -- wait, accept what arrived, read
  from whoever spoke, close whoever left.

  `timeoutMs` is a limit and not a promise: negative waits until something is
  ready, zero asks and returns at once, and a positive number waits at most
  that long. Answering `errNone` with nothing in `ready` is the ordinary way a
  timeout reports, and is not a failure.

  **A socket holding a line the runtime has already read is ready**, which the
  operating system cannot tell you: those bytes are off the socket, so the
  descriptor is quiet while `ReadLine` would answer at once. Waiting on the
  descriptor alone is how a server comes to sit still holding a line it was
  handed, and it is why this is a call of this module rather than a binding to
  `poll`.

  `errFull` where `ready` is shorter than `socks` has elements; `errIO` where
  the system refused. }
function Wait(var socks: SocketList; timeoutMs: integer;
              var ready: array of boolean): ErrorCode;

end;

{ The directive, kept to this module. Every one of these is the runtime's:
  what a library may not do is declare `struct sockaddr`, and every call below
  would need one (ADR-0185). }

{ 0 with a socket, 1 the name or service did not resolve, 2 refused. }
function ExtConnect(host, service: string; var status: integer): Socket;
  external 'pasx_socket_connect';
function ExtListen(host, service: string; var status: integer): Socket;
  external 'pasx_socket_listen';

{ The listening socket is *lent*, AP 6.4.12.4: what crosses is the value and
  the variable goes on owning it. }
function ExtAccept(srv: Socket; var status: integer): Socket;
  external 'pasx_socket_accept';

{ Both answer the runtime's own storage, valid until the next call, which
  ADR-0123's optional copies at the call site. `cap` is checked over there
  because the length is known over there. }
function ExtService(s: Socket; cap: integer; var status: integer): OptService;
  external 'pasx_socket_service';
function ExtReadLine(s: Socket; cap: integer; var status: integer): OptLine;
  external 'pasx_socket_readline';

{ 0, or 2 on a refusal. }
function ExtWrite(s: Socket; text: string): integer;
  external 'pasx_socket_write';

{ The readiness pair. `ExtFd` is the one place a descriptor becomes a number
  in this language, and it is **not exported**: what ADR-0203 refuses is a
  *program* holding one, AP 6.4.2.6.2 making an integer numeric so that a
  program could add to it, copy it and close it twice. Here it lives inside
  one call, in an array handed straight back to the runtime.

  `ExtPending` is the half `poll` cannot answer -- see `Wait` above. }
function ExtPending(s: Socket): integer; external 'pasx_socket_pending';
function ExtFd(s: Socket): integer; external 'pasx_socket_fd';

{ The descriptors in, the flags out, and the counts the compiler computed from
  the two slices (ADR-0129). A negative descriptor is a slot nobody is
  watching, which is what `poll` already does with one. }
function ExtPoll(var fds: array of integer; var got: array of integer;
                 timeoutMs: integer): integer;
  external 'pasx_socket_poll';

function Opened(protected var s: Socket; status: integer): ErrorCode;
begin
  if s <> nil then Opened := errNone
  else if status = 1 then Opened := errAbsent
  else Opened := errIO
end;

function Connect;
var status: integer;
begin
  status := 0;
  s := ExtConnect(host, service, status);
  Connect := Opened(s, status)
end;

function Listen;
var status: integer;
begin
  status := 0;
  s := ExtListen(host, service, status);
  Listen := Opened(s, status)
end;

function Accept;
var status: integer;
begin
  status := 0;
  conn := ExtAccept(srv, status);
  if conn <> nil then Accept := errNone else Accept := errIO
end;

function Service;
var got: OptService; status: integer;
begin
  status := 0;
  { the caller's capacity and not ServiceMax: what must not be exceeded is the
    string the answer is going into, and 6.4.3.3.3 makes that readable }
  got := ExtService(s, name.capacity, status);
  name := '';
  if got = nil then begin
    if status = 3 then Service := errFull else Service := errIO
  end
  else begin
    name := got^;
    Service := errNone
  end
end;

function WriteText;
begin
  if ExtWrite(s, text) = 0 then WriteText := errNone else WriteText := errIO
end;

function WriteLine;
var e: ErrorCode;
begin
  { one call and not two: a newline written separately is a second packet on
    the wire for no reason, and a reader that got the first would block }
  e := WriteText(s, text + chr(10));
  WriteLine := e
end;

function ReadLine;
var got: OptLine; status: integer;
begin
  status := 0;
  got := ExtReadLine(s, line.capacity, status);
  line := '';
  { The value decides the successful case and the code decides the rest, which
    is PasDir.Next's shape: a routine answering 0 with no line would be a
    defect over there, and reading `got^` for it is the trap that says so. }
  if got = nil then begin
    if status = 1 then ReadLine := errAbsent
    else if status = 3 then ReadLine := errFull
    else ReadLine := errIO
  end
  else begin
    line := got^;
    ReadLine := errNone
  end
end;

procedure Close;
begin
  { AP 6.4.12.2's second form: the release is the assignment's (ADR-0202) }
  s := nil
end;

function Wait;
var
  k, have, ms, n: integer;
  { §6.2.3.8 b): a bound written in a variable-declaration is evaluated when
    the block is activated, so these are exactly as long as the list the
    caller passed -- no fixed maximum, and no bound this module invented. }
  fds: array [1..socks.n] of integer;
  got: array [1..socks.n] of integer;
begin
  { The caller's flags are cleared whole, so what `ready` says is only ever
    about this call. }
  for k := 1 to length(ready) do
    ready[k] := false;
  if length(ready) < socks.n then
    exit(errFull);

  have := 0;
  for k := 1 to socks.n do
    if socks[k] = nil then
      fds[k] := -1                    { a slot nobody is using }
    else if ExtPending(socks[k]) <> 0 then begin
      { A line is already off the socket and in the runtime's buffer, so the
        descriptor is quiet and there is nothing to ask the system about it. }
      ready[k] := true;
      have := have + 1;
      fds[k] := -1
    end
    else
      fds[k] := ExtFd(socks[k]);

  { Something can be served already, so the wait is over before it begins --
    but ask anyway, with no timeout, so one call reports everything that is
    ready rather than only the buffered half. }
  if have > 0 then ms := 0 else ms := timeoutMs;

  n := ExtPoll(fds[1..socks.n], got[1..socks.n], ms);
  if n < 0 then
    exit(errIO);
  for k := 1 to socks.n do
    if got[k] <> 0 then
      ready[k] := true;
  Wait := errNone
end;

end.
