# Can we run a small model next to the TempleOS VM?

Yes. Measured, not estimated — all numbers below come from this container.

## Host

| | |
| --- | --- |
| CPU | Intel Xeon @ 2.30GHz, 4 cores, **AVX-512** (`avx2 avx512f f16c fma`) |
| GPU | none (`nvidia-smi` absent, no `/dev/dri`) |
| RAM | 16 GB total, ~14 GB free |
| Disk | ~28 GB free after both stacks installed |

## Result

`Qwen2.5-0.5B-Instruct`, Q8_0 GGUF, on llama.cpp built with `-DGGML_NATIVE=ON`:

```
| model         |     size |   params | backend | threads |  test |            t/s |
| qwen2 1B Q8_0 | 638.7MiB | 630.17 M | CPU     |       4 | pp128 | 1144.32 ±30.06 |
| qwen2 1B Q8_0 | 638.7MiB | 630.17 M | CPU     |       4 |  tg64 |    76.38 ± 1.40 |
```

- **76 tokens/s generated** — faster than a person reads.
- **1144 tokens/s prompt processing.**
- **~1.5 GB RSS** at the default 4096-token context; less with `-c 2048`.
- Runs happily **alongside the TempleOS VM** (QEMU sits at ~167 MB RSS). The two
  together use well under a fifth of available RAM.

Reproduce with `oracle/setup.sh` then `oracle/bench.sh`. For the full size
ladder and the memory ceiling, see [model-ceiling.md](model-ceiling.md).

## Quality caveat

A 0.5B is small. Asked *"You are an oracle. Answer in one short, cryptic
sentence. What should the programmer do next?"* it replied:

> Next, the programmer should search for bugs and fix them.

Serviceable, entirely un-cryptic. The persona is exactly the thing a fine-tune
would fix, so the weak baseline is an argument *for* the plan, not against it.

## Fine-tuning on this box

Inference is comfortable; training is the tighter constraint, because there is
no GPU.

- **LoRA on 0.5B: plausible.** Only a few million parameters train. Forward
  throughput is ~1100 tok/s and a backward pass costs roughly 2× forward, so a
  small corpus (~1000 short examples) should be minutes-to-hours per epoch
  rather than days. This needs measuring before it is promised.
- **Full fine-tune of 0.5B on 4 CPU cores: slow.** Possible, not pleasant.
- Requires the PyTorch/PEFT stack and the fp16 safetensors (~1 GB), not the
  GGUF. Train there, then convert and quantize back to GGUF for serving.

## Architectural constraint

**The model cannot run inside TempleOS.** TempleOS has 512 MB in this VM, a
single address space, no networking here, no BLAS, and no way to host a 640 MB
model. So the model runs on the host, and there are two honest options:

1. **Bridge at runtime** — TempleOS asks, host answers, over a shared channel
   (mounted disk image or a second ISO). Live, but needs plumbing, and TempleOS
   has no network stack to do it the easy way.
2. **Bake a corpus ahead of time** — generate oracle utterances on the host,
   ship them into the VM as a RedSea data file, and let a pure-HolyC oracle draw
   from that file the way Terry's draws from the dictionary.

Option 2 is closer in spirit to the original: the in-TempleOS side stays plain
HolyC, and the "improvement" is in what it draws from. It is also the one that
actually ships without a network stack.
