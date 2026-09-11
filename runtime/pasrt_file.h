/* Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
 * Copyright (C) 2026 Hui-Hong You
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* The one routine of `pasrt_file.c` that another unit calls (ADR-0405).
 *
 * Every `pasx_` routine is bound from Pascal by name and declared in C
 * nowhere, which is why this header did not exist before: the runtime's units
 * did not call one another. Splitting the file model out of `pasrt_posix.c`
 * left exactly one call across the cut -- `pasx_exec_getc` waits on a child's
 * pipe, and waiting on a descriptor is a question about a descriptor and
 * belongs on this side of it.
 *
 * **It is a header and not a prototype written into the caller** for the
 * reason a prototype is dangerous: C checks a call against whatever
 * declaration is in scope and the linker checks only the name, so a
 * declaration written beside the caller can disagree with the definition and
 * nothing says so. Both units include this, so the compiler compares the two.
 */

#ifndef PASRT_FILE_H
#define PASRT_FILE_H

int pasx_fd_ready(int fd, int timeout_ms);

#endif
