{ Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
  Copyright (C) 2026 Hui-Hong You
  
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 3 of the License, or (at your option)
  any later version.
  
  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.
  
  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <https://www.gnu.org/licenses/>. }

{ ApTypes -- what the lexer, the parser, Sema and the code generator all agree
  about: the token kinds, the AST's node kinds and its variant record, the type
  and symbol records, and the string pool those records point into.

  The first of the three program-components ISO/IEC 10206:1991 6.13 makes a
  program-block out of (ADR-0233). It imports nothing, which is what makes it
  the component every build translates on its own.

  Two kinds of routine are here rather than in ApFront, and the reason is the
  same for both: a second copy would be free to drift, which is the mistake
  ADR-0024 was written to stop making. The character sink -- `Put` and the pool
  writers -- is where every diagnostic and every line of IR goes, and one sink
  is what lets a type be spelled by *one* routine for two readers:
  `WriteTypeName` writes into a Sema diagnostic and into a code generator's
  trap string, and the trap string is a string constant in the generated
  program, so it has to be built before it is emitted.

  ISO 7185 6.4.3.3 requires a record's field identifiers to be distinct across
  all variants, so the AST's arms cannot all call their operands `base` and
  `next` the way the C++ structs did. Hence the two-letter prefixes. The tag is
  read by a case-statement rather than by a dynamic_cast, which is ADR-0005's
  bootstrap constraint outliving the C++ it constrained -- and ADR-0118's guard
  is what makes reading the wrong arm an error rather than a wrong answer. }

module ApTypes;

export ApTypes = (
  strMax, realDigits, vgNone, vgRead, vgWrite, kwWidth, bindNameCap,
  dateLen, timeLen, apVersion, maxImports, argMax, wordWidth, msgWidth,
  textWidth, nounParamForm, nounVarType, nounPointerDomain, kwCount, nul,
  tab, newline, creturn, poolMax, tokMax, maxDepth, maxBlockDepth,
  fileSize, tgtCount, tgtX86, tgtAarch64, jumpSize, handleSize, deferSize,
  taskSetSize,
  setLimit, setBits, lnkNone, lnkVar, lnkProc, lnkStdIn, lnkStdOut,
  lnkForeign, strLen, nameStr, bindText, str, kwLit, wordLit, msgLit,
  textLit, tokenKind, token, ctxKind, labelWhat, binaryOp, unaryOp,
  nodeKind, symKind, fileBinding, typeKind, builtinKind, stdProcKind,
  typePtr, symPtr, constitPtr, ifacePtr, modRecPtr, producedPtr, instPtr,
  boundPtr, entryPtr, nodePtr, fieldPtr, variantPtr, numPtr, rangePtr,
  namePtr, symListPtr, nodeListPtr, numRec, rangeRec, nameRec, symListRec,
  nodeListRec, fieldRec, variantRec, typeRec, symbol, producedRec,
  instRec, boundRec, entryRec, constitRec, ifaceRec, modRec, discValPtr,
  discValRec, heapTypePtr, heapTypeRec, layoutPtr, layoutRec, dispatchPtr,
  dispatchRec, chainPtr, chainRec, tagPtr, tagRec, pendingPtr, pendingRec,
  strConstPtr, strConstRec, constGlobalPtr, constGlobalRec, ownRelPtr,
  ownRelRec, opndPtr, opndRec, node, stmtPathPtr, stmtPathRec,
  labelInfoPtr, labelInfoRec, pendingGotoPtr, pendingGotoRec,
  labelBlockPtr, labelBlockRec, labelScopePtr, labelScopeRec, tkEof,
  tkIdent, tkInt, tkReal, tkStr, tkInt64, tkPlus, tkMinus, tkStar,
  tkSlash, tkAssign, tkComma, tkSemi, tkColon, tkPeriod, tkDotDot,
  tkLParen, tkRParen, tkLBracket, tkRBracket, tkCaret, tkQuery, tkBang,
  tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe, tkAnd, tkArray, tkBegin, tkCase,
  tkConst, tkDiv, tkDo, tkDownto, tkElse, tkEnd, tkFile, tkFor,
  tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod, tkNil, tkNot, tkOf,
  tkOr, tkPacked, tkProcedure, tkProgram, tkRecord, tkRepeat, tkSet,
  tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile, tkWith, tkOtherwise,
  tkPow, tkProtected, tkValue, tkBindable, tkRestricted, tkModule,
  tkExport, tkImport, tkOnly, tkQualified, tkStarStar, tkGtLt, tkArrow,
  tkAndThen, tkOrElse, ctxNone, ctxProgramStart, ctxProgramParams,
  ctxProgramHeader, ctxFinalEnd, ctxAfterFile, ctxAfterSet, ctxChannel, ctxSetMembers,
  ctxSubrangeBounds, ctxEnumConstants, ctxAfterArray, ctxSchemaArgs,
  ctxFormalDisc, ctxTypeInquiry, ctxDirectIndex, ctxArrayIndex,
  ctxRecordEnd, ctxFieldList, ctxVariantTag, ctxVariantLabels,
  ctxVariantOpen, ctxVariantFields, ctxVariantClose, ctxConstDef,
  ctxConstDefEnd, ctxTypeDef, ctxTypeDefEnd, ctxVarDecl, ctxVarDeclEnd,
  ctxParamList, ctxParamListEnd, ctxProcHeading, ctxProcBody,
  ctxCompoundStart, ctxCompoundEnd, ctxIf, ctxWhile, ctxRepeatEnd, ctxFor,
  ctxCaseSelector, ctxCaseLabels, ctxCaseEnd, ctxWith, ctxAssign,
  ctxProcCallArgs, ctxWriteArgs, ctxReadArgs, ctxSubscript, ctxSubstring,
  ctxReadStrArgs, ctxWriteStrArgs, ctxValueOpen, ctxValueSelector,
  ctxValueClose, ctxVariantValueOf, ctxParenExpr, ctxCallArgs,
  ctxAfterGoto, ctxLabelStart, ctxAfterLabel, ctxLabelDecl,
  ctxAfterLabelPart, ctxFuncParamResult, ctxImplementation,
  ctxModuleBlockEnd, ctxModuleHeadEnd, ctxModuleParams, ctxModuleHeader,
  ctxModuleEnd, ctxModuleBlockClose, ctxToBegin, ctxToEnd, ctxExportName,
  ctxExportOpen, ctxExportClose, ctxExportEnd, ctxImportClose,
  ctxImportEnd, lwCase, lwVariant, lwArrayValue, lwTagValue, opAdd, opSub,
  opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr, opExp, opPow, opAndThen,
  opOrElse, opSymDiff, opEq, opNe, opLt, opLe, opGt, opGe, opIn, opPos,
  opNeg, opNot, nkInt, nkReal, nkInt64, nkChar, nkStr, nkNil, nkSet,
  nkSetMember, nkVar, nkIndex, nkField, nkDeref, nkBinary, nkUnary,
  nkCall, nkSubstr, nkStructValue, nkValueElem, nkEmpty, nkAssign,
  nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat, nkFor, nkProcCall,
  nkWith, nkCase, nkGoto, nkLabeled, nkDefer, nkSpawn, nkWriteArg, nkCaseArm,
  nkVariantArm, nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray,
  nkRecord, nkPointer, nkFile, nkSetOf, nkOptional, nkHandle, nkFallible,
  nkConfArray, nkSchema, nkInquiry, nkRestricted, nkConstDecl, nkTypeDecl,
  nkProcDecl, nkLabelDecl, nkBlock, nkModule, nkExportPart, nkExportItem,
  nkImportSpec, nkImportItem, skConst, skType, skVar, skParam, skVarParam,
  skProcParam, skDisc, skProc, skFunc, skSchema, skInterface, skRequired,
  fbInternal, fbStdInput, fbStdOutput, fbArgument, tyVoid, tyInteger,
  tyReal, tyBoolean, tyChar, tyEnum, tySubrange, tyArray, tyRecord,
  tyPointer, tyFile, tySet, tyProc, tyComplex, tyRestricted, tySlice,
  tyOptional, tyHandle, tyString, tyText, tyInt64, biNone, biAbs, biSqr,
  biOdd, biOrd, biChr, biSucc, biPred, biSqrt, biSin, biCos, biLn, biExp,
  biArcTan, biTrunc, biRound, biEof, biEoln, biCmplx, biPolar, biRe, biIm,
  biArg, biCard, biPosition, biLastPosition, biEmpty, biLength, biIndex,
  biSubstr, biTrim, biStrEq, biStrNe, biStrLt, biStrGt, biStrLe, biStrGe,
  biBinding, biDate, biTime, biArgCount, biArgument, biTry, biTake,
  biReceive,
  biRelease, spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut,
  spSeekRead, spSeekWrite, spSeekUpdate, spUpdate, spExtend, spBind,
  spUnbind, spHalt, spSend, spGetTimeStamp, spPack, spUnpack, spPage, spExit,
  spBreak, spContinue, readingImports, line, col, pool, poolLen, tokCount,
  pos, depth, aborted, errorSeen, errorCount, progBlock, progModules,
  progModuleTail, progMainIndex, activeModules, msgOut, msgBuf, annotate,
  layoutHead, programSym, ircode, imports, importName, dumping,
  dumpLayoutOpt, dumpDispatchOpt, dispatchHead, dispatchTail, enumHead,
  enumTail, chainHead, chainTail, tagHead, tagTail, curFile, curImportIdx,
  mainTokBase, notingUses, notingStmts, mainFile, FileIndexOf, instDeclHead, intType, int64Type, canonTextType,
  stringSchema, handleClosers, StrClear, StrAppend, Put, PutIrLit,
  ErrorAt, PoolAdd, WritePool, PoolIsWide, PoolIs, ReservedForeignName,
  PoolSame, PoolPut, InternWord, InternWide, InternWide2,
  InternResultName, InternBindingName, InternCallResultName,
  InternTryName, InternWithName, InternBoundsName, InternForName, NewType,
  Base, IsInteger, IsReal, IsInt64, IsComplex, IsVarString, IsText,
  IsStringRep, IsOptional, IsFallible, IsHandleBirth,
  IsSlice, SliceOf, IsNumeric,
  IsArith, IsBoolean, IsChar, IsEnum, IsArray, IsRecord, IsPointer,
  IsFile, IsHandle, IsChannel, IsOwned, IsOwnedPointer, IsAffine, IsTextFile, IsNil,
  IsSet, IsProcType, IsEmptySet, IsRestricted, Underlying, IsStructured,
  IsMemory, Protectable, IsOrdinal, IsCharArray, IsStringType,
  IsStringOrChar, StringValueFormal, ForeignStringFormal, EnumCount,
  OrdinalLo, OrdinalHi, TypeLength, PadsToFixedString, ArmAtIn, FindField,
  ArmsAt, FieldsAt, TagFieldAt, TagTypeAt, WriteOrdinalName,
  WriteTypeName, WriteDistinctTypeNote);

import StandardOutput;

const
  { The longest identifier or character-string this compiler accepts. Not
    "kept": exceeding it is diagnosed where the scanner counts, never applied
    by truncating, which is what it used to do -- see ADR-0110 and the comment
    in LexIdentOrKeyword. Stated in doc/implementation-defined.md 6, which
    5.1 c) asks for. }
  strMax   = 255;
  { The total-width a folded real is written back with (ADR-0227). 6.10.3.4.2's
    floating-point representation spends six characters on the sign, the point
    and the exponent, so this asks for 24 significant digits where 17 are what
    names a binary64 uniquely -- the margin is deliberate, the clause fixing
    only the *form* of the representation and not its precision. A real
    constant is text here (ADR-0025), so a folded one has to be written back
    as text a strtod reads to the same value; ADR-0227 round-trips 0.1,
    4*arctan(1), 1e300 and the smallest denormal through this width. }
  realDigits = 30;
  { How a field selection is being used, for ADR-0118's variant guard.
    vgNone is the machinery that writes whole records -- the initial state, a
    whole-variable copy, the file walk -- which reaches every arm on purpose;
    vgWrite is an assignment target, which activates the arm it names; vgRead
    is every other use and is checked against the tag. }
  vgNone   = 0;
  vgRead   = 1;
  vgWrite  = 2;
  kwWidth  = 9;      { 'procedure', the longest reserved word }
  { The capacity of BindingType.name. ISO/IEC 10206:1991 6.4.3.4 makes the
    field "an implementation-defined variable-string-type" and says nothing
    more, so the number is this compiler's; it is a file name's worth. }
  bindNameCap = 255;
  { 6.7.6.9 gives each result "an implementation-defined length", singular --
    one length for the implementation and not one per value -- so the two
    representations are fixed-width ISO 8601: YYYY-MM-DD and HH:MM:SS. Being
    compile-time constants is what makes them free, since a string value is a
    pointer and a length and only the pointer needs a call. }
  dateLen = 10;
  timeLen = 8;
  { The version this compiler reports, and the one place it is written on this
    side of the build. Pascal has no preprocessor, so CMake cannot substitute
    it -- it is checked against `project()`'s VERSION by producttest.sh instead,
    which is the same arrangement `fileSize` and PAS_FILE_SIZE have for the
    same reason: two files that cannot include one another, and a disagreement
    that is checked rather than trusted. }
  apVersion = '3.1.0';
  { How many --import arguments one translation may be given. Bounded because
    an array is, and generous because 6.13 puts no limit on how many
    program-components a program-block has.

    It was eight, and eight was the number ADR-0114 recorded as the reason a
    library of more than eight modules could not be used whole. ADR-0158 raised
    argMax and said in as many words that it did not revisit this one, because
    nothing had asked. `lsp/pasls.pas` asked: its import chain is ten modules
    and none of them is optional -- PasIO needs PasFS, PasJson needs
    PasContainer, PasProcess needs PasStrVec -- so the first program in this
    tree written to be used rather than to be tested could not be compiled at
    all. Thirty-two is the whole library today with room over it. }
  maxImports = 32;
  { How many command-line arguments the compiler can be handed, and one more
    program-parameter than that exists so that going over is reported rather
    than truncated -- see the declarations of arg1..argOver.

    It is derived from maxImports and has to be: an import costs *two* words,
    so a bound on imports that the argument list cannot express is not a bound
    at all. Thirty-two imports are sixty-four words; --target=, a --dump flag,
    --coverage, the source, `-o` and its file name are six more; seventy-two
    leaves two over. Raising maxImports without raising this is the mistake the
    number is written this way to prevent. }
  argMax = 72;
  wordWidth = 12;    { the longest word a diagnostic passes about, padded }
  msgWidth = 16;     { 'packed array [', the longest piece of a type name }
  textWidth = 40;    { the longest fixed part of a runtime-error message }
  { Which noun a diagnostic calls a schema's generic production by. Three
    places ask for one: a parameter form (6.7.3.1), a variable's type
    (6.2.3.2), and a pointer domain (6.4.4). }
  nounParamForm = 0;
  nounVarType = 1;
  nounPointerDomain = 2;
  kwCount  = 45;     { 35 word-symbols of ISO 7185, then ISO 10206's ten }
  nul      = 0;      { what Peek yields past the end, as the C++ lexer does }
  tab      = 9;
  newline  = 10;
  creturn  = 13;
  { Sized for this compiler's own source with room to grow: it is the largest
    Pascal in the tree, and the one that has to keep fitting. Both are frame
    storage, so they are the fixed-buffer limits ADR-0012 predicted.

    Twice now the loud failure has been the *build*, because the array that
    has to hold this source is the seed's and raising the constant here does
    not raise the seed's (ADR-0095 for the pool, ADR-0126 for the tokens).
    Both are sized for roughly twice the present source, and `--dump-limits`
    says how much of each is left -- the `buffer-headroom` case reads it, so a
    third time is a report rather than a wall. The tokens could be counted
    without the flag and the pool never could: `--dump-tokens` writes one line
    per token and a string-literal cannot contain a newline, while PoolAdd is
    called from Sema and from CodeGen as well as from the lexer, so no count
    taken over the token stream is the pool's size (ADR-0148).

    One entry to the pool is not loud: PoolPut drops a character when the pool
    is full rather than reporting, so the two names it builds -- a function's
    result slot and a `with` binding -- would come out short. It is reachable
    only once the pool is within a name's length of full, which is the state
    the headroom gate exists to report long before; doc/sop.md §7 carries it. }
  poolMax  = 1000000; { characters of identifier and literal text }
  tokMax   = 300000;
  maxDepth = 1000;   { ADR-0020, and the same number the C++ parser uses }
  { Blocks nest inside that limit and never beyond it, because ParseBlock
    counts one -- which it did not until a security audit wrote 1001 nested
    procedures and indexed `scopeMark` off its end. The claim this comment
    makes is the only thing standing between scopeDepth and that array, so it
    is load-bearing prose: if a block is ever parsed by a path that does not
    call EnterLevel, this is wrong again and nothing else will say so.
    One more than maxDepth so the outermost scope can be depth 0 and the
    deepest a block the parser let through. }
  maxBlockDepth = 1001;
  { The size of a file variable's storage, which is PAS_FILE_SIZE in
    runtime/pasrt.h. The C++ code generator includes that header so the two
    cannot disagree; ISO 7185 has no include mechanism, so this side repeats
    the number and selfhost/irtest.sh checks that the two still match. }
  fileSize = 120;
  { ISO 7185 says nothing about a machine; this compiler has to. `--target=`
    selects which triple and datalayout the emitted module states, and the list
    is **two entries long on purpose** (ADR-0156).

    A target belongs here when this compiler's own layout rules -- LlSize and
    LlAlign, which are hand-written because there is no DataLayout to ask --
    have been shown to agree with LLVM's for it. That was measured for aarch64
    against x86-64 over 4501 frame sizes and field offsets, the `i256` in a
    record that is ADR-0028's segfault included, and it holds because both are
    LP64 and little-endian. It does not hold for a 32-bit target, where LlSize
    says a pointer is 8 -- so `--target=i686-linux-gnu` is refused rather than
    answered wrongly. Refusal by construction, as everywhere else here.

    A case statement rather than an array: the datalayout strings are long and
    fixed, TargetIndex reads a spelling and RunCodeGen writes the pair, and
    adding a target is two arms and a count -- after the offsets have been
    compared for it, which doc/roadmap.md's cross-platform chapter says how to
    do. }
  tgtCount = 2;
  tgtX86 = 1;
  tgtAarch64 = 2;
  { The storage a block needs to be the target of a non-local `goto`, which is
    PAS_JUMP_SIZE in runtime/pasrt.h -- opaque here for the same reason a file
    variable's is, and checked against that header by selfhost/irtest.sh.

    **A per-target maximum, not a measurement of this one** (ADR-0155). It was
    256, which is what the runtime's record needs on x86-64 and nowhere else:
    `jmp_buf` is 200 bytes here, 312 on aarch64 and 392 on 32-bit arm, so the
    runtime's own _Static_assert stopped an aarch64 build before anything else
    could. The header carries the four measurements and why 1024. The cost is
    paid only by a block that is the target of a non-local goto -- the only
    kind that carries a record at all -- and this compiler contains no `goto`,
    so no frame in seed/*.ll has one. }
  jumpSize = 1024;
  { AP 6.4.12's handle slot: the value, the routine that releases it, and the
    two links of the runtime's list of live handles -- four words, and
    PAS_HANDLE_SIZE is the same number in runtime/pasrt.h, checked by
    selfhost/irtest.sh as the two above are (ADR-0174). }
  handleSize = 32;
  { AP 6.9.3.11's defer record: the runner, the frame to run it against, and
    the two links of the runtime's list -- four words, and PAS_DEFER_SIZE is
    the same number in runtime/pasrt.h, checked by selfhost/irtest.sh
    (ADR-0175). One per *activation* that defers, not one per defer-statement:
    which statements are armed is a flag apiece in the frame, and the runner
    is what reads them. }
  deferSize = 32;
  { AP 6.9.3.12's task set (ADR-0268): the threads a block has spawned, so it
    can join every one before its activation ends. A pointer, a count and a
    capacity; 32 clears a 64-bit target with room, as the defer record's does.
    One per *block* that spawns, not one per task -- the defer record's shape,
    and the reason a block spawning in a loop needs no more storage than one
    spawning once. It must equal PAS_TASKSET_SIZE in runtime/pasrt.h; irtest.sh
    checks the two. }
  taskSetSize = 32;
  { Every set is one 256-bit word, so a set's base type must have its values
    in 0..setLimit (ADR-0028). That admits `char` exactly. }
  setLimit = 255;
  setBits  = 256;
  { Which shape a symbol's linkage name takes (6.13). Only these six cross a
    program-component boundary; everything else in the emitted text is named
    with a counter, which is a fact about the order one translation walked the
    tree in and so cannot be reproduced by another. }
  lnkNone   = 0;
  lnkVar    = 1;  { v.<interface>.<constituent> }
  lnkProc   = 2;  { p.<interface>.<constituent> }
  lnkStdIn  = 3;  { pas.input }
  lnkStdOut = 4;  { pas.output }
  { ADR-0121's `external` directive: the name is the one the program wrote,
    letter for letter, and is the only linkage name here that this compiler
    did not compose. It is stored in linkItemAt/linkItemLen with no interface
    part, there being no interface -- what is on the other side was not
    translated by anything that reads this repository's conventions. }
  lnkForeign = 5; { the foreign name, exactly as written }


type
  strLen = 0..strMax;
  { A file name or a command-line argument. 6.7.3.1 makes a parameter's type a
    type-*name*, so the production needs a name of its own before it can be
    passed; the schema-name `string` would take any capacity but then the
    variables holding one would each need their own descriptor. }
  nameStr = string(strMax);
  { A bindable text, named because 6.7.3.1 wants a type-name here too and
    because 6.4.1 makes `bindable` part of the type-denoter (ADR-0052). }
  bindText = bindable text;
  str = record
    len: strLen;
    ch: packed array [1..strMax] of char
  end;
  kwLit = packed array [1..kwWidth] of char;
  wordLit = packed array [1..wordWidth] of char;
  { Two more padded-literal widths, for the pieces a runtime-error message is
    built out of. A trap message is a *string constant in the generated
    program*, so unlike a diagnostic it cannot be written as it is computed --
    it has to be assembled first and emitted afterwards. }
  msgLit = packed array [1..msgWidth] of char;
  textLit = packed array [1..textWidth] of char;

  tokenKind = (
    tkEof, tkIdent, tkInt, tkReal, tkStr,
    { ADR-0128: a decimal literal above maxint. It is
      a token of its own rather than a flag on tkInt because what it carries is
      *text* -- this compiler has no value of the type to put in intVal -- and
      that is the same reason tkReal is a token of its own. }
    tkInt64,
    tkPlus, tkMinus, tkStar, tkSlash, tkAssign, tkComma, tkSemi, tkColon,
    tkPeriod, tkDotDot, tkLParen, tkRParen, tkLBracket, tkRBracket, tkCaret,
    { ADR-0123's optional-type marker. `?` is a character neither standard
      admits anywhere at all, so the dialect can take it and the lexis costs
      nothing -- the same property ADR-0121 got out of a directive. }
    tkQuery,
    { AP 6.4.13's fallible-type marker (ADR-0176). `!` is free for the reason
      `?` was: neither standard admits the character in any position, so the
      dialect takes it and the lexis costs nothing. }
    tkBang,
    tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe,
    tkAnd, tkArray, tkBegin, tkCase, tkConst, tkDiv, tkDo, tkDownto, tkElse,
    tkEnd, tkFile, tkFor, tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod,
    tkNil, tkNot, tkOf, tkOr, tkPacked, tkProcedure, tkProgram, tkRecord,
    tkRepeat, tkSet, tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile, tkWith,
    { ISO/IEC 10206:1991 word-symbols, reserved only under the extended
      standard. Under ISO 7185 the scanner yields these spellings as
      identifiers, which is what they are in that language. }
    tkOtherwise, tkPow, tkProtected, tkValue, tkBindable, tkRestricted,
    { 6.11's five. `interface` and `implementation` are deliberately not among
      them: 6.1.5 and 6.1.6 make those *directives*, which are identifiers in
      the one position each may occupy -- exactly as `forward` is. }
    tkModule, tkExport, tkImport, tkOnly, tkQualified,
    { And the one operator ISO/IEC 10206:1991 spells in symbols. It is scanned
      under both standards and refused under ISO 7185, where no valid program
      can hold two adjacent stars outside a comment or a string anyway. }
    tkStarStar, tkGtLt,
    { 6.11.2's renaming, in an export-clause and an import-clause alike.
      Scanned under both standards for the reason `**` is: no valid ISO 7185
      program can hold `=>`, so consuming it and refusing it yields one
      diagnostic rather than a cascade about `=` and `>`. }
    tkArrow,
    { 6.1.2 spells the short-circuit operators as *two words with a separator
      between them* -- `and then` and `or else` are each one word-symbol, not
      a pair. They reserve nothing new, because both halves are already
      word-symbols of ISO 7185, and the scanner builds them by joining two
      tokens rather than by looking a spelling up. }
    tkAndThen, tkOrElse);

  token = record
    kind: tokenKind;
    line, col: integer;
    { One past this token's last character, on the same line -- no token here
      spans one, a string-literal included (6.1.7). It is not derivable from
      what is beside it, which is the reason it is recorded (ADR-0258): `len`
      is the length in the string *pool*, which is zero for every token
      AddSimple builds and differs from the source length for a literal --
      `'a''b'` is three pool characters and six source ones. }
    endCol: integer;
    at, len: integer;   { the spelling or value, in the pool }
    intVal: integer;
    { A literal too large for the integer type. The value left behind is an
      accident of whatever conversion detected it, so both dumps print a
      placeholder rather than comparing two accidents. }
    tooBig: boolean
  end;

  { What follows 'expected X' in a message from Expect. The C++ parser passes
    the phrase itself; a padded literal per phrase would cost more than the
    case statement that writes them, so the call site names the place instead
    of spelling it. }
  ctxKind = (
    ctxNone, ctxProgramStart, ctxProgramParams, ctxProgramHeader, ctxFinalEnd,
    ctxAfterFile, ctxAfterSet, ctxChannel, ctxSetMembers, ctxSubrangeBounds, ctxEnumConstants, ctxAfterArray,
    ctxSchemaArgs, ctxFormalDisc, ctxTypeInquiry, ctxDirectIndex,
    ctxArrayIndex, ctxRecordEnd, ctxFieldList, ctxVariantTag,
    ctxVariantLabels, ctxVariantOpen, ctxVariantFields, ctxVariantClose,
    ctxConstDef, ctxConstDefEnd, ctxTypeDef, ctxTypeDefEnd, ctxVarDecl,
    ctxVarDeclEnd, ctxParamList, ctxParamListEnd, ctxProcHeading, ctxProcBody,
    ctxCompoundStart, ctxCompoundEnd, ctxIf, ctxWhile, ctxRepeatEnd, ctxFor,
    ctxCaseSelector, ctxCaseLabels, ctxCaseEnd, ctxWith, ctxAssign,
    ctxProcCallArgs, ctxWriteArgs, ctxReadArgs, ctxSubscript, ctxSubstring,
    { ISO/IEC 10206:1991 6.7.5.5's two string transfer procedures. Their lists
      are parsed as write- and read-parameter-lists (ADR-0087), so only the
      closing parenthesis is still theirs to complain about -- but the parser
      does know which of the six words it read, and a message that named the
      wrong one would be naming a procedure the program never wrote. }
    ctxReadStrArgs, ctxWriteStrArgs,
    { ISO/IEC 10206:1991 6.8.7's structured-value-constructor }
    ctxValueOpen, ctxValueSelector, ctxValueClose, ctxVariantValueOf,
    ctxParenExpr,
    ctxCallArgs, ctxAfterGoto, ctxLabelStart, ctxAfterLabel, ctxLabelDecl,
    ctxAfterLabelPart, ctxFuncParamResult,
    { ISO/IEC 10206:1991 6.11's module, its two lists, and the two `to` parts }
    ctxImplementation, ctxModuleBlockEnd, ctxModuleHeadEnd, ctxModuleParams,
    ctxModuleHeader, ctxModuleEnd, ctxModuleBlockClose, ctxToBegin, ctxToEnd,
    ctxExportName, ctxExportOpen, ctxExportClose, ctxExportEnd,
    ctxImportClose, ctxImportEnd);

  { Which construct a case-constant-list belongs to, for the one diagnostic
    EvalLabelRange writes. 6.8.7.2's array-value names the same production the
    case statement and the variant part do, so it joins them here rather than
    getting a folder of its own. }
  labelWhat = (lwCase, lwVariant, lwArrayValue, lwTagValue);

  { `in` is a relational operator (ISO 7185 6.7.2.4) and sits at the same
    precedence as `=`, which is why it belongs here rather than with the
    adding operators despite taking a set on only one side. }
  { opExp and opPow are ISO/IEC 10206:1991 6.8.3.2's exponentiating operators.
    They differ in more than spelling: `**` converts both operands to real and
    yields a real, while `pow` takes an integer right operand and yields the
    type of its left one -- so `2 pow 3` is the integer 8 and `2 ** 3` is 8.0. }
  { opAndThen and opOrElse are 6.8.3.3's short-circuit operators. This compiler
    already evaluates `and` and `or` that way (ADR-0010), so they lower
    identically -- but the standard only *permits* that for `and` and `or`
    while *requiring* it here, and a tree spelling both as opAnd would have
    thrown away the one fact that says which. }
  binaryOp = (opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
              opExp, opPow, opAndThen, opOrElse,
              { 6.8.3.4's set symmetric difference: the members of exactly one
                operand. An *adding*-operator like the + and - that are already
                union and difference on sets, and one instruction for the same
                reason. }
              opSymDiff,
              opEq, opNe, opLt, opLe, opGt, opGe, opIn);
  unaryOp = (opPos, opNeg, opNot);

  { The tag ADR-0005 has been carrying since the first commit. Expressions and
    statements are the C++ NK enumeration; the rest are the plain structs of
    ast.h, which become nodes here because one arena and one walker is less
    code than five parallel ones. }
  nodeKind = (
    { expressions }
    nkInt, nkReal, nkInt64, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar, nkIndex,
    nkField, nkDeref, nkBinary, nkUnary, nkCall, nkSubstr,
    { ISO/IEC 10206:1991 6.8.7's structured-value-constructor, and one
      array-value-element or field-value of it. The two forms of the
      constructor -- array-value and record-value -- share the node, because
      which one a bracketed value is cannot be decided until the type-name
      has been resolved. }
    nkStructValue, nkValueElem,
    { statements }
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkGoto, nkLabeled,
    { AP 6.9.3.11's defer-statement, `defer S` (ADR-0175): S is *armed* here
      and executed when the statement-sequence this statement stands in is
      completed, or when the activation terminates, whichever comes first.
      Dialect only, and spelled with no reserved word -- ADR-0140's test is
      asked of the token after the identifier. }
    nkDefer,
    { AP 6.9.3.12's spawn-statement, `spawn P(...)` (ADR-0268): P is a
      task-declaration and this starts an activation of it that runs
      concurrently with the statement after. Spelled with no reserved word,
      ADR-0140's test being a statement-initial identifier followed by none of
      `(`, `:=`, `[`, `.`, `^` or a terminator -- which is `defer`'s, and here
      the token after is the task's own identifier. }
    nkSpawn,
    { the pieces the C++ side keeps in vectors of plain structs }
    nkWriteArg, nkCaseArm, nkVariantArm, nkGroup, nkDeclName,
    { type denoters }
    nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer, nkFile,
    nkSetOf,
    { ADR-0123's optional-type, `?T`. Unlike nkPointer it holds a whole
      denoter rather than a name: a pointer takes a name so a type may name
      itself and close a cycle (6.4.4), and an optional has no cycle to close
      -- `?T` has to *contain* a T, so a type that were its own optional would
      have no size. }
    nkOptional,
    { AP 6.4.12's handle-type, `handle external 'closer'` (ADR-0174): a
      foreign routine's answer that is an address of storage the callee owns,
      released by the named routine when the variable dies. A denoter and
      not a name, for the optional's reason. }
    nkHandle,
    { AP 6.4.13's fallible-type, `T ! E` (ADR-0176): the result record
      ADR-0120 tells a module to write, with the field names fixed. It is a
      denoter holding two denoters and resolves to an ordinary record, which
      is the whole of why it is cheap. }
    nkFallible,
    { ISO 7185 6.6.3.7's conformant-array-schema, and ISO/IEC 10206:1991
      6.7.3.7's, which is the same construct. It is a type-denoter that may
      appear in one position only -- a formal parameter's -- and it is the only
      one whose bounds are *identifiers being declared* rather than expressions
      being read: `array [u..v: integer] of real` gives u and v defining-points
      for the parameter list and for the block (6.6.3.7.1).

      One node per index-type-specification, always. 6.6.3.7 makes the
      abbreviated form `array [u..v: T1; j..k: T2] of T3` equivalent to the
      full `array [u..v: T1] of array [j..k: T2] of T3`, so the parser writes
      the full one and nothing after it has two shapes to know about. }
    nkConfArray,
    { ISO/IEC 10206:1991 6.4.8's discriminated-schema. The only type-denoter
      whose children are expressions rather than denoters. }
    nkSchema,
    { 6.4.9's type-inquiry, `type of x`. The only type-denoter that names a
      *variable*: what it denotes is the type that variable possesses, which is
      why its name is resolved in the ordinary scope rather than among the
      types. }
    nkInquiry, nkRestricted,
    { declarations }
    nkConstDecl, nkTypeDecl, nkProcDecl, nkLabelDecl, nkBlock,
    { ISO/IEC 10206:1991 6.11's module and the two lists that surround it. An
      export-part names an *interface*, which 6.2.2.2 makes a region that
      "shall not be a part of the program text" -- so nothing here is a scope
      of the module that wrote it. }
    nkModule, nkExportPart, nkExportItem, nkImportSpec, nkImportItem);

  { ------------------------------------------------------- Sema's own types }

  { skProcParam is a procedural or functional parameter (ISO 7185 6.6.3.1).
    Its frame slot holds a *pair*: the code to call, and the static link to
    call it with -- the link of the block the actual procedure was declared
    in, not of the caller. `stype` is the procedural type and its `elem` is
    the result type, nil for a procedural parameter as against a functional
    one. }
  { skSchema is ISO/IEC 10206:1991 6.4.7's schema: a mapping from discriminant
    tuples to types. It is not a type -- nothing possesses it and it has no
    values -- so naming one where a type-denoter is wanted is an error until
    its discriminants are given. }
  { skDisc is one formal discriminant of a *schematic formal parameter*, as
    seen from inside the block (6.7.3.2). It has storage -- the slot of the
    parameter it belongs to holds the address and then the tuple -- but it is
    not a variable: nothing may assign to it, and it is in scope only while
    the parameter's type is being resolved. Afterwards `v.n` is the only way
    to name it, which is what 6.8.4 makes a primary. }
  { skInterface is an *imported-interface-identifier* (6.11.3). It is not a
    value, a type or anything callable -- its whole job is to be the left half
    of `i.x`, which is the only way to reach a constituent of an interface
    imported `qualified`. }
  { skRequired is a required function -- 6.2.2.10 puts its defining-point in "a
    region enclosing the program", so it is a symbol in the outermost scope and
    a program that declares one of the same name hides it. It is a *marker* and
    nothing else: IsInvocable is false for it, ResultTypeOf answers nil, and
    LookupUser turns it back into the nil every caller here reads as "the
    required one". A real skFunc would send `abs` through CheckArguments, which
    has no parameter list to check it against. What the symbol buys is a place
    for 6.2.2.9's applied occurrence to be recorded. }
  { Appended rather than placed where it reads best: the sema dump prints a
    symbol kind as an ordinal, so where a name sits in this list is an
    interface (ADR-0059). }
  symKind = (skConst, skType, skVar, skParam, skVarParam, skProcParam, skDisc,
             skProc, skFunc, skSchema, skInterface, skRequired);

  { How a file variable reaches something outside the program. ISO 7185 6.10
    makes only a *program parameter* external; every other file variable is a
    scratch file with no name, which is what skInternal means. }
  fileBinding = (fbInternal, fbStdInput, fbStdOutput, fbArgument);

  { tyProc is the type of a procedural or functional parameter. There is no
    way to *write* one outside a formal parameter list -- the type part has no
    procedure type -- so no variable ever has it, and it takes part in no
    operation but being passed on and being called. }
  { ISO/IEC 10206:1991 6.4.2.2 e): "The required type-identifier `complex`
    shall denote the complex-type. The complex-type shall be a
    **simple-type**." Simple is the operative word -- a complex value is
    assigned, passed and returned as a value, so none of the by-address
    machinery touches it, exactly as for a set. }
  typeKind = (tyVoid, tyInteger, tyReal, tyBoolean, tyChar, tyEnum, tySubrange,
              tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc, tyComplex,
              tyRestricted,
              { ADR-0125's slice: a view of part of an array, and the type
                of a formal parameter and of nothing else -- the second such
                kind after tyProc. `elem` is the component type; there is no
                extent, that being the half that arrives with the actual. }
              tySlice,
              { ADR-0123's optional-type. `elem` is the type it may hold, and
                the value is that type's storage with a flag in front of it.
                Neither standard has one: it is what lets a pointer come back
                from a foreign call without a null becoming a Pascal value. }
              tyOptional,
              { AP 6.4.12's handle-type (ADR-0174): a foreign address this
                program owns and a routine that releases it. Its value has
                no register form and the variable is the file model's --
                uncopyable, released when the variable dies -- so it answers
                with a file nearly everywhere a kind is asked. `handleAt`
                and `handleLen` name the closer. }
              tyHandle,
              { ISO/IEC 10206:1991 6.4.3.3.3's variable-string-type: a type
                produced from the required schema `string`. Its value is a
                length and that many characters, and the length may be anything
                from zero up to the *capacity* -- the schema's one discriminant.
                `hi` holds the capacity, `hiDisc` the discriminant it came from
                when an actual brought it, and `lo` is 1 because 6.4.3.3.1
                makes every string's index-domain start there.

                The *canonical*-string-type of 6.4.3.3.1 -- the type of `+`,
                `substr` and `trim` -- is this kind with `hi` negative: a value
                with no storage and so no capacity to exceed. }
              tyString,
              { AP 6.4.15's text-type (ADR-0189, ADR-0190): a type produced
                from the required schema `utf8`, whose value is well-formed
                UTF-8 in Normalization Form C and whose *elements* are extended
                grapheme clusters.

                Its **representation** is tyString's exactly -- a length and
                that many bytes -- and `IsStringRep` is what asks that, so
                every copy, parameter and frame slot is the string's and needed
                nothing added. Its **rules** are not the string's: an element is
                not a char, so there is no indexing and no substring; `length`
                counts elements and the capacity counts bytes; and a string is
                not assignment-compatible to it, the conversion being able to
                fail. Representation and rules being two questions asked by two
                predicates is ADR-0181's lesson applied before it could cost
                anything -- a flag on tyString would have handed a text every
                permission a string has (ADR-0146). }
              tyText,
              { ADR-0128's `int64`, and the reason it answers like `real` rather
                than like `integer`: it is a *numeric* type and not an ordinal
                one. Nothing this compiler can hold is a value of it -- its own
                integers are 32 bits -- so a value is carried as the text that
                was written, all the way into the IR, which is what ADR-0025
                already does with a real and for the same reason. Everything an
                ordinal is asked for follows from that and is refused: no case
                label, no array index, no subrange host, no set base, no `for`
                control variable, because each of those needs a value the
                compiler must hold. }
              tyInt64);

  { The required functions of ISO 7185, and the standard procedures that are
    not statements of their own. }
  builtinKind = (biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred,
                 biSqrt, biSin, biCos, biLn, biExp, biArcTan, biTrunc, biRound,
                 biEof, biEoln,
                 { 6.7.6.3's constructors and 6.7.6.2's accessors. cmplx and
                   polar are the only way to *write* a complex value -- the
                   standard gives the type no literal -- and re, im and arg are
                   the only way back out to a real. }
                 biCmplx, biPolar, biRe, biIm, biArg,
                 { 6.7.6.3's card(x): the number of members of a set. One
                   instruction, and the standard's "error if no such value of
                   integer-type exists" cannot arise -- every set is 256 bits,
                   so the count is at most 256 (ADR-0028). }
                 biCard,
                 { 6.7.6.6's direct-access position functions and 6.7.6.5's
                   `empty`. All three take a file variable, so they join eof
                   and eoln in taking an *address* rather than a value. }
                 biPosition, biLastPosition, biEmpty,
                 { 6.7.6.7's string functions. The six comparisons are
                   deliberately *not* the operators: NOTE 3 points out that
                   LT(a,b) may be false where a<b is true, because these
                   compare lengths as well as characters and the operators pad
                   with spaces instead. }
                 biLength, biIndex, biSubstr, biTrim,
                 biStrEq, biStrNe, biStrLt, biStrGt, biStrLe, biStrGe,
                 { 6.7.6.8's `binding`, the only required function whose result
                   is a *record*. It is given a hidden frame slot to be built
                   in -- the same mechanism a `with` binding uses -- so that
                   `b := binding(f)` is an ordinary designator. }
                 biBinding,
                 { 6.7.6.9's time functions. Each takes a TimeStamp and returns
                   the canonical-string-type -- so unlike every other required
                   function here, what these *say* is this compiler's choice
                   and not the standard's. Only date has an error condition:
                   an hour, a minute and a second cannot fail to be a time,
                   their subranges having already said so. }
                 biDate, biTime,
                 { AP 6.7.6.10's program-argument functions, the dialect's
                   alone (ADR-0173). `argcount` is the number of arguments the
                   program was activated with and `argument(k)` is the k'th as
                   a value of the canonical-string-type -- the same list 6.12
                   binds the program-parameters to, reached without declaring
                   one file variable per argument (ADR-0081). }
                 biArgCount, biArgument,
                 { AP 6.8.9's try, the dialect's propagation (ADR-0178).
                   `try(x)` is the value of a fallible x where it succeeded,
                   and where it did not it assigns the cause to the enclosing
                   function's result and terminates that activation -- so it
                   is the one required function here that is also a transfer
                   of control. Appended, as spExit was, because --dump-sema
                   prints a required function as its ordinal (ADR-0067), so a
                   constant inserted anywhere else renumbers the ones after
                   it. }
                 biTry,
                 { AP 6.4.14.6's take, the dialect's move (ADR-0182).
                   `take(v)` empties an owned pointer variable and yields what
                   it held, and may stand only as the whole right side of an
                   assignment to a variable of its own type -- 6.4.12.2's
                   position rule, reached by the same flag. Appended for
                   biTry's reason. }
                 biTake,
                 { AP 6.9.3.13's receive (ADR-0268), which answers whether a
                   value arrived -- the loop condition a reader wants. Its
                   twin `send` is a required *procedure* (spSend) and not a
                   builtin function, which is the asymmetry the clause
                   argues for rather than an accident of where each landed. }
                 biReceive,
                 { AP 6.4.12.5's release, the dialect's early close with an
                   answer (ADR-0206). `release(h)` releases what a handle
                   variable holds and yields what the closer answered.
                   Appended for biTry's reason. }
                 biRelease);
  { ISO/IEC 10206:1991 6.7.5.2's direct-access procedures join ISO 7185's. The
    three seeks differ only in the mode they leave the file in; update writes
    the buffer variable back without advancing; extend opens for writing at the
    end, and is the one of the five that needs no direct-access file. }
  stdProcKind = (spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut,
                 spSeekRead, spSeekWrite, spSeekUpdate, spUpdate, spExtend,
                 { 6.7.5.6's binding procedures. bind attaches a variable to an
                   entity outside the program and unbind detaches it. }
                 spBind, spUnbind,
                 { 6.7.5.7's control procedure: "no further processing of the
                   activation of the program shall occur". A required
                   *identifier*, so a program may declare its own halt. }
                 spHalt,
                 { AP 6.9.3.13's send (ADR-0268). A *procedure* where
                   `receive` is a function, and the asymmetry is the design:
                   a send either happens or the program has lost track of who
                   is listening, which is a fault this language stops for; a
                   receive has an ordinary second outcome -- closed and
                   drained -- and that outcome is the loop condition a reader
                   wants. }
                 spSend,
                 { 6.7.5.8's time procedure, the only required one that reads
                   something outside the program which is not a file. 6.9.4 f)
                   makes it threaten its argument. }
                 spGetTimeStamp,
                 { ISO 7185 6.6.5.4's transfer procedures and 6.9.5's page.
                   Appended, because the AST dump prints a builtin as its
                   ordinal and both compilers must agree on the number
                   (ADR-0067). }
                 spPack, spUnpack, spPage,
                 { AP 6.7.5.9's exit, the dialect's own control procedure, and
                   appended for the same reason as the three above it: the
                   dump prints a required procedure as its ordinal, so a
                   constant inserted anywhere else renumbers the ones after
                   it. }
                 spExit,
                 { AP 6.7.5.10's break and 6.7.5.11's continue, the dialect's
                   two loop-control procedures (ADR-0208). Appended for
                   spExit's reason, and next to it for a second one: the three
                   of them are the only required procedures here that are a
                   transfer of control rather than an operation. }
                 spBreak, spContinue);

  typePtr = ^typeRec;
  symPtr = ^symbol;
  { ISO/IEC 10206:1991 6.11's three: one constituent of an interface, an
    interface, and a module's record. Forward here because a symbol holds a
    list of constituents. }
  constitPtr = ^constitRec;
  ifacePtr = ^ifaceRec;
  modRecPtr = ^modRec;
  producedPtr = ^producedRec;
  instPtr = ^instRec;
  boundPtr = ^boundRec;
  entryPtr = ^entryRec;
  { Forward, because a schema's symbol holds the *syntax* of its body: a
    schema-definition has no type until a tuple gives its discriminants
    values, so what the symbol keeps is a type-denoter (6.4.7). }
  nodePtr = ^node;
  fieldPtr = ^fieldRec;
  variantPtr = ^variantRec;
  numPtr = ^numRec;
  rangePtr = ^rangeRec;
  namePtr = ^nameRec;
  symListPtr = ^symListRec;
  nodeListPtr = ^nodeListRec;

  { A component of a schema's type-argument-tuple (6.4.7), or of a generic
    routine's (AP 6.7.3.10). `value_` is the whole of 6.4.7's identity -- an
    ordinal, or ADR-0209's `typeId` for a type-valued one -- and `ty` is that
    type again, beside it.

    It is there for AP 6.7.3.10.4's inference, which reads a tuple *backwards*:
    given an actual whose type was produced from `Fallible`, it has to recover
    what `Fallible` was produced *with* in order to bind `T`, and until this
    field there was no way -- `ProduceFromSchema` says so where it re-derives
    the type from the argument node instead ("the tuple holds an id and there
    is no registry to turn one back into a type"). Nil for an ordinal
    component, and for a tuple built before this field existed.

    It does **not** make `typeId` an identity, which ADR-0209 warns against:
    nothing compares these types by id. `SameTuple` goes on comparing
    `value_`, and a reader that wants the type gets a pointer back and
    compares pointers, which is ADR-0017. }
  numRec = record value_: integer; ty: typePtr; next: numPtr end;
  { A folded case-constant: the closed interval it denotes. A single
    constant is lo = hi, so every user of a label list works one way and a
    range is never expanded into its members -- `1..maxint` is one of
    these and two billion switch cases if expanded. }
  rangeRec = record lo, hi: integer; next: rangePtr end;
  nameRec = record at, len: integer; next: namePtr end;
  symListRec = record sym: symPtr; next: symListPtr end;
  { A stack of record *type-denoters* -- the parse tree, not the resolved
    type, because a field's defining-point governs the whole record-type
    (6.4.3.3) including the pointer domains written before the field itself
    has been added to the type. }
  nodeListRec = record dn: nodePtr; next: nodeListPtr end;

  { One field of a record. `index` is the position in the struct it belongs to,
    which is also the declaration order; `variant` says which struct that is --
    -1 for the fixed part, otherwise the arm. }
  fieldRec = record
    at, len: integer;
    ftype: typePtr;
    index: integer;
    { 6.6: a field's own type-denoter may carry an initial-state-specifier, and
      then the record's initial state has that field bearing that value. }
    initValue: nodePtr;
    { 6.4.3.4: "That component shall have the type, bindability, and initial
      state denoted by the type-denoter of the record-section." Bindability is
      the third of the three and the last to be carried -- it sits beside
      initValue because the clause names them in one breath and for one reason.

      It has to live here rather than on the type: `type bt = bindable text`
      hands the bindability on without making a *type* distinct from `text`
      (ADR-0017 gives structured types name equivalence, and this one is not
      structured at all), so a flag on typePtr would say the same thing about
      both spellings. The denoter is what knows, and this is where the denoter's
      answer is kept. }
    isBindable: boolean;
    { Where the field lives, as a path: nil is the record's fixed part, (0) is
      arm 0 of its variant part, (0, 1) is arm 1 of the variant part inside arm
      0. ISO 7185 6.4.3.3 puts no limit on the nesting, so a single index could
      not say where a field is. }
    variant: numPtr;
    { 6.2.2.4's defining-point for a field-identifier: where it was written,
      and in which source. `line` is 0 for a field of a *required*
      record-type -- 6.4.3.4's TimeStamp -- which has no defining-point in
      any source, the same zero a required identifier's symbol carries.

      A field is not a symbol and never has been, which is why this pair sits
      here rather than being reached through one: 6.4.3.3 makes a record a
      region and a field's defining-point is in it, but nothing about a field
      is looked up in a scope. `declFile` indexes importName, 0 being the
      source being compiled (ADR-0246), and it is spelled as the symbol's is
      rather than as `file`, which §6.1.2 reserves. }
    line, col, declFile: integer;
    next: fieldPtr
  end;

  { One arm of a variant part. An arm is shaped exactly like a record -- a
    fixed part and an optional variant part of its own -- because that is what
    6.4.3.3 makes it: its field-list is a field-list like any other. }
  variantRec = record
    labels: rangePtr;
    { selected by whatever the other arms leave (Extended Pascal's
      variant-part-completer) }
    isOtherwise: boolean;
    fields, fieldTail: fieldPtr;
    variants, variantTail: variantPtr;
    tagField: integer;
    tagType: typePtr;
    { The nested variant-selector was a discriminant-identifier rather than a
      tag-type (6.4.3.4). See typeRec's discSelector. }
    discSelector: boolean;
    line, col: integer;
    next: variantPtr
  end;

  { A Pascal type. Simple types are shared singletons; every array or record
    *type-denoter* in the source produces one of these. Identity is therefore
    what ISO 7185 6.4.5 calls "the same type" (ADR-0017). }
  typeRec = record
    kind: typeKind;
    { Array: the component type. Pointer: the domain, nil only for `nil`
      itself. File: the component type. Sharing the field is what a variant
      record would do, which is where the C++ one was going. }
    elem, indexType, host, tagType: typePtr;
    { Whether `elem` was written with a bindability of bindable -- 6.4.3.5's
      "each component shall have the type, bindability, and initial state
      denoted by the type-denoter" for an array, said about the component
      rather than about the component's type, for fieldRec::isBindable's
      reason. A pointer's domain uses the same slot and does not set it yet;
      doc/implementation-defined.md 6.1 has why. }
    elemBindable: boolean;
    isPacked: boolean;
    { ISO 7185 6.7.1: a set-constructor with members "shall denote either a
      value of the unpacked-canonical-set-of-T-type or, if the context so
      requires, the packed-canonical-set-of-T-type". So a constructor's type
      has not chosen a packing and fits either destination, where 6.4.5 c)
      makes two *declared* set-types compatible only when they agree.
      isPacked has two values and this is the third. }
    setCanonical: boolean;
    { File: this is `text`, not a `file of char`. ISO 7185 6.4.3.5 makes them
      different types and gives only the first one lines, so readln, writeln,
      eoln and reading a number all belong to a text file and to nothing
      else. Nothing but this flag distinguishes the two. }
    isText: boolean;
    lo, hi: integer;
    enumNames, enumTail: namePtr;
    fields, fieldTail: fieldPtr;
    variants, variantTail: variantPtr;
    { AP 6.4.13: this record was written by `T ! E` rather than by the program
      (ADR-0176). The two types are kept so a diagnostic can spell the type the
      way the source did; everything else about it is an ordinary record, which
      is what makes the trap, the copy and the layout inherited rather than
      re-implemented. }
    isFallible: boolean;
    falVal, falCause: typePtr;
    { AP 6.4.13.5 (ADR-0256): this record's variant arms are laid **beside**
      one another rather than over one another, because one of them holds
      something affine -- a handle, a file, an owned pointer.

      The overlay is what a variant part normally is and what 6.4.3.4's own
      refusal of a file in one is about: the arms share storage, and a file's
      storage is its own. The prologue registers the affine slot with the
      runtime and the epilogue releases it, so a *cause* written into the same
      bytes would overwrite half of a `struct pas_handle` and the block would
      then release whatever was left there.

      Set only by ResolveFallible and only where a side is affine, so every
      fallible-type a program has written until now keeps the layout it had
      and no golden, no gate and no offset moves. It is per type rather than
      per language because an unconditional change would grow every fallible
      in the corpus for a reader that does not exist. }
    armsApart: boolean;
    tagField: integer;
    { 6.4.3.4 spells a variant-selector `[tag-field ':'] tag-type |
      discriminant-identifier`, and this says it was the third form. The
      selector is then not a field -- the tuple holds it -- so the *layout* is
      a tagless `case T of` and CodeGen never asks. What it changes is that
      6.7.5.3 requires a tag-type of every variant-part `new(p, c1, ..., cn)`
      selects, so this variant part is not one a tag value may choose. }
    discSelector: boolean;
    aliasAt, aliasLen: integer;
    { tyHandle: the foreign name of the routine that releases the value. }
    handleAt, handleLen: integer;
    { tyPointer: this pointer *owns* the variable it identifies (AP 6.4.14,
      ADR-0181). A flag on the kind rather than a kind of its own, which is
      isText's shape and setCanonical's: what changes is the ownership, and
      nothing about the pointer. IsOwned answers yes for it, so 6.4.6 a)'s
      refusals arrive through ContainsFile without a call site being edited --
      the handle's own route (ADR-0174). }
    owns: boolean;
    { 6.4.7 and 6.4.8: the schema this type was produced from and the tuple it
      was produced with, nil and empty for every type written out in full.
      Sema interns by the pair, so "one tuple, one type" needs no rule in
      Assignable -- two productions with equal tuples *are* the same record. }
    schema: symPtr;
    tuple, tupleTail: numPtr;
    { AP 6.4.7's type-valued discriminant needs a tuple component that names a
      *type*, and a tuple component is an integer (6.4.8). This is that integer:
      one per type object, handed out by NewType and never reused, so equal ids
      are the same object and the interning `Assignable` rests on goes on being
      "one tuple, one type" (ADR-0017, ADR-0039, ADR-0209). Structural equality
      is deliberately not what it answers -- two alike records are two types
      here, and `Vector(a)` and `Vector(b)` over them must be two as well. }
    typeId: integer;
    { 6.7.3.2 and 6.7.3.3: a bound that is not known until the block is
      entered -- the discriminant the source wrote there, whose value arrives
      with the actual. lo/hi are then not the bound and nothing reads them.
      Nil for every bound written as a constant, which is every bound outside
      a schematic formal parameter. }
    loDisc, hiDisc: symPtr;
    { ISO 7185 6.6.3.7: this array-type came from a conformant-array-schema.
      Not derivable from loDisc and hiDisc being set -- a schematic formal's
      `array [1..n]` sets one of them and could set both -- and 6.6.3.8's
      conformability has to know, because it recurses into a component that is
      another schema and stops at one that is a type-identifier. }
    isConfSchema: boolean;

    { 10206 6.4.4: this type's tuple is in a header immediately before the
      variable rather than in an activation record -- it is the domain of a
      pointer written as a bare schema-name, and `new` supplied the tuple
      (ADR-0043). descOwner holds its discriminant symbols, because a heap
      variable is reached through `p^` and so has no name to hang them on. }
    heapTuple: boolean;
    descOwner: symPtr;

    { 6.2.3.8 b) at a type-definition (ADR-0127): the hidden frame variable
      whose descriptor holds this type's bounds, evaluated once at the
      commencement of the activation of the block that defines it. Every
      variable of the type reads that one descriptor, so the extent is the
      type's and not each variable's -- which is what 6.4.1 requires of a
      type-name and what distinguishes this from ADR-0113's per-variable
      bounds, where the type belongs to one name. Nil for every type whose
      bounds folded, which is every type outside this clause. }
    boundsVar: symPtr
  end;

  symbol = record
    at, len: integer;
    kind: symKind;
    stype: typePtr;
    { 6.2.2.1's **defining-point**: where this identifier was written, and in
      which source. Every applied occurrence resolves to a symbol and the
      symbol could not say where it came from -- `Declare` was handed a line
      and a column for its own duplicate-declaration message and threw them
      away. Go-to-definition is the first caller that wanted the pair kept,
      and it is the compiler's answer to give: the alternative is a tool
      re-deciding 6.2.2's scope rules from an outline, which is the reader of
      Pascal-shaped output that ADR-0239 exists to refuse.

      declLine is 0 for a symbol with no defining-point in any source -- a
      required identifier (6.2.2.10), a result variable, a `with` binding --
      and that zero is the answer, not a missing one: there is nowhere to go.
      declFile indexes importName, 0 being the source being compiled. }
    declLine, declCol, declFile: integer;
    binding: fileBinding;
    fileArg: integer;
    { The value of a constant, in whichever field its type selects. A real
      constant keeps its *source text* and a sign, not a converted value: the
      one place a real is finally needed is the code generator, and what it
      needs there is a decimal literal to print. See EmitReal. }
    intVal: integer;
    charVal: char;
    boolVal: boolean;
    realAt, realLen: integer;
    realNeg: boolean;
    { ...unless the value does not fit in a field. ISO 7185 6.3 makes a
      character-string a constant, and a string has no scalar form -- so such
      a constant is *its defining expression, named*, and this is that node.
      The same shape initValue gives 6.6's initial state below. ADR-0068. }
    constValue: nodePtr;
    { This symbol is a `with` binding over a 6.8.8 constant-access, so the
      field-identifiers it introduces are 6.9.3.10's constant-field-
      identifiers: they denote values, and nothing may threaten one. }
    isConstBinding: boolean;
    { The number this procedure's LLVM function is named with. Nesting allows
      two procedures of the same name in different parents, so the name cannot
      be the Pascal one. }
    irId: integer;
    { lexical position: `level` is the nesting depth, and owner/frameIndex say
      which activation record holds this variable and where (ADR-0016) }
    level, frameIndex: integer;
    owner: symPtr;
    params, paramTail: symListPtr;
    frameVars, frameTail: symListPtr;
    frameCount: integer;
    { The constants this block defined whose value is a 6.8.7 constructor, in
      definition order. They have storage rather than a frame slot, and the
      prologue fills it (ADR-0069). }
    memConsts, memConstTail: symListPtr;
    { The ids of this block's labels that a goto in a *nested* block jumps to.
      Non-empty means the activation record carries a jump record after the
      frame variables, and the prologue arms it and dispatches on it -- so it
      is the one thing about a block that its own statements do not decide. }
    nlLabels, nlTail: numPtr;
    { AP 6.9.3.11: this block's defer-statements, most recently *written*
      first, and how many there are. Non-empty means the activation record
      carries a defer record and a flag per statement after the jump record,
      and that a runner function is emitted for the block. The list is in
      reverse source order because that is the order the armed statements are
      executed in, so nothing has to walk it backwards (ADR-0175). }
    defers: nodeListPtr;
    deferCount: integer;
    { AP 6.9.3.12 (ADR-0268): this routine's block contains a
      spawn-statement, so its activation needs a task-set slot and must join
      what it spawned before it ends. A boolean and not a count, the set
      growing in the runtime -- and recorded by Sema rather than found by
      CodeGen walking the tree, which is ADR-0111's rule and ADR-0230's. }
    spawns: boolean;
    { AP 6.7.8: this routine was declared `task` and not `procedure`, so
      only a spawn-statement may start an activation of it. }
    isTask: boolean;
    { AP 6.7.5.9: the block a `br` leaves this activation through, or 0 where
      no exit-statement was emitted. It is CodeGen's and is claimed by the
      first `exit` of a function body -- the label is written before the
      block it names, which textual IR admits and an instruction list would
      not have. BeginFunction clears it, so a block emitted more than once
      (a module's initialization and its finalization) numbers each. }
    exitBlock: integer;
    resultVar: symPtr;
    { 6.7.2: a result-variable-specification was written, so the body names
      the result and must *not* assign to the function identifier. Without one
      the body must assign to it at least once -- the two rules are exclusive,
      which is why one flag answers both. assignedResult is the syntactic
      containment the standard asks about: an assignment inside an `if`
      counts. }
    resultNamed, assignedResult: boolean;
    { 6.9.4's *threatens*, recorded on the symbol as it is seen. It is what
      6.7.2 asks of a **result variable**, where assignedResult is what it asks
      of a function identifier -- and the two words are not the same one: a
      `read` into the result, or passing it to a var parameter, threatens it
      and assigns nothing. Set by `Threatened`, which is called at every one of
      the clause's six sites and nowhere else, so this is that list rather than
      a second reading of it (ADR-0134). }
    wasThreatened: boolean;
    { The result-variable-specification's identifier as the *source* spells it.
      resultVar's own name is that spelling with `$result` appended, which the
      program deliberately cannot write, so the binding needs this instead.

      It is kept on the symbol rather than read off the declaration node
      because §6.7.2 puts the defining-point in "the block of the
      function-block, if any, associated with the identifier of the
      function-heading" -- and for a `forward` the heading and the block are in
      *different* declarations. That is the same phrase the clause uses for the
      formal-parameter-list one paragraph later, and the parameters have always
      reached a forward body by living on the symbol; the result variable did
      not, and that asymmetry was the defect. }
    resAt, resLen: integer;
    { The result type was refused, so `never assigns its result` is
      suppressed: the body cannot assign a type the heading does not have, and
      one mistake deserves one message. }
    resultTypeBad: boolean;
    defined: boolean;
    { 6.4.7: the type-denoter a schema produces its types from, re-resolved
      once per distinct tuple with the discriminants bound to that tuple's
      values -- which is why a schema keeps its *syntax* and not a type. The
      formal discriminants carry only a name and an ordinal type. }
    schemaBody: nodePtr;
    { AP 6.7.3.5's generic routine (ADR-0211), and the shape is the schema's
      one line above: a routine with a type parameter keeps its *syntax* and
      not a translation, because a type cannot travel in a descriptor
      (ADR-0040) and so one compiled body cannot serve every T. What is kept
      is where to start reading it again -- genBodyPos is the token index of
      its block -- and everything needed to read it in the region it was
      written in rather than the one a call stands in: the scope as it was at
      the declaration, and which source it came from, for ADR-0210.

      genInsts is the cache, keyed by the tuple of type-ids the call named, so
      two calls with the same T share one translation and a recursive call
      finds the instantiation already in progress. isGeneric is what stops the
      generic itself from being given formals, a body or a frame: it is a
      declaration and never a procedure. }
    { AP 6.4.4.1 (ADR-0213): a schema derived from another by binding its type
      discriminants and leaving its ordinal ones open. `boundOf` is the schema
      it came from and `boundTypes` are the bindings to install before the body
      is resolved -- so everything downstream sees an ordinary schema whose
      discriminants happen to be exactly the ordinal ones, and `^Vec(integer)`
      is `^IntVec` with the element decided. }
    boundOf: symPtr;
    boundTypes, boundTypeTail: symListPtr;
    isGeneric: boolean;
    genBodyPos: integer;
    genDeclTop: entryPtr;
    genDeclDepth, genFileIdx: integer;
    genDecl: nodePtr;
    genBlock: nodePtr;
    genInsts: instPtr;
    genOf: symPtr;
    discs, discTail: symListPtr;
    { 6.7.3.2 and 6.7.3.3: the schema a formal parameter was written as the
      bare name of. Its type is then produced *generically* -- the
      discriminants become skDisc symbols reading this parameter's descriptor
      rather than constants -- so one compiled body serves every tuple an
      actual may bring. discSyms are those symbols, in the schema's order, and
      their storage is inside this parameter's frame slot after the address.
      discIndex is which of them a skDisc is; paramSection is which
      formal-parameter-section declared a parameter, because 6.7.3.3 requires
      every actual in one section to bring the same tuple. }
    descSchema: symPtr;
    { ISO 7185 6.6.3.7: this parameter's type came from a conformant array
      schema rather than from a schema-name. The descriptor is the same object
      either way -- ADR-0113's BoundSchemaFor builds it for both -- and what
      differs is the *call site*: a schematic formal wants an actual produced
      from its own schema, and a conformant array parameter wants one
      conformable with the schema (6.6.3.8), which is a rule about bounds and
      not about identity. }
    isConformant: boolean;
    { ...and this one of them is the parameter that *declares* the section's
      bound-identifiers. 6.6.3.7.1 gives them one defining-point per
      index-type-specification, not one per name, so a section naming two
      parameters binds them once -- and the block's scope has to be told which
      of the two carries them, the parameter list's scope having been popped
      before the body is entered. }
    confBinds: boolean;
    discSyms, discSymTail: symListPtr;
    { The actual-discriminant-part of a variable whose discriminants are not
      constants, in order -- the expressions the prologue evaluates on entry
      (6.2.3.2). Nil for a schematic formal parameter, whose tuple the caller
      brings, which is what tells the two apart wherever it matters. }
    discExprs: nodePtr;
    { The one expression *this* skDisc reads, for a variable whose type has no
      schema in the source: `var a: array [1..m] of real` has an
      actual-discriminant-part nowhere, so there is no list to walk in step and
      each discriminant carries its own bound instead (ADR-0113). Nil for every
      discriminant that came from a written schema, where discExprs above is
      the list. }
    discExpr: nodePtr;
    discIndex, paramSection: integer;

    { The two halves 6.2.3.8 b) needs at a *type-definition* (ADR-0127). The
      clause evaluates a subrange-bound or an actual-discriminant-part closest-
      contained by the block once, at the block's commencement -- and a
      type-definition is contained by the block, so the descriptor belongs to
      the block rather than to any one variable of the type.

      boundsOwner is that block-level descriptor: a hidden frame variable made
      for the type-definition, which fills its discriminants on entry and
      allocates nothing, a type having no storage. boundsFromType is a variable
      of such a type: its descriptor holds only the address, because the
      discriminants it reads are the *type's* and its discSyms are that same
      list, reached through the owner's frame slot exactly as any other
      discriminant is. }
    boundsOwner, boundsFromType: boolean;

    { A skDisc whose storage is not in any activation record: the tuple of a
      variable created by `new` lives in a header immediately before it, so
      this one is read from the object's own address rather than by walking
      the static chain (ADR-0043). }
    heapDisc: boolean;

    { This symbol is a schema's discriminant, bound for as long as the body is
      being resolved -- an skConst in a production with a tuple and an skDisc
      in a generic one. Both forms answer 6.4.3.4's question "is this name in
      the variant-selector a discriminant-identifier?", which the *kind*
      cannot, because an ordinary constant is also an skConst and is not
      one. }
    discBinding: boolean;

    { ISO/IEC 10206:1991 6.7.3.1's `protected`: no statement of the body may
      *threaten* this parameter (6.9.4). It says nothing about how the argument
      travels -- a protected var parameter is still an address -- so it is a
      Sema-only property and CodeGen never reads it. It also rides on the
      hidden binding a `with` makes, because 6.5.1 asks about the
      variable-access's *closest-containing* variable-identifier and a `with`
      is where that name stops being written down. }
    isProtected: boolean;

    { Where a *nested* block threatens this variable, or 0. 6.8.3.9 forbids
      the procedure-and-function-declaration-part of the block containing a
      for-statement to threaten its control-variable, and those bodies are
      walked before the statement part that loops -- so the threat is recorded
      when it is seen and the for-statement asks afterwards. A threat from the
      containing block's own statements is *not* recorded: the clause names
      the for-statement and the declaration part, and nothing else. }
    threatLine, threatCol: integer;

    { ISO/IEC 10206:1991 6.4.3.3.3's *required* schema `string`. It has no
      body: what it produces is a variable-string-type, whose representation
      the compiler fixes rather than the program's text. The flag is what tells
      ProduceFromSchema to build one instead of resolving a denoter. }
    isStringSchema: boolean;
    { AP 6.4.15.1's required schema `utf8`, which produces a text-type the
      way `string` produces a variable-string-type. Its one discriminant is
      also spelled `capacity` and is also a count -- of bytes, where the
      string's is of characters (ADR-0189). }
    isTextSchema: boolean;

    { ISO/IEC 10206:1991 6.4.1's `bindable`. 6.7.5.6 makes it a
      dynamic-violation to `bind` a file variable that is not one, and 6.5.1
      makes such a variable totally-undefined until it is bound -- so this is
      the one property of a variable that says something about the world
      outside the program. }
    isBindable: boolean;

    { 6.11.1's module. It is an skProc because it owns an activation record and
      procedures nest inside it exactly as they nest inside the program -- but
      it is never called, and it has exactly one activation, which is what lets
      its frame be a global (ADR-0053). }
    isModuleSym: boolean;
    { 6.11.4.2: whether the required text file is *implicitly accessible* in
      this level-0 block. It is a property of the block and not of the program
      -- a module that neither lists `output` as a module-parameter nor imports
      StandardOutput may not write, however many other blocks do. }
    stdInputOk, stdOutputOk: boolean;
    { The constituents an imported-interface-identifier makes reachable as
      `i.x`. Only a symbol of kind skInterface has any. }
    constituents, constitTail: constitPtr;
    { The modules whose interfaces this block imports, directly. 6.2.2.13's
      "supplies" is the transitive closure of this, and the program's copy is
      what decides which modules are activated at all. }
    importedFrom, importedTail: symListPtr;

    { 6.13. This module's own program-component was translated separately, so
      this translation has its heading and not its block: no body of its is
      emitted, its activation record is declared rather than defined, and
      every name of its reached from here is reached by its linkage name. }
    compiledElsewhere: boolean;
    { The linkage name of this symbol's storage, for the one case where a
      frame index cannot say where something is: the other side of a component
      boundary decided that layout, and a *name* is all two translations can
      agree on. linkKind says which shape it takes -- lnkNone, lnkVar and
      lnkProc build it from the interface and constituent spellings both ends
      have read, and the two lnkStd forms are the required files, whose names
      are fixed because 6.10 and 6.11.4.2 make them one per program however
      the program was divided. }
    linkKind: integer;
    linkIfaceAt, linkIfaceLen: integer;
    linkItemAt, linkItemLen: integer;
    { ...and whether the storage that name denotes is defined by *another*
      component. Both ends compute the same name; this is which end this is. }
    storageElsewhere: boolean;

    { ISO 7185 6.2.2.9: "The defining-point of an identifier or label shall
      precede all applied occurrences of that identifier or label contained by
      the program-block". `usedSeq` is when this symbol was last applied, on a
      counter that only goes up, and `scopeMark[d]` is that counter when the
      block at depth d was entered -- so "applied inside the block being
      declared into" is one comparison. The *latest* application is enough:
      the check runs at a defining-point, so nothing later has happened yet,
      and if the newest application is not inside this block then none is. }
    usedSeq: integer;

    { ISO/IEC 10206:1991 6.6: the value this variable bears when the block that
      declares it is entered. Borrowed from the AST and read only by the
      prologue -- every expression in one is nonvarying (6.8.2), so it is
      emitted where it stands rather than folded. For an skType it is the
      initial state the *type-name* hands on (6.4.1). }
    initValue: nodePtr
  end;

  { Every type produced from a schema, keyed by the schema and the tuple.
    6.4.8 makes a type produced with one tuple distinct from one produced with
    any other and from every type of any other schema -- so this list is the
    whole of that rule, and Assignable needs no case for schemata. }
  producedRec = record
    schema: symPtr;
    tuple: numPtr;
    ty: typePtr;
    next: producedPtr
  end;

  { AP 6.7.3.5: one translation of a generic routine, keyed by the tuple of
    type-ids its call named -- ADR-0039's interning, for a routine instead of
    a type, and for the same reason: two calls naming the same T must reach
    one translated body, or a recursive one would instantiate for ever. The
    tuple is the key and `sym` is the routine it produced. }
  instRec = record
    tuple: numPtr;
    sym: symPtr;
    next: instPtr
  end;

  { AP 6.4.4.1: one derived schema per (schema, tuple of type-ids), so
    `^Vec(integer)` written twice is one type (ADR-0213). }
  boundRec = record
    schema: symPtr;
    tuple: numPtr;
    derived: symPtr;
    next: boundPtr
  end;

  { A name bound in a scope. Kept apart from the symbol it names because the
    same symbol is bound twice -- once where a parameter is declared, and again
    when the procedure's body puts it back in scope. }
  entryRec = record
    at, len: integer;
    depth: integer;
    sym: symPtr;
    prev: entryPtr
  end;

  { ISO/IEC 10206:1991 6.11.2: one name an interface makes available. The
    spelling is what an importer writes and is not the symbol's own, since
    either end may rename it. `protected` travels with the *constituent*
    rather than with the symbol, because the module that exported it may still
    write to the variable. }
  constitRec = record
    at, len: integer;
    sym: symPtr;
    isProtected: boolean;
    next: constitPtr
  end;

  { 6.2.2.2 makes an interface a region that "shall not be a part of the
    program text and shall be disjoint from every other interface" -- so it is
    not a scope of the module that wrote it, and one list serves the whole
    program-block. }
  ifaceRec = record
    at, len: integer;
    { 6.11.1's export-part is where an interface-identifier's defining-point
      is, and until ADR-0248 this record held the name and not the place. An
      interface is found by spelling -- `FindInterface` walks this list
      comparing the pool -- so nothing in the compiler had ever needed it, and
      a tool asking where an `import` leads had nothing to be told.

      0 for the two required interfaces, which are built by the compiler and
      written in no source; `declFile` indexes importName, and is spelled as
      the symbol's and the field's are rather than as `file`, which §6.1.2
      reserves. }
    line, col, declFile: integer;
    owner: symPtr;
    items, itemTail: constitPtr;
    next: ifacePtr
  end;

  { A module's heading and its block may be two separate program-components,
    so the scope the heading built has to survive until the block arrives --
    6.2.2.12 makes every defining-point of the heading one of the block's. The
    scope stack is a chain, so keeping its top and its depth is keeping it. }
  modRec = record
    at, len: integer;
    sym: symPtr;
    savedTop: entryPtr;
    savedDepth: integer;
    headingSeen, blockSeen: boolean;
    headingDecl, blockDecl: nodePtr;
    line, col: integer;
    next: modRecPtr
  end;

  { A pointer type whose domain named a type not yet defined: ISO 7185 6.4.4
    allows exactly this, and it is the only forward reference in the language
    (ADR-0019). }
  { 6.4.4's schema domains, one type per schema. Not the intern table of
    ADR-0039: that is keyed by (schema, tuple) and these have no tuple. }
  { One discriminant of the tuple `new` is building, before there is a block
    to put it in front of. }
  discValPtr = ^discValRec;
  discValRec = record
    idx: integer;
    value_: str;
    next: discValPtr
  end;

  heapTypePtr = ^heapTypeRec;
  heapTypeRec = record
    schema: symPtr;
    ty: typePtr;
    next: heapTypePtr
  end;

  { --dump-layout's subjects: every record type-definition Sema resolved, in
    the order they were written. Built only when the flag is set, which is
    --coverage's discipline (ADR-0104) -- a compilation that is not asking
    this question pays one boolean test per type-definition.

    --dump-dispatch keeps a second list of the same shape, of every
    *enumeration* type-definition (ADR-0229). It needs the declarations and
    not only the dispatch sites, because an enumeration no case-statement
    mentions at all has every constant unnamed and reaches no site to be
    found at. }
  layoutPtr = ^layoutRec;
  layoutRec = record
    at, len: integer;
    ty: typePtr;
    next: layoutPtr
  end;

  { --dump-dispatch's subjects (ADR-0229): every case-statement whose selector
    is an enumeration, with how many of that enumeration's constants its labels
    name. Built only when the flag is set, which is --coverage's discipline
    (ADR-0104) and --dump-layout's: a compilation not asking the question pays
    one boolean test per case-statement. }
  dispatchPtr = ^dispatchRec;
  dispatchRec = record
    { the enclosing routine, and the enumeration dispatched on }
    procAt, procLen: integer;
    ty: typePtr;
    { how many constants the labels name, and how many the type has. The pair
      is the point: a constant added to the enumeration moves every M over it,
      so every site that names a subset has to be looked at again. }
    named, total: integer;
    hasOtherwise: boolean;
    { the label ranges, kept so the dump can *name* the constants no arm
      selects. A count says a site needs looking at; the names say what to
      look for, which is what the catalogue's failure message has always
      given and what a replacement for it must go on giving. }
    ranges: rangePtr;
    line, col: integer;
    next: dispatchPtr
  end;

  { --dump-dispatch's other half (ADR-0230): an if-chain that dispatches on a
    tag. Two lists, because a chain is a *shape* and not a node -- there is no
    if-chain in the tree, only an if whose else-part is another if.

    `chainRec` records every if-statement, so a head can be told from a
    continuation: a head is one that is no other's else-part. `tagRec` records
    every test of an enumeration-valued expression against a constant of its
    own type, keyed by the if whose condition held it -- one record per test,
    because a single condition may hold several and a single chain may
    dispatch on more than one enumeration at once. }
  chainPtr = ^chainRec;
  chainRec = record
    node, elsePart: nodePtr;
    procAt, procLen: integer;
    line, col: integer;
    next: chainPtr
  end;

  tagPtr = ^tagRec;
  tagRec = record
    node: nodePtr;
    ty: typePtr;
    ord_: integer;
    { the field the test read, when the tested side is a field-designator, and
      zero when it is anything else. It is what tells a *tag* dispatch from a
      lookahead ladder: `e^.kind = nkVar` asks a value for its own kind, and
      `t = tkSemi` asks whether a token happens to be a semicolon. The reader
      this replaces approximated the same thing by matching the text `^.kind`,
      which is why it saw no chain over any other field -- and missed three
      over the fields it could see. }
    fieldAt, fieldLen: integer;
    next: tagPtr
  end;

  pendingPtr = ^pendingRec;
  pendingRec = record
    ptype: typePtr;
    at, len: integer;
    line, col: integer;
    { Set when the domain is a schema that was still being produced: the
      recursion 6.4.7 permits in a pointer domain, which cannot be resolved
      until that production has finished and can be memoised. }
    schema: symPtr;
    next: pendingPtr
  end;

  { A string constant of the generated program: a runtime-error message, an
    external file's name, or a string literal. A global cannot be written in
    the middle of a function, so it is numbered where it is used and its text
    written after the last one. }
  strConstPtr = ^strConstRec;
  strConstRec = record
    id: integer;
    at, len: integer;
    next: strConstPtr
  end;

  { The storage of a 6.8.7 constant. A constructor has no storage of its own --
    ADR-0061 builds one into a hidden frame slot, and a constant cannot use
    that, because one node serves uses in blocks that have no such frame -- so
    it gets a global, filled once by the prologue of the block that defined it
    (ADR-0069). Keyed by the *node*, not by the symbol, so `const b = a` shares
    a's storage rather than copying it: the two names denote one value, and the
    folder hands on one node. `at`/`len` is a name for the reader; the number
    is what makes it unique, since two blocks may each define `c`. }
  constGlobalPtr = ^constGlobalRec;
  constGlobalRec = record
    id: integer;
    at, len: integer;
    cvalue: nodePtr;
    ctype: typePtr;
    next: constGlobalPtr
  end;

  { AP 6.4.14 (ADR-0181): the release routine for one owned pointer's domain.
    A generated function per domain type rather than straight-line code,
    because a type may own something of its own type and a list has no length
    the emitter knows -- so the recursion has to be in the emitted program.
    Keyed by the *domain*, since that is the whole of what the routine walks;
    two `owned ^Node` denoters are two types (6.4.1) and share one routine.

    `emitted` is what makes the recursion terminate: the number is handed out
    when the first call is written and the body is emitted from a worklist
    afterwards, so a routine that calls itself finds its own entry rather than
    asking for a second one. }
  ownRelPtr = ^ownRelRec;
  ownRelRec = record
    dom: typePtr;
    id: integer;
    emitted: boolean;
    next: ownRelPtr
  end;

  { An argument's operand, held until the whole list is known: the call line
    cannot be written until every argument's instructions have been. }
  opndPtr = ^opndRec;
  opndRec = record
    text: str;
    { How the operand is spelled on the call line. A parameter contributes one
      operand, except a procedural one, which contributes two -- so the type
      travels with the operand rather than being re-derived by walking the
      parameter list a second time. }
    asPtr: boolean;
    otype: typePtr;
    next: opndPtr
  end;

  node = record
    line, col: integer;
    { The sibling list that a std::vector<...Ptr> becomes. }
    next: nodePtr;
    { The type of an expression, or the type a type-denoter resolved to. A node
      is never both, so one field serves -- the same sharing typeRec.elem uses,
      and what the C++ splits over Expr::type and TypeExpr::resolved. }
    ntype: typePtr;
    { ISO/IEC 10206:1991 6.6's initial-state-specifier, `value <expression>`.
      It hangs off the *type-denoter* (6.4.1) rather than the declaration,
      which is why it is here and why `type count = integer value 1` gives the
      initial state to every variable of `count`. It is in the fixed part
      because 6.4.1 offers it to every denoter, whatever kind, and a variant
      field could not be shared across them. nsOk is Sema's: set when the
      specifier passed its checks, so a rejected one cannot reach CodeGen. }
    nsValue: nodePtr;
    nsOk: boolean;
    { ISO/IEC 10206:1991 6.4.1's `bindable`, which precedes the denoter where
      the initial-state-specifier follows it. A variable of a bindable type may
      be bound to an entity outside the program (6.7.5.6), and 6.5.1 makes it
      totally-undefined until it is. }
    nsBindable: boolean;

    { ISO 7185 6.6.3.3 / ISO/IEC 10206:1991 6.7.3.3: "The actual-parameter
      shall be a variable-access", and 6.5.1's four variable-accesses do not
      include a parenthesised expression -- `p((x))` passes a value, and there
      is nothing to establish a reference to. The parser drops the brackets,
      `(a + b) * c` being the node `a + b` is, so the node has to remember they
      were written. Nothing else reads this. }
    nParen: boolean;
    { AP 6.7.3.10.4: this actual has already been checked, by the inference
      that read its type in order to bind a type parameter (ADR-0254).
      CheckArguments would otherwise check it a second time, and CheckExpr is
      not idempotent -- it writes a `use` line for every applied occurrence
      (ADR-0246), so an editor would be told twice where a name is declared,
      and it claims a frame slot for a nested call's result, so the frame
      would grow a slot nothing reads. Set nowhere else and read nowhere
      else. }
    nChecked: boolean;
    { Where the construct this node is ends: the line of its last token and one
      past that token's last character (ADR-0258). Zero on a node nothing
      stamped, which is every node that is not a statement -- the parser knows
      a statement's extent because it is standing past it when the production
      returns, and knows nothing of the kind about an expression it built
      bottom-up.

      **Not the position of the next token**, which is what a block's own end
      is (ADR-0253) and is right there because a block's `end` is followed by
      `;` or `.` immediately. After a *statement* the next token is `;`, `end`,
      `else`, `until` or `otherwise`, routinely on a later line and with
      comments in between -- and a comment is not a token, so that position
      would swallow whatever a reader wrote after the statement. }
    endLine, endCol: integer;
    case kind: nodeKind of
      nkInt:        (intVal: integer);
      { A real literal is kept as its source text and not converted. The
        comparison is on text for the reason ADR-0022 gives, and an untested
        conversion would be worse than an absent one; it arrives with Sema,
        which is the first stage that needs the value. }
      nkReal:       (rlAt, rlLen: integer);
      { ADR-0128, and the same field pair for the same reason: the digits, in
        the pool, carried to the code generator without ever being a value. }
      nkInt64:      (i64At, i64Len: integer);
      nkChar:       (chVal: char);
      nkStr:        (stAt, stLen: integer);
      nkNil:        ();
      { A set constructor and one of its members. A member with no `smHi` is a
        single value and one with it is the range ISO 7185 6.7.1 abbreviates;
        the bounds need not be constant, so a range is not expanded here. }
      nkSet:        (seMembers: nodePtr);
      nkSetMember:  (smLo, smHi: nodePtr);
      { vrSlot: a parameterless function written as a bare name is a call
        (ISO 7185 6.8.2.2), and a result that lives in memory needs storage the
        caller supplies -- so this node takes a result slot exactly as nkCall
        does. nil unless vrSym is invocable with such a result. }
      nkVar:        (vrAt, vrLen: integer; vrSym: symPtr; vrField: fieldPtr;
                     vrSlot: symPtr;
                     { AP 6.7.6.10's `argcount` written bare: a call with no
                       parameter list, which the parser cannot tell from a
                       variable and Sema can, by looking the name up. The
                       husk rule (ADR-0044): this node stays, the call hangs
                       here, and every later pass reads this field first.
                       Decided in Sema and not in the parser because a
                       program of the contained standard may declare its own
                       `argcount` -- a variable, even -- and must keep it
                       (ADR-0173). }
                     vrCall: nodePtr);
      { ixSetValue is 6.8.7.4's set-value, `digits[1, 3]`. Its tokens are a
        subscript's, so the parser builds this spine and Sema tells the two
        apart by the symbol at the root of it -- the same shape as
        fdQualified, and for the same reason (ADR-0066). When it is set the
        spine is not a designator at all and this is what it means; the member
        expressions have been moved out of the spine into it. }
      nkIndex:      (ixBase, ixIndex: nodePtr; ixSetValue: nodePtr);
      { 6.5.6's substring-variable when the base is a string-*variable*, and
        6.8.6.5's substring-function-access when it is a function-access -- one
        kind, because the two differ only in whether the base is a designator,
        and IsDesignator asks the base that anyway. The type is the
        canonical-string-type, a pointer and a length: 6.5.6 calls it "a new
        fixed-string-type" of capacity ssHi - ssLo + 1, and that capacity is
        not a compile-time number. Nothing observable needs it to be one --
        the only rule that reads it is the store, which reads it at run time
        from the same subtraction.

        ssSetValue carries the same second reading ixSetValue does: a `..` in
        brackets is a substring or a member-designator of a set-value, and the
        parser cannot tell which. ssListed says a comma followed the range in
        the same brackets, which only a set-value may have -- 6.5.6 gives a
        substring one range and no list, and without that flag the parser's
        relaxation would quietly make `s[1..3, 2]` mean `s[1..3][2]`. }
      nkSubstr:     (ssBase, ssLo, ssHi, ssSetValue: nodePtr;
                     ssListed: boolean);
      { 6.8.7's structured-value-constructor. svAt/svLen is the type-name, and
        is empty (svLen = 0) for a component-value nested inside another, which
        takes the type of the component it is for. svTagValue and svVariant are
        6.8.7.3's variant-part-value: the constant-tag-value and the
        field-list-value it selects, the latter a structure-value of its own
        because an arm's field-list may hold a variant part in turn (ADR-0026).
        svSlot is where the value is built -- an array and a record have no
        register form (ADR-0017), so a constructor of one needs storage, and it
        is the hidden frame slot a memory-living function result gets. }
      nkStructValue: (svAt, svLen: integer; svElems: nodePtr;
                      svTagAt, svTagLen: integer;
                      svTagValue, svVariant: nodePtr;
                      svArm, svTagOrd: integer; svSlot: symPtr);
      { One element. veLabels holds the selectors -- 6.8.7.2's case-constant
        list for an array-value and 6.8.7.3's field-identifiers for a
        record-value, which are the same tokens until the type says which. So
        only the resolved side is separate: veValues for the folded ranges of
        an array-value, veFields for the field numbers of a record-value. }
      nkValueElem:   (veLabels, veValue: nodePtr; veCompleter: boolean;
                      veValues, veValueTail: rangePtr;
                      veFields, veFieldTail: numPtr);
      { ISO/IEC 10206:1991 6.8.4's schema-discriminant, `v.n`: the base
        possesses a type produced from a schema and the name is one of that
        schema's formal discriminants. It shares its syntax with a field
        selection and nothing else -- there is no field, and fdResolved stays
        nil. Sema folds it to the tuple's value. }
      { fdQualified is 6.11.3's qualified name, `i.x`: the base names an
        imported interface rather than a record, so the whole selection denotes
        one symbol and there is no base to evaluate. Sema decides which reading
        this is -- the syntax is the same, and only the symbol the base
        resolves to can tell them apart. }
      nkField:      (fdBase: nodePtr; fdAt, fdLen: integer;
                     { Where the field-identifier itself is, which the node's
                       own line and column are not: those are the `.` before
                       it, the parser having built this node before reading
                       the name. Whitespace is legal on either side of a
                       point, so the two cannot be derived from each other --
                       and a caller resolving a source position needs the
                       name's own extent (ADR-0246). }
                     fdLine, fdCol: integer;
                     fdResolved: fieldPtr; fdQualified: symPtr;
                     fdIsDisc: boolean; fdDiscValue: integer;
                     { ...unless the base is a schematic formal parameter,
                       whose type was produced with no tuple at all: then the
                       value arrives with the actual and this is the skDisc
                       symbol that reads it out of the descriptor. Exactly one
                       of the two is how a discriminant answers. }
                     fdDiscSym: symPtr;
                     { The same slot vrSlot is, for 6.11.3's qualified name
                       denoting a parameterless function. }
                     fdSlot: symPtr);
      nkDeref:      (drBase: nodePtr);
      nkBinary:     (bnOp: binaryOp; bnLhs, bnRhs: nodePtr);
      nkUnary:      (unOp: unaryOp; unArg: nodePtr);
      { clSlot is where binding(f)'s result is built: a hidden frame variable
        of type BindingType, one per call site. 6.7.6.8 makes the result a
        record and this compiler returns no records, so the value needs
        somewhere to live -- and a frame slot is somewhere both backends can
        name without an alloca in the middle of a function. }
      { clQualAt/clQualLen is 6.11.3's qualified name in call position,
        `i.f(x)`. The parser decides this one on its own: a record field is
        never followed by `(`, so `a.b(` has exactly one reading. }
      { clOk, clFail and clVal are AP 6.8.9's try (ADR-0178), and they are a
        husk of the same kind (ADR-0044): Sema writes the three things the
        construct means and CodeGen emits them in order. clOk reads the
        operand's tag, clFail is the assignment of the cause to the enclosing
        function's result -- the same node an `exit(e)` hangs on pcExit, and
        emitted by the same routine -- and clVal reads the value. All three
        designate through clSlot, which for a try is a
        binding to the operand rather than storage for a result -- so the
        operand is evaluated once however many of the three are emitted, which
        is a `with` statement's shape and not a new one. }
      nkCall:       (clAt, clLen, clQualAt, clQualLen: integer; clArgs: nodePtr;
                     clBuiltin: builtinKind; clSym: symPtr; clSlot: symPtr;
                     clOk, clFail, clVal: nodePtr);
      nkEmpty:      ();
      { asFactory: AP 6.4.12.6 (ADR-0255). The value is a call of a function
        of *this program* answering a handle, so the target's address is what
        the callee is handed and the callee stores through it -- the value is
        born in the variable that will own it and is never held anywhere
        else. Nothing may store it again here: the callee's own
        `Open := ExtFopen(...)` already did, through this same address, and a
        second `pas_handle_set` would release what it just wrote.

        Sema's to decide and CodeGen's to obey, which is the contract: the
        answer is "was the callee an external declaration", and CodeGen never
        asks a question about a symbol's linkage that Sema could have
        answered. False for an external call, whose answer arrives in a
        register and is stored here as it always was. }
      nkAssign:     (asTarget, asValue: nodePtr; asFactory: boolean);
      { wrStr is 6.7.5.5's writestr: the string-variable written to. Non-nil
        makes this a writestr rather than a write, and then wrFile stays nil --
        the file is the auxiliary text variable the clause defines the
        statement in terms of, which the runtime supplies. It is *Sema* that
        moves it out of the argument list, because until the name has been
        looked up there is no telling a writestr from a call of a procedure
        the program declared under that name (ADR-0087); wrIsStr is the
        parser's half of that, and says only which word was written.
        wrAt/wrLen is that word, and wrCall is the other reading: an
        nkProcCall Sema builds when the program did declare one, after which
        the node this hangs off is a husk and every later pass reads the
        field first. }
      nkWrite:      (wrArgs, wrFile, wrStr, wrCall: nodePtr;
                     wrAt, wrLen: integer; wrNewline, wrIsStr: boolean);
      nkWriteArg:   (waValue, waWidth, waPrec: nodePtr);
      { rdStr is 6.7.5.5's readstr: the string-expression read from, and
        rdAt/rdLen/rdCall/rdIsStr have the meanings wrStr's neighbours have. }
      nkRead:       (rdArgs, rdFile, rdStr, rdCall: nodePtr;
                     rdAt, rdLen: integer; rdNewline, rdIsStr: boolean);
      nkCompound:   (cpBody: nodePtr);
      nkIf:         (ifCond, ifThen, ifElse: nodePtr);
      nkWhile:      (whCond, whBody: nodePtr);
      nkRepeat:     (rpBody, rpCond: nodePtr);
      { frSet is 6.9.3.9.3's set-member-iteration, `for v in s do`. Non-nil
        makes this the set form, and then frFrom and frTo are nil: 6.9.3.9.1
        makes the two an *iteration-clause*, one production with two
        alternatives, so they are one node with two shapes. }
      nkFor:        (frVar, frFrom, frTo, frSet, frBody: nodePtr;
                     frDownto: boolean;
                     { `for v in s` walks the base type's ordinals in a counter
                       the program cannot name and that has to survive from one
                       iteration to the next, so it needs storage. That storage
                       is a frame slot -- the shape a `with` binding already
                       has -- rather than an alloca, because an alloca is
                       written wherever the emitter has reached and a
                       `for ... in` nested in another loop would claim a fresh
                       one on every iteration of the outer one. nil for the
                       sequence form, whose limit needs no storage at all. }
                     frCounter: symPtr);
      { pcSelect: `new(p, c1, ..., cn)` -- the arms the tag values select,
        outermost first, as indices into the variant part at each level
        (ISO 7185 6.6.5.3). nil for the one-argument form.

        pcTagVals is the same list of *values*, and the two are parallel
        because an arm index is not a tag value: `1, 2: (…)` is one arm, and
        which of the two constants was written decides what 10206's 6.7.5.3
        stores in the tag-field. The path needs the index and the store needs
        the value, so both are kept rather than one derived from the other
        (ADR-0144). }
      { pcExit is AP 6.7.5.9's husk (ADR-0044): `exit(e)` assigns the result
        and then leaves, and Sema writes that assignment here -- moving the
        argument out of pcArgs, so that after Sema the node says what it does
        rather than what it was written as. Every rule about assigning a
        result then reaches it through the one routine that decides them. }
      nkProcCall:   (pcAt, pcLen, pcQualAt, pcQualLen: integer; pcArgs: nodePtr;
                     pcSym: symPtr; pcStd: stdProcKind;
                     pcSelect, pcTagVals: numPtr; pcExit: nodePtr);
      { The hidden frame slot the record's address is bound to. Sema makes
        it; CodeGen stores through it. }
      nkWith:       (wtRecord, wtBody: nodePtr; wtBinding: symPtr);
      { dfIndex is this statement's position among the block's defer-statements,
        which is the flag in the frame that says whether it is armed. Sema
        numbers them and pushes the node onto the block's list; CodeGen reads
        the list in that order, which is *reverse* source order and so is the
        order the armed statements run in. }
      nkDefer:      (dfStmt: nodePtr; dfIndex: integer);
      { The task and its actuals. spSym is the task-declaration's symbol and
        spArgs the actual-parameter-list, both what nkProcCall holds -- a
        separate kind rather than a flag on that one because what is emitted
        is not a call: it is an argument block, a copy of it, and a thread. }
      nkSpawn:      (spAt, spLen: integer; spArgs: nodePtr; spSym: symPtr);
      { csHasOtherwise, not `csOtherwise <> nil`: `otherwise` followed by
        nothing is an empty statement -- a legal way to say "and otherwise do
        nothing", which is exactly the case that must not trap. }
      nkCase:       (csSelector, csArms, csOtherwise: nodePtr;
                     csHasOtherwise: boolean);
      { `goto L` and `L: statement`. Sema resolves the number to the labelled
        statement's own id, which is what codegen branches to -- the number is
        not enough, since two blocks may each declare label 1. }
      { gtNonLocal: the label belongs to an *enclosing* block, so reaching
        it abandons every activation between here and that one. A different
        lowering, not a longer one: a branch cannot leave a function. }
      nkGoto:       (gtLabel, gtId: integer; gtNonLocal: boolean;
                     gtOwner: symPtr);
      nkLabeled:    (lbLabel, lbId: integer; lbStmt: nodePtr);
      nkLabelDecl:  (ldNumber: integer);
      nkCaseArm:    (caLabels, caBody: nodePtr;
                     caValues, caValueTail: rangePtr);
      nkDeclName:   (dnAt, dnLen: integer);
      { one type-denoter shared by a list of names: a field group, a variable
        declaration, or a parameter group -- or, when grIsProc, a single
        procedural or functional parameter written as a heading of its own
        (ISO 7185 6.6.3.1), which uses grParams and grResult in place of
        grType and always has exactly one name. }
      { grIsTypeDisc is AP 6.4.7's type-valued formal discriminant (ADR-0209),
        written `T: type`. grType is then nil: there is no type-name there to
        resolve, the word-symbol standing where one would be. }
      nkGroup:      (grNames, grType: nodePtr; grByRef, grIsProtected,
                     grIsProc, grIsFunction, grIsTypeDisc: boolean;
                     grParams, grResult: nodePtr);
      { nmQualAt/nmQualLen is 6.11.3's qualified name in a type-denoter. There
        is nothing else `a.b` could be there -- a type has no fields to select
        -- so unlike an expression this needs no help from Sema. }
      nkNamed:      (nmAt, nmLen, nmQualAt, nmQualLen: integer);
      { tqObj is AP 6.4.9's object when it is a *component* of a variable
        rather than a name: the dialect widens the type-inquiry-object to
        6.5.1's whole variable-access, and a selected one is parsed by the
        very production an expression's designator uses. Exactly one of the
        two shapes is filled -- a bare name stays a name, in tqAt/tqLen, so
        every rule 6.4.9 already had is asked the question it was written
        for and a program of ISO/IEC 10206:1991 takes the path it always took
        (ADR-0215). }
      nkInquiry:    (tqAt, tqLen, tqQualAt, tqQualLen: integer;
                     tqObj: nodePtr);
      { 6.4.2.5's restricted-type, `restricted type-name`. The syntax admits a
        *name* and nothing else, so there is no nested denoter and no recursion
        to bound. }
      nkRestricted: (rtAt, rtLen, rtQualAt, rtQualLen: integer);
      nkSchema:     (scAt, scLen, scQualAt, scQualLen: integer;
                     scArgs, scArgTail: nodePtr);
      { ptOwns: the denoter was `owned ^T` (AP 6.4.14, ADR-0181). A flag on
        the pointer rather than a node kind of its own, because every rule
        about a pointer -- the domain must be a name so a type may name
        itself, `nil`, the dereference -- is a rule about this one too. }
      nkPointer:    (ptAt, ptLen, ptQualAt, ptQualLen: integer;
                     ptOwns: boolean;
                     { AP 6.4.4.1 (ADR-0213): the actual type-discriminants of
                       a domain that names a schema with type discriminants,
                       `^Vec(integer)`. Only the *type* ones are given here;
                       the ordinal ones are still 6.7.5.3's, supplied by `new`.
                       nil for every other pointer, which is every pointer a
                       conforming program can write. }
                     ptArgs: nodePtr);
      nkOptional:   (opElem: nodePtr);
      { hdAt/hdLen name the closer. hdElem is nil for a handle-type written
        out (AP 6.4.12) and the element type for a channel-type (AP 6.4.16),
        which is a handle whose closer is the runtime's -- the denoter's own
        version of IsChannel's question. hdCap is the channel's capacity. }
      nkHandle:     (hdAt, hdLen: integer; hdCap, hdElem: nodePtr);
      nkFallible:   (faVal, faCause: nodePtr);
      { caLo and caHi are nkDeclName nodes -- these are defining-points, and a
        declared name is what that node kind is for. caIndex is the
        ordinal-type-identifier the two bounds are values of. }
      nkConfArray:  (caLo, caHi, caIndex, caElem: nodePtr; caPacked: boolean);
      nkEnum:       (enConstants: nodePtr);
      nkSubrange:   (sbLo, sbHi: nodePtr);
      nkArray:      (arDims, arElem: nodePtr; arPacked: boolean);
      { ISO/IEC 10206:1991 6.4.3.6: `file [ index-type ] of component-type`.
        The brackets are what make a file direct-access, and nothing else
        does -- so flIndex is the whole of the syntax the feature adds. }
      nkFile:       (flElem, flIndex: nodePtr; flPacked: boolean);
      nkSetOf:      (soElem: nodePtr; soPacked: boolean);
      nkRecord:     (rcFields, rcTagType, rcVariants: nodePtr;
                     rcTagAt, rcTagLen, rcTagLine, rcTagCol: integer;
                     rcPacked: boolean);
      nkVariantArm: (vaLabels, vaFields, vaTagType, vaVariants: nodePtr;
                     vaTagAt, vaTagLen, vaTagLine, vaTagCol: integer;
                     { the variant-part-completer of ISO/IEC 10206:1991: an
                       arm with no labels, selected by whatever the others
                       leave }
                     vaOtherwise: boolean);
      nkConstDecl:  (kdAt, kdLen: integer; kdValue: nodePtr);
      { tdDiscs is 6.4.7's formal-discriminant-part, and is nil for an
        ordinary type-definition: a schema is a type-definition that has not
        been told everything yet. Each entry is an nkGroup whose grType is the
        nkNamed ordinal type the discriminants possess. }
      nkTypeDecl:   (tdAt, tdLen: integer; tdType, tdDiscs, tdDiscTail: nodePtr);
      { pdInHeading: a heading in a module-heading's
        procedure-and-function-heading-part (6.11.1). It behaves exactly as
        `forward` does -- name and parameters here, body later, repeating the
        name alone -- so only the diagnostic tells the two apart. }
      { pdResAt/pdResLen: 6.7.2's result-variable-specification, the name
        the block calls its result by. Zero length where none was written,
        which is what decides whether `f := e` is required or forbidden. }
      { pdExtAt/pdExtLen: the foreign name of ADR-0121's `external`
        directive, which is a string-literal and not an identifier because
        this lexer case-folds identifiers and a linker symbol is matched
        exactly. Zero length where the directive was not written. }
      nkProcDecl:   (pdAt, pdLen, pdResAt, pdResLen: integer;
                     pdExtAt, pdExtLen: integer;
                     { AP 6.7.3.5 (ADR-0211): where this routine's block
                       begins in the token stream, and which source those
                       tokens came from. Both are needed only by a *generic*
                       routine, which is read again once per distinct type
                       argument -- what a schema does to its body's syntax
                       (ADR-0039), done to a block by starting the parser over
                       rather than by copying the tree it built. A copy would
                       be a second statement of every node's shape and free to
                       drift; re-reading the tokens is parsing, so it cannot
                       disagree with parsing. }
                     pdBodyPos, pdFileIdx: integer;
                     pdParams, pdResult, pdBody: nodePtr;
                     pdIsFunction, pdIsForward, pdInHeading: boolean;
                     pdIsExternal: boolean;
                     { AP 6.7.8 (ADR-0268): this declaration was written
                       `task` and not `procedure`, so an activation of it may
                       be started by a spawn-statement and by nothing else.
                       A flag rather than a kind of its own, which is
                       `owns`'s shape on a pointer: what changes is how the
                       activation is started, and nothing about the block. }
                     pdIsTask: boolean;
                     { Where the *name* was written, which the node's own
                       line and col are not: those are the word-symbol that
                       opened the declaration, and both tree dumps print them
                       that way. --dump-symbols reports a position a caller
                       slices the source at to recover the written spelling,
                       so it needs the identifier's own (ADR-0239). }
                     pdNameLine, pdNameCol: integer;
                     pdSym: symPtr);
      { 6.2.1 puts an import-part at the head of a block, before the label,
        constant, type, variable and procedure parts -- in every block, and
        not only a module's. There is at most one. }
      nkBlock:      (blImports, blLabels, blConsts, blTypes, blVars, blProcs,
                     blBody: nodePtr;
                     { Where the block *ends* -- the position just past its
                       closing `end`. The tree records where every declaration
                       begins and, until ADR-0253, nowhere recorded where one
                       stopped, so a tool asking for the extent of a procedure
                       could be given only the extent of its name. It is taken
                       in ParseBlock after the compound-statement, which is
                       the one place a block is finished. }
                     blEndLine, blEndCol: integer);
      { 6.11.1's module-declaration in whichever of its three forms was
        written. The heading and the block are one module however they were
        split, and 6.2.2.12 makes every defining-point of the heading one of
        the block's too -- so the two share one scope and one activation
        record. mdInit and mdFini are the `to begin do` and `to end do` parts,
        each a single *statement*. }
      nkModule:     (mdAt, mdLen: integer;
                     { The module name's own position, for the reason
                       pdNameLine gives (ADR-0239). }
                     mdNameLine, mdNameCol: integer;
                     mdParams, mdExports, mdHeading, mdBlock,
                     mdInit, mdFini: nodePtr;
                     mdHasHeading, mdHasBlock: boolean;
                     { A digest of the module-**heading**'s tokens, which is
                       what 6.11.1 makes the interface and therefore the whole
                       of what a client depends on (ADR-0245). Two 30-bit
                       hashes rather than one 64-bit one, because integer
                       arithmetic here traps on overflow (ADR-0014) and a
                       wrapping multiply is not available to say so.

                       Zero when this component holds no heading for the
                       module -- 6.11.1's `implementation` form, whose heading
                       came from another component -- and the emitter then
                       looks the digest up by name on whichever node does
                       hold one. }
                     mdDigest1, mdDigest2: int64;
                     { Which source this component was read from: 0 for the
                       one named on the command line, k for the k'th
                       --import. A module's block is parsed while reading its
                       own file and *checked* later, in the client, by which
                       time curFile has been put back -- so without this a
                       diagnostic inside an imported body carries the client's
                       name and the component's line number, which is a
                       position the named file need not even have. }
                     mdFileIdx: integer;
                     { 6.13: this program-component was accepted separately
                       and is read only for the interfaces its heading
                       exports. }
                     mdElsewhere: boolean; mdSym: symPtr);
      nkExportPart: (epAt, epLen: integer; epItems: nodePtr);
      { An export-clause and an export-range share this shape: a range is the
        one with eiLastLen > 0, and may not also be renamed, because what it
        exports is whatever principal identifiers the values already have. }
      { eiQualAt/eiQualLen and eiLastQualAt/eiLastQualLen are 6.11.3's
        qualified name in an export-list: a module may re-export what it
        imported `qualified`, and then the only name it has for it is `i.x`.
        The standard's own example 3 (6.11.6) does exactly this. }
      nkExportItem: (eiAt, eiLen, eiLastAt, eiLastLen,
                     eiNewAt, eiNewLen, eiQualAt, eiQualLen,
                     eiLastQualAt, eiLastQualLen: integer;
                     eiProtected: boolean);
      { The three modifiers are independent: `only` says the list is
        exhaustive rather than a set of renamings, and `qualified` says the
        names arrive only as `i.x` and never bare (6.11.3 NOTE 2). }
      nkImportSpec: (isAt, isLen: integer; isItems: nodePtr;
                     isQualified, isOnly, isHasList: boolean);
      nkImportItem: (iiAt, iiLen, iiNewAt, iiNewLen: integer)
  end;

  { The statements containing the one being checked, innermost first. Built by
    pushing a new cell in front of the current head and never mutated, so two
    paths *share* their common suffix -- which is what makes the prefix test in
    ResolveGotos a pointer comparison rather than a walk. }
  stmtPathPtr = ^stmtPathRec;
  stmtPathRec = record
    stmt: nodePtr;
    { True when this entry holds a *statement-sequence*, which 6.8.1 b) is
      about. A compound-statement and a repeat-statement hold one; so does
      ISO/IEC 10206:1991 6.9.3.5's case-statement-completer, which has no node
      of its own and so cannot be told from its case statement by kind. }
    seq: boolean;
    depth: integer;
    next: stmtPathPtr
  end;

  { One label of one block's label declaration part. ISO 7185 6.1.6 makes a
    label a number rather than a name, so it is not a symbol and does not go in
    a scope: two blocks may both declare label 1, and each means its own.
    `path` is what 6.8.1's restriction is stated over -- a goto may reach a
    label only when every statement containing the label also contains the
    goto. }
  labelInfoPtr = ^labelInfoRec;
  labelInfoRec = record
    number, id: integer;
    isDefined: boolean;
    line, col, defLine, defCol: integer;
    path: stmtPathPtr;
    { The labelled statement itself. 6.8.1 a) admits a goto that the labelled
      statement *contains*, which the path cannot answer -- the path says
      which statements contain the label, not whether the label contains the
      goto. }
    lnode: nodePtr;
    owner: symPtr;
    next: labelInfoPtr
  end;

  { A goto whose target is not resolved until the whole block has been walked:
    a label may be declared before the statement it labels appears, so a
    forward jump cannot be checked where it is written. }
  pendingGotoPtr = ^pendingGotoRec;
  pendingGotoRec = record
    gnode: nodePtr;
    gpath: stmtPathPtr;
    { True once the goto has been handed outwards because its label belongs to
      an enclosing block. The hand-off is what makes the diagnostic right: a
      nested procedure's body is checked *before* the statements of the block
      containing it, so where the goto is written the label it targets has not
      been seen yet and looks undeclared. }
    fromInner: boolean;
    next: pendingGotoPtr
  end;

  { The block number each label denotes, by the id Sema gave it. Per function,
    since a label belongs to exactly one block. }
  labelBlockPtr = ^labelBlockRec;
  labelBlockRec = record
    lid, blk: integer;
    next: labelBlockPtr
  end;

  labelScopePtr = ^labelScopeRec;
  labelScopeRec = record
    labels, labelTail: labelInfoPtr;
    gotos, gotoTail: pendingGotoPtr;
    outer: labelScopePtr
  end;



var
  { Which program-component the lexer is taking in (6.13): the source named on
    the command line, or the already-translated ones. }
  readingImports: boolean;
  line, col: integer;

  pool: packed array [1..poolMax] of char;
  poolLen: integer;
  tokCount: integer;

  { --- the parser --- }
  pos: integer;
  depth: integer;
  { The two halves of what the C++ parser gets from one exception: `aborted`
    stops every production, and `errorSeen` decides whether there is a tree to
    print at all. }
  aborted, errorSeen: boolean;
  errorCount: integer;
  progBlock: nodePtr;
  { 6.13's other program-components, in the order they were written, and how
    many of them precede the main-program-declaration. That order is also a
    legal *activation* order and no sort produced it: 6.2.2.9 already requires
    a module-heading to precede everything importing its interface, so a
    supplier is always textually earlier than what it supplies. }
  progModules, progModuleTail: nodePtr;
  progMainIndex: integer;
  { 6.2.3.6: the modules that supply the main-program-block, in the order
    their activations must commence. }
  activeModules: symListPtr;

  { --- the character sink (see Put) --- }
  msgOut: boolean;
  msgBuf: str;
  { False while the tree is dumped as the parser left it, true while it is
    dumped as Sema left it. One walker, two formats. }
  annotate: boolean;
  layoutHead: layoutPtr;
  programSym: symPtr;
  { --- CodeGen --- }
  ircode: bindText;         { where the IR goes: the name -o gave }
  { 6.13's already-translated program-components. Each --import names one, and
    this is bound to them in turn -- where the four-file interface took them
    concatenated into a single program parameter, because a program that cannot
    name a file cannot open several (ADR-0079). It can now. }
  imports: bindText;
  importName: array [1..maxImports] of nameStr;
  { Which stages to dump, if any. Dumping is *off* by default: a compiler is
    quiet when it succeeds. It was on unconditionally for as long as there
    were two compilers to compare, because the dumps were what
    selfhost/difftest.sh diffed and there was no second binary to select a mode
    on (ADR-0025) -- and that reason expired with stage 0, twice over now that
    ADR-0232 has retired difftest itself.

    `dumping` decides the diagnostic format as well as the sections. Inside a
    dump a diagnostic is `line col error message`, which is the format the two
    compilers agreed on while there were two; outside one it is
    `file:line:col: error: message`, which is what a person reads and what
    tests/*.err holds. }
  dumping: boolean;
  dumpLayoutOpt: boolean;
  dumpDispatchOpt: boolean;
  dispatchHead, dispatchTail: dispatchPtr;
  enumHead, enumTail: layoutPtr;
  chainHead, chainTail: chainPtr;
  tagHead, tagTail: tagPtr;
  { The file a diagnostic belongs to: the source, or whichever already-
    translated component is being read (6.13). Only the human-readable format
    names it -- inside a dump the file is the one the harness passed. }
  curFile: nameStr;
  { Which --import is being read, for the module nodes built while reading it
    (0 = the source named on the command line). Parse-time only: Sema reads
    nkModule's own copy, the parser having moved on by then. }
  curImportIdx: integer;
  { --dump-uses: write every applied occurrence and the defining-point it
    resolved to, as Sema resolves it (ADR-0246). It is a flag on the *lookup*
    and not a walk over the finished tree, for the reason ADR-0111 gives about
    the string arena's counter and ADR-0230 gives about the dispatch dump: the
    stage that resolved a name already knows it resolved one, and a second
    reader of the tree would be a second opinion free to drift -- and free to
    miss a node kind, silently, which is the failure `kind-exhaustive` exists
    to make loud.

    Off by default and read once per lookup, which is --coverage's discipline
    (ADR-0104): a compilation that is not asking pays one boolean test. }
  notingUses: boolean;
  { ADR-0258: `--dump-stmts` is on, so the parser reports each statement's
    extent as it finishes one. The same shape `notingUses` has and for the
    same reason -- the stage that did the work already knows the answer, and a
    walker over the finished tree would be a second reader of a variant record
    free to miss a node kind in silence (ADR-0230). }
  notingStmts: boolean;
  { The source named on the command line, against which `curFile` says whether
    the text Sema is checking belongs to *this* document. It is the one fact
    already maintained for that purpose -- CheckModule sets curFile from the
    module's own file and puts it back -- so nothing new has to be kept in
    step with it, which a shadow index would have been. }
  mainFile: nameStr;
  { Where the source named on the command line begins in the token array.
    Everything before it belongs to an --import and is kept rather than
    overwritten (ADR-0212), so the two places that mean *this source* -- the
    token dump and nothing else -- start here instead of at 1. }
  mainTokBase: integer;
  { Every instantiation AP 6.7.3.10 produced, in the order they were demanded.
    They are emitted from here rather than from the block their generic was
    declared in, because that block may belong to a module translated
    elsewhere -- and this translation is the one that asked for the type, so
    it is the one that must contain the routine. }
  instDeclHead: nodePtr;

  { the predefined types, shared singletons }
  intType: typePtr;
  { ADR-0128. A required identifier 6.1.3 lets any program shadow, so it is
    reached by name only where nothing has, and it is built unconditionally:
    a type object costs one record. It was conditional on nothing even while
    there were modes, so that no predicate naming it had to test one. }
  int64Type: typePtr;
  { AP 6.4.15.7's result: a text-type with no capacity, as
    canonStringType is a variable-string with none. What `+` yields has
    to fit any target, so it carries no capacity to exceed and the
    store is where 6.4.15.5's fit is checked. }
  canonTextType: typePtr;
  { 6.4.3.3.3's required schema `string`. Kept because a type produced from it
    has to be interned by (schema, tuple) -- 6.4.8 -- and BindingType's `name`
    field is such a production made where there is no denoter to resolve. See
    StringOfCapacity. }
  stringSchema: symPtr;
  { AP 6.4.12 (ADR-0174): every foreign name some handle-type names as its
    closer, once each. CodeGen declares each as `i32 (ptr)` unless an
    `external` heading already declared the name, and Sema holds such a
    heading to that shape so the two declarations agree. }
  handleClosers: namePtr;

{ ------------------------------------------------------------------ strings }
procedure StrClear(var s: str);

{ Drops what will not fit, in silence, and that is deliberate (ADR-0110): this
  is the generic append and builds diagnostic messages as well as tokens, where
  there is no source position to attribute and no error to raise. Whoever knows
  what is being scanned does the reporting -- LexIdentOrKeyword and LexString. }
procedure StrAppend(var s: str; c: char);

{ ------------------------------------------------------- the character sink }

{ Where the next character goes. A type name is written by one routine and
  wanted in two places: straight out, as part of a diagnostic, and *into a
  buffer*, as part of a runtime-error message the code generator has to store
  and emit as a string constant. One sink is what keeps a single WriteTypeName
  serving both -- and a second copy of it would be a copy free to drift, which
  is the mistake ADR-0024 was written to stop making. }
procedure Put(c: char);

{ A padded literal written straight to the IR file. PutLit goes through the Put
  sink, which may be aimed at the message buffer; an instruction never is. }
procedure PutIrLit(w: msgLit);

{ ------------------------------------------------------------- diagnostics }

{ Begin a diagnostic. Every one in this compiler starts here, which is what
  makes the format a single decision.

  Two formats, and the mode picks: inside a dump it is `line col error msg`,
  the shape the dumps have always had; outside one it is
  `file:line:col: error: msg`, which is what a person reads and what the
  tests/*.err goldens hold. Both go to `output` -- neither standard gives a
  program a second stream, and adding one would be a second invented extension
  for the sake of tidiness (ADR-0084 is the first and it earned its place). }

procedure ErrorAt(l, c: integer);

{ -------------------------------------------------------------- the pool -- }

{ Text is interned once and referred to by (at, len) afterwards. The token
  table would otherwise hold a 255-character buffer per token, which is a
  megabyte of frame for a file of any size. }
function PoolAdd(var s: str): integer;

procedure WritePool(at, len: integer);

{ True when a pooled spelling is the given word. The literal is padded because
  a value parameter of a packed array type must have the array's exact length
  (ADR-0012); the padding is stripped here rather than at the call. }
{ ...and the same against a *wider* literal. ISO/IEC 10206:1991 has required
  identifiers longer than the longest ISO 7185 word-symbol -- `seekupdate` is
  ten characters and `lastposition` twelve -- so kwLit cannot spell them. }
function PoolIsWide(at, len: integer; word: msgLit): boolean;

function PoolIs(at, len: integer; word: kwLit): boolean;

{ Whether a foreign name (ADR-0121) is one this compiler already emits for
  something of its own. LLVM's assembler refuses a second declaration of any
  global, however identical the two are -- so without this a program writing
  `external 'nnn'` is answered with an error about a file nobody wrote,
  for one of the two names below.

  Every name this compiler composes is caught by one of the tests below. A
  **dot** catches LLVM's intrinsics and every linkage name 6.13 needs --
  `p.<interface>.<constituent>`, `v.<...>`, `pas.input`, `frame.<module>` and
  `m.<module>.<std>.<part>` -- none of which is spellable without one. `pas_`
  catches the runtime. A letter and then digits catch the two counters, one
  for procedures and one for string constants. What is left is two bare names,
  and `tests/checks/foreign_reserved.py` is what keeps that a complete list: it
  reads the `declare` and `define` literals out of this file and fails if any
  of them names something this function would let through -- and fails the
  other way too, so a name that stops being emitted stops being reserved.

  It was five. `atan`, `atan2` and `hypot` were the only ones a Pascal
  programmer would plausibly reach for -- `arctan` compiles to the first, and
  `abs` and `arg` of a complex to the other two -- so they moved into the
  runtime as `pas_atan`, `pas_atan2` and `pas_hypot`, and a program can have
  the names. The two left cannot move: `main` is the entry point, and
  `_setjmp` has to be called in the frame `longjmp` returns to, so a wrapper
  would return before the jump. }
function ReservedForeignName(at, len: integer): boolean;

{ Two pooled spellings, compared. Every name in the compiler is a slice of the
  pool, so this is what "the same identifier" means from here on. }
function PoolSame(a1, l1, a2, l2: integer): boolean;

{ A character straight into the pool, for the two names Sema builds rather than
  reads: a function's result slot and a `with` binding. }
procedure PoolPut(c: char);

{ A padded literal interned into the pool, so a name the compiler knows about
  can be compared and printed like one it read from the source. }
procedure InternWord(w: kwLit; var at, len: integer);

{ ...and the same for a name longer than the longest ISO 7185 word-symbol.
  `bindingtype` is eleven characters, and kwLit holds nine. }
procedure InternWide(w: msgLit; var at, len: integer);

{ ...and in two pieces, for text longer than any literal type here holds. The
  three required real constants of 6.4.2.2 b) are the only users: the shortest
  decimal that round-trips to an IEEE-754 binary64 runs to twenty-two
  characters and msgLit holds sixteen. }
procedure InternWide2(a, b: msgLit; var at, len: integer);

{ The two names Sema builds rather than reads. A function's result slot is
  named after the function; a `with` binding is named after the frame slot it
  occupies, which is unique within the frame and needs no type name -- see the
  note beside Sema::checkWith. }
procedure InternResultName(nameAt, nameLen: integer; var at, len: integer);

{ ...and the slot 6.7.6.8's `binding` builds its result in, named the same way
  and for the same reason: it is a frame slot the program cannot name. }
procedure InternBindingName(slot: integer; var at, len: integer);

{ ...and the slot a call whose result lives in memory builds it in (6.7.2),
  named the same way and for the same reason. }
procedure InternCallResultName(slot: integer; var at, len: integer);

{ ...and the slot AP 6.8.9's try binds its operand in, which is a `with`
  binding in everything but the name it is given here -- and it is given its
  own so that a frame layout in --dump-sema says which construct claimed the
  slot. }
procedure InternTryName(slot: integer; var at, len: integer);

procedure InternWithName(slot: integer; var at, len: integer);

{ The name of the ordinal counter a `for v in s` walks its base type with. It
  is a frame variable so that it survives the iteration and so that a nested
  `for ... in` does not allocate one per iteration of the loop around it; the
  program cannot name it, and the `$` is what keeps it out of reach of a source
  identifier. }
{ The name of the hidden frame variable a type-definition's bounds descriptor
  lives in (ADR-0127). Named rather than anonymous for the same reason `for$`
  and `with$` are: the Sema dump prints a frame's variables and a nameless one
  would be indistinguishable from the next. Nothing looks it up -- `$` is not
  an identifier character, so no program can write the name. }
procedure InternBoundsName(slot: integer; var at, len: integer);

procedure InternForName(slot: integer; var at, len: integer);

{ ==========================================================================
  The type representation, and the two routines that spell a type.

  Sema decides what a type *is* and the code generator decides what it costs;
  both of them read it, and both of them write it into text a person sees --
  Sema into a diagnostic, CodeGen into the trap message a generated program
  carries. So the arena, the predicates over it and WriteTypeName are ApTypes'
  and not Sema's, and there is one of each rather than two that could drift
  (ADR-0233).
  ========================================================================== }

{ ------------------------------------------------------------ the type arena }
function NewType(k: typeKind): typePtr;

{ The type a subrange is a subrange of; every other type is its own base.
  Assignment compatibility, arithmetic and the machine representation are all
  decided on the base, which is what makes `1..9` an integer that happens to be
  checked (ISO 7185 6.4.2.4). }
function Base(t: typePtr): typePtr;

{ These ask what a value *is*, so they look through a subrange to its host:
  `1..9` is an integer that happens to be range-checked, and every rule about
  integers applies to it unchanged.

  Note the local in each: ISO 7185 6.5.1 makes a variable-access the only thing
  a selector may follow, so Base(t)^.kind -- which the C++ writes directly --
  is not a thing this language can say. }
function IsInteger(t: typePtr): boolean;

function IsReal(t: typePtr): boolean;

{ ADR-0128. Asked on the type itself and never through Base(), for the reason
  IsReal is: an int64 is not an ordinal, so it is never the host of a subrange
  and there is nothing for Base() to look through. }
function IsInt64(t: typePtr): boolean;

function IsComplex(t: typePtr): boolean;

{ A type produced from the required schema `string` (6.4.3.3.3), or the
  canonical-string-type that `+` yields. }
function IsVarString(t: typePtr): boolean;

{ AP 6.4.15's text-type. Asked of the kind and never through Base(): a text is
  not a string and the whole point is that it does not answer for one. }
function IsText(t: typePtr): boolean;

{ "Is this value a length and that many bytes?" -- a question about
  *representation*, which a text and a variable-string answer alike, and which
  is why AP 6.4.15 needed no new frame slot, no new copy and no new parameter
  form (ADR-0189).

  It is deliberately not the same question as IsVarString, and every use of one
  where the other was meant is a defect. IsVarString asks whether the *rules*
  of 6.4.3.3.3 apply -- indexing, substrings, `length` in characters,
  assignment from a char -- and none of those is a text's. ADR-0181 had to
  split `IsOwned` from `IsAffine` for exactly this reason after the two had
  been one name; this one starts split. }
function IsStringRep(t: typePtr): boolean;

{ ADR-0123. Asked on the type itself and never through Base(): an optional is
  not its T and the whole point is that it does not answer for one. }
function IsOptional(t: typePtr): boolean;

{ AP 6.4.13 (ADR-0176). A fallible-type *is* a record -- everything that asks
  "is this a record?" must go on answering yes, which is what makes the copy,
  the layout and ADR-0118's trap free -- so this asks the flag rather than the
  kind. It is what the two assignment rules and the tag refusal key on. }
function IsFallible(t: typePtr): boolean;

{ AP 6.4.12.2's position, asked of an assignment's *target* rather than of its
  value. A handle variable is one, and since AP 6.4.13.5 (ADR-0256) so is a
  fallible variable whose value side is a handle: `res := ExtFopen(...)` is
  6.4.13.3's shorthand for `res.val := ExtFopen(...)`, and the permission has
  to be granted before the value is checked while the rewrite happens after --
  so the question is asked of what the target *is* and not of what the
  statement will become. }
function IsHandleBirth(t: typePtr): boolean;

{ ADR-0125's slice. Like tyProc, this is the type of a formal parameter and of
  nothing else -- so most of the compiler meets one only through the parameter
  paths, and everything that asks "is this a value?" is right to answer no. }
function IsSlice(t: typePtr): boolean;

{ The type a slice-designator has. A fresh one each time, because two slices
  are compatible when their *component* types are the same type and never
  because they are the same object -- there being nothing to name-equate,
  ADR-0017's rule being about types a program can write and this being a type
  no program can. }
function SliceOf(comp: typePtr): typePtr;

function IsNumeric(t: typePtr): boolean;

{ Everything the arithmetic operators accept (6.8.3.2, table 3). Kept apart
  from IsNumeric because the *ordering* operators take a numeric type and
  refuse a complex one -- 6.8.3.5 admits only = and <> there, there being no
  order on the complex numbers. }
function IsArith(t: typePtr): boolean;

function IsBoolean(t: typePtr): boolean;

function IsChar(t: typePtr): boolean;

function IsEnum(t: typePtr): boolean;

function IsArray(t: typePtr): boolean;

function IsRecord(t: typePtr): boolean;

function IsPointer(t: typePtr): boolean;

function IsFile(t: typePtr): boolean;

{ AP 6.4.12's handle-type (ADR-0174). Asked on its own where the handle's
  two permissions are decided -- the assignment from an external call and the
  comparison with nil -- and through IsOwned everywhere a file's refusals
  apply, which is the rest. }
function IsHandle(t: typePtr): boolean;

{ AP 6.4.16 (ADR-0268): a channel-type, which **is** a handle-type -- one whose
  closer is the runtime's and whose `elem` is what it carries. A kind of its
  own was considered and refused: everything a channel needs from the language
  is what a handle already has -- no copy, released when the variable dies,
  `release` before that, and lending to a routine without giving it away -- so
  a second kind would be a parallel mechanism where a field does. `elem` is nil
  for every other handle, which is what makes the question answerable. }
function IsChannel(t: typePtr): boolean;

{ A file or a handle: the two owned things whose *value* lives in memory and
  therefore travels by address. IsMemory is what asks this, and it is why the
  owned pointer of AP 6.4.14 is not in it -- that one is affine like these two
  and its value is still one word, so it goes on being loaded and stored the
  way every other pointer is. Ask IsAffine for the ownership and IsOwned for
  the representation; the two questions were one until ADR-0181. }
function IsOwned(t: typePtr): boolean;

{ AP 6.4.14's owned-pointer-type (ADR-0181): `owned ^T`, which identifies a
  variable created by `new` and released when the pointer's own variable dies. }
function IsOwnedPointer(t: typePtr): boolean;

{ Affine: no copy, and released when the variable holding it dies -- the whole
  of ADR-0151's *lifetime* half, which since ADR-0181 has three members rather
  than two. ContainsFile is the walk over this, and the walk's name stays
  because 6.4.6 a)'s condition is the file's and the other two were fitted to
  it. }
function IsAffine(t: typePtr): boolean;

{ `text` as against `file of char`: see typeRec.isText. }
function IsTextFile(t: typePtr): boolean;

{ `nil`, which is a value of every pointer type and of no other. }
function IsNil(t: typePtr): boolean;

function IsSet(t: typePtr): boolean;

{ The type of a procedural or functional parameter (ISO 7185 6.6.3.1). }
function IsProcType(t: typePtr): boolean;

{ `[]`, which belongs to every set type -- the set-valued counterpart of nil,
  and elem-less for the same reason: it has no base type of its own. }
function IsEmptySet(t: typePtr): boolean;

{ Arrays and records live in memory and are copied wholesale. A file is *not*
  structured: it also lives in memory, but it may never be copied, so grouping
  it here would grant it exactly the operations it must not have. }
{ A set is not structured either, and for the opposite reason to a file: it
  *is* a value. Every set is one 256-bit integer, so it is assigned, compared
  and passed exactly as an integer is (ADR-0028). }
function IsRestricted(t: typePtr): boolean;

{ 6.4.2.5: "The underlying-type of a type that is not restricted shall be the
  type." Written so a caller need not ask which it has. }
function Underlying(t: typePtr): typePtr;

{ 6.4.2.5 associates a restricted-type's states one-to-one with the underlying
  type's, so *how a value travels* is the underlying type's question -- a
  restricted record is copied and passed by address exactly as the record is.
  These two are the only predicates that see through, and that is what confines
  the feature: everything else answers false and refuses the operation where it
  stood. }
function IsStructured(t: typePtr): boolean;

function IsMemory(t: typePtr): boolean;

{ ISO/IEC 10206:1991 6.4.1: a type is protectable unless it is a file or a
  pointer, or is structured and holds one. The standard's own NOTE gives both
  reasons: nearly every operation on a file modifies it, and a pointer *value*
  can be copied out and disposed of -- so protecting the variable would protect
  nothing. Only 6.7.3.1 asks this today. }
function Protectable(t: typePtr): boolean;

function IsOrdinal(t: typePtr): boolean;

{ A `packed array [1..n] of char` -- the type ISO 7185 6.4.3.2 gives a string
  literal, and the only structured type with its own operators.

  6.4.3.2 designates a string-type by four properties at once: "Any type
  designated packed and denoted by an array-type having as its index-type a
  denotation of a subrange-type specifying a smallest value of 1 and a largest
  value of greater than 1, and having as its component-type a denotation of
  the char-type, shall be designated a string-type." ISO/IEC 10206:1991
  6.4.3.3.2 says the same of its fixed-string-type with one clause dropped --
  the first bound must be nonvarying, contain no discriminant-identifier and
  denote 1, and *nothing* is required of the largest value. This language
  takes 6.4.3.3.2's reading, so `packed array [1..1] of char` is a
  fixed-string-type; ISO 7185's extra clause was the whole of what `--std`
  decided about a string-type, and ADR-0232 removed it.

  Two of these are easy to get wrong. IsChar is not what the component asks:
  it sees through a subrange to its host, and `packed array [1..4] of 'A'..'Z'`
  denotes no char-type at all. And the smallest *value* is not the smallest
  ordinal -- ord(blue) is 1 for an index-type of `blue..green`, so the
  index-type has to be an integer one before its lower bound means anything. }
function IsCharArray(t: typePtr): boolean;

{ 6.4.3.3.1: "A string-type shall be a fixed-string-type or a
  variable-string-type or the required type designated canonical-string-type."
  A fixed-string-type is 6.4.3.3.2's `packed array [1..n] of char`, which
  ISO 7185 already had and already gave the relational operators. }
function IsStringType(t: typePtr): boolean;

{ 6.4.3.3.1 gives the char-type "length 1 and capacity 1", so it stands
  wherever a string does -- in a comparison, a concatenation, an assignment --
  without being one. }
function IsStringOrChar(t: typePtr): boolean;

{ ISO/IEC 10206:1991 6.7.3.2's rule for the required schema `string` as a
  **value** parameter, which is a rule of its own and not the schematic-formal
  rule one construct along:

    "If the parameter-form of the value-parameter-specification contains a
     schema-name that denotes the schema denoted by the required
     schema-identifier string, then each corresponding actual-parameter
     contained by the activation-point of an activation shall possess a type
     having an underlying-type that is a string-type or the char-type ...
     Within the activation, each corresponding formal-parameter shall possess
     the type produced from the schema string with the tuple having that
     length as its component."

  So the actual is an *expression* of any string-or-char type -- not a variable
  produced from the schema, which is what every other schema-name asks for --
  and the formal's capacity is the **length of the value**, not the capacity of
  whatever variable it came out of. Both halves were wrong here: 6.11.6's own
  Example 10 writes `record event('event-module initialization')` and this
  compiler answered "needs a variable produced from schema 'string'".

  Only a value parameter. 6.7.3.3's variable-parameter clause has no such
  paragraph -- a var parameter binds to storage, so there is no value to take a
  length from -- and it goes on asking for a variable of the schema's type. }
function StringValueFormal(f: symPtr): boolean;

{ ADR-0122: the one shape a string is allowed to have in an `external`
  heading -- a schematic formal, so the size is the actual's and the formal
  states none. What crosses is a `const char *`, whose length is the NUL, so a
  capacity here would be a promise nothing on the other side keeps and a fixed
  size would be one nothing states. One spelling and no second rule, which is
  ADR-0121 decision 2 applied a second time. }
function ForeignStringFormal(f: symPtr): boolean;

function EnumCount(t: typePtr): integer;

{ The first and last values of an ordinal type -- what succ and pred run out
  at, and what a subrange assignment is checked against. }
function OrdinalLo(t: typePtr): integer;

function OrdinalHi(t: typePtr): integer;

function TypeLength(t: typePtr): integer;

{ 6.7.3.2: "If the parameter-form of the value-parameter-specification
  contains a type-name or a type-inquiry ... [the value] shall be
  assignment-compatible with the type possessed by the formal-parameters."
  6.4.6 f) then makes a string value assignment-compatible with a string-type
  of at least its length, and 6.4.6's last paragraph says what it means: "the
  canonical-string-type value shall be treated as a value of the
  fixed-string-type whose components ... followed by zero or more spaces." So
  a shorter actual is *padded*, exactly as `f := s` already pads -- and 6.8's
  primary rule, "any primary whose type is a string-type shall be treated as
  if it were of the canonical-string-type", is what makes the actual a
  canonical value however it was spelled.

  What made this a refusal rather than a lowering is that a structured value
  parameter travels as an address (ADR-0017) and an actual of a different
  length has none of the formal's shape. This answers the one question both
  ends have to agree on: does this pair need the padded temporary built at the
  call site? An actual that is already a char array of the formal's own length
  is the ordinary copy and answers false, so nothing that compiled before is
  lowered differently. }
function PadsToFixedString(formal, actual: typePtr): boolean;

{ ISO 7185 6.4.3.3 requires every field name in a record to be distinct,
  variants included, so one flat search over all of them is unambiguous. }
{ The k-th arm of one variant part. }
function ArmAtIn(v: variantPtr; k: integer): variantPtr;

function FindField(t: typePtr; at, len: integer): fieldPtr;

{ The arms of the variant part at `path`, the fields of the field-list there,
  and that variant part's selector. An empty path is the record itself; an
  arm's field-list is a field-list like any other (ISO 7185 6.4.3.3), which is
  what makes one set of functions serve both. CodeGen had the first two; Sema
  wants the same answers to decide whether a 6.8.7 record-value is complete,
  which is why they live here with the other type queries. }
function ArmsAt(rec: typePtr; path: numPtr): variantPtr;

function FieldsAt(rec: typePtr; path: numPtr): fieldPtr;

{ The index into FieldsAt(path) of the selector's own field, or -1 for a
  tagless variant part and for a discriminant-selected one (6.4.3.4) -- neither
  has a field anywhere. }
function TagFieldAt(rec: typePtr; path: numPtr): integer;

function TagTypeAt(rec: typePtr; path: numPtr): typePtr;

{ How a value of an ordinal type is written in source: 7, 'a', true, or an
  enumeration constant's own name. }
procedure WriteOrdinalName(t: typePtr; value_: integer);

{ Which of the sources this translation has read is named by `n`: 0 for the
  one on the command line, otherwise its --import index. It answers 0 for a
  name it does not recognise, which is the safe direction -- a use attributed
  to the document being edited is checked against that document's own text by
  the caller, and one attributed to a file that was never opened is not.

  It is a scan and not a stored index, and that is the point. `curFile` is
  already maintained across a module's check and put back afterwards, so
  asking it beats keeping a second variable that says the same thing and can
  stop agreeing with it. It is asked once per defining-point and only when
  --dump-uses is set, which is a few thousand short comparisons at most. }
function FileIndexOf(n: nameStr): integer;

{ ------------------------------------------------------------- type names }
procedure WriteTypeName(t: typePtr);

{ The missing half of a message that names two types. 6.4.1 of both standards
  makes each occurrence of a new-type denote a type distinct from every other,
  so two type-denoters written alike denote two types -- and WriteTypeName then
  prints one spelling twice while the message says nothing a reader can act on.
  "cannot assign array [1..3] of integer to a variable of type array [1..3] of
  integer" is accurate and useless, which is the same fault the file case beside
  the assignment check was given a message of its own for.

  Nothing is written when the spellings differ, so no message grows where it was
  already saying something and no caller needs a condition of its own. The
  question is "do these two print alike", so it is asked by rendering both
  through the msgBuf sink -- and a spelling that fills the buffer cannot be
  compared, so neither compiler says anything about one. The C++ carries the
  same limit under the name kTypeNameCompareLimit. That compiler and the
  harness that compared the two are both gone (ADR-0232); the limit stays
  because a spelling longer than the buffer cannot be compared, which is a fact
  about msgBuf and not about a second implementation. }
procedure WriteDistinctTypeNote(a, b: typePtr);

end;

var
  { Handed out by NewType, one per type object and never reused, so that
    AP 6.4.7's type-valued discriminant has an integer to put in a tuple
    (ADR-0209). Starts at zero, which is therefore no type's -- a tuple
    component of zero would be a defect rather than a type nobody named. }
  nextTypeId: integer;
{ ------------------------------------------------------------------ strings }

procedure StrClear;
begin
  s.len := 0
end;

{ Drops what will not fit, in silence, and that is deliberate (ADR-0110): this
  is the generic append and builds diagnostic messages as well as tokens, where
  there is no source position to attribute and no error to raise. Whoever knows
  what is being scanned does the reporting -- LexIdentOrKeyword and LexString. }
procedure StrAppend;
begin
  if s.len < strMax then begin
    s.len := s.len + 1;
    s.ch[s.len] := c
  end
end;

{ ------------------------------------------------------- the character sink }

{ Where the next character goes. A type name is written by one routine and
  wanted in two places: straight out, as part of a diagnostic, and *into a
  buffer*, as part of a runtime-error message the code generator has to store
  and emit as a string constant. One sink is what keeps a single WriteTypeName
  serving both -- and a second copy of it would be a copy free to drift, which
  is the mistake ADR-0024 was written to stop making. }
procedure Put;
begin
  if msgOut then StrAppend(msgBuf, c) else write(c)
end;

{ A padded literal, with the padding stripped -- the same convention kwLit and
  wordLit already use, and for the same reason (ADR-0012). }
procedure PutLit(w: msgLit);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    Put(w[k])
end;

{ A padded literal written straight to the IR file. PutLit goes through the Put
  sink, which may be aimed at the message buffer; an instruction never is. }
procedure PutIrLit;
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    write(ircode, w[k])
end;

{ An integer, written the way `v:1` writes it. Spelled out rather than left to
  `write` because the digits may have to land in the buffer instead. }
procedure PutInt(v: integer);
var digits: array [1..12] of char; n, k: integer; negative: boolean;
begin
  negative := v < 0;
  n := 0;
  { -maxint..maxint is symmetric, so negating first cannot overflow. }
  if negative then v := -v;
  if v = 0 then begin
    n := 1;
    digits[1] := '0'
  end;
  while v > 0 do begin
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  end;
  if negative then Put('-');
  for k := n downto 1 do
    Put(digits[k])
end;

{ ------------------------------------------------------------- diagnostics }

{ Begin a diagnostic. Every one in this compiler starts here, which is what
  makes the format a single decision.

  Two formats, and the mode picks: inside a dump it is `line col error msg`,
  the shape the dumps have always had; outside one it is
  `file:line:col: error: msg`, which is what a person reads and what the
  tests/*.err goldens hold. Both go to `output` -- neither standard gives a
  program a second stream, and adding one would be a second invented extension
  for the sake of tidiness (ADR-0084 is the first and it earned its place). }

procedure ErrorAt;
begin
  errorSeen := true;
  { Counted as well as flagged: producing a type from a schema needs to know
    whether *its* resolution reported anything, so that the tuple that chose
    it can be named too (6.4.7's domain). }
  errorCount := errorCount + 1;
  if dumping then write(l:1, ' ', c:1, ' error ')
  else write(curFile, ':', l:1, ':', c:1, ': error: ')
end;

{ -------------------------------------------------------------- the pool -- }

{ Text is interned once and referred to by (at, len) afterwards. The token
  table would otherwise hold a 255-character buffer per token, which is a
  megabyte of frame for a file of any size. }
function PoolAdd;
var k: integer;
begin
  if poolLen + s.len > poolMax then begin
    ErrorAt(line, col);
    writeln('out of string space: this compiler keeps ', poolMax:1,
            ' characters of text');
    PoolAdd := 1
  end
  else begin
    PoolAdd := poolLen + 1;
    for k := 1 to s.len do
      pool[poolLen + k] := s.ch[k];
    poolLen := poolLen + s.len
  end
end;

procedure WritePool;
var k: integer;
begin
  for k := at to at + len - 1 do
    Put(pool[k])
end;

{ True when a pooled spelling is the given word. The literal is padded because
  a value parameter of a packed array type must have the array's exact length
  (ADR-0012); the padding is stripped here rather than at the call. }
{ ...and the same against a *wider* literal. ISO/IEC 10206:1991 has required
  identifiers longer than the longest ISO 7185 word-symbol -- `seekupdate` is
  ten characters and `lastposition` twelve -- so kwLit cannot spell them. }
function PoolIsWide;
var n, k: integer; same: boolean;
begin
  n := msgWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  if n <> len then
    PoolIsWide := false
  else begin
    same := true;
    for k := 1 to n do
      if pool[at + k - 1] <> word[k] then same := false;
    PoolIsWide := same
  end
end;

function PoolIs;
var n, k: integer; same: boolean;
begin
  n := kwWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  if n <> len then
    PoolIs := false
  else begin
    same := true;
    k := 1;
    while same and (k <= n) do begin
      same := word[k] = pool[at + k - 1];
      k := k + 1
    end;
    PoolIs := same
  end
end;

{ As PoolIs, but of a prefix: the pooled text need only begin with the word. }
function PoolStarts(at, len: integer; word: kwLit): boolean;
var n, k: integer; same: boolean;
begin
  n := kwWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  if len < n then
    PoolStarts := false
  else begin
    same := true;
    k := 1;
    while same and (k <= n) do begin
      same := word[k] = pool[at + k - 1];
      k := k + 1
    end;
    PoolStarts := same
  end
end;

{ Whether a foreign name (ADR-0121) is one this compiler already emits for
  something of its own. LLVM's assembler refuses a second declaration of any
  global, however identical the two are -- so without this a program writing
  `external 'nnn'` is answered with an error about a file nobody wrote,
  for one of the two names below.

  Every name this compiler composes is caught by one of the tests below. A
  **dot** catches LLVM's intrinsics and every linkage name 6.13 needs --
  `p.<interface>.<constituent>`, `v.<...>`, `pas.input`, `frame.<module>` and
  `m.<module>.<std>.<part>` -- none of which is spellable without one. `pas_`
  catches the runtime. A letter and then digits catch the two counters, one
  for procedures and one for string constants. What is left is two bare names,
  and `tests/checks/foreign_reserved.py` is what keeps that a complete list: it
  reads the `declare` and `define` literals out of this file and fails if any
  of them names something this function would let through -- and fails the
  other way too, so a name that stops being emitted stops being reserved.

  It was five. `atan`, `atan2` and `hypot` were the only ones a Pascal
  programmer would plausibly reach for -- `arctan` compiles to the first, and
  `abs` and `arg` of a complex to the other two -- so they moved into the
  runtime as `pas_atan`, `pas_atan2` and `pas_hypot`, and a program can have
  the names. The two left cannot move: `main` is the entry point, and
  `_setjmp` has to be called in the frame `longjmp` returns to, so a wrapper
  would return before the jump. }
function ReservedForeignName;
var k: integer; counter, dotted, frames, rels: boolean;
begin
  dotted := false;
  for k := at to at + len - 1 do
    if pool[k] = '.' then dotted := true;

  counter := (len >= 2) and ((pool[at] = 'p') or (pool[at] = 's'));
  if counter then
    for k := at + 1 to at + len - 1 do
      if (pool[k] < '0') or (pool[k] > '9') then counter := false;

  { ADR-0144: `frame` and digits. An activation record gets a name apiece and
    a level-0 one is a *global* -- `@frame1` is the program's, emitted as an
    `internal global` before the first function that indexes it. A module's is
    `@frame.<name>` and is caught by `dotted`; the program's is not, and
    `function frame1(x: integer): integer; external 'frame1'` was refused with
    `redefinition of function '@frame1'`, an error naming a file nobody wrote,
    which is the exact failure this predicate exists to prevent.

    Not seen by tests/checks/foreign_reserved.py either, and for a reason
    worth writing down: that gate harvests the `declare` and `define` literals
    the emitter writes, so a global emitted as neither was outside what it
    could compare. It reads `internal global` now as well. }
  frames := (len >= 6) and PoolStarts(at, len, 'frame    ');
  if frames then
    for k := at + 5 to at + len - 1 do
      if (pool[k] < '0') or (pool[k] > '9') then frames := false;

  { AP 6.4.14 (ADR-0181): `ownrel` and digits, a release routine per owned
    pointer's domain. `frame`'s case, and found the same way -- by
    tests/checks/foreign_reserved.py refusing to pass, which is what that gate
    asking the *compiler* rather than its own copy of this list is for.

    The bare spelling is reserved as well, where `frame` is not, and the
    difference is in how the two names are built: `@frame1` is AppendLit and a
    counter, so no literal in this file holds `@frame`, while the call to a
    release routine is written as the literal `@ownrel` followed by the
    number. That literal is what the gate harvests, so `ownrel` is a name it
    offers -- and reserving one more spelling is the cheaper of the two ways
    to answer it. }
  rels := (len >= 6) and PoolStarts(at, len, 'ownrel   ');
  if rels then
    for k := at + 6 to at + len - 1 do
      if (pool[k] < '0') or (pool[k] > '9') then rels := false;

  ReservedForeignName := dotted or counter or frames or rels or
    PoolStarts(at, len, 'pas_     ') or
    PoolIs(at, len, 'main     ') or PoolIs(at, len, '_setjmp  ')
end;

{ Two pooled spellings, compared. Every name in the compiler is a slice of the
  pool, so this is what "the same identifier" means from here on. }
function PoolSame;
var k: integer; same: boolean;
begin
  if l1 <> l2 then
    PoolSame := false
  else begin
    same := true;
    k := 0;
    while same and (k < l1) do begin
      same := pool[a1 + k] = pool[a2 + k];
      k := k + 1
    end;
    PoolSame := same
  end
end;

{ A character straight into the pool, for the two names Sema builds rather than
  reads: a function's result slot and a `with` binding. }
procedure PoolPut;
begin
  if poolLen < poolMax then begin
    poolLen := poolLen + 1;
    pool[poolLen] := c
  end
end;

{ A padded literal interned into the pool, so a name the compiler knows about
  can be compared and printed like one it read from the source. }
procedure InternWord;
var n, k: integer;
begin
  n := kwWidth;
  while (n > 0) and (w[n] = ' ') do n := n - 1;
  at := poolLen + 1;
  len := n;
  for k := 1 to n do PoolPut(w[k])
end;

{ ...and the same for a name longer than the longest ISO 7185 word-symbol.
  `bindingtype` is eleven characters, and kwLit holds nine. }
procedure InternWide;
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do n := n - 1;
  at := poolLen + 1;
  len := n;
  for k := 1 to n do PoolPut(w[k])
end;

{ ...and in two pieces, for text longer than any literal type here holds. The
  three required real constants of 6.4.2.2 b) are the only users: the shortest
  decimal that round-trips to an IEEE-754 binary64 runs to twenty-two
  characters and msgLit holds sixteen. }
procedure InternWide2;
var n, k: integer;
begin
  at := poolLen + 1;
  len := 0;
  n := msgWidth;
  while (n > 0) and (a[n] = ' ') do n := n - 1;
  for k := 1 to n do PoolPut(a[k]);
  len := len + n;
  n := msgWidth;
  while (n > 0) and (b[n] = ' ') do n := n - 1;
  for k := 1 to n do PoolPut(b[k]);
  len := len + n
end;

{ The two names Sema builds rather than reads. A function's result slot is
  named after the function; a `with` binding is named after the frame slot it
  occupies, which is unique within the frame and needs no type name -- see the
  note beside Sema::checkWith. }
procedure InternResultName;
var k: integer;
begin
  at := poolLen + 1;
  for k := 0 to nameLen - 1 do PoolPut(pool[nameAt + k]);
  PoolPut('$');
  PoolPut('r'); PoolPut('e'); PoolPut('s'); PoolPut('u');
  PoolPut('l'); PoolPut('t');
  len := nameLen + 7
end;

{ ...and the slot 6.7.6.8's `binding` builds its result in, named the same way
  and for the same reason: it is a frame slot the program cannot name. }
procedure InternBindingName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('b'); PoolPut('i'); PoolPut('n'); PoolPut('d'); PoolPut('i');
  PoolPut('n'); PoolPut('g'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := poolLen + 1 - at
end;

{ ...and the slot a call whose result lives in memory builds it in (6.7.2),
  named the same way and for the same reason. }
procedure InternCallResultName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('r'); PoolPut('e'); PoolPut('s'); PoolPut('u');
  PoolPut('l'); PoolPut('t'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := poolLen + 1 - at
end;

{ ...and the slot AP 6.8.9's try binds its operand in, which is a `with`
  binding in everything but the name it is given here -- and it is given its
  own so that a frame layout in --dump-sema says which construct claimed the
  slot. }
procedure InternTryName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('t'); PoolPut('r'); PoolPut('y'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := 4 + n
end;

procedure InternWithName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('w'); PoolPut('i'); PoolPut('t'); PoolPut('h'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := 5 + n
end;

{ The name of the ordinal counter a `for v in s` walks its base type with. It
  is a frame variable so that it survives the iteration and so that a nested
  `for ... in` does not allocate one per iteration of the loop around it; the
  program cannot name it, and the `$` is what keeps it out of reach of a source
  identifier. }
{ The name of the hidden frame variable a type-definition's bounds descriptor
  lives in (ADR-0127). Named rather than anonymous for the same reason `for$`
  and `with$` are: the Sema dump prints a frame's variables and a nameless one
  would be indistinguishable from the next. Nothing looks it up -- `$` is not
  an identifier character, so no program can write the name. }
procedure InternBoundsName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('b'); PoolPut('n'); PoolPut('d'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := 4 + n
end;

procedure InternForName;
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('f'); PoolPut('o'); PoolPut('r'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := 4 + n
end;

{ ==========================================================================
  The type representation, and the two routines that spell a type.

  Sema decides what a type *is* and the code generator decides what it costs;
  both of them read it, and both of them write it into text a person sees --
  Sema into a diagnostic, CodeGen into the trap message a generated program
  carries. So the arena, the predicates over it and WriteTypeName are ApTypes'
  and not Sema's, and there is one of each rather than two that could drift
  (ADR-0233).
  ========================================================================== }

{ ------------------------------------------------------------ the type arena }

function NewType;
var t: typePtr;
begin
  new(t);
  t^.kind := k;
  t^.elem := nil;
  t^.elemBindable := false;
  t^.indexType := nil;
  t^.host := nil;
  t^.tagType := nil;
  t^.isPacked := false;
  t^.setCanonical := false;
  t^.isText := false;
  t^.lo := 0;
  t^.hi := -1;
  t^.enumNames := nil;
  t^.enumTail := nil;
  t^.fields := nil;
  t^.fieldTail := nil;
  t^.variants := nil;
  t^.variantTail := nil;
  t^.discSelector := false;
  t^.isFallible := false;
  t^.armsApart := false;
  t^.falVal := nil;
  t^.falCause := nil;
  t^.tagField := -1;
  t^.aliasAt := 0;
  t^.aliasLen := 0;
  t^.handleAt := 0;
  t^.handleLen := 0;
  t^.owns := false;
  t^.schema := nil;
  t^.tuple := nil;
  t^.tupleTail := nil;
  t^.loDisc := nil;
  t^.isConfSchema := false;
  t^.hiDisc := nil;
  t^.heapTuple := false;
  t^.descOwner := nil;
  nextTypeId := nextTypeId + 1;
  t^.typeId := nextTypeId;
  t^.boundsVar := nil;
  NewType := t
end;

{ The type a subrange is a subrange of; every other type is its own base.
  Assignment compatibility, arithmetic and the machine representation are all
  decided on the base, which is what makes `1..9` an integer that happens to be
  checked (ISO 7185 6.4.2.4). }
function Base;
begin
  if (t <> nil) and (t^.kind = tySubrange) and (t^.host <> nil) then
    Base := t^.host
  else
    Base := t
end;

{ These ask what a value *is*, so they look through a subrange to its host:
  `1..9` is an integer that happens to be range-checked, and every rule about
  integers applies to it unchanged.

  Note the local in each: ISO 7185 6.5.1 makes a variable-access the only thing
  a selector may follow, so Base(t)^.kind -- which the C++ writes directly --
  is not a thing this language can say. }
function IsInteger;
var b: typePtr;
begin
  b := Base(t);
  IsInteger := (b <> nil) and (b^.kind = tyInteger)
end;

function IsReal;
begin IsReal := (t <> nil) and (t^.kind = tyReal) end;

{ ADR-0128. Asked on the type itself and never through Base(), for the reason
  IsReal is: an int64 is not an ordinal, so it is never the host of a subrange
  and there is nothing for Base() to look through. }
function IsInt64;
begin IsInt64 := (t <> nil) and (t^.kind = tyInt64) end;

function IsComplex;
begin IsComplex := (t <> nil) and (t^.kind = tyComplex) end;

{ A type produced from the required schema `string` (6.4.3.3.3), or the
  canonical-string-type that `+` yields. }
function IsVarString;
begin IsVarString := (t <> nil) and (t^.kind = tyString) end;

{ AP 6.4.15's text-type. Asked of the kind and never through Base(): a text is
  not a string and the whole point is that it does not answer for one. }
function IsText;
begin IsText := (t <> nil) and (t^.kind = tyText) end;

{ "Is this value a length and that many bytes?" -- a question about
  *representation*, which a text and a variable-string answer alike, and which
  is why AP 6.4.15 needed no new frame slot, no new copy and no new parameter
  form (ADR-0189).

  It is deliberately not the same question as IsVarString, and every use of one
  where the other was meant is a defect. IsVarString asks whether the *rules*
  of 6.4.3.3.3 apply -- indexing, substrings, `length` in characters,
  assignment from a char -- and none of those is a text's. ADR-0181 had to
  split `IsOwned` from `IsAffine` for exactly this reason after the two had
  been one name; this one starts split. }
function IsStringRep;
begin IsStringRep := (t <> nil) and ((t^.kind = tyString) or (t^.kind = tyText))
end;

{ ADR-0123. Asked on the type itself and never through Base(): an optional is
  not its T and the whole point is that it does not answer for one. }
function IsOptional;
begin IsOptional := (t <> nil) and (t^.kind = tyOptional) end;

{ AP 6.4.13 (ADR-0176). A fallible-type *is* a record -- everything that asks
  "is this a record?" must go on answering yes, which is what makes the copy,
  the layout and ADR-0118's trap free -- so this asks the flag rather than the
  kind. It is what the two assignment rules and the tag refusal key on. }
function IsFallible;
begin IsFallible := (t <> nil) and (t^.kind = tyRecord) and t^.isFallible end;

function IsHandleBirth;
begin
  IsHandleBirth := IsHandle(t) or
                         (IsFallible(t) and IsHandle(t^.falVal))
end;

{ ADR-0125's slice. Like tyProc, this is the type of a formal parameter and of
  nothing else -- so most of the compiler meets one only through the parameter
  paths, and everything that asks "is this a value?" is right to answer no. }
function IsSlice;
begin IsSlice := (t <> nil) and (t^.kind = tySlice) end;

{ The type a slice-designator has. A fresh one each time, because two slices
  are compatible when their *component* types are the same type and never
  because they are the same object -- there being nothing to name-equate,
  ADR-0017's rule being about types a program can write and this being a type
  no program can. }
function SliceOf;
var t: typePtr;
begin
  t := NewType(tySlice);
  t^.elem := comp;
  t^.lo := 1;
  SliceOf := t
end;

function IsNumeric;
begin IsNumeric := IsInteger(t) or IsInt64(t) or IsReal(t) end;

{ Everything the arithmetic operators accept (6.8.3.2, table 3). Kept apart
  from IsNumeric because the *ordering* operators take a numeric type and
  refuse a complex one -- 6.8.3.5 admits only = and <> there, there being no
  order on the complex numbers. }
function IsArith;
begin IsArith := IsNumeric(t) or IsComplex(t) end;

function IsBoolean;
var b: typePtr;
begin
  b := Base(t);
  IsBoolean := (b <> nil) and (b^.kind = tyBoolean)
end;

function IsChar;
var b: typePtr;
begin
  b := Base(t);
  IsChar := (b <> nil) and (b^.kind = tyChar)
end;

function IsEnum;
var b: typePtr;
begin
  b := Base(t);
  IsEnum := (b <> nil) and (b^.kind = tyEnum)
end;

function IsArray;
begin IsArray := (t <> nil) and (t^.kind = tyArray) end;

function IsRecord;
begin IsRecord := (t <> nil) and (t^.kind = tyRecord) end;

function IsPointer;
begin IsPointer := (t <> nil) and (t^.kind = tyPointer) end;

function IsFile;
begin IsFile := (t <> nil) and (t^.kind = tyFile) end;

{ AP 6.4.12's handle-type (ADR-0174). Asked on its own where the handle's
  two permissions are decided -- the assignment from an external call and the
  comparison with nil -- and through IsOwned everywhere a file's refusals
  apply, which is the rest. }
function IsHandle;
begin IsHandle := (t <> nil) and (t^.kind = tyHandle) end;

function IsChannel;
begin IsChannel := IsHandle(t) and (t^.elem <> nil) end;

{ A file or a handle: the two owned things whose *value* lives in memory and
  therefore travels by address. IsMemory is what asks this, and it is why the
  owned pointer of AP 6.4.14 is not in it -- that one is affine like these two
  and its value is still one word, so it goes on being loaded and stored the
  way every other pointer is. Ask IsAffine for the ownership and IsOwned for
  the representation; the two questions were one until ADR-0181. }
function IsOwned;
begin IsOwned := IsFile(t) or IsHandle(t) end;

{ AP 6.4.14's owned-pointer-type (ADR-0181): `owned ^T`, which identifies a
  variable created by `new` and released when the pointer's own variable dies. }
function IsOwnedPointer;
begin IsOwnedPointer := IsPointer(t) and t^.owns end;

{ Affine: no copy, and released when the variable holding it dies -- the whole
  of ADR-0151's *lifetime* half, which since ADR-0181 has three members rather
  than two. ContainsFile is the walk over this, and the walk's name stays
  because 6.4.6 a)'s condition is the file's and the other two were fitted to
  it. }
function IsAffine;
begin IsAffine := IsOwned(t) or IsOwnedPointer(t) end;

{ `text` as against `file of char`: see typeRec.isText. }
function IsTextFile;
begin IsTextFile := IsFile(t) and t^.isText end;

{ `nil`, which is a value of every pointer type and of no other. }
function IsNil;
begin IsNil := IsPointer(t) and (t^.elem = nil) end;

function IsSet;
begin IsSet := (t <> nil) and (t^.kind = tySet) end;

{ The type of a procedural or functional parameter (ISO 7185 6.6.3.1). }
function IsProcType;
begin IsProcType := (t <> nil) and (t^.kind = tyProc) end;

{ `[]`, which belongs to every set type -- the set-valued counterpart of nil,
  and elem-less for the same reason: it has no base type of its own. }
function IsEmptySet;
begin IsEmptySet := IsSet(t) and (t^.elem = nil) end;

{ Arrays and records live in memory and are copied wholesale. A file is *not*
  structured: it also lives in memory, but it may never be copied, so grouping
  it here would grant it exactly the operations it must not have. }
{ A set is not structured either, and for the opposite reason to a file: it
  *is* a value. Every set is one 256-bit integer, so it is assigned, compared
  and passed exactly as an integer is (ADR-0028). }
function IsRestricted;
begin IsRestricted := (t <> nil) and (t^.kind = tyRestricted) end;

{ 6.4.2.5: "The underlying-type of a type that is not restricted shall be the
  type." Written so a caller need not ask which it has. }
function Underlying;
begin
  if IsRestricted(t) then Underlying := t^.elem else Underlying := t
end;

{ 6.4.2.5 associates a restricted-type's states one-to-one with the underlying
  type's, so *how a value travels* is the underlying type's question -- a
  restricted record is copied and passed by address exactly as the record is.
  These two are the only predicates that see through, and that is what confines
  the feature: everything else answers false and refuses the operation where it
  stood. }
function IsStructured;
begin
  if IsRestricted(t) then
    IsStructured := IsArray(t^.elem) or IsRecord(t^.elem) or
                    IsOptional(t^.elem)
  else IsStructured := IsArray(t) or IsRecord(t) or IsOptional(t)
end;

function IsMemory;
begin
  if IsRestricted(t) then
    IsMemory := IsStructured(t) or IsOwned(t^.elem) or IsStringRep(t^.elem)
  else IsMemory := IsStructured(t) or IsOwned(t) or IsStringRep(t)
end;

{ ISO/IEC 10206:1991 6.4.1: a type is protectable unless it is a file or a
  pointer, or is structured and holds one. The standard's own NOTE gives both
  reasons: nearly every operation on a file modifies it, and a pointer *value*
  can be copied out and disposed of -- so protecting the variable would protect
  nothing. Only 6.7.3.1 asks this today. }
function Protectable;
var f: fieldPtr; ok: boolean;
begin
  if t = nil then
    Protectable := true
  else if IsFile(t) or IsPointer(t) then
    Protectable := false
  else if IsArray(t) then
    Protectable := Protectable(t^.elem)
  else if IsRecord(t) then begin
    ok := true;
    f := t^.fields;
    while (f <> nil) and ok do begin
      if not Protectable(f^.ftype) then ok := false;
      f := f^.next
    end;
    Protectable := ok
  end
  else
    Protectable := true
end;

function IsOrdinal;
var k: typeKind; b: typePtr;
begin
  if t = nil then
    IsOrdinal := false
  else begin
    b := Base(t);
    k := b^.kind;
    IsOrdinal := (k = tyInteger) or (k = tyBoolean) or (k = tyChar) or
                 (k = tyEnum)
  end
end;

{ A `packed array [1..n] of char` -- the type ISO 7185 6.4.3.2 gives a string
  literal, and the only structured type with its own operators.

  6.4.3.2 designates a string-type by four properties at once: "Any type
  designated packed and denoted by an array-type having as its index-type a
  denotation of a subrange-type specifying a smallest value of 1 and a largest
  value of greater than 1, and having as its component-type a denotation of
  the char-type, shall be designated a string-type." ISO/IEC 10206:1991
  6.4.3.3.2 says the same of its fixed-string-type with one clause dropped --
  the first bound must be nonvarying, contain no discriminant-identifier and
  denote 1, and *nothing* is required of the largest value. This language
  takes 6.4.3.3.2's reading, so `packed array [1..1] of char` is a
  fixed-string-type; ISO 7185's extra clause was the whole of what `--std`
  decided about a string-type, and ADR-0232 removed it.

  Two of these are easy to get wrong. IsChar is not what the component asks:
  it sees through a subrange to its host, and `packed array [1..4] of 'A'..'Z'`
  denotes no char-type at all. And the smallest *value* is not the smallest
  ordinal -- ord(blue) is 1 for an index-type of `blue..green`, so the
  index-type has to be an integer one before its lower bound means anything. }
function IsCharArray;
var ok: boolean;
begin
  ok := IsArray(t) and t^.isPacked;
  if ok then ok := (t^.elem <> nil) and (t^.elem^.kind = tyChar);
  if ok then
    ok := IsInteger(t^.indexType) and (t^.loDisc = nil) and (t^.lo = 1);
  IsCharArray := ok
end;

{ 6.4.3.3.1: "A string-type shall be a fixed-string-type or a
  variable-string-type or the required type designated canonical-string-type."
  A fixed-string-type is 6.4.3.3.2's `packed array [1..n] of char`, which
  ISO 7185 already had and already gave the relational operators. }
function IsStringType;
begin IsStringType := IsVarString(t) or IsCharArray(t) end;

{ 6.4.3.3.1 gives the char-type "length 1 and capacity 1", so it stands
  wherever a string does -- in a comparison, a concatenation, an assignment --
  without being one. }
function IsStringOrChar;
begin IsStringOrChar := IsStringType(t) or IsChar(t) end;

{ ISO/IEC 10206:1991 6.7.3.2's rule for the required schema `string` as a
  **value** parameter, which is a rule of its own and not the schematic-formal
  rule one construct along:

    "If the parameter-form of the value-parameter-specification contains a
     schema-name that denotes the schema denoted by the required
     schema-identifier string, then each corresponding actual-parameter
     contained by the activation-point of an activation shall possess a type
     having an underlying-type that is a string-type or the char-type ...
     Within the activation, each corresponding formal-parameter shall possess
     the type produced from the schema string with the tuple having that
     length as its component."

  So the actual is an *expression* of any string-or-char type -- not a variable
  produced from the schema, which is what every other schema-name asks for --
  and the formal's capacity is the **length of the value**, not the capacity of
  whatever variable it came out of. Both halves were wrong here: 6.11.6's own
  Example 10 writes `record event('event-module initialization')` and this
  compiler answered "needs a variable produced from schema 'string'".

  Only a value parameter. 6.7.3.3's variable-parameter clause has no such
  paragraph -- a var parameter binds to storage, so there is no value to take a
  length from -- and it goes on asking for a variable of the schema's type. }
function StringValueFormal;
begin
  StringValueFormal := (f^.kind = skParam) and (f^.descSchema <> nil) and
                       (f^.descSchema = stringSchema)
end;

{ ADR-0122: the one shape a string is allowed to have in an `external`
  heading -- a schematic formal, so the size is the actual's and the formal
  states none. What crosses is a `const char *`, whose length is the NUL, so a
  capacity here would be a promise nothing on the other side keeps and a fixed
  size would be one nothing states. One spelling and no second rule, which is
  ADR-0121 decision 2 applied a second time. }
function ForeignStringFormal;
begin
  ForeignStringFormal := (f^.kind = skParam) and (f^.descSchema <> nil) and
                         IsVarString(f^.stype)
end;

function EnumCount;
var p: namePtr; n: integer;
begin
  n := 0;
  p := t^.enumNames;
  while p <> nil do begin
    n := n + 1;
    p := p^.next
  end;
  EnumCount := n
end;

{ The first and last values of an ordinal type -- what succ and pred run out
  at, and what a subrange assignment is checked against. }
function OrdinalLo;
begin
  if t^.kind = tySubrange then OrdinalLo := t^.lo
  else if t^.kind = tyInteger then OrdinalLo := -maxint
  else OrdinalLo := 0
end;

function OrdinalHi;
begin
  if t^.kind = tySubrange then OrdinalHi := t^.hi
  else if t^.kind = tyInteger then OrdinalHi := maxint
  else if t^.kind = tyChar then OrdinalHi := 255
  else if t^.kind = tyBoolean then OrdinalHi := 1
  else if t^.kind = tyEnum then OrdinalHi := EnumCount(t) - 1
  else OrdinalHi := 0
end;

function TypeLength;
begin TypeLength := t^.hi - t^.lo + 1 end;

{ 6.7.3.2: "If the parameter-form of the value-parameter-specification
  contains a type-name or a type-inquiry ... [the value] shall be
  assignment-compatible with the type possessed by the formal-parameters."
  6.4.6 f) then makes a string value assignment-compatible with a string-type
  of at least its length, and 6.4.6's last paragraph says what it means: "the
  canonical-string-type value shall be treated as a value of the
  fixed-string-type whose components ... followed by zero or more spaces." So
  a shorter actual is *padded*, exactly as `f := s` already pads -- and 6.8's
  primary rule, "any primary whose type is a string-type shall be treated as
  if it were of the canonical-string-type", is what makes the actual a
  canonical value however it was spelled.

  What made this a refusal rather than a lowering is that a structured value
  parameter travels as an address (ADR-0017) and an actual of a different
  length has none of the formal's shape. This answers the one question both
  ends have to agree on: does this pair need the padded temporary built at the
  call site? An actual that is already a char array of the formal's own length
  is the ordinary copy and answers false, so nothing that compiled before is
  lowered differently. }
function PadsToFixedString;
begin
  PadsToFixedString :=
    (formal <> nil) and (actual <> nil) and
    IsCharArray(formal) and (formal^.loDisc = nil) and
    (formal^.hiDisc = nil) and IsStringOrChar(actual) and
    (not IsCharArray(actual) or (actual^.loDisc <> nil) or
     (actual^.hiDisc <> nil) or (TypeLength(actual) <> TypeLength(formal)))
end;

{ ISO 7185 6.4.3.3 requires every field name in a record to be distinct,
  variants included, so one flat search over all of them is unambiguous. }
{ The k-th arm of one variant part. }
function ArmAtIn;
begin
  while k > 0 do begin
    v := v^.next;
    k := k - 1
  end;
  ArmAtIn := v
end;

function FindFieldIn(v: variantPtr; at, len: integer): fieldPtr;
var f, found: fieldPtr;
begin
  found := nil;
  while (v <> nil) and (found = nil) do begin
    f := v^.fields;
    while (f <> nil) and (found = nil) do begin
      if PoolSame(f^.at, f^.len, at, len) then found := f;
      f := f^.next
    end;
    if found = nil then found := FindFieldIn(v^.variants, at, len);
    v := v^.next
  end;
  FindFieldIn := found
end;

function FindField;
var f, found: fieldPtr;
begin
  found := nil;
  f := t^.fields;
  while (f <> nil) and (found = nil) do begin
    if PoolSame(f^.at, f^.len, at, len) then found := f;
    f := f^.next
  end;
  if found = nil then found := FindFieldIn(t^.variants, at, len);
  FindField := found
end;

{ The arm a path names. Each step selects an arm of the variant part it is in;
  a further step goes into the variant part nested inside that arm. }
function ArmAt(rec: typePtr; path: numPtr): variantPtr;
var v: variantPtr; k: integer;
begin
  v := rec^.variants;
  while path <> nil do begin
    k := 0;
    while k < path^.value_ do begin
      v := v^.next;
      k := k + 1
    end;
    if path^.next <> nil then v := v^.variants;
    path := path^.next
  end;
  ArmAt := v
end;

{ The arms of the variant part at `path`, the fields of the field-list there,
  and that variant part's selector. An empty path is the record itself; an
  arm's field-list is a field-list like any other (ISO 7185 6.4.3.3), which is
  what makes one set of functions serve both. CodeGen had the first two; Sema
  wants the same answers to decide whether a 6.8.7 record-value is complete,
  which is why they live here with the other type queries. }
function ArmsAt;
var a: variantPtr;
begin
  if path = nil then
    ArmsAt := rec^.variants
  else begin
    a := ArmAt(rec, path);
    ArmsAt := a^.variants
  end
end;

function FieldsAt;
var a: variantPtr;
begin
  if path = nil then
    FieldsAt := rec^.fields
  else begin
    a := ArmAt(rec, path);
    FieldsAt := a^.fields
  end
end;

{ The index into FieldsAt(path) of the selector's own field, or -1 for a
  tagless variant part and for a discriminant-selected one (6.4.3.4) -- neither
  has a field anywhere. }
function TagFieldAt;
var a: variantPtr;
begin
  if path = nil then
    TagFieldAt := rec^.tagField
  else begin
    a := ArmAt(rec, path);
    TagFieldAt := a^.tagField
  end
end;

function TagTypeAt;
var a: variantPtr;
begin
  if path = nil then
    TagTypeAt := rec^.tagType
  else begin
    a := ArmAt(rec, path);
    TagTypeAt := a^.tagType
  end
end;

function FileIndexOf;
var i: integer;
begin
  FileIndexOf := 0;
  { To maxImports and not to a count, because the count is the driver's and
    this component imports nothing (ADR-0233). An unused entry is the empty
    string and no file this compiler opened is named by one, so the two are
    distinguishable without one. }
  if n <> mainFile then
    for i := 1 to maxImports do
      if n = importName[i] then FileIndexOf := i
end;

{ ------------------------------------------------------------- type names }

{ How a value of an ordinal type is written in source: 7, 'a', true, or an
  enumeration constant's own name. }
procedure WriteOrdinalName;
var b: typePtr; p: namePtr; i: integer; done: boolean;
begin
  if t = nil then b := nil else b := Base(t);
  if b = nil then
    PutInt(value_)
  { A printable character is written as itself; anything else is written as
    chr(n). Not cosmetic: the C++ prints a diagnostic with %s, so a char of
    value 0 written literally would truncate the message at that point. }
  else if b^.kind = tyChar then
    if (value_ >= 32) and (value_ < 127) then begin
      Put('''');
      Put(chr(value_));
      Put('''')
    end
    else begin
      PutLit('chr(            ');
      PutInt(value_);
      Put(')')
    end
  else if b^.kind = tyBoolean then
    if value_ <> 0 then PutLit('true            ')
    else PutLit('false           ')
  else if (b^.kind = tyEnum) and (value_ >= 0) and (value_ < EnumCount(b)) then
  begin
    p := b^.enumNames;
    i := 0;
    done := false;
    while not done do
      if i = value_ then begin
        WritePool(p^.at, p^.len);
        done := true
      end
      else begin
        p := p^.next;
        i := i + 1
      end
  end
  else
    PutInt(value_)
end;

{ A description for diagnostics. A named type reports its name; an anonymous
  one is spelled out the way the source would have written it. }
{ How a bound is written when it may be dynamic: a constant as itself, and a
  discriminant as its own name. }
procedure WriteBoundName(t: typePtr; disc: symPtr; value_: integer);
begin
  if disc = nil then WriteOrdinalName(t, value_)
  else WritePool(disc^.at, disc^.len)
end;

procedure WriteTypeName;
var p: namePtr; f: fieldPtr; first: boolean;
begin
  if t = nil then
    Put('?')
  else if t^.aliasLen > 0 then
    WritePool(t^.aliasAt, t^.aliasLen)
  else
    case t^.kind of
      tyInteger: PutLit('integer         ');
      tyInt64:   PutLit('int64           ');
      tyReal:    PutLit('real            ');
      tyComplex: PutLit('complex         ');
      { 6.4.2.5's own spelling. A restricted-type is nearly always named -- the
        whole point of one is a type-name whose structure is hidden -- so this
        is reached mostly by the anonymous form in a diagnostic. }
      tyRestricted: begin
        PutLit('restricted      ');
        WriteTypeName(t^.elem)
      end;
      tyString:
        if t^.hi < 0 then PutLit('string          ')
        else begin
          PutLit('string(         ');
          PutInt(t^.hi);
          PutLit(')               ')
        end;
      { AP 6.4.15.1. A schematic formal has no capacity of its own -- the
        actual brings it -- so it prints bare, as a string does. }
      tyText:
        if t^.hi <= 0 then PutLit('utf8            ')
        else begin
          PutLit('utf8(           ');
          PutInt(t^.hi);
          PutLit(')               ')
        end;
      tyBoolean: PutLit('boolean         ');
      tyChar:    PutLit('char            ');
      tyVoid:    PutLit('void            ');
      tyEnum: begin
        Put('(');
        p := t^.enumNames;
        first := true;
        while p <> nil do begin
          if not first then begin PutLit(',               '); Put(' ') end;
          WritePool(p^.at, p^.len);
          first := false;
          p := p^.next
        end;
        Put(')')
      end;
      tySubrange: begin
        WriteBoundName(t^.host, t^.loDisc, t^.lo);
        PutLit('..              ');
        WriteBoundName(t^.host, t^.hiDisc, t^.hi)
      end;
      { ISO 7185 6.4.4 makes a pointer's domain a type *identifier*, so the
        recursion always stops at a name -- which is what lets a type point at
        itself without this looping forever. }
      tyPointer:
        if t^.elem <> nil then begin
          { AP 6.4.14: spelled the way the source spells it, and the word is
            not decoration -- two diagnostics about a parameter say "X, but
            the value is Y" and would otherwise print `^node` twice for two
            different types. }
          if t^.owns then begin
            PutLit('owned           ');
            Put(' ')            { PutLit trims its padding }
          end;
          Put('^');
          WriteTypeName(t^.elem)
        end
        else
          PutLit('nil             ');
      { ADR-0125. Printed the way it is written, and with no extent because
        it has none of its own -- the extent is the actual's. }
      tySlice: begin
        PutLit('array of        ');
        Put(' ');
        WriteTypeName(t^.elem)
      end;
      { ADR-0123. Printed the way it is written, `?` and then the type it
        may hold -- which recurses, but never forever: the denoter had to
        contain a T for the storage to have a size. }
      tyOptional: begin
        Put('?');
        WriteTypeName(t^.elem)
      end;
      { `text` names itself; every other file names its component, because a
        `file of char` is a different type from a text and a diagnostic that
        called them both "text" would be describing the wrong one. }
      { A direct-access file names its index type too (6.4.3.6): it is what
        makes the type direct-access, so a diagnostic that left it out would
        be describing a different type. }
      tyHandle: begin
        PutLit('handle external ');
        Put(' ');
        Put('''');
        WritePool(t^.handleAt, t^.handleLen);
        Put('''')
      end;
      tyFile:
        if t^.isText then PutLit('text            ')
        else if t^.indexType <> nil then begin
          PutLit('file [          ');
          WriteTypeName(t^.indexType);
          PutLit('] of            ');
          Put(' ');
          WriteTypeName(t^.elem)
        end
        else begin
          PutLit('file of         ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      { The type of `[]` names no base type because it has none; it is written
        the way the source writes it. }
      tySet:
        if t^.elem = nil then PutLit('[]              ')
        else begin
          { 6.4.5 c) makes packing part of a set-type's identity for
            compatibility, so a message leaving the word out would name two
            different types by one spelling -- and WriteDistinctTypeNote would
            then offer advice that cannot help (ADR-0074). }
          if t^.isPacked then PutLit('packed set of   ')
          else PutLit('set of          ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      { Two procedural parameters differ by their *parameter lists*, and ISO
        7185 6.6.3.6 compares those pairwise rather than as a whole; the
        congruity diagnostic names the parameter that failed, so spelling a
        signature out here would say less at more cost. }
      tyProc:
        if t^.elem = nil then PutLit('procedure       ')
        else begin
          PutLit('function        ');
          Put(' ');
          PutLit('returning       ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      tyRecord: if t^.isFallible then begin
        { AP 6.4.13: spelled the way the source wrote it. Naming its three
          fields instead would be accurate and would tell a reader nothing
          about which type this is. }
        WriteTypeName(t^.falVal);
        PutLit(' !              ');
        Put(' ');
        WriteTypeName(t^.falCause)
      end
      else begin
        { An anonymous record is named by its fields, which is the only thing
          that distinguishes it from any other anonymous record. }
        PutLit('record          ');
        Put(' ');
        f := t^.fields;
        first := true;
        while f <> nil do begin
          if not first then begin PutLit(',               '); Put(' ') end;
          WritePool(f^.at, f^.len);
          first := false;
          f := f^.next
        end;
        PutLit(' end            ')
      end;
      tyArray: begin
        if t^.isPacked then PutLit('packed array [  ')
        else PutLit('array [         ');
        WriteBoundName(t^.indexType, t^.loDisc, t^.lo);
        PutLit('..              ');
        WriteBoundName(t^.indexType, t^.hiDisc, t^.hi);
        PutLit('] of            ');
        Put(' ');
        if t^.elem <> nil then WriteTypeName(t^.elem) else Put('?')
      end
    end
end;

{ The missing half of a message that names two types. 6.4.1 of both standards
  makes each occurrence of a new-type denote a type distinct from every other,
  so two type-denoters written alike denote two types -- and WriteTypeName then
  prints one spelling twice while the message says nothing a reader can act on.
  "cannot assign array [1..3] of integer to a variable of type array [1..3] of
  integer" is accurate and useless, which is the same fault the file case beside
  the assignment check was given a message of its own for.

  Nothing is written when the spellings differ, so no message grows where it was
  already saying something and no caller needs a condition of its own. The
  question is "do these two print alike", so it is asked by rendering both
  through the msgBuf sink -- and a spelling that fills the buffer cannot be
  compared, so neither compiler says anything about one. The C++ carries the
  same limit under the name kTypeNameCompareLimit. That compiler and the
  harness that compared the two are both gone (ADR-0232); the limit stays
  because a spelling longer than the buffer cannot be compared, which is a fact
  about msgBuf and not about a second implementation. }
procedure WriteDistinctTypeNote;
var saved: str; i: integer; same: boolean;
begin
  if (a <> nil) and (b <> nil) and (a <> b) then begin
    msgOut := true;
    StrClear(msgBuf);
    WriteTypeName(a);
    saved := msgBuf;
    StrClear(msgBuf);
    WriteTypeName(b);
    msgOut := false;
    same := (saved.len < strMax) and (saved.len = msgBuf.len);
    if same then
      for i := 1 to saved.len do
        if saved.ch[i] <> msgBuf.ch[i] then same := false;
    if same then begin
      write('; the two are written alike, but ');
      { Two anonymous denoters are the shape a reader can act on: the fix is
        one named type used twice. Two type-names that print alike are distinct
        for the very same reason -- each type-definition contains its own
        new-type -- but naming them again is no advice, so that half is left
        off. }
      if (a^.aliasLen = 0) and (b^.aliasLen = 0) then
        write('6.4.1 makes each type-denoter that is not a type name denote ',
              'a type of its own, so declare one named type and give it to ',
              'both')
      else
        write('each was defined separately and 6.4.1 makes the definitions ',
              'distinct types')
    end
  end
end;

{ 6.2.3.6: this module's own state, cleared before the program-block it
  supplies is activated. It was the program's own first statements while
  there was one component (ADR-0233). }
to begin do
  begin
    { Before the first NewType, which is InstallRequired's (ADR-0209). }
    nextTypeId := 0;
    poolLen := 0;
    tokCount := 0;
    pos := 1;
    mainTokBase := 1;
    depth := 0;
    aborted := false;
    errorSeen := false;
    errorCount := 0;
    annotate := false;
    msgOut := false;
    StrClear(msgBuf);
    readingImports := false;
    curFile := '';
    curImportIdx := 0;
    notingUses := false;
    notingStmts := false;
    mainFile := '';
    instDeclHead := nil;
    stringSchema := nil;
    layoutHead := nil
  end;

end.
