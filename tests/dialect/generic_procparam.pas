{ ADR-0260: a generic taking a **procedural** parameter, instantiated twice.

  AP 6.7.3.10.2 translates a generic once per tuple, and the heading's nodes
  are shared between those translations -- so ADR-0211 runs ForgetResolved
  over them, which is ADR-0039's remedy for the same problem in a schema: a
  resolved denoter caches its type, and without forgetting it the second
  instantiation reads the first one's answer.

  It walked past a procedural parameter. Such a group has no `grType` at all;
  its types are in a formal-parameter-list of its own and in its result, and a
  loop over `grType` never reaches them. So the second instantiation below
  used to see the *first* one's key type, and `ChHash` was refused as
  incongruent with a `hash` whose parameter was `integer` -- a diagnostic
  about a type that appears nowhere in the activation being complained about.

  Found by writing `PasContainer`'s key-generic map, which is the only client
  here that puts a type-inquiry inside a procedural parameter. The two
  together are what makes the omission visible: without the inquiry the
  procedural parameter's types do not depend on the tuple, so forgetting them
  changes nothing. }
program generic_procparam(output);

type
  Holder(K: type; cap: integer) = record
    slots: array [1..cap] of record theKey: K end
  end;
  IntHolder = ^Holder(integer);
  ChHolder = ^Holder(char);

{ The key's type is read off the container (AP 6.4.9, ADR-0215), and so is the
  hash's own parameter type -- which is what makes a hash for the wrong key
  type a congruence error rather than something accepted and misused. }
procedure Keep(Ptr: type; var m: Ptr;
               key: type of m^.slots[1].theKey;
               function hash(k: type of m^.slots[1].theKey): integer);
begin
  m^.slots[1].theKey := key;
  writeln('kept, hashed ', hash(key):1)
end;

function IntHash(k: integer): integer;
begin IntHash := k + 1 end;

function ChHash(k: char): integer;
begin ChHash := ord(k) end;

var a: IntHolder; b: ChHolder;
begin
  new(a, 2);
  new(b, 2);
  { Two tuples, two translations. The second is the one that was wrong. }
  Keep(a, 41, IntHash);
  Keep(b, 'A', ChHash);
  writeln('a=', a^.slots[1].theKey:1, ' b=', b^.slots[1].theKey);
  dispose(a);
  dispose(b)
end.
