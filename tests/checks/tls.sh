#!/bin/bash
# PasTls against a real TLS server, and its transcribed header constants
# against OpenSSL's own headers (ADR-0264).
#
# **Why this is a check and not a case under `tests/dialect/`.** Two things
# have to be present and neither is a documented dependency of this
# repository: libssl to link against, and the `openssl` program to be the far
# end. `tests/run_test.sh` cannot skip -- it compiles and compares, so a
# machine without either would report a compilation failure and read as a
# defect in the compiler. This decides instead, and skips 77. `TLS_REQUIRE` is
# how a CI job refuses to pass by skipping, as TARGET_SIZES_REQUIRE and
# UNICODE_CONFORMANCE_REQUIRE do.
#
# **It asks two questions and they are different in kind.**
#
# The first is the ordinary one: a program using the module talks to a server,
# and what it printed is compared with a golden. What makes it worth having is
# the *negative* half -- a certificate no anchor knows, and a certificate whose
# chain is perfect and whose name is wrong. A TLS client that verifies wrongly
# is worse than one that does not verify at all, and the second of those is the
# case a client checking only the chain gets wrong. Two servers are started for
# exactly that: one presenting a certificate for `localhost`, one presenting a
# certificate for a name nobody asked for.
#
# The second is a question no golden could answer. Six of the values
# `lib/dialect/pastls.pas` passes to OpenSSL are **transcribed from headers**,
# because each is a macro or a bare `#define` and this language cannot reach
# one: SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name,
# SSL_CTRL_SET_MIN_PROTO_VERSION, TLS1_2_VERSION, SSL_VERIFY_PEER and X509_V_OK.
# A wrong one does not fail loudly -- `SSL_ctrl` with a command it does not
# know answers 0, and the module reports a refusal; a wrong SSL_VERIFY_PEER
# would leave verification *off* and every case here would still pass. So a C
# program including OpenSSL's own headers prints what they say, and the Pascal
# source is read for what it claims. That is `foreign-layout`'s shape (ADR-0185)
# applied to constants rather than to offsets, and it is the half of this
# module that nothing else can see.
#
# **The goldens hold nothing OpenSSL wrote.** A reason string is that library's
# wording and moves between releases; so does the cipher list on the status
# page. What the program prints is what *this module* decided.
#
#   usage: tls.sh <pascalcc> [<pascalc>]
set -u

pascalcc=${1:?usage: tls.sh <pascalcc> [<pascalc>]}
pascalc=${2:-${PASCALC:-pascalc}}
root=$(cd "$(dirname "$0")/../.." && pwd)
here=$root/tests/checks/tls

skip() {
  if [[ -n ${TLS_REQUIRE:-} ]]; then
    echo "tls: $1, and TLS_REQUIRE is set" >&2
    exit 1
  fi
  echo "tls: $1 -- skipping" >&2
  exit 77
}

command -v clang >/dev/null || skip "no clang"
command -v openssl >/dev/null || skip "no openssl program"

work=$(mktemp -d)
servers=()
cleanup() {
  local pid
  for pid in ${servers[@]+"${servers[@]}"}; do kill "$pid" 2>/dev/null; done
  rm -rf "$work"
}
trap cleanup EXIT

# Is libssl here to link against? A three-line C program is the only honest
# way to ask: a header without a library, or a library without a header, are
# both "no" and neither is visible from a file test.
cat >"$work/have.c" <<'EOF'
#include <openssl/ssl.h>
int main(void) { return SSL_CTX_new(TLS_client_method()) == 0; }
EOF
clang "$work/have.c" -o "$work/have" -lssl -lcrypto 2>"$work/have.txt" ||
  skip "no libssl to link against"

# --- 1. the transcribed constants ----------------------------------------
#
# What the headers say, printed by a program that includes them.
cat >"$work/consts.c" <<'EOF'
#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/tls1.h>
#include <openssl/x509_vfy.h>
int main(void) {
  printf("CtrlSetHostName %d\n", SSL_CTRL_SET_TLSEXT_HOSTNAME);
  printf("NameTypeHost %d\n", TLSEXT_NAMETYPE_host_name);
  printf("CtrlSetMinProto %d\n", SSL_CTRL_SET_MIN_PROTO_VERSION);
  printf("VersionTls12 %d\n", TLS1_2_VERSION);
  printf("VerifyPeer %d\n", SSL_VERIFY_PEER);
  printf("VerifyOk %d\n", X509_V_OK);
  printf("ErrorZeroReturn %d\n", SSL_ERROR_ZERO_RETURN);
  printf("ErrorSyscall %d\n", SSL_ERROR_SYSCALL);
  return 0;
}
EOF
clang "$work/consts.c" -o "$work/consts" -lssl -lcrypto 2>"$work/consts.txt" ||
  { echo "tls: the constant probe did not build" >&2
    cat "$work/consts.txt" >&2; exit 1; }
"$work/consts" >"$work/header.txt" || exit 1

# ...and what the module claims. The const-part is read by name, so a constant
# renamed in the source is a constant this check stops seeing -- which is why
# the count is compared as well. Eight names, eight rows, or this fails.
sed -n 's/^  \([A-Za-z][A-Za-z0-9]*\) = \([0-9]*\);.*{ *\(SSL_\|TLS\|X509_\).*$/\1 \2/p' \
    "$root/lib/dialect/pastls.pas" >"$work/claimed.txt"

if ! diff -u "$work/header.txt" "$work/claimed.txt" >"$work/consts.diff"; then
  echo "tls: lib/dialect/pastls.pas disagrees with OpenSSL's headers" >&2
  echo "     (left: the header; right: what the module transcribed)" >&2
  cat "$work/consts.diff" >&2
  exit 1
fi
n=$(wc -l <"$work/claimed.txt")
if [[ $n -ne 8 ]]; then
  echo "tls: expected 8 transcribed constants, read $n from pastls.pas" >&2
  echo "     a renamed constant is one this check stops looking at" >&2
  exit 1
fi
echo "tls: $n transcribed constants agree with OpenSSL's headers"

# --- 2. two servers, two certificates ------------------------------------
#
# The first is for `localhost` and is what a good connection uses. The second
# is for a name nobody will ask for, and is the chain-is-right-name-is-wrong
# case. Both are self-signed, which is the point: a self-signed certificate is
# its own trust anchor, so `TlsConnectTrusting` reaches it and `TlsConnect` -- which
# consults the system's anchors -- must not.
# The second certificate must **not** name localhost, or the case it exists
# for proves nothing: what is being asked is whether a chain that verifies is
# accepted for a host it does not name.
for pair in "good:localhost" "bad:other.example"; do
  tag=${pair%%:*}; cn=${pair##*:}
  openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
          -keyout "$work/$tag.key" -out "$work/$tag.pem" \
          -subj "/CN=$cn" -addext "subjectAltName=DNS:$cn" \
          >/dev/null 2>&1 || skip "openssl req refused to make a certificate"
done

# What the good server serves. `-WWW` answers `GET /hello` with this file and
# nothing else, which is what keeps the goldens below free of anything OpenSSL
# wrote: `-www`'s status page lists the ciphers the library was built with, and
# is longer than `PasHttp`'s own `MaxBodyLines`. Three short lines, no
# Content-Length, so RFC 9112 §6.3 rule 6 frames the body -- the shape only
# `PasHttp.FeedEnd` completes.
mkdir -p "$work/www"
printf 'hello, TLS!\nthis body is framed by the close.\nthree lines is enough.\n' \
  >"$work/www/hello"

# A free port, asked for rather than assumed: a fixed number is a test that
# fails on a machine where something else holds it.
# Sets `port` -- not by writing it to standard output, because a command
# substitution is a subshell and the server started inside one would outlive
# this script with nothing holding its pid.
port=
start_server() {
  local tag=$1 p pid i
  for p in $(seq 24433 24473); do
    ( cd "$work/www" &&
      exec openssl s_server -accept "$p" \
           -cert "$work/$tag.pem" -key "$work/$tag.key" -WWW ) \
      >"$work/$tag.log" 2>&1 </dev/null &
    pid=$!
    for i in $(seq 1 50); do
      sleep 0.1
      kill -0 "$pid" 2>/dev/null || break
      if exec 3<>"/dev/tcp/127.0.0.1/$p" 2>/dev/null; then
        exec 3>&-
        servers+=("$pid")
        port=$p
        return 0
      fi
    done
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  return 1
}

start_server good || skip "no port would take a test server"
goodPort=$port
start_server bad || skip "no port would take a test server"
badPort=$port

# --- 3. the program ------------------------------------------------------
export PASCALC="$pascalc"
export AFTERSCHOOL_PASCAL_PATH="$root/lib/dialect"
export AFTERSCHOOL_PASCAL_LDFLAGS="-lssl -lcrypto"

for prog in tls_probe tls_https; do
  if ! "$pascalcc" "$here/$prog.pas" -o "$work/$prog" \
       >"$work/build.txt" 2>&1; then
    echo "tls: $prog.pas did not build" >&2
    cat "$work/build.txt" >&2
    exit 1
  fi
done

printf '%s\n%s\n%s\n%s\n' "$goodPort" "$badPort" \
       "$work/good.pem" "$work/bad.pem" >"$work/stdin.txt"
printf '%s\n%s\n' "$goodPort" "$work/good.pem" >"$work/https.txt"

if ! "$work/tls_probe" <"$work/stdin.txt" >"$work/got.txt" 2>"$work/err.txt"; then
  echo "tls: tls_probe exited non-zero" >&2
  cat "$work/err.txt" >&2
  cat "$work/got.txt" >&2
  exit 1
fi

# The golden is `.expected` and not `.out` deliberately: `selfhost/irtest.sh`
# sweeps every `.pas` under `tests/` and runs the ones that have an `.out` or
# an `.err`, which this one cannot be -- it needs two servers and a library
# nothing else here links. A source with neither is skipped there, which is
# how `target_layout.pas` and `foreign_layout_stat.pas` already sit under
# `tests/checks/`.
if ! diff -u "$here/tls_probe.expected" "$work/got.txt" >"$work/diff.txt"; then
  echo "tls: tls_probe did not print what was expected" >&2
  cat "$work/diff.txt" >&2
  exit 1
fi
echo "tls: the probe agrees with its golden"

# --- 3b. and the same grammar over the other transport -------------------
#
# `PasHttps` is `PasHttp`'s parser over `PasTls`'s transport (ADR-0265), and
# this is the only place a second transport is driven at all: everything else
# here reads a plain socket, so a grammar that had quietly kept a socket in it
# would pass every other case in the tree.
if ! "$work/tls_https" <"$work/https.txt" >"$work/https_got.txt" \
     2>"$work/https_err.txt"; then
  echo "tls: tls_https exited non-zero" >&2
  cat "$work/https_err.txt" >&2
  cat "$work/https_got.txt" >&2
  exit 1
fi
if ! diff -u "$here/tls_https.expected" "$work/https_got.txt" \
     >"$work/https_diff.txt"; then
  echo "tls: tls_https did not print what was expected" >&2
  cat "$work/https_diff.txt" >&2
  exit 1
fi
echo "tls: HTTP/1.1 over TLS agrees with its golden"

# --- 4. and the handles are released -------------------------------------
#
# Eleven connections are made above and every one of them holds three handles
# -- a socket, a context and a session -- released by the block that declared
# the record holding them (AP 6.4.12 NOTE 3). Nothing else here can see that a
# release did not happen: `heap-balance` counts `pas_new` against
# `pas_dispose` and OpenSSL allocates through neither. So the whole program is
# run a second time under LeakSanitizer, which can.
echo 'int main(void) { return 0; }' >"$work/san.c"
if clang -fsanitize=address "$work/san.c" -o "$work/sanprobe" 2>/dev/null; then
  mkdir -p "$work/sanlib"
  ok=1
  for u in pasrt pasrt_posix pasrt_unicode; do
    clang -fsanitize=address -O1 -I"$root/runtime" -c "$root/runtime/$u.c" \
          -o "$work/$u.o" 2>/dev/null || ok=0
  done
  if [[ $ok -eq 1 ]] &&
     ar rcs "$work/sanlib/libpasrt.a" "$work"/pasrt*.o 2>/dev/null; then
    AFTERSCHOOL_PASCAL_RUNTIME="$work/sanlib" \
    AFTERSCHOOL_PASCAL_CFLAGS="-fsanitize=address" \
      "$pascalcc" "$here/tls_probe.pas" -o "$work/tls_probe-san" \
      >"$work/sanbuild.txt" 2>&1 || ok=0
    if [[ $ok -eq 1 ]]; then
      if "$work/tls_probe-san" <"$work/stdin.txt" >/dev/null 2>"$work/san.txt"; then
        if grep -q 'LeakSanitizer\|ERROR: AddressSanitizer' "$work/san.txt"; then
          echo "tls: the sanitizer found something" >&2
          head -40 "$work/san.txt" >&2
          exit 1
        fi
        echo "tls: 11 connections made and released, and nothing leaked"
      else
        echo "tls: the probe failed under the sanitizer" >&2
        head -40 "$work/san.txt" >&2
        exit 1
      fi
    else
      echo "tls: no sanitized runtime, so the leak half was not asked"
    fi
  else
    echo "tls: no sanitized runtime, so the leak half was not asked"
  fi
else
  echo "tls: no AddressSanitizer, so the leak half was not asked"
fi
