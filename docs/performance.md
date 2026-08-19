# VKMT performance and stability

## Invariants

- Native ARM64 host only; Rosetta is rejected.
- `FEX_TSOENABLED=0`, `FEX_VECTORTSOENABLED=0`, and
  `FEX_MEMCPYSETTSOENABLED=0` on every launcher path.
- Persistent translated-code and graphics caches are versioned per prefix.
- Provider or generation changes stop the exact wineserver and invalidate
  stale state before reuse.
- Hot-set prefetch is bounded, prefix-scoped, and never blocks Wine startup.

## Accepted optimizations

The shipped runtime uses the accepted loader/session cache, deferred headless
MoltenVK initialization, batched Vulkan procedure discovery, software x86
memory ordering, executable-memory publication, GPU cache generation, and
hot-set support. These changes are retained in the pinned Wine/FEX patches and
runtime helpers rather than as optional tracing modes.

The external acceptance record measured the shipped hot-set closure at
0.791952 GB/s physical, 1.908866 GB/s effective, and 0.990010 GB/s with
overlap, with 58.41 percent measured stall reduction. Measurements are
supporting evidence; correctness and zero-status execution remain mandatory.

## Stability policy

Do not enable tracing in a production package. Do not promote candidates based
on source presence or a single benchmark. Preserve the exact provider hashes,
package manifest, and fresh-prefix architecture result together.
