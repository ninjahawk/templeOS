# templeOS

A reproducible, headless [TempleOS](https://templeos.org) 5.03 VM on Linux/QEMU,
plus scripts to drive it and capture screenshots without a display attached.

TempleOS is Terry A. Davis's public-domain 64-bit operating system: ring-0 only,
single address space, 640×480 16-color, programmed in HolyC.

## Quick start

```bash
cd vm
./setup.sh      # install qemu + netpbm, fetch the ISO, create a 2G qcow2
./install.sh    # boot the live CD installer (interactive -- see below)
./run.sh        # boot the installed system from disk
```

`setup.sh` needs root for `apt-get`. Everything else runs as a normal user.

## Installing

`install.sh` boots the ISO, which is both the live CD and the installer. It is
interactive; the prompt sequence on 5.03 is:

| Prompt | Answer |
| --- | --- |
| `Install onto hard drive (y or n)?` | `y` |
| `Are you installing inside VMware, QEMU, VirtualBox or a similar virtual machine?` | `y` |
| *(auto-partitions, formats, copies ~44 MB to `C:`)* | wait ~2 min |
| `Reboot Now (y or n)?` | `n` |

Then stop that VM and start `./run.sh`. At the `TempleOS Boot Loader` menu pick
**1 (Drive C)**. First boot decompresses the dictionary and shows a Tip of the Day.

To skip the install entirely and just poke around, answer `n` to the first
prompt — the CD runs live, but nothing you write survives a reboot.

## Driving it headless

The VM runs with `-display none`, exposing:

- a **VNC** server on `127.0.0.1:5900` (`VNC_DISPLAY` in `env.sh`)
- a **QEMU HMP monitor** unix socket at `$VM_DIR/monitor.sock`

The monitor is what the helper scripts use, so no GUI is required:

```bash
python3 mon.py "info status"                  # query the VM
python3 mon.py "sendkey ret"                  # press a key
python3 type.py 'Dir;'                        # type a string, no Enter
python3 mon.py "sendkey ret"                  # ...then run it
./snap.sh desktop                             # framebuffer -> $VM_DIR/desktop.png
```

`type.py` handles shifted characters, so HolyC with quotes and parens works:

```bash
python3 type.py '"Hello from HolyC!\n";'
python3 mon.py "sendkey ret"
```

## Layout

| Path | Purpose |
| --- | --- |
| `vm/env.sh` | shared paths and knobs (`VM_DIR`, `VM_MEM`, `VNC_DISPLAY`) |
| `vm/setup.sh` | one-time host setup: QEMU, ISO download, disk creation |
| `vm/install.sh` | boot the live CD / installer |
| `vm/run.sh` | boot the installed system from disk |
| `vm/mon.py` | QEMU HMP monitor client |
| `vm/type.py` | ASCII → `sendkey` typist |
| `vm/snap.sh` | screenshot to PNG (via netpbm) |

The disk image, ISO and screenshots live in `$VM_DIR` (default `~/templeos-vm`)
and are deliberately kept out of the repo — see `.gitignore`.

## Notes

- **No KVM needed.** These scripts use plain TCG emulation, so they work in
  containers and CI where `/dev/kvm` is absent. Boot takes ~30 s instead of ~2 s.
- **512 MB RAM, 1 vCPU.** TempleOS is happiest small; it does not use SMP.
- **`if=ide`.** TempleOS has no AHCI/virtio drivers — the disk and CD must be IDE.
- **`-vga std`.** TempleOS drives plain VGA at 640×480.
- Beware `pkill -f qemu-system-x86_64`: the pattern matches the invoking shell's
  own command line and kills it. Use `pkill -x qemu-system-x86_64` instead.
