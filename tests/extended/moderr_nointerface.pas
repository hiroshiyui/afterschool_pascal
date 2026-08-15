{ 6.11.1: "An interface-directive shall occur in a module-heading of a
  module-declaration if and only if a module-block does not occur in the
  module-declaration." An `implementation` component is the block half, so
  there has to be a heading half for it to implement -- and here there is
  none, this being the only component. }
module m implementation;
var v: integer;
end.
