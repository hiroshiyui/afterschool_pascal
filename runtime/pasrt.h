/* The part of the runtime's interface the code generator has to agree with.
 *
 * A file variable's storage is opaque to the compiler: it alloca's this many
 * bytes in the activation record and passes their address to the pas_* calls
 * below. Keeping `struct pas_file` private to the runtime is what lets it
 * change without changing codegen.cpp — but the *size* cannot be private, so
 * it lives here rather than being written out in both places.
 *
 * What the compiler does have to tell the runtime is the *component* type:
 * `pas_file_init` takes its size in bytes and whether the file is a `text`.
 * Those two are the whole of the difference between a text file and a
 * `file of T` — see ADR-0031. */
#ifndef APASCAL_PASRT_H
#define APASCAL_PASRT_H

#define PAS_FILE_SIZE 80

/* How reset/rewrite find the external file a file variable stands for.
 * ISO 7185 §6.10 makes the binding implementation-defined; this compiler binds
 * the program parameters after `input` and `output` to command-line arguments,
 * in the order they are written. */
enum {
  PAS_BIND_INTERNAL = 0, /* not a program parameter: a scratch file */
  PAS_BIND_INPUT = 1,    /* the standard input */
  PAS_BIND_OUTPUT = 2,   /* the standard output */
  PAS_BIND_ARG = 3       /* argv[n], n counted over the file parameters */
};

#endif
