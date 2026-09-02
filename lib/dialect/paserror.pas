{ PasError -- the vocabulary every fallible routine in the dialect answers in.

  ADR-0114's library found, three increments running, that every routine which
  can fail invents its own way of saying so: TryParseInt answers a boolean and
  writes through a `var`, MapGet takes a `whenAbsent` value, VecNew clamps a
  bad capacity in silence. Three shapes for one missing thing, and none of them
  *reports*, because a library here may not halt -- 6.9.1's read of an integer
  is an error when the text is not a number and stops the program (ADR-0076).

  ADR-0120 answers that with a shape rather than a type, and this module is the
  half of the shape that can be shared. The other half could not be, for a
  long time: with no generics a result record's payload type was part of its
  layout, so each producing module declared its own `T ! ErrorCode`, and 6.4.1
  made each such denoter a type of its own -- so one routine could serve none
  of them, and every module grew an `XOr(r, whenBad)` accessor of its own.
  `Fallible(T)` is the other half now (ADR-0297): 6.4.7 interns a production
  per tuple, so `Fallible(integer)` written in two modules is one type, and
  `ValueOr` is the one accessor, with its type inferred at the call
  (AP 6.7.3.10.4). Every result type in `lib/` is a production of it.

  This module is **dialect-only**, and that is a decision rather than an
  accident (ADR-0119, ADR-0120). Its safety comes from this dialect making a
  variant's tag authoritative (ADR-0118), which no standard Pascal does -- and
  a component holding half of that rule is worse than one holding neither, so
  the modules under lib/dialect/ are dialect all the way down. While there were
  conformance modes, ADR-0119 stopped such a module linking into a program
  compiled under one; ADR-0232 removed the modes and with them that half of the
  argument, and the other half -- a tag nobody else guarantees -- is why the
  split stands. lib/'s other modules stay Extended Pascal and stay portable. }

module PasError;

export PasError = (ErrorCode,
                   errNone, errSyntax, errRange, errAbsent, errFull, errIO,
                   ErrText, ErrorText, Failed, Fallible, ValueOr);

type
  { Short enough that a caller can put one in a fixed field without asking how
    long it is, and long enough for a sentence rather than a token. }
  ErrText = string(48);

  { Deliberately small and deliberately closed. A code is a *category* a
    caller can branch on; anything finer belongs in the message a caller
    composes, because an enumeration that grows with every producer stops
    being something a `case` can cover -- and 6.4.3.3 with ADR-0096 makes a
    variant part over one cover it exactly. }
  ErrorCode = (errNone,     { no failure -- the value of a result that is ok }
               errSyntax,   { the input was not of the form asked for }
               errRange,    { well-formed, and outside what can be represented }
               errAbsent,   { nothing was there to return }
               errFull,     { a bound the caller chose was reached }
               errIO);      { the world refused }

  { The one result type, over whatever a routine answers. A module names its
    production -- `IntResult = Fallible(integer)` -- and keeps the name; what
    the schema adds is that the name is the *same* type wherever the tuple is
    the same, which is what lets `ValueOr` below take every one of them. }
  Fallible(T: type) = T ! ErrorCode;

{ A sentence for a code, for a caller assembling a message. `errNone` has one
  too: a routine that formats a result unconditionally must not have to special-
  case the successful one. }
function ErrorText(e: ErrorCode): ErrText;

{ Whether a code reports a failure -- `e <> errNone`, spelled so that a caller
  reads the intent rather than the comparison. }
function Failed(e: ErrorCode): boolean;

{ The value of a successful result, or `whenBad` for a failed one -- for a
  caller with a sensible default that does not want to branch. `ValueOr(r, 0)`
  is the whole call: T is read off `r` (AP 6.7.3.10.4). Reading `val` here is
  safe for the reason the dialect makes it safe: the read is inside the arm
  the tag selects (ADR-0118). }
function ValueOr(T: type; res: Fallible(T); whenBad: T): T;

end;

function ErrorText;
begin
  case e of
    errNone:   ErrorText := 'no error';
    errSyntax: ErrorText := 'not of the expected form';
    errRange:  ErrorText := 'outside the representable range';
    errAbsent: ErrorText := 'not present';
    errFull:   ErrorText := 'no room left';
    errIO:     ErrorText := 'the operation was refused'
  end
end;

function Failed;
begin
  Failed := e <> errNone
end;

function ValueOr;
begin
  if res.ok then ValueOr := res.val else ValueOr := whenBad
end;

end.
