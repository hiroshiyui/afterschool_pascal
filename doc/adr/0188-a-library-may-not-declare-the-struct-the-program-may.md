# 188. A library may not declare the struct the program may

Date: 2026-08-25

## Status

Accepted.

## Context

ADR-0187 was written to close `doc/roadmap.md`'s last row under "What blocks
the library": a foreign routine that *answers* a struct the callee owns. It
closed it, and the record and the roadmap both said what that unblocked —
`readdir`, and with it a directory listing.

`lib/dialect/pasdir.pas` is the module that item was standing in front of. It
does not use ADR-0187, and the reason is a rule three commits older.

**ADR-0185's fifth decision: a library may not make a struct claim.** A record
crossing the boundary is a claim about *some* C compiler's layout, checkable by
`foreign-layout` on the machine you build on — and `lib/` has to work on
machines nobody here builds on. `PasFS.Info` was where that was decided:
`struct stat` is not the same struct on macOS, so the module asks a `pasx_`
routine and the target's own C compiler reads the target's own header.

`struct dirent` is the same case and worse. glibc puts an `unsigned short` and
an `unsigned char` in front of `d_name`; macOS puts a 64-bit seek offset and
two 16-bit fields; and POSIX itself requires only `d_ino` and `d_name`, **in
any order**. There is no field list a portable module could write.

That generalises further than it first looks, and the generalisation is why
this is a record rather than a paragraph in the module. `struct tm` is
*standardised* — ISO C 7.27.1 — and a library may not declare that one either,
because the same clause says the members may appear in any order. The set of
structs a library may declare is very close to empty.

So ADR-0187 is a **program**-level feature. A program knows what it was built
for and can have its claim checked by ADR-0185's gate; a module cannot, and
must not pretend otherwise. Nothing about ADR-0187 is wrong; what was wrong was
reading "readdir is declarable" as "the module can declare it".

## Decision

**`PasDir` binds `opendir` and `closedir` itself and asks the runtime for one
thing: the name.**

`opendir` and `closedir` have no struct in their signatures, so neither needs a
header and neither needs the runtime. The `DIR *` is a handle-type
(AP 6.4.12, ADR-0174) with `closedir` as its closer, which is ADR-0174's own
worked example arriving as a library at last. The whole of the runtime's
involvement is

    const char *pasx_dir_next(void *d, int cap, int *status);

whose body is `readdir` and `e->d_name`. `<dirent.h>` joins the two headers
ADR-0186 catalogued.

Three things follow, and each was a decision rather than a consequence:

**There is no entry kind, and there should not be.** `d_type` is not POSIX. It
is invisible under `_POSIX_C_SOURCE`, which is exactly what `runtime-isoc`
compiles the POSIX half with, and where it does exist it is `DT_UNKNOWN` on
filesystems that do not carry the field. So the module answers a name and a
caller composes `PasFS.Info(dir + '/' + name)` — one `stat`, and an answer that
is right everywhere. Reporting `fkOther` for an unknown type would have been a
number this module could not check, which is the same policy PasFS set over
`access`'s R_OK and W_OK.

**The capacity is checked on the far side, and that closes a §7 row for this
module.** `doc/sop.md` §7 carries "a foreign string of unstated length has no
safe reception": `PasEnv.Lookup` receives `getenv`'s answer into a `?EnvText`,
and a value longer than the capacity **stops the caller's program**, which the
routine's own result type cannot express. Here the length is not unstated —
`pasx_dir_next` holds the pointer and can call `strlen` — so the capacity
travels *in* and an over-long name comes back as `errFull` instead of as a
trap. `Next` therefore takes `var name: string`, schematic, and passes
`name.capacity`: the bound checked is the caller's own, not a constant this
module chose. `PasEnv` could be given the same treatment and has not been.

**`Next` gives every entry and `List` skips `.` and `..`.** The iterator is
complete because an iterator that hides things cannot be built back up; the
convenience is convenient because a program deciding what to do next has no use
for those two, and skipping them makes an empty vector mean an empty directory.

The four outcomes are `PasError`'s existing codes and no new type: `errNone`
with a name, `errAbsent` at the end — which is `errAbsent`'s own gloss,
*nothing was there to return* — `errFull` for a name that did not fit, and
`errIO` for a refusal.

## Consequences

**The library list in `doc/roadmap.md` is empty and stays empty.** The
directory-listing row's fallback — `PasProcess.CaptureLines('ls -1 dir', names)`
— is superseded: it forked a shell, inherited the shell's quoting rules, and
could not tell an empty directory from a failed `ls`.

**`errFull` is reachable and reached.** `tests/dialect/lib_dir.pas` asks for
entries into a `string(2)` and gets four `errFull`s out of six entries, `.` and
`..` being the two that fit. That is worth noting because the *first* version
of this module made `name` an `EntryName` of capacity 255, under which
`errFull` could not happen on any filesystem in existence — a branch that
cannot fire is a branch nobody has checked.

**A handle is released by leaving the block, and the case says so without
being able to prove it.** `CountEntries` opens a directory into a local and
returns; nothing in the golden would change if the release never happened, only
the number of open descriptors. That property belongs to ADR-0174 and is
covered where the handle was decided, not here.

**The mutations.** Four, all killed by `lib_dir`. The runtime dropping its
length check → the over-long name becomes ADR-0123's capacity trap, exit 1.
`Next` passing `NameMax` instead of `name.capacity` → the same trap, which is
what says the schematic parameter is load-bearing and not decoration. `List`
not skipping the two dot entries → `empty count = 2`. `List` not turning
`errAbsent` into `errNone` → every listing reports *not present*.

## What this does not do

**It does not weaken ADR-0187.** A program may still declare `struct dirent`
and receive a copy of one, and on a known platform that is the better
interface — it gets `d_ino` and `d_type` in the same call. What it does not get
is portability, and `foreign-layout` with `@cplatform` is how such a program
says so.

**It does not sort, and it does not promise an order.** `readdir`'s order is
the file system's, neither sorted nor stable. `tests/dialect/lib_dir.pas` sorts
before it prints, because a golden holding the raw order would be a golden
about ext4.

**It says nothing about a directory changed while it is being read.** POSIX
does not either: whether an entry created or removed after `opendir` appears is
unspecified, and this module has no way to improve on that.

**It does not give `PasEnv` the same fix**, though the fix transfers: `getenv`'s
answer could be measured by a `pasx_` routine the same way. That is a separate
change to a module this one does not touch, and `doc/sop.md` §7's row stands
until it is made.

## Alternatives rejected

**Declaring `struct dirent` in the module and using ADR-0187.** This is the one
the roadmap's sentence invites, and it is wrong for ADR-0185's reason with no
extenuation: the struct differs on the two systems this project is most likely
to run on, and POSIX does not even fix the member order. It would have been a
module that works where it was built and silently reads the wrong bytes
elsewhere.

**A struct of *our* invention, declared in the runtime and crossed with
ADR-0187.** `struct pasx_dirent { long long ino; int kind; char name[256]; }`
would be ours, laid out by the target's own C compiler from our own
declaration, so ADR-0185's objection does not obviously apply. It was rejected
on two grounds. It carries `kind`, which would have to come from `d_type` and
therefore cannot be portable anyway; and it makes the library the first place
in this tree to cross a record, three commits after a record said libraries do
not — a rule erodes at its first exception, and this one would have been an
exception for tidiness rather than for capability. What it would have bought is
one call instead of two, in a routine that is already doing a system call.

**A boolean `Next`, as `PasStream.ReadLine` has.** It reads better in a `while`
and cannot express two of the four outcomes. `ReadLine`'s losses are an end and
a failure, which for a buffered stream are nearly the same event; here the
losses would have included `errFull`, which is a name the caller did not get
and needs to know about.

**Letting `List` continue past an over-long name.** It would answer `errNone`
having silently dropped an entry. A listing that is missing a file without
saying so is worse than one that stops.
