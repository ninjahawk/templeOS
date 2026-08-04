# Contributing

## Getting a machine running

```sh
cd vm
./install.sh     # host deps, ISO, disk, unattended TempleOS install, HolyC sources
./test.sh        # verifies citations and that the entropy source is live
```

`install.sh` takes several minutes. There is no `/dev/kvm` in most containers
and CI runners, so QEMU emulates every instruction; TempleOS is small enough
that this is merely slow, not impractical.

## Working on HolyC

Sources live in `holyc/` and are the artifact of record. The copies inside the
VM are disposable, and so is the disk image — everything is rebuildable from
`vm/install.sh`.

The edit loop is:

```sh
./tos.py type 'Del("::/Home/Urim.HC");' ; ./tos.py key ret
./tos.py type 'Ed("::/Home/Urim.HC");'  ; ./tos.py key ret
./tos.py typefile ../holyc/Urim.HC      ; ./tos.py key esc
./tos.py boot                            # reboot before recompiling
```

Reboot before re-including a file you changed. A failed compile leaves partial
declarations behind, and the next attempt reports `Fun header args mismatch`
against a definition that is actually fine.

Verify a file arrived intact rather than assuming — a dropped keystroke will
otherwise sit in a source file undetected:

```sh
./export.py '::/Home/Urim.HC' /tmp/rt.HC && diff ../holyc/Urim.HC /tmp/rt.HC
```

## HolyC is not C

Things that cost time here, in case they save you some:

- There is no `StrCat`. Use `CatPrint(dst,"fmt",...)`.
- Adjacent string literals do not concatenate. One call per fragment.
- Declare locals at the top of a function, not inside blocks.
- Call with parentheses inside expressions. Bare `Foo;` works as a statement
  only.
- `#include` compiles a file, but do not rely on a trailing bare call in it
  running. Call the function explicitly afterwards.
- `FileRead` raises a visible error on a missing file. Guard with `FileFind`.
- Terry's assembler predates `RDRAND`, so it goes in as
  `DU8 0x48,0x0F,0xC7,0xF0;`. `MOV U64 [&global],RAX` does assemble, which is
  how values come back out of an `asm` block.

## The journal is append-only

`journal/` holds real consultations. Do not rewrite entries, including wrong
ones — consultation 2 carries a citation produced by a bug that is now fixed,
and it stays. A record that gets quietly corrected cannot be used to check
anything, which defeats the reason the journal exists.

## Scope

The oracle's design follows from a stated premise: if the lot is genuinely
undetermined, the implementation has obligations. Changes that weaken those —
falling back to a PRNG when `RDRAND` fails, dropping the question, making the
journal optional — undo the point of the project rather than extend it.

The open problem is the fifth gap. Terry refused networking, but a temple with
one worshipper is a hermitage. Closing it is a design question about shared
witness, not a networking task.
