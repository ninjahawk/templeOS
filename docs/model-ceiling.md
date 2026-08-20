# How big a model can this host actually run?

All figures measured on this container with `llama-bench`, 4 threads, `-p 128
-n 64`. Host: 4-core Xeon @2.30GHz, AVX-512, ~14 GB usable RAM, **no GPU**.
Reproduce with `oracle/ladder.sh`.

## Single-stream results

| Model | Quant | Size | Generation (tok/s) | Prompt (tok/s) |
| --- | --- | ---: | ---: | ---: |
| Qwen2.5-0.5B | Q8_0 | 0.62 GiB | **76.4** | 1144 |
| Qwen2.5-1.5B | Q4_K_M | 1.04 GiB | 19.3 | 250 |
| Qwen2.5-1.5B | Q8_0 | 1.76 GiB | **24.2** | 329 |
| Qwen2.5-3B | Q4_K_M | 1.95 GiB | 10.3 | 119 |
| Qwen2.5-7B | Q4_K_M | 4.36 GiB | 4.8 | 57 |
| Qwen2.5-7B | Q8_0 | 7.54 GiB | **5.6** | 62 |
| Qwen2.5-14B | Q4_K_M | 8.37 GiB | 2.5 | 27 |

## Generation is bandwidth-bound, with two regimes

Multiply size by tok/s and the numbers collapse onto two constants:

| Quant | size × tok/s | |
| --- | ---: | --- |
| Q4_K_M | 20.1, 20.0, 20.8, 20.9 GiB/s | across 1.5B → 14B |
| Q8_0 | 47.4, 42.5, 42.5 GiB/s | across 0.5B → 7B |

So `tok/s ≈ 20.5 / size_GiB` for K-quants and `≈ 42.5 / size_GiB` for Q8_0.
Both hold within a few percent over a 13× size range, which makes them safe to
extrapolate from.

### Q8_0 beats Q4_K_M here — the counterintuitive part

On this box **Q8_0 is faster than Q4_K_M despite being ~73% larger**:

- 1.5B: Q8_0 24.2 tok/s vs Q4_K_M 19.3
- 7B: Q8_0 5.6 tok/s vs Q4_K_M 4.8

K-quant super-block dequantization costs real compute, and with only 4 cores
that cost outweighs the bandwidth saved. On a GPU or a many-core host the usual
ordering returns. Here, prefer Q8_0 whenever it fits in RAM — it is faster *and*
higher fidelity, and the only price is memory.

## The ceiling: 14B

RAM is the wall, at ~14 GB usable.

| Config | Size | Verdict |
| --- | ---: | --- |
| 7B Q8_0 | 7.5 GiB | fits comfortably — **5.6 tok/s** |
| 14B Q4_K_M | 8.4 GiB | fits, ~6 GB headroom left — **2.5 tok/s** |
| 14B Q8_0 | ~15.7 GiB | does not fit |
| 32B Q4_K_M | ~19 GiB | does not fit |

Above ~12 GiB the model exceeds RAM. llama.cpp mmaps weights, so an oversized
model still *starts* — it then pages every layer from disk on every token.
Expect something on the order of a token every several seconds; not a usable
regime. (Reasoned from disk throughput, not measured.)

**The interesting comparison is 14B-Q4 vs 7B-Q8 at nearly the same memory
budget** (8.4 vs 7.5 GiB): the 7B is **2.3× faster**. A 14B at Q4 is generally
the stronger model on benchmarks, so this is a real quality-vs-latency trade
rather than a free win.

## Batching changes the corpus math

Weights are read once per batch, not once per sequence, so generating many
outputs concurrently scales far better than single-stream. Qwen2.5-7B Q8_0,
`llama-batched-bench`:

| Concurrent seqs | Generation (tok/s) |
| ---: | ---: |
| 1 | 5.4 |
| 4 | 14.1 |
| 8 | 23.4 |
| 16 | **45.1** |

**8.4× at batch 16.** This matters because the corpus-baking architecture is
embarrassingly parallel — every oracle utterance is independent.

## What this means in practice

For a single ~30-token oracle line:

| Model | Latency |
| --- | ---: |
| 0.5B Q8_0 | 0.4 s |
| 1.5B Q8_0 | 1.2 s |
| 3B Q4_K_M | 2.9 s |
| 7B Q8_0 | 5.3 s |
| 14B Q4_K_M | 12 s |

For baking a corpus of 5,000 lines (~125k tokens) at batch 16:

| Model | Time |
| --- | ---: |
| 7B Q8_0 | ~45 min |
| 14B Q4_K_M | ~1.7 h (extrapolated at the same 8.4× batch gain) |

Both are overnight-trivial. Since the corpus is generated once and shipped into
TempleOS as a data file, **the quality ceiling matters far more than the speed
ceiling** — which argues for running the largest model that fits, 14B Q4_K_M, and
simply waiting.
