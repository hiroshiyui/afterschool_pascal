# `tests/checks/importdiag/` — a diagnostic about an imported component

Two sources for one probe in `selfhost/producttest.sh`, and they are here
rather than under `tests/` for the same reason `stdannot/` is: **the ordinary
harness cannot express this case.**

`run_test.sh` translates every `name.components` entry *separately, first*, and
gives up if one of them fails — which is right, and which means a case can
never reach the state this probe needs: a component that does **not** translate
on its own, handed to `--import` anyway.

That state is reachable by a person. `--import` re-parses each component's full
source and `CheckModuleBlock` runs over it in the client, so the client reports
the component's errors. Until ADR-0210 it reported them against the *client's*
file name with the *component's* line numbers — a position the named file need
not even have, and `client.pas:15:3` for a three-line `client.pas` is what the
probe pins.

- `badmod.pas` — a module whose implementation assigns a string to an integer.
  It does not translate on its own, which is the whole point.
- `client.pas` — three lines, imports it, and has nothing wrong with it.
- `badclient.pas` — imports the same module and has an error of *its own*, so
  the probe fails in both directions: a fix that named the component for
  everything would pass the first half and fail this one.
