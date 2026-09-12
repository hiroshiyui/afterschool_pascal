# AP 6.1.3 and AP 6.7.5.7: the two extensions the specification did not state.
#
# Both were carried in `doc/implementation-defined.md` §5 as extensions to
# ISO 7185 with no clause of their own, for as long as each has existed, so a
# reader holding the specification alone did not know either was legal
# (AP 5.7 NOTE 1). These are the scenarios 5.5 d) asks for now that they have
# clauses -- and the first of them is also what corrected the clause: the
# writer's draft refused a leading `_` and `_` alone, and the processor admits
# both.
Feature: the underscore, and halt's exit status

  # 6.1.3. The character in every position it may take, and the reason it may
  # take all of them: no conforming program can write it anywhere.
  @afterschool:6.1.3
  Scenario: an identifier may contain an underscore, begin with one, or be one
    Given the Afterschool Pascal program
      """
      program p(output);
      var my_name, _lead, _, a_b_: integer;
      begin
        my_name := 1; _lead := 2; _ := 4; a_b_ := 8;
        writeln(my_name + _lead + _ + a_b_:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      15
      """

  # 6.1.3 NOTE 2: what it is for. `set` is a word-symbol §6.1.2 reserves, so
  # there is no way to write a variable of that name in either standard.
  @afterschool:6.1.3
  Scenario: an underscore gives back a name a word-symbol has taken
    Given the Afterschool Pascal program
      """
      program p(output);
      var set_, label_, packed_: integer;
      begin set_ := 1; label_ := 2; packed_ := 3;
        writeln(set_ + label_ + packed_:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      6
      """

  # 6.7.5.7. `halt` alone is §6.7.5.7's own procedure and still exits 0; the
  # form with an argument is the extension, and the status is what the program
  # terminates with.
  @afterschool:6.7.5.7
  Scenario: halt takes the status the program terminates with
    Given the Afterschool Pascal program
      """
      program p(output);
      begin
        writeln('before');
        halt(7);
        writeln('after')
      end.
      """
    When it is compiled and run
    Then it prints
      """
      before
      """

  # The other half, and the one a wrong implementation could pass the first on
  # its own: `halt` with no argument terminates with 0, as it always did.
  @afterschool:6.7.5.7
  Scenario: halt alone terminates successfully
    Given the Afterschool Pascal program
      """
      program p(output);
      begin
        writeln('done');
        halt
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      done
      """
