{ ISO 7185 6.6.5.4's pack and unpack each write one of their arguments, and
  6.9.4 e) makes that argument threatened -- so it may not be a protected
  parameter (ISO/IEC 10206:1991 6.7.3.1).

  Which argument that is, is the whole difference between the two procedures:
  `pack(a, i, z)` writes z and reads a, `unpack(z, a, i)` writes a and reads z.
  Both directions are here because a check that asked about the wrong argument
  would still reject one of them.

  `protected` is Extended Pascal's, so this file has to be -- but neither
  message is gated on the standard, the rule being 6.6.5.4's. }
program TransferProtected(output);
type
  u = array [1..8] of char;
  k = packed array [1..8] of char;

procedure intoPacked(a: u; protected z: k);
var i: integer;
begin
  i := 1;
  pack(a, i, z)
end;

procedure intoUnpacked(protected a: u; z: k);
var i: integer;
begin
  i := 1;
  unpack(z, a, i)
end;

begin
end.
