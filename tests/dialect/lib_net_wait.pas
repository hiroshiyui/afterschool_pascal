{ NetWait: one thread of control serving more than one connection
  (ADR-0205).

  **What this pins is the thing a server could not do before.** ADR-0203 left
  `PasNet` able to accept, serve and close one connection at a time, because
  `ReadLine` blocks and a server holding two clients cannot know which of them
  has spoken. Here client two speaks and client one says nothing, so a server
  reading them in turn would stop on client one and never reach the line that
  is waiting -- which makes this a test that **hangs** when `NetWait` is wrong,
  rather than one that prints the wrong thing.

  **The sockets live in the array.** A handle has exactly two assignments
  (AP 6.4.12.2) and neither is `a := b`, so nothing is ever copied into
  `watch`: `NetListen` and `NetAccept` are handed the element itself, and the array
  owns what they put there. Slot 1 is the listening socket and the rest are
  connections, which is what lets one `NetWait` answer both "somebody has
  arrived" and "somebody has spoken" -- to `poll` they are one question.

  **An empty slot is a hole, and needs no compaction.** Closing a connection
  is `watch[k] := nil` (ADR-0202) and `NetWait` skips what is empty.

  The whole exchange is in one activation, for `lib_net.pas`'s reason: a test
  that needed a second machine would be a test of the environment. }
program lib_net_wait(output);

import PasError;
       PasNet;

const
  Slots = 3;        { 1 is the listener; 2 and 3 are connections }
  Patience = 2000;  { a limit and not a promise, in milliseconds }
  Rounds = 8;       { so a wrong answer ends the program instead of the suite }

var
  watch: SocketList(Slots);
  ready: array [1..Slots] of boolean;
  cli: array [1..2] of Socket;
  port: ServiceName;
  line: NetLine;
  e: ErrorCode;
  k, free, round, closed: integer;
  idle: SocketList(2);
  quiet: array [1..2] of boolean;
  clock: TimeStamp;
  before, after, elapsed: integer;
  { **What was heard, and not when.** The golden used to hold the narration in
    arrival order, and arrival order is not this program's to decide: the
    second line client two wrote is in the runtime's buffer, the reply to
    client one is on a socket, and which of the two a round finds ready is the
    operating system's answer and not the same one twice. It passed here and
    on aarch64 for as long as it existed and failed on macOS the third time
    that platform ran it (ADR-0368's first finding), which is what a golden
    pinning an interleaving is worth.

    So the lines are collected and sorted, and what is asserted is what this
    test is *for*: that all three were read -- the buffered one included, which
    nothing but `NetWait` can find -- that both connections closed, and that it
    took a bounded number of rounds. Which slot heard which, and in what order,
    was never the claim; the comment at the top says the claim is that a wrong
    `NetWait` **hangs**. }
  heard: array [1..4] of NetLine;
  heardN, i, j: integer;
  swap: NetLine;

begin
  { **The timeout is a wait and not a poll**, which nothing else here can see:
    a `NetWait` that ignored it would answer the same in every case below,
    because both ends are in this program and whatever was written has already
    arrived. A server whose readiness call did not wait would burn a
    processor, and this is the only shape that catches it -- an empty list, so
    there is nothing that could ever become ready, and a clock either side.

    §6.7.6.9's `GetTimeStamp` is second-resolution, so the wait is asked for in
    whole seconds' worth and the assertion is the weak one it can carry. }
  GetTimeStamp(clock);
  before := clock.minute * 60 + clock.second;
  e := NetWait(idle, 1200, quiet);
  GetTimeStamp(clock);
  after := clock.minute * 60 + clock.second;
  elapsed := after - before;
  if elapsed < 0 then elapsed := elapsed + 3600;   { over a minute boundary }
  writeln('idle wait: ', e.Text, ', nothing ready: ',
          not (quiet[1] or quiet[2]));
  writeln('and it did wait: ', elapsed >= 1);
  writeln;

  e := NetListen(watch[1], 'localhost', '0');
  writeln('listen:    ', e.Text);
  e := watch[1].Service(port);
  writeln('service:   ', e.Text, ', a port was given: ', port <> '');

  for k := 1 to 2 do begin
    e := NetConnect(cli[k], 'localhost', port);
    writeln('connect ', k:1, ':  ', e.Text)
  end;

  { Only the second client says anything -- and it says two lines in one
    write, which is what puts the second of them in the runtime's buffer with
    the descriptor left quiet.  Nothing but `NetWait` can find that line. }
  e := cli[2].WriteText('from two' + chr(10) + 'and again' + chr(10));
  writeln('two has spoken twice at once, one is silent');
  writeln;

  closed := 0;
  round := 0;
  heardN := 0;
  while (closed < 2) and (round < Rounds) do begin
    round := round + 1;
    e := NetWait(watch, Patience, ready);
    if e.Failed then begin
      writeln('wait: ', e.Text);
      closed := 2
    end
    else begin
      { Somebody arrived: the connection goes in the first free slot. }
      if ready[1] then begin
        free := 0;
        for k := 2 to Slots do
          if (free = 0) and (watch[k] = nil) then free := k;
        if free = 0 then writeln('arrived, and no room for it')
        else begin
          e := NetAccept(watch[1], watch[free]);
          writeln('accepted into slot ', free:1, ': ', e.Text)
        end
      end;

      { And whoever spoke is read.  Nothing here waits on a particular one. }
      for k := 2 to Slots do
        if ready[k] then begin
          e := watch[k].ReadLine(line);
          if e = errAbsent then begin
            { Which of the two closes first is the same question as above,
              and the count below is the assertion. }
            watch[k] := nil;
            closed := closed + 1
          end
          else begin
            if heardN < 4 then begin
              heardN := heardN + 1;
              heard[heardN] := line
            end;
            { The other half of the conversation, driven by what was heard.
              The actions stay where they were -- it is only the narration
              that moved, the reply to client one being what makes the next
              round's readiness a race. }
            if line = 'from two' then
              e := cli[1].WriteLine('from one')
            else if line = 'and again' then
              cli[2] := nil
            else if line = 'from one' then
              cli[1] := nil
          end
        end
    end
  end;

  { Sorted, so what is printed is the set and not the schedule. }
  for i := 1 to heardN - 1 do
    for j := 1 to heardN - i do
      if heard[j] > heard[j + 1] then begin
        swap := heard[j];
        heard[j] := heard[j + 1];
        heard[j + 1] := swap
      end;
  for i := 1 to heardN do writeln('heard: ', heard[i]);

  writeln;
  writeln('closed:    ', closed:1);
  writeln('in rounds: ', round < Rounds)
end.
