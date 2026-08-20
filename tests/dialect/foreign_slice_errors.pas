program foreign_slice_errors(output);

{ ADR-0129: which component types may cross inside a slice, and why the list
  is not `ForeignType`'s.

  A slice is storage the callee may *write*, so ADR-0121's argument for
  testing the type rather than `Base(t)` bites in the direction that record
  only had to consider for a result: nothing runs `checkedForSubrange` over a
  value a foreign routine put there. }

type
  small = 1..10;
  point = record x, y: integer end;

{ A subrange has its host's representation, and that is not the question:
  `read` may leave any of an i32's bit patterns in each component and none of
  them would be checked against 1..10.

  The four headings below name four different symbols, and have to: AP §6.7.7.11
  gives one linker symbol one external-declaration, and four bad slices on one
  name would report that rule four times over the rule this case is about. }
function R1(fd: integer; var b: array of small): int64; external 'read';

{ Two hundred and fifty-four of a byte's patterns are not values of boolean,
  and the compiler that would have to refuse them is not this one. }
function R2(fd: integer; var b: array of boolean): int64; external 'readv';

{ A record's layout is this compiler's, and nothing on the other side agrees
  to it. }
function R3(fd: integer; var b: array of point): int64; external 'pread';

{ A view of the caller's storage cannot be a copy -- ADR-0125's rule, and it
  is reported once, by the rule that is about slices rather than by the one
  that is about the boundary. }
function R4(fd: integer; b: array of char): int64; external 'preadv';

begin
end.
