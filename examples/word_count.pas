{ Count the lines, words and characters of a text file, like wc(1).

  Nothing here is dialect-specific except the string capacity: `readln`
  fills a `string(n)` and skips whatever did not fit (6.9.1), so the
  capacity a reader declares is a decision -- 4096 is a line no editor
  wraps, and a longer one is counted short. Run it as

      pascalcc word_count.pas -o wc && ./wc < some.txt

  The harness feeds `word_count.in` to standard input. }
program word_count(input, output);

type LineBuf = string(4096);

var
  line: LineBuf;
  lines, words, chars, longest, k: integer;
  inWord: boolean;

begin
  lines := 0;
  words := 0;
  chars := 0;
  longest := 0;
  while not eof do begin
    readln(line);
    lines := lines + 1;
    chars := chars + length(line) + 1;    { the newline counts }
    if length(line) > longest then longest := length(line);
    inWord := false;
    for k := 1 to length(line) do
      if line[k] = ' ' then
        inWord := false
      else if not inWord then begin
        inWord := true;
        words := words + 1
      end
  end;
  writeln(lines:6, words:6, chars:6);
  writeln('longest line: ', longest:1, ' characters')
end.
