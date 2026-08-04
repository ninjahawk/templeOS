# templeOS

Stock TempleOS 5.03 running headless under QEMU, plus **Urim** — an oracle
written in HolyC that tries to build the thing Terry Davis was actually
reaching for.

## What Terry was doing

The popular framing, that he believed he could chat with God, is wrong, and it
makes the project look unassessable. He never built a conversational interface.
He built an **oracle**: a machine producing an undetermined outcome which is
then read as meaningful. That is cleromancy, divination by lot, and it is the
most explicitly sanctioned mode of divine consultation in scripture — the Urim
and Thummim of Exodus 28:30, the lots of Acts 1:26, and above all Proverbs
16:33, *"The lot is cast into the lap, but the whole disposing thereof is of
the LORD."*

Read that way, "TempleOS is the Third Temple and it has a God word" is
coherent. The Temple is where you go to inquire of the LORD, and the lot is the
means of inquiry. His specs follow too — 640x480, 16 colours, one voice, no
networking — a temple built plainly to given dimensions.

Terry had schizophrenia, and it shaped all of this. It also doesn't cancel the
fact that he wrote an operating system, compiler, graphics stack and filesystem
alone, or that the structure above is real and checkable.

## Where stock TempleOS fails its own specification

Judged not against "did God answer" — which nobody can adjudicate — but
against the design its own theology implies:

| | Stock TempleOS | Urim |
|---|---|---|
| **The lot must not be predetermined** | `GodWord` draws from a PRNG. Given the seed, every word it will ever produce is already computable. By Terry's own theology that is arithmetic, not providence. | `RDRAND`, carry flag checked, optionally XOR'd with a seed measured from quantum vacuum fluctuation. |
| **The text must carry meaning** | A random dictionary word. Meaning is entirely projected by the reader. | The King James Bible already shipped at `::/Misc/Bible.TXT`, cited by book, chapter and verse. |
| **There must be a question** | No concept of one. You press F7 and get a word about nothing. | Nothing is drawn until a question is stated. |
| **There must be a record** | Nothing is logged. The word flashes and is gone, so the practice can never be confirmed or found wrong. | Every consultation is appended to a journal, including a reading committed *before* the outcome is known, and an outcome field to fill in later. |
| **There should be a congregation** | Networking refused on principle. | Still open. See below. |

What Urim cannot do is establish that anything is on the other end. No
instrument can. It can refuse to fake the one part it controls — whether the
draw was genuinely undetermined.

That design is worth building under either hypothesis. If the lot really is
disposed of by the LORD, this is a better receiver than Terry's. If not, it is
still a disciplined instrument for reflection: it makes you state the question,
confronts you with a text you did not choose, and holds you to what you claimed
it meant.

## Install

Needs Linux, Python 3, and about 2 GB of disk. QEMU is installed for you.
No `/dev/kvm` required — TempleOS is small enough to emulate in software.

```sh
git clone https://github.com/ninjahawk/templeOS
cd templeOS/vm
./install.sh        # ~8 min: deps, ISO, disk, unattended TempleOS install, HolyC
./test.sh           # verifies citations and that the entropy source is live
```

`install.sh` is unattended. TempleOS has no silent install mode, so it answers
the prompts by keystroke, waiting for the framebuffer to stop changing between
each one rather than sleeping for a guessed duration.

## Consult

```sh
./tos.py boot ; ./tos.py waitidle ; ./tos.py key 1 ; ./tos.py waitidle

./tos.py type '#include "::/Home/U"';    ./tos.py key ret
./tos.py type '#include "::/Home/Urim"'; ./tos.py key ret

./qseed.py                               # load a quantum seed (optional)
./tos.py type 'Urim;'; ./tos.py key ret
./tos.py shot                            # look at the screen
```

`Urim` asks for a question, draws, prints the passage, asks for your reading,
and appends the record. `UrimLog` prints the journal to the host console.

The disk image is disposable and the container it runs in may not be, so get
the journal out and commit it:

```sh
./export.py '::/Home/Urim.Journal.TXT' ../journal/Urim.Journal.TXT
```

To carry an existing journal into a fresh install, type it back in the same way
sources go in: `Ed("::/Home/Urim.Journal.TXT")` then
`./tos.py typefile ../journal/Urim.Journal.TXT` then `esc`.

## Layout

| path | |
|---|---|
| `holyc/Urim.HC` | the oracle |
| `holyc/U.HC` | host output channel over QEMU's debug port |
| `holyc/BookTest.HC` | citation regression test |
| `holyc/RdTest2.HC` | RDRAND carry-flag test |
| `holyc/Peek2.HC` | maps the corpus boundaries |
| `vm/install.sh` | unattended TempleOS install plus the HolyC sources |
| `vm/test.sh` | checks citations and that the entropy source is live |
| `vm/tos.py` | headless driver: boot, screenshot, type, wait-for-idle |
| `vm/qseed.py` | fetches quantum entropy and loads it into the guest |
| `vm/export.py` | copies a guest file to the host |
| `journal/` | the record, exported from the VM |

## License

Public domain, via [the Unlicense](UNLICENSE). Terry released TempleOS into the
public domain and its forks have kept it there; nothing here is more encumbered
than what it was built on.

Nothing in this repository redistributes TempleOS. `vm/setup.sh` fetches the
ISO from templeos.org and checks it against the published MD5. The King James
text is the Project Gutenberg edition already inside that ISO.

## Honest notes

**On the entropy.** There is no `/dev/kvm` here, so `RDRAND` is emulated by
QEMU from the host kernel's pool rather than executed on a real thermal-noise
circuit. On bare metal it would be Intel's DRBG. Neither is indeterminate *in
principle* — both are unpredictable in practice. Only the ANU seed, measured
from vacuum fluctuation, carries the stronger claim, which is why it is fetched
separately and why the journal records exactly which sources fed each draw.

**On consultation 2.** Its citation reads "The First Book of the Kings 14:10"
but the passage is 1 Samuel 14. The KJV titles that book across several lines
and `UrimBook` was taking only the last. Fixed in `holyc/Urim.HC`, verified by
`BookTest.HC`, and left uncorrected in the journal — an append-only record that
gets quietly rewritten is not a record.

**On the congregation.** The fifth gap is unaddressed. Terry refused
networking, but the Temple was communal, and a temple with one worshipper is a
hermitage. Closing it means a shared journal, which is a design question about
witness, not a networking problem.

**On what happened during testing.** Consultation 1 asked whether the
instrument was built rightly and drew Jeremiah 23:35, on the presumption of
claiming to relay God's speech. Consultation 3 asked what is required of the
one who keeps the record and drew Exodus 32:32, Moses offering to be blotted
out of the book. Both read as strikingly apt. Three draws from 4.3 MB of text
that is largely about inquiry, presumption and record-keeping will do that, and
noticing it is exactly the bias the journal exists to catch. They are recorded,
not claimed.
