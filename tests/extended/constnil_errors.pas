{ What a pointer constant is not.

  A constant is a value, and every one of these positions wants a *variable*.
  None of the messages below is new — each is the one that rule already gave —
  and that is the point of the file: `const q = nil` made a constant reach
  four places no constant had ever reached, and the question was whether any
  of them needed a rule of its own. None did.

  - §6.5.4's identified-variable is `pointer-variable '^'`, and §6.8.8's
    constant-access has three selector forms, none of them `^`. So `q^` is in
    neither grammar — but what refuses it is the type, and the message is the
    one message here that is *not* the one that rule already gave. §6.4.4 gives
    a pointer-type one nil-value and a set of identifying-values, and its
    NOTE 1 draws the consequence: "Since the nil-value is not an
    identifying-value, it does not identify a variable." `nil^` is therefore
    not a dereference of something that is not a pointer, which is what the
    general message would have said. Nothing had noticed, because writing a
    bare `nil^` is not something a program does and until now there was no
    other way to write one.
  - §6.7.5.3's `new` and §6.7.5.4's `dispose` each take a pointer-variable,
    and their existing messages say so.
  - §6.10.3 lists what `write` accepts, and no pointer-type is on it. The
    diagnostic names the type, which for this one is the word `nil` — §6.4.4
    gives the token no other type to be named after.

  The last two are the ordinal positions. §6.4.2.4's subrange bounds and
  §6.9.3.5's case-constants are constant-expressions under this standard
  (ADR-0054), so a constant *is* what they want — but an ordinal one, and a
  pointer is not ordinal. Both messages were written for `const s = 'ab'` and
  answer here unchanged. }
program ConstNilErrors(output);

const
  q = nil;

type
  pi = ^integer;
  bad = q..q;

var
  a: pi;
  i: integer;

begin
  i := q^;
  new(q);
  dispose(q);
  writeln(q);
  case i of
    q: writeln
  end
end.
