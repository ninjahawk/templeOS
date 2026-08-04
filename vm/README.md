# Headless TempleOS

Stock TempleOS 5.03 running under QEMU with no display attached, driven
entirely from a shell.

## Rebuild it

```sh
./setup.sh          # host deps, ISO (checksummed), blank disk
                    # then follow the printed install keystrokes once
./tos.py boot       # subsequently: boot the installed system
./tos.py key 1      # boot loader -> Drive C
```

## Drive it

```sh
./tos.py shot [name]      # framebuffer -> shots/<name>.png
./tos.py key ret a f7     # send keys
./tos.py type 'Dir;'      # type a literal string
./tos.py typefile x.HC    # type a whole source file into an open editor
./tos.py mark             # remember the current console.log length
./tos.py con              # print console output since the mark
./tos.py cmd 'info block' # raw QEMU monitor command
./tos.py stop
```

The CPU model is `max` rather than `qemu64`, which exposes `RDRAND` and
`RDSEED`. TCG implements both, backed by the host entropy pool. Terry's
assembler predates `RDRAND` by nine years, so `Urim.HC` emits the opcode as
raw bytes (`DU8 0x48,0x0F,0xC7,0xF0`).

Screenshots go through the QEMU monitor's `screendump`, so nothing needs a
display or a VNC client. Input goes in through `sendkey`.

## What this machine can and can't do

No `/dev/kvm` — the container is itself a VM and nested virtualisation isn't
exposed, so QEMU runs on TCG software emulation. For TempleOS this barely
matters: it boots in ~20s and holds ~29 FPS at 512 MB / 1 vCPU.

Getting files **in**: `./tos.py typefile <path>` types a source file into an
open `Ed()` window over the QEMU monitor. About 2.5 lines a second, and
verified by dumping the file back out and diffing.

Getting files **out** looked like the hard direction — TempleOS can't see ext4,
stock 5.03 has no networking, and RedSea has no Linux driver. The way through
is QEMU's debug console: `-debugcon file:console.log` captures every byte
written to I/O port `0xE9`, and TempleOS has `OutU8`. `holyc/U.HC` wraps that
into `UDump`, and `export.py` drives it to copy a guest file to the host.

Note: never truncate `console.log` while QEMU is running. QEMU keeps its own
write offset on that descriptor, so emptying the file leaves a sparse hole and
the next output shows up after a wall of NULs. Use `./tos.py mark` to record an
offset and `./tos.py con` to read forward from it.

## RedSea notes

The ISO advertises ISO 9660 and `file` believes it, but the volume descriptor
is malformed (the little- and big-endian root extents disagree) and real
ISO 9660 readers reject it. Underneath it is RedSea.

Directory entries are 64 bytes, and a directory's contents are just an array
of them. Its first entry is the directory itself, the second is `..`:

| offset | size | field |
|---|---|---|
| `0x00` | 1 | attributes — bit `0x10` means directory |
| `0x01` | 1 | flags (`0x08` seen on dirs, `0x0c` on files) |
| `0x02` | 38 | name, NUL-padded ASCII |
| `0x28` | 8 | starting cluster |
| `0x30` | 8 | size in bytes |
| `0x38` | 8 | date/time |

Clusters are 512 bytes and are absolute — byte offset is `cluster * 512`.
Confirmed against `/Adam/God`, whose entry gives cluster `0x612a`, and
`0x612a * 512 = 0xc25400`, exactly where its own entry array begins.

Most shipped files end in `.Z` and are compressed with Terry's own codec.
Header is `<i64 compressed_size><i64 expanded_size><u8 type>` followed by the
stream; `type` 2 is what the `.HC.Z` sources use. The stream is **not**
standard bit-packed LZW — literals stay byte-aligned and readable, so codes
are not 9-bit packed. Decoding it is still open.
