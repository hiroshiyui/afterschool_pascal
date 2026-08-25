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

  **What it is not.** There is no datagram socket, no timeout, no shutdown of
  one direction, and no way to wait on several connections at once: a program
  serving two clients at a time needs something this language does not have
  (ADR-0201), and everything here is written for one connection at a time. A
  server that accepts, serves and closes in a loop is what it is for. }

module PasNet;

export PasNet = (HostName, ServiceName, NetLine, Socket,
                 Connect, Listen, Accept, Service,
                 WriteText, WriteLine, ReadLine, Close);

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

function Opened(var s: Socket; status: integer): ErrorCode;
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

end.
