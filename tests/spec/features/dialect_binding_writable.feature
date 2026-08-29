# AP 6.4.3.4.7 -- the third field of BindingType.
#
# ISO/IEC 10206:1991 §6.4.3.4 NOTE 7 permits a processor to add fields to
# BindingType as an extension. This is the dialect's one, and what it answers
# is the question the standard leaves a program no way to ask: §6.7.5.6's
# NOTE 2 offers `bound` to a program about to *read*, and a program about to
# write had nothing. §6.7.5.2 leaves the activities on the external entity
# implementation-defined, and this processor's choice where one cannot be
# created is to stop the program -- which the last scenario here is.
#
# Nothing below creates a file. The scenarios name /tmp, which POSIX requires
# to exist, and ask about a name in it without writing there; every other name
# is under a directory no machine has.

@afterschool:6.4.3.4.7
Feature: A third field of BindingType

  Scenario: a name nothing is at, in a directory that would admit it
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: bindable text; b: BindingType;
      begin
        b := binding(f);
        b.name := '/tmp/ap-spec-6-4-3-4-7-never-created';
        bind(f, b);
        b := binding(f);
        writeln('bound=', b.bound, ' writable=', b.writable)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      bound=FALSE writable=TRUE
      """

  Scenario: a name under a directory that is not there
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: bindable text; b: BindingType;
      begin
        b := binding(f);
        b.name := '/no-such-directory-at-all/f.txt';
        bind(f, b);
        b := binding(f);
        writeln('bound=', b.bound, ' writable=', b.writable)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      bound=FALSE writable=FALSE
      """

  Scenario: a variable bound to nothing reports false
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: bindable text;
      begin
        writeln('writable=', binding(f).writable)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      writable=FALSE
      """

  Scenario: the field lets a program avoid the stop the standard leaves it
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: bindable text; b: BindingType;
      begin
        b := binding(f);
        b.name := '/no-such-directory-at-all/f.txt';
        bind(f, b);
        if binding(f).writable then rewrite(f)
        else writeln('refused, and still running');
        writeln('reached the end')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      refused, and still running
      reached the end
      """

  Scenario: and a program that does not ask is stopped, as before
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: bindable text; b: BindingType;
      begin
        b := binding(f);
        b.name := '/no-such-directory-at-all/f.txt';
        bind(f, b);
        rewrite(f);
        writeln('not reached')
      end.
      """
    When it is compiled and run
    Then it stops at run time
