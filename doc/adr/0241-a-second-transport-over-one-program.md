# 241. A second transport over one program

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It is the increment
[`doc/roadmap.md`](../roadmap.md)'s *MCP implementation* section recorded and
did not start, and it was gated on [ADR-0239](0239-the-compiler-answers-a-tools-question.md) —
which that section named as the prerequisite and which is now taken.

## Context

`lsp/pasls.pas` speaks the Language Server Protocol to an editor. The Model
Context Protocol asks the same kind of questions of the same compiler on behalf
of a different reader: **an agent working on a checkout**, which is a real
reader of this repository and not a hypothetical one.

The roadmap's argument for it is short and is not repeated here. What it turns
on is a defect this project has already paid for twice: an agent editing
`selfhost/apfront.pas` — 22 102 lines — has no semantic route into it and falls
back on `grep`, and §6.11.1 puts an exported routine's header in the
module-heading *and* leaves the block repeating the name, so `^function Name(`
matches an interface entry with no body. That is how `foreign-reserved` broke on
the day of the three-component split, and ADR-0229 and ADR-0230 answered the
class of it by moving a gate off a Pascal-parsing regex and onto the compiler's
own `--dump-dispatch`.

The section also named, in advance and as its own discipline demands, **the
finding it expected to produce**: *`PasLsp` is a frame reader and not a
transport, and the second transport is what says so.*

## Decision

**`pasls --mcp` speaks MCP over stdio; the same binary with no flag speaks
LSP.** One document store, one import resolver, one scratch path, one set of
answers about a program.

The protocol details here are read from the specification at
`modelcontextprotocol.io`, revision **2025-06-18**, and not recalled: the
transport's framing, the lifecycle's version negotiation, the `tools/list` and
`tools/call` shapes, and the separation of a protocol error from a tool
execution error are each quoted where the code turns on them.

**Two tools, and they are exactly what the compiler can answer about a
program.** `outline` is `--dump-symbols` rendered for a reader — two spaces a
level, the kind, the name and the position — and `diagnostics` is a compilation
with imports resolved from `.components`. Nothing else is offered: compiling,
running the suite and reading a file are things a shell already does better,
and wrapping them in a tool call would be surface without a reason.

**Errors are reported in the two kinds the specification separates.** An
unknown tool and a missing `path` are *protocol* errors with a JSON-RPC code;
a file that is not there is a tool that ran and could not do the job, which is
`isError: true` inside a result. Getting that backwards is the commonest way an
MCP server misbehaves, and the session pins both.

## Consequences

**The predicted finding was right, and the useful one was a second one it did
not have.**

`PasLsp` *is* a buffered descriptor reader with a framing layered over it.
`LspReader`, `Ready` and `NextByte` are shared unchanged; `LspRead` is 40 lines
and `JsonlRead`/`JsonlWrite` together are 58. **The module's name is now
narrower than its contents** and it is kept anyway: renaming it is churn in
every component list that names it, and a second framing is not a reason on its
own. A third caller wanting the reader and *neither* framing would be.

**The work half was less transport-neutral than the roadmap claimed, and only
the second caller could say so.** Two places:

- `CompilerCommand` had the scratch path baked in as the **source**, which is
  an LSP assumption — the document is a buffer that may never have been saved,
  so it must be written out before a compiler can read it. MCP's unit is a file
  on disk. The source is a parameter now and the *output* still is not: the IR
  goes beside the scratch file whatever is compiled, because writing a `.ll`
  next to somebody's source would be this program leaving something behind.
- The `path` argument has to be made **absolute**, because `ImportsFor`
  compares the file it is asked about against sidecar entries it has resolved
  against the sidecar's own directory. A relative path matches none of them and
  the answer is `lib/dialect/pasjson.pas` reporting 48 diagnostics again —
  **ADR-0238's defect arriving a second time by a different road**. The LSP
  side never met it because `UriToPath` always yields an absolute path, so the
  routine was neutral only in the sense that every caller so far happened to
  hand it one shape. That is ADR-0116's two-sites rule applied to an
  *interface* rather than to a feature, and it is the finding worth carrying
  forward.

**The two protocols disagree about what a unit is**, and that is not a detail.
LSP's is a document the client is holding; MCP's is a file on disk. So the MCP
side has no document store and writes no scratch copy — not an economy, the
honest reading of both.

**And they disagree about where a workspace comes from.** LSP is told at
`initialize`. MCP's `roots` is a *client* capability reached by a request the
server issues, which this server does not do — so it takes the directory it was
started in, a client having launched it as a subprocess and an agent's
subprocess starting in the tree it is working on. `lsp/run.sh` runs the server
in the checkout for that reason, which meant making the compiler paths it is
handed absolute.

**One prediction was wrong, and in the comfortable direction.** The roadmap
expected the tool descriptors to stress `PasJson` under construction load and
to turn `JsonLine`'s 255 and `MapKey`'s 63 "from recorded into blocking". They
did not: the whole `tools/list` frame is **931 bytes**, every literal in it is
under 255, and `JsonTextAdd` carries the long values. The two bounds are still
open findings and this was not what closed the question about them.

**What did stress something is the outline**, and it stressed the framing
rather than the builder. `outline` on `selfhost/apfront.pas` is 40 146
characters holding **1 624 newlines**, in a frame of 41 859 bytes and one line —
because `JsonRender` escapes a newline as `\n` and the frame therefore contains
none. MCP requires that in as many words, and `JsonlWrite` **refuses** a body
holding a real newline rather than writing a frame that would be read back as
two. That check confirms the property instead of assuming it.

**Evidence.** `lsp/sessions/mcp.jsonl` is the protocol half: the lifecycle,
the descriptors, both tools against real sources in this checkout, and all
three error shapes. Its `diagnostics` call names a **relative** path on
purpose — that is the line that fails when the resolution above is removed, and
nothing else in the session does. `tests/dialect/lib_lsp_jsonl.pas` is the
module half, and it exists as a second program because one program has one
standard input and the two framings cannot be read from it at once; it pins the
skipped empty line, the dropped carriage return, `errAbsent` at the end of the
input, and the refusal of a body holding a newline. Removing the newline from
`JsonlWrite` fails the session; removing the refusal fails the module case.
