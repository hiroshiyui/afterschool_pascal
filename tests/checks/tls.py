#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal compiler written in Pascal.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

"""PasTls against a real TLS server, and its transcribed header constants
against OpenSSL's own headers (ADR-0264).

**Why this is a check and not a case under `tests/dialect/`.** Two things
have to be present and neither is a documented dependency of this
repository: libssl to link against, and the `openssl` program to be the far
end. `tests/run_test.sh` cannot skip -- it compiles and compares, so a
machine without either would report a compilation failure and read as a
defect in the compiler. This decides instead, and skips 77. `TLS_REQUIRE` is
how a CI job refuses to pass by skipping, as TARGET_SIZES_REQUIRE and
UNICODE_CONFORMANCE_REQUIRE do.

**It asks two questions and they are different in kind.**

The first is the ordinary one: a program using the module talks to a server,
and what it printed is compared with a golden. What makes it worth having is
the *negative* half -- a certificate no anchor knows, and a certificate whose
chain is perfect and whose name is wrong. A TLS client that verifies wrongly
is worse than one that does not verify at all, and the second of those is the
case a client checking only the chain gets wrong. Two servers are started for
exactly that: one presenting a certificate for `localhost`, one presenting a
certificate for a name nobody asked for.

The second is a question no golden could answer. Six of the values
`lib/dialect/pastls.pas` passes to OpenSSL are **transcribed from headers**,
because each is a macro or a bare `#define` and this language cannot reach
one: SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name,
SSL_CTRL_SET_MIN_PROTO_VERSION, TLS1_2_VERSION, SSL_VERIFY_PEER and X509_V_OK.
A wrong one does not fail loudly -- `SSL_ctrl` with a command it does not
know answers 0, and the module reports a refusal; a wrong SSL_VERIFY_PEER
would leave verification *off* and every case here would still pass. So a C
program including OpenSSL's own headers prints what they say, and the Pascal
source is read for what it claims. That is `foreign-layout`'s shape (ADR-0185)
applied to constants rather than to offsets, and it is the half of this
module that nothing else can see.

**The goldens hold nothing OpenSSL wrote.** A reason string is that library's
wording and moves between releases; so does the cipher list on the status
page. What the program prints is what *this module* decided.

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, on this tree and on every arm.

  usage: tls.py <pascalcc> [<pascalc>]
"""

import difflib
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Python block-buffers a redirected stdout where `echo` does not, so a line
# printed here would otherwise land after the output of a subprocess this
# script does not capture.
sys.stdout.reconfigure(line_buffering=True)

ROOT = Path(__file__).resolve().parent.parent.parent
HERE = ROOT / 'tests' / 'checks' / 'tls'

# The const-part is read by name: `  Name = 123;   { SSL_... }`. A constant
# renamed in the source is a constant this check stops seeing, which is why
# the count is compared as well.
CLAIMED = re.compile(
    r'^  ([A-Za-z][A-Za-z0-9]*) = ([0-9]*);.*\{ *(?:SSL_|TLS|X509_).*$')


def gnu_date(p):
    """`diff -u`'s header timestamp, so what this writes is still a unified
    diff a reader can hand to `patch`."""
    ns = p.stat().st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


def unified(a, b, pa, pb):
    return list(difflib.unified_diff(a, b, str(pa), str(pb),
                                     gnu_date(pa), gnu_date(pb)))


class Skip(Exception):
    pass


def skip(what):
    raise Skip(what)


def head(text, n):
    """`head -n`, over text that may not end in a newline."""
    lines = text.splitlines(keepends=True)
    return ''.join(lines[:n])


def start_server(work, tag, servers):
    """A free port, asked for rather than assumed: a fixed number is a test
    that fails on a machine where something else holds it."""
    for p in range(24433, 24474):
        log = open(work / ('%s.log' % tag), 'wb')
        devnull = open(os.devnull, 'rb')
        try:
            proc = subprocess.Popen(
                ['openssl', 's_server', '-accept', str(p),
                 '-cert', str(work / ('%s.pem' % tag)),
                 '-key', str(work / ('%s.key' % tag)), '-WWW'],
                cwd=str(work / 'www'),
                stdin=devnull, stdout=log, stderr=subprocess.STDOUT)
        finally:
            log.close()
            devnull.close()
        for _ in range(50):
            time.sleep(0.1)
            if proc.poll() is not None:
                break
            try:
                s = socket.create_connection(('127.0.0.1', p))
            except OSError:
                continue
            s.close()
            servers.append(proc)
            return p
        proc.kill()
        proc.wait()
    return None


def run(work, servers, pascalcc, pascalc):
    if shutil.which('clang') is None:
        skip('no clang')
    if shutil.which('openssl') is None:
        skip('no openssl program')

    # Is libssl here to link against? A three-line C program is the only
    # honest way to ask: a header without a library, or a library without a
    # header, are both "no" and neither is visible from a file test.
    (work / 'have.c').write_text(
        '#include <openssl/ssl.h>\n'
        'int main(void) { return SSL_CTX_new(TLS_client_method()) == 0; }\n')
    with open(work / 'have.txt', 'wb') as f:
        r = subprocess.run(['clang', str(work / 'have.c'),
                            '-o', str(work / 'have'), '-lssl', '-lcrypto'],
                           stderr=f)
    if r.returncode != 0:
        skip('no libssl to link against')

    # --- 1. the transcribed constants ------------------------------------
    #
    # What the headers say, printed by a program that includes them.
    (work / 'consts.c').write_text("""#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/tls1.h>
#include <openssl/x509_vfy.h>
int main(void) {
  printf("CtrlSetHostName %d\\n", SSL_CTRL_SET_TLSEXT_HOSTNAME);
  printf("NameTypeHost %d\\n", TLSEXT_NAMETYPE_host_name);
  printf("CtrlSetMinProto %d\\n", SSL_CTRL_SET_MIN_PROTO_VERSION);
  printf("VersionTls12 %d\\n", TLS1_2_VERSION);
  printf("VerifyPeer %d\\n", SSL_VERIFY_PEER);
  printf("VerifyOk %d\\n", X509_V_OK);
  printf("ErrorZeroReturn %d\\n", SSL_ERROR_ZERO_RETURN);
  printf("ErrorSyscall %d\\n", SSL_ERROR_SYSCALL);
  return 0;
}
""")
    with open(work / 'consts.txt', 'wb') as f:
        r = subprocess.run(['clang', str(work / 'consts.c'),
                            '-o', str(work / 'consts'), '-lssl', '-lcrypto'],
                           stderr=f)
    if r.returncode != 0:
        print('tls: the constant probe did not build', file=sys.stderr)
        sys.stderr.flush()
        sys.stderr.buffer.write((work / 'consts.txt').read_bytes())
        sys.stderr.buffer.flush()
        return 1
    with open(work / 'header.txt', 'wb') as f:
        r = subprocess.run([str(work / 'consts')], stdout=f)
    if r.returncode != 0:
        return 1

    # ...and what the module claims.
    claimed = []
    src = (ROOT / 'lib' / 'dialect' / 'pastls.pas').read_text().split('\n')
    for line in src:
        m = CLAIMED.match(line)
        if m:
            claimed.append('%s %s\n' % (m.group(1), m.group(2)))
    (work / 'claimed.txt').write_text(''.join(claimed))

    a = (work / 'header.txt').read_text().splitlines(keepends=True)
    if a != claimed:
        d = unified(a, claimed, work / 'header.txt', work / 'claimed.txt')
        print("tls: lib/dialect/pastls.pas disagrees with OpenSSL's headers",
              file=sys.stderr)
        print('     (left: the header; right: what the module transcribed)',
              file=sys.stderr)
        sys.stderr.writelines(d)
        return 1
    n = len(claimed)
    if n != 8:
        print('tls: expected 8 transcribed constants, read %d from '
              'pastls.pas' % n, file=sys.stderr)
        print('     a renamed constant is one this check stops looking at',
              file=sys.stderr)
        return 1
    print("tls: %d transcribed constants agree with OpenSSL's headers" % n)

    # --- 2. two servers, two certificates --------------------------------
    #
    # The first is for `localhost` and is what a good connection uses. The
    # second is for a name nobody will ask for, and is the
    # chain-is-right-name-is-wrong case. Both are self-signed, which is the
    # point: a self-signed certificate is its own trust anchor, so
    # `TlsConnectTrusting` reaches it and `TlsConnect` -- which consults the
    # system's anchors -- must not.
    # The second certificate must **not** name localhost, or the case it
    # exists for proves nothing: what is being asked is whether a chain that
    # verifies is accepted for a host it does not name.
    for tag, cn in (('good', 'localhost'), ('bad', 'other.example')):
        r = subprocess.run(
            ['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
             '-days', '2',
             '-keyout', str(work / ('%s.key' % tag)),
             '-out', str(work / ('%s.pem' % tag)),
             '-subj', '/CN=%s' % cn,
             '-addext', 'subjectAltName=DNS:%s' % cn],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if r.returncode != 0:
            skip('openssl req refused to make a certificate')

    # What the good server serves. `-WWW` answers `GET /hello` with this file
    # and nothing else, which is what keeps the goldens below free of anything
    # OpenSSL wrote: `-www`'s status page lists the ciphers the library was
    # built with, and is longer than `PasHttp`'s own `MaxBodyLines`. Three
    # short lines, no Content-Length, so RFC 9112 §6.3 rule 6 frames the body
    # -- the shape only `PasHttp.FeedEnd` completes.
    (work / 'www').mkdir(parents=True, exist_ok=True)
    (work / 'www' / 'hello').write_text(
        'hello, TLS!\nthis body is framed by the close.\n'
        'three lines is enough.\n')

    good_port = start_server(work, 'good', servers)
    if good_port is None:
        skip('no port would take a test server')
    bad_port = start_server(work, 'bad', servers)
    if bad_port is None:
        skip('no port would take a test server')

    # --- 3. the program --------------------------------------------------
    os.environ['PASCALC'] = pascalc
    os.environ['AFTERSCHOOL_PASCAL_PATH'] = str(ROOT / 'lib' / 'dialect')
    os.environ['AFTERSCHOOL_PASCAL_LDFLAGS'] = '-lssl -lcrypto'

    for prog in ('tls_probe', 'tls_https'):
        with open(work / 'build.txt', 'wb') as f:
            r = subprocess.run([pascalcc, str(HERE / ('%s.pas' % prog)),
                                '-o', str(work / prog)],
                               stdout=f, stderr=subprocess.STDOUT)
        if r.returncode != 0:
            print('tls: %s.pas did not build' % prog, file=sys.stderr)
            sys.stderr.flush()
            sys.stderr.buffer.write((work / 'build.txt').read_bytes())
            sys.stderr.buffer.flush()
            return 1

    (work / 'stdin.txt').write_text('%d\n%d\n%s\n%s\n' % (
        good_port, bad_port, work / 'good.pem', work / 'bad.pem'))
    (work / 'https.txt').write_text('%d\n%s\n' % (
        good_port, work / 'good.pem'))

    with open(work / 'stdin.txt', 'rb') as si, \
            open(work / 'got.txt', 'wb') as so, \
            open(work / 'err.txt', 'wb') as se:
        r = subprocess.run([str(work / 'tls_probe')],
                           stdin=si, stdout=so, stderr=se)
    if r.returncode != 0:
        print('tls: tls_probe exited non-zero', file=sys.stderr)
        sys.stderr.flush()
        sys.stderr.buffer.write((work / 'err.txt').read_bytes())
        sys.stderr.buffer.write((work / 'got.txt').read_bytes())
        sys.stderr.buffer.flush()
        return 1

    # The golden is `.expected` and not `.out` deliberately:
    # `selfhost/irtest.sh` sweeps every `.pas` under `tests/` and runs the ones
    # that have an `.out` or an `.err`, which this one cannot be -- it needs
    # two servers and a library nothing else here links. A source with neither
    # is skipped there, which is how `target_layout.pas` and
    # `foreign_layout_stat.pas` already sit under `tests/checks/`.
    exp = HERE / 'tls_probe.expected'
    got = work / 'got.txt'
    a = exp.read_text().splitlines(keepends=True)
    b = got.read_text().splitlines(keepends=True)
    if a != b:
        print('tls: tls_probe did not print what was expected',
              file=sys.stderr)
        sys.stderr.writelines(unified(a, b, exp, got))
        return 1
    print('tls: the probe agrees with its golden')

    # --- 3b. and the same grammar over the other transport ----------------
    #
    # `PasHttps` is `PasHttp`'s parser over `PasTls`'s transport (ADR-0265),
    # and this is the only place a second transport is driven at all:
    # everything else here reads a plain socket, so a grammar that had quietly
    # kept a socket in it would pass every other case in the tree.
    with open(work / 'https.txt', 'rb') as si, \
            open(work / 'https_got.txt', 'wb') as so, \
            open(work / 'https_err.txt', 'wb') as se:
        r = subprocess.run([str(work / 'tls_https')],
                           stdin=si, stdout=so, stderr=se)
    if r.returncode != 0:
        print('tls: tls_https exited non-zero', file=sys.stderr)
        sys.stderr.flush()
        sys.stderr.buffer.write((work / 'https_err.txt').read_bytes())
        sys.stderr.buffer.write((work / 'https_got.txt').read_bytes())
        sys.stderr.buffer.flush()
        return 1
    exp = HERE / 'tls_https.expected'
    got = work / 'https_got.txt'
    a = exp.read_text().splitlines(keepends=True)
    b = got.read_text().splitlines(keepends=True)
    if a != b:
        print('tls: tls_https did not print what was expected',
              file=sys.stderr)
        sys.stderr.writelines(unified(a, b, exp, got))
        return 1
    print('tls: HTTP/1.1 over TLS agrees with its golden')

    # --- 4. and the handles are released ---------------------------------
    #
    # Eleven connections are made above and every one of them holds three
    # handles -- a socket, a context and a session -- released by the block
    # that declared the record holding them (AP 6.4.12 NOTE 3). Nothing else
    # here can see that a release did not happen: `heap-balance` counts
    # `pas_new` against `pas_dispose` and OpenSSL allocates through neither.
    # So the whole program is run a second time under LeakSanitizer, which can.
    (work / 'san.c').write_text('int main(void) { return 0; }\n')
    r = subprocess.run(['clang', '-fsanitize=address', str(work / 'san.c'),
                        '-o', str(work / 'sanprobe')],
                       stderr=subprocess.DEVNULL)
    if r.returncode != 0:
        print('tls: no AddressSanitizer, so the leak half was not asked')
        return 0

    (work / 'sanlib').mkdir(parents=True, exist_ok=True)
    ok = True
    for u in ('pasrt', 'pasrt_posix', 'pasrt_unicode'):
        r = subprocess.run(
            ['clang', '-fsanitize=address', '-O1',
             '-I%s' % (ROOT / 'runtime'), '-c',
             str(ROOT / 'runtime' / ('%s.c' % u)),
             '-o', str(work / ('%s.o' % u))],
            stderr=subprocess.DEVNULL)
        if r.returncode != 0:
            ok = False
    if ok:
        objs = sorted(str(p) for p in work.glob('pasrt*.o'))
        r = subprocess.run(['ar', 'rcs', str(work / 'sanlib' / 'libpasrt.a')]
                           + objs, stderr=subprocess.DEVNULL)
        ar_ok = r.returncode == 0
    else:
        ar_ok = False
    if not (ok and ar_ok):
        print('tls: no sanitized runtime, so the leak half was not asked')
        return 0

    env = dict(os.environ)
    env['AFTERSCHOOL_PASCAL_RUNTIME'] = str(work / 'sanlib')
    env['AFTERSCHOOL_PASCAL_CFLAGS'] = '-fsanitize=address'
    with open(work / 'sanbuild.txt', 'wb') as f:
        r = subprocess.run([pascalcc, str(HERE / 'tls_probe.pas'),
                            '-o', str(work / 'tls_probe-san')],
                           stdout=f, stderr=subprocess.STDOUT, env=env)
    if r.returncode != 0:
        print('tls: no sanitized runtime, so the leak half was not asked')
        return 0

    with open(work / 'stdin.txt', 'rb') as si, \
            open(work / 'san.txt', 'wb') as se:
        r = subprocess.run([str(work / 'tls_probe-san')],
                           stdin=si, stdout=subprocess.DEVNULL, stderr=se)
    san = (work / 'san.txt').read_text(errors='replace')
    if r.returncode != 0:
        print('tls: the probe failed under the sanitizer', file=sys.stderr)
        sys.stderr.write(head(san, 40))
        return 1
    if 'LeakSanitizer' in san or 'ERROR: AddressSanitizer' in san:
        print('tls: the sanitizer found something', file=sys.stderr)
        sys.stderr.write(head(san, 40))
        return 1
    print('tls: 11 connections made and released, and nothing leaked')
    return 0


def main(argv):
    if len(argv) < 2:
        print('usage: tls.py <pascalcc> [<pascalc>]', file=sys.stderr)
        return 1
    pascalcc = argv[1]
    pascalc = argv[2] if len(argv) > 2 else os.environ.get('PASCALC',
                                                           'pascalc')

    work = Path(tempfile.mkdtemp())
    servers = []
    try:
        try:
            return run(work, servers, pascalcc, pascalc)
        except Skip as e:
            if os.environ.get('TLS_REQUIRE', ''):
                print('tls: %s, and TLS_REQUIRE is set' % e, file=sys.stderr)
                return 1
            print('tls: %s -- skipping' % e, file=sys.stderr)
            return 77
    finally:
        for proc in servers:
            try:
                proc.kill()
                proc.wait()
            except OSError:
                pass
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
