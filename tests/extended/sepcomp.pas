{ ISO/IEC 10206:1991 6.13: the program-components of a program-block, accepted
  separately.

  This is the component holding the main-program-declaration. The other one is
  components/counter.pas, translated on its own before this one; the harness
  passes it with --import, and what this translation reads of it is its
  module-heading. Nothing else about it is available here, and nothing else is
  needed: 6.11.1 puts the whole interface in the heading.

  Three things the output pins, and each is a fact about the *boundary* rather
  than about modules:

  - `tally` starts at 100. Nothing in this component writes that; the other
    one's `to begin do` does, and 6.2.3.6 orders its commencement before the
    main-program-block's. So an initialization-part runs across a component
    boundary.
  - `counter finalizing` is written *after* this block ends, by the other
    component's `to end do`, to the `output` this component declares. The two
    halves of that sentence are the interesting part: the file belongs to this
    program-block and the writing happens in a translation that never saw it.
  - `ticks` counts calls to `bump`, which increments a variable of the module
    that no interface names. This component cannot mention `hidden` at all --
    it does not know it exists -- which is the reason a frame index is not a
    thing two translations can exchange.

  What is *not* tested here is any file format for an interface, because there
  is none: the artefact is the other component's source. }
program SepComp(output);

{ Two interfaces, each exporting a variable called `tally`. They are different
  variables of different modules, so the second arrives under another spelling
  -- and what keeps their *storage* apart is that a linkage name is built from
  the interface's name as well as the constituent's. See components/gauge.pas. }
import counting;
       gauging (tally => reading);

begin
  writeln('tally at commencement: ', tally:1);

  bump(7);
  writeln('after bump(7): ', tally:1, ', ticks = ', ticks:1);

  bump(5);
  writeln('after bump(5): ', tally:1, ', ticks = ', ticks:1);

  clear;
  writeln('after clear: ', tally:1, ', ticks = ', ticks:1);

  bump(3);
  writeln('after bump(3): ', tally:1, ', ticks = ', ticks:1);

  sample(4);
  writeln('gauge reading: ', reading:1);

  writeln('program body done')
end.
