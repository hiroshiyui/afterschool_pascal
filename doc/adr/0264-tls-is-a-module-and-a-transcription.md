# ADR-0264: TLS is a module, and the only new risk is a transcription

Date: 2026-08-30

## Status

Accepted. Closes the last unstruck row of `doc/roadmap.md` §3, *What a daily
program still cannot reach for*, and corrects that row for the second time.

## Context

The row said TLS was blocked, and gave two grounds. Both were written without a
probe and both are wrong.

**"It means binding a C library, which puts the whole of that library's surface
behind ADR-0185's rule that a library may not declare a foreign struct."**
OpenSSL's client interface is opaque pointers throughout — `SSL_CTX *` and
`SSL *` are incomplete types in the headers, and every operation on one is a
function. That is AP 6.4.12's handle exactly, with `SSL_CTX_free` and `SSL_free`
as the closers. No struct is declared here, so ADR-0185 has nothing to refuse.

**"The runtime would have to link a cryptography library."** The runtime links
nothing and gains nothing here. `libpasrt.a` is unchanged; the **program**
links, and a program that imports no TLS links no OpenSSL. The seam already
existed — `AFTERSCHOOL_PASCAL_CFLAGS`, which ADR-0261's sanitizer gate uses to
reach the link.

A complete handshake was run before any of this was written: TCP, certificate
verification, `SSL_write`, `SSL_read`, against a local server, from an ordinary
program with no change to the compiler and none to the runtime.

**And the probe walked into a real defect on its way**, which is recorded
separately as ADR-0263: AP 6.7.7.11 scopes its one-declaration-per-symbol rule
to one program-component and the compiler was enforcing it over the whole
compilation, so a program could not bind a foreign routine any module it
imported bound privately. `PasNet` holds `pasx_socket_fd`, which this module
needs, so nothing below could have been written until that was fixed.

### What is actually new, and it is one thing

Six of the values this module hands OpenSSL are **transcribed from headers**,
because each is a macro or a bare `#define` and no `external` declaration can
reach one:

| Name here | The header's |
| --- | --- |
| `CtrlSetHostName` | `SSL_CTRL_SET_TLSEXT_HOSTNAME` |
| `NameTypeHost` | `TLSEXT_NAMETYPE_host_name` |
| `CtrlSetMinProto` | `SSL_CTRL_SET_MIN_PROTO_VERSION` |
| `VersionTls12` | `TLS1_2_VERSION` |
| `VerifyPeer` | `SSL_VERIFY_PEER` |
| `VerifyOk` | `X509_V_OK` |

Two more (`SSL_ERROR_ZERO_RETURN`, `SSL_ERROR_SYSCALL`) are transcribed for the
same reason and matter less.

`SSL_set_tlsext_host_name` and `SSL_CTX_set_min_proto_version` are macros over
`SSL_ctrl` and `SSL_CTX_ctrl`, both of which are ordinary exported functions —
so what this language cannot spell is the *number*, not the call. That is
`CLOCKS_PER_SEC`'s hazard, which `PasProcess` already carries.

**A wrong number here does not fail loudly.** `SSL_ctrl` with a command it does
not recognise answers 0 and the module reports a refusal, which is at least
visible. `SSL_VERIFY_PEER` transcribed as 0 is `SSL_VERIFY_NONE`: verification
is off, every handshake succeeds, and a test suite that only ever meets good
certificates stays green. That is the shape of defect this repository exists to
refuse, and no golden can see it.

## Decision

**`lib/dialect/pastls.pas` binds OpenSSL directly, and a check compiles a C
program against OpenSSL's own headers to judge the numbers it transcribed.**

### The module

A client, and only a client. `Connection` is a record holding three handles —
the TCP socket, the context and the session — so the block that declared it
releases all three, and lib/dialect/README.md's third rule then applies: an
owned value is filled through a `var` parameter and never returned.

The line buffer is **Pascal**, not C. `SSL_read` is handed a slice of an
ordinary `array [1..n] of char` (AP 6.7.7.7), so the buffering `PasNet` does in
40 lines of `runtime/pasrt_posix.c` is done here in about thirty lines of this
language, and no translation unit is added. That is what keeps OpenSSL out of
the runtime, and it is the reason the module could be written at all.

`PasNet` is imported **qualified**. Five of its exported names — `Connect`,
`Close`, `WriteText`, `WriteLine`, `ReadLine` — are five of this module's, and
that is the property worth keeping rather than an obstacle: a program moving
from a socket to a TLS connection changes the type of a variable and nothing
else.

### Verification cannot be turned off

There is no flag, no mode and no second entry point that skips it. Every
connection checks the chain to an anchor, checks that the chain is valid now,
and checks that the certificate is for the host that was asked for. TLS 1.2 is
the floor.

What a caller chooses is *which anchors*: `Connect` uses the system's,
`ConnectTrusting` uses one PEM file and nothing else. **A self-signed
certificate is its own anchor**, so the case that usually motivates an insecure
flag — a test server, a box on a private network — is reached by naming that
certificate, which is a stronger statement than switching checking off and is
no more work.

The alternative considered was a `verify: boolean` parameter or a
`ConnectUnverified`. Both were rejected on the same ground: the commonest way a
TLS client comes to accept anything is a flag somebody set while debugging, and
a boolean `false` reads as nothing at a call site. A door that is not there
cannot be left open.

### The name goes out twice

`host` is sent as the server-name indication *and* is what the certificate is
checked against. Only the first is skipped for an address literal, RFC 6066 §3
forbidding one there; the check is made either way, and `SSL_set1_host` handles
an address against an IP subjectAltName without a second binding.

### The gate

`tests/checks/tls.sh`, and it asks two questions of different kinds.

The **constants** half is `foreign-layout`'s shape (ADR-0185) applied to
numbers rather than to offsets: a C program including OpenSSL's real headers
prints what they say, the Pascal source is read for what it claims, and the two
are diffed. It also counts — eight rows, or it fails — because a constant
renamed in the source is a constant this check stops looking at.

The **behavioural** half runs a program against two servers, and the second
server is the whole reason there are two: it presents a certificate whose chain
verifies perfectly and whose name is `other.example`, connected to as
`localhost`. That is the case a client checking only the chain gets wrong, and
it is the one a single-server test cannot pose.

**No golden here holds anything OpenSSL wrote.** A reason string is that
library's wording and moves between releases; so does the cipher list on
`s_server`'s status page. What is printed is the ErrorCode, whether a reason was
recorded, and the *shape* of the protocol name.

A third half runs the same program under LeakSanitizer, because eleven
connections are made and every one holds three handles, and nothing else here
can see a release that did not happen: `heap-balance` (ADR-0183) counts
`pas_new` against `pas_dispose`, and OpenSSL allocates through neither.

### `AFTERSCHOOL_PASCAL_LDFLAGS`

`tools/pascalcc` gains a second flag variable, for the link alone.
`AFTERSCHOOL_PASCAL_CFLAGS` reaches every `clang` and is deliberately blunt —
that is what a sanitizer needs — but `-lssl` handed to a `clang -c` is an input
clang has nothing to do with, and it says so once per translation. A program
binding a foreign library needs the flag in exactly one place. It is appended
**after** `libpasrt.a`, because a static archive is searched once and satisfies
only what has already been referenced.

## Consequences

`tests/checks/tls.sh` skips 77 without libssl or the `openssl` program, neither
of which is a documented dependency of this repository; `TLS_REQUIRE` is how a
CI job refuses to pass by skipping, as `TARGET_SIZES_REQUIRE` and
`UNICODE_CONFORMANCE_REQUIRE` do.

The probe source is `tests/checks/tls/tls_probe.pas` and its golden is
`tls_probe.expected` rather than `tls_probe.out`, because `selfhost/irtest.sh`
sweeps every `.pas` under `tests/` and runs the ones carrying an `.out` or an
`.err`. This one needs two servers and a library nothing else here links.
`target_layout.pas` and `foreign_layout_stat.pas` already sit under
`tests/checks/` on the same footing.

Two mutations were made and each is caught by the half it should be:
`VerifyPeer = 1` changed to 0 fails the constants diff, and it fails *only*
there — every behavioural case stays green, which is the argument for that half
existing. Removing the `SSL_set1_host` call leaves the constants green and
fails the behavioural golden at *right chain, wrong name*, and at nothing else.

### What it does not do

No server side, no client certificate, no session resumption, no
renegotiation, and **no revocation checking** — neither CRLs nor OCSP. A caller
for whom revocation matters wants more than this module, and the module says so
rather than leaving it to be discovered.

`SSL_get_verify_result` is checked after the handshake although
`SSL_VERIFY_PEER` has already failed the handshake on a bad chain. It is
therefore not reached by anything in the corpus, which is stated at the call
site rather than argued away: it costs one call, and the property it states is
the one this module exists for.

**`PasHttp` still speaks plain HTTP only.** It writes to a `PasNet.Socket`, and
making it speak both would mean importing this module — so every program using
HTTP would link OpenSSL. The way to close that is to split `PasHttp`'s grammar
from its transport, which is a change to that module and not to this one, and
it is now the entry in `doc/roadmap.md` that this row leaves behind.

### What nothing here checks

Nothing compares an `external` declaration against the routine it names
(AP 6.7.7.8 NOTE, `doc/sop.md` §7), and this module has twenty-four of them.
The constants gate closes the one part of that surface which is a *value* this
repository wrote down; the signatures remain unchecked claims, as every
`external` in `lib/dialect/` is.
