program Control(output);

var
  i, n, sum: integer;
  c: char;

begin
  sum := 0;
  for i := 1 to 10 do
    sum := sum + i;
  writeln('sum 1..10 = ', sum);

  for i := 3 downto 1 do
    write(i:2);
  writeln;

  for c := 'a' to 'e' do
    write(c);
  writeln;

  n := 1;
  while n < 100 do
    n := n * 3;
  writeln('first power of 3 over 100: ', n);

  n := 0;
  repeat
    n := n + 7
  until n mod 5 = 0;
  writeln('first multiple of 7 divisible by 5: ', n);

  for i := 1 to 15 do
    begin
      if (i mod 3 = 0) and (i mod 5 = 0) then
        write('FizzBuzz')
      else if i mod 3 = 0 then
        write('Fizz')
      else if i mod 5 = 0 then
        write('Buzz')
      else
        write(i);
      if i < 15 then
        write(' ')
    end;
  writeln
end.
