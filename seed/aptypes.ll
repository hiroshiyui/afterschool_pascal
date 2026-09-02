target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%frame1 = type { ptr, i1, i32, i32, [1000000 x i8], i32, i32, i32, i32, i1, i1, i32, ptr, ptr, ptr, i32, ptr, i1, { i32, [255 x i8] }, i1, ptr, ptr, [15 x i64], [15 x i64], [32 x { i32, [4096 x i8] }], i1, i1, i1, i32, i1, i1, i1, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, { i32, [4096 x i8] }, i32, i1, i1, { i32, [4096 x i8] }, i32, ptr, ptr, ptr, ptr, ptr, ptr, i32 }
%frame2 = type { ptr, ptr }
%frame3 = type { ptr, ptr, i8 }
%frame4 = type { ptr, i8 }
%frame5 = type { ptr, [16 x i8], i32, i32 }
%frame6 = type { ptr, i32, i32 }
%frame7 = type { ptr, i32, i32 }
%frame8 = type { ptr, ptr, i32, i32 }
%frame9 = type { ptr, i32, i32, i32 }
%frame10 = type { ptr, i32, i32, [16 x i8], i1, i32, i32, i1 }
%frame11 = type { ptr, i32, i32, [9 x i8], i1, i32, i32, i1 }
%frame12 = type { ptr, i32, i32, i1, i32, i1, i1, i1, i1 }
%frame13 = type { ptr, i32, i32, i32, i32, i1, i32, i1 }
%frame14 = type { ptr, i8 }
%frame15 = type { ptr, [9 x i8], ptr, ptr, i32, i32 }
%frame16 = type { ptr, [16 x i8], ptr, ptr, i32, i32 }
%frame17 = type { ptr, [16 x i8], [16 x i8], ptr, ptr, i32, i32 }
%frame18 = type { ptr, i32, i32, ptr, ptr, i32 }
%frame19 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame20 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame21 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame22 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame23 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame24 = type { ptr, i32, ptr, ptr, [12 x i8], i32, i32, i32 }
%frame25 = type { ptr, i32, ptr, ptr }
%frame26 = type { ptr, ptr, ptr }
%frame27 = type { ptr, ptr, i1, ptr }
%frame28 = type { ptr, ptr, i1 }
%frame29 = type { ptr, ptr, i1 }
%frame30 = type { ptr, ptr, i1 }
%frame31 = type { ptr, ptr, i1 }
%frame32 = type { ptr, ptr, i1 }
%frame33 = type { ptr, ptr, i1 }
%frame34 = type { ptr, ptr, i1 }
%frame35 = type { ptr, ptr, i1 }
%frame36 = type { ptr, ptr, i1 }
%frame37 = type { ptr, ptr, i1 }
%frame38 = type { ptr, ptr, ptr, ptr }
%frame39 = type { ptr, ptr, i1 }
%frame40 = type { ptr, ptr, i1 }
%frame41 = type { ptr, ptr, i1, ptr }
%frame42 = type { ptr, ptr, i1, ptr }
%frame43 = type { ptr, ptr, i1, ptr }
%frame44 = type { ptr, ptr, i1 }
%frame45 = type { ptr, ptr, i1 }
%frame46 = type { ptr, ptr, i1 }
%frame47 = type { ptr, ptr, i1 }
%frame48 = type { ptr, ptr, i1 }
%frame49 = type { ptr, ptr, i1 }
%frame50 = type { ptr, ptr, i1 }
%frame51 = type { ptr, ptr, i1 }
%frame52 = type { ptr, ptr, i1 }
%frame53 = type { ptr, ptr, i1 }
%frame54 = type { ptr, ptr, i1 }
%frame55 = type { ptr, ptr, i1 }
%frame56 = type { ptr, ptr, i1 }
%frame57 = type { ptr, ptr, i1 }
%frame58 = type { ptr, ptr, i1 }
%frame59 = type { ptr, ptr, ptr }
%frame60 = type { ptr, ptr, i1 }
%frame61 = type { ptr, ptr, i1 }
%frame62 = type { ptr, ptr, i1, ptr, i1 }
%frame63 = type { ptr, ptr, i1, i32, ptr }
%frame64 = type { ptr, ptr, i1, i1 }
%frame65 = type { ptr, ptr, i1 }
%frame66 = type { ptr, ptr, i1 }
%frame67 = type { ptr, ptr, i1 }
%frame68 = type { ptr, ptr, i1 }
%frame69 = type { ptr, ptr, i32, i1 }
%frame70 = type { ptr, i32 }
%frame71 = type { ptr, i32 }
%frame72 = type { ptr, ptr, i1 }
%frame73 = type { ptr, ptr, i1 }
%frame74 = type { ptr, ptr, i32, ptr, i32 }
%frame75 = type { ptr, ptr, i32 }
%frame76 = type { ptr, ptr, i32 }
%frame77 = type { ptr, ptr, i64, i64 }
%frame78 = type { ptr, ptr, ptr, i1 }
%frame79 = type { ptr, ptr, i32, ptr }
%frame80 = type { ptr, ptr, i32, i32, ptr, ptr, ptr }
%frame81 = type { ptr, ptr, ptr, ptr, ptr }
%frame82 = type { ptr, ptr, ptr, ptr, ptr }
%frame83 = type { ptr, ptr, ptr, i32, ptr }
%frame84 = type { ptr, ptr, ptr, ptr, ptr }
%frame85 = type { ptr, ptr, i32, ptr, ptr, i32, i1 }
%frame86 = type { ptr, { i32, [4096 x i8] }, i32, i32 }
%frame87 = type { ptr, ptr, ptr, ptr, i1 }
%frame88 = type { ptr, ptr, ptr, { i32, [255 x i8] }, i32, i1 }
%frame89 = type { ptr, [16 x i8], i32, i32 }
%frame90 = type { ptr, i32, [12 x i8], i32, i32, i1 }
%frame91 = type { ptr, i32, i32, [9 x i8], i1, i32, i32, i1 }
%frame92 = type { ptr, ptr, i32, i32, ptr, ptr, ptr }
%frame93 = type { ptr, ptr, ptr, ptr, ptr, i32 }
%frame94 = type { ptr, ptr, ptr, i32 }

@frame.aptypes = global %frame1 zeroinitializer
@v.aptypes.readingimports = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 1)
@v.aptypes.line = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 2)
@v.aptypes.col = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 3)
@v.aptypes.pool = alias [1000000 x i8], ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 4)
@v.aptypes.poollen = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 5)
@v.aptypes.tokcount = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 6)
@v.aptypes.pos = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 7)
@v.aptypes.depth = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 8)
@v.aptypes.aborted = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 9)
@v.aptypes.errorseen = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 10)
@v.aptypes.errorcount = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 11)
@v.aptypes.progblock = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 12)
@v.aptypes.progmodules = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 13)
@v.aptypes.progmoduletail = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 14)
@v.aptypes.progmainindex = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 15)
@v.aptypes.activemodules = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 16)
@v.aptypes.msgout = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 17)
@v.aptypes.msgbuf = alias { i32, [255 x i8] }, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 18)
@v.aptypes.annotate = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 19)
@v.aptypes.layouthead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 20)
@v.aptypes.programsym = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 21)
@v.aptypes.ircode = alias [15 x i64], ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 22)
@v.aptypes.imports = alias [15 x i64], ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 23)
@v.aptypes.importname = alias [32 x { i32, [4096 x i8] }], ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 24)
@v.aptypes.dumping = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 25)
@v.aptypes.warnon = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 26)
@v.aptypes.keeptrivia = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 27)
@v.aptypes.triviacount = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 28)
@v.aptypes.triviafull = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 29)
@v.aptypes.dumplayoutopt = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 30)
@v.aptypes.dumpdispatchopt = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 31)
@v.aptypes.dispatchhead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 32)
@v.aptypes.dispatchtail = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 33)
@v.aptypes.enumhead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 34)
@v.aptypes.enumtail = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 35)
@v.aptypes.chainhead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 36)
@v.aptypes.chaintail = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 37)
@v.aptypes.taghead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 38)
@v.aptypes.tagtail = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 39)
@v.aptypes.curfile = alias { i32, [4096 x i8] }, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 40)
@v.aptypes.curimportidx = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 41)
@v.aptypes.notinguses = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 42)
@v.aptypes.notingstmts = alias i1, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 43)
@v.aptypes.mainfile = alias { i32, [4096 x i8] }, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 44)
@v.aptypes.maintokbase = alias i32, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 45)
@v.aptypes.instdeclhead = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 46)
@v.aptypes.inttype = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 47)
@v.aptypes.int64type = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 48)
@v.aptypes.canontexttype = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 49)
@v.aptypes.stringschema = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 50)
@v.aptypes.handleclosers = alias ptr, ptr getelementptr inbounds (%frame1, ptr @frame.aptypes, i32 0, i32 51)

define void @m.aptypes.afterschool.2ed694c516ee18bd.init() {
L1:
  %v1 = load i32, ptr @pas_str_at
  %v2 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  %v3 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 22
  call void @pas_file_init(ptr %v3, i32 0, i32 0, ptr @s1, i32 1, i32 1, i32 0, i32 0)
  %v4 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 23
  call void @pas_file_init(ptr %v4, i32 0, i32 0, ptr @s2, i32 1, i32 1, i32 0, i32 0)
  %v5 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 52
  store i32 0, ptr %v5
  %v6 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  store i32 0, ptr %v6
  %v7 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 6
  store i32 0, ptr %v7
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 7
  store i32 1, ptr %v8
  %v9 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 45
  store i32 1, ptr %v9
  %v10 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 8
  store i32 0, ptr %v10
  %v11 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 9
  store i1 false, ptr %v11
  %v12 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 10
  store i1 false, ptr %v12
  %v13 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 11
  store i32 0, ptr %v13
  %v14 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 19
  store i1 false, ptr %v14
  %v15 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 17
  store i1 false, ptr %v15
  %v16 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  call void @p.aptypes.strclear(ptr @frame.aptypes, ptr %v16)
  %v17 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 1
  store i1 false, ptr %v17
  %v18 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 27
  store i1 false, ptr %v18
  %v19 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 28
  store i32 0, ptr %v19
  %v20 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 29
  store i1 false, ptr %v20
  %v21 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 40
  call void @pas_str_store_var(ptr %v21, i32 4096, ptr @s3, i32 0)
  %v22 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 41
  store i32 0, ptr %v22
  %v23 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 42
  store i1 false, ptr %v23
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 43
  store i1 false, ptr %v24
  %v25 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 44
  call void @pas_str_store_var(ptr %v25, i32 4096, ptr @s4, i32 0)
  %v26 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 46
  store ptr null, ptr %v26
  %v27 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 50
  store ptr null, ptr %v27
  %v28 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 20
  store ptr null, ptr %v28
  ret void
}

define void @m.aptypes.afterschool.2ed694c516ee18bd.fini() {
L1:
  %v1 = load i32, ptr @pas_str_at
  %v2 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 22
  call void @pas_file_done(ptr %v2)
  %v3 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 23
  call void @pas_file_done(ptr %v3)
  ret void
}

; strclear 2973
define void @p.aptypes.strclear(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame2
  %v2 = getelementptr inbounds %frame2, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame2, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame2, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = getelementptr inbounds { i32, [255 x i8] }, ptr %v5, i32 0, i32 0
  %v7 = icmp slt i32 0, 0
  %v8 = icmp sgt i32 0, 255
  %v9 = or i1 %v7, %v8
  br i1 %v9, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s5)
  unreachable
L3:
  store i32 0, ptr %v6
  ret void
}

; strappend 2982
define void @p.aptypes.strappend(ptr %link, ptr %a0, i8 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame3
  %v2 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 2
  store i8 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = getelementptr inbounds { i32, [255 x i8] }, ptr %v6, i32 0, i32 0
  %v8 = load i32, ptr %v7
  %v9 = icmp slt i32 %v8, 255
  br i1 %v9, label %L2, label %L3
L2:
  %v10 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  %v11 = load ptr, ptr %v10
  %v12 = getelementptr inbounds { i32, [255 x i8] }, ptr %v11, i32 0, i32 0
  %v13 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  %v14 = load ptr, ptr %v13
  %v15 = getelementptr inbounds { i32, [255 x i8] }, ptr %v14, i32 0, i32 0
  %v16 = load i32, ptr %v15
  %v17 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v16, i32 1)
  %v18 = extractvalue { i32, i1 } %v17, 0
  %v19 = extractvalue { i32, i1 } %v17, 1
  %v20 = icmp eq i32 %v18, -2147483648
  %v21 = or i1 %v19, %v20
  br i1 %v21, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s6)
  unreachable
L5:
  %v22 = icmp slt i32 %v18, 0
  %v23 = icmp sgt i32 %v18, 255
  %v24 = or i1 %v22, %v23
  br i1 %v24, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s7)
  unreachable
L7:
  store i32 %v18, ptr %v12
  %v25 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  %v26 = load ptr, ptr %v25
  %v27 = getelementptr inbounds { i32, [255 x i8] }, ptr %v26, i32 0, i32 1
  %v28 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 1
  %v29 = load ptr, ptr %v28
  %v30 = getelementptr inbounds { i32, [255 x i8] }, ptr %v29, i32 0, i32 0
  %v31 = load i32, ptr %v30
  %v32 = icmp slt i32 %v31, 1
  %v33 = icmp sgt i32 %v31, 255
  %v34 = or i1 %v32, %v33
  br i1 %v34, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s8)
  unreachable
L9:
  %v35 = sub i32 %v31, 1
  %v36 = getelementptr inbounds [255 x i8], ptr %v27, i32 0, i32 %v35
  %v37 = getelementptr inbounds %frame3, ptr %frame, i32 0, i32 2
  %v38 = load i8, ptr %v37
  store i8 %v38, ptr %v36
  br label %L3
L3:
  ret void
}

; put 2998
define void @p.aptypes.put(ptr %link, i8 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame4
  %v2 = getelementptr inbounds %frame4, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame4, ptr %frame, i32 0, i32 1
  store i8 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 17
  %v5 = load i1, ptr %v4
  br i1 %v5, label %L2, label %L3
L2:
  %v6 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  %v7 = getelementptr inbounds %frame4, ptr %frame, i32 0, i32 1
  %v8 = load i8, ptr %v7
  call void @p.aptypes.strappend(ptr @frame.aptypes, ptr %v6, i8 %v8)
  br label %L4
L3:
  %v9 = getelementptr inbounds %frame4, ptr %frame, i32 0, i32 1
  %v10 = load i8, ptr %v9
  call void @pas_write_char(ptr @pas.output, i8 %v10, i32 -1)
  br label %L4
L4:
  ret void
}

; putlit 3005
define internal void @p89(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame89
  %v2 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v3, ptr align 1 %a0, i64 16, i1 false)
  %v4 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  store i32 16, ptr %v4
  br label %L2
L2:
  %v5 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  %v6 = load i32, ptr %v5
  %v7 = icmp sgt i32 %v6, 0
  br i1 %v7, label %L5, label %L6
L5:
  %v8 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 1
  %v9 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  %v10 = load i32, ptr %v9
  %v11 = icmp slt i32 %v10, 1
  %v12 = icmp sgt i32 %v10, 16
  %v13 = or i1 %v11, %v12
  br i1 %v13, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s9)
  unreachable
L8:
  %v14 = sub i32 %v10, 1
  %v15 = getelementptr inbounds [16 x i8], ptr %v8, i32 0, i32 %v14
  %v16 = load i8, ptr %v15
  %v17 = icmp eq i8 %v16, 32
  br label %L6
L6:
  %v18 = phi i1 [ false, %L2 ], [ %v17, %L8 ]
  br i1 %v18, label %L3, label %L4
L3:
  %v19 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  %v20 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s10)
  unreachable
L10:
  store i32 %v23, ptr %v19
  br label %L2
L4:
  %v27 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 3
  %v28 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 2
  %v29 = load i32, ptr %v28
  store i32 1, ptr %v27
  br label %L11
L11:
  %v30 = load i32, ptr %v27
  %v31 = icmp sle i32 %v30, %v29
  br i1 %v31, label %L12, label %L14
L12:
  %v32 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 1
  %v33 = getelementptr inbounds %frame89, ptr %frame, i32 0, i32 3
  %v34 = load i32, ptr %v33
  %v35 = icmp slt i32 %v34, 1
  %v36 = icmp sgt i32 %v34, 16
  %v37 = or i1 %v35, %v36
  br i1 %v37, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s11)
  unreachable
L17:
  %v38 = sub i32 %v34, 1
  %v39 = getelementptr inbounds [16 x i8], ptr %v32, i32 0, i32 %v38
  %v40 = load i8, ptr %v39
  call void @p.aptypes.put(ptr @frame.aptypes, i8 %v40)
  br label %L15
L15:
  %v41 = load i32, ptr %v27
  %v42 = icmp eq i32 %v41, %v29
  br i1 %v42, label %L14, label %L13
L13:
  %v43 = add i32 %v41, 1
  store i32 %v43, ptr %v27
  br label %L11
L14:
  ret void
}

; putirlit 3017
define void @p.aptypes.putirlit(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame5
  %v2 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v3, ptr align 1 %a0, i64 16, i1 false)
  %v4 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  store i32 16, ptr %v4
  br label %L2
L2:
  %v5 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  %v6 = load i32, ptr %v5
  %v7 = icmp sgt i32 %v6, 0
  br i1 %v7, label %L5, label %L6
L5:
  %v8 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 1
  %v9 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  %v10 = load i32, ptr %v9
  %v11 = icmp slt i32 %v10, 1
  %v12 = icmp sgt i32 %v10, 16
  %v13 = or i1 %v11, %v12
  br i1 %v13, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s12)
  unreachable
L8:
  %v14 = sub i32 %v10, 1
  %v15 = getelementptr inbounds [16 x i8], ptr %v8, i32 0, i32 %v14
  %v16 = load i8, ptr %v15
  %v17 = icmp eq i8 %v16, 32
  br label %L6
L6:
  %v18 = phi i1 [ false, %L2 ], [ %v17, %L8 ]
  br i1 %v18, label %L3, label %L4
L3:
  %v19 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  %v20 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s13)
  unreachable
L10:
  store i32 %v23, ptr %v19
  br label %L2
L4:
  %v27 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 3
  %v28 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 2
  %v29 = load i32, ptr %v28
  store i32 1, ptr %v27
  br label %L11
L11:
  %v30 = load i32, ptr %v27
  %v31 = icmp sle i32 %v30, %v29
  br i1 %v31, label %L12, label %L14
L12:
  %v32 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 22
  %v33 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 1
  %v34 = getelementptr inbounds %frame5, ptr %frame, i32 0, i32 3
  %v35 = load i32, ptr %v34
  %v36 = icmp slt i32 %v35, 1
  %v37 = icmp sgt i32 %v35, 16
  %v38 = or i1 %v36, %v37
  br i1 %v38, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s14)
  unreachable
L17:
  %v39 = sub i32 %v35, 1
  %v40 = getelementptr inbounds [16 x i8], ptr %v33, i32 0, i32 %v39
  %v41 = load i8, ptr %v40
  call void @pas_write_char(ptr %v32, i8 %v41, i32 -1)
  br label %L15
L15:
  %v42 = load i32, ptr %v27
  %v43 = icmp eq i32 %v42, %v29
  br i1 %v43, label %L14, label %L13
L13:
  %v44 = add i32 %v42, 1
  store i32 %v44, ptr %v27
  br label %L11
L14:
  ret void
}

; putint 3029
define internal void @p90(ptr %link, i32 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame90
  %v2 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 5
  %v5 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v6 = load i32, ptr %v5
  %v7 = icmp slt i32 %v6, 0
  store i1 %v7, ptr %v4
  %v8 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  store i32 0, ptr %v8
  %v9 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 5
  %v10 = load i1, ptr %v9
  br i1 %v10, label %L2, label %L3
L2:
  %v11 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v12 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v13 = load i32, ptr %v12
  %v14 = sub nsw i32 0, %v13
  store i32 %v14, ptr %v11
  br label %L3
L3:
  %v15 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v16 = load i32, ptr %v15
  %v17 = icmp eq i32 %v16, 0
  br i1 %v17, label %L4, label %L5
L4:
  %v18 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  store i32 1, ptr %v18
  %v19 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 2
  %v20 = icmp slt i32 1, 1
  %v21 = icmp sgt i32 1, 12
  %v22 = or i1 %v20, %v21
  br i1 %v22, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s15)
  unreachable
L7:
  %v23 = sub i32 1, 1
  %v24 = getelementptr inbounds [12 x i8], ptr %v19, i32 0, i32 %v23
  store i8 48, ptr %v24
  br label %L5
L5:
  br label %L8
L8:
  %v25 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v26 = load i32, ptr %v25
  %v27 = icmp sgt i32 %v26, 0
  br i1 %v27, label %L9, label %L10
L9:
  %v28 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  %v29 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  %v30 = load i32, ptr %v29
  %v31 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v30, i32 1)
  %v32 = extractvalue { i32, i1 } %v31, 0
  %v33 = extractvalue { i32, i1 } %v31, 1
  %v34 = icmp eq i32 %v32, -2147483648
  %v35 = or i1 %v33, %v34
  br i1 %v35, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s16)
  unreachable
L12:
  store i32 %v32, ptr %v28
  %v36 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 2
  %v37 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  %v38 = load i32, ptr %v37
  %v39 = icmp slt i32 %v38, 1
  %v40 = icmp sgt i32 %v38, 12
  %v41 = or i1 %v39, %v40
  br i1 %v41, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s17)
  unreachable
L14:
  %v42 = sub i32 %v38, 1
  %v43 = getelementptr inbounds [12 x i8], ptr %v36, i32 0, i32 %v42
  %v44 = zext i8 48 to i32
  %v45 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v46 = load i32, ptr %v45
  %v47 = icmp sle i32 10, 0
  br i1 %v47, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s18)
  unreachable
L16:
  %v48 = srem i32 %v46, 10
  %v49 = icmp slt i32 %v48, 0
  %v50 = add i32 %v48, 10
  %v51 = select i1 %v49, i32 %v50, i32 %v48
  %v52 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v44, i32 %v51)
  %v53 = extractvalue { i32, i1 } %v52, 0
  %v54 = extractvalue { i32, i1 } %v52, 1
  %v55 = icmp eq i32 %v53, -2147483648
  %v56 = or i1 %v54, %v55
  br i1 %v56, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s19)
  unreachable
L18:
  %v57 = icmp slt i32 %v53, 0
  %v58 = icmp sgt i32 %v53, 255
  %v59 = or i1 %v57, %v58
  br i1 %v59, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s20)
  unreachable
L20:
  %v60 = trunc i32 %v53 to i8
  store i8 %v60, ptr %v43
  %v61 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v62 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 1
  %v63 = load i32, ptr %v62
  %v64 = icmp eq i32 10, 0
  br i1 %v64, label %L21, label %L22
L21:
  call void @pas_runtime_error(ptr @s21)
  unreachable
L22:
  %v65 = icmp eq i32 %v63, -2147483648
  %v66 = icmp eq i32 10, -1
  %v67 = and i1 %v65, %v66
  br i1 %v67, label %L23, label %L24
L23:
  call void @pas_runtime_error(ptr @s22)
  unreachable
L24:
  %v68 = sdiv i32 %v63, 10
  store i32 %v68, ptr %v61
  br label %L8
L10:
  %v69 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 5
  %v70 = load i1, ptr %v69
  br i1 %v70, label %L25, label %L26
L25:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 45)
  br label %L26
L26:
  %v71 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 4
  %v72 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 3
  %v73 = load i32, ptr %v72
  store i32 %v73, ptr %v71
  br label %L27
L27:
  %v74 = load i32, ptr %v71
  %v75 = icmp sge i32 %v74, 1
  br i1 %v75, label %L28, label %L30
L28:
  %v76 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 2
  %v77 = getelementptr inbounds %frame90, ptr %frame, i32 0, i32 4
  %v78 = load i32, ptr %v77
  %v79 = icmp slt i32 %v78, 1
  %v80 = icmp sgt i32 %v78, 12
  %v81 = or i1 %v79, %v80
  br i1 %v81, label %L32, label %L33
L32:
  call void @pas_runtime_error(ptr @s23)
  unreachable
L33:
  %v82 = sub i32 %v78, 1
  %v83 = getelementptr inbounds [12 x i8], ptr %v76, i32 0, i32 %v82
  %v84 = load i8, ptr %v83
  call void @p.aptypes.put(ptr @frame.aptypes, i8 %v84)
  br label %L31
L31:
  %v85 = load i32, ptr %v71
  %v86 = icmp eq i32 %v85, 1
  br i1 %v86, label %L30, label %L29
L29:
  %v87 = sub i32 %v85, 1
  store i32 %v87, ptr %v71
  br label %L27
L30:
  ret void
}

; errorat 3062
define void @p.aptypes.errorat(ptr %link, i32 %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame6
  %v2 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 10
  store i1 true, ptr %v5
  %v6 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 11
  %v7 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 11
  %v8 = load i32, ptr %v7
  %v9 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v8, i32 1)
  %v10 = extractvalue { i32, i1 } %v9, 0
  %v11 = extractvalue { i32, i1 } %v9, 1
  %v12 = icmp eq i32 %v10, -2147483648
  %v13 = or i1 %v11, %v12
  br i1 %v13, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s24)
  unreachable
L3:
  store i32 %v10, ptr %v6
  %v14 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 25
  %v15 = load i1, ptr %v14
  br i1 %v15, label %L4, label %L5
L4:
  %v16 = icmp slt i32 1, 0
  br i1 %v16, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s25)
  unreachable
L8:
  %v17 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  %v19 = sext i32 %v18 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v19, i32 1)
  call void @pas_write_char(ptr @pas.output, i8 32, i32 -1)
  %v20 = icmp slt i32 1, 0
  br i1 %v20, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s26)
  unreachable
L10:
  %v21 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 2
  %v22 = load i32, ptr %v21
  %v23 = sext i32 %v22 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v23, i32 1)
  call void @pas_write_str(ptr @pas.output, ptr @s27, i32 7, i32 -1)
  br label %L6
L5:
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 40
  %v25 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v24, i32 0, i32 0
  %v26 = load i32, ptr %v25
  %v27 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v24, i32 0, i32 1
  call void @pas_write_str(ptr @pas.output, ptr %v27, i32 %v26, i32 -1)
  call void @pas_write_char(ptr @pas.output, i8 58, i32 -1)
  %v28 = icmp slt i32 1, 0
  br i1 %v28, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s28)
  unreachable
L12:
  %v29 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 1
  %v30 = load i32, ptr %v29
  %v31 = sext i32 %v30 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v31, i32 1)
  call void @pas_write_char(ptr @pas.output, i8 58, i32 -1)
  %v32 = icmp slt i32 1, 0
  br i1 %v32, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s29)
  unreachable
L14:
  %v33 = getelementptr inbounds %frame6, ptr %frame, i32 0, i32 2
  %v34 = load i32, ptr %v33
  %v35 = sext i32 %v34 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v35, i32 1)
  call void @pas_write_str(ptr @pas.output, ptr @s30, i32 9, i32 -1)
  br label %L6
L6:
  ret void
}

; warnat 3073
define void @p.aptypes.warnat(ptr %link, i32 %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame7
  %v2 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 25
  %v6 = load i1, ptr %v5
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = icmp slt i32 1, 0
  br i1 %v7, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s31)
  unreachable
L6:
  %v8 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 1
  %v9 = load i32, ptr %v8
  %v10 = sext i32 %v9 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v10, i32 1)
  call void @pas_write_char(ptr @pas.output, i8 32, i32 -1)
  %v11 = icmp slt i32 1, 0
  br i1 %v11, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s32)
  unreachable
L8:
  %v12 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 2
  %v13 = load i32, ptr %v12
  %v14 = sext i32 %v13 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v14, i32 1)
  call void @pas_write_str(ptr @pas.output, ptr @s33, i32 9, i32 -1)
  br label %L4
L3:
  %v15 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 40
  %v16 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v15, i32 0, i32 0
  %v17 = load i32, ptr %v16
  %v18 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v15, i32 0, i32 1
  call void @pas_write_str(ptr @pas.output, ptr %v18, i32 %v17, i32 -1)
  call void @pas_write_char(ptr @pas.output, i8 58, i32 -1)
  %v19 = icmp slt i32 1, 0
  br i1 %v19, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s34)
  unreachable
L10:
  %v20 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 1
  %v21 = load i32, ptr %v20
  %v22 = sext i32 %v21 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v22, i32 1)
  call void @pas_write_char(ptr @pas.output, i8 58, i32 -1)
  %v23 = icmp slt i32 1, 0
  br i1 %v23, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s35)
  unreachable
L12:
  %v24 = getelementptr inbounds %frame7, ptr %frame, i32 0, i32 2
  %v25 = load i32, ptr %v24
  %v26 = sext i32 %v25 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v26, i32 1)
  call void @pas_write_str(ptr @pas.output, ptr @s36, i32 11, i32 -1)
  br label %L4
L4:
  ret void
}

; pooladd 3087
define i32 @p.aptypes.pooladd(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame8
  %v2 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v5 = load i32, ptr %v4
  %v6 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 1
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds { i32, [255 x i8] }, ptr %v7, i32 0, i32 0
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v5, i32 %v9)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s37)
  unreachable
L3:
  %v15 = icmp sgt i32 %v11, 1000000
  br i1 %v15, label %L4, label %L5
L4:
  %v16 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 2
  %v17 = load i32, ptr %v16
  %v18 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 3
  %v19 = load i32, ptr %v18
  call void @p.aptypes.errorat(ptr @frame.aptypes, i32 %v17, i32 %v19)
  call void @pas_write_str(ptr @pas.output, ptr @s38, i32 41, i32 -1)
  %v20 = icmp slt i32 1, 0
  br i1 %v20, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s39)
  unreachable
L8:
  %v21 = sext i32 1000000 to i64
  call void @pas_write_int(ptr @pas.output, i64 %v21, i32 1)
  call void @pas_write_str(ptr @pas.output, ptr @s40, i32 19, i32 -1)
  call void @pas_writeln(ptr @pas.output)
  %v22 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 2
  store i32 1, ptr %v22
  br label %L6
L5:
  %v23 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 2
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v25 = load i32, ptr %v24
  %v26 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v25, i32 1)
  %v27 = extractvalue { i32, i1 } %v26, 0
  %v28 = extractvalue { i32, i1 } %v26, 1
  %v29 = icmp eq i32 %v27, -2147483648
  %v30 = or i1 %v28, %v29
  br i1 %v30, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s41)
  unreachable
L10:
  store i32 %v27, ptr %v23
  %v31 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 3
  %v32 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 1
  %v33 = load ptr, ptr %v32
  %v34 = getelementptr inbounds { i32, [255 x i8] }, ptr %v33, i32 0, i32 0
  %v35 = load i32, ptr %v34
  store i32 1, ptr %v31
  br label %L11
L11:
  %v36 = load i32, ptr %v31
  %v37 = icmp sle i32 %v36, %v35
  br i1 %v37, label %L12, label %L14
L12:
  %v38 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v39 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v40 = load i32, ptr %v39
  %v41 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 3
  %v42 = load i32, ptr %v41
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v40, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s42)
  unreachable
L17:
  %v48 = icmp slt i32 %v44, 1
  %v49 = icmp sgt i32 %v44, 1000000
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s43)
  unreachable
L19:
  %v51 = sub i32 %v44, 1
  %v52 = getelementptr inbounds [1000000 x i8], ptr %v38, i32 0, i32 %v51
  %v53 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 1
  %v54 = load ptr, ptr %v53
  %v55 = getelementptr inbounds { i32, [255 x i8] }, ptr %v54, i32 0, i32 1
  %v56 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 3
  %v57 = load i32, ptr %v56
  %v58 = icmp slt i32 %v57, 1
  %v59 = icmp sgt i32 %v57, 255
  %v60 = or i1 %v58, %v59
  br i1 %v60, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s44)
  unreachable
L21:
  %v61 = sub i32 %v57, 1
  %v62 = getelementptr inbounds [255 x i8], ptr %v55, i32 0, i32 %v61
  %v63 = load i8, ptr %v62
  store i8 %v63, ptr %v52
  br label %L15
L15:
  %v64 = load i32, ptr %v31
  %v65 = icmp eq i32 %v64, %v35
  br i1 %v65, label %L14, label %L13
L13:
  %v66 = add i32 %v64, 1
  store i32 %v66, ptr %v31
  br label %L11
L14:
  %v67 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v68 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v69 = load i32, ptr %v68
  %v70 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 1
  %v71 = load ptr, ptr %v70
  %v72 = getelementptr inbounds { i32, [255 x i8] }, ptr %v71, i32 0, i32 0
  %v73 = load i32, ptr %v72
  %v74 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v69, i32 %v73)
  %v75 = extractvalue { i32, i1 } %v74, 0
  %v76 = extractvalue { i32, i1 } %v74, 1
  %v77 = icmp eq i32 %v75, -2147483648
  %v78 = or i1 %v76, %v77
  br i1 %v78, label %L22, label %L23
L22:
  call void @pas_runtime_error(ptr @s45)
  unreachable
L23:
  store i32 %v75, ptr %v67
  br label %L6
L6:
  %v79 = getelementptr inbounds %frame8, ptr %frame, i32 0, i32 2
  %v80 = load i32, ptr %v79
  ret i32 %v80
}

; writepool 3104
define void @p.aptypes.writepool(ptr %link, i32 %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame9
  %v2 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 3
  %v6 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 1
  %v7 = load i32, ptr %v6
  %v8 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 1
  %v9 = load i32, ptr %v8
  %v10 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 2
  %v11 = load i32, ptr %v10
  %v12 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 %v11)
  %v13 = extractvalue { i32, i1 } %v12, 0
  %v14 = extractvalue { i32, i1 } %v12, 1
  %v15 = icmp eq i32 %v13, -2147483648
  %v16 = or i1 %v14, %v15
  br i1 %v16, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s46)
  unreachable
L3:
  %v17 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v13, i32 1)
  %v18 = extractvalue { i32, i1 } %v17, 0
  %v19 = extractvalue { i32, i1 } %v17, 1
  %v20 = icmp eq i32 %v18, -2147483648
  %v21 = or i1 %v19, %v20
  br i1 %v21, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s47)
  unreachable
L5:
  store i32 %v7, ptr %v5
  br label %L6
L6:
  %v22 = load i32, ptr %v5
  %v23 = icmp sle i32 %v22, %v18
  br i1 %v23, label %L7, label %L9
L7:
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v25 = getelementptr inbounds %frame9, ptr %frame, i32 0, i32 3
  %v26 = load i32, ptr %v25
  %v27 = icmp slt i32 %v26, 1
  %v28 = icmp sgt i32 %v26, 1000000
  %v29 = or i1 %v27, %v28
  br i1 %v29, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s48)
  unreachable
L12:
  %v30 = sub i32 %v26, 1
  %v31 = getelementptr inbounds [1000000 x i8], ptr %v24, i32 0, i32 %v30
  %v32 = load i8, ptr %v31
  call void @p.aptypes.put(ptr @frame.aptypes, i8 %v32)
  br label %L10
L10:
  %v33 = load i32, ptr %v5
  %v34 = icmp eq i32 %v33, %v18
  br i1 %v34, label %L9, label %L8
L8:
  %v35 = add i32 %v33, 1
  store i32 %v35, ptr %v5
  br label %L6
L9:
  ret void
}

; pooliswide 3117
define i1 @p.aptypes.pooliswide(ptr %link, i32 %a0, i32 %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame10
  %v2 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 3
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v5, ptr align 1 %a2, i64 16, i1 false)
  %v6 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  store i32 16, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v8 = load i32, ptr %v7
  %v9 = icmp sgt i32 %v8, 0
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 3
  %v11 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v12 = load i32, ptr %v11
  %v13 = icmp slt i32 %v12, 1
  %v14 = icmp sgt i32 %v12, 16
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s49)
  unreachable
L8:
  %v16 = sub i32 %v12, 1
  %v17 = getelementptr inbounds [16 x i8], ptr %v10, i32 0, i32 %v16
  %v18 = load i8, ptr %v17
  %v19 = icmp eq i8 %v18, 32
  br label %L6
L6:
  %v20 = phi i1 [ false, %L2 ], [ %v19, %L8 ]
  br i1 %v20, label %L3, label %L4
L3:
  %v21 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v22 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v23 = load i32, ptr %v22
  %v24 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v23, i32 1)
  %v25 = extractvalue { i32, i1 } %v24, 0
  %v26 = extractvalue { i32, i1 } %v24, 1
  %v27 = icmp eq i32 %v25, -2147483648
  %v28 = or i1 %v26, %v27
  br i1 %v28, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s50)
  unreachable
L10:
  store i32 %v25, ptr %v21
  br label %L2
L4:
  %v29 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v30 = load i32, ptr %v29
  %v31 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 2
  %v32 = load i32, ptr %v31
  %v33 = icmp ne i32 %v30, %v32
  br i1 %v33, label %L11, label %L12
L11:
  %v34 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v34
  br label %L13
L12:
  %v35 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 7
  store i1 true, ptr %v35
  %v36 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 6
  %v37 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 5
  %v38 = load i32, ptr %v37
  store i32 1, ptr %v36
  br label %L14
L14:
  %v39 = load i32, ptr %v36
  %v40 = icmp sle i32 %v39, %v38
  br i1 %v40, label %L15, label %L17
L15:
  %v41 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v42 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 1
  %v43 = load i32, ptr %v42
  %v44 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 6
  %v45 = load i32, ptr %v44
  %v46 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v43, i32 %v45)
  %v47 = extractvalue { i32, i1 } %v46, 0
  %v48 = extractvalue { i32, i1 } %v46, 1
  %v49 = icmp eq i32 %v47, -2147483648
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s51)
  unreachable
L20:
  %v51 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v47, i32 1)
  %v52 = extractvalue { i32, i1 } %v51, 0
  %v53 = extractvalue { i32, i1 } %v51, 1
  %v54 = icmp eq i32 %v52, -2147483648
  %v55 = or i1 %v53, %v54
  br i1 %v55, label %L21, label %L22
L21:
  call void @pas_runtime_error(ptr @s52)
  unreachable
L22:
  %v56 = icmp slt i32 %v52, 1
  %v57 = icmp sgt i32 %v52, 1000000
  %v58 = or i1 %v56, %v57
  br i1 %v58, label %L23, label %L24
L23:
  call void @pas_runtime_error(ptr @s53)
  unreachable
L24:
  %v59 = sub i32 %v52, 1
  %v60 = getelementptr inbounds [1000000 x i8], ptr %v41, i32 0, i32 %v59
  %v61 = load i8, ptr %v60
  %v62 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 3
  %v63 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 6
  %v64 = load i32, ptr %v63
  %v65 = icmp slt i32 %v64, 1
  %v66 = icmp sgt i32 %v64, 16
  %v67 = or i1 %v65, %v66
  br i1 %v67, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s54)
  unreachable
L26:
  %v68 = sub i32 %v64, 1
  %v69 = getelementptr inbounds [16 x i8], ptr %v62, i32 0, i32 %v68
  %v70 = load i8, ptr %v69
  %v71 = icmp ne i8 %v61, %v70
  br i1 %v71, label %L27, label %L28
L27:
  %v72 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 7
  store i1 false, ptr %v72
  br label %L28
L28:
  br label %L18
L18:
  %v73 = load i32, ptr %v36
  %v74 = icmp eq i32 %v73, %v38
  br i1 %v74, label %L17, label %L16
L16:
  %v75 = add i32 %v73, 1
  store i32 %v75, ptr %v36
  br label %L14
L17:
  %v76 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 4
  %v77 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 7
  %v78 = load i1, ptr %v77
  store i1 %v78, ptr %v76
  br label %L13
L13:
  %v79 = getelementptr inbounds %frame10, ptr %frame, i32 0, i32 4
  %v80 = load i1, ptr %v79
  ret i1 %v80
}

; poolis 3133
define i1 @p.aptypes.poolis(ptr %link, i32 %a0, i32 %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame11
  %v2 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 3
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v5, ptr align 1 %a2, i64 9, i1 false)
  %v6 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  store i32 9, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v8 = load i32, ptr %v7
  %v9 = icmp sgt i32 %v8, 0
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 3
  %v11 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v12 = load i32, ptr %v11
  %v13 = icmp slt i32 %v12, 1
  %v14 = icmp sgt i32 %v12, 9
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s55)
  unreachable
L8:
  %v16 = sub i32 %v12, 1
  %v17 = getelementptr inbounds [9 x i8], ptr %v10, i32 0, i32 %v16
  %v18 = load i8, ptr %v17
  %v19 = icmp eq i8 %v18, 32
  br label %L6
L6:
  %v20 = phi i1 [ false, %L2 ], [ %v19, %L8 ]
  br i1 %v20, label %L3, label %L4
L3:
  %v21 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v22 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v23 = load i32, ptr %v22
  %v24 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v23, i32 1)
  %v25 = extractvalue { i32, i1 } %v24, 0
  %v26 = extractvalue { i32, i1 } %v24, 1
  %v27 = icmp eq i32 %v25, -2147483648
  %v28 = or i1 %v26, %v27
  br i1 %v28, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s56)
  unreachable
L10:
  store i32 %v25, ptr %v21
  br label %L2
L4:
  %v29 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v30 = load i32, ptr %v29
  %v31 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 2
  %v32 = load i32, ptr %v31
  %v33 = icmp ne i32 %v30, %v32
  br i1 %v33, label %L11, label %L12
L11:
  %v34 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v34
  br label %L13
L12:
  %v35 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 7
  store i1 true, ptr %v35
  %v36 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  store i32 1, ptr %v36
  br label %L14
L14:
  %v37 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 7
  %v38 = load i1, ptr %v37
  br i1 %v38, label %L17, label %L18
L17:
  %v39 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  %v40 = load i32, ptr %v39
  %v41 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 5
  %v42 = load i32, ptr %v41
  %v43 = icmp sle i32 %v40, %v42
  br label %L18
L18:
  %v44 = phi i1 [ false, %L14 ], [ %v43, %L17 ]
  br i1 %v44, label %L15, label %L16
L15:
  %v45 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 7
  %v46 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 3
  %v47 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  %v48 = load i32, ptr %v47
  %v49 = icmp slt i32 %v48, 1
  %v50 = icmp sgt i32 %v48, 9
  %v51 = or i1 %v49, %v50
  br i1 %v51, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s57)
  unreachable
L20:
  %v52 = sub i32 %v48, 1
  %v53 = getelementptr inbounds [9 x i8], ptr %v46, i32 0, i32 %v52
  %v54 = load i8, ptr %v53
  %v55 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v56 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 1
  %v57 = load i32, ptr %v56
  %v58 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  %v59 = load i32, ptr %v58
  %v60 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v57, i32 %v59)
  %v61 = extractvalue { i32, i1 } %v60, 0
  %v62 = extractvalue { i32, i1 } %v60, 1
  %v63 = icmp eq i32 %v61, -2147483648
  %v64 = or i1 %v62, %v63
  br i1 %v64, label %L21, label %L22
L21:
  call void @pas_runtime_error(ptr @s58)
  unreachable
L22:
  %v65 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v61, i32 1)
  %v66 = extractvalue { i32, i1 } %v65, 0
  %v67 = extractvalue { i32, i1 } %v65, 1
  %v68 = icmp eq i32 %v66, -2147483648
  %v69 = or i1 %v67, %v68
  br i1 %v69, label %L23, label %L24
L23:
  call void @pas_runtime_error(ptr @s59)
  unreachable
L24:
  %v70 = icmp slt i32 %v66, 1
  %v71 = icmp sgt i32 %v66, 1000000
  %v72 = or i1 %v70, %v71
  br i1 %v72, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s60)
  unreachable
L26:
  %v73 = sub i32 %v66, 1
  %v74 = getelementptr inbounds [1000000 x i8], ptr %v55, i32 0, i32 %v73
  %v75 = load i8, ptr %v74
  %v76 = icmp eq i8 %v54, %v75
  store i1 %v76, ptr %v45
  %v77 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  %v78 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 6
  %v79 = load i32, ptr %v78
  %v80 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v79, i32 1)
  %v81 = extractvalue { i32, i1 } %v80, 0
  %v82 = extractvalue { i32, i1 } %v80, 1
  %v83 = icmp eq i32 %v81, -2147483648
  %v84 = or i1 %v82, %v83
  br i1 %v84, label %L27, label %L28
L27:
  call void @pas_runtime_error(ptr @s61)
  unreachable
L28:
  store i32 %v81, ptr %v77
  br label %L14
L16:
  %v85 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 4
  %v86 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 7
  %v87 = load i1, ptr %v86
  store i1 %v87, ptr %v85
  br label %L13
L13:
  %v88 = getelementptr inbounds %frame11, ptr %frame, i32 0, i32 4
  %v89 = load i1, ptr %v88
  ret i1 %v89
}

; poolstarts 3153
define internal i1 @p91(ptr %link, i32 %a0, i32 %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame91
  %v2 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 3
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v5, ptr align 1 %a2, i64 9, i1 false)
  %v6 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  store i32 9, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v8 = load i32, ptr %v7
  %v9 = icmp sgt i32 %v8, 0
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 3
  %v11 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v12 = load i32, ptr %v11
  %v13 = icmp slt i32 %v12, 1
  %v14 = icmp sgt i32 %v12, 9
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s62)
  unreachable
L8:
  %v16 = sub i32 %v12, 1
  %v17 = getelementptr inbounds [9 x i8], ptr %v10, i32 0, i32 %v16
  %v18 = load i8, ptr %v17
  %v19 = icmp eq i8 %v18, 32
  br label %L6
L6:
  %v20 = phi i1 [ false, %L2 ], [ %v19, %L8 ]
  br i1 %v20, label %L3, label %L4
L3:
  %v21 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v22 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v23 = load i32, ptr %v22
  %v24 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v23, i32 1)
  %v25 = extractvalue { i32, i1 } %v24, 0
  %v26 = extractvalue { i32, i1 } %v24, 1
  %v27 = icmp eq i32 %v25, -2147483648
  %v28 = or i1 %v26, %v27
  br i1 %v28, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s63)
  unreachable
L10:
  store i32 %v25, ptr %v21
  br label %L2
L4:
  %v29 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 2
  %v30 = load i32, ptr %v29
  %v31 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v32 = load i32, ptr %v31
  %v33 = icmp slt i32 %v30, %v32
  br i1 %v33, label %L11, label %L12
L11:
  %v34 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v34
  br label %L13
L12:
  %v35 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 7
  store i1 true, ptr %v35
  %v36 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  store i32 1, ptr %v36
  br label %L14
L14:
  %v37 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 7
  %v38 = load i1, ptr %v37
  br i1 %v38, label %L17, label %L18
L17:
  %v39 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  %v40 = load i32, ptr %v39
  %v41 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 5
  %v42 = load i32, ptr %v41
  %v43 = icmp sle i32 %v40, %v42
  br label %L18
L18:
  %v44 = phi i1 [ false, %L14 ], [ %v43, %L17 ]
  br i1 %v44, label %L15, label %L16
L15:
  %v45 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 7
  %v46 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 3
  %v47 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  %v48 = load i32, ptr %v47
  %v49 = icmp slt i32 %v48, 1
  %v50 = icmp sgt i32 %v48, 9
  %v51 = or i1 %v49, %v50
  br i1 %v51, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s64)
  unreachable
L20:
  %v52 = sub i32 %v48, 1
  %v53 = getelementptr inbounds [9 x i8], ptr %v46, i32 0, i32 %v52
  %v54 = load i8, ptr %v53
  %v55 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v56 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 1
  %v57 = load i32, ptr %v56
  %v58 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  %v59 = load i32, ptr %v58
  %v60 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v57, i32 %v59)
  %v61 = extractvalue { i32, i1 } %v60, 0
  %v62 = extractvalue { i32, i1 } %v60, 1
  %v63 = icmp eq i32 %v61, -2147483648
  %v64 = or i1 %v62, %v63
  br i1 %v64, label %L21, label %L22
L21:
  call void @pas_runtime_error(ptr @s65)
  unreachable
L22:
  %v65 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v61, i32 1)
  %v66 = extractvalue { i32, i1 } %v65, 0
  %v67 = extractvalue { i32, i1 } %v65, 1
  %v68 = icmp eq i32 %v66, -2147483648
  %v69 = or i1 %v67, %v68
  br i1 %v69, label %L23, label %L24
L23:
  call void @pas_runtime_error(ptr @s66)
  unreachable
L24:
  %v70 = icmp slt i32 %v66, 1
  %v71 = icmp sgt i32 %v66, 1000000
  %v72 = or i1 %v70, %v71
  br i1 %v72, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s67)
  unreachable
L26:
  %v73 = sub i32 %v66, 1
  %v74 = getelementptr inbounds [1000000 x i8], ptr %v55, i32 0, i32 %v73
  %v75 = load i8, ptr %v74
  %v76 = icmp eq i8 %v54, %v75
  store i1 %v76, ptr %v45
  %v77 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  %v78 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 6
  %v79 = load i32, ptr %v78
  %v80 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v79, i32 1)
  %v81 = extractvalue { i32, i1 } %v80, 0
  %v82 = extractvalue { i32, i1 } %v80, 1
  %v83 = icmp eq i32 %v81, -2147483648
  %v84 = or i1 %v82, %v83
  br i1 %v84, label %L27, label %L28
L27:
  call void @pas_runtime_error(ptr @s68)
  unreachable
L28:
  store i32 %v81, ptr %v77
  br label %L14
L16:
  %v85 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 4
  %v86 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 7
  %v87 = load i1, ptr %v86
  store i1 %v87, ptr %v85
  br label %L13
L13:
  %v88 = getelementptr inbounds %frame91, ptr %frame, i32 0, i32 4
  %v89 = load i1, ptr %v88
  ret i1 %v89
}

; reservedforeignname 3196
define i1 @p.aptypes.reservedforeignname(ptr %link, i32 %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame12
  %v2 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 6
  store i1 false, ptr %v5
  %v6 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v7 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v8 = load i32, ptr %v7
  %v9 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v10 = load i32, ptr %v9
  %v11 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v12 = load i32, ptr %v11
  %v13 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v10, i32 %v12)
  %v14 = extractvalue { i32, i1 } %v13, 0
  %v15 = extractvalue { i32, i1 } %v13, 1
  %v16 = icmp eq i32 %v14, -2147483648
  %v17 = or i1 %v15, %v16
  br i1 %v17, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s69)
  unreachable
L3:
  %v18 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v14, i32 1)
  %v19 = extractvalue { i32, i1 } %v18, 0
  %v20 = extractvalue { i32, i1 } %v18, 1
  %v21 = icmp eq i32 %v19, -2147483648
  %v22 = or i1 %v20, %v21
  br i1 %v22, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s70)
  unreachable
L5:
  store i32 %v8, ptr %v6
  br label %L6
L6:
  %v23 = load i32, ptr %v6
  %v24 = icmp sle i32 %v23, %v19
  br i1 %v24, label %L7, label %L9
L7:
  %v25 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v26 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v27 = load i32, ptr %v26
  %v28 = icmp slt i32 %v27, 1
  %v29 = icmp sgt i32 %v27, 1000000
  %v30 = or i1 %v28, %v29
  br i1 %v30, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s71)
  unreachable
L12:
  %v31 = sub i32 %v27, 1
  %v32 = getelementptr inbounds [1000000 x i8], ptr %v25, i32 0, i32 %v31
  %v33 = load i8, ptr %v32
  %v34 = icmp eq i8 %v33, 46
  br i1 %v34, label %L13, label %L14
L13:
  %v35 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 6
  store i1 true, ptr %v35
  br label %L14
L14:
  br label %L10
L10:
  %v36 = load i32, ptr %v6
  %v37 = icmp eq i32 %v36, %v19
  br i1 %v37, label %L9, label %L8
L8:
  %v38 = add i32 %v36, 1
  store i32 %v38, ptr %v6
  br label %L6
L9:
  %v39 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 5
  %v40 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v41 = load i32, ptr %v40
  %v42 = icmp sge i32 %v41, 2
  br i1 %v42, label %L15, label %L16
L15:
  %v43 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v44 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v45 = load i32, ptr %v44
  %v46 = icmp slt i32 %v45, 1
  %v47 = icmp sgt i32 %v45, 1000000
  %v48 = or i1 %v46, %v47
  br i1 %v48, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s72)
  unreachable
L18:
  %v49 = sub i32 %v45, 1
  %v50 = getelementptr inbounds [1000000 x i8], ptr %v43, i32 0, i32 %v49
  %v51 = load i8, ptr %v50
  %v52 = icmp eq i8 %v51, 112
  br i1 %v52, label %L20, label %L19
L19:
  %v53 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v54 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v55 = load i32, ptr %v54
  %v56 = icmp slt i32 %v55, 1
  %v57 = icmp sgt i32 %v55, 1000000
  %v58 = or i1 %v56, %v57
  br i1 %v58, label %L21, label %L22
L21:
  call void @pas_runtime_error(ptr @s73)
  unreachable
L22:
  %v59 = sub i32 %v55, 1
  %v60 = getelementptr inbounds [1000000 x i8], ptr %v53, i32 0, i32 %v59
  %v61 = load i8, ptr %v60
  %v62 = icmp eq i8 %v61, 115
  br label %L20
L20:
  %v63 = phi i1 [ true, %L18 ], [ %v62, %L22 ]
  br label %L16
L16:
  %v64 = phi i1 [ false, %L9 ], [ %v63, %L20 ]
  store i1 %v64, ptr %v39
  %v65 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 5
  %v66 = load i1, ptr %v65
  br i1 %v66, label %L23, label %L24
L23:
  %v67 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v68 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v69 = load i32, ptr %v68
  %v70 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v69, i32 1)
  %v71 = extractvalue { i32, i1 } %v70, 0
  %v72 = extractvalue { i32, i1 } %v70, 1
  %v73 = icmp eq i32 %v71, -2147483648
  %v74 = or i1 %v72, %v73
  br i1 %v74, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s74)
  unreachable
L26:
  %v75 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v76 = load i32, ptr %v75
  %v77 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v78 = load i32, ptr %v77
  %v79 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v76, i32 %v78)
  %v80 = extractvalue { i32, i1 } %v79, 0
  %v81 = extractvalue { i32, i1 } %v79, 1
  %v82 = icmp eq i32 %v80, -2147483648
  %v83 = or i1 %v81, %v82
  br i1 %v83, label %L27, label %L28
L27:
  call void @pas_runtime_error(ptr @s75)
  unreachable
L28:
  %v84 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v80, i32 1)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L29, label %L30
L29:
  call void @pas_runtime_error(ptr @s76)
  unreachable
L30:
  store i32 %v71, ptr %v67
  br label %L31
L31:
  %v89 = load i32, ptr %v67
  %v90 = icmp sle i32 %v89, %v85
  br i1 %v90, label %L32, label %L34
L32:
  %v91 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v92 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v93 = load i32, ptr %v92
  %v94 = icmp slt i32 %v93, 1
  %v95 = icmp sgt i32 %v93, 1000000
  %v96 = or i1 %v94, %v95
  br i1 %v96, label %L36, label %L37
L36:
  call void @pas_runtime_error(ptr @s77)
  unreachable
L37:
  %v97 = sub i32 %v93, 1
  %v98 = getelementptr inbounds [1000000 x i8], ptr %v91, i32 0, i32 %v97
  %v99 = load i8, ptr %v98
  %v100 = icmp ult i8 %v99, 48
  br i1 %v100, label %L39, label %L38
L38:
  %v101 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v102 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v103 = load i32, ptr %v102
  %v104 = icmp slt i32 %v103, 1
  %v105 = icmp sgt i32 %v103, 1000000
  %v106 = or i1 %v104, %v105
  br i1 %v106, label %L40, label %L41
L40:
  call void @pas_runtime_error(ptr @s78)
  unreachable
L41:
  %v107 = sub i32 %v103, 1
  %v108 = getelementptr inbounds [1000000 x i8], ptr %v101, i32 0, i32 %v107
  %v109 = load i8, ptr %v108
  %v110 = icmp ugt i8 %v109, 57
  br label %L39
L39:
  %v111 = phi i1 [ true, %L37 ], [ %v110, %L41 ]
  br i1 %v111, label %L42, label %L43
L42:
  %v112 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 5
  store i1 false, ptr %v112
  br label %L43
L43:
  br label %L35
L35:
  %v113 = load i32, ptr %v67
  %v114 = icmp eq i32 %v113, %v85
  br i1 %v114, label %L34, label %L33
L33:
  %v115 = add i32 %v113, 1
  store i32 %v115, ptr %v67
  br label %L31
L34:
  br label %L24
L24:
  %v116 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 7
  %v117 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v118 = load i32, ptr %v117
  %v119 = icmp sge i32 %v118, 6
  br i1 %v119, label %L44, label %L45
L44:
  %v120 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v121 = load i32, ptr %v120
  %v122 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v123 = load i32, ptr %v122
  %v124 = call i1 @p91(ptr @frame.aptypes, i32 %v121, i32 %v123, ptr @s79)
  br label %L45
L45:
  %v125 = phi i1 [ false, %L24 ], [ %v124, %L44 ]
  store i1 %v125, ptr %v116
  %v126 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 7
  %v127 = load i1, ptr %v126
  br i1 %v127, label %L46, label %L47
L46:
  %v128 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v129 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v130 = load i32, ptr %v129
  %v131 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v130, i32 5)
  %v132 = extractvalue { i32, i1 } %v131, 0
  %v133 = extractvalue { i32, i1 } %v131, 1
  %v134 = icmp eq i32 %v132, -2147483648
  %v135 = or i1 %v133, %v134
  br i1 %v135, label %L48, label %L49
L48:
  call void @pas_runtime_error(ptr @s80)
  unreachable
L49:
  %v136 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v137 = load i32, ptr %v136
  %v138 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v139 = load i32, ptr %v138
  %v140 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v137, i32 %v139)
  %v141 = extractvalue { i32, i1 } %v140, 0
  %v142 = extractvalue { i32, i1 } %v140, 1
  %v143 = icmp eq i32 %v141, -2147483648
  %v144 = or i1 %v142, %v143
  br i1 %v144, label %L50, label %L51
L50:
  call void @pas_runtime_error(ptr @s81)
  unreachable
L51:
  %v145 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v141, i32 1)
  %v146 = extractvalue { i32, i1 } %v145, 0
  %v147 = extractvalue { i32, i1 } %v145, 1
  %v148 = icmp eq i32 %v146, -2147483648
  %v149 = or i1 %v147, %v148
  br i1 %v149, label %L52, label %L53
L52:
  call void @pas_runtime_error(ptr @s82)
  unreachable
L53:
  store i32 %v132, ptr %v128
  br label %L54
L54:
  %v150 = load i32, ptr %v128
  %v151 = icmp sle i32 %v150, %v146
  br i1 %v151, label %L55, label %L57
L55:
  %v152 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v153 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v154 = load i32, ptr %v153
  %v155 = icmp slt i32 %v154, 1
  %v156 = icmp sgt i32 %v154, 1000000
  %v157 = or i1 %v155, %v156
  br i1 %v157, label %L59, label %L60
L59:
  call void @pas_runtime_error(ptr @s83)
  unreachable
L60:
  %v158 = sub i32 %v154, 1
  %v159 = getelementptr inbounds [1000000 x i8], ptr %v152, i32 0, i32 %v158
  %v160 = load i8, ptr %v159
  %v161 = icmp ult i8 %v160, 48
  br i1 %v161, label %L62, label %L61
L61:
  %v162 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v163 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v164 = load i32, ptr %v163
  %v165 = icmp slt i32 %v164, 1
  %v166 = icmp sgt i32 %v164, 1000000
  %v167 = or i1 %v165, %v166
  br i1 %v167, label %L63, label %L64
L63:
  call void @pas_runtime_error(ptr @s84)
  unreachable
L64:
  %v168 = sub i32 %v164, 1
  %v169 = getelementptr inbounds [1000000 x i8], ptr %v162, i32 0, i32 %v168
  %v170 = load i8, ptr %v169
  %v171 = icmp ugt i8 %v170, 57
  br label %L62
L62:
  %v172 = phi i1 [ true, %L60 ], [ %v171, %L64 ]
  br i1 %v172, label %L65, label %L66
L65:
  %v173 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 7
  store i1 false, ptr %v173
  br label %L66
L66:
  br label %L58
L58:
  %v174 = load i32, ptr %v128
  %v175 = icmp eq i32 %v174, %v146
  br i1 %v175, label %L57, label %L56
L56:
  %v176 = add i32 %v174, 1
  store i32 %v176, ptr %v128
  br label %L54
L57:
  br label %L47
L47:
  %v177 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 8
  %v178 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v179 = load i32, ptr %v178
  %v180 = icmp sge i32 %v179, 6
  br i1 %v180, label %L67, label %L68
L67:
  %v181 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v182 = load i32, ptr %v181
  %v183 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v184 = load i32, ptr %v183
  %v185 = call i1 @p91(ptr @frame.aptypes, i32 %v182, i32 %v184, ptr @s85)
  br label %L68
L68:
  %v186 = phi i1 [ false, %L47 ], [ %v185, %L67 ]
  store i1 %v186, ptr %v177
  %v187 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 8
  %v188 = load i1, ptr %v187
  br i1 %v188, label %L69, label %L70
L69:
  %v189 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v190 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v191 = load i32, ptr %v190
  %v192 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v191, i32 6)
  %v193 = extractvalue { i32, i1 } %v192, 0
  %v194 = extractvalue { i32, i1 } %v192, 1
  %v195 = icmp eq i32 %v193, -2147483648
  %v196 = or i1 %v194, %v195
  br i1 %v196, label %L71, label %L72
L71:
  call void @pas_runtime_error(ptr @s86)
  unreachable
L72:
  %v197 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v198 = load i32, ptr %v197
  %v199 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v200 = load i32, ptr %v199
  %v201 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v198, i32 %v200)
  %v202 = extractvalue { i32, i1 } %v201, 0
  %v203 = extractvalue { i32, i1 } %v201, 1
  %v204 = icmp eq i32 %v202, -2147483648
  %v205 = or i1 %v203, %v204
  br i1 %v205, label %L73, label %L74
L73:
  call void @pas_runtime_error(ptr @s87)
  unreachable
L74:
  %v206 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v202, i32 1)
  %v207 = extractvalue { i32, i1 } %v206, 0
  %v208 = extractvalue { i32, i1 } %v206, 1
  %v209 = icmp eq i32 %v207, -2147483648
  %v210 = or i1 %v208, %v209
  br i1 %v210, label %L75, label %L76
L75:
  call void @pas_runtime_error(ptr @s88)
  unreachable
L76:
  store i32 %v193, ptr %v189
  br label %L77
L77:
  %v211 = load i32, ptr %v189
  %v212 = icmp sle i32 %v211, %v207
  br i1 %v212, label %L78, label %L80
L78:
  %v213 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v214 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v215 = load i32, ptr %v214
  %v216 = icmp slt i32 %v215, 1
  %v217 = icmp sgt i32 %v215, 1000000
  %v218 = or i1 %v216, %v217
  br i1 %v218, label %L82, label %L83
L82:
  call void @pas_runtime_error(ptr @s89)
  unreachable
L83:
  %v219 = sub i32 %v215, 1
  %v220 = getelementptr inbounds [1000000 x i8], ptr %v213, i32 0, i32 %v219
  %v221 = load i8, ptr %v220
  %v222 = icmp ult i8 %v221, 48
  br i1 %v222, label %L85, label %L84
L84:
  %v223 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v224 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 4
  %v225 = load i32, ptr %v224
  %v226 = icmp slt i32 %v225, 1
  %v227 = icmp sgt i32 %v225, 1000000
  %v228 = or i1 %v226, %v227
  br i1 %v228, label %L86, label %L87
L86:
  call void @pas_runtime_error(ptr @s90)
  unreachable
L87:
  %v229 = sub i32 %v225, 1
  %v230 = getelementptr inbounds [1000000 x i8], ptr %v223, i32 0, i32 %v229
  %v231 = load i8, ptr %v230
  %v232 = icmp ugt i8 %v231, 57
  br label %L85
L85:
  %v233 = phi i1 [ true, %L83 ], [ %v232, %L87 ]
  br i1 %v233, label %L88, label %L89
L88:
  %v234 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 8
  store i1 false, ptr %v234
  br label %L89
L89:
  br label %L81
L81:
  %v235 = load i32, ptr %v189
  %v236 = icmp eq i32 %v235, %v207
  br i1 %v236, label %L80, label %L79
L79:
  %v237 = add i32 %v235, 1
  store i32 %v237, ptr %v189
  br label %L77
L80:
  br label %L70
L70:
  %v238 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 3
  %v239 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 6
  %v240 = load i1, ptr %v239
  br i1 %v240, label %L91, label %L90
L90:
  %v241 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 5
  %v242 = load i1, ptr %v241
  br label %L91
L91:
  %v243 = phi i1 [ true, %L70 ], [ %v242, %L90 ]
  br i1 %v243, label %L93, label %L92
L92:
  %v244 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 7
  %v245 = load i1, ptr %v244
  br label %L93
L93:
  %v246 = phi i1 [ true, %L91 ], [ %v245, %L92 ]
  br i1 %v246, label %L95, label %L94
L94:
  %v247 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 8
  %v248 = load i1, ptr %v247
  br label %L95
L95:
  %v249 = phi i1 [ true, %L93 ], [ %v248, %L94 ]
  br i1 %v249, label %L97, label %L96
L96:
  %v250 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v251 = load i32, ptr %v250
  %v252 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v253 = load i32, ptr %v252
  %v254 = call i1 @p91(ptr @frame.aptypes, i32 %v251, i32 %v253, ptr @s91)
  br label %L97
L97:
  %v255 = phi i1 [ true, %L95 ], [ %v254, %L96 ]
  br i1 %v255, label %L99, label %L98
L98:
  %v256 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v257 = load i32, ptr %v256
  %v258 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v259 = load i32, ptr %v258
  %v260 = call i1 @p.aptypes.poolis(ptr @frame.aptypes, i32 %v257, i32 %v259, ptr @s92)
  br label %L99
L99:
  %v261 = phi i1 [ true, %L97 ], [ %v260, %L98 ]
  br i1 %v261, label %L101, label %L100
L100:
  %v262 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 1
  %v263 = load i32, ptr %v262
  %v264 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 2
  %v265 = load i32, ptr %v264
  %v266 = call i1 @p.aptypes.poolis(ptr @frame.aptypes, i32 %v263, i32 %v265, ptr @s93)
  br label %L101
L101:
  %v267 = phi i1 [ true, %L99 ], [ %v266, %L100 ]
  store i1 %v267, ptr %v238
  %v268 = getelementptr inbounds %frame12, ptr %frame, i32 0, i32 3
  %v269 = load i1, ptr %v268
  ret i1 %v269
}

; poolsame 3249
define i1 @p.aptypes.poolsame(ptr %link, i32 %a0, i32 %a1, i32 %a2, i32 %a3) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame13
  %v2 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 3
  store i32 %a2, ptr %v5
  %v6 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 4
  store i32 %a3, ptr %v6
  %v7 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 2
  %v8 = load i32, ptr %v7
  %v9 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 4
  %v10 = load i32, ptr %v9
  %v11 = icmp ne i32 %v8, %v10
  br i1 %v11, label %L2, label %L3
L2:
  %v12 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 5
  store i1 false, ptr %v12
  br label %L4
L3:
  %v13 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 7
  store i1 true, ptr %v13
  %v14 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  store i32 0, ptr %v14
  br label %L5
L5:
  %v15 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 7
  %v16 = load i1, ptr %v15
  br i1 %v16, label %L8, label %L9
L8:
  %v17 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  %v18 = load i32, ptr %v17
  %v19 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 2
  %v20 = load i32, ptr %v19
  %v21 = icmp slt i32 %v18, %v20
  br label %L9
L9:
  %v22 = phi i1 [ false, %L5 ], [ %v21, %L8 ]
  br i1 %v22, label %L6, label %L7
L6:
  %v23 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 7
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v25 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 1
  %v26 = load i32, ptr %v25
  %v27 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  %v28 = load i32, ptr %v27
  %v29 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v26, i32 %v28)
  %v30 = extractvalue { i32, i1 } %v29, 0
  %v31 = extractvalue { i32, i1 } %v29, 1
  %v32 = icmp eq i32 %v30, -2147483648
  %v33 = or i1 %v31, %v32
  br i1 %v33, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s94)
  unreachable
L11:
  %v34 = icmp slt i32 %v30, 1
  %v35 = icmp sgt i32 %v30, 1000000
  %v36 = or i1 %v34, %v35
  br i1 %v36, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s95)
  unreachable
L13:
  %v37 = sub i32 %v30, 1
  %v38 = getelementptr inbounds [1000000 x i8], ptr %v24, i32 0, i32 %v37
  %v39 = load i8, ptr %v38
  %v40 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v41 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 3
  %v42 = load i32, ptr %v41
  %v43 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  %v44 = load i32, ptr %v43
  %v45 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v42, i32 %v44)
  %v46 = extractvalue { i32, i1 } %v45, 0
  %v47 = extractvalue { i32, i1 } %v45, 1
  %v48 = icmp eq i32 %v46, -2147483648
  %v49 = or i1 %v47, %v48
  br i1 %v49, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s96)
  unreachable
L15:
  %v50 = icmp slt i32 %v46, 1
  %v51 = icmp sgt i32 %v46, 1000000
  %v52 = or i1 %v50, %v51
  br i1 %v52, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s97)
  unreachable
L17:
  %v53 = sub i32 %v46, 1
  %v54 = getelementptr inbounds [1000000 x i8], ptr %v40, i32 0, i32 %v53
  %v55 = load i8, ptr %v54
  %v56 = icmp eq i8 %v39, %v55
  store i1 %v56, ptr %v23
  %v57 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  %v58 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 6
  %v59 = load i32, ptr %v58
  %v60 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v59, i32 1)
  %v61 = extractvalue { i32, i1 } %v60, 0
  %v62 = extractvalue { i32, i1 } %v60, 1
  %v63 = icmp eq i32 %v61, -2147483648
  %v64 = or i1 %v62, %v63
  br i1 %v64, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s98)
  unreachable
L19:
  store i32 %v61, ptr %v57
  br label %L5
L7:
  %v65 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 5
  %v66 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 7
  %v67 = load i1, ptr %v66
  store i1 %v67, ptr %v65
  br label %L4
L4:
  %v68 = getelementptr inbounds %frame13, ptr %frame, i32 0, i32 5
  %v69 = load i1, ptr %v68
  ret i1 %v69
}

; poolput 3267
define void @p.aptypes.poolput(ptr %link, i8 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame14
  %v2 = getelementptr inbounds %frame14, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame14, ptr %frame, i32 0, i32 1
  store i8 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v5 = load i32, ptr %v4
  %v6 = icmp slt i32 %v5, 1000000
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s99)
  unreachable
L5:
  store i32 %v11, ptr %v7
  %v15 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v16 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v17 = load i32, ptr %v16
  %v18 = icmp slt i32 %v17, 1
  %v19 = icmp sgt i32 %v17, 1000000
  %v20 = or i1 %v18, %v19
  br i1 %v20, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s100)
  unreachable
L7:
  %v21 = sub i32 %v17, 1
  %v22 = getelementptr inbounds [1000000 x i8], ptr %v15, i32 0, i32 %v21
  %v23 = getelementptr inbounds %frame14, ptr %frame, i32 0, i32 1
  %v24 = load i8, ptr %v23
  store i8 %v24, ptr %v22
  br label %L3
L3:
  ret void
}

; internword 3277
define void @p.aptypes.internword(ptr %link, ptr %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame15
  %v2 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v3, ptr align 1 %a0, i64 9, i1 false)
  %v4 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  store i32 9, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v8 = load i32, ptr %v7
  %v9 = icmp sgt i32 %v8, 0
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 1
  %v11 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v12 = load i32, ptr %v11
  %v13 = icmp slt i32 %v12, 1
  %v14 = icmp sgt i32 %v12, 9
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s101)
  unreachable
L8:
  %v16 = sub i32 %v12, 1
  %v17 = getelementptr inbounds [9 x i8], ptr %v10, i32 0, i32 %v16
  %v18 = load i8, ptr %v17
  %v19 = icmp eq i8 %v18, 32
  br label %L6
L6:
  %v20 = phi i1 [ false, %L2 ], [ %v19, %L8 ]
  br i1 %v20, label %L3, label %L4
L3:
  %v21 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v22 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v23 = load i32, ptr %v22
  %v24 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v23, i32 1)
  %v25 = extractvalue { i32, i1 } %v24, 0
  %v26 = extractvalue { i32, i1 } %v24, 1
  %v27 = icmp eq i32 %v25, -2147483648
  %v28 = or i1 %v26, %v27
  br i1 %v28, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s102)
  unreachable
L10:
  store i32 %v25, ptr %v21
  br label %L2
L4:
  %v29 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 2
  %v30 = load ptr, ptr %v29
  %v31 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v32 = load i32, ptr %v31
  %v33 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v32, i32 1)
  %v34 = extractvalue { i32, i1 } %v33, 0
  %v35 = extractvalue { i32, i1 } %v33, 1
  %v36 = icmp eq i32 %v34, -2147483648
  %v37 = or i1 %v35, %v36
  br i1 %v37, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s103)
  unreachable
L12:
  store i32 %v34, ptr %v30
  %v38 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 3
  %v39 = load ptr, ptr %v38
  %v40 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v41 = load i32, ptr %v40
  store i32 %v41, ptr %v39
  %v42 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 5
  %v43 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 4
  %v44 = load i32, ptr %v43
  store i32 1, ptr %v42
  br label %L13
L13:
  %v45 = load i32, ptr %v42
  %v46 = icmp sle i32 %v45, %v44
  br i1 %v46, label %L14, label %L16
L14:
  %v47 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 1
  %v48 = getelementptr inbounds %frame15, ptr %frame, i32 0, i32 5
  %v49 = load i32, ptr %v48
  %v50 = icmp slt i32 %v49, 1
  %v51 = icmp sgt i32 %v49, 9
  %v52 = or i1 %v50, %v51
  br i1 %v52, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s104)
  unreachable
L19:
  %v53 = sub i32 %v49, 1
  %v54 = getelementptr inbounds [9 x i8], ptr %v47, i32 0, i32 %v53
  %v55 = load i8, ptr %v54
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v55)
  br label %L17
L17:
  %v56 = load i32, ptr %v42
  %v57 = icmp eq i32 %v56, %v44
  br i1 %v57, label %L16, label %L15
L15:
  %v58 = add i32 %v56, 1
  store i32 %v58, ptr %v42
  br label %L13
L16:
  ret void
}

; internwide 3289
define void @p.aptypes.internwide(ptr %link, ptr %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame16
  %v2 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v3, ptr align 1 %a0, i64 16, i1 false)
  %v4 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  store i32 16, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v8 = load i32, ptr %v7
  %v9 = icmp sgt i32 %v8, 0
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 1
  %v11 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v12 = load i32, ptr %v11
  %v13 = icmp slt i32 %v12, 1
  %v14 = icmp sgt i32 %v12, 16
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s105)
  unreachable
L8:
  %v16 = sub i32 %v12, 1
  %v17 = getelementptr inbounds [16 x i8], ptr %v10, i32 0, i32 %v16
  %v18 = load i8, ptr %v17
  %v19 = icmp eq i8 %v18, 32
  br label %L6
L6:
  %v20 = phi i1 [ false, %L2 ], [ %v19, %L8 ]
  br i1 %v20, label %L3, label %L4
L3:
  %v21 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v22 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v23 = load i32, ptr %v22
  %v24 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v23, i32 1)
  %v25 = extractvalue { i32, i1 } %v24, 0
  %v26 = extractvalue { i32, i1 } %v24, 1
  %v27 = icmp eq i32 %v25, -2147483648
  %v28 = or i1 %v26, %v27
  br i1 %v28, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s106)
  unreachable
L10:
  store i32 %v25, ptr %v21
  br label %L2
L4:
  %v29 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 2
  %v30 = load ptr, ptr %v29
  %v31 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v32 = load i32, ptr %v31
  %v33 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v32, i32 1)
  %v34 = extractvalue { i32, i1 } %v33, 0
  %v35 = extractvalue { i32, i1 } %v33, 1
  %v36 = icmp eq i32 %v34, -2147483648
  %v37 = or i1 %v35, %v36
  br i1 %v37, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s107)
  unreachable
L12:
  store i32 %v34, ptr %v30
  %v38 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 3
  %v39 = load ptr, ptr %v38
  %v40 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v41 = load i32, ptr %v40
  store i32 %v41, ptr %v39
  %v42 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 5
  %v43 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 4
  %v44 = load i32, ptr %v43
  store i32 1, ptr %v42
  br label %L13
L13:
  %v45 = load i32, ptr %v42
  %v46 = icmp sle i32 %v45, %v44
  br i1 %v46, label %L14, label %L16
L14:
  %v47 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 1
  %v48 = getelementptr inbounds %frame16, ptr %frame, i32 0, i32 5
  %v49 = load i32, ptr %v48
  %v50 = icmp slt i32 %v49, 1
  %v51 = icmp sgt i32 %v49, 16
  %v52 = or i1 %v50, %v51
  br i1 %v52, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s108)
  unreachable
L19:
  %v53 = sub i32 %v49, 1
  %v54 = getelementptr inbounds [16 x i8], ptr %v47, i32 0, i32 %v53
  %v55 = load i8, ptr %v54
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v55)
  br label %L17
L17:
  %v56 = load i32, ptr %v42
  %v57 = icmp eq i32 %v56, %v44
  br i1 %v57, label %L16, label %L15
L15:
  %v58 = add i32 %v56, 1
  store i32 %v58, ptr %v42
  br label %L13
L16:
  ret void
}

; internwide2 3303
define void @p.aptypes.internwide2(ptr %link, ptr %a0, ptr %a1, ptr %a2, ptr %a3) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame17
  %v2 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v3, ptr align 1 %a0, i64 16, i1 false)
  %v4 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 2
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %v4, ptr align 1 %a1, i64 16, i1 false)
  %v5 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  store ptr %a3, ptr %v6
  %v7 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 3
  %v8 = load ptr, ptr %v7
  %v9 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v10 = load i32, ptr %v9
  %v11 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v10, i32 1)
  %v12 = extractvalue { i32, i1 } %v11, 0
  %v13 = extractvalue { i32, i1 } %v11, 1
  %v14 = icmp eq i32 %v12, -2147483648
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s109)
  unreachable
L3:
  store i32 %v12, ptr %v8
  %v16 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  %v17 = load ptr, ptr %v16
  store i32 0, ptr %v17
  %v18 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  store i32 16, ptr %v18
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v20 = load i32, ptr %v19
  %v21 = icmp sgt i32 %v20, 0
  br i1 %v21, label %L7, label %L8
L7:
  %v22 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 1
  %v23 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v24 = load i32, ptr %v23
  %v25 = icmp slt i32 %v24, 1
  %v26 = icmp sgt i32 %v24, 16
  %v27 = or i1 %v25, %v26
  br i1 %v27, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s110)
  unreachable
L10:
  %v28 = sub i32 %v24, 1
  %v29 = getelementptr inbounds [16 x i8], ptr %v22, i32 0, i32 %v28
  %v30 = load i8, ptr %v29
  %v31 = icmp eq i8 %v30, 32
  br label %L8
L8:
  %v32 = phi i1 [ false, %L4 ], [ %v31, %L10 ]
  br i1 %v32, label %L5, label %L6
L5:
  %v33 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v34 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v35 = load i32, ptr %v34
  %v36 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v35, i32 1)
  %v37 = extractvalue { i32, i1 } %v36, 0
  %v38 = extractvalue { i32, i1 } %v36, 1
  %v39 = icmp eq i32 %v37, -2147483648
  %v40 = or i1 %v38, %v39
  br i1 %v40, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s111)
  unreachable
L12:
  store i32 %v37, ptr %v33
  br label %L4
L6:
  %v41 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 6
  %v42 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v43 = load i32, ptr %v42
  store i32 1, ptr %v41
  br label %L13
L13:
  %v44 = load i32, ptr %v41
  %v45 = icmp sle i32 %v44, %v43
  br i1 %v45, label %L14, label %L16
L14:
  %v46 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 1
  %v47 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 6
  %v48 = load i32, ptr %v47
  %v49 = icmp slt i32 %v48, 1
  %v50 = icmp sgt i32 %v48, 16
  %v51 = or i1 %v49, %v50
  br i1 %v51, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s112)
  unreachable
L19:
  %v52 = sub i32 %v48, 1
  %v53 = getelementptr inbounds [16 x i8], ptr %v46, i32 0, i32 %v52
  %v54 = load i8, ptr %v53
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v54)
  br label %L17
L17:
  %v55 = load i32, ptr %v41
  %v56 = icmp eq i32 %v55, %v43
  br i1 %v56, label %L16, label %L15
L15:
  %v57 = add i32 %v55, 1
  store i32 %v57, ptr %v41
  br label %L13
L16:
  %v58 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  %v59 = load ptr, ptr %v58
  %v60 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  %v61 = load ptr, ptr %v60
  %v62 = load i32, ptr %v61
  %v63 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v64 = load i32, ptr %v63
  %v65 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v62, i32 %v64)
  %v66 = extractvalue { i32, i1 } %v65, 0
  %v67 = extractvalue { i32, i1 } %v65, 1
  %v68 = icmp eq i32 %v66, -2147483648
  %v69 = or i1 %v67, %v68
  br i1 %v69, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s113)
  unreachable
L21:
  store i32 %v66, ptr %v59
  %v70 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  store i32 16, ptr %v70
  br label %L22
L22:
  %v71 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v72 = load i32, ptr %v71
  %v73 = icmp sgt i32 %v72, 0
  br i1 %v73, label %L25, label %L26
L25:
  %v74 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 2
  %v75 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v76 = load i32, ptr %v75
  %v77 = icmp slt i32 %v76, 1
  %v78 = icmp sgt i32 %v76, 16
  %v79 = or i1 %v77, %v78
  br i1 %v79, label %L27, label %L28
L27:
  call void @pas_runtime_error(ptr @s114)
  unreachable
L28:
  %v80 = sub i32 %v76, 1
  %v81 = getelementptr inbounds [16 x i8], ptr %v74, i32 0, i32 %v80
  %v82 = load i8, ptr %v81
  %v83 = icmp eq i8 %v82, 32
  br label %L26
L26:
  %v84 = phi i1 [ false, %L22 ], [ %v83, %L28 ]
  br i1 %v84, label %L23, label %L24
L23:
  %v85 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v86 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v87 = load i32, ptr %v86
  %v88 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v87, i32 1)
  %v89 = extractvalue { i32, i1 } %v88, 0
  %v90 = extractvalue { i32, i1 } %v88, 1
  %v91 = icmp eq i32 %v89, -2147483648
  %v92 = or i1 %v90, %v91
  br i1 %v92, label %L29, label %L30
L29:
  call void @pas_runtime_error(ptr @s115)
  unreachable
L30:
  store i32 %v89, ptr %v85
  br label %L22
L24:
  %v93 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 6
  %v94 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v95 = load i32, ptr %v94
  store i32 1, ptr %v93
  br label %L31
L31:
  %v96 = load i32, ptr %v93
  %v97 = icmp sle i32 %v96, %v95
  br i1 %v97, label %L32, label %L34
L32:
  %v98 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 2
  %v99 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 6
  %v100 = load i32, ptr %v99
  %v101 = icmp slt i32 %v100, 1
  %v102 = icmp sgt i32 %v100, 16
  %v103 = or i1 %v101, %v102
  br i1 %v103, label %L36, label %L37
L36:
  call void @pas_runtime_error(ptr @s116)
  unreachable
L37:
  %v104 = sub i32 %v100, 1
  %v105 = getelementptr inbounds [16 x i8], ptr %v98, i32 0, i32 %v104
  %v106 = load i8, ptr %v105
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v106)
  br label %L35
L35:
  %v107 = load i32, ptr %v93
  %v108 = icmp eq i32 %v107, %v95
  br i1 %v108, label %L34, label %L33
L33:
  %v109 = add i32 %v107, 1
  store i32 %v109, ptr %v93
  br label %L31
L34:
  %v110 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  %v111 = load ptr, ptr %v110
  %v112 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 4
  %v113 = load ptr, ptr %v112
  %v114 = load i32, ptr %v113
  %v115 = getelementptr inbounds %frame17, ptr %frame, i32 0, i32 5
  %v116 = load i32, ptr %v115
  %v117 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v114, i32 %v116)
  %v118 = extractvalue { i32, i1 } %v117, 0
  %v119 = extractvalue { i32, i1 } %v117, 1
  %v120 = icmp eq i32 %v118, -2147483648
  %v121 = or i1 %v119, %v120
  br i1 %v121, label %L38, label %L39
L38:
  call void @pas_runtime_error(ptr @s117)
  unreachable
L39:
  store i32 %v118, ptr %v111
  ret void
}

; internresultname 3322
define void @p.aptypes.internresultname(ptr %link, i32 %a0, i32 %a1, ptr %a2, ptr %a3) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame18
  %v2 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 4
  store ptr %a3, ptr %v6
  %v7 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 3
  %v8 = load ptr, ptr %v7
  %v9 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v10 = load i32, ptr %v9
  %v11 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v10, i32 1)
  %v12 = extractvalue { i32, i1 } %v11, 0
  %v13 = extractvalue { i32, i1 } %v11, 1
  %v14 = icmp eq i32 %v12, -2147483648
  %v15 = or i1 %v13, %v14
  br i1 %v15, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s118)
  unreachable
L3:
  store i32 %v12, ptr %v8
  %v16 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 5
  %v17 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 2
  %v18 = load i32, ptr %v17
  %v19 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v18, i32 1)
  %v20 = extractvalue { i32, i1 } %v19, 0
  %v21 = extractvalue { i32, i1 } %v19, 1
  %v22 = icmp eq i32 %v20, -2147483648
  %v23 = or i1 %v21, %v22
  br i1 %v23, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s119)
  unreachable
L5:
  store i32 0, ptr %v16
  br label %L6
L6:
  %v24 = load i32, ptr %v16
  %v25 = icmp sle i32 %v24, %v20
  br i1 %v25, label %L7, label %L9
L7:
  %v26 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 4
  %v27 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 1
  %v28 = load i32, ptr %v27
  %v29 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 5
  %v30 = load i32, ptr %v29
  %v31 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v28, i32 %v30)
  %v32 = extractvalue { i32, i1 } %v31, 0
  %v33 = extractvalue { i32, i1 } %v31, 1
  %v34 = icmp eq i32 %v32, -2147483648
  %v35 = or i1 %v33, %v34
  br i1 %v35, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s120)
  unreachable
L12:
  %v36 = icmp slt i32 %v32, 1
  %v37 = icmp sgt i32 %v32, 1000000
  %v38 = or i1 %v36, %v37
  br i1 %v38, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s121)
  unreachable
L14:
  %v39 = sub i32 %v32, 1
  %v40 = getelementptr inbounds [1000000 x i8], ptr %v26, i32 0, i32 %v39
  %v41 = load i8, ptr %v40
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v41)
  br label %L10
L10:
  %v42 = load i32, ptr %v16
  %v43 = icmp eq i32 %v42, %v20
  br i1 %v43, label %L9, label %L8
L8:
  %v44 = add i32 %v42, 1
  store i32 %v44, ptr %v16
  br label %L6
L9:
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 114)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 101)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 115)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 117)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 108)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 116)
  %v45 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 4
  %v46 = load ptr, ptr %v45
  %v47 = getelementptr inbounds %frame18, ptr %frame, i32 0, i32 2
  %v48 = load i32, ptr %v47
  %v49 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v48, i32 7)
  %v50 = extractvalue { i32, i1 } %v49, 0
  %v51 = extractvalue { i32, i1 } %v49, 1
  %v52 = icmp eq i32 %v50, -2147483648
  %v53 = or i1 %v51, %v52
  br i1 %v53, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s122)
  unreachable
L16:
  store i32 %v50, ptr %v46
  ret void
}

; internbindingname 3335
define void @p.aptypes.internbindingname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame19
  %v2 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s123)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 98)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 105)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 110)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 100)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 105)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 110)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 103)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s124)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s125)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s126)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s127)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s128)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s129)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s130)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s131)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v83, i32 1)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s132)
  unreachable
L29:
  %v89 = getelementptr inbounds %frame19, ptr %frame, i32 0, i32 2
  %v90 = load ptr, ptr %v89
  %v91 = load i32, ptr %v90
  %v92 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v85, i32 %v91)
  %v93 = extractvalue { i32, i1 } %v92, 0
  %v94 = extractvalue { i32, i1 } %v92, 1
  %v95 = icmp eq i32 %v93, -2147483648
  %v96 = or i1 %v94, %v95
  br i1 %v96, label %L30, label %L31
L30:
  call void @pas_runtime_error(ptr @s133)
  unreachable
L31:
  store i32 %v93, ptr %v81
  ret void
}

; interncallresultname 3354
define void @p.aptypes.interncallresultname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame20
  %v2 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s134)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 114)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 101)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 115)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 117)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 108)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 116)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s135)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s136)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s137)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s138)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s139)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s140)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s141)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s142)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v83, i32 1)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s143)
  unreachable
L29:
  %v89 = getelementptr inbounds %frame20, ptr %frame, i32 0, i32 2
  %v90 = load ptr, ptr %v89
  %v91 = load i32, ptr %v90
  %v92 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v85, i32 %v91)
  %v93 = extractvalue { i32, i1 } %v92, 0
  %v94 = extractvalue { i32, i1 } %v92, 1
  %v95 = icmp eq i32 %v93, -2147483648
  %v96 = or i1 %v94, %v95
  br i1 %v96, label %L30, label %L31
L30:
  call void @pas_runtime_error(ptr @s144)
  unreachable
L31:
  store i32 %v93, ptr %v81
  ret void
}

; interntryname 3375
define void @p.aptypes.interntryname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame21
  %v2 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s145)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 116)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 114)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 121)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s146)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s147)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s148)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s149)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s150)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s151)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s152)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s153)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame21, ptr %frame, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 4, i32 %v83)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s154)
  unreachable
L29:
  store i32 %v85, ptr %v81
  ret void
}

; internwithname 3391
define void @p.aptypes.internwithname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame22
  %v2 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s155)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 119)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 105)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 116)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 104)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s156)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s157)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s158)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s159)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s160)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s161)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s162)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s163)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame22, ptr %frame, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 5, i32 %v83)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s164)
  unreachable
L29:
  store i32 %v85, ptr %v81
  ret void
}

; internboundsname 3417
define void @p.aptypes.internboundsname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame23
  %v2 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s165)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 98)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 110)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 100)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s166)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s167)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s168)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s169)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s170)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s171)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s172)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s173)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame23, ptr %frame, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 4, i32 %v83)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s174)
  unreachable
L29:
  store i32 %v85, ptr %v81
  ret void
}

; internforname 3433
define void @p.aptypes.internforname(ptr %link, i32 %a0, ptr %a1, ptr %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame24
  %v2 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 3
  store ptr %a2, ptr %v5
  %v6 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 5
  %v9 = load i32, ptr %v8
  %v10 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v9, i32 1)
  %v11 = extractvalue { i32, i1 } %v10, 0
  %v12 = extractvalue { i32, i1 } %v10, 1
  %v13 = icmp eq i32 %v11, -2147483648
  %v14 = or i1 %v12, %v13
  br i1 %v14, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s175)
  unreachable
L3:
  store i32 %v11, ptr %v7
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 102)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 111)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 114)
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 36)
  %v15 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v15
  %v16 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 6
  %v17 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 1
  %v18 = load i32, ptr %v17
  store i32 %v18, ptr %v16
  br label %L4
L4:
  %v19 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  %v20 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  %v21 = load i32, ptr %v20
  %v22 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v21, i32 1)
  %v23 = extractvalue { i32, i1 } %v22, 0
  %v24 = extractvalue { i32, i1 } %v22, 1
  %v25 = icmp eq i32 %v23, -2147483648
  %v26 = or i1 %v24, %v25
  br i1 %v26, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s176)
  unreachable
L8:
  store i32 %v23, ptr %v19
  %v27 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 4
  %v28 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  %v29 = load i32, ptr %v28
  %v30 = icmp slt i32 %v29, 1
  %v31 = icmp sgt i32 %v29, 12
  %v32 = or i1 %v30, %v31
  br i1 %v32, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s177)
  unreachable
L10:
  %v33 = sub i32 %v29, 1
  %v34 = getelementptr inbounds [12 x i8], ptr %v27, i32 0, i32 %v33
  %v35 = zext i8 48 to i32
  %v36 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 6
  %v37 = load i32, ptr %v36
  %v38 = icmp sle i32 10, 0
  br i1 %v38, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s178)
  unreachable
L12:
  %v39 = srem i32 %v37, 10
  %v40 = icmp slt i32 %v39, 0
  %v41 = add i32 %v39, 10
  %v42 = select i1 %v40, i32 %v41, i32 %v39
  %v43 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v35, i32 %v42)
  %v44 = extractvalue { i32, i1 } %v43, 0
  %v45 = extractvalue { i32, i1 } %v43, 1
  %v46 = icmp eq i32 %v44, -2147483648
  %v47 = or i1 %v45, %v46
  br i1 %v47, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s179)
  unreachable
L14:
  %v48 = icmp slt i32 %v44, 0
  %v49 = icmp sgt i32 %v44, 255
  %v50 = or i1 %v48, %v49
  br i1 %v50, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s180)
  unreachable
L16:
  %v51 = trunc i32 %v44 to i8
  store i8 %v51, ptr %v34
  %v52 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 6
  %v53 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 6
  %v54 = load i32, ptr %v53
  %v55 = icmp eq i32 10, 0
  br i1 %v55, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s181)
  unreachable
L18:
  %v56 = icmp eq i32 %v54, -2147483648
  %v57 = icmp eq i32 10, -1
  %v58 = and i1 %v56, %v57
  br i1 %v58, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s182)
  unreachable
L20:
  %v59 = sdiv i32 %v54, 10
  store i32 %v59, ptr %v52
  br label %L5
L5:
  %v60 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 6
  %v61 = load i32, ptr %v60
  %v62 = icmp eq i32 %v61, 0
  br i1 %v62, label %L6, label %L4
L6:
  %v63 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 7
  %v64 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  %v65 = load i32, ptr %v64
  store i32 %v65, ptr %v63
  br label %L21
L21:
  %v66 = load i32, ptr %v63
  %v67 = icmp sge i32 %v66, 1
  br i1 %v67, label %L22, label %L24
L22:
  %v68 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 4
  %v69 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 7
  %v70 = load i32, ptr %v69
  %v71 = icmp slt i32 %v70, 1
  %v72 = icmp sgt i32 %v70, 12
  %v73 = or i1 %v71, %v72
  br i1 %v73, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s183)
  unreachable
L27:
  %v74 = sub i32 %v70, 1
  %v75 = getelementptr inbounds [12 x i8], ptr %v68, i32 0, i32 %v74
  %v76 = load i8, ptr %v75
  call void @p.aptypes.poolput(ptr @frame.aptypes, i8 %v76)
  br label %L25
L25:
  %v77 = load i32, ptr %v63
  %v78 = icmp eq i32 %v77, 1
  br i1 %v78, label %L24, label %L23
L23:
  %v79 = sub i32 %v77, 1
  store i32 %v79, ptr %v63
  br label %L21
L24:
  %v80 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 3
  %v81 = load ptr, ptr %v80
  %v82 = getelementptr inbounds %frame24, ptr %frame, i32 0, i32 5
  %v83 = load i32, ptr %v82
  %v84 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 4, i32 %v83)
  %v85 = extractvalue { i32, i1 } %v84, 0
  %v86 = extractvalue { i32, i1 } %v84, 1
  %v87 = icmp eq i32 %v85, -2147483648
  %v88 = or i1 %v86, %v87
  br i1 %v88, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s184)
  unreachable
L29:
  store i32 %v85, ptr %v81
  ret void
}

; newtype 3462
define ptr @p.aptypes.newtype(ptr %link, i32 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame25
  %v2 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v5 = call ptr @pas_new(i64 232)
  store ptr %v5, ptr %v4
  %v6 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v7 = load ptr, ptr %v6
  %v8 = icmp eq ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s185)
  unreachable
L3:
  %v9 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v7, i32 0, i32 0
  %v10 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 1
  %v11 = load i32, ptr %v10
  store i32 %v11, ptr %v9
  %v12 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s186)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 1
  store ptr null, ptr %v15
  %v16 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v17 = load ptr, ptr %v16
  %v18 = icmp eq ptr %v17, null
  br i1 %v18, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s187)
  unreachable
L7:
  %v19 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v17, i32 0, i32 5
  store i1 false, ptr %v19
  %v20 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v21 = load ptr, ptr %v20
  %v22 = icmp eq ptr %v21, null
  br i1 %v22, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s188)
  unreachable
L9:
  %v23 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v21, i32 0, i32 2
  store ptr null, ptr %v23
  %v24 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v25 = load ptr, ptr %v24
  %v26 = icmp eq ptr %v25, null
  br i1 %v26, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s189)
  unreachable
L11:
  %v27 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v25, i32 0, i32 3
  store ptr null, ptr %v27
  %v28 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v29 = load ptr, ptr %v28
  %v30 = icmp eq ptr %v29, null
  br i1 %v30, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s190)
  unreachable
L13:
  %v31 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v29, i32 0, i32 4
  store ptr null, ptr %v31
  %v32 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v33 = load ptr, ptr %v32
  %v34 = icmp eq ptr %v33, null
  br i1 %v34, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s191)
  unreachable
L15:
  %v35 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v33, i32 0, i32 6
  store i1 false, ptr %v35
  %v36 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v37 = load ptr, ptr %v36
  %v38 = icmp eq ptr %v37, null
  br i1 %v38, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s192)
  unreachable
L17:
  %v39 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v37, i32 0, i32 7
  store i1 false, ptr %v39
  %v40 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v41 = load ptr, ptr %v40
  %v42 = icmp eq ptr %v41, null
  br i1 %v42, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s193)
  unreachable
L19:
  %v43 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v41, i32 0, i32 8
  store i1 false, ptr %v43
  %v44 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v45 = load ptr, ptr %v44
  %v46 = icmp eq ptr %v45, null
  br i1 %v46, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s194)
  unreachable
L21:
  %v47 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v45, i32 0, i32 9
  store i32 0, ptr %v47
  %v48 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v49 = load ptr, ptr %v48
  %v50 = icmp eq ptr %v49, null
  br i1 %v50, label %L22, label %L23
L22:
  call void @pas_runtime_error(ptr @s195)
  unreachable
L23:
  %v51 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v49, i32 0, i32 10
  %v52 = sub nsw i32 0, 1
  store i32 %v52, ptr %v51
  %v53 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v54 = load ptr, ptr %v53
  %v55 = icmp eq ptr %v54, null
  br i1 %v55, label %L24, label %L25
L24:
  call void @pas_runtime_error(ptr @s196)
  unreachable
L25:
  %v56 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v54, i32 0, i32 11
  store ptr null, ptr %v56
  %v57 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v58 = load ptr, ptr %v57
  %v59 = icmp eq ptr %v58, null
  br i1 %v59, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s197)
  unreachable
L27:
  %v60 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v58, i32 0, i32 12
  store ptr null, ptr %v60
  %v61 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v62 = load ptr, ptr %v61
  %v63 = icmp eq ptr %v62, null
  br i1 %v63, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s198)
  unreachable
L29:
  %v64 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v62, i32 0, i32 13
  store ptr null, ptr %v64
  %v65 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v66 = load ptr, ptr %v65
  %v67 = icmp eq ptr %v66, null
  br i1 %v67, label %L30, label %L31
L30:
  call void @pas_runtime_error(ptr @s199)
  unreachable
L31:
  %v68 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v66, i32 0, i32 14
  store ptr null, ptr %v68
  %v69 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v70 = load ptr, ptr %v69
  %v71 = icmp eq ptr %v70, null
  br i1 %v71, label %L32, label %L33
L32:
  call void @pas_runtime_error(ptr @s200)
  unreachable
L33:
  %v72 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v70, i32 0, i32 15
  store ptr null, ptr %v72
  %v73 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v74 = load ptr, ptr %v73
  %v75 = icmp eq ptr %v74, null
  br i1 %v75, label %L34, label %L35
L34:
  call void @pas_runtime_error(ptr @s201)
  unreachable
L35:
  %v76 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v74, i32 0, i32 16
  store ptr null, ptr %v76
  %v77 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v78 = load ptr, ptr %v77
  %v79 = icmp eq ptr %v78, null
  br i1 %v79, label %L36, label %L37
L36:
  call void @pas_runtime_error(ptr @s202)
  unreachable
L37:
  %v80 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v78, i32 0, i32 22
  store i1 false, ptr %v80
  %v81 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v82 = load ptr, ptr %v81
  %v83 = icmp eq ptr %v82, null
  br i1 %v83, label %L38, label %L39
L38:
  call void @pas_runtime_error(ptr @s203)
  unreachable
L39:
  %v84 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v82, i32 0, i32 17
  store i1 false, ptr %v84
  %v85 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v86 = load ptr, ptr %v85
  %v87 = icmp eq ptr %v86, null
  br i1 %v87, label %L40, label %L41
L40:
  call void @pas_runtime_error(ptr @s204)
  unreachable
L41:
  %v88 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v86, i32 0, i32 20
  store i1 false, ptr %v88
  %v89 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v90 = load ptr, ptr %v89
  %v91 = icmp eq ptr %v90, null
  br i1 %v91, label %L42, label %L43
L42:
  call void @pas_runtime_error(ptr @s205)
  unreachable
L43:
  %v92 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v90, i32 0, i32 18
  store ptr null, ptr %v92
  %v93 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v94 = load ptr, ptr %v93
  %v95 = icmp eq ptr %v94, null
  br i1 %v95, label %L44, label %L45
L44:
  call void @pas_runtime_error(ptr @s206)
  unreachable
L45:
  %v96 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v94, i32 0, i32 19
  store ptr null, ptr %v96
  %v97 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v98 = load ptr, ptr %v97
  %v99 = icmp eq ptr %v98, null
  br i1 %v99, label %L46, label %L47
L46:
  call void @pas_runtime_error(ptr @s207)
  unreachable
L47:
  %v100 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v98, i32 0, i32 21
  %v101 = sub nsw i32 0, 1
  store i32 %v101, ptr %v100
  %v102 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v103 = load ptr, ptr %v102
  %v104 = icmp eq ptr %v103, null
  br i1 %v104, label %L48, label %L49
L48:
  call void @pas_runtime_error(ptr @s208)
  unreachable
L49:
  %v105 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v103, i32 0, i32 23
  store i32 0, ptr %v105
  %v106 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v107 = load ptr, ptr %v106
  %v108 = icmp eq ptr %v107, null
  br i1 %v108, label %L50, label %L51
L50:
  call void @pas_runtime_error(ptr @s209)
  unreachable
L51:
  %v109 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v107, i32 0, i32 24
  store i32 0, ptr %v109
  %v110 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v111 = load ptr, ptr %v110
  %v112 = icmp eq ptr %v111, null
  br i1 %v112, label %L52, label %L53
L52:
  call void @pas_runtime_error(ptr @s210)
  unreachable
L53:
  %v113 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v111, i32 0, i32 25
  store i32 0, ptr %v113
  %v114 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v115 = load ptr, ptr %v114
  %v116 = icmp eq ptr %v115, null
  br i1 %v116, label %L54, label %L55
L54:
  call void @pas_runtime_error(ptr @s211)
  unreachable
L55:
  %v117 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v115, i32 0, i32 26
  store i32 0, ptr %v117
  %v118 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v119 = load ptr, ptr %v118
  %v120 = icmp eq ptr %v119, null
  br i1 %v120, label %L56, label %L57
L56:
  call void @pas_runtime_error(ptr @s212)
  unreachable
L57:
  %v121 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v119, i32 0, i32 27
  store i1 false, ptr %v121
  %v122 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v123 = load ptr, ptr %v122
  %v124 = icmp eq ptr %v123, null
  br i1 %v124, label %L58, label %L59
L58:
  call void @pas_runtime_error(ptr @s213)
  unreachable
L59:
  %v125 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v123, i32 0, i32 28
  store ptr null, ptr %v125
  %v126 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v127 = load ptr, ptr %v126
  %v128 = icmp eq ptr %v127, null
  br i1 %v128, label %L60, label %L61
L60:
  call void @pas_runtime_error(ptr @s214)
  unreachable
L61:
  %v129 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v127, i32 0, i32 29
  store ptr null, ptr %v129
  %v130 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v131 = load ptr, ptr %v130
  %v132 = icmp eq ptr %v131, null
  br i1 %v132, label %L62, label %L63
L62:
  call void @pas_runtime_error(ptr @s215)
  unreachable
L63:
  %v133 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v131, i32 0, i32 30
  store ptr null, ptr %v133
  %v134 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v135 = load ptr, ptr %v134
  %v136 = icmp eq ptr %v135, null
  br i1 %v136, label %L64, label %L65
L64:
  call void @pas_runtime_error(ptr @s216)
  unreachable
L65:
  %v137 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v135, i32 0, i32 32
  store ptr null, ptr %v137
  %v138 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v139 = load ptr, ptr %v138
  %v140 = icmp eq ptr %v139, null
  br i1 %v140, label %L66, label %L67
L66:
  call void @pas_runtime_error(ptr @s217)
  unreachable
L67:
  %v141 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v139, i32 0, i32 34
  store i1 false, ptr %v141
  %v142 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v143 = load ptr, ptr %v142
  %v144 = icmp eq ptr %v143, null
  br i1 %v144, label %L68, label %L69
L68:
  call void @pas_runtime_error(ptr @s218)
  unreachable
L69:
  %v145 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v143, i32 0, i32 33
  store ptr null, ptr %v145
  %v146 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v147 = load ptr, ptr %v146
  %v148 = icmp eq ptr %v147, null
  br i1 %v148, label %L70, label %L71
L70:
  call void @pas_runtime_error(ptr @s219)
  unreachable
L71:
  %v149 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v147, i32 0, i32 35
  store i1 false, ptr %v149
  %v150 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v151 = load ptr, ptr %v150
  %v152 = icmp eq ptr %v151, null
  br i1 %v152, label %L72, label %L73
L72:
  call void @pas_runtime_error(ptr @s220)
  unreachable
L73:
  %v153 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v151, i32 0, i32 36
  store ptr null, ptr %v153
  %v154 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 52
  %v155 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 52
  %v156 = load i32, ptr %v155
  %v157 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v156, i32 1)
  %v158 = extractvalue { i32, i1 } %v157, 0
  %v159 = extractvalue { i32, i1 } %v157, 1
  %v160 = icmp eq i32 %v158, -2147483648
  %v161 = or i1 %v159, %v160
  br i1 %v161, label %L74, label %L75
L74:
  call void @pas_runtime_error(ptr @s221)
  unreachable
L75:
  store i32 %v158, ptr %v154
  %v162 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v163 = load ptr, ptr %v162
  %v164 = icmp eq ptr %v163, null
  br i1 %v164, label %L76, label %L77
L76:
  call void @pas_runtime_error(ptr @s222)
  unreachable
L77:
  %v165 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v163, i32 0, i32 31
  %v166 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 52
  %v167 = load i32, ptr %v166
  store i32 %v167, ptr %v165
  %v168 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v169 = load ptr, ptr %v168
  %v170 = icmp eq ptr %v169, null
  br i1 %v170, label %L78, label %L79
L78:
  call void @pas_runtime_error(ptr @s223)
  unreachable
L79:
  %v171 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v169, i32 0, i32 37
  store ptr null, ptr %v171
  %v172 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 2
  %v173 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 3
  %v174 = load ptr, ptr %v173
  store ptr %v174, ptr %v172
  %v175 = getelementptr inbounds %frame25, ptr %frame, i32 0, i32 2
  %v176 = load ptr, ptr %v175
  ret ptr %v176
}

; base 3512
define ptr @p.aptypes.base(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame26
  %v2 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp ne ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  %v8 = load ptr, ptr %v7
  %v9 = icmp eq ptr %v8, null
  br i1 %v9, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s224)
  unreachable
L5:
  %v10 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v8, i32 0, i32 0
  %v11 = load i32, ptr %v10
  %v12 = icmp eq i32 %v11, 6
  br label %L3
L3:
  %v13 = phi i1 [ false, %L1 ], [ %v12, %L5 ]
  br i1 %v13, label %L6, label %L7
L6:
  %v14 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  %v15 = load ptr, ptr %v14
  %v16 = icmp eq ptr %v15, null
  br i1 %v16, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s225)
  unreachable
L9:
  %v17 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v15, i32 0, i32 3
  %v18 = load ptr, ptr %v17
  %v19 = icmp ne ptr %v18, null
  br label %L7
L7:
  %v20 = phi i1 [ false, %L3 ], [ %v19, %L9 ]
  br i1 %v20, label %L10, label %L11
L10:
  %v21 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 2
  %v22 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  %v23 = load ptr, ptr %v22
  %v24 = icmp eq ptr %v23, null
  br i1 %v24, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s226)
  unreachable
L14:
  %v25 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v23, i32 0, i32 3
  %v26 = load ptr, ptr %v25
  store ptr %v26, ptr %v21
  br label %L12
L11:
  %v27 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 2
  %v28 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 1
  %v29 = load ptr, ptr %v28
  store ptr %v29, ptr %v27
  br label %L12
L12:
  %v30 = getelementptr inbounds %frame26, ptr %frame, i32 0, i32 2
  %v31 = load ptr, ptr %v30
  ret ptr %v31
}

; isinteger 3527
define i1 @p.aptypes.isinteger(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame27
  %v2 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v6)
  store ptr %v7, ptr %v4
  %v8 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 2
  %v9 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 3
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br i1 %v11, label %L2, label %L3
L2:
  %v12 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s227)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 0
  %v16 = load i32, ptr %v15
  %v17 = icmp eq i32 %v16, 1
  br label %L3
L3:
  %v18 = phi i1 [ false, %L1 ], [ %v17, %L5 ]
  store i1 %v18, ptr %v8
  %v19 = getelementptr inbounds %frame27, ptr %frame, i32 0, i32 2
  %v20 = load i1, ptr %v19
  ret i1 %v20
}

; isreal 3534
define i1 @p.aptypes.isreal(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame28
  %v2 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s228)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 2
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame28, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isint64 3540
define i1 @p.aptypes.isint64(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame29
  %v2 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s229)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 20
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame29, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; iscomplex 3543
define i1 @p.aptypes.iscomplex(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame30
  %v2 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s230)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 13
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame30, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isvarstring 3548
define i1 @p.aptypes.isvarstring(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame31
  %v2 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s231)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 18
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame31, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; istext 3553
define i1 @p.aptypes.istext(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame32
  %v2 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s232)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 19
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame32, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isstringrep 3567
define i1 @p.aptypes.isstringrep(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame33
  %v2 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s233)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 18
  br i1 %v13, label %L7, label %L6
L6:
  %v14 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 1
  %v15 = load ptr, ptr %v14
  %v16 = icmp eq ptr %v15, null
  br i1 %v16, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s234)
  unreachable
L9:
  %v17 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v15, i32 0, i32 0
  %v18 = load i32, ptr %v17
  %v19 = icmp eq i32 %v18, 19
  br label %L7
L7:
  %v20 = phi i1 [ true, %L5 ], [ %v19, %L9 ]
  br label %L3
L3:
  %v21 = phi i1 [ false, %L1 ], [ %v20, %L7 ]
  store i1 %v21, ptr %v4
  %v22 = getelementptr inbounds %frame33, ptr %frame, i32 0, i32 2
  %v23 = load i1, ptr %v22
  ret i1 %v23
}

; isoptional 3573
define i1 @p.aptypes.isoptional(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame34
  %v2 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s235)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 16
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame34, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isfallible 3580
define i1 @p.aptypes.isfallible(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame35
  %v2 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s236)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 8
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  br i1 %v14, label %L6, label %L7
L6:
  %v15 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = icmp eq ptr %v16, null
  br i1 %v17, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s237)
  unreachable
L9:
  %v18 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v16, i32 0, i32 17
  %v19 = load i1, ptr %v18
  br label %L7
L7:
  %v20 = phi i1 [ false, %L3 ], [ %v19, %L9 ]
  store i1 %v20, ptr %v4
  %v21 = getelementptr inbounds %frame35, ptr %frame, i32 0, i32 2
  %v22 = load i1, ptr %v21
  ret i1 %v22
}

; ishandlebirth 3583
define i1 @p.aptypes.ishandlebirth(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame36
  %v2 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.ishandle(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isfallible(ptr @frame.aptypes, ptr %v9)
  br i1 %v10, label %L4, label %L5
L4:
  %v11 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s238)
  unreachable
L7:
  %v14 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v12, i32 0, i32 18
  %v15 = load ptr, ptr %v14
  %v16 = call i1 @p.aptypes.ishandle(ptr @frame.aptypes, ptr %v15)
  br label %L5
L5:
  %v17 = phi i1 [ false, %L2 ], [ %v16, %L7 ]
  br label %L3
L3:
  %v18 = phi i1 [ true, %L1 ], [ %v17, %L5 ]
  store i1 %v18, ptr %v4
  %v19 = getelementptr inbounds %frame36, ptr %frame, i32 0, i32 2
  %v20 = load i1, ptr %v19
  ret i1 %v20
}

; isslice 3592
define i1 @p.aptypes.isslice(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame37
  %v2 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s239)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 15
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame37, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; sliceof 3600
define ptr @p.aptypes.sliceof(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame38
  %v2 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 3
  %v5 = call ptr @p.aptypes.newtype(ptr @frame.aptypes, i32 15)
  store ptr %v5, ptr %v4
  %v6 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 3
  %v7 = load ptr, ptr %v6
  %v8 = icmp eq ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s240)
  unreachable
L3:
  %v9 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v7, i32 0, i32 1
  %v10 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 1
  %v11 = load ptr, ptr %v10
  store ptr %v11, ptr %v9
  %v12 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s241)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 9
  store i32 1, ptr %v15
  %v16 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 2
  %v17 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 3
  %v18 = load ptr, ptr %v17
  store ptr %v18, ptr %v16
  %v19 = getelementptr inbounds %frame38, ptr %frame, i32 0, i32 2
  %v20 = load ptr, ptr %v19
  ret ptr %v20
}

; isnumeric 3609
define i1 @p.aptypes.isnumeric(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame39
  %v2 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isinteger(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isint64(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  br i1 %v11, label %L5, label %L4
L4:
  %v12 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 1
  %v13 = load ptr, ptr %v12
  %v14 = call i1 @p.aptypes.isreal(ptr @frame.aptypes, ptr %v13)
  br label %L5
L5:
  %v15 = phi i1 [ true, %L3 ], [ %v14, %L4 ]
  store i1 %v15, ptr %v4
  %v16 = getelementptr inbounds %frame39, ptr %frame, i32 0, i32 2
  %v17 = load i1, ptr %v16
  ret i1 %v17
}

; isarith 3616
define i1 @p.aptypes.isarith(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame40
  %v2 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isnumeric(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.iscomplex(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  store i1 %v11, ptr %v4
  %v12 = getelementptr inbounds %frame40, ptr %frame, i32 0, i32 2
  %v13 = load i1, ptr %v12
  ret i1 %v13
}

; isboolean 3619
define i1 @p.aptypes.isboolean(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame41
  %v2 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v6)
  store ptr %v7, ptr %v4
  %v8 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 2
  %v9 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 3
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br i1 %v11, label %L2, label %L3
L2:
  %v12 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s242)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 0
  %v16 = load i32, ptr %v15
  %v17 = icmp eq i32 %v16, 3
  br label %L3
L3:
  %v18 = phi i1 [ false, %L1 ], [ %v17, %L5 ]
  store i1 %v18, ptr %v8
  %v19 = getelementptr inbounds %frame41, ptr %frame, i32 0, i32 2
  %v20 = load i1, ptr %v19
  ret i1 %v20
}

; ischar 3626
define i1 @p.aptypes.ischar(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame42
  %v2 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v6)
  store ptr %v7, ptr %v4
  %v8 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 2
  %v9 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 3
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br i1 %v11, label %L2, label %L3
L2:
  %v12 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s243)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 0
  %v16 = load i32, ptr %v15
  %v17 = icmp eq i32 %v16, 4
  br label %L3
L3:
  %v18 = phi i1 [ false, %L1 ], [ %v17, %L5 ]
  store i1 %v18, ptr %v8
  %v19 = getelementptr inbounds %frame42, ptr %frame, i32 0, i32 2
  %v20 = load i1, ptr %v19
  ret i1 %v20
}

; isenum 3633
define i1 @p.aptypes.isenum(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame43
  %v2 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v6)
  store ptr %v7, ptr %v4
  %v8 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 2
  %v9 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 3
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br i1 %v11, label %L2, label %L3
L2:
  %v12 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 3
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s244)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 0
  %v16 = load i32, ptr %v15
  %v17 = icmp eq i32 %v16, 5
  br label %L3
L3:
  %v18 = phi i1 [ false, %L1 ], [ %v17, %L5 ]
  store i1 %v18, ptr %v8
  %v19 = getelementptr inbounds %frame43, ptr %frame, i32 0, i32 2
  %v20 = load i1, ptr %v19
  ret i1 %v20
}

; isarray 3640
define i1 @p.aptypes.isarray(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame44
  %v2 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s245)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 7
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame44, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isrecord 3643
define i1 @p.aptypes.isrecord(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame45
  %v2 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s246)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 8
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame45, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; ispointer 3646
define i1 @p.aptypes.ispointer(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame46
  %v2 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s247)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 9
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame46, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isfile 3649
define i1 @p.aptypes.isfile(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame47
  %v2 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s248)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 10
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame47, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; ishandle 3656
define i1 @p.aptypes.ishandle(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame48
  %v2 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s249)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 17
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame48, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; ischannel 3659
define i1 @p.aptypes.ischannel(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame49
  %v2 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.ishandle(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s250)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp ne ptr %v12, null
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame49, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isowned 3668
define i1 @p.aptypes.isowned(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame50
  %v2 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isfile(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.ishandle(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  store i1 %v11, ptr %v4
  %v12 = getelementptr inbounds %frame50, ptr %frame, i32 0, i32 2
  %v13 = load i1, ptr %v12
  ret i1 %v13
}

; isownedpointer 3673
define i1 @p.aptypes.isownedpointer(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame51
  %v2 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.ispointer(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s251)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 27
  %v12 = load i1, ptr %v11
  br label %L3
L3:
  %v13 = phi i1 [ false, %L1 ], [ %v12, %L5 ]
  store i1 %v13, ptr %v4
  %v14 = getelementptr inbounds %frame51, ptr %frame, i32 0, i32 2
  %v15 = load i1, ptr %v14
  ret i1 %v15
}

; isaffine 3681
define i1 @p.aptypes.isaffine(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame52
  %v2 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isowned(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isownedpointer(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  store i1 %v11, ptr %v4
  %v12 = getelementptr inbounds %frame52, ptr %frame, i32 0, i32 2
  %v13 = load i1, ptr %v12
  ret i1 %v13
}

; istextfile 3685
define i1 @p.aptypes.istextfile(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame53
  %v2 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isfile(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s252)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 8
  %v12 = load i1, ptr %v11
  br label %L3
L3:
  %v13 = phi i1 [ false, %L1 ], [ %v12, %L5 ]
  store i1 %v13, ptr %v4
  %v14 = getelementptr inbounds %frame53, ptr %frame, i32 0, i32 2
  %v15 = load i1, ptr %v14
  ret i1 %v15
}

; isnil 3689
define i1 @p.aptypes.isnil(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame54
  %v2 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.ispointer(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s253)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame54, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isset 3692
define i1 @p.aptypes.isset(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame55
  %v2 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s254)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 11
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame55, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isproctype 3696
define i1 @p.aptypes.isproctype(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame56
  %v2 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s255)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 12
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame56, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isemptyset 3701
define i1 @p.aptypes.isemptyset(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame57
  %v2 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isset(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s256)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame57, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; isrestricted 3710
define i1 @p.aptypes.isrestricted(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame58
  %v2 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp ne ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s257)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 0
  %v12 = load i32, ptr %v11
  %v13 = icmp eq i32 %v12, 14
  br label %L3
L3:
  %v14 = phi i1 [ false, %L1 ], [ %v13, %L5 ]
  store i1 %v14, ptr %v4
  %v15 = getelementptr inbounds %frame58, ptr %frame, i32 0, i32 2
  %v16 = load i1, ptr %v15
  ret i1 %v16
}

; underlying 3715
define ptr @p.aptypes.underlying(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame59
  %v2 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = call i1 @p.aptypes.isrestricted(ptr @frame.aptypes, ptr %v5)
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 2
  %v8 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s258)
  unreachable
L6:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  store ptr %v12, ptr %v7
  br label %L4
L3:
  %v13 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 2
  %v14 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 1
  %v15 = load ptr, ptr %v14
  store ptr %v15, ptr %v13
  br label %L4
L4:
  %v16 = getelementptr inbounds %frame59, ptr %frame, i32 0, i32 2
  %v17 = load ptr, ptr %v16
  ret ptr %v17
}

; isstructured 3726
define i1 @p.aptypes.isstructured(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame60
  %v2 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = call i1 @p.aptypes.isrestricted(ptr @frame.aptypes, ptr %v5)
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 2
  %v8 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s259)
  unreachable
L6:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = call i1 @p.aptypes.isarray(ptr @frame.aptypes, ptr %v12)
  br i1 %v13, label %L8, label %L7
L7:
  %v14 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v15 = load ptr, ptr %v14
  %v16 = icmp eq ptr %v15, null
  br i1 %v16, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s260)
  unreachable
L10:
  %v17 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v15, i32 0, i32 1
  %v18 = load ptr, ptr %v17
  %v19 = call i1 @p.aptypes.isrecord(ptr @frame.aptypes, ptr %v18)
  br label %L8
L8:
  %v20 = phi i1 [ true, %L6 ], [ %v19, %L10 ]
  br i1 %v20, label %L12, label %L11
L11:
  %v21 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v22 = load ptr, ptr %v21
  %v23 = icmp eq ptr %v22, null
  br i1 %v23, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s261)
  unreachable
L14:
  %v24 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v22, i32 0, i32 1
  %v25 = load ptr, ptr %v24
  %v26 = call i1 @p.aptypes.isoptional(ptr @frame.aptypes, ptr %v25)
  br label %L12
L12:
  %v27 = phi i1 [ true, %L8 ], [ %v26, %L14 ]
  store i1 %v27, ptr %v7
  br label %L4
L3:
  %v28 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 2
  %v29 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v30 = load ptr, ptr %v29
  %v31 = call i1 @p.aptypes.isarray(ptr @frame.aptypes, ptr %v30)
  br i1 %v31, label %L16, label %L15
L15:
  %v32 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v33 = load ptr, ptr %v32
  %v34 = call i1 @p.aptypes.isrecord(ptr @frame.aptypes, ptr %v33)
  br label %L16
L16:
  %v35 = phi i1 [ true, %L3 ], [ %v34, %L15 ]
  br i1 %v35, label %L18, label %L17
L17:
  %v36 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 1
  %v37 = load ptr, ptr %v36
  %v38 = call i1 @p.aptypes.isoptional(ptr @frame.aptypes, ptr %v37)
  br label %L18
L18:
  %v39 = phi i1 [ true, %L16 ], [ %v38, %L17 ]
  store i1 %v39, ptr %v28
  br label %L4
L4:
  %v40 = getelementptr inbounds %frame60, ptr %frame, i32 0, i32 2
  %v41 = load i1, ptr %v40
  ret i1 %v41
}

; ismemory 3734
define i1 @p.aptypes.ismemory(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame61
  %v2 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = call i1 @p.aptypes.isrestricted(ptr @frame.aptypes, ptr %v5)
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 2
  %v8 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isstructured(ptr @frame.aptypes, ptr %v9)
  br i1 %v10, label %L6, label %L5
L5:
  %v11 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s262)
  unreachable
L8:
  %v14 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v12, i32 0, i32 1
  %v15 = load ptr, ptr %v14
  %v16 = call i1 @p.aptypes.isowned(ptr @frame.aptypes, ptr %v15)
  br label %L6
L6:
  %v17 = phi i1 [ true, %L2 ], [ %v16, %L8 ]
  br i1 %v17, label %L10, label %L9
L9:
  %v18 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s263)
  unreachable
L12:
  %v21 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v19, i32 0, i32 1
  %v22 = load ptr, ptr %v21
  %v23 = call i1 @p.aptypes.isstringrep(ptr @frame.aptypes, ptr %v22)
  br label %L10
L10:
  %v24 = phi i1 [ true, %L6 ], [ %v23, %L12 ]
  store i1 %v24, ptr %v7
  br label %L4
L3:
  %v25 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 2
  %v26 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v27 = load ptr, ptr %v26
  %v28 = call i1 @p.aptypes.isstructured(ptr @frame.aptypes, ptr %v27)
  br i1 %v28, label %L14, label %L13
L13:
  %v29 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v30 = load ptr, ptr %v29
  %v31 = call i1 @p.aptypes.isowned(ptr @frame.aptypes, ptr %v30)
  br label %L14
L14:
  %v32 = phi i1 [ true, %L3 ], [ %v31, %L13 ]
  br i1 %v32, label %L16, label %L15
L15:
  %v33 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 1
  %v34 = load ptr, ptr %v33
  %v35 = call i1 @p.aptypes.isstringrep(ptr @frame.aptypes, ptr %v34)
  br label %L16
L16:
  %v36 = phi i1 [ true, %L14 ], [ %v35, %L15 ]
  store i1 %v36, ptr %v25
  br label %L4
L4:
  %v37 = getelementptr inbounds %frame61, ptr %frame, i32 0, i32 2
  %v38 = load i1, ptr %v37
  ret i1 %v38
}

; protectable 3746
define i1 @p.aptypes.protectable(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame62
  %v2 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp eq ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  store i1 true, ptr %v7
  br label %L4
L3:
  %v8 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isfile(ptr @frame.aptypes, ptr %v9)
  br i1 %v10, label %L6, label %L5
L5:
  %v11 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = call i1 @p.aptypes.ispointer(ptr @frame.aptypes, ptr %v12)
  br label %L6
L6:
  %v14 = phi i1 [ true, %L3 ], [ %v13, %L5 ]
  br i1 %v14, label %L7, label %L8
L7:
  %v15 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  store i1 false, ptr %v15
  br label %L9
L8:
  %v16 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v17 = load ptr, ptr %v16
  %v18 = call i1 @p.aptypes.isarray(ptr @frame.aptypes, ptr %v17)
  br i1 %v18, label %L10, label %L11
L10:
  %v19 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  %v20 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v21 = load ptr, ptr %v20
  %v22 = icmp eq ptr %v21, null
  br i1 %v22, label %L13, label %L14
L13:
  call void @pas_runtime_error(ptr @s264)
  unreachable
L14:
  %v23 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v21, i32 0, i32 1
  %v24 = load ptr, ptr %v23
  %v25 = call i1 @p.aptypes.protectable(ptr @frame.aptypes, ptr %v24)
  store i1 %v25, ptr %v19
  br label %L12
L11:
  %v26 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v27 = load ptr, ptr %v26
  %v28 = call i1 @p.aptypes.isrecord(ptr @frame.aptypes, ptr %v27)
  br i1 %v28, label %L15, label %L16
L15:
  %v29 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 4
  store i1 true, ptr %v29
  %v30 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 3
  %v31 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 1
  %v32 = load ptr, ptr %v31
  %v33 = icmp eq ptr %v32, null
  br i1 %v33, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s265)
  unreachable
L19:
  %v34 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v32, i32 0, i32 13
  %v35 = load ptr, ptr %v34
  store ptr %v35, ptr %v30
  br label %L20
L20:
  %v36 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 3
  %v37 = load ptr, ptr %v36
  %v38 = icmp ne ptr %v37, null
  br i1 %v38, label %L23, label %L24
L23:
  %v39 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 4
  %v40 = load i1, ptr %v39
  br label %L24
L24:
  %v41 = phi i1 [ false, %L20 ], [ %v40, %L23 ]
  br i1 %v41, label %L21, label %L22
L21:
  %v42 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 3
  %v43 = load ptr, ptr %v42
  %v44 = icmp eq ptr %v43, null
  br i1 %v44, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s266)
  unreachable
L26:
  %v45 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v43, i32 0, i32 2
  %v46 = load ptr, ptr %v45
  %v47 = call i1 @p.aptypes.protectable(ptr @frame.aptypes, ptr %v46)
  %v48 = xor i1 %v47, true
  br i1 %v48, label %L27, label %L28
L27:
  %v49 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v49
  br label %L28
L28:
  %v50 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 3
  %v51 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 3
  %v52 = load ptr, ptr %v51
  %v53 = icmp eq ptr %v52, null
  br i1 %v53, label %L29, label %L30
L29:
  call void @pas_runtime_error(ptr @s267)
  unreachable
L30:
  %v54 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v52, i32 0, i32 10
  %v55 = load ptr, ptr %v54
  store ptr %v55, ptr %v50
  br label %L20
L22:
  %v56 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  %v57 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 4
  %v58 = load i1, ptr %v57
  store i1 %v58, ptr %v56
  br label %L17
L16:
  %v59 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  store i1 true, ptr %v59
  br label %L17
L17:
  br label %L12
L12:
  br label %L9
L9:
  br label %L4
L4:
  %v60 = getelementptr inbounds %frame62, ptr %frame, i32 0, i32 2
  %v61 = load i1, ptr %v60
  ret i1 %v61
}

; isordinal 3768
define i1 @p.aptypes.isordinal(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame63
  %v2 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp eq ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  %v7 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 2
  store i1 false, ptr %v7
  br label %L4
L3:
  %v8 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 4
  %v9 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v10)
  store ptr %v11, ptr %v8
  %v12 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 3
  %v13 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 4
  %v14 = load ptr, ptr %v13
  %v15 = icmp eq ptr %v14, null
  br i1 %v15, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s268)
  unreachable
L6:
  %v16 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v14, i32 0, i32 0
  %v17 = load i32, ptr %v16
  store i32 %v17, ptr %v12
  %v18 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 2
  %v19 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 3
  %v20 = load i32, ptr %v19
  %v21 = icmp eq i32 %v20, 1
  br i1 %v21, label %L8, label %L7
L7:
  %v22 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 3
  %v23 = load i32, ptr %v22
  %v24 = icmp eq i32 %v23, 3
  br label %L8
L8:
  %v25 = phi i1 [ true, %L6 ], [ %v24, %L7 ]
  br i1 %v25, label %L10, label %L9
L9:
  %v26 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 3
  %v27 = load i32, ptr %v26
  %v28 = icmp eq i32 %v27, 4
  br label %L10
L10:
  %v29 = phi i1 [ true, %L8 ], [ %v28, %L9 ]
  br i1 %v29, label %L12, label %L11
L11:
  %v30 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 3
  %v31 = load i32, ptr %v30
  %v32 = icmp eq i32 %v31, 5
  br label %L12
L12:
  %v33 = phi i1 [ true, %L10 ], [ %v32, %L11 ]
  store i1 %v33, ptr %v18
  br label %L4
L4:
  %v34 = getelementptr inbounds %frame63, ptr %frame, i32 0, i32 2
  %v35 = load i1, ptr %v34
  ret i1 %v35
}

; ischararray 3801
define i1 @p.aptypes.ischararray(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame64
  %v2 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isarray(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s269)
  unreachable
L5:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 6
  %v12 = load i1, ptr %v11
  br label %L3
L3:
  %v13 = phi i1 [ false, %L1 ], [ %v12, %L5 ]
  store i1 %v13, ptr %v4
  %v14 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v15 = load i1, ptr %v14
  br i1 %v15, label %L6, label %L7
L6:
  %v16 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v17 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v18 = load ptr, ptr %v17
  %v19 = icmp eq ptr %v18, null
  br i1 %v19, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s270)
  unreachable
L9:
  %v20 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v18, i32 0, i32 1
  %v21 = load ptr, ptr %v20
  %v22 = icmp ne ptr %v21, null
  br i1 %v22, label %L10, label %L11
L10:
  %v23 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v24, null
  br i1 %v25, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s271)
  unreachable
L13:
  %v26 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v24, i32 0, i32 1
  %v27 = load ptr, ptr %v26
  %v28 = icmp eq ptr %v27, null
  br i1 %v28, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s272)
  unreachable
L15:
  %v29 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v27, i32 0, i32 0
  %v30 = load i32, ptr %v29
  %v31 = icmp eq i32 %v30, 4
  br label %L11
L11:
  %v32 = phi i1 [ false, %L9 ], [ %v31, %L15 ]
  store i1 %v32, ptr %v16
  br label %L7
L7:
  %v33 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v34 = load i1, ptr %v33
  br i1 %v34, label %L16, label %L17
L16:
  %v35 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v36 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v37 = load ptr, ptr %v36
  %v38 = icmp eq ptr %v37, null
  br i1 %v38, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s273)
  unreachable
L19:
  %v39 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v37, i32 0, i32 2
  %v40 = load ptr, ptr %v39
  %v41 = call i1 @p.aptypes.isinteger(ptr @frame.aptypes, ptr %v40)
  br i1 %v41, label %L20, label %L21
L20:
  %v42 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v43 = load ptr, ptr %v42
  %v44 = icmp eq ptr %v43, null
  br i1 %v44, label %L22, label %L23
L22:
  call void @pas_runtime_error(ptr @s274)
  unreachable
L23:
  %v45 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v43, i32 0, i32 32
  %v46 = load ptr, ptr %v45
  %v47 = icmp eq ptr %v46, null
  br label %L21
L21:
  %v48 = phi i1 [ false, %L19 ], [ %v47, %L23 ]
  br i1 %v48, label %L24, label %L25
L24:
  %v49 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 1
  %v50 = load ptr, ptr %v49
  %v51 = icmp eq ptr %v50, null
  br i1 %v51, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s275)
  unreachable
L27:
  %v52 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v50, i32 0, i32 9
  %v53 = load i32, ptr %v52
  %v54 = icmp eq i32 %v53, 1
  br label %L25
L25:
  %v55 = phi i1 [ false, %L21 ], [ %v54, %L27 ]
  store i1 %v55, ptr %v35
  br label %L17
L17:
  %v56 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 2
  %v57 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 3
  %v58 = load i1, ptr %v57
  store i1 %v58, ptr %v56
  %v59 = getelementptr inbounds %frame64, ptr %frame, i32 0, i32 2
  %v60 = load i1, ptr %v59
  ret i1 %v60
}

; isstringtype 3815
define i1 @p.aptypes.isstringtype(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame65
  %v2 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isvarstring(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.ischararray(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  store i1 %v11, ptr %v4
  %v12 = getelementptr inbounds %frame65, ptr %frame, i32 0, i32 2
  %v13 = load i1, ptr %v12
  ret i1 %v13
}

; isstringorchar 3821
define i1 @p.aptypes.isstringorchar(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame66
  %v2 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isstringtype(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.ischar(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  store i1 %v11, ptr %v4
  %v12 = getelementptr inbounds %frame66, ptr %frame, i32 0, i32 2
  %v13 = load i1, ptr %v12
  ret i1 %v13
}

; isordered 3826
define i1 @p.aptypes.isordered(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame67
  %v2 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isordinal(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isnumeric(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  br i1 %v11, label %L5, label %L4
L4:
  %v12 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 1
  %v13 = load ptr, ptr %v12
  %v14 = call i1 @p.aptypes.isstringtype(ptr @frame.aptypes, ptr %v13)
  br label %L5
L5:
  %v15 = phi i1 [ true, %L3 ], [ %v14, %L4 ]
  br i1 %v15, label %L7, label %L6
L6:
  %v16 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 1
  %v17 = load ptr, ptr %v16
  %v18 = call i1 @p.aptypes.istext(ptr @frame.aptypes, ptr %v17)
  br label %L7
L7:
  %v19 = phi i1 [ true, %L5 ], [ %v18, %L6 ]
  store i1 %v19, ptr %v4
  %v20 = getelementptr inbounds %frame67, ptr %frame, i32 0, i32 2
  %v21 = load i1, ptr %v20
  ret i1 %v21
}

; isequatable 3836
define i1 @p.aptypes.isequatable(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame68
  %v2 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = call i1 @p.aptypes.isordinal(ptr @frame.aptypes, ptr %v6)
  br i1 %v7, label %L3, label %L2
L2:
  %v8 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = call i1 @p.aptypes.isnumeric(ptr @frame.aptypes, ptr %v9)
  br label %L3
L3:
  %v11 = phi i1 [ true, %L1 ], [ %v10, %L2 ]
  br i1 %v11, label %L5, label %L4
L4:
  %v12 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v13 = load ptr, ptr %v12
  %v14 = call i1 @p.aptypes.iscomplex(ptr @frame.aptypes, ptr %v13)
  br label %L5
L5:
  %v15 = phi i1 [ true, %L3 ], [ %v14, %L4 ]
  br i1 %v15, label %L7, label %L6
L6:
  %v16 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v17 = load ptr, ptr %v16
  %v18 = call i1 @p.aptypes.isset(ptr @frame.aptypes, ptr %v17)
  br label %L7
L7:
  %v19 = phi i1 [ true, %L5 ], [ %v18, %L6 ]
  br i1 %v19, label %L9, label %L8
L8:
  %v20 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v21 = load ptr, ptr %v20
  %v22 = call i1 @p.aptypes.isstringtype(ptr @frame.aptypes, ptr %v21)
  br label %L9
L9:
  %v23 = phi i1 [ true, %L7 ], [ %v22, %L8 ]
  br i1 %v23, label %L11, label %L10
L10:
  %v24 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v25 = load ptr, ptr %v24
  %v26 = call i1 @p.aptypes.istext(ptr @frame.aptypes, ptr %v25)
  br label %L11
L11:
  %v27 = phi i1 [ true, %L9 ], [ %v26, %L10 ]
  br i1 %v27, label %L13, label %L12
L12:
  %v28 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v29 = load ptr, ptr %v28
  %v30 = call i1 @p.aptypes.ispointer(ptr @frame.aptypes, ptr %v29)
  br i1 %v30, label %L14, label %L15
L14:
  %v31 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 1
  %v32 = load ptr, ptr %v31
  %v33 = call i1 @p.aptypes.isownedpointer(ptr @frame.aptypes, ptr %v32)
  %v34 = xor i1 %v33, true
  br label %L15
L15:
  %v35 = phi i1 [ false, %L12 ], [ %v34, %L14 ]
  br label %L13
L13:
  %v36 = phi i1 [ true, %L11 ], [ %v35, %L15 ]
  store i1 %v36, ptr %v4
  %v37 = getelementptr inbounds %frame68, ptr %frame, i32 0, i32 2
  %v38 = load i1, ptr %v37
  ret i1 %v38
}

; satisfiescat 3843
define i1 @p.aptypes.satisfiescat(ptr %link, ptr %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame69
  %v2 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 2
  %v6 = load i32, ptr %v5
  switch i32 %v6, label %L7 [ i32 0, label %L2 i32 1, label %L3 i32 2, label %L4 i32 3, label %L5 i32 4, label %L6 ]
L2:
  %v7 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  store i1 true, ptr %v7
  br label %L8
L3:
  %v8 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  %v9 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = call i1 @p.aptypes.isarith(ptr @frame.aptypes, ptr %v10)
  store i1 %v11, ptr %v8
  br label %L8
L4:
  %v12 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  %v13 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 1
  %v14 = load ptr, ptr %v13
  %v15 = call i1 @p.aptypes.isordinal(ptr @frame.aptypes, ptr %v14)
  store i1 %v15, ptr %v12
  br label %L8
L5:
  %v16 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  %v17 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 1
  %v18 = load ptr, ptr %v17
  %v19 = call i1 @p.aptypes.isordered(ptr @frame.aptypes, ptr %v18)
  store i1 %v19, ptr %v16
  br label %L8
L6:
  %v20 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  %v21 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 1
  %v22 = load ptr, ptr %v21
  %v23 = call i1 @p.aptypes.isequatable(ptr @frame.aptypes, ptr %v22)
  store i1 %v23, ptr %v20
  br label %L8
L7:
  call void @pas_runtime_error(ptr @s276)
  unreachable
L8:
  %v24 = getelementptr inbounds %frame69, ptr %frame, i32 0, i32 3
  %v25 = load i1, ptr %v24
  ret i1 %v25
}

; writecatname 3856
define void @p.aptypes.writecatname(ptr %link, i32 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame70
  %v2 = getelementptr inbounds %frame70, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame70, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame70, ptr %frame, i32 0, i32 1
  %v5 = load i32, ptr %v4
  switch i32 %v5, label %L7 [ i32 0, label %L2 i32 1, label %L3 i32 2, label %L4 i32 3, label %L5 i32 4, label %L6 ]
L2:
  call void @pas_write_str(ptr @pas.output, ptr @s277, i32 4, i32 -1)
  br label %L8
L3:
  call void @pas_write_str(ptr @pas.output, ptr @s278, i32 7, i32 -1)
  br label %L8
L4:
  call void @pas_write_str(ptr @pas.output, ptr @s279, i32 7, i32 -1)
  br label %L8
L5:
  call void @pas_write_str(ptr @pas.output, ptr @s280, i32 7, i32 -1)
  br label %L8
L6:
  call void @pas_write_str(ptr @pas.output, ptr @s281, i32 9, i32 -1)
  br label %L8
L7:
  call void @pas_runtime_error(ptr @s282)
  unreachable
L8:
  ret void
}

; writecatadmits 3874
define void @p.aptypes.writecatadmits(ptr %link, i32 %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame71
  %v2 = getelementptr inbounds %frame71, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame71, ptr %frame, i32 0, i32 1
  store i32 %a0, ptr %v3
  %v4 = getelementptr inbounds %frame71, ptr %frame, i32 0, i32 1
  %v5 = load i32, ptr %v4
  switch i32 %v5, label %L6 [ i32 1, label %L2 i32 2, label %L3 i32 3, label %L4 i32 4, label %L5 ]
L2:
  call void @pas_write_str(ptr @pas.output, ptr @s283, i32 51, i32 -1)
  br label %L7
L3:
  call void @pas_write_str(ptr @pas.output, ptr @s284, i32 44, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s285, i32 20, i32 -1)
  br label %L7
L4:
  call void @pas_write_str(ptr @pas.output, ptr @s286, i32 49, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s287, i32 8, i32 -1)
  br label %L7
L5:
  call void @pas_write_str(ptr @pas.output, ptr @s288, i32 51, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s289, i32 51, i32 -1)
  br label %L7
L6:
  call void @pas_runtime_error(ptr @s290)
  unreachable
L7:
  ret void
}

; stringvalueformal 3914
define i1 @p.aptypes.stringvalueformal(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame72
  %v2 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s291)
  unreachable
L3:
  %v8 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v6, i32 0, i32 2
  %v9 = load i32, ptr %v8
  %v10 = icmp eq i32 %v9, 3
  br i1 %v10, label %L4, label %L5
L4:
  %v11 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s292)
  unreachable
L7:
  %v14 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v12, i32 0, i32 60
  %v15 = load ptr, ptr %v14
  %v16 = icmp ne ptr %v15, null
  br label %L5
L5:
  %v17 = phi i1 [ false, %L3 ], [ %v16, %L7 ]
  br i1 %v17, label %L8, label %L9
L8:
  %v18 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 1
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s293)
  unreachable
L11:
  %v21 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v19, i32 0, i32 60
  %v22 = load ptr, ptr %v21
  %v23 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 50
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v22, %v24
  br label %L9
L9:
  %v26 = phi i1 [ false, %L5 ], [ %v25, %L11 ]
  store i1 %v26, ptr %v4
  %v27 = getelementptr inbounds %frame72, ptr %frame, i32 0, i32 2
  %v28 = load i1, ptr %v27
  ret i1 %v28
}

; foreignstringformal 3926
define i1 @p.aptypes.foreignstringformal(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame73
  %v2 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 2
  %v5 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s294)
  unreachable
L3:
  %v8 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v6, i32 0, i32 2
  %v9 = load i32, ptr %v8
  %v10 = icmp eq i32 %v9, 3
  br i1 %v10, label %L4, label %L5
L4:
  %v11 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s295)
  unreachable
L7:
  %v14 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v12, i32 0, i32 60
  %v15 = load ptr, ptr %v14
  %v16 = icmp ne ptr %v15, null
  br label %L5
L5:
  %v17 = phi i1 [ false, %L3 ], [ %v16, %L7 ]
  br i1 %v17, label %L8, label %L9
L8:
  %v18 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 1
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s296)
  unreachable
L11:
  %v21 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v19, i32 0, i32 3
  %v22 = load ptr, ptr %v21
  %v23 = call i1 @p.aptypes.isvarstring(ptr @frame.aptypes, ptr %v22)
  br label %L9
L9:
  %v24 = phi i1 [ false, %L5 ], [ %v23, %L11 ]
  store i1 %v24, ptr %v4
  %v25 = getelementptr inbounds %frame73, ptr %frame, i32 0, i32 2
  %v26 = load i1, ptr %v25
  ret i1 %v26
}

; enumcount 3932
define i32 @p.aptypes.enumcount(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame74
  %v2 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 4
  store i32 0, ptr %v4
  %v5 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 3
  %v6 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 1
  %v7 = load ptr, ptr %v6
  %v8 = icmp eq ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s297)
  unreachable
L3:
  %v9 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v7, i32 0, i32 11
  %v10 = load ptr, ptr %v9
  store ptr %v10, ptr %v5
  br label %L4
L4:
  %v11 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 3
  %v12 = load ptr, ptr %v11
  %v13 = icmp ne ptr %v12, null
  br i1 %v13, label %L5, label %L6
L5:
  %v14 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 4
  %v15 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 4
  %v16 = load i32, ptr %v15
  %v17 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v16, i32 1)
  %v18 = extractvalue { i32, i1 } %v17, 0
  %v19 = extractvalue { i32, i1 } %v17, 1
  %v20 = icmp eq i32 %v18, -2147483648
  %v21 = or i1 %v19, %v20
  br i1 %v21, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s298)
  unreachable
L8:
  store i32 %v18, ptr %v14
  %v22 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 3
  %v23 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 3
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v24, null
  br i1 %v25, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s299)
  unreachable
L10:
  %v26 = getelementptr inbounds { i32, i32, ptr }, ptr %v24, i32 0, i32 2
  %v27 = load ptr, ptr %v26
  store ptr %v27, ptr %v22
  br label %L4
L6:
  %v28 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 2
  %v29 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 4
  %v30 = load i32, ptr %v29
  store i32 %v30, ptr %v28
  %v31 = getelementptr inbounds %frame74, ptr %frame, i32 0, i32 2
  %v32 = load i32, ptr %v31
  ret i32 %v32
}

; ordinallo 3946
define i32 @p.aptypes.ordinallo(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame75
  %v2 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp eq ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s300)
  unreachable
L3:
  %v7 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v5, i32 0, i32 0
  %v8 = load i32, ptr %v7
  %v9 = icmp eq i32 %v8, 6
  br i1 %v9, label %L4, label %L5
L4:
  %v10 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 2
  %v11 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s301)
  unreachable
L8:
  %v14 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v12, i32 0, i32 9
  %v15 = load i32, ptr %v14
  store i32 %v15, ptr %v10
  br label %L6
L5:
  %v16 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 1
  %v17 = load ptr, ptr %v16
  %v18 = icmp eq ptr %v17, null
  br i1 %v18, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s302)
  unreachable
L10:
  %v19 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v17, i32 0, i32 0
  %v20 = load i32, ptr %v19
  %v21 = icmp eq i32 %v20, 1
  br i1 %v21, label %L11, label %L12
L11:
  %v22 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 2
  %v23 = sub nsw i32 0, 2147483647
  store i32 %v23, ptr %v22
  br label %L13
L12:
  %v24 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 2
  store i32 0, ptr %v24
  br label %L13
L13:
  br label %L6
L6:
  %v25 = getelementptr inbounds %frame75, ptr %frame, i32 0, i32 2
  %v26 = load i32, ptr %v25
  ret i32 %v26
}

; ordinalhi 3953
define i32 @p.aptypes.ordinalhi(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame76
  %v2 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp eq ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s303)
  unreachable
L3:
  %v7 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v5, i32 0, i32 0
  %v8 = load i32, ptr %v7
  %v9 = icmp eq i32 %v8, 6
  br i1 %v9, label %L4, label %L5
L4:
  %v10 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  %v11 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v12 = load ptr, ptr %v11
  %v13 = icmp eq ptr %v12, null
  br i1 %v13, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s304)
  unreachable
L8:
  %v14 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v12, i32 0, i32 10
  %v15 = load i32, ptr %v14
  store i32 %v15, ptr %v10
  br label %L6
L5:
  %v16 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v17 = load ptr, ptr %v16
  %v18 = icmp eq ptr %v17, null
  br i1 %v18, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s305)
  unreachable
L10:
  %v19 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v17, i32 0, i32 0
  %v20 = load i32, ptr %v19
  %v21 = icmp eq i32 %v20, 1
  br i1 %v21, label %L11, label %L12
L11:
  %v22 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  store i32 2147483647, ptr %v22
  br label %L13
L12:
  %v23 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v24, null
  br i1 %v25, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s306)
  unreachable
L15:
  %v26 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v24, i32 0, i32 0
  %v27 = load i32, ptr %v26
  %v28 = icmp eq i32 %v27, 4
  br i1 %v28, label %L16, label %L17
L16:
  %v29 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  store i32 255, ptr %v29
  br label %L18
L17:
  %v30 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v31 = load ptr, ptr %v30
  %v32 = icmp eq ptr %v31, null
  br i1 %v32, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s307)
  unreachable
L20:
  %v33 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v31, i32 0, i32 0
  %v34 = load i32, ptr %v33
  %v35 = icmp eq i32 %v34, 3
  br i1 %v35, label %L21, label %L22
L21:
  %v36 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  store i32 1, ptr %v36
  br label %L23
L22:
  %v37 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v38 = load ptr, ptr %v37
  %v39 = icmp eq ptr %v38, null
  br i1 %v39, label %L24, label %L25
L24:
  call void @pas_runtime_error(ptr @s308)
  unreachable
L25:
  %v40 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v38, i32 0, i32 0
  %v41 = load i32, ptr %v40
  %v42 = icmp eq i32 %v41, 5
  br i1 %v42, label %L26, label %L27
L26:
  %v43 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  %v44 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 1
  %v45 = load ptr, ptr %v44
  %v46 = call i32 @p.aptypes.enumcount(ptr @frame.aptypes, ptr %v45)
  %v47 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v46, i32 1)
  %v48 = extractvalue { i32, i1 } %v47, 0
  %v49 = extractvalue { i32, i1 } %v47, 1
  %v50 = icmp eq i32 %v48, -2147483648
  %v51 = or i1 %v49, %v50
  br i1 %v51, label %L29, label %L30
L29:
  call void @pas_runtime_error(ptr @s309)
  unreachable
L30:
  store i32 %v48, ptr %v43
  br label %L28
L27:
  %v52 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  store i32 0, ptr %v52
  br label %L28
L28:
  br label %L23
L23:
  br label %L18
L18:
  br label %L13
L13:
  br label %L6
L6:
  %v53 = getelementptr inbounds %frame76, ptr %frame, i32 0, i32 2
  %v54 = load i32, ptr %v53
  ret i32 %v54
}

; typelength 3963
define i64 @p.aptypes.typelength(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame77
  %v2 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 3
  %v5 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s310)
  unreachable
L3:
  %v8 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v6, i32 0, i32 9
  %v9 = load i32, ptr %v8
  %v10 = sext i32 %v9 to i64
  store i64 %v10, ptr %v4
  %v11 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 2
  %v12 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 1
  %v13 = load ptr, ptr %v12
  %v14 = icmp eq ptr %v13, null
  br i1 %v14, label %L4, label %L5
L4:
  call void @pas_runtime_error(ptr @s311)
  unreachable
L5:
  %v15 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v13, i32 0, i32 10
  %v16 = load i32, ptr %v15
  %v17 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 3
  %v18 = load i64, ptr %v17
  %v19 = sext i32 %v16 to i64
  %v20 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %v19, i64 %v18)
  %v21 = extractvalue { i64, i1 } %v20, 0
  %v22 = extractvalue { i64, i1 } %v20, 1
  %v23 = icmp eq i64 %v21, -9223372036854775808
  %v24 = or i1 %v22, %v23
  br i1 %v24, label %L6, label %L7
L6:
  call void @pas_runtime_error(ptr @s312)
  unreachable
L7:
  %v25 = sext i32 1 to i64
  %v26 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v21, i64 %v25)
  %v27 = extractvalue { i64, i1 } %v26, 0
  %v28 = extractvalue { i64, i1 } %v26, 1
  %v29 = icmp eq i64 %v27, -9223372036854775808
  %v30 = or i1 %v28, %v29
  br i1 %v30, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s313)
  unreachable
L9:
  store i64 %v27, ptr %v11
  %v31 = getelementptr inbounds %frame77, ptr %frame, i32 0, i32 2
  %v32 = load i64, ptr %v31
  ret i64 %v32
}

; padstofixedstring 3990
define i1 @p.aptypes.padstofixedstring(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame78
  %v2 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 3
  %v6 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  %v7 = load ptr, ptr %v6
  %v8 = icmp ne ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  %v9 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br label %L3
L3:
  %v12 = phi i1 [ false, %L1 ], [ %v11, %L2 ]
  br i1 %v12, label %L4, label %L5
L4:
  %v13 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  %v14 = load ptr, ptr %v13
  %v15 = call i1 @p.aptypes.ischararray(ptr @frame.aptypes, ptr %v14)
  br label %L5
L5:
  %v16 = phi i1 [ false, %L3 ], [ %v15, %L4 ]
  br i1 %v16, label %L6, label %L7
L6:
  %v17 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  %v18 = load ptr, ptr %v17
  %v19 = icmp eq ptr %v18, null
  br i1 %v19, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s314)
  unreachable
L9:
  %v20 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v18, i32 0, i32 32
  %v21 = load ptr, ptr %v20
  %v22 = icmp eq ptr %v21, null
  br label %L7
L7:
  %v23 = phi i1 [ false, %L5 ], [ %v22, %L9 ]
  br i1 %v23, label %L10, label %L11
L10:
  %v24 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  %v25 = load ptr, ptr %v24
  %v26 = icmp eq ptr %v25, null
  br i1 %v26, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s315)
  unreachable
L13:
  %v27 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v25, i32 0, i32 33
  %v28 = load ptr, ptr %v27
  %v29 = icmp eq ptr %v28, null
  br label %L11
L11:
  %v30 = phi i1 [ false, %L7 ], [ %v29, %L13 ]
  br i1 %v30, label %L14, label %L15
L14:
  %v31 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v32 = load ptr, ptr %v31
  %v33 = call i1 @p.aptypes.isstringorchar(ptr @frame.aptypes, ptr %v32)
  br label %L15
L15:
  %v34 = phi i1 [ false, %L11 ], [ %v33, %L14 ]
  br i1 %v34, label %L16, label %L17
L16:
  %v35 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v36 = load ptr, ptr %v35
  %v37 = call i1 @p.aptypes.ischararray(ptr @frame.aptypes, ptr %v36)
  %v38 = xor i1 %v37, true
  br i1 %v38, label %L19, label %L18
L18:
  %v39 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v40 = load ptr, ptr %v39
  %v41 = icmp eq ptr %v40, null
  br i1 %v41, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s316)
  unreachable
L21:
  %v42 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v40, i32 0, i32 32
  %v43 = load ptr, ptr %v42
  %v44 = icmp ne ptr %v43, null
  br label %L19
L19:
  %v45 = phi i1 [ true, %L16 ], [ %v44, %L21 ]
  br i1 %v45, label %L23, label %L22
L22:
  %v46 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v47 = load ptr, ptr %v46
  %v48 = icmp eq ptr %v47, null
  br i1 %v48, label %L24, label %L25
L24:
  call void @pas_runtime_error(ptr @s317)
  unreachable
L25:
  %v49 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v47, i32 0, i32 33
  %v50 = load ptr, ptr %v49
  %v51 = icmp ne ptr %v50, null
  br label %L23
L23:
  %v52 = phi i1 [ true, %L19 ], [ %v51, %L25 ]
  br i1 %v52, label %L27, label %L26
L26:
  %v53 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 2
  %v54 = load ptr, ptr %v53
  %v55 = call i64 @p.aptypes.typelength(ptr @frame.aptypes, ptr %v54)
  %v56 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 1
  %v57 = load ptr, ptr %v56
  %v58 = call i64 @p.aptypes.typelength(ptr @frame.aptypes, ptr %v57)
  %v59 = icmp ne i64 %v55, %v58
  br label %L27
L27:
  %v60 = phi i1 [ true, %L23 ], [ %v59, %L26 ]
  br label %L17
L17:
  %v61 = phi i1 [ false, %L15 ], [ %v60, %L27 ]
  store i1 %v61, ptr %v5
  %v62 = getelementptr inbounds %frame78, ptr %frame, i32 0, i32 3
  %v63 = load i1, ptr %v62
  ret i1 %v63
}

; armatin 4003
define ptr @p.aptypes.armatin(ptr %link, ptr %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame79
  %v2 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  br label %L2
L2:
  %v5 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 2
  %v6 = load i32, ptr %v5
  %v7 = icmp sgt i32 %v6, 0
  br i1 %v7, label %L3, label %L4
L3:
  %v8 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 1
  %v9 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = icmp eq ptr %v10, null
  br i1 %v11, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s318)
  unreachable
L6:
  %v12 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v10, i32 0, i32 11
  %v13 = load ptr, ptr %v12
  store ptr %v13, ptr %v8
  %v14 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 2
  %v15 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 2
  %v16 = load i32, ptr %v15
  %v17 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %v16, i32 1)
  %v18 = extractvalue { i32, i1 } %v17, 0
  %v19 = extractvalue { i32, i1 } %v17, 1
  %v20 = icmp eq i32 %v18, -2147483648
  %v21 = or i1 %v19, %v20
  br i1 %v21, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s319)
  unreachable
L8:
  store i32 %v18, ptr %v14
  br label %L2
L4:
  %v22 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 3
  %v23 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 1
  %v24 = load ptr, ptr %v23
  store ptr %v24, ptr %v22
  %v25 = getelementptr inbounds %frame79, ptr %frame, i32 0, i32 3
  %v26 = load ptr, ptr %v25
  ret ptr %v26
}

; findfieldin 4012
define internal ptr @p92(ptr %link, ptr %a0, i32 %a1, i32 %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame92
  %v2 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 3
  store i32 %a2, ptr %v5
  %v6 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  store ptr null, ptr %v6
  br label %L2
L2:
  %v7 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  %v8 = load ptr, ptr %v7
  %v9 = icmp ne ptr %v8, null
  br i1 %v9, label %L5, label %L6
L5:
  %v10 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v11 = load ptr, ptr %v10
  %v12 = icmp eq ptr %v11, null
  br label %L6
L6:
  %v13 = phi i1 [ false, %L2 ], [ %v12, %L5 ]
  br i1 %v13, label %L3, label %L4
L3:
  %v14 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v15 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = icmp eq ptr %v16, null
  br i1 %v17, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s320)
  unreachable
L8:
  %v18 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v16, i32 0, i32 2
  %v19 = load ptr, ptr %v18
  store ptr %v19, ptr %v14
  br label %L9
L9:
  %v20 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v21 = load ptr, ptr %v20
  %v22 = icmp ne ptr %v21, null
  br i1 %v22, label %L12, label %L13
L12:
  %v23 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v24, null
  br label %L13
L13:
  %v26 = phi i1 [ false, %L9 ], [ %v25, %L12 ]
  br i1 %v26, label %L10, label %L11
L10:
  %v27 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v28 = load ptr, ptr %v27
  %v29 = icmp eq ptr %v28, null
  br i1 %v29, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s321)
  unreachable
L15:
  %v30 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v28, i32 0, i32 0
  %v31 = load i32, ptr %v30
  %v32 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v33 = load ptr, ptr %v32
  %v34 = icmp eq ptr %v33, null
  br i1 %v34, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s322)
  unreachable
L17:
  %v35 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v33, i32 0, i32 1
  %v36 = load i32, ptr %v35
  %v37 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 2
  %v38 = load i32, ptr %v37
  %v39 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 3
  %v40 = load i32, ptr %v39
  %v41 = call i1 @p.aptypes.poolsame(ptr @frame.aptypes, i32 %v31, i32 %v36, i32 %v38, i32 %v40)
  br i1 %v41, label %L18, label %L19
L18:
  %v42 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v43 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v44 = load ptr, ptr %v43
  store ptr %v44, ptr %v42
  br label %L19
L19:
  %v45 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v46 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 5
  %v47 = load ptr, ptr %v46
  %v48 = icmp eq ptr %v47, null
  br i1 %v48, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s323)
  unreachable
L21:
  %v49 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v47, i32 0, i32 10
  %v50 = load ptr, ptr %v49
  store ptr %v50, ptr %v45
  br label %L9
L11:
  %v51 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v52 = load ptr, ptr %v51
  %v53 = icmp eq ptr %v52, null
  br i1 %v53, label %L22, label %L23
L22:
  %v54 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v55 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  %v56 = load ptr, ptr %v55
  %v57 = icmp eq ptr %v56, null
  br i1 %v57, label %L24, label %L25
L24:
  call void @pas_runtime_error(ptr @s324)
  unreachable
L25:
  %v58 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v56, i32 0, i32 4
  %v59 = load ptr, ptr %v58
  %v60 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 2
  %v61 = load i32, ptr %v60
  %v62 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 3
  %v63 = load i32, ptr %v62
  %v64 = call ptr @p92(ptr @frame.aptypes, ptr %v59, i32 %v61, i32 %v63)
  store ptr %v64, ptr %v54
  br label %L23
L23:
  %v65 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  %v66 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 1
  %v67 = load ptr, ptr %v66
  %v68 = icmp eq ptr %v67, null
  br i1 %v68, label %L26, label %L27
L26:
  call void @pas_runtime_error(ptr @s325)
  unreachable
L27:
  %v69 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v67, i32 0, i32 11
  %v70 = load ptr, ptr %v69
  store ptr %v70, ptr %v65
  br label %L2
L4:
  %v71 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 4
  %v72 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 6
  %v73 = load ptr, ptr %v72
  store ptr %v73, ptr %v71
  %v74 = getelementptr inbounds %frame92, ptr %frame, i32 0, i32 4
  %v75 = load ptr, ptr %v74
  ret ptr %v75
}

; findfield 4028
define ptr @p.aptypes.findfield(ptr %link, ptr %a0, i32 %a1, i32 %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame80
  %v2 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 3
  store i32 %a2, ptr %v5
  %v6 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  store ptr null, ptr %v6
  %v7 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v8 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 1
  %v9 = load ptr, ptr %v8
  %v10 = icmp eq ptr %v9, null
  br i1 %v10, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s326)
  unreachable
L3:
  %v11 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v9, i32 0, i32 13
  %v12 = load ptr, ptr %v11
  store ptr %v12, ptr %v7
  br label %L4
L4:
  %v13 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v14 = load ptr, ptr %v13
  %v15 = icmp ne ptr %v14, null
  br i1 %v15, label %L7, label %L8
L7:
  %v16 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  %v17 = load ptr, ptr %v16
  %v18 = icmp eq ptr %v17, null
  br label %L8
L8:
  %v19 = phi i1 [ false, %L4 ], [ %v18, %L7 ]
  br i1 %v19, label %L5, label %L6
L5:
  %v20 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v21 = load ptr, ptr %v20
  %v22 = icmp eq ptr %v21, null
  br i1 %v22, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s327)
  unreachable
L10:
  %v23 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v21, i32 0, i32 0
  %v24 = load i32, ptr %v23
  %v25 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v26 = load ptr, ptr %v25
  %v27 = icmp eq ptr %v26, null
  br i1 %v27, label %L11, label %L12
L11:
  call void @pas_runtime_error(ptr @s328)
  unreachable
L12:
  %v28 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v26, i32 0, i32 1
  %v29 = load i32, ptr %v28
  %v30 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 2
  %v31 = load i32, ptr %v30
  %v32 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 3
  %v33 = load i32, ptr %v32
  %v34 = call i1 @p.aptypes.poolsame(ptr @frame.aptypes, i32 %v24, i32 %v29, i32 %v31, i32 %v33)
  br i1 %v34, label %L13, label %L14
L13:
  %v35 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  %v36 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v37 = load ptr, ptr %v36
  store ptr %v37, ptr %v35
  br label %L14
L14:
  %v38 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v39 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 5
  %v40 = load ptr, ptr %v39
  %v41 = icmp eq ptr %v40, null
  br i1 %v41, label %L15, label %L16
L15:
  call void @pas_runtime_error(ptr @s329)
  unreachable
L16:
  %v42 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v40, i32 0, i32 10
  %v43 = load ptr, ptr %v42
  store ptr %v43, ptr %v38
  br label %L4
L6:
  %v44 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  %v45 = load ptr, ptr %v44
  %v46 = icmp eq ptr %v45, null
  br i1 %v46, label %L17, label %L18
L17:
  %v47 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  %v48 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 1
  %v49 = load ptr, ptr %v48
  %v50 = icmp eq ptr %v49, null
  br i1 %v50, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s330)
  unreachable
L20:
  %v51 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v49, i32 0, i32 15
  %v52 = load ptr, ptr %v51
  %v53 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 2
  %v54 = load i32, ptr %v53
  %v55 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 3
  %v56 = load i32, ptr %v55
  %v57 = call ptr @p92(ptr @frame.aptypes, ptr %v52, i32 %v54, i32 %v56)
  store ptr %v57, ptr %v47
  br label %L18
L18:
  %v58 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 4
  %v59 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 6
  %v60 = load ptr, ptr %v59
  store ptr %v60, ptr %v58
  %v61 = getelementptr inbounds %frame80, ptr %frame, i32 0, i32 4
  %v62 = load ptr, ptr %v61
  ret ptr %v62
}

; armat 4043
define internal ptr @p93(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame93
  %v2 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v6 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 1
  %v7 = load ptr, ptr %v6
  %v8 = icmp eq ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  call void @pas_runtime_error(ptr @s331)
  unreachable
L3:
  %v9 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v7, i32 0, i32 15
  %v10 = load ptr, ptr %v9
  store ptr %v10, ptr %v5
  br label %L4
L4:
  %v11 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  %v12 = load ptr, ptr %v11
  %v13 = icmp ne ptr %v12, null
  br i1 %v13, label %L5, label %L6
L5:
  %v14 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v14
  br label %L7
L7:
  %v15 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 5
  %v16 = load i32, ptr %v15
  %v17 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  %v18 = load ptr, ptr %v17
  %v19 = icmp eq ptr %v18, null
  br i1 %v19, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s332)
  unreachable
L11:
  %v20 = getelementptr inbounds { i32, ptr, ptr }, ptr %v18, i32 0, i32 0
  %v21 = load i32, ptr %v20
  %v22 = icmp slt i32 %v16, %v21
  br i1 %v22, label %L8, label %L9
L8:
  %v23 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v24 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v25 = load ptr, ptr %v24
  %v26 = icmp eq ptr %v25, null
  br i1 %v26, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s333)
  unreachable
L13:
  %v27 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v25, i32 0, i32 11
  %v28 = load ptr, ptr %v27
  store ptr %v28, ptr %v23
  %v29 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 5
  %v30 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 5
  %v31 = load i32, ptr %v30
  %v32 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v31, i32 1)
  %v33 = extractvalue { i32, i1 } %v32, 0
  %v34 = extractvalue { i32, i1 } %v32, 1
  %v35 = icmp eq i32 %v33, -2147483648
  %v36 = or i1 %v34, %v35
  br i1 %v36, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s334)
  unreachable
L15:
  store i32 %v33, ptr %v29
  br label %L7
L9:
  %v37 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  %v38 = load ptr, ptr %v37
  %v39 = icmp eq ptr %v38, null
  br i1 %v39, label %L16, label %L17
L16:
  call void @pas_runtime_error(ptr @s335)
  unreachable
L17:
  %v40 = getelementptr inbounds { i32, ptr, ptr }, ptr %v38, i32 0, i32 2
  %v41 = load ptr, ptr %v40
  %v42 = icmp ne ptr %v41, null
  br i1 %v42, label %L18, label %L19
L18:
  %v43 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v44 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v45 = load ptr, ptr %v44
  %v46 = icmp eq ptr %v45, null
  br i1 %v46, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s336)
  unreachable
L21:
  %v47 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v45, i32 0, i32 4
  %v48 = load ptr, ptr %v47
  store ptr %v48, ptr %v43
  br label %L19
L19:
  %v49 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  %v50 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 2
  %v51 = load ptr, ptr %v50
  %v52 = icmp eq ptr %v51, null
  br i1 %v52, label %L22, label %L23
L22:
  call void @pas_runtime_error(ptr @s337)
  unreachable
L23:
  %v53 = getelementptr inbounds { i32, ptr, ptr }, ptr %v51, i32 0, i32 2
  %v54 = load ptr, ptr %v53
  store ptr %v54, ptr %v49
  br label %L4
L6:
  %v55 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 3
  %v56 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 4
  %v57 = load ptr, ptr %v56
  store ptr %v57, ptr %v55
  %v58 = getelementptr inbounds %frame93, ptr %frame, i32 0, i32 3
  %v59 = load ptr, ptr %v58
  ret ptr %v59
}

; armsat 4065
define ptr @p.aptypes.armsat(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame81
  %v2 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 2
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 3
  %v9 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = icmp eq ptr %v10, null
  br i1 %v11, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s338)
  unreachable
L6:
  %v12 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v10, i32 0, i32 15
  %v13 = load ptr, ptr %v12
  store ptr %v13, ptr %v8
  br label %L4
L3:
  %v14 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 4
  %v15 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 2
  %v18 = load ptr, ptr %v17
  %v19 = call ptr @p93(ptr @frame.aptypes, ptr %v16, ptr %v18)
  store ptr %v19, ptr %v14
  %v20 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 3
  %v21 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 4
  %v22 = load ptr, ptr %v21
  %v23 = icmp eq ptr %v22, null
  br i1 %v23, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s339)
  unreachable
L8:
  %v24 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v22, i32 0, i32 4
  %v25 = load ptr, ptr %v24
  store ptr %v25, ptr %v20
  br label %L4
L4:
  %v26 = getelementptr inbounds %frame81, ptr %frame, i32 0, i32 3
  %v27 = load ptr, ptr %v26
  ret ptr %v27
}

; fieldsat 4076
define ptr @p.aptypes.fieldsat(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame82
  %v2 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 2
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 3
  %v9 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = icmp eq ptr %v10, null
  br i1 %v11, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s340)
  unreachable
L6:
  %v12 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v10, i32 0, i32 13
  %v13 = load ptr, ptr %v12
  store ptr %v13, ptr %v8
  br label %L4
L3:
  %v14 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 4
  %v15 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 2
  %v18 = load ptr, ptr %v17
  %v19 = call ptr @p93(ptr @frame.aptypes, ptr %v16, ptr %v18)
  store ptr %v19, ptr %v14
  %v20 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 3
  %v21 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 4
  %v22 = load ptr, ptr %v21
  %v23 = icmp eq ptr %v22, null
  br i1 %v23, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s341)
  unreachable
L8:
  %v24 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v22, i32 0, i32 2
  %v25 = load ptr, ptr %v24
  store ptr %v25, ptr %v20
  br label %L4
L4:
  %v26 = getelementptr inbounds %frame82, ptr %frame, i32 0, i32 3
  %v27 = load ptr, ptr %v26
  ret ptr %v27
}

; tagfieldat 4090
define i32 @p.aptypes.tagfieldat(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame83
  %v2 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 2
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 3
  %v9 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = icmp eq ptr %v10, null
  br i1 %v11, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s342)
  unreachable
L6:
  %v12 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v10, i32 0, i32 21
  %v13 = load i32, ptr %v12
  store i32 %v13, ptr %v8
  br label %L4
L3:
  %v14 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 4
  %v15 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 2
  %v18 = load ptr, ptr %v17
  %v19 = call ptr @p93(ptr @frame.aptypes, ptr %v16, ptr %v18)
  store ptr %v19, ptr %v14
  %v20 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 3
  %v21 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 4
  %v22 = load ptr, ptr %v21
  %v23 = icmp eq ptr %v22, null
  br i1 %v23, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s343)
  unreachable
L8:
  %v24 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v22, i32 0, i32 6
  %v25 = load i32, ptr %v24
  store i32 %v25, ptr %v20
  br label %L4
L4:
  %v26 = getelementptr inbounds %frame83, ptr %frame, i32 0, i32 3
  %v27 = load i32, ptr %v26
  ret i32 %v27
}

; tagtypeat 4101
define ptr @p.aptypes.tagtypeat(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame84
  %v2 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 2
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 3
  %v9 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = icmp eq ptr %v10, null
  br i1 %v11, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s344)
  unreachable
L6:
  %v12 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v10, i32 0, i32 4
  %v13 = load ptr, ptr %v12
  store ptr %v13, ptr %v8
  br label %L4
L3:
  %v14 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 4
  %v15 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 1
  %v16 = load ptr, ptr %v15
  %v17 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 2
  %v18 = load ptr, ptr %v17
  %v19 = call ptr @p93(ptr @frame.aptypes, ptr %v16, ptr %v18)
  store ptr %v19, ptr %v14
  %v20 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 3
  %v21 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 4
  %v22 = load ptr, ptr %v21
  %v23 = icmp eq ptr %v22, null
  br i1 %v23, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s345)
  unreachable
L8:
  %v24 = getelementptr inbounds { ptr, i1, ptr, ptr, ptr, ptr, i32, ptr, i1, i32, i32, ptr }, ptr %v22, i32 0, i32 7
  %v25 = load ptr, ptr %v24
  store ptr %v25, ptr %v20
  br label %L4
L4:
  %v26 = getelementptr inbounds %frame84, ptr %frame, i32 0, i32 3
  %v27 = load ptr, ptr %v26
  ret ptr %v27
}

; fileindexof 4112
define i32 @p.aptypes.fileindexof(ptr %link, ptr %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame86
  %v2 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 1
  call void @pas_str_store_var(ptr %v3, i32 4096, ptr %a0, i32 %a1)
  %v4 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 2
  store i32 0, ptr %v4
  %v5 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 1
  %v6 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v5, i32 0, i32 0
  %v7 = load i32, ptr %v6
  %v8 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v5, i32 0, i32 1
  %v9 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 44
  %v10 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v9, i32 0, i32 0
  %v11 = load i32, ptr %v10
  %v12 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v9, i32 0, i32 1
  %v13 = call i32 @pas_str_cmp_pad(ptr %v8, i32 %v7, ptr %v12, i32 %v11)
  %v14 = icmp ne i32 %v13, 0
  br i1 %v14, label %L2, label %L3
L2:
  %v15 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 3
  store i32 1, ptr %v15
  br label %L4
L4:
  %v16 = load i32, ptr %v15
  %v17 = icmp sle i32 %v16, 32
  br i1 %v17, label %L5, label %L7
L5:
  %v18 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 1
  %v19 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v18, i32 0, i32 0
  %v20 = load i32, ptr %v19
  %v21 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v18, i32 0, i32 1
  %v22 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 24
  %v23 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 3
  %v24 = load i32, ptr %v23
  %v25 = icmp slt i32 %v24, 1
  %v26 = icmp sgt i32 %v24, 32
  %v27 = or i1 %v25, %v26
  br i1 %v27, label %L9, label %L10
L9:
  call void @pas_runtime_error(ptr @s346)
  unreachable
L10:
  %v28 = sub i32 %v24, 1
  %v29 = getelementptr inbounds [32 x { i32, [4096 x i8] }], ptr %v22, i32 0, i32 %v28
  %v30 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v29, i32 0, i32 0
  %v31 = load i32, ptr %v30
  %v32 = getelementptr inbounds { i32, [4096 x i8] }, ptr %v29, i32 0, i32 1
  %v33 = call i32 @pas_str_cmp_pad(ptr %v21, i32 %v20, ptr %v32, i32 %v31)
  %v34 = icmp eq i32 %v33, 0
  br i1 %v34, label %L11, label %L12
L11:
  %v35 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 2
  %v36 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 3
  %v37 = load i32, ptr %v36
  store i32 %v37, ptr %v35
  br label %L12
L12:
  br label %L8
L8:
  %v38 = load i32, ptr %v15
  %v39 = icmp eq i32 %v38, 32
  br i1 %v39, label %L7, label %L6
L6:
  %v40 = add i32 %v38, 1
  store i32 %v40, ptr %v15
  br label %L4
L7:
  br label %L3
L3:
  %v41 = getelementptr inbounds %frame86, ptr %frame, i32 0, i32 2
  %v42 = load i32, ptr %v41
  ret i32 %v42
}

; writeordinalname 4129
define void @p.aptypes.writeordinalname(ptr %link, ptr %a0, i32 %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame85
  %v2 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  store i32 %a1, ptr %v4
  %v5 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 1
  %v6 = load ptr, ptr %v5
  %v7 = icmp eq ptr %v6, null
  br i1 %v7, label %L2, label %L3
L2:
  %v8 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  store ptr null, ptr %v8
  br label %L4
L3:
  %v9 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v10 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 1
  %v11 = load ptr, ptr %v10
  %v12 = call ptr @p.aptypes.base(ptr @frame.aptypes, ptr %v11)
  store ptr %v12, ptr %v9
  br label %L4
L4:
  %v13 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v14 = load ptr, ptr %v13
  %v15 = icmp eq ptr %v14, null
  br i1 %v15, label %L5, label %L6
L5:
  %v16 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v17 = load i32, ptr %v16
  call void @p90(ptr @frame.aptypes, i32 %v17)
  br label %L7
L6:
  %v18 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L8, label %L9
L8:
  call void @pas_runtime_error(ptr @s347)
  unreachable
L9:
  %v21 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v19, i32 0, i32 0
  %v22 = load i32, ptr %v21
  %v23 = icmp eq i32 %v22, 4
  br i1 %v23, label %L10, label %L11
L10:
  %v24 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v25 = load i32, ptr %v24
  %v26 = icmp sge i32 %v25, 32
  br i1 %v26, label %L13, label %L14
L13:
  %v27 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v28 = load i32, ptr %v27
  %v29 = icmp slt i32 %v28, 127
  br label %L14
L14:
  %v30 = phi i1 [ false, %L10 ], [ %v29, %L13 ]
  br i1 %v30, label %L15, label %L16
L15:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 39)
  %v31 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v32 = load i32, ptr %v31
  %v33 = icmp slt i32 %v32, 0
  %v34 = icmp sgt i32 %v32, 255
  %v35 = or i1 %v33, %v34
  br i1 %v35, label %L18, label %L19
L18:
  call void @pas_runtime_error(ptr @s348)
  unreachable
L19:
  %v36 = trunc i32 %v32 to i8
  call void @p.aptypes.put(ptr @frame.aptypes, i8 %v36)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 39)
  br label %L17
L16:
  call void @p89(ptr @frame.aptypes, ptr @s349)
  %v37 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v38 = load i32, ptr %v37
  call void @p90(ptr @frame.aptypes, i32 %v38)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 41)
  br label %L17
L17:
  br label %L12
L11:
  %v39 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v40 = load ptr, ptr %v39
  %v41 = icmp eq ptr %v40, null
  br i1 %v41, label %L20, label %L21
L20:
  call void @pas_runtime_error(ptr @s350)
  unreachable
L21:
  %v42 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v40, i32 0, i32 0
  %v43 = load i32, ptr %v42
  %v44 = icmp eq i32 %v43, 3
  br i1 %v44, label %L22, label %L23
L22:
  %v45 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v46 = load i32, ptr %v45
  %v47 = icmp ne i32 %v46, 0
  br i1 %v47, label %L25, label %L26
L25:
  call void @p89(ptr @frame.aptypes, ptr @s351)
  br label %L27
L26:
  call void @p89(ptr @frame.aptypes, ptr @s352)
  br label %L27
L27:
  br label %L24
L23:
  %v48 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v49 = load ptr, ptr %v48
  %v50 = icmp eq ptr %v49, null
  br i1 %v50, label %L28, label %L29
L28:
  call void @pas_runtime_error(ptr @s353)
  unreachable
L29:
  %v51 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v49, i32 0, i32 0
  %v52 = load i32, ptr %v51
  %v53 = icmp eq i32 %v52, 5
  br i1 %v53, label %L30, label %L31
L30:
  %v54 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v55 = load i32, ptr %v54
  %v56 = icmp sge i32 %v55, 0
  br label %L31
L31:
  %v57 = phi i1 [ false, %L29 ], [ %v56, %L30 ]
  br i1 %v57, label %L32, label %L33
L32:
  %v58 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v59 = load i32, ptr %v58
  %v60 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v61 = load ptr, ptr %v60
  %v62 = call i32 @p.aptypes.enumcount(ptr @frame.aptypes, ptr %v61)
  %v63 = icmp slt i32 %v59, %v62
  br label %L33
L33:
  %v64 = phi i1 [ false, %L31 ], [ %v63, %L32 ]
  br i1 %v64, label %L34, label %L35
L34:
  %v65 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 4
  %v66 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 3
  %v67 = load ptr, ptr %v66
  %v68 = icmp eq ptr %v67, null
  br i1 %v68, label %L37, label %L38
L37:
  call void @pas_runtime_error(ptr @s354)
  unreachable
L38:
  %v69 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v67, i32 0, i32 11
  %v70 = load ptr, ptr %v69
  store ptr %v70, ptr %v65
  %v71 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 5
  store i32 0, ptr %v71
  %v72 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 6
  store i1 false, ptr %v72
  br label %L39
L39:
  %v73 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 6
  %v74 = load i1, ptr %v73
  %v75 = xor i1 %v74, true
  br i1 %v75, label %L40, label %L41
L40:
  %v76 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 5
  %v77 = load i32, ptr %v76
  %v78 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v79 = load i32, ptr %v78
  %v80 = icmp eq i32 %v77, %v79
  br i1 %v80, label %L42, label %L43
L42:
  %v81 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 4
  %v82 = load ptr, ptr %v81
  %v83 = icmp eq ptr %v82, null
  br i1 %v83, label %L45, label %L46
L45:
  call void @pas_runtime_error(ptr @s355)
  unreachable
L46:
  %v84 = getelementptr inbounds { i32, i32, ptr }, ptr %v82, i32 0, i32 0
  %v85 = load i32, ptr %v84
  %v86 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 4
  %v87 = load ptr, ptr %v86
  %v88 = icmp eq ptr %v87, null
  br i1 %v88, label %L47, label %L48
L47:
  call void @pas_runtime_error(ptr @s356)
  unreachable
L48:
  %v89 = getelementptr inbounds { i32, i32, ptr }, ptr %v87, i32 0, i32 1
  %v90 = load i32, ptr %v89
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v85, i32 %v90)
  %v91 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 6
  store i1 true, ptr %v91
  br label %L44
L43:
  %v92 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 4
  %v93 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 4
  %v94 = load ptr, ptr %v93
  %v95 = icmp eq ptr %v94, null
  br i1 %v95, label %L49, label %L50
L49:
  call void @pas_runtime_error(ptr @s357)
  unreachable
L50:
  %v96 = getelementptr inbounds { i32, i32, ptr }, ptr %v94, i32 0, i32 2
  %v97 = load ptr, ptr %v96
  store ptr %v97, ptr %v92
  %v98 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 5
  %v99 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 5
  %v100 = load i32, ptr %v99
  %v101 = call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %v100, i32 1)
  %v102 = extractvalue { i32, i1 } %v101, 0
  %v103 = extractvalue { i32, i1 } %v101, 1
  %v104 = icmp eq i32 %v102, -2147483648
  %v105 = or i1 %v103, %v104
  br i1 %v105, label %L51, label %L52
L51:
  call void @pas_runtime_error(ptr @s358)
  unreachable
L52:
  store i32 %v102, ptr %v98
  br label %L44
L44:
  br label %L39
L41:
  br label %L36
L35:
  %v106 = getelementptr inbounds %frame85, ptr %frame, i32 0, i32 2
  %v107 = load i32, ptr %v106
  call void @p90(ptr @frame.aptypes, i32 %v107)
  br label %L36
L36:
  br label %L24
L24:
  br label %L12
L12:
  br label %L7
L7:
  ret void
}

; writeboundname 4175
define internal void @p94(ptr %link, ptr %a0, ptr %a1, i32 %a2) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame94
  %v2 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 3
  store i32 %a2, ptr %v5
  %v6 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 2
  %v7 = load ptr, ptr %v6
  %v8 = icmp eq ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  %v9 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 1
  %v10 = load ptr, ptr %v9
  %v11 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 3
  %v12 = load i32, ptr %v11
  call void @p.aptypes.writeordinalname(ptr @frame.aptypes, ptr %v10, i32 %v12)
  br label %L4
L3:
  %v13 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 2
  %v14 = load ptr, ptr %v13
  %v15 = icmp eq ptr %v14, null
  br i1 %v15, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s359)
  unreachable
L6:
  %v16 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v14, i32 0, i32 0
  %v17 = load i32, ptr %v16
  %v18 = getelementptr inbounds %frame94, ptr %frame, i32 0, i32 2
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L7, label %L8
L7:
  call void @pas_runtime_error(ptr @s360)
  unreachable
L8:
  %v21 = getelementptr inbounds { i32, i32, i32, ptr, i32, i32, i32, i32, i32, i32, i8, i1, i32, i32, i1, ptr, i1, i32, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr, i32, i1, i1, i32, ptr, i1, i1, i1, i1, i32, i32, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i1, i1, ptr, ptr, ptr, ptr, i32, i32, i1, i1, i1, i1, i1, i32, i32, i1, i1, i1, i1, i1, i1, ptr, ptr, ptr, ptr, i1, i32, i32, i32, i32, i32, i1, i32, ptr }, ptr %v19, i32 0, i32 1
  %v22 = load i32, ptr %v21
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v17, i32 %v22)
  br label %L4
L4:
  ret void
}

; writetypename 4181
define void @p.aptypes.writetypename(ptr %link, ptr %a0) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame87
  %v2 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v5 = load ptr, ptr %v4
  %v6 = icmp eq ptr %v5, null
  br i1 %v6, label %L2, label %L3
L2:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 63)
  br label %L4
L3:
  %v7 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v8 = load ptr, ptr %v7
  %v9 = icmp eq ptr %v8, null
  br i1 %v9, label %L5, label %L6
L5:
  call void @pas_runtime_error(ptr @s361)
  unreachable
L6:
  %v10 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v8, i32 0, i32 24
  %v11 = load i32, ptr %v10
  %v12 = icmp sgt i32 %v11, 0
  br i1 %v12, label %L7, label %L8
L7:
  %v13 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v14 = load ptr, ptr %v13
  %v15 = icmp eq ptr %v14, null
  br i1 %v15, label %L10, label %L11
L10:
  call void @pas_runtime_error(ptr @s362)
  unreachable
L11:
  %v16 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v14, i32 0, i32 23
  %v17 = load i32, ptr %v16
  %v18 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v19 = load ptr, ptr %v18
  %v20 = icmp eq ptr %v19, null
  br i1 %v20, label %L12, label %L13
L12:
  call void @pas_runtime_error(ptr @s363)
  unreachable
L13:
  %v21 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v19, i32 0, i32 24
  %v22 = load i32, ptr %v21
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v17, i32 %v22)
  br label %L9
L8:
  %v23 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v24 = load ptr, ptr %v23
  %v25 = icmp eq ptr %v24, null
  br i1 %v25, label %L14, label %L15
L14:
  call void @pas_runtime_error(ptr @s364)
  unreachable
L15:
  %v26 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v24, i32 0, i32 0
  %v27 = load i32, ptr %v26
  switch i32 %v27, label %L37 [ i32 1, label %L16 i32 20, label %L17 i32 2, label %L18 i32 13, label %L19 i32 14, label %L20 i32 18, label %L21 i32 19, label %L22 i32 3, label %L23 i32 4, label %L24 i32 0, label %L25 i32 5, label %L26 i32 6, label %L27 i32 9, label %L28 i32 15, label %L29 i32 16, label %L30 i32 17, label %L31 i32 10, label %L32 i32 11, label %L33 i32 12, label %L34 i32 8, label %L35 i32 7, label %L36 ]
L16:
  call void @p89(ptr @frame.aptypes, ptr @s365)
  br label %L38
L17:
  call void @p89(ptr @frame.aptypes, ptr @s366)
  br label %L38
L18:
  call void @p89(ptr @frame.aptypes, ptr @s367)
  br label %L38
L19:
  call void @p89(ptr @frame.aptypes, ptr @s368)
  br label %L38
L20:
  call void @p89(ptr @frame.aptypes, ptr @s369)
  %v28 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v29 = load ptr, ptr %v28
  %v30 = icmp eq ptr %v29, null
  br i1 %v30, label %L39, label %L40
L39:
  call void @pas_runtime_error(ptr @s370)
  unreachable
L40:
  %v31 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v29, i32 0, i32 1
  %v32 = load ptr, ptr %v31
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v32)
  br label %L38
L21:
  %v33 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v34 = load ptr, ptr %v33
  %v35 = icmp eq ptr %v34, null
  br i1 %v35, label %L41, label %L42
L41:
  call void @pas_runtime_error(ptr @s371)
  unreachable
L42:
  %v36 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v34, i32 0, i32 10
  %v37 = load i32, ptr %v36
  %v38 = icmp slt i32 %v37, 0
  br i1 %v38, label %L43, label %L44
L43:
  call void @p89(ptr @frame.aptypes, ptr @s372)
  br label %L45
L44:
  call void @p89(ptr @frame.aptypes, ptr @s373)
  %v39 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v40 = load ptr, ptr %v39
  %v41 = icmp eq ptr %v40, null
  br i1 %v41, label %L46, label %L47
L46:
  call void @pas_runtime_error(ptr @s374)
  unreachable
L47:
  %v42 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v40, i32 0, i32 10
  %v43 = load i32, ptr %v42
  call void @p90(ptr @frame.aptypes, i32 %v43)
  call void @p89(ptr @frame.aptypes, ptr @s375)
  br label %L45
L45:
  br label %L38
L22:
  %v44 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v45 = load ptr, ptr %v44
  %v46 = icmp eq ptr %v45, null
  br i1 %v46, label %L48, label %L49
L48:
  call void @pas_runtime_error(ptr @s376)
  unreachable
L49:
  %v47 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v45, i32 0, i32 10
  %v48 = load i32, ptr %v47
  %v49 = icmp sle i32 %v48, 0
  br i1 %v49, label %L50, label %L51
L50:
  call void @p89(ptr @frame.aptypes, ptr @s377)
  br label %L52
L51:
  call void @p89(ptr @frame.aptypes, ptr @s378)
  %v50 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v51 = load ptr, ptr %v50
  %v52 = icmp eq ptr %v51, null
  br i1 %v52, label %L53, label %L54
L53:
  call void @pas_runtime_error(ptr @s379)
  unreachable
L54:
  %v53 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v51, i32 0, i32 10
  %v54 = load i32, ptr %v53
  call void @p90(ptr @frame.aptypes, i32 %v54)
  call void @p89(ptr @frame.aptypes, ptr @s380)
  br label %L52
L52:
  br label %L38
L23:
  call void @p89(ptr @frame.aptypes, ptr @s381)
  br label %L38
L24:
  call void @p89(ptr @frame.aptypes, ptr @s382)
  br label %L38
L25:
  call void @p89(ptr @frame.aptypes, ptr @s383)
  br label %L38
L26:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 40)
  %v55 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v56 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v57 = load ptr, ptr %v56
  %v58 = icmp eq ptr %v57, null
  br i1 %v58, label %L55, label %L56
L55:
  call void @pas_runtime_error(ptr @s384)
  unreachable
L56:
  %v59 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v57, i32 0, i32 11
  %v60 = load ptr, ptr %v59
  store ptr %v60, ptr %v55
  %v61 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  store i1 true, ptr %v61
  br label %L57
L57:
  %v62 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v63 = load ptr, ptr %v62
  %v64 = icmp ne ptr %v63, null
  br i1 %v64, label %L58, label %L59
L58:
  %v65 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  %v66 = load i1, ptr %v65
  %v67 = xor i1 %v66, true
  br i1 %v67, label %L60, label %L61
L60:
  call void @p89(ptr @frame.aptypes, ptr @s385)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  br label %L61
L61:
  %v68 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v69 = load ptr, ptr %v68
  %v70 = icmp eq ptr %v69, null
  br i1 %v70, label %L62, label %L63
L62:
  call void @pas_runtime_error(ptr @s386)
  unreachable
L63:
  %v71 = getelementptr inbounds { i32, i32, ptr }, ptr %v69, i32 0, i32 0
  %v72 = load i32, ptr %v71
  %v73 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v74 = load ptr, ptr %v73
  %v75 = icmp eq ptr %v74, null
  br i1 %v75, label %L64, label %L65
L64:
  call void @pas_runtime_error(ptr @s387)
  unreachable
L65:
  %v76 = getelementptr inbounds { i32, i32, ptr }, ptr %v74, i32 0, i32 1
  %v77 = load i32, ptr %v76
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v72, i32 %v77)
  %v78 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v78
  %v79 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v80 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 2
  %v81 = load ptr, ptr %v80
  %v82 = icmp eq ptr %v81, null
  br i1 %v82, label %L66, label %L67
L66:
  call void @pas_runtime_error(ptr @s388)
  unreachable
L67:
  %v83 = getelementptr inbounds { i32, i32, ptr }, ptr %v81, i32 0, i32 2
  %v84 = load ptr, ptr %v83
  store ptr %v84, ptr %v79
  br label %L57
L59:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 41)
  br label %L38
L27:
  %v85 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v86 = load ptr, ptr %v85
  %v87 = icmp eq ptr %v86, null
  br i1 %v87, label %L68, label %L69
L68:
  call void @pas_runtime_error(ptr @s389)
  unreachable
L69:
  %v88 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v86, i32 0, i32 3
  %v89 = load ptr, ptr %v88
  %v90 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v91 = load ptr, ptr %v90
  %v92 = icmp eq ptr %v91, null
  br i1 %v92, label %L70, label %L71
L70:
  call void @pas_runtime_error(ptr @s390)
  unreachable
L71:
  %v93 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v91, i32 0, i32 32
  %v94 = load ptr, ptr %v93
  %v95 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v96 = load ptr, ptr %v95
  %v97 = icmp eq ptr %v96, null
  br i1 %v97, label %L72, label %L73
L72:
  call void @pas_runtime_error(ptr @s391)
  unreachable
L73:
  %v98 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v96, i32 0, i32 9
  %v99 = load i32, ptr %v98
  call void @p94(ptr @frame.aptypes, ptr %v89, ptr %v94, i32 %v99)
  call void @p89(ptr @frame.aptypes, ptr @s392)
  %v100 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v101 = load ptr, ptr %v100
  %v102 = icmp eq ptr %v101, null
  br i1 %v102, label %L74, label %L75
L74:
  call void @pas_runtime_error(ptr @s393)
  unreachable
L75:
  %v103 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v101, i32 0, i32 3
  %v104 = load ptr, ptr %v103
  %v105 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v106 = load ptr, ptr %v105
  %v107 = icmp eq ptr %v106, null
  br i1 %v107, label %L76, label %L77
L76:
  call void @pas_runtime_error(ptr @s394)
  unreachable
L77:
  %v108 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v106, i32 0, i32 33
  %v109 = load ptr, ptr %v108
  %v110 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v111 = load ptr, ptr %v110
  %v112 = icmp eq ptr %v111, null
  br i1 %v112, label %L78, label %L79
L78:
  call void @pas_runtime_error(ptr @s395)
  unreachable
L79:
  %v113 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v111, i32 0, i32 10
  %v114 = load i32, ptr %v113
  call void @p94(ptr @frame.aptypes, ptr %v104, ptr %v109, i32 %v114)
  br label %L38
L28:
  %v115 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v116 = load ptr, ptr %v115
  %v117 = icmp eq ptr %v116, null
  br i1 %v117, label %L80, label %L81
L80:
  call void @pas_runtime_error(ptr @s396)
  unreachable
L81:
  %v118 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v116, i32 0, i32 1
  %v119 = load ptr, ptr %v118
  %v120 = icmp ne ptr %v119, null
  br i1 %v120, label %L82, label %L83
L82:
  %v121 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v122 = load ptr, ptr %v121
  %v123 = icmp eq ptr %v122, null
  br i1 %v123, label %L85, label %L86
L85:
  call void @pas_runtime_error(ptr @s397)
  unreachable
L86:
  %v124 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v122, i32 0, i32 27
  %v125 = load i1, ptr %v124
  br i1 %v125, label %L87, label %L88
L87:
  call void @p89(ptr @frame.aptypes, ptr @s398)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  br label %L88
L88:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 94)
  %v126 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v127 = load ptr, ptr %v126
  %v128 = icmp eq ptr %v127, null
  br i1 %v128, label %L89, label %L90
L89:
  call void @pas_runtime_error(ptr @s399)
  unreachable
L90:
  %v129 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v127, i32 0, i32 1
  %v130 = load ptr, ptr %v129
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v130)
  br label %L84
L83:
  call void @p89(ptr @frame.aptypes, ptr @s400)
  br label %L84
L84:
  br label %L38
L29:
  call void @p89(ptr @frame.aptypes, ptr @s401)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v131 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v132 = load ptr, ptr %v131
  %v133 = icmp eq ptr %v132, null
  br i1 %v133, label %L91, label %L92
L91:
  call void @pas_runtime_error(ptr @s402)
  unreachable
L92:
  %v134 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v132, i32 0, i32 1
  %v135 = load ptr, ptr %v134
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v135)
  br label %L38
L30:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 63)
  %v136 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v137 = load ptr, ptr %v136
  %v138 = icmp eq ptr %v137, null
  br i1 %v138, label %L93, label %L94
L93:
  call void @pas_runtime_error(ptr @s403)
  unreachable
L94:
  %v139 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v137, i32 0, i32 1
  %v140 = load ptr, ptr %v139
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v140)
  br label %L38
L31:
  call void @p89(ptr @frame.aptypes, ptr @s404)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 39)
  %v141 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v142 = load ptr, ptr %v141
  %v143 = icmp eq ptr %v142, null
  br i1 %v143, label %L95, label %L96
L95:
  call void @pas_runtime_error(ptr @s405)
  unreachable
L96:
  %v144 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v142, i32 0, i32 25
  %v145 = load i32, ptr %v144
  %v146 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v147 = load ptr, ptr %v146
  %v148 = icmp eq ptr %v147, null
  br i1 %v148, label %L97, label %L98
L97:
  call void @pas_runtime_error(ptr @s406)
  unreachable
L98:
  %v149 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v147, i32 0, i32 26
  %v150 = load i32, ptr %v149
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v145, i32 %v150)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 39)
  br label %L38
L32:
  %v151 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v152 = load ptr, ptr %v151
  %v153 = icmp eq ptr %v152, null
  br i1 %v153, label %L99, label %L100
L99:
  call void @pas_runtime_error(ptr @s407)
  unreachable
L100:
  %v154 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v152, i32 0, i32 8
  %v155 = load i1, ptr %v154
  br i1 %v155, label %L101, label %L102
L101:
  call void @p89(ptr @frame.aptypes, ptr @s408)
  br label %L103
L102:
  %v156 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v157 = load ptr, ptr %v156
  %v158 = icmp eq ptr %v157, null
  br i1 %v158, label %L104, label %L105
L104:
  call void @pas_runtime_error(ptr @s409)
  unreachable
L105:
  %v159 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v157, i32 0, i32 2
  %v160 = load ptr, ptr %v159
  %v161 = icmp ne ptr %v160, null
  br i1 %v161, label %L106, label %L107
L106:
  call void @p89(ptr @frame.aptypes, ptr @s410)
  %v162 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v163 = load ptr, ptr %v162
  %v164 = icmp eq ptr %v163, null
  br i1 %v164, label %L109, label %L110
L109:
  call void @pas_runtime_error(ptr @s411)
  unreachable
L110:
  %v165 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v163, i32 0, i32 2
  %v166 = load ptr, ptr %v165
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v166)
  call void @p89(ptr @frame.aptypes, ptr @s412)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v167 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v168 = load ptr, ptr %v167
  %v169 = icmp eq ptr %v168, null
  br i1 %v169, label %L111, label %L112
L111:
  call void @pas_runtime_error(ptr @s413)
  unreachable
L112:
  %v170 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v168, i32 0, i32 1
  %v171 = load ptr, ptr %v170
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v171)
  br label %L108
L107:
  call void @p89(ptr @frame.aptypes, ptr @s414)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v172 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v173 = load ptr, ptr %v172
  %v174 = icmp eq ptr %v173, null
  br i1 %v174, label %L113, label %L114
L113:
  call void @pas_runtime_error(ptr @s415)
  unreachable
L114:
  %v175 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v173, i32 0, i32 1
  %v176 = load ptr, ptr %v175
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v176)
  br label %L108
L108:
  br label %L103
L103:
  br label %L38
L33:
  %v177 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v178 = load ptr, ptr %v177
  %v179 = icmp eq ptr %v178, null
  br i1 %v179, label %L115, label %L116
L115:
  call void @pas_runtime_error(ptr @s416)
  unreachable
L116:
  %v180 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v178, i32 0, i32 1
  %v181 = load ptr, ptr %v180
  %v182 = icmp eq ptr %v181, null
  br i1 %v182, label %L117, label %L118
L117:
  call void @p89(ptr @frame.aptypes, ptr @s417)
  br label %L119
L118:
  %v183 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v184 = load ptr, ptr %v183
  %v185 = icmp eq ptr %v184, null
  br i1 %v185, label %L120, label %L121
L120:
  call void @pas_runtime_error(ptr @s418)
  unreachable
L121:
  %v186 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v184, i32 0, i32 6
  %v187 = load i1, ptr %v186
  br i1 %v187, label %L122, label %L123
L122:
  call void @p89(ptr @frame.aptypes, ptr @s419)
  br label %L124
L123:
  call void @p89(ptr @frame.aptypes, ptr @s420)
  br label %L124
L124:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v188 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v189 = load ptr, ptr %v188
  %v190 = icmp eq ptr %v189, null
  br i1 %v190, label %L125, label %L126
L125:
  call void @pas_runtime_error(ptr @s421)
  unreachable
L126:
  %v191 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v189, i32 0, i32 1
  %v192 = load ptr, ptr %v191
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v192)
  br label %L119
L119:
  br label %L38
L34:
  %v193 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v194 = load ptr, ptr %v193
  %v195 = icmp eq ptr %v194, null
  br i1 %v195, label %L127, label %L128
L127:
  call void @pas_runtime_error(ptr @s422)
  unreachable
L128:
  %v196 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v194, i32 0, i32 1
  %v197 = load ptr, ptr %v196
  %v198 = icmp eq ptr %v197, null
  br i1 %v198, label %L129, label %L130
L129:
  call void @p89(ptr @frame.aptypes, ptr @s423)
  br label %L131
L130:
  call void @p89(ptr @frame.aptypes, ptr @s424)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  call void @p89(ptr @frame.aptypes, ptr @s425)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v199 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v200 = load ptr, ptr %v199
  %v201 = icmp eq ptr %v200, null
  br i1 %v201, label %L132, label %L133
L132:
  call void @pas_runtime_error(ptr @s426)
  unreachable
L133:
  %v202 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v200, i32 0, i32 1
  %v203 = load ptr, ptr %v202
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v203)
  br label %L131
L131:
  br label %L38
L35:
  %v204 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v205 = load ptr, ptr %v204
  %v206 = icmp eq ptr %v205, null
  br i1 %v206, label %L134, label %L135
L134:
  call void @pas_runtime_error(ptr @s427)
  unreachable
L135:
  %v207 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v205, i32 0, i32 17
  %v208 = load i1, ptr %v207
  br i1 %v208, label %L136, label %L137
L136:
  %v209 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v210 = load ptr, ptr %v209
  %v211 = icmp eq ptr %v210, null
  br i1 %v211, label %L139, label %L140
L139:
  call void @pas_runtime_error(ptr @s428)
  unreachable
L140:
  %v212 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v210, i32 0, i32 18
  %v213 = load ptr, ptr %v212
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v213)
  call void @p89(ptr @frame.aptypes, ptr @s429)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v214 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v215 = load ptr, ptr %v214
  %v216 = icmp eq ptr %v215, null
  br i1 %v216, label %L141, label %L142
L141:
  call void @pas_runtime_error(ptr @s430)
  unreachable
L142:
  %v217 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v215, i32 0, i32 19
  %v218 = load ptr, ptr %v217
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v218)
  br label %L138
L137:
  call void @p89(ptr @frame.aptypes, ptr @s431)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v219 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v220 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v221 = load ptr, ptr %v220
  %v222 = icmp eq ptr %v221, null
  br i1 %v222, label %L143, label %L144
L143:
  call void @pas_runtime_error(ptr @s432)
  unreachable
L144:
  %v223 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v221, i32 0, i32 13
  %v224 = load ptr, ptr %v223
  store ptr %v224, ptr %v219
  %v225 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  store i1 true, ptr %v225
  br label %L145
L145:
  %v226 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v227 = load ptr, ptr %v226
  %v228 = icmp ne ptr %v227, null
  br i1 %v228, label %L146, label %L147
L146:
  %v229 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  %v230 = load i1, ptr %v229
  %v231 = xor i1 %v230, true
  br i1 %v231, label %L148, label %L149
L148:
  call void @p89(ptr @frame.aptypes, ptr @s433)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  br label %L149
L149:
  %v232 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v233 = load ptr, ptr %v232
  %v234 = icmp eq ptr %v233, null
  br i1 %v234, label %L150, label %L151
L150:
  call void @pas_runtime_error(ptr @s434)
  unreachable
L151:
  %v235 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v233, i32 0, i32 0
  %v236 = load i32, ptr %v235
  %v237 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v238 = load ptr, ptr %v237
  %v239 = icmp eq ptr %v238, null
  br i1 %v239, label %L152, label %L153
L152:
  call void @pas_runtime_error(ptr @s435)
  unreachable
L153:
  %v240 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v238, i32 0, i32 1
  %v241 = load i32, ptr %v240
  call void @p.aptypes.writepool(ptr @frame.aptypes, i32 %v236, i32 %v241)
  %v242 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 4
  store i1 false, ptr %v242
  %v243 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v244 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 3
  %v245 = load ptr, ptr %v244
  %v246 = icmp eq ptr %v245, null
  br i1 %v246, label %L154, label %L155
L154:
  call void @pas_runtime_error(ptr @s436)
  unreachable
L155:
  %v247 = getelementptr inbounds { i32, i32, ptr, i32, ptr, i1, ptr, i32, i32, i32, ptr }, ptr %v245, i32 0, i32 10
  %v248 = load ptr, ptr %v247
  store ptr %v248, ptr %v243
  br label %L145
L147:
  call void @p89(ptr @frame.aptypes, ptr @s437)
  br label %L138
L138:
  br label %L38
L36:
  %v249 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v250 = load ptr, ptr %v249
  %v251 = icmp eq ptr %v250, null
  br i1 %v251, label %L156, label %L157
L156:
  call void @pas_runtime_error(ptr @s438)
  unreachable
L157:
  %v252 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v250, i32 0, i32 6
  %v253 = load i1, ptr %v252
  br i1 %v253, label %L158, label %L159
L158:
  call void @p89(ptr @frame.aptypes, ptr @s439)
  br label %L160
L159:
  call void @p89(ptr @frame.aptypes, ptr @s440)
  br label %L160
L160:
  %v254 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v255 = load ptr, ptr %v254
  %v256 = icmp eq ptr %v255, null
  br i1 %v256, label %L161, label %L162
L161:
  call void @pas_runtime_error(ptr @s441)
  unreachable
L162:
  %v257 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v255, i32 0, i32 2
  %v258 = load ptr, ptr %v257
  %v259 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v260 = load ptr, ptr %v259
  %v261 = icmp eq ptr %v260, null
  br i1 %v261, label %L163, label %L164
L163:
  call void @pas_runtime_error(ptr @s442)
  unreachable
L164:
  %v262 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v260, i32 0, i32 32
  %v263 = load ptr, ptr %v262
  %v264 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v265 = load ptr, ptr %v264
  %v266 = icmp eq ptr %v265, null
  br i1 %v266, label %L165, label %L166
L165:
  call void @pas_runtime_error(ptr @s443)
  unreachable
L166:
  %v267 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v265, i32 0, i32 9
  %v268 = load i32, ptr %v267
  call void @p94(ptr @frame.aptypes, ptr %v258, ptr %v263, i32 %v268)
  call void @p89(ptr @frame.aptypes, ptr @s444)
  %v269 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v270 = load ptr, ptr %v269
  %v271 = icmp eq ptr %v270, null
  br i1 %v271, label %L167, label %L168
L167:
  call void @pas_runtime_error(ptr @s445)
  unreachable
L168:
  %v272 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v270, i32 0, i32 2
  %v273 = load ptr, ptr %v272
  %v274 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v275 = load ptr, ptr %v274
  %v276 = icmp eq ptr %v275, null
  br i1 %v276, label %L169, label %L170
L169:
  call void @pas_runtime_error(ptr @s446)
  unreachable
L170:
  %v277 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v275, i32 0, i32 33
  %v278 = load ptr, ptr %v277
  %v279 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v280 = load ptr, ptr %v279
  %v281 = icmp eq ptr %v280, null
  br i1 %v281, label %L171, label %L172
L171:
  call void @pas_runtime_error(ptr @s447)
  unreachable
L172:
  %v282 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v280, i32 0, i32 10
  %v283 = load i32, ptr %v282
  call void @p94(ptr @frame.aptypes, ptr %v273, ptr %v278, i32 %v283)
  call void @p89(ptr @frame.aptypes, ptr @s448)
  call void @p.aptypes.put(ptr @frame.aptypes, i8 32)
  %v284 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v285 = load ptr, ptr %v284
  %v286 = icmp eq ptr %v285, null
  br i1 %v286, label %L173, label %L174
L173:
  call void @pas_runtime_error(ptr @s449)
  unreachable
L174:
  %v287 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v285, i32 0, i32 1
  %v288 = load ptr, ptr %v287
  %v289 = icmp ne ptr %v288, null
  br i1 %v289, label %L175, label %L176
L175:
  %v290 = getelementptr inbounds %frame87, ptr %frame, i32 0, i32 1
  %v291 = load ptr, ptr %v290
  %v292 = icmp eq ptr %v291, null
  br i1 %v292, label %L178, label %L179
L178:
  call void @pas_runtime_error(ptr @s450)
  unreachable
L179:
  %v293 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v291, i32 0, i32 1
  %v294 = load ptr, ptr %v293
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v294)
  br label %L177
L176:
  call void @p.aptypes.put(ptr @frame.aptypes, i8 63)
  br label %L177
L177:
  br label %L38
L37:
  call void @pas_runtime_error(ptr @s451)
  unreachable
L38:
  br label %L9
L9:
  br label %L4
L4:
  ret void
}

; writedistincttypenote 4377
define void @p.aptypes.writedistincttypenote(ptr %link, ptr %a0, ptr %a1) {
L1:
  %v1 = load i32, ptr @pas_str_at
  %frame = alloca %frame88
  %v2 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 0
  store ptr %link, ptr %v2
  %v3 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 1
  store ptr %a0, ptr %v3
  %v4 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 2
  store ptr %a1, ptr %v4
  %v5 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v6 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 1
  %v7 = load ptr, ptr %v6
  %v8 = icmp ne ptr %v7, null
  br i1 %v8, label %L2, label %L3
L2:
  %v9 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 2
  %v10 = load ptr, ptr %v9
  %v11 = icmp ne ptr %v10, null
  br label %L3
L3:
  %v12 = phi i1 [ false, %L1 ], [ %v11, %L2 ]
  br i1 %v12, label %L4, label %L5
L4:
  %v13 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 1
  %v14 = load ptr, ptr %v13
  %v15 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 2
  %v16 = load ptr, ptr %v15
  %v17 = icmp ne ptr %v14, %v16
  br label %L5
L5:
  %v18 = phi i1 [ false, %L3 ], [ %v17, %L4 ]
  br i1 %v18, label %L6, label %L7
L6:
  %v19 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 17
  store i1 true, ptr %v19
  %v20 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  call void @p.aptypes.strclear(ptr @frame.aptypes, ptr %v20)
  %v21 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 1
  %v22 = load ptr, ptr %v21
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v22)
  %v23 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v24 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  call void @llvm.memcpy.p0.p0.i64(ptr align 4 %v23, ptr align 4 %v24, i64 260, i1 false)
  %v25 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  call void @p.aptypes.strclear(ptr @frame.aptypes, ptr %v25)
  %v26 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 2
  %v27 = load ptr, ptr %v26
  call void @p.aptypes.writetypename(ptr @frame.aptypes, ptr %v27)
  %v28 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 17
  store i1 false, ptr %v28
  %v29 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 5
  %v30 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v31 = getelementptr inbounds { i32, [255 x i8] }, ptr %v30, i32 0, i32 0
  %v32 = load i32, ptr %v31
  %v33 = icmp slt i32 %v32, 255
  br i1 %v33, label %L8, label %L9
L8:
  %v34 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v35 = getelementptr inbounds { i32, [255 x i8] }, ptr %v34, i32 0, i32 0
  %v36 = load i32, ptr %v35
  %v37 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  %v38 = getelementptr inbounds { i32, [255 x i8] }, ptr %v37, i32 0, i32 0
  %v39 = load i32, ptr %v38
  %v40 = icmp eq i32 %v36, %v39
  br label %L9
L9:
  %v41 = phi i1 [ false, %L6 ], [ %v40, %L8 ]
  store i1 %v41, ptr %v29
  %v42 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 5
  %v43 = load i1, ptr %v42
  br i1 %v43, label %L10, label %L11
L10:
  %v44 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 4
  %v45 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v46 = getelementptr inbounds { i32, [255 x i8] }, ptr %v45, i32 0, i32 0
  %v47 = load i32, ptr %v46
  store i32 1, ptr %v44
  br label %L12
L12:
  %v48 = load i32, ptr %v44
  %v49 = icmp sle i32 %v48, %v47
  br i1 %v49, label %L13, label %L15
L13:
  %v50 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 3
  %v51 = getelementptr inbounds { i32, [255 x i8] }, ptr %v50, i32 0, i32 1
  %v52 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 4
  %v53 = load i32, ptr %v52
  %v54 = icmp slt i32 %v53, 1
  %v55 = icmp sgt i32 %v53, 255
  %v56 = or i1 %v54, %v55
  br i1 %v56, label %L17, label %L18
L17:
  call void @pas_runtime_error(ptr @s452)
  unreachable
L18:
  %v57 = sub i32 %v53, 1
  %v58 = getelementptr inbounds [255 x i8], ptr %v51, i32 0, i32 %v57
  %v59 = load i8, ptr %v58
  %v60 = getelementptr inbounds %frame1, ptr @frame.aptypes, i32 0, i32 18
  %v61 = getelementptr inbounds { i32, [255 x i8] }, ptr %v60, i32 0, i32 1
  %v62 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 4
  %v63 = load i32, ptr %v62
  %v64 = icmp slt i32 %v63, 1
  %v65 = icmp sgt i32 %v63, 255
  %v66 = or i1 %v64, %v65
  br i1 %v66, label %L19, label %L20
L19:
  call void @pas_runtime_error(ptr @s453)
  unreachable
L20:
  %v67 = sub i32 %v63, 1
  %v68 = getelementptr inbounds [255 x i8], ptr %v61, i32 0, i32 %v67
  %v69 = load i8, ptr %v68
  %v70 = icmp ne i8 %v59, %v69
  br i1 %v70, label %L21, label %L22
L21:
  %v71 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 5
  store i1 false, ptr %v71
  br label %L22
L22:
  br label %L16
L16:
  %v72 = load i32, ptr %v44
  %v73 = icmp eq i32 %v72, %v47
  br i1 %v73, label %L15, label %L14
L14:
  %v74 = add i32 %v72, 1
  store i32 %v74, ptr %v44
  br label %L12
L15:
  br label %L11
L11:
  %v75 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 5
  %v76 = load i1, ptr %v75
  br i1 %v76, label %L23, label %L24
L23:
  call void @pas_write_str(ptr @pas.output, ptr @s454, i32 33, i32 -1)
  %v77 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 1
  %v78 = load ptr, ptr %v77
  %v79 = icmp eq ptr %v78, null
  br i1 %v79, label %L25, label %L26
L25:
  call void @pas_runtime_error(ptr @s455)
  unreachable
L26:
  %v80 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v78, i32 0, i32 24
  %v81 = load i32, ptr %v80
  %v82 = icmp eq i32 %v81, 0
  br i1 %v82, label %L27, label %L28
L27:
  %v83 = getelementptr inbounds %frame88, ptr %frame, i32 0, i32 2
  %v84 = load ptr, ptr %v83
  %v85 = icmp eq ptr %v84, null
  br i1 %v85, label %L29, label %L30
L29:
  call void @pas_runtime_error(ptr @s456)
  unreachable
L30:
  %v86 = getelementptr inbounds { i32, ptr, ptr, ptr, ptr, i1, i1, i1, i1, i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i1, ptr, ptr, i1, i32, i1, i32, i32, i32, i32, i1, ptr, ptr, ptr, i32, ptr, ptr, i1, i1, ptr, ptr }, ptr %v84, i32 0, i32 24
  %v87 = load i32, ptr %v86
  %v88 = icmp eq i32 %v87, 0
  br label %L28
L28:
  %v89 = phi i1 [ false, %L26 ], [ %v88, %L30 ]
  br i1 %v89, label %L31, label %L32
L31:
  call void @pas_write_str(ptr @pas.output, ptr @s457, i32 61, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s458, i32 60, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s459, i32 4, i32 -1)
  br label %L33
L32:
  call void @pas_write_str(ptr @pas.output, ptr @s460, i32 60, i32 -1)
  call void @pas_write_str(ptr @pas.output, ptr @s461, i32 14, i32 -1)
  br label %L33
L33:
  br label %L24
L24:
  br label %L7
L7:
  ret void
}

@s1 = private unnamed_addr constant [7 x i8] c"ircode\00"
@s2 = private unnamed_addr constant [8 x i8] c"imports\00"
@s3 = private unnamed_addr constant [1 x i8] c"\00"
@s4 = private unnamed_addr constant [1 x i8] c"\00"
@s5 = private unnamed_addr constant [28 x i8] c"value out of range (strlen)\00"
@s6 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s7 = private unnamed_addr constant [28 x i8] c"value out of range (strlen)\00"
@s8 = private unnamed_addr constant [35 x i8] c"array index out of bounds (1..255)\00"
@s9 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s10 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s11 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s12 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s13 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s14 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s15 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s16 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s17 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s18 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s19 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s20 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s21 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s22 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s23 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s24 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s25 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s26 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s27 = private unnamed_addr constant [8 x i8] c" error \00"
@s28 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s29 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s30 = private unnamed_addr constant [10 x i8] c": error: \00"
@s31 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s32 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s33 = private unnamed_addr constant [10 x i8] c" warning \00"
@s34 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s35 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s36 = private unnamed_addr constant [12 x i8] c": warning: \00"
@s37 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s38 = private unnamed_addr constant [42 x i8] c"out of string space: this compiler keeps \00"
@s39 = private unnamed_addr constant [35 x i8] c"a field width must not be negative\00"
@s40 = private unnamed_addr constant [20 x i8] c" characters of text\00"
@s41 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s42 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s43 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s44 = private unnamed_addr constant [35 x i8] c"array index out of bounds (1..255)\00"
@s45 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s46 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s47 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s48 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s49 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s50 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s51 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s52 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s53 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s54 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s55 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s56 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s57 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s58 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s59 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s60 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s61 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s62 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s63 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s64 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s65 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s66 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s67 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s68 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s69 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s70 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s71 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s72 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s73 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s74 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s75 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s76 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s77 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s78 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s79 = private unnamed_addr constant [10 x i8] c"frame    \00"
@s80 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s81 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s82 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s83 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s84 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s85 = private unnamed_addr constant [10 x i8] c"ownrel   \00"
@s86 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s87 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s88 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s89 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s90 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s91 = private unnamed_addr constant [10 x i8] c"pas_     \00"
@s92 = private unnamed_addr constant [10 x i8] c"main     \00"
@s93 = private unnamed_addr constant [10 x i8] c"_setjmp  \00"
@s94 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s95 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s96 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s97 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s98 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s99 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s100 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s101 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s102 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s103 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s104 = private unnamed_addr constant [33 x i8] c"array index out of bounds (1..9)\00"
@s105 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s106 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s107 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s108 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s109 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s110 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s111 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s112 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s113 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s114 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s115 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s116 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..16)\00"
@s117 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s118 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s119 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s120 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s121 = private unnamed_addr constant [39 x i8] c"array index out of bounds (1..1000000)\00"
@s122 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s123 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s124 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s125 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s126 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s127 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s128 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s129 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s130 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s131 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s132 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s133 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s134 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s135 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s136 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s137 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s138 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s139 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s140 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s141 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s142 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s143 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s144 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s145 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s146 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s147 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s148 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s149 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s150 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s151 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s152 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s153 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s154 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s155 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s156 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s157 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s158 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s159 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s160 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s161 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s162 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s163 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s164 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s165 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s166 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s167 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s168 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s169 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s170 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s171 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s172 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s173 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s174 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s175 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s176 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s177 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s178 = private unnamed_addr constant [42 x i8] c"the right operand of mod must be positive\00"
@s179 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s180 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s181 = private unnamed_addr constant [17 x i8] c"division by zero\00"
@s182 = private unnamed_addr constant [24 x i8] c"integer overflow in div\00"
@s183 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..12)\00"
@s184 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s185 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s186 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s187 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s188 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s189 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s190 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s191 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s192 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s193 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s194 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s195 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s196 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s197 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s198 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s199 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s200 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s201 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s202 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s203 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s204 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s205 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s206 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s207 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s208 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s209 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s210 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s211 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s212 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s213 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s214 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s215 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s216 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s217 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s218 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s219 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s220 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s221 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s222 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s223 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s224 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s225 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s226 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s227 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s228 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s229 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s230 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s231 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s232 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s233 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s234 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s235 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s236 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s237 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s238 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s239 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s240 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s241 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s242 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s243 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s244 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s245 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s246 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s247 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s248 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s249 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s250 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s251 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s252 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s253 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s254 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s255 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s256 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s257 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s258 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s259 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s260 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s261 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s262 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s263 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s264 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s265 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s266 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s267 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s268 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s269 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s270 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s271 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s272 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s273 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s274 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s275 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s276 = private unnamed_addr constant [36 x i8] c"case: no label matches the selector\00"
@s277 = private unnamed_addr constant [5 x i8] c"type\00"
@s278 = private unnamed_addr constant [8 x i8] c"numeric\00"
@s279 = private unnamed_addr constant [8 x i8] c"ordinal\00"
@s280 = private unnamed_addr constant [8 x i8] c"ordered\00"
@s281 = private unnamed_addr constant [10 x i8] c"equatable\00"
@s282 = private unnamed_addr constant [36 x i8] c"case: no label matches the selector\00"
@s283 = private unnamed_addr constant [52 x i8] c"integer, int64, real, complex, or a subrange of one\00"
@s284 = private unnamed_addr constant [45 x i8] c"integer, char, boolean, an enumerated type, \00"
@s285 = private unnamed_addr constant [21 x i8] c"or a subrange of one\00"
@s286 = private unnamed_addr constant [50 x i8] c"any ordinal type, and int64, real, a string-type \00"
@s287 = private unnamed_addr constant [9 x i8] c"and utf8\00"
@s288 = private unnamed_addr constant [52 x i8] c"any ordinal type, and int64, real, complex, a set, \00"
@s289 = private unnamed_addr constant [52 x i8] c"a pointer that is not owned, a string-type and utf8\00"
@s290 = private unnamed_addr constant [36 x i8] c"case: no label matches the selector\00"
@s291 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s292 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s293 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s294 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s295 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s296 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s297 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s298 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s299 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s300 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s301 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s302 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s303 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s304 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s305 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s306 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s307 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s308 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s309 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s310 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s311 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s312 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s313 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s314 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s315 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s316 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s317 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s318 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s319 = private unnamed_addr constant [22 x i8] c"integer overflow in -\00"
@s320 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s321 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s322 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s323 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s324 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s325 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s326 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s327 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s328 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s329 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s330 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s331 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s332 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s333 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s334 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s335 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s336 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s337 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s338 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s339 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s340 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s341 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s342 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s343 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s344 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s345 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s346 = private unnamed_addr constant [34 x i8] c"array index out of bounds (1..32)\00"
@s347 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s348 = private unnamed_addr constant [41 x i8] c"chr: argument is not a character ordinal\00"
@s349 = private unnamed_addr constant [17 x i8] c"chr(            \00"
@s350 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s351 = private unnamed_addr constant [17 x i8] c"true            \00"
@s352 = private unnamed_addr constant [17 x i8] c"false           \00"
@s353 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s354 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s355 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s356 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s357 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s358 = private unnamed_addr constant [22 x i8] c"integer overflow in +\00"
@s359 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s360 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s361 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s362 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s363 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s364 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s365 = private unnamed_addr constant [17 x i8] c"integer         \00"
@s366 = private unnamed_addr constant [17 x i8] c"int64           \00"
@s367 = private unnamed_addr constant [17 x i8] c"real            \00"
@s368 = private unnamed_addr constant [17 x i8] c"complex         \00"
@s369 = private unnamed_addr constant [17 x i8] c"restricted      \00"
@s370 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s371 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s372 = private unnamed_addr constant [17 x i8] c"string          \00"
@s373 = private unnamed_addr constant [17 x i8] c"string(         \00"
@s374 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s375 = private unnamed_addr constant [17 x i8] c")               \00"
@s376 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s377 = private unnamed_addr constant [17 x i8] c"utf8            \00"
@s378 = private unnamed_addr constant [17 x i8] c"utf8(           \00"
@s379 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s380 = private unnamed_addr constant [17 x i8] c")               \00"
@s381 = private unnamed_addr constant [17 x i8] c"boolean         \00"
@s382 = private unnamed_addr constant [17 x i8] c"char            \00"
@s383 = private unnamed_addr constant [17 x i8] c"void            \00"
@s384 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s385 = private unnamed_addr constant [17 x i8] c",               \00"
@s386 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s387 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s388 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s389 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s390 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s391 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s392 = private unnamed_addr constant [17 x i8] c"..              \00"
@s393 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s394 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s395 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s396 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s397 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s398 = private unnamed_addr constant [17 x i8] c"owned           \00"
@s399 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s400 = private unnamed_addr constant [17 x i8] c"nil             \00"
@s401 = private unnamed_addr constant [17 x i8] c"array of        \00"
@s402 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s403 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s404 = private unnamed_addr constant [17 x i8] c"handle external \00"
@s405 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s406 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s407 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s408 = private unnamed_addr constant [17 x i8] c"text            \00"
@s409 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s410 = private unnamed_addr constant [17 x i8] c"file [          \00"
@s411 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s412 = private unnamed_addr constant [17 x i8] c"] of            \00"
@s413 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s414 = private unnamed_addr constant [17 x i8] c"file of         \00"
@s415 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s416 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s417 = private unnamed_addr constant [17 x i8] c"[]              \00"
@s418 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s419 = private unnamed_addr constant [17 x i8] c"packed set of   \00"
@s420 = private unnamed_addr constant [17 x i8] c"set of          \00"
@s421 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s422 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s423 = private unnamed_addr constant [17 x i8] c"procedure       \00"
@s424 = private unnamed_addr constant [17 x i8] c"function        \00"
@s425 = private unnamed_addr constant [17 x i8] c"returning       \00"
@s426 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s427 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s428 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s429 = private unnamed_addr constant [17 x i8] c" !              \00"
@s430 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s431 = private unnamed_addr constant [17 x i8] c"record          \00"
@s432 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s433 = private unnamed_addr constant [17 x i8] c",               \00"
@s434 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s435 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s436 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s437 = private unnamed_addr constant [17 x i8] c" end            \00"
@s438 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s439 = private unnamed_addr constant [17 x i8] c"packed array [  \00"
@s440 = private unnamed_addr constant [17 x i8] c"array [         \00"
@s441 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s442 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s443 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s444 = private unnamed_addr constant [17 x i8] c"..              \00"
@s445 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s446 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s447 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s448 = private unnamed_addr constant [17 x i8] c"] of            \00"
@s449 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s450 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s451 = private unnamed_addr constant [36 x i8] c"case: no label matches the selector\00"
@s452 = private unnamed_addr constant [35 x i8] c"array index out of bounds (1..255)\00"
@s453 = private unnamed_addr constant [35 x i8] c"array index out of bounds (1..255)\00"
@s454 = private unnamed_addr constant [34 x i8] c"; the two are written alike, but \00"
@s455 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s456 = private unnamed_addr constant [19 x i8] c"dereference of nil\00"
@s457 = private unnamed_addr constant [62 x i8] c"6.4.1 makes each type-denoter that is not a type name denote \00"
@s458 = private unnamed_addr constant [61 x i8] c"a type of its own, so declare one named type and give it to \00"
@s459 = private unnamed_addr constant [5 x i8] c"both\00"
@s460 = private unnamed_addr constant [61 x i8] c"each was defined separately and 6.4.1 makes the definitions \00"
@s461 = private unnamed_addr constant [15 x i8] c"distinct types\00"
@pas.output = external global i8

declare void @pas_runtime_error(ptr)
declare void @pas_args(i32, ptr)
declare void @pas_file_init(ptr, i32, i32, ptr, i32, i32, i32, i32)
declare void @pas_file_done(ptr)
declare void @pas_defer_init(ptr, ptr, ptr)
declare void @pas_defer_done(ptr)
declare void @pas_handle_init(ptr, ptr)
declare i32 @pas_chan_close(ptr)
declare ptr @pas_chan_new(i64, i64)
declare void @pas_chan_ref(ptr)
declare i32 @pas_chan_unref(ptr)
declare void @pas_chan_send(ptr, ptr)
declare ptr @llvm.stacksave.p0()
declare void @llvm.stackrestore.p0(ptr)
declare i32 @pas_chan_receive(ptr, ptr)
declare void @pas_tasks_init(ptr)
declare ptr @pas_tasks_alloc(i64)
declare void @pas_tasks_spawn(ptr, ptr, ptr)
declare void @pas_tasks_join(ptr)
declare void @pas_handle_done(ptr)
declare void @pas_handle_set(ptr, ptr)
declare ptr @pas_handle_lend(ptr)
declare i32 @pas_handle_release_result(ptr)
declare ptr @pas_handle_take(ptr)
declare ptr @pas_jump_env(ptr)
declare void @pas_jump_done(ptr)
declare void @pas_jump_go(ptr, i32)
declare i32 @_setjmp(ptr) #0
attributes #0 = { returns_twice }
declare void @pas_reset(ptr)
declare void @pas_rewrite(ptr)
declare void @pas_get(ptr)
declare void @pas_put(ptr)
declare ptr @pas_buffer(ptr)
declare ptr @pas_new(i64)
declare void @pas_dispose(ptr)
declare void @pas_write_int(ptr, i64, i32)
declare void @pas_write_real(ptr, double, i32, i32)
declare void @pas_write_bool(ptr, i32, i32)
declare void @pas_write_char(ptr, i8, i32)
declare void @pas_write_str(ptr, ptr, i32, i32)
declare void @pas_writeln(ptr)
declare void @pas_page(ptr)
declare i8 @pas_read_char(ptr)
declare double @pas_read_real(ptr)
declare i64 @pas_read_int(ptr)
declare i64 @pas_read_int64(ptr)
declare void @pas_readln(ptr)
declare i32 @pas_eof(ptr)
declare i32 @pas_eoln(ptr)
declare i32 @pas_str_compare(ptr, ptr, i32)
declare double @pas_pow_real(double, double)
declare double @pas_pow_realint(double, i32)
declare i32 @pas_pow_int(i32, i32)
declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)
declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)
declare i32 @llvm.abs.i32(i32, i1)
declare double @llvm.fabs.f64(double)
declare double @llvm.sqrt.f64(double)
declare double @llvm.sin.f64(double)
declare double @llvm.cos.f64(double)
declare double @llvm.log.f64(double)
declare double @llvm.exp.f64(double)
declare double @pas_atan(double)
declare ptr @pas_str_char(i8)
declare ptr @pas_str_concat(ptr, i32, ptr, i32)
declare ptr @pas_str_cstr(ptr, i32)
declare i32 @pas_cstr_take(ptr, i32, ptr)
declare i32 @pas_rec_take(ptr, i64, ptr)
declare void @pas_slice_check(i32, i32, i32)
@pas_str_at = external thread_local global i32
declare i32 @pas_str_cmp_pad(ptr, i32, ptr, i32)
declare i32 @pas_str_cmp_exact(ptr, i32, ptr, i32)
declare i32 @pas_str_trimlen(ptr, i32)
declare i32 @pas_str_index(ptr, i32, ptr, i32)
declare void @pas_str_slice_check(i32, i32, i32)
declare void @pas_str_substr_check(i32, i32, i32, i32)
declare void @pas_str_store_fixed(ptr, i32, ptr, i32)
declare ptr @pas_str_pad(i32, ptr, i32)
declare ptr @pas_str_read_begin(ptr, i32)
declare void @pas_str_read_end(ptr)
declare ptr @pas_str_write_begin()
declare i32 @pas_str_write_len(ptr)
declare ptr @pas_str_write_ptr(ptr)
declare void @pas_str_write_end(ptr)
declare void @pas_str_store_var(ptr, i32, ptr, i32)
declare void @pas_text_store(ptr, i32, ptr, i32)
declare i32 @pas_text_length(ptr, i32)
declare ptr @pas_text_concat(ptr, i32, ptr, i32)
declare void @pas_text_take(ptr, i32, ptr, i32)
declare i32 @pas_text_boundary(ptr, i32, i32)
declare i32 @pas_text_cmp(ptr, i32, ptr, i32, i32)
declare void @pas_write_text(ptr, ptr, i32, i32)
declare void @pas_str_store_char(ptr, ptr, i32)
declare void @pas_read_str(ptr, ptr, i32, i32)
declare void @pas_bind(ptr, ptr, i32)
declare void @pas_unbind(ptr)
declare void @pas_halt(i32)
declare i32 @pas_binding_bound(ptr)
declare i32 @pas_binding_writable(ptr)
declare ptr @pas_binding_name(ptr)
declare i32 @pas_argcount()
declare ptr @pas_argument(i32)
declare i32 @pas_argument_len(i32)
declare i32 @pas_binding_namelen(ptr)
declare void @pas_gettimestamp()
declare i32 @pas_timestamp_field(i32)
declare ptr @pas_date(i32, i32, i32)
declare ptr @pas_time(i32, i32, i32)
declare void @pas_seekread(ptr, i32)
declare void @pas_seekwrite(ptr, i32)
declare void @pas_seekupdate(ptr, i32)
declare void @pas_update(ptr)
declare void @pas_extend(ptr)
declare i32 @pas_position(ptr)
declare i32 @pas_lastposition(ptr)
declare i32 @pas_empty(ptr)
declare double @pas_hypot(double, double)
declare double @pas_atan2(double, double)
declare double @pas_csqrt_re(double, double)
declare double @pas_csqrt_im(double, double)
declare double @pas_cexp_re(double, double)
declare double @pas_cexp_im(double, double)
declare double @pas_cln_re(double, double)
declare double @pas_cln_im(double, double)
declare double @pas_csin_re(double, double)
declare double @pas_csin_im(double, double)
declare double @pas_ccos_re(double, double)
declare double @pas_ccos_im(double, double)
declare double @pas_carctan_re(double, double)
declare double @pas_carctan_im(double, double)
declare double @pas_cpow_re(double, double, double)
declare double @pas_cpow_im(double, double, double)
declare double @pas_cpowi_re(double, double, i32)
declare double @pas_cpowi_im(double, double, i32)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)
declare void @llvm.memcpy.p0.p0.i32(ptr, ptr, i32, i1)
declare i256 @llvm.ctpop.i256(i256)
declare void @pas_index_error(i32, i32)
declare void @pas_range_error(i32, i32)
declare void @pas_disc_error(ptr, ptr, i32, i32)
declare void @pas_length_error(i32, i32)
