{ §6.7.5.6: "It shall be a dynamic-violation if the variable is already bound to
  an external entity." Only the running program knows, so this one is a stop
  rather than a diagnostic — unlike "the variable is not bindable", which is a
  property of the declaration and is reported where it is written. }
program TrapBindTwice(output);
type btext = bindable text;
var f: btext;
    b: BindingType;
begin
  b.name := '/tmp/apascal_bindtwice.txt';
  bind(f, b);
  { E.16 (ADR-0172): the variable is bound to an external entity when the
    entity exists, so the file is created before the second attempt -- a
    name nothing is at may be bound again, bind_missing.pas }
  rewrite(f);
  writeln('first ok');
  { NOTE 7 permits unbind on a variable that is not bound, so binding again
    after one would be fine — this one does not. }
  bind(f, b);
  writeln('not reached')
end.
