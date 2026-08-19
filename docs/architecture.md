# VKMT Architecture and Compatibility

This is the consolidated architecture reference for Wine, emulation, WoW64,
managed runtimes, Java, installers, and application compatibility.

## Emulation design and implementation journal


PE-side emulation work (arm64ec / xtajit / wow64) on native arm64 Wine 11.12.
Related: [NATIVE_WINE_D3D12.md](NATIVE_WINE_D3D12.md) (native D3D12 bring-up).

### 2026-07-25 — M0: arm64ec PE architecture enabled, xtajit64.dll links

Goal: `--enable-archs=aarch64,arm64ec,x86_64,i386` builds cleanly and
`xtajit64.dll` (upstream stub) links as ARM64EC. Result: **PASS**, no wine
source breakage beyond one configure.ac fix.

#### Toolchain: arm64ec CRT + C++ runtime rebuilt with fixed registers

- `scripts/rebuild-mingw-crt.sh` generalized: now takes a target argument
  (`aarch64` default, `arm64ec` new) plus the existing `cxx` mode, in any
  order (`rebuild-mingw-crt.sh arm64ec [cxx]`). Per-target build dirs
  (`third_party/build-mingw-crt-arm64ec`, `build-winpthread-arm64ec`,
  `build-cxxrt-arm64ec`); backups in
  `<toolchain>/arm64ec-w64-mingw32/lib-backup-stock`.
- mingw-w64 master was refreshed in `third_party/mingw-w64` (the old
  depth-1 checkout predated arm64ec CRT support; arm64ec CRT is the
  libarm64 build selected by `--host=arm64ec-w64-mingw32`, which sets
  `ARM64EC_TRUE` and adds `-target arm64ec-windows-gnu` automatically).
- Built + installed for arm64ec with `-O2 -ffixed-x18 -ffixed-x28`:
  mingw-w64 CRT, winpthreads, then libunwind/libc++abi/libc++ from
  llvm-project @ ca7933e4 (same sparse checkout as aarch64, no extra dirs
  needed).
- Verified: `arm64ec-w64-mingw32-clang` accepts both fixed flags
  (arm64ec is an ARM64-compatible ABI); hello-world C and C++ (with
  exceptions, static libstdc++) link and contain no x18 references after
  fixup.

#### x28 / x18 facts learned (arm64ec)

- The VKMT-patched `winnt.h` (already installed in both triples) declares
  `NtCurrentTeb()` as a global register variable on **x28** for both
  `__aarch64__` and `__arm64ec__`. Clang only accepts a global register
  variable on x28 when x28 is reserved, so **both** `-ffixed-x18` and
  `-ffixed-x28` are required to compile any EC code including winnt.h —
  same recipe as aarch64. Without the flags the header errors out.
- Plain arm64ec clang does not allocate x18/x28 as scratch (verified by
  disassembly of register-pressure test), so the stock EC CRT was less
  dangerous than stock aarch64 CRT — but EC CRT startup (`crt2.o`,
  `__tmainCRTStartup`) reads `[x28,#8]` (StackBase via NtCurrentTeb), so a
  consistent rebuilt CRT is still required, and static libs must be
  rebuilt with the fixed flags just like aarch64.
- **LLVM's arm64ec-windows TLS lowering emits the same `[x18,#0x58]`
  pattern as aarch64** (seen in libc++ exception-state TLS).
  `scripts/fix-x18-tls.py` rewrites it to `[x28,#0x58]` unchanged — no
  script changes needed. Confirmed: 2/2 sites patched in a test EC exe.

#### wine configure fix

- `wine/wine-11.12/configure.ac`: the VKMT block appended
  `-ffixed-x18 -ffixed-x28` only for `aarch64`; changed to
  `AS_CASE([$wine_arch],[aarch64|arm64ec],...)`. Regenerated `configure`
  with `autoconf` (2.73, matches the shipped one).
- `scripts/build-ec.sh` (new): mirrors `build-wine.sh` into
  `wine/build-ec` with `--enable-archs=aarch64,arm64ec,x86_64,i386`.
  `wine/build-full` untouched.
- configure result: `arm64ec_CC=arm64ec-w64-mingw32-clang` (found via
  PATH), `arm64ec_CFLAGS='-g -O2 -ffixed-x18 -ffixed-x28'`,
  `enable_xtajit64=arm64ec`.

#### Build result

`make -j8` completed with **zero source changes beyond configure.ac** —
winebuild EC thunk generation and `libs/winecrt0/arm64ec.c` worked
out of the box.

Layout surprise (not a bug): with arm64ec in `--enable-archs`, wine links
**ARM64X (0xA64E) hybrid dlls** for dual-arch modules, placed in the
`aarch64-windows/` dirs (e.g. `ntdll.dll`, `kernel32.dll` are ARM64X).
Pure-EC modules land there too as single-arch ARM64EC (0xA641):
`xtajit64.dll` is at `dlls/xtajit64/aarch64-windows/xtajit64.dll`
(the `arm64ec-windows/` dirs hold only intermediate `.o` files).
The handoff's expected path `arm64ec-windows/xtajit64.dll` does not exist;
the ARM64EC dll at the aarch64-windows path is the real artifact.

#### Verification

- `xtajit64.dll`: `Machine: IMAGE_FILE_MACHINE_ARM64EC (0xA641)` ✓
- `ntdll.dll`, `kernel32.dll` (aarch64-windows): ARM64X ✓; x86_64 and
  i386 ntdll.dll present ✓
- **x18 scan:** every ARM64/ARM64EC/ARM64X dll+exe in build-ec — zero
  `[x18]` memory operands (full-tree llvm-objdump scan). Wine's own dlls
  never needed fix-x18-tls.py (no `__thread` TLS in PE code; TEB access
  goes through the patched header).
- Boot test: fresh `test/prefix-ec`,
  `./wine/build-ec/wine 'C:\windows\system32\cmd.exe' /c echo EC-BOOT-OK`
  → EC-BOOT-OK printed. (First-boot RpcSs error is the known cosmetic
  upstream race.)

### 2026-07-25 — M1: ARM64EC processes boot on Darwin, hello_ec runs native

Goal: EC/CHPE per-thread init (emulator stack + CHPE_V2_CPU_AREA_INFO) works
despite the no-sub-4GB host constraint, and a mingw arm64ec console exe runs.
Result: **PASS (ideal)** — `hello from arm64ec` printed, exit code 42, fully
native execution (xtajit64 stub never entered).

#### Wine source fixes (all `#if defined(__APPLE__) && defined(__aarch64__)` or VKMT-marked)

- `dlls/ntdll/unix/thread.c` (`init_thread_stack`, arm64ec block): the
  emulator stack was allocated with `limit_low = limit_4g` ("anywhere above
  4GB") — harmless upstream, but the same call is the one that must not aim
  below 4GB here; made the limits explicit `0, 0` on Darwin with a VKMT
  comment, plus a one-per-thread `FIXME` log line proving the allocation
  (`VKMT: arm64ec emulator stack at 0x...-0x..., cpu area 0x...`).
- `dlls/ntdll/unix/virtual.c` (`virtual_set_large_address_space`): upstream
  resets `address_space_start` to `0x10000` for 64-bit guests — that would
  re-open the sub-4GB range on this host (EC guests included, since
  `is_wow64()` is false for them). Guarded out on Darwin.
- `include/winnt.h` — **the big one**: the VKMT x28-TEB patch only covered
  the `__GNUC__` branch of `NtCurrentTeb()` for aarch64. Wine builds PE with
  `-target arm64ec-windows` (MSVC mode, no `__GNUC__`), so the `_MSC_VER`
  branch was taken, and it returned `__getReg(18)` for `__arm64ec__`
  ("arm64ec keeps x18 for now"). Both branches now use x28 for
  aarch64 **and** arm64ec. Without this, EC ntdll faulted immediately:
  `ldrh w8, [x18, #0x17ee]` (TEB.SkipLoaderInit) with x18 kernel-zeroed →
  read at address `0x17ee` → exception-dispatch recursion → native-stack
  exhaustion (`virtual_setup_exception stack overflow`).
- `dlls/ntdll/signal_arm64ec.c`: four inline-asm TEB reads switched
  `x18` → `x28`: `KiUserCallbackDispatcher` (peb), `arm64x_check_call`
  (peb→EcCodeBitMap — this is `__os_arm64x_check_call`, hit on *every*
  indirect call in EC code), `raise_status` (peb->BeingDebugged),
  `DbgUiRemoteBreakin` (peb).

#### review of other low-VA / EC paths (checked, no change needed)

- `virtual.c` `alloc_arm64ec_map` (EcCodeBitMap): `map_view(..., MEM_TOP_DOWN, 0, 0)`
  — top-down anywhere, host-safe. Note it reserves one bit per page over the
  whole 128TB guest space = a **4GB reservation** (reserve-only, committed
  per EC range via `commit_arm64ec_map`); works fine on Darwin.
- `set_arm64ec_range`/`clear_arm64ec_range`: pure bitmap math on guest page
  numbers, no host assumptions. `MEM_EXTENDED_PARAMETER_EC_CODE` path only
  gates on `arm64ec_view` existing.
- `virtual_alloc_thread_data` (`map_view limit_low=limit_4g`): "above 4GB",
  correct on this host. `ldt_update_entry` and the `user_space_wow_limit`
  paths are 32-bit-wow64-only (arm64ec is_win64 && !is_wow64; wow64 stays
  rejected in `env.c`). `map_image` chooses the `base >= limit_4g` branch
  for 64-bit images — fine.
- `loader.c` (PE, `load_arm64ec_module`/`arm64ec_thread_init`) and
  `unix/loader.c` (`redirect_ntdll_functions`, unix-call dispatcher swap):
  no VA assumptions.
- `unix/signal_arm64.c` EC hook (`is_ec_code` check before
  KiUserEmulationDispatcher): address-space-neutral.

#### Diagnostics left in / removed

Kept: the `init_thread_stack` FIXME (one line per EC thread, proves CHPE
init). Removed after debugging: temporary `init_syscall_frame` and
`segv_handler` FIXME traces.

#### Test: test/x64emu/hello_ec.c

`arm64ec-w64-mingw32-clang -O1 hello_ec.c -o hello_ec.exe` (pure ARM64EC,
`file format coff-arm64ec`; puts + `return 42`). Run in fresh
`test/prefix-ec2`:

```
0024:fixme:thread:init_thread_stack VKMT: arm64ec emulator stack at 0x107cf0000-0x107df0000, cpu area 0x107cf0000
hello from arm64ec
EXIT=42
```

**Observed EC entry behavior:** the exe entry (`0x140001424`) is EC code and
runs *natively* — ARM64EC is an ABI, not a different ISA, so the host CPU
executes it directly; the emulator is only needed for actual x86_64 code,
which this binary contains none of. CRT startup, `puts` into wine's hybrid
ARM64X ucrtbase, and exit all ran native. xtajit64.dll loads
(`load_arm64ec_module` + `arm64ec_process_init` succeeded silently) but its
stub was never entered.

**Regression check:** fresh `test/prefix-ec`,
`wine cmd /c echo OK` → `OK`, exit 0.

#### Surprises / notes for M2 (the actual emulator)

- **The M0 "zero x18 operands" scan was a false negative.** Its pattern
  (`[x18]`) missed offset forms like `[x18, #0x17ee]`. EC ntdll had two
  such TEB reads until the winnt.h `_MSC_VER` branch was fixed. A
  full-tree rescan with `\[x18, #0x` found one more offender:
- **`dlls/icu/aarch64-windows/icu.dll` (ARM64X) had 22 `[x18,#0x58]` TLS
  sites** in its EC half (ICU's own `__thread` TLS — the pattern
  `fix-x18-tls.py` exists for). Patched post-link with the script
  (22/22 rewritten to x28). **This regresses on any icu.dll relink** — M2
  should wire `scripts/fix-x18-tls.py` into the PE link step (or strip
  `__thread` from the ICU build) before anything loads icu (usp10 /
  directwrite path).
- EC code in wine's own dlls reads PEB.EcCodeBitMap via
  `arm64x_check_call` on every indirect call; with the x28 fix this works
  and is on the hot path for any future emulation dispatch.
- `llvm-objdump`/`llvm-nm` on ARM64X binaries print the EC image at
  ImageBase `0x180000000`; native-half symbols appear at plain RVAs —
  handy for offline symbolication of EC crashes (fault RVA = pc − module
  base; both halves land in one map).


---

### M2 (2026-07-25): xtajit64 emulator skeleton — derived ABI conventions

The stub xtajit64 ("x64 emulation not implemented" → NtTerminateProcess) is
replaced by our own interface-complete skeleton in
`dlls/xtajit64/vkmt/` (thin export layer stays in `dlls/xtajit64/cpu.c`).
**No x86 execution yet** beyond a minimal decode skeleton; M3 fills in the
interpreter. This section is the ABI reference M3 is built against.

#### Where the emulator gets invoked (verified in source + disassembly)

There are exactly four entry points from native code into the emulator:

1. **`BeginSimulation()`** — called as an ordinary EC function
   (`pBeginSimulation()` in `dispatch_emulation`,
   `dlls/ntdll/signal_arm64ec.c:1264`). Reached whenever the unix side
   resumes a thread whose target PC is not EC code
   (`signal_set_full_context`, `dlls/ntdll/unix/signal_arm64.c:379-387`:
   the resume frame PC is redirected to `KiUserEmulationDispatcher` with a
   full native context placed on the stack). Before the call, ntdll has:
   - converted the saved native context into the cpu area:
     `context_arm_to_x64( cpu_area->ContextAmd64, arm_ctx )`
   - set `cpu_area->InSimulation = 1`
   So at `BeginSimulation` entry **all guest state lives in
   `cpu_area->ContextAmd64`** (an `ARM64EC_NT_CONTEXT`); the native
   registers belong to the dispatcher and may be clobbered. The function
   must never return (its caller does `brk #1` afterwards) — it leaves via
   `NtContinue` or process termination.

2. **`ExitToX64()`** (`__os_arm64x_dispatch_call_no_redirect`) — `blr`'d
   from inside llvm-mingw `$iexit_thunk$` thunks when EC code calls an x64
   function. Verified from ntdll.dll disassembly:
   ```
   $iexit_thunk$cdecl$i8$i8:
     sub sp, sp, #0x30
     stp x29, x30, [sp, #0x20]
     add x29, sp, #0x20
     ldr x16, [__os_arm64x_dispatch_call_no_redirect]
     blr x16                    ; -> ExitToX64
     mov x0, x8                 ; guest RAX comes back in x8
     ldp x29, x30, [sp, #0x20]
     add sp, sp, #0x30
     ret
   ```
   At `ExitToX64` entry: **x9 = x64 target address** (placed by
   `arm64x_check_call`'s `.Lexit`: `mov x9, x11`), x0–x7 = EC args,
   sp = guest stack (the thunk's 0x30 frame: saved fp/lr at `[sp,#0x20]`,
   16 bytes free at `[sp,#0x00]` — believed to be the slot where the
   emulator writes the `RetToEntryThunk` marker as the guest return
   address; **unverified, confirm in M3**), lr = return address into the
   thunk epilogue. Return protocol: emulator resumes native execution with
   guest RAX in x8 and PC = the lr it saw at entry (the thunk then does
   `mov x0, x8; ret` back into EC code).

3. **`DispatchJump()`** (`__os_arm64x_dispatch_fptr`) — same convention as
   `ExitToX64` (x9 = x64 target) but tail-called for indirect *jumps* into
   x64 code; no new frame is created, so a guest `ret` lands directly on
   the EC caller's return address (which is EC code → plain exit-to-native).

4. **`RetToEntryThunk()`** (`__os_arm64x_dispatch_ret`) — `br`'d to from
   the epilogue of `$ientry_thunk$` thunks when a native (EC) function that
   was called *from the emulator* returns:
   ```
   $ientry_thunk$cdecl$...:
     sub sp, sp, #0xd0 ; save q6-q15, fp/lr
     ldp x8, x5, [x4, #0x20] ; reload args from a descriptor buffer in x4:
     ldr q0,     [x4, #0x40] ;   +0x20 x4, +0x28 x5, +0x30 x6/x7,
     ldp x6, x7, [x4, #0x30] ;   +0x40 q0, +0x50 extra (stack-arg/retaddr?)
     ldr x10,    [x4, #0x50] ;   (exact x4 descriptor semantics: M3)
     blr x9                  ; x9 = native EC function
     ldr x1, [__os_arm64x_dispatch_ret]
     mov x8, x0              ; result -> guest RAX in x8
     ...restore..., add sp, sp, #0xd0
     br x1                   ; -> RetToEntryThunk
   ```
   At `RetToEntryThunk` entry: x8 = guest RAX, sp = guest RSP as at
   entry-thunk entry, and `[sp]` = the x64 return address the guest pushed
   with its `call`. So the re-entry convention is: capture regs,
   guest RIP = pop([sp]), re-enter simulation.

#### Guest state representation

`CHPE_V2_CPU_AREA_INFO` (include/winternl.h:352), per thread, allocated by
M1 in `dlls/ntdll/unix/thread.c:1217-1241` (above 4GB on Darwin):
- `InSimulation` (0x00), `InSyscallCallback` (0x01) — cooperative flags
  read by `signal_arm64.c` suspend machinery; emulator must set
  `InSimulation=1` while interpreting and clear it before any `NtContinue`
  back to native code.
- `EmulatorStackBase` (0x08) / `EmulatorStackLimit` (0x10) — private
  emulator stack (256KB); entry points switch SP here before running C.
- `ContextAmd64` (0x18) → `ARM64EC_NT_CONTEXT` (0x4d0 bytes, lives inline
  in the reserved area at `EmulatorDataInline`). THE guest register file.
- `EmulatorData[4]` (0x30) — emulator-private slots; VKMT uses
  `[0]` = per-thread `vkmt_x64_context*`, `[1]` = raw NZCV scratch during
  ExitToX64/DispatchJump entry.

x64 ↔ ARM64EC register aliasing inside `ARM64EC_NT_CONTEXT`
(include/winnt.h:1908-2012; this is what the interpreter reads/writes):

| x64 | ARM64EC field | offset | x64 | ARM64EC field | offset |
|-----|---------------|--------|-----|---------------|--------|
| rax | X8   | 0x078 | r8  | X2  | 0x0b8 |
| rcx | X0   | 0x080 | r9  | X3  | 0x0c0 |
| rdx | X1   | 0x088 | r10 | X4  | 0x0c8 |
| rbx | X27  | 0x090 | r11 | X5  | 0x0d0 |
| rsp | Sp   | 0x098 | r12 | X19 | 0x0d8 |
| rbp | Fp   | 0x0a0 | r13 | X20 | 0x0e0 |
| rsi | X25  | 0x0a8 | r14 | X21 | 0x0e8 |
| rdi | X26  | 0x0b0 | r15 | X22 | 0x0f0 |
| rip | Pc   | 0x0f8 | lr (native ret) | Lr | 0x120 |
| rflags | AMD64_EFlags | 0x044 | xmm0-15 | V[0..15] | 0x1a0 |

EFlags ↔ CPSR (from ntdll `cpsr_to_eflags`): N→SF(0x80), Z→ZF(0x40),
C→CF(0x01), V→OF(0x800), plus always-set 0x002 and IF 0x200. Raw NZCV has
no place in the EC context, so the asm entry stashes it in
`EmulatorData[1]` and C code converts.

#### Leaving simulation

Uniform exit for all paths: write final guest state into `ContextAmd64`,
set `Pc` = native (EC) target, `InSimulation = 0`, then
`NtContinue( (CONTEXT *)ContextAmd64, FALSE )` (EC ntdll converts
x64→native and resumes; if the target were still x64 the unix side would
bounce us straight back into `KiUserEmulationDispatcher` →
`BeginSimulation`, which is the correct re-entry loop).

The interpreter decides to exit when the next guest RIP is:
- EC code (`RtlIsEcCode(rip)`) → exit to native at that PC
  (covers guest `call`/`jmp`/`ret` into EC thunks and EC return addresses);
- equal to `&RetToEntryThunk` (the marker) → guest `ret` from an
  ExitToX64-entered call: exit to native at the saved native lr
  (`ContextAmd64->Lr`), guest RAX already in X8;
- 0 → giveup diagnostic (guest returned from a top-level entry).

#### Skeleton behavior for M2 (no real x86 execution)

`vkmt/interp_stub.c` decodes a deliberately tiny subset — enough to run a
hand-written `mov eax,imm; ret` snippet and typical prologue prefixes:
`nop`, `mov r32,imm32` / `mov r64,imm64` (B8+rd), register-direct
`mov r64,r64` (89/8B mod=3), `push/pop r64`, `add/sub rsp,imm8`,
`call/jmp rel`, `call/jmp r/m64` (FF /2,/4 mod=3), `ret`/`ret imm16`,
`int3`. Anything else → loud `ERR` diagnostic ("VKMT M2 skeleton:
unsupported guest opcode …") and clean `NtTerminateProcess(
STATUS_ILLEGAL_INSTRUCTION )` — replacing the stub's blanket terminate.
All Notify*/BTCpu64* hooks log on the `vkmtx64` debug channel.

#### Implementation notes (what actually landed)

- `dlls/xtajit64/cpu.c` is now a thin export layer; implementation in
  `dlls/xtajit64/vkmt/`: `vkmt.h`, `context.c` (process/thread lifecycle,
  per-thread `vkmt_x64_context` in `EmulatorData[0]`, feature bits,
  `UpdateProcessorInformation` → AMD64/level 21/revision 1), `dispatch.c`
  (naked `BeginSimulation`/`ExitToX64`/`DispatchJump`/`RetToEntryThunk`,
  `vkmt_simulate` loop, `ResetToConsistentState`), `interp_stub.c`.
  Debug channel `vkmtx64`.
- **Observed entry path:** the x64 exe entry point is reached via
  **ExitToX64** (loader → exit thunk → `blr ExitToX64`, x9 = exe entry),
  not via `BeginSimulation`. `BeginSimulation` fires on the
  `NtContinue`-to-x64 path (thread starts, syscall re-entry,
  `STATUS_EMULATION_SYSCALL`); both funnel into the same `vkmt_simulate`.
- **Return-marker protocol (now implemented + verified):** on
  ExitToX64/DispatchJump entry the emulator writes `&RetToEntryThunk` to
  the guest stack top and stashes the thunk-entry SP/FP in
  `EmulatorData[2..3]`. A guest `ret` pops the marker → EXIT_RETURN →
  `NtContinue` with `Pc = entry-time lr` (thunk epilogue), **SP/FP
  restored to entry values** (the guest frame is discarded; the thunk's
  own epilogue must see its exact entry SP — first version of this
  crashed with c0000005 at caller+4 until the restore was added).
  Guest RAX lands in x8, thunk does `mov x0, x8` → the EC caller sees a
  normal return value.
- **x64-half discovery:** a guest call to a hybrid-dll API (e.g.
  `ExitProcess` via IAT) lands in the dll's **x64 half** (real x64 code,
  not EC per `RtlIsEcCode`), which then transitions to the EC half
  internally. So M3 cannot avoid interpreting those prologues — API calls
  are not a cheap "jump straight to native" escape.
- Interpreter subset: as listed above plus rip-relative `call/jmp
  [rip+disp32]` (FF /2,/4 mod=0 rm=101).

#### TLS fixup wiring (M1 follow-up, done)

`tools/makedep.c` now emits a post-link command for every module whose
link arch is arm64ec (covers arm64x too): runs
`tools/vkmt-fix-x18-tls.py $@` (a copy of `scripts/fix-x18-tls.py`,
shipped in the wine patch; guarded by `if [ -f ]`, silent skip when
absent). Make-level hook in `output_module()` — the single rule every PE
dll/exe link goes through — no winegcc changes needed. Gotcha found:
`$(top_srcdir)` is not defined in the generated top-level Makefile; the
hook uses `$(srcdir)`. Verified: `touch libs/icucommon/chariter.cpp &&
make dlls/icu/aarch64-windows/icu.dll` relinks and prints
`dlls/icu/aarch64-windows/icu.dll: patched 22/22 [x18]->[x28] sites`;
post-link scan `llvm-objdump -d | grep -c '\[x18, #0x'` → **0**.
Full rescan of every `aarch64-windows`/`arm64ec-windows` PE in build-ec
with the corrected `\[x18, #0x` pattern → **0 offenders**.

#### Test results (verbatim highlights)

- Regression, fresh prefix: `wine cmd /c echo OK` → `OK`.
- Regression, `test/prefix-ec2`, `C:\hello_ec.exe` → `hello from arm64ec`,
  `exit=42`.
- `test/x64emu/entry_x64.exe` (normal-CRT hello+`return 7`), fresh
  `test/prefix-x64`, `WINEDEBUG=+vkmtx64`:
  ```
  0024:trace:vkmtx64:vkmt_process_init VKMT x86-64 emulator skeleton (M2): process init
  0024:trace:vkmtx64:vkmt_thread_init thread 0024 init, cpu area 0000000105CB0000
  0024:trace:vkmtx64:vkmt_simulate_from_ec simulation from EC: thread 0024 guest rip 0000000140001480 rsp 0000000105AEF500 native lr 00006FFFFFA56364
  0024:trace:vkmtx64:vkmt_simulate enter simulation: thread 0024 guest rip 0000000140001480 rsp 0000000105AEF500
  0024:err:vkmtx64:vkmt_simulate VKMT M2 skeleton: cannot continue guest execution at rip 0000000140001487 (opcode 8b) — terminating process cleanly; full x86-64 interpretation lands in M3
  ```
  → process exit code 0x1d (STATUS_ILLEGAL_INSTRUCTION), no crash/hang,
  `wineserver -w` returns 0. (All Notify* traffic visible on the channel.)
- `test/x64emu/ret_snippet_x64.exe` (hand-written `mov eax,7; ret`,
  `-nostdlib -e entry`):
  ```
  0024:trace:vkmtx64:vkmt_simulate_from_ec simulation from EC: thread 0024 guest rip 0000000140001000 rsp 000000010755FFB0 native lr 00006FFFFF68F9FC
  0024:trace:vkmtx64:vkmt_simulate enter simulation: thread 0024 guest rip 0000000140001000 rsp 000000010755FFB0
  0024:trace:vkmtx64:vkmt_simulate guest returned to EC caller at 00006FFFFF68F9FC (rax 0000000000000007)
  0024:trace:vkmtx64:vkmt_process_term process term handle 0000000000000000 is_post 0 status 0
  ```
  → **process exit code 7**: full enter→interpret→return→native round
  trip with the exit-code value propagated through x8 → x0.
- `test/x64emu/exit_native_x64.exe` (`mov ecx,7; jmp [rip+__imp_ExitProcess]`):
  interpreter followed the IAT into kernel32's **x64 half** and gave up
  cleanly at its prologue (`48 89` memory-form mov) — expected for M2,
  see the x64-half note above.

#### Open questions / M3 scope (honest assessment)

- **M3 is a real interpreter, no shortcuts.** The two biggest hopes for
  avoiding full decode turned out false: (1) the CRT entry runs dozens of
  x64 instructions before any native call; (2) hybrid-dll API calls route
  through the dll's x64 half first, so even "just call ExitProcess"
  needs memory-operand decode. Expect entry_x64's `hello` to need:
  full ModRM/SIB memory addressing, flag-tracking ALU, jcc, movs/stos,
  SSE movs, and the `syscall`/fast-forward sequences.
- **Confirm the ExitToX64 marker slot** ([thunk sp+0]) against a call
  with >4 args and against floating-point args (entry thunks save
  q6–q15; xmm0–3 argument passing is untested).
- **`$ientry_thunk` x4-descriptor layout** (+0x20/+0x30/+0x40/+0x50) needs
  confirmation the first time the emulator exits to native through an
  entry thunk rather than a plain EC return address.
- KiUserExceptionDispatcher's `dispatch_ret`-based unwind and
  `ResetToConsistentState` are stubs; exception flow across the
  x64/EC boundary is unexplored.
- Guest FPU/SSE state: v0–v15 captured on thunk entry, mxcsr defaults to
  0x1f80; no per-instruction FP decode yet.
- Debuggers: winedbg auto-attach after a guest giveup couldn't get the
  first exception (debugger process itself trips emulation paths) —
  worth fixing early in M3, debugging the interpreter needs it.

---

### M3 (2026-07-25): real x86-64 interpreter — entry_x64.exe passes

`dlls/xtajit64/vkmt/interp.c` replaces the M2 stub with a full
decode→execute interpreter (decoder fills a `vkmt_insn` metadata struct —
prefixes/opcode/ModRM/SIB/disp/imm/resolved EA — reusable by a future JIT;
execute stage is separate). RFLAGS: **always-compute** (every ALU op
materialises CF/OF/AF/SF/ZF/PF immediately; no lazy state).

Coverage: full ModRM/SIB/REX + rip-relative addressing, 8/16/32/64
operands (incl. no-REX high-byte regs), ALU groups + group1 imm, flag-
accurate add/sub/and/or/xor/test/cmp, shifts/rotates (rcl/rcr via carry
loop), mul/imul/div/idiv (incl. 128-bit), inc/dec/neg/not, jcc8/jcc32/
loop/jrcxz/cmov/setcc, movzx/movsx/movsxd, lea, xchg, bswap, bsf/bsr,
bt/bts/btr/btc (+bit-string mem addressing), shld/shrd, popcnt,
cmpxchg/cmpxchg8b/16b and xadd with host `__atomic` RMW for LOCK forms,
string ops (movs/stos/scas/cmps/lods + rep; rep movsb/stosb have
memcpy/memset fast paths), push/pop/pushf/popf/enter/leave, cbw/cwde/cdqe
+cwd/cdq/cqo, sahf/lahf, xlat, clc/stc/cmc/cld/std, CPUID (GenuineIntel
baseline matching UpdateProcessorInformation: SSE..SSE4.2, POPCNT, NX,
RDTSCP, long mode), RDTSC/RDTSCP (NtQueryPerformanceCounter-based),
mfence/lfence/sfence as nops, ldmxcsr/stmxcsr, x87: fldcw/fnstcw/fninit/
fnstsw only — anything else x87 is a loud giveup.
SSE/SSE2: movups/movaps/movdqa/movdqu/movss/movsd/movd/movq/movlps/
movhps/movhlps/movlhps/movddup, add/sub/mul/div/min/max/sqrt ps/pd/ss/sd
(local Newton sqrt — no libm in PE link), cvt family (cvtsi2ss/sd,
cvt(t)s(s|d)2si, cvtss2sd/sd2ss/ps2pd/pd2ps, cvtdq2ps/ps2dq/tps2dq),
ucomiss/ucomisd, cmpps/pd/ss/sd (8 predicates), and/andn/or/xor ps/pd,
pxor/pand/pandn/por, pcmpeq/pcmpgt b/w/d, padd/psub b/w/d/q, pshufd/
pshuflw/pshufhw, shufps/shufpd, unpcklps/pd, punpcklbw/lwd/lqdq/hqdq,
psll/psrl/psra w/d/q + pslldq/psrldq, movmskps/pd, movnti.

#### Boundary discoveries (M2 open questions resolved)

- **IAT slots in a pure-x64 exe point at the *EC halves* of ARM64X dlls**
  (verified: `__imp___acrt_iob_func` = ucrtbase EC `__acrt_iob_func`, arm64
  code at dll RVA 0xBD5FC). So guest calls into dll code exit to native
  immediately via `RtlIsEcCode` — hybrid transitions need no x64-half
  interpretation for wine's own dlls. (llvm-objdump prints the *EC* half
  at plain RVAs with base 0x180000000.)
- **x64→EC call protocol:** when the interpreter exits to native at an EC
  target it must plant `Lr = &RetToEntryThunk` in the context — the EC
  callee returns with a plain `ret` (x30); without the marker it rets to
  0 (M2 never exercised EXIT_NATIVE; first attempt crashed execute-at-0).
  RetToEntryThunk therefore now also runs when a *native* EC callee
  returns (not only via `$ientry_thunk$`): it does `mov x8, x0` first
  (EC result → guest RAX; idempotent with the real ientry thunks which
  already do it), then pops the guest return address. >4-arg/xmm-arg
  EC calls need nothing special: stack args are read off the guest stack
  and xmm args flow through ec->V (captured/restored on every switch) —
  confirmed working by puts/__acrt_iob_func/setvbuf/fflush.
- **ec->Lr cannot back the EXIT_RETURN path:** the RetToEntryThunk capture
  overwrites `ContextAmd64->Lr` with the planted marker on every EC-callee
  return, so the ExitToX64-entry lr is now saved separately
  (`vkmt_x64_context.native_ret`). Using ec->Lr caused an infinite
  marker→marker ping-pong (observed).

#### Interpreter bugs found via the exec-ring dump (new debug tool)

The giveup dump now prints guest regs, 32 bytes at rip, last 16 branch
targets, and the last up-to-8192 executed instructions
(rip/eflags/rax/rcx ring in the per-thread context; tight loops elided).
`vkmt_reset_to_consistent_state` dumps the *live* guest context when a
host fault happens mid-simulation — this is how these were found:

1. Missing immz table entries for ALU accumulator forms
   (05/0d/15/1d/25/2d/35/3d) — `cmp rax,imm32` decoded 4 bytes short.
2. `cmp` (ALU index 7) fell into the XOR branch of the shared ALU helper —
   flags always wrong for `cmp` (CF never set); `___chkstk_ms` probed the
   stack into the guard page (c00000fd).

Null-page guest operands (< 0x10000) are caught at decode time and turned
into a clean giveup with the full dump (exempt: lea, hint nops, prefetch).

#### Result

`entry_x64.exe` (full mingw CRT startup, puts("VKMT entry_x64: hello
from x86-64 guest"), `return 7`): prints correctly, **process exit code
7**, clean `wineserver -w`. This is the complete path: loader → exit
thunk → ExitToX64 → CRT startup (~100k+ interpreted insns across dozens
of simulation entries) → puts → EC ucrtbase → return marker → exit code.

#### M3b: math_x64.exe passes — ARM64EC arg convention resolved

Probe 2 (`test/x64emu/math_x64.c`, -O2): 64/32/16/8-bit integer mul/div
(incl. __int128 mulhi), shifts/rotates, scalar SSE2 double add/sub/mul/
div/sqrt, 1000-term series, i2d/d2i conversions, packed ps/pd — prints
`math_x64: OK (0 failures)`, exit 0.

**ARM64EC argument convention (the M2 >4-arg/xmm-arg open question,
resolved):** args 1-4 in x0-x3 (alias rcx/rdx/r8/r9), **args 5-8 in
x4-x7**, args 9+ on the stack at [sp+8i]; FP args in v0-v7 (= xmm0-7).
The x64 caller puts args 5+ at [rsp+0x28+8i] (retaddr+shadow at
[rsp]..[rsp+0x27]). So EXIT_NATIVE (guest call into EC code, no thunk in
the path) now: pushes the guest retaddr/rsp onto a per-thread LIFO,
loads x4-x7 from [rsp_g+0x28..0x40], repacks a 30-qword stack window
from [rsp_g+0x48] to a scratch frame below the guest rsp, plants
Lr=&EcCallRet (new trampoline, mode 2: pops the LIFO, `mov x8,x0` for the
result). ExitToX64 (EC→x64) does the mirror image: builds the x64 frame
below the thunk sp — marker at [new_sp], x4-x7 → [new_sp+0x28+8i],
EC stack args ([thunk_sp+0x30+8i]) → [new_sp+0x48+8i]. Confirmed by
printf → `__stdio_common_vfprintf` (5th arg va_list in x4).

Interpreter bugs fixed (all found with the exec-ring/conditional-bp
dumps):
3. group3 (0xf6/0xf7) immediate must be conditional on modrm.reg —
   `idiv` (/7) has no imm, decoder was eating 4 bytes of the next insn.
4. `0F 51` (sqrtsd) missing from the modrm table — 3-byte decode,
   phantom instruction, then fallthrough into `call sqrt` (double sqrt).

#### M3c: mem_x64.exe passes

Probe 3 (`test/x64emu/mem_x64.c`, -O2): VirtualAlloc 4MB (lands at
0x1xxxxxxxx, above 4GB as required), memset/memcpy/memmove loops with
value checks, per-page touch, decommit/recommit/release, CreateFile +
CreateFileMapping + MapViewOfFile write/flush/read-back round trip —
`mem_x64: OK (0 failures)`, exit 0.

Interpreter bug fixed:
5. ALU accumulator imm8 forms (04/0c/14/1c/24/2c/34/3c) missing from the
   imm8 table — same decode-misalignment class as bug 1 (this time it
   produced both a bogus check failure AND a truncated pointer;
   diagnosed via conditional rip breakpoints printing registers).

#### M3d: thread_x64.exe passes

Probe 4 (`test/x64emu/thread_x64.c`, -O2): CreateThread x4, each worker
does a 200k-iteration integer loop, LocalAlloc + TlsSetValue/TlsGetValue
round trip, WaitForMultipleObjects, GetExitCodeThread — all four sums
identical (258433085493875), all tls_ok 1, `thread_x64: OK (0
failures)`, exit 0. No interpreter changes needed: new threads enter
simulation through the M2 BeginSimulation path (NtContinue-to-x64 from
the unix side), per-thread cpu area/context init from M1/M2 just works,
and locked-RMW atomics (`InterlockedIncrement/Add`) hold up under real
contention.

#### M3e: SEH — partial: AV delivery + pass-1 dispatch work, unwind bridge missing

Probe 5 (`test/x64emu/seh_x64.c`, -O2 -fms-extensions): __try/__except
catching a deliberate AV (behind a noinline call — see note), plus
__try/__finally around the same AV.

**Works (verified):**
- `vkmt_reset_to_consistent_state` is now real: when a host fault happens
  mid-simulation it rewrites the exception context from the live guest
  context (rip = faulting guest instruction), sets
  `rec->ExceptionAddress` to the guest rip, and clears InSimulation.
  The old decode-time null-page giveup was removed so guest AVs fault
  naturally into this path.
- Pass-1 dispatch: wine's arm64ec KiUserExceptionDispatcher →
  RtlDispatchException over the amd64 context finds main's
  RUNTIME_FUNCTION, calls `__C_specific_handler` (EC msvcrt), which
  matches the scope and calls the guest filter via ExitToX64 →
  `filter saw exception c0000005` printed, filter returns
  EXECUTE_HANDLER, `RtlUnwindEx` targets the except funclet and
  execution resumes at `$ehgcr_0_2` ("AV caught and handled" path
  reaches `$ehgcr_0_2` per the vkmtx64 trace).
- Probe gotcha worth recording: LLVM's WinEH only assigns scope coverage
  to *calls* (synchronous exceptions); a plain store inside __try is not
  guarded, and LLVM will even fold/hoist a provably-null store out of
  the scope entirely. The probe therefore faults inside a noinline
  `do_av()` call — the realistic cross-frame case anyway.
- Also fixed en route: the ExitToX64 thunk-frame save is now a
  per-thread LIFO (`exit_sp/fp/lr[64]`) — nested EC→guest calls during
  exception dispatch (filter, then handler) used to clobber the single
  EmulatorData[2..3] slot, giving an infinite marker ping-pong.

**Broken (documented, not faked): unwind across the EC/x64 boundary.**
`RtlUnwindEx` (called by `__C_specific_handler` after the filter
accepts) walks EC frames from itself down: __C_specific_handler →
call_seh_handler (its `nested_exception_handler` runs) →
call_seh_handlers → dispatch_exception → KiUserExceptionDispatcher.
The next `virtual_unwind` must cross the dispatcher boundary via the
MSFT_OP_EC_CONTEXT opcode in KUED's frame. On this stack configuration
that restore yields the *arm64 host* context (the interpreter's own
frames on the emulator stack), not the amd64 guest context: the very
next EstablisherFrame is on the emulator stack, fails
`is_valid_arm64ec_frame` (guest stack range only), and the walk aborts
with `err:seh:RtlUnwindEx invalid frame`. Consequences:
- The unwind never enters the guest's x64 frames, so `RtlRestoreContext`
  resumes the except funclet with the *dispatcher-level* stack, not
  main's establisher frame.
- The __try/__finally test then faults again in `do_av`, and the second
  dispatch inherits the broken chain — the process loops/unwinds to
  unhandled. `finally` handlers in guest frames never run.
What is precisely missing: a working transition from the EC dispatcher
frames to the *amd64* exception context at the KUED boundary. The amd64
context is present in KUED's frame (at its sp+0, where
prepare_exception_arm64ec's `mov x1, sp` points, and where our
reconcile writes); the observed walk instead follows the arm64 host
context (stacked by `call_user_exception_dispatcher` at the dispatcher's
entry sp, which is what the EC_CONTEXT opcode reads). Fixing it needs
either (a) the EC_CONTEXT op to restore from the amd64 context (op
ordering vs the `.seh_stackalloc 0x4d0` in
`dlls/ntdll/signal_arm64ec.c:1311-1337` KiUserExceptionDispatcher), or
(b) an explicit bridge in `virtual_unwind`/RtlVirtualUnwind2_arm64
(signal_arm64ec.c:1028) that switches to the amd64 context when the walk
reaches the dispatcher frame. Overwriting the stacked arm64 context from
vkmt_reset_to_consistent_state was tried (with rec-overlap repair at
+0x3b0): no effect — the failing frame predates that restore, and the
change was reverted.

#### M3f: performance + wrap-up

Perf probe (`test/x64emu/perf_x64.c`, -O2, tight 4×-unrolled integer
dependency loop, ~9.25 insns/iter measured from the disassembly):
`perf_x64: 30000000 iters in 3018 ms (201.20 ns/iter)` → **~92 million
guest instructions/sec** (2.78e8 insns / 3.018 s) on this host, CRT
startup excluded as noise. No profiling-driven tuning was done; obvious
fast paths present: rep movsb/stosb → memcpy/memset, locked RMW → host
single atomics, everything else is a plain threaded decode/execute
switch. The 5e8 runaway guard is the only known long-run limit (hit
naturally by a 1e8-iteration probe and reported correctly).

SSE2 gap found by the perf probe: punpckldq/hdq + punpckhbw/hwd/hdq were
missing (only the byte/word forms existed) — added the full
punpckl/h b/w/d/q family.

#### M3 final ladder status

| probe | status |
|-------|--------|
| entry_x64.exe  | PASS — prints, exit code 7 |
| math_x64.exe   | PASS — `math_x64: OK (0 failures)`, exit 0 |
| mem_x64.exe    | PASS — `mem_x64: OK (0 failures)`, exit 0 |
| thread_x64.exe | PASS — `thread_x64: OK (0 failures)`, exit 0 |
| seh_x64.exe    | PASS — AV filter/except and nested __finally both execute; clean ExitProcess(0) |
| perf_x64.exe   | ~92M insns/sec |

#### M4a: x64 D3D12 device creation + feature-contract hardening

The x86-64 `test/d3d12_probe.c` was built with
`x86_64-w64-mingw32-clang -O1` and run in `prefix-x64` with native
`d3d12`, `d3d12core`, and DXVK `dxgi` overrides plus the VKMT MoltenVK
ICD.  It creates a Vulkan device on the Apple M4 through the emulated x64
guest, records an offscreen render-target clear, submits it, and waits for a
fence before printing `PROBE OK` and exiting 0.  This is the first verified
x86-64 guest path through DXGI -> vkd3d-proton -> VKMT MoltenVK with real
GPU command submission (headless; no swapchain/window required).

SSE4.1/4.2 have deliberately been removed from CPUID leaf 1 and the
processor-feature mask.  The interpreter has no 0f 38 / 0f 3a opcode maps,
so reporting those bits was an invalid feature contract.  `cpuid_x64.exe`
checks that both bits stay clear.  SSE4 support can be restored only with
the corresponding opcode implementation and tests.

The KUED-boundary unwind bridge is complete.  `virtual_unwind()` recognizes
the dispatcher by its `RUNTIME_FUNCTION` entry (not a single ARM64X PC,
which differs between entry paths) and restores the original guest context
saved in the per-thread VKMT context.  This bypasses KUED's normal
`MSFT_OP_EC_CONTEXT` restore, which belongs to the host signal frame.  The
bridge state intentionally does not use PE TLS or an `EmulatorData` scratch
slot: nested EC exits would corrupt either; it lives at the stable prefix of
VKMT's per-thread context instead.  The SEH probe verifies both a filter /
except transfer and `__finally` execution during unwind, then exits cleanly.

M4 closure: KUED unwind, honest SSE feature reporting, x64 D3D12 device
creation, and headless GPU submission are all verified.  The remaining
`DispatchJump` tail-jump LIFO review is a contained cleanup rather than an
M4 acceptance blocker; retain it as a pre-JIT regression item.  M5 starts
with a block translator consuming the existing `vkmt_insn` metadata.  SSE4
can be re-enabled only alongside the 0F 38 / 0F 3A opcode maps and tests.

#### M5: ARM64EC tier-0 block cache

`vkmt/jit.c` adds a tier-0 block translator over the interpreter decoder's
`vkmt_insn` metadata.  It caches straight-line x64 blocks and emits
ARM64EC-marked W^X code. Native lowering covers NOP, immediate and
register-to-register moves, simple base+displacement loads, stack stores,
and flag-dead XOR/add/shift operations.  A 32-bit guest write is stored back
to the full 64-bit context slot after ARM64 zero-extension, preserving x86-64
register semantics. Instructions with live or complex flag effects use the
shared decoded executor, retaining exact architectural behavior as fallback.
The generated stub observes AAPCS64 stack alignment and preserves x29/x30;
the EC-code allocation attribute is essential so Wine executes the generated
ARM64 instructions rather than re-entering x64 emulation.

Blocks retain verified fall-through links through a bounded cache chain before
returning to decode.
Unsupported operations, memory-addressed instructions, and control flow
remain in the interpreter. `BTCpu64FlushInstructionCache`, its heavy form,
memory-dirty notification, and successful protection changes retire the
current cache generation. Retired blocks are not freed while a guest thread
may still execute them; process termination releases the code cache.

`smc_x64.exe` proves coherency: it executes a dynamically allocated
`mov eax,1; ret`, patches it to return 2, calls `FlushInstructionCache`, and
returns `smc_x64: OK (1 -> 2)`. `math_x64.exe` and `mem_x64.exe` remain green
with native generated blocks enabled.

## Compatibility expansion


The accepted graphics/runtime baseline remains fixed: ARM64, ARM64EC,
x86_64, and i386/WoW64 execute in one prefix; VKMT, DXMT, SDL2/3, OpenGL
2.1/GLSL 1.20, and Metal-backed GLSL 3.30/4.50 gates pass. The work below
adds application compatibility without reopening that baseline.

Every workstream must use source or pinned redistributable inputs stored in the
VKMT tree, targeted component builds, ARM64-only host Mach-O, exact-prefix
wineserver shutdown, and disposable-prefix cleanup.

### Workstream A — relocatable host dependency closure

1. Stage GnuTLS 3 and its complete ARM64 dylib closure beside Wine:
   `libgnutls`, gettext/libintl, p11-kit/libffi, libidn2, libunistring,
   libtasn1, nettle/hogweed, and GMP.
2. Rewrite every non-system dependency to `@loader_path`; remove Homebrew
   runtime paths; sign each staged Mach-O artifact.
3. Apply the same closure review to enabled Fontconfig, CUPS, ODBC, SDL2,
   GStreamer/FFmpeg, and MoltenVK consumers.
4. Gate the native ARM64 Wine server/provider path through Schannel
   credentials, WinHTTP and WinINet HTTPS, certificate validation, staged
   GnuTLS load evidence, and a no-Homebrew-path `otool -L` review. Guest
   architecture HTTPS runs are optional diagnostics, not Workstream A gates,
   because the server/Unix provider is native ARM64.

### Workstream B — input and game-device compatibility — COMPLETE (2026-07-28)

1. Wine's in-tree XInput
   1.1/1.2/1.3/1.4/9.1.0/UAP modules and DirectInput/DirectInput8 pass in one
   prefix for ARM64, ARM64EC, x86_64, and i386/WoW64. The native provider is
   the source-built ARM64 `winebus.so` SDL backend with its pinned, relocatable
   ARM64 SDL2 provider; no Rosetta or guest Mach-O is involved.
2. A physical PS5 DualSense passes normalized XInput enumeration/state,
   live-axis activity, force-feedback capability, and nonzero vibration calls
   in all four guest modes. DirectInput/DirectInput8 controller enumeration
   and keyboard/mouse enumeration also pass.
3. SDL is authoritative for game controllers on macOS during the acceptance
   run; raw IOHID joystick enumeration is disabled to prevent duplicate,
   unnormalized devices. The newer Wine PE modules remain authoritative, so
   no packaged MetalSharp XInput DLL replaces them.
4. Multiple-controller and disconnect/reconnect exercises remain optional
   hardware-coverage extensions, not blockers for the completed single-pad
   workstream.

### Workstream C — installers and package engines

**Complete (2026-07-28).**

1. MSI's core install/corrupt/repair/uninstall lifecycle passes ARM64,
   ARM64EC, x86_64, and i386/WoW64 in one prefix. Native ARM64 `msiexec` and
   `msidb` additionally pass WiX upgrades, environment rows, registry rows,
   shortcuts, and service-table processing. Guest CLI modes remain optional
   diagnostics because the all-architecture contract is the MSI API fixture.
2. Native ARM64 `wixl` reproducibly builds both 32-bit and 64-bit core
   packages plus versioned extended packages.
3. The i386 NSIS fixture passes silent installation, payload execution,
   uninstall-section cleanup, and registry removal.
4. Inno Setup 6.3.3's real i386 `ISCC.exe` executes through WoW64 and compiles
   the deterministic fixture. The pinned, relocatable native ARM64
   `innoextract` closure recovers and byte-validates its payload. Inno 6.5.4
   is pinned and classified, but its GUI setup transaction is not claimed;
   packages use the extraction fallback when direct execution is unsuitable.
5. The read-only classifier recognizes MSI, Inno, NSIS, WiX Burn,
   InstallShield, Squirrel, ClickOnce, MSIX, and AppX families. Unsupported
   engines return a bounded diagnostic failure and never create a prefix.

Evidence: `docs/validation/installer-completion-20260728/RESULTS.md`.

### Workstream D — browser and launcher engines

1. Pin Wine Gecko 2.47.4 x86 and x86_64 packages, stage them in-tree, and
   prove `mshtml` document creation, JavaScript, HTTPS, DOM events, and
   navigation without a download prompt.
2. Integrate MetalSharp's source-preserved CEF compatibility wrapper and
   child-process hook for i386 and x86_64 launchers.
3. Gate CEF `libcef.dll` loading, browser/renderer/GPU subprocess creation,
   sandbox-disabled compatibility mode, offscreen rendering, input, audio,
   HTTPS, and clean child teardown.
4. Add a WebView2 fixed-runtime lane; prove Evergreen-style installers and
   WebView2-based launchers separately from CEF.
5. Cover Electron launchers and common embedded-browser launch patterns.

### Workstream E — managed and language runtimes

1. Extract the signed/notarized Oracle JRE 8u501 ARM64 payload from the local
   DMG into a pinned native-Java stage. Preserve license/provenance and do not
   silently redistribute it outside the user's private runtime.
2. Gate native `java -version`, class execution, JAR launch, JNI, JavaFX,
   networking/TLS, audio, and launcher handoff from a Wine bottle.
3. Add separately pinned Windows JRE/JDK i386 and x86_64 lanes for applications
   that require Windows JNI DLLs; a macOS JRE cannot satisfy that ABI.
4. Stage and gate Wine Mono, .NET Framework 3.5/4.8, modern .NET Desktop
   Runtime, PowerShell-hosted installer actions, and common VC++ runtimes.
5. Add opt-in Python and Node.js Windows runtime fixtures for launchers that
   embed those engines.

Status (2026-07-29): the private Oracle JRE 8u501 ARM64 payload is pinned,
staged, and accepted for the HotSpot Server VM, class/JAR execution, ARM64
JNI, deterministic TLS 1.2, and Wine-prefix-to-native-process handoff.
Official Wine Mono 11.2.0 is pinned from GitHub, its x86 and x86_64
engines are preserved unchanged, and a source-built ARM64 engine is integrated
with the VKMT ABI/W^X contract. Wine's process, Unix loader, Windows loader,
and server image-view paths now agree that same-bitness PE32+ IL-only images
use the native 64-bit CLR rather than starting `xtajit64`. One disposable
prefix passes managed compile and direct execution gates for ARM64, x86_64,
and i386, followed by the ordinary ARM64/ARM64EC/x86_64/i386 single-prefix
regression. Windows Java, .NET Framework/modern .NET/PowerShell, and opt-in
Python/Node remain.

Windows Java implementation is scoped in
`docs/architecture.md`: i386 uses the newest published Temurin 8
x86 Client VM through FEX/WoW64, while x86_64 uses the Temurin 8 Server VM
through `xtajit64`. The plan freezes the golden providers, stages candidates
side by side, and gates interpreter, JNI/services, JIT/W^X, TSO atomics,
safepoints, and unified-prefix regressions before promotion.
The Java lane retains FEX's x86 TSO model but requires software ARM64 ordering
at final emission: aligned `LDAR`/`STLR`, barrier-backed unaligned accesses,
and acquire/release locked atomics. It may not depend on Apple hardware TSO.

### Workstream F — common game/application redistributables

**Closed by scope decision (2026-07-29).**

The current Wine build already contains the desired D3DCompiler,
XAudio2/XACT, UCRT/Visual C++/ATL, MSXML, Quartz, Media Foundation, MIDI,
WineGStreamer, and Windows codec modules. XNA/FNA and FAudio assets are
preserved through MetalSharp. No additional Workstream F staging, probing, or
validation is required. Legacy D3DX9/10/11, MFC, OpenAL, PhysX, and additional
core-font payload work are outside the completion plan.

There is no Workstream G. Enterprise services and additional peripheral coverage
are explicitly outside this runtime's completion plan.

### Final acceptance

One fresh prefix must pass:

1. Native ARM64 wineboot and baseline architecture/graphics regressions.
2. XInput/DInput and audio/media fixtures.
3. MSI/WiX, NSIS, and Inno install/uninstall fixtures.
4. Gecko/MSHTML, CEF, WebView2, and Electron launcher fixtures.
5. Native-Java handoff plus Windows Java and .NET fixtures.
6. HTTPS through staged GnuTLS with no Homebrew dependency.
7. Exact wineserver/child-process shutdown and cleanup.

Kernel anti-cheat, kernel DRM, Windows Store identity/licensing, and arbitrary
Windows kernel drivers remain application-specific boundaries. They must be
reported honestly rather than hidden behind a broad compatibility claim.

## i386 and WoW64 execution contract


This document is the implementation and acceptance contract for Workstream 3. It
does not describe a low-address compatibility mode. The supported design is a
native ARM64 Wine process hosting a native ARM64 FEX `xtajit.dll`, with i386
addresses represented independently from Darwin host pointers.

### Address ownership

- Wine owns the i386 guest virtual-address space and is the sole authority for
  assigning, mapping, protecting, and retiring guest ranges.
- A guest address is always a 32-bit value. A host pointer may be anywhere in
  the ARM64 address space and must never be truncated, biased, or used as the
  source of a guest address.
- Wine publishes explicit `(guest page, host page)` records to FEX. FEX may
  resolve a host notification back through those records, but it may not
  invent a mapping or derive a guest address by truncating a host pointer.
- The guest page size is 4 KiB. Host VM operations must respect Darwin's actual
  host page size, currently 16 KiB on Apple Silicon. Adjacent guest pages are
  not required to have adjacent host backing.

### Publication and invalidation ordering

Successful allocation or section mapping is published in this order:

1. Wine commits the native mapping and assigns its guest range.
2. Wine commits the range to its authoritative registry.
3. Wine publishes the guest-page records to FEX with release ordering.
4. Wine sends the host-range protection/image notification to FEX.

Successful release or unmap is retired in this order:

1. Wine retains the guest identity and host range before invoking the native
   operation.
2. FEX invalidates translated code and prevents new use of the retiring host
   range.
3. Wine commits the successful native release/unmap.
4. Wine unpublishes the guest pages and retires the registry entry.

Protect, dirty, and instruction-cache notifications keep the guest identity
stable. Guest-map publication and host-range code invalidation are separate
interfaces even when one VM operation triggers both.

### FEX execution invariants

- EIP, ESP, all i386 GPRs, FS base, stack entries, BOP return addresses,
  callback frames, APC frames, and exception frames remain guest values.
- Instruction fetch and every generated guest-memory access resolve through
  the published page map. Cross-page accesses translate every participating
  guest page and never assume contiguous host backing.
- Unmapped, non-executable, or inaccessible guest pages raise the corresponding
  guest exception. A null page-table entry must not become a host address.
- Mapping changes are observed through acquire/release publication of the
  page-table entries. Wine's serialized memory notifications evict guest-keyed
  decode and execution-cache entries before stale code can run.
- FEX code-cache memory is host-only. Every dispatcher, initial thunk, compiled
  block, link patch, and unlink patch follows one reviewed Darwin W^X protocol
  and flushes the ARM64 instruction cache before execution.

### Extended independent gate ladder

This follow-on ladder is intentionally split so a failure has one likely
owner. The current Workstream 3 fixture implements the basic, SMC, and lock cases,
plus loader/syscall-boundary coverage needed to reach them:

1. `basic`: arithmetic, branches, calls, returns, and process exit.
2. `stack`: deep calls and a return frame crossing a guest-page boundary.
3. `memory`: lifecycle and scalar/vector accesses across non-contiguous host
   pages, including 32-bit effective-address wrapping.
4. `fetch`: an i386 instruction crossing a guest-page boundary.
5. `smc`: RW -> RX execution, RX -> RW modification, flush, and re-execution.
6. `locks`: interlocked operations and a contended critical section using two
   guest threads.
7. `boundary`: BOP syscall and Wine Unix-call argument/return frames.
8. `exceptions`: breakpoint, access violation, APC, and user callback delivery.
9. `lifecycle`: imports, TLS, second-thread startup/exit, `wineboot`, and clean
   wineserver shutdown.

The aggregate i386 smoke probe is acceptance evidence only after all focused
gates pass in a new prefix. Every disposable run root lives below
`build/probe-runs` on the external SSD and is stopped through its exact
`wine/build-ec/server/wineserver` before the exact run root is moved to Trash.

### Current Workstream 3 completion evidence

The current Workstream 3 execution contract is complete when its aggregate fixture
passes arithmetic, branches, stack calls, critical sections, locked atomics,
executable allocation, and self-modifying-code re-execution in a fresh prefix;
the CPU provider and native Wine processes are ARM64; and no Rosetta or x86
Mach-O dependency participates. The remaining extended ladder items are
separate regression expansion, not evidence already claimed by this fixture.

## i386 and WoW64 implementation record


### Decision

The i386 implementation is FEX's native ARM64 Windows/WoW64 CPU-provider,
built as `xtajit.dll` and loaded through Wine's existing WoW64 CPU-provider
ABI.  This is not FEX's Linux user-mode executable: the Windows module does
only x86 instruction translation, while Wine continues to perform NT syscall
conversion and Unix-call dispatch.  Consequently every Unix library remains
native ARM64 and no x86 rootfs, i386 Mach-O binary, QEMU process, or Rosetta is
involved.

FEX-2607 is pinned at commit `1cc4b93e7a71c883ec021b71359f136394dc1f3c` and
is built from `third_party/FEX-2607`.  The build uses the project LLVM-mingw
toolchain and reserves `x28`, matching the native ARM64 Wine TEB ABI on
Darwin.  QEMU remains unnecessary and is not part of the shipped stack.

### What already exists

Wine already selects `xtajit.dll` for an i386 process on an ARM64 native
machine (`dlls/wow64/syscall.c`).  That module supplies the `BTCpu*` entry
points used to enter guest code, return to WoW64 for an NT syscall, manage
thread contexts, and report memory-map changes.  The x64 `xtajit64` module is
the model for its build and integration shape.

The current macOS failure is earlier and intentional: `build_wow64_parameters`
requires process data below 4 GiB, but native ARM64 Darwin does not provide a
usable sub-4-GiB mapping.  Merely removing the rejection would truncate host
pointers stored in PEB32/TEB32 structures and corrupt the process.

The restriction is verified on the target host: normal ARM64 processes reserve
the first 4 GiB in `__PAGEZERO`, and `MAP_FIXED` allocations in that range fail
with `ENOMEM`.  Linking a diagnostic binary with a smaller `__PAGEZERO` causes
macOS to terminate it at launch, so this is not a linker flag that Wine can
safely use.  FEX supplies the CPU translation layer but cannot by itself alter
this Darwin virtual-memory contract.

### M6.0 — i386 execution substrate (hard gate)

Implement a 32-bit **guest virtual-address** layer whose 32-bit values never
depend on the high native ARM64 host addresses used to back them.  Every
conversion at the WoW64 boundary must be explicit and checked.

Work items:

1. Build and stage FEX's ARM64 `xtajit.dll`, with the complete `BTCpu*`
   contract required by `dlls/wow64/syscall.c`.
2. Resolve Darwin's unavailable sub-4-GiB host mapping without casting a high
   host pointer to `ULONG`.  This must preserve the Windows guest address
   space, allocation, protection, unmap, and image-map notifications.
3. Route PEB32, TEB32, `WOW32Reserved`, syscall thunks, stack setup, context
   get/set, and exception delivery through that safe address boundary.
4. Add independent fixtures: process start/exit, arithmetic and control flow,
   read/write guest memory, `LoadLibrary`, NT syscall return, TLS, exceptions,
   and a second thread.

**Exit criterion:** a genuine i386 PE runs under the native ARM64 Wine loader,
executes those fixtures, and completes the relevant WoW64 tests without any
host-pointer truncation or low-address host mapping assumption.  No graphics
work starts before this gate passes.

### M6.1 — i386 Vulkan graphics probe

Both vendored projects already include Win32 cross files:

* `third_party/dxvk/build-win32.txt`
* `third_party/vkd3d-proton/build-win32.txt`

Wine also already builds i386 PE `d3d12core.dll` and the associated system
DLLs.  This workstream builds the eligible 32-bit PE front ends and verifies their
WoW64 marshalling to the native ARM64 Unix side.  MoltenVK remains native
ARM64; it has no guest-bitness variant.  The gate is therefore the i386
Windows ABI and the Wine Unix-call boundary, not an i386 MoltenVK build.

Acceptance sequence:

1. Verify PE machine type and DLL routing for i386 `dxgi`, `d3d12`, and
   `d3d12core`.
2. Run an i386 D3D12 device/adapter probe.
3. Run a resource/command-list smoke test, then repeat with the eligible DXVK
   D3D9/D3D10/D3D11 PE DLLs.

### M6.2 — i386 DXMT probe

DXMT v0.80 already supplies i386 `d3d10core.dll`, `d3d11.dll`, `dxgi.dll`,
and `winemetal.dll`.  Build those PE DLLs from its pinned source together with
the M5.5 native ARM64 `winemetal.so`; do not build or attempt to load an i386
Unix driver on macOS.

Acceptance sequence:

1. Confirm i386 PE architecture, builtin routing, and ARM64 Unix-driver
   selection.
2. Probe `WMTCopyAllDevices`.
3. Probe `D3D11CreateDevice`, then issue a minimal resource/draw workload.

### M6.3 — source-integrated product build

Move each successful component behind a reproducible source-controlled build
step and staged installation layout: Wine/xtajit, MoltenVK, vkd3d-proton,
DXVK when eligible, and DXMT.  The final distribution may not depend on a
hand-copied DLL directory, `WINEDLLPATH`, or prebuilt runtime archive.

The release gate is a clean checkout, fetch, and rebuild followed by native
ARM64, x64-on-ARM64, and i386 probe runs using only the produced installation.

### Guest-managed boundary implementation plan (2026-07-27)

This plan supersedes any assumption that a 32-bit guest pointer can be used as
an ARM64 Darwin host pointer. FEX remains a native ARM64 Windows CPU provider
(`xtajit.dll`), Wine retains syscall and Unix-call ownership, and all Unix,
Vulkan, MoltenVK, and Metal modules remain native ARM64. QEMU, i386 Mach-O,
and Rosetta are not part of this design.

#### 1. Freeze and characterize the existing boundary

Preserve the current FEX and Wine worktree state without reset, cleanup, or
rebuild. Capture one fresh i386 launch with loader resolution, selected host
arena, guest-to-host conversions, `BTCpu*` entry/return, and first failure.
Record exact revisions, staged PE/Mach-O architectures, prefix lifecycle, and
the first failing boundary. This workstream does not change runtime behavior.

#### 2. Canonical guest-address manager

Introduce one Wine-owned conversion layer for i386 guest virtual addresses.
Guest addresses are always `uint32_t`; host mappings may be arbitrary native
ARM64 addresses. Only named checked helpers may convert between them. The
manager owns reserve/commit, images, protection, unmap, PEB32/TEB32, stacks,
and KUSER mappings. A high contiguous arena may be used as a fast path but
cannot be a correctness requirement.

##### 2026-07-27 implementation checkpoint

`dlls/wow64/memory.c` is the sole i386 guest-address conversion layer. It
uses checked, registered guest-range to host-range mappings and gives explicit
non-contiguous mappings precedence over the existing Darwin high-arena
compatibility aperture. The syscall, VM, process, security, synchronization,
and system wrappers now use named conversions rather than truncating host
pointers.

The manager registers the bootstrap TEB32, PEB32, process parameters, guest
stack, and KUSER data, and the VM wrappers register allocation and section-map
results, retain mappings across protect/commit, and remove them only after
successful release/unmap. With `WINEDEBUG=+wow`, its in-process fixture uses
independent guest ranges for native host mappings above 4 GiB and validates
allocate, guest-to-host and host-to-guest conversion, protect, free, map, and
unmap. The trace on 2026-07-27 reached:

```
i386 guest memory selftest passed: allocate/map/protect/unmap above 4GiB
```

This proves the Wine-side VM contract. The subsequent FEX page-map/TLB work
remains Workstream 3: it must consume these registered mappings rather than assume
a linear aperture for generated guest memory accesses.

#### 1.5. Close the CPU-provider import contract

Before invoking guest execution, enumerate `xtajit.dll` imports against Wine's
native ARM64 PE exports and implement or deliberately remove every unresolved
provider import. The first recorded gap is `ntdll.RtlWow64SuspendThread`, used
by FEX for non-self thread suspension. This is an ABI gate, not a reason to
weaken address conversion or bypass thread safety. Re-run the Workstream 1 launch
with an explicit `BTCpuSimulate` entry/return record after the import surface
is closed.

#### 3. FEX provider contract

Make FEX retain EIP, ESP, GPRs, contexts, callbacks, and return addresses as
guest values. Instruction fetch and generated memory accesses resolve through
the manager's page map/TLB. Wire every Wine memory notification to FEX cache
invalidation and mapping state. Complete context, syscall/Unix-call, TLS,
exception, APC, and thread-lifecycle behavior; first focused regression is
`RtlEnterCriticalSection` plus subsequent locked operations.

#### 4. Non-graphics i386 substrate gate

In a fresh disposable prefix, prove wineboot and clean server exit, then
process start/exit, arithmetic/control flow, memory lifecycle, imports,
syscall return, TLS, exceptions, APCs, and a second thread. Every fixture must
assert that guest pointers remain 32-bit and no raw host-pointer truncation is
used.

##### 2026-07-27 completion result

Workstream through 4.8 are complete. The unified fixture and runner are
`test/i386/phase4_contract.c`, `test/i386/phase4_helper.c`, and
`scripts/probe-i386-wow64-phase4.sh`. One fresh prefix passed native ARM64
`wineboot --init`, DLL loading,
syscall return/output pointers, executable/DLL/dynamic TLS, suspended i386
context get/set, software and hardware SEH with resume, two ordered APCs,
second-thread state isolation, a real headless Wine user callback, eight
thread-lifecycle cycles, and the Workstream 3 guest-memory regression.

The callback gate uses `WH_MSGFILTER` plus `CallMsgFilter`: ARM64 `win32u`
enters `KeUserModeCallback`, ARM64 `wow64win` marshals the hook frame, i386
`user32` calls the application hook, and `NtCallbackReturn` restores the
native frame. It does not create a window or initialize a display driver.

The same acceptance session re-proved the unified ARM64/AArch64/ARM64EC gate
and the separate x86_64 DXVK deterministic readback gate. Evidence is in
`docs/validation/wow64-system-contract-20260727/RESULTS.md`; the focused
Wine change is commit `d43a990`.

This closes the non-graphics system contract only. Remaining i386 GDI/D3DKMT
data-pointer marshalling is owned by the following graphics workstream and must not
be inferred from these results.

#### 5. Graphics gates after substrate success

Validate VKMT and DXMT separately. VKMT is i386 PE DXVK/vkd3d-proton through
native ARM64 Wine Unix libraries and MoltenVK; DXMT is i386 PE frontends and
`winemetal.dll` through the paired ARM64 `winemetal.so`. For each route use
load/export, factory/adapter, device, queue/resource, and deterministic
readback gates. Never mix the DXVK and DXMT D3D11/DXGI pairs.

##### Workstream 5 execution plan — i386 VKMT (complete 2026-07-28)

Workstream is accepted. The final fresh-prefix runner produced all five required
markers after rebuilding the selected i386 DXVK and vkd3d-proton DLLs with
the in-tree LLVM-MinGW 22.1.8 toolchain. Wine `97ff7730`, FEX `baaca8565`,
DXVK `ab0f99ac`, and vkd3d-proton `3300fe64` are the accepted revisions.
Detailed evidence and architecture hashes are in
`docs/validation/i386-graphics-20260727/RESULTS.md`.

The retained `p5-i386-vkmt.NDwg2k` diagnostic root was disposed after final
acceptance. `scripts/probe-p5-i386-vkmt.sh` now always creates one fresh
external-SSD prefix, stops its exact wineserver, and removes that run root
unless explicit diagnostic retention is requested.

**Accepted scope and fixed inputs.** The Windows front ends are i386 PEs;
every Unix library and every host executable is ARM64 Mach-O. On any future
failure, stop that prefix with its exact `wineserver -k` then `-w`, dispose
that exact run root, and only then start a fresh run.

```
i386 dxgi.dll / d3d11.dll (DXVK)       i386 d3d12.dll / d3d12core.dll (vkd3d-proton)
                  |                                      |
                  +----------- i386 winevulkan.dll -------+
                                      |
                        ARM64 winevulkan.so / ntdll.so
                                      |
                       pinned ARM64 MoltenVK → Apple Metal
```

The authoritative inputs are `third_party/dxvk/runtime/dxvk-vkmt-1a5919b/x32`,
`third_party/vkd3d-proton/install-win32/bin`, `wine/build-ec`, and the pinned
MoltenVK dynamic library.  Before any runtime gate, record `llvm-readobj`
machine type `IMAGE_FILE_MACHINE_I386` for every PE and `lipo -archs` value
`arm64` for `wine`, `wineserver`, `ntdll.so`, `winevulkan.so`, and MoltenVK.

**5.1 — close the i386 Winevulkan ABI boundary.** The current first failure
was a raw i386 guest pointer passed to the ARM64 `winevulkan.so` in
`wow64_init_vulkan`.  The generated `vulkan_thunks.c` must use the named
guest-to-host and host-to-guest conversion helpers for data pointers; the only
remaining direct 32-bit casts may be documented `PFN_*` guest callback
pointers.  Build only `ntdll.so`, `wow64.dll`, `winevulkan.so`, and the i386
`winevulkan.dll`; stage only those two PEs into the retained prefix.  The
focused `i386_vkmt_dxgi_probe.exe` must create a Vulkan instance and enumerate
the Apple M4 in the DXVK log without a guest-address fault.  This gate does
not require a DXGI factory yet.  On a pointer fault, stop here and repair the
Winevulkan/NTDLL conversion owner; do not change DXVK features or FEX.

**5.2 — accept DXGI factory and adapter enumeration.** Rebuild the x32 DXVK
PEs from the pinned source, stage only `dxgi.dll` and `d3d11.dll`, and run
`test/i386_vkmt_dxgi_probe.c` in the retained prefix.  Its required output is
`P5_I386_DXGI_FACTORY_OK`, followed by `P5_I386_DXGI_ADAPTER_OK`; the log must
identify the Apple M4 adapter.  The present failure after Vulkan enumeration
is DXVK's x32 `geometryShader` eligibility check, so the immediate work item
is to validate the freshly built x32 DLLs containing the MoltenVK portability
feature policy.  If factory creation fails before the DXVK device list, own it
in Winevulkan/ABI; if DXVK sees the device but rejects a required feature, own
it in DXVK; if it lists no Vulkan device, own it in ICD/MoltenVK setup.  Do
not advance to D3D12 until both markers are produced by one run.

**5.3 — accept the i386 D3D12 device boundary.** With 5.2 still staged,
stage only vkd3d-proton's pinned i386 `d3d12.dll` and `d3d12core.dll` and run
the i386 build of `test/d3d12_probe_nodxgi.c`.  Require a successful
`D3D12CreateDevice`, a vkd3d-proton log naming the native Vulkan device, and
MoltenVK evidence of `VkDevice` creation.  Keep DXVK out of this probe: it is
not a DXGI acceptance test.  A failure before the PE exports is routing; from
PE entry through Unix call is a WoW64 ABI failure; after Vulkan feature query
is a vkd3d-proton/MoltenVK capability failure.

**5.4 — accept deterministic i386 D3D12 execution.** Reuse exactly the
5.3 route and fixture, which performs upload → default buffer → explicit
COPY_DEST-to-COPY_SOURCE barrier → direct-queue execute → fence wait →
readback.  Require the fixture's `PROBE OK` and the exact CPU value
`0x4b4d5456`; record command submission and `VkDevice` evidence.  The result
must be deterministic on two consecutive invocations in the same prefix.
If it fails, classify the first missing step as command marshalling, resource
state/barrier, queue/fence synchronization, or readback mapping before making
another source change.

**5.5 — accept i386 D3D11/DXVK execution.** Use only the matching x32 DXVK
`dxgi.dll` and `d3d11.dll` from 5.2, never a DXMT DLL.  Run the i386 build of
`test/d3d11_probe.c`; require `VKMT_D3D11_PROBE_OK`, DXVK's adapter/device
record, and MoltenVK `VkDevice` evidence.  The fixture must cover device
creation plus clear/copy/readback.  If it fails after D3D12 passed, treat it
as a DXVK D3D11 path issue, not evidence to reopen vkd3d-proton or FEX.

**5.6 — reproduce, package, and preserve.** Dispose the retained diagnostic
prefix only after its focused boundary has either passed or been fully
captured.  Then run `scripts/probe-p5-i386-vkmt.sh` once from a new disposable
root with the exact same staged inputs; it must print all five final markers:
`P5_I386_DLL_LOAD_OK`, `P5_I386_DXGI_FACTORY_ADAPTER_OK`,
`P5_I386_D3D12_DEVICE_QUEUE_FENCE_COPY_READBACK_OK`,
`P5_I386_D3D11_DEVICE_CLEAR_COPY_READBACK_OK`, and `P5_I386_VKMT_OK`.
Archive concise logs and architecture evidence under `docs/validation/`,
make source-controlled targeted build/stage rules reproduce the selected
artifacts, update `AGENTS.md`, and commit only after that clean run.  A
passing retained diagnostic run alone is not a Workstream 5 acceptance result.

##### Workstream 6 — i386 DXMT (begins only after Workstream 5.6)

Stage the pinned DXMT 0.80 i386 `dxgi.dll`, `d3d11.dll`, and
`winemetal.dll` with the already-native ARM64 `winemetal.so` and its relative
`libunwind.1.dylib`.  First prove DLL routing and `WMTCopyAllDevices`, then
`D3D11CreateDevice`, then a separate minimal clear/copy/readback probe.  The
DXMT D3D11/DXGI pair never shares a prefix-stage test with DXVK's pair.  The
host must load the ARM64 `winemetal.so`; an i386 Mach-O bridge is invalid and
is a hard failure.

##### Workstream 7 — final multi-architecture acceptance and release integration

Run the maintained fresh-prefix probes in this order: pure ARM64/AArch64,
ARM64EC, x86_64 through `xtajit64`, i386/WoW64 non-graphics contract, i386
VKMT, then i386 DXMT.  Each run must use only source-built/staged artifacts,
native ARM64 host binaries, the pinned MoltenVK ICD, an exact wineserver
shutdown, and disposable external-SSD storage.  The final review records
`lipo`/`llvm-readobj` output, loaded Unix bridge paths, no Rosetta process,
and no hand-copied dependency outside the staged tree.

#### 6. Product integration

Put every proven source change behind targeted build/stage rules, preserve
architecture/routing checks and exact-prefix cleanup in probes, update this
document and `AGENTS.md`, and commit only validated focused changes. Do not
perform a full Wine rebuild unless generated configuration genuinely requires
it.

## Windows Java and WoW64 compatibility


### Decision and fixed baseline

Windows Java is feasible on this stack, but it is a guest runtime and is
separate from the accepted native Oracle JRE 8u501 ARM64 lane. The Windows
i386 JVM executes through Wine WoW64 and the native ARM64 FEX `xtajit.dll`;
the Windows x86_64 JVM executes through `xtajit64.dll`. Windows JNI libraries
must match the guest JVM architecture. Neither guest JVM may load an ARM64
Mach-O JNI library.

The canonical accepted providers after J6 are:

- i386 `xtajit-arm64-known-good.dll`, SHA-256
  `fe1345724f6a2950541966515f766099b7bce38701c9960d4be513c27ec81073`;
- x86_64 `xtajit64-arm64ec-known-good.dll`, SHA-256
  `7b9f55ceabe971ffa1f514570bb54ed7b5640959e4440e7f8a013e9af13ab7e6`.

The current FEX worktree contains later uncommitted TSO, unaligned-memory,
W^X, exception, and ARM64EC candidates. They are evidence and candidate
source, not permission to overwrite the golden providers. A Java candidate
must be built to a side directory and selected through
`VKMT_XTAJIT_SOURCE`/`VKMT_XTAJIT_SHA256`.

#### Mandatory memory-model invariant

Do not remove or bypass FEX's x86 TSO semantic model. Also do not depend on
Apple hardware TSO being present. Guest operations remain classified as TSO
through the IR, and the final AArch64 emitter supplies their ordering:

- naturally aligned scalar load: size-appropriate `LDAR`;
- naturally aligned scalar store: size-appropriate `STLR`;
- unaligned scalar load: ordinary `LDR` followed by `DMB ISHLD`;
- unaligned scalar store: `DMB ISH` followed by ordinary `STR`;
- locked read/modify/write: acquire/release atomic operation or
  `LDAXR`/`STLXR` loop, with a serialized fallback for split or unaligned
  atomics.

The alignment-selection sequence must preserve NZCV. Darwin W^X means the
unaligned form is emitted before publication; it may not depend on patching an
RX JIT page after an alignment fault. The existing candidate's optional
`LDAPR` path is not the conservative Java baseline: use `LDAR` unless a
separate cumulative-ordering proof and fixture justify otherwise.

### Pinned inputs discovered during scoping

As of 2026-07-29, Eclipse Temurin publishes different latest Java 8 levels for
the two Windows architectures:

- i386: Temurin 8u472-b08,
  `OpenJDK8U-jre_x86-32_windows_hotspot_8u472b08.zip`, SHA-256
  `21a2c5af684a658f1484daa85eabf4961ab9de28c0efbf31da2381d77fce3b5f`,
  from
  `https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u472-b08/OpenJDK8U-jre_x86-32_windows_hotspot_8u472b08.zip`;
- x86_64: Temurin 8u492-b09,
  `OpenJDK8U-jre_x64_windows_hotspot_8u492b09.zip`, SHA-256
  `bb25b002556afc7ef158cd95ec6270dddb3eecba69acdd7abb9d28b2e9ff0f5e`,
  from
  `https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jre_x64_windows_hotspot_8u492b09.zip`.

The archives were inspected transiently on the external SSD and the inspection
roots were removed. The i386 archive contains PE32 `java.exe` and
`bin/client/jvm.dll`; it does not contain a Server VM. The x86_64 archive
contains PE32+ `java.exe` and `bin/server/jvm.dll`. Therefore i386 acceptance
means HotSpot Client VM interpreter plus C1 JIT; x86_64 acceptance means
HotSpot Server VM plus its JIT.

Both VM DLLs import the UCRT API-set surface, `VCRUNTIME140.dll`, Kernel32,
PSAPI, User32, Version, WinMM, and Winsock. Both use PE TLS, virtual-memory
allocation/protection/query, mapped files, thread suspend/resume/context,
events/condition variables, process creation, exception filters, dynamic DLL
loading, and performance counters. The i386 VM also contains `cmpxchg8b`,
`movntq`, and REP move/store instruction families.

### Boundary ownership map

| HotSpot surface | Existing owner | First files to inspect if its gate fails |
| --- | --- | --- |
| 32-bit heap, code-cache and mapped-JAR addresses | Wine canonical guest-memory manager | `dlls/wow64/memory.c`, `dlls/wow64/virtual.c`, `dlls/ntdll/unix/virtual.c` |
| Guest effective-address translation | FEX i386 page-table path | `JIT/MemoryOps.cpp`, `JIT/AtomicOps.cpp`, `JIT/JITClass.h` |
| JIT RW→RX, instruction-cache flush and SMC eviction | Wine VM notifications plus FEX code cache | `dlls/wow64/virtual.c`, `Source/Windows/WOW64/Module.cpp`, `CPUBackend.cpp`, `JIT/JIT.cpp`, `Core.cpp`, `CodeCache.cpp` |
| x86 TSO, volatile accesses, CAS and unaligned access | FEX TSO IR plus final ARM64 memory/atomic emitter; never host TSO | `JIT/MemoryOps.cpp`, `JIT/AtomicOps.cpp`, `Common/TSOHandlerConfig.h`, `ArchHelpers/Arm64Emitter.*` |
| TLS and segment bases | Wine loader/WoW64 plus FEX CPU state | `dlls/ntdll/loader.c`, `dlls/wow64/syscall.c`, `Source/Windows/WOW64/Module.cpp`, `CoreState.h` |
| Implicit null checks, stack guards, SEH and continuation | Wine exception dispatch plus FEX reconstruction | `dlls/wow64/syscall.c`, `dlls/ntdll/unix/signal_arm64.c`, `Source/Windows/WOW64/Module.cpp` |
| Safepoint suspension and thread context | Wine thread syscalls plus `BTCpu*Context` | `dlls/wow64/process.c`, `dlls/wow64/syscall.c`, `Source/Windows/WOW64/Module.cpp` |
| JNI DLL routing and dependencies | Wine PE loader and architecture-specific stage | `dlls/ntdll/loader.c`, `dlls/kernelbase/loader.c`, UCRT/VCRUNTIME stages |
| `ProcessBuilder` child creation | Wine WoW64 process conversion | `dlls/wow64/process.c`, `dlls/ntdll/unix/process.c` |
| Networking/TLS | i386 Winsock/AFD and Java JSSE | `dlls/ws2_32`, `dlls/wow64/file.c`, staged GnuTLS only where Wine APIs participate |

This map is diagnostic ownership, not a list of files to edit preemptively.
The first failing gate selects the owner.

### Workstream J0 — preserve and stage — complete 2026-07-29

1. Record root, Wine, and FEX revisions, all dirty nested-source paths, golden
   provider hashes, and the current four-architecture baseline.
2. Add checksum-pinned fetch and stage scripts for the two ZIP archives. Stage
   them separately under `wine/build-ec/java-runtime/i386` and
   `wine/build-ec/java-runtime/x86_64`; never merge their `bin` directories.
3. Verify PE machine type for `java.exe`, `javaw.exe`, `jvm.dll`, and every
   native JRE DLL. Verify the matching UCRT/VCRUNTIME dependency closure before
   launch.
4. Build candidates only under `build/fex-wow64-java/`. Adjust the existing
   FEX builder before using it so it cannot replace the canonical
   `xtajit.dll`.
5. Add a provider-mode review proving Darwin uses software TSO lowering, then
   disassemble focused aligned, unaligned, and locked fixtures. Require the
   exact `LDAR`/`STLR` or `LDR`/`DMB`/`STR` families above before launching
   either JVM.

Gate: inputs, hashes, architecture manifests, and provider selection are
deterministic; the golden provider files remain byte-identical; software TSO
lowering is visible in generated ARM64 code.

Acceptance evidence is
`docs/validation/windows-java-j0-20260729/RESULTS.md`. The retained,
source-integrated side baseline is `third_party/FEX-2607-java-baseline`; its
accepted candidate is deliberately not promoted before the later Java and
WoW64 regression workstreams.

### Workstream J1 — loader and interpreter gate — complete 2026-07-29

At each step, run x86_64 first as the fixture/control lane and then i386 in the
same fresh prefix:

1. run the focused TSO publication/CAS preflight with the selected provider;
2. `java.exe -version`;
3. i386 `-client -Xint -version`, x86_64 `-server -Xint -version`;
4. class-path execution;
5. executable-JAR execution;
6. reflection, class loading, ZIP/JAR reads, and clean VM shutdown.

Require logs to identify the expected VM and data model: i386 Client VM/32-bit
and x86_64 Server VM/64-bit. No JIT fix is considered during this workstream.

Failure ownership:

- missing import or wrong DLL machine → stage/loader;
- guest address outside the registered map → Wine guest-memory owner;
- missing/incorrect x86 instruction → FEX decoder/emitter;
- exception before `_JNI_CreateJavaVM` → loader/TLS/CRT boundary.

Gate: both interpreters run the same class and JAR fixtures and exit exactly.

Acceptance evidence is
`docs/validation/windows-java-j1-20260729/RESULTS.md`. One fresh prefix ran
x86_64 first and i386 second; both reported interpreted mode, the correct
Server/Client VM and data model, and identical class-path, executable-JAR,
reflection/class-loader, and ZIP/JAR markers before exact shutdown.

### Workstream J2 — services and guest JNI gate under `-Xint` — complete 2026-07-29

Use architecture-matched Windows JNI DLLs built with the in-tree LLVM-MinGW
toolchain. Cover:

1. JNI load, symbol lookup, 32/64-bit pointer width, callbacks, and
   attach/detach from a second native thread;
2. allocation pressure, explicit GC, direct byte buffers, mapped files, and
   repeated class-loader creation;
3. Java threads, monitors, TLS, exceptions, stack overflow, and shutdown
   hooks;
4. `ProcessBuilder` child launch and inherited environment;
5. sockets plus deterministic local HTTPS/TLS;
6. timing and sleeps driven by `QueryPerformanceCounter`.

Gate: identical semantic markers from i386 and x86_64, no host pointer in an
i386 exception or Java-visible address, and no leaked child process.

Acceptance evidence is
`docs/validation/windows-java-j2-20260729/RESULTS.md`. One fresh prefix ran
x86_64 first and i386 second. Architecture-matched JNI DLLs passed load,
callback, exception, pointer-width, and native-thread attach/detach gates.
Both interpreted JVMs then passed matching allocation/GC, direct and mapped
buffer, class-loader, monitor/TLS, exception/stack-overflow, child-process,
socket, local HTTPS, timer, sleep, and shutdown-hook fixtures. The i386
Java-visible native address was `0x78925034`, the mapped files were removed
at VM shutdown, and exact wineserver shutdown left no child or prefix.

### Workstream J3 — HotSpot JIT and executable-memory gate — complete 2026-07-29

Enable one compiler at a time:

- i386: Client VM/C1 with a low compile threshold, then `-Xcomp`;
- x86_64: Server VM with normal tiering, then `-Xcomp`.

Fixtures must prove compilation occurred, then exercise:

1. code-cache reserve/commit and RW→RX transitions;
2. `FlushInstructionCache` and FEX guest-block invalidation;
3. deoptimization, uncommon traps, class unloading, and recompilation;
4. implicit null checks, divide-by-zero, stack guards, and exception resume
   from compiled code;
5. repeated code-cache growth without a stale guest-to-host block.

Do not patch Java binaries. On the first fault record guest EIP, host PC,
guest fault address, translated host address, mapping/protection, current
provider hash, and last completed Java marker.

Gate: both JIT lanes complete twice in one prefix and report nonzero compiled
method counts.

Acceptance evidence is
`docs/validation/windows-java-j3-20260729/RESULTS.md`. One fresh prefix ran
x86_64 Server tiered and scoped `-Xcomp`, then i386 Client/C1 and scoped
`-Xcomp`. All four lanes passed with nonzero fixture compilation counts,
nonzero HotSpot compilation time, four code-cache unload/reload waves, and
architecture-matched RW→RX/patch/flush executable-memory fixtures. Tiered
lanes own uncommon-trap and exception-resume acceptance; forced lanes own
compile-on-first-use and repeated execution, with orchestration/reflection
and exception-catching coordinators deliberately excluded from `-Xcomp`.

The x86_64 side provider is
`build/xtajit64-java-j3-final/provider/xtajit64.dll`, SHA-256
`3c5878816c78dc670190e3587e76ace53e472c14a50972cd97808fda25636c3b`.
It adds guest-byte validation, free/unmap invalidation, and
`VKMT_X64_TIER0=0` for a precise dynamic-code lane. It is not promoted.

### Workstream J4 — x86 memory-model acceptance — complete 2026-07-29

Run the golden i386 provider first. FEX's x86 TSO model remains enabled, but
Darwin must always use software lowering at the final ARM64 emitter. It must
not call `SetHardwareTSOSupport(true)` or otherwise suppress TSO IR based on a
host capability. Vector and REP memcpy/set TSO are intentionally separate
modes; do not globally enable them without a fixture proving the need.

The acceptance suite covers:

1. volatile producer/consumer publication with sequence and payload checks;
2. monitor enter/exit and contended wait/notify;
3. `AtomicInteger` and i386 `AtomicLong` CAS (`cmpxchg8b`);
4. concurrent queue handoff and once-only initialization;
5. aligned and deliberately unaligned scalar loads/stores;
6. REP move/store and the i386 VM's non-temporal `movntq` path;
7. GC write barriers while mutator threads are active.

If the golden provider fails an unaligned TSO access, evaluate the existing
side candidate after making its final lowering match the mandatory invariant:
aligned accesses use `LDAR`/`STLR`; unaligned loads use `LDR` then
`DMB ISHLD`; unaligned stores use `DMB ISH` then `STR`. This avoids runtime
backpatching of Darwin RX pages. Flags must be preserved across the alignment
test. Strict split-lock mode is enabled only for a reproduced cross-boundary
atomic. Vector or memcpy TSO is enabled only for a failing vector/REP ordering
fixture.

Gate: deterministic checksums and sequence counts across repeated high-load
runs with no torn 64-bit atomic, missed publication, deadlock, or exception
loop.

Acceptance evidence is
`docs/validation/windows-java-j4-20260729/RESULTS.md`. Three independent
fresh-prefix repetitions selected the accepted golden provider without
promotion. Each repetition passed a mixed/JIT volatile, monitor, CAS,
queue/once, unaligned, REP, and `movntq` lane plus an interpreted
allocation-driven GC/write-barrier lane. The split is intentional: J5 owns
the separately reproduced interaction between repeated safepoints and
compiled mutators.

### Workstream J5 — safepoint and lifecycle stress — complete 2026-07-29

Combine the JIT and memory-model fixtures with:

1. repeated thread creation/exit;
2. GC safepoints while other threads allocate and execute compiled code;
3. suspend/get-context/set-context/resume through HotSpot's normal machinery;
4. JNI attach/detach and callbacks during GC pressure;
5. repeated VM process startup/shutdown and exact wineserver survival.

This workstream specifically regresses FEX call-return cursor preservation,
internal synchronous-fault reconstruction versus external context transfer,
Wine `NtContinueEx`, PE TLS, APC delivery, and second-thread isolation.

Gate: 100 lifecycle iterations with exact process exit and no retained Java,
Wine, or TLS-server process.

Acceptance evidence is
`docs/validation/windows-java-j5-20260729/RESULTS.md`. One fresh prefix
completed 10 i386 Client-VM launches with 10 lifecycle iterations per launch:
100/100 total. Every iteration ran four compiled/allocation workers through
two full collections, JNI native-thread attach/callback/detach, PE TLS,
compiled null/divide exceptions, APC delivery, and exact worker/JVM exit.
Launch 0 additionally passed a controlled HotSpot
SuspendThread/GetThreadContext/SetThreadContext/ResumeThread roundtrip.

The accepted side provider is
`build/fex-wow64-java-j5-divide/provider/xtajit.dll`, SHA-256
`fe1345724f6a2950541966515f766099b7bce38701c9960d4be513c27ec81073`.
The final targeted `wow64.dll` is SHA-256
`3f252921f12806907c78a4bf07c1aa5a761ba7882d3b72bb876c1dc316f93e7b`.
The provider invalidates only dirty writable-executable HotSpot code-cache
ranges at non-alertable, quiescent wait boundaries; alertable APC waits are
excluded. The complete Workstream 4 i386/WoW64 contract passed afterward,
including context, SEH, APC, second-thread, user-callback, and repeated-thread
gates. No J5 or Workstream 4 prefix/process remains.

### Workstream J6 — unified-prefix and regression promotion — complete 2026-07-29

One fresh prefix must run, sequentially:

1. native ARM64 Oracle JRE server handoff;
2. Windows x86_64 Temurin Server VM;
3. Windows i386 Temurin Client VM through WoW64;
4. the ordinary ARM64/ARM64EC/x86_64/i386 single-prefix gate.

If FEX or Wine changes were needed, also rerun:

- the complete Workstream 4 i386 lifecycle contract;
- i386 VKMT/D3D12/D3D11;
- i386 Gecko/MSHTML;
- OpenGL and SDL multi-architecture gates.

A candidate provider is promoted only after every affected regression passes.
Then update the canonical provider hash, preservation inventory, recovery
snapshot manifest, validation evidence, and `AGENTS.md`.

Acceptance evidence is
`docs/validation/windows-java-j6-20260729/RESULTS.md`. One clean prefix ran
the native Oracle ARM64 Server VM handoff, Windows x86_64 Temurin Server VM,
Windows i386 Temurin Client VM, then ARM64, ARM64EC, x86_64, and i386 Wine
fixtures in that order. Exact shutdown passed with no retained process or
prefix.

The J5 i386 provider was promoted to the canonical source and Wine build
copies at SHA-256
`fe1345724f6a2950541966515f766099b7bce38701c9960d4be513c27ec81073`.
The established x86_64 provider remains canonical at
`7b9f55ceabe971ffa1f514570bb54ed7b5640959e4440e7f8a013e9af13ab7e6`.
J6 proved that build-tree Wine resolves `xtajit64` from its build output
rather than a prefix override. Promoting the experimental J3 x86_64 binary
there exposed a reproducible tier-0 interpreter crash, so it was rejected and
the byte-identical established provider was restored before final acceptance.

After promotion, the complete Workstream 4 WoW64 contract, i386 VKMT
DXGI/D3D12/D3D11, Gecko/MSHTML, OpenGL through GLSL 4.5 Metal readback,
SDL2/SDL3, and the ordinary four-architecture single-prefix gate all passed
without provider override variables. All affected probes re-stage the
selected providers after `wineboot` and delete only their exact disposable
run root.

### Build and cleanup discipline

- Never perform a full Wine rebuild for this work. Rebuild only the owning
  targets, normally `wow64.dll`, `ntdll.dll`/`ntdll.so`, `wineserver`, or the
  FEX `wow64fex` target.
- Every probe root lives under
  `/Volumes/AverySSD/VKMT/build/probe-runs/windows-java.*`.
- Every exit path stops that root's exact `wine/build-ec/server/wineserver`
  with `-k` and `-w`, stops local TLS/child processes, then deletes only that
  exact disposable run root.
- A retained diagnostic root must be removed before the next prefix is
  created.
- Never overwrite or delete the golden Wine tree or providers. Candidate
  staging is explicit and reversible.

## Native ARM64 Wine and D3D12


Related docs: [EMULATION.md](EMULATION.md) (arm64ec/xtajit PE emulation log).

Status: **PASS.** `D3D12CreateDevice(FL_11_0)` returns `S_OK` on native
arm64-apple-darwin Wine 11.12 via vkd3d-proton → VKMT MoltenVK → Metal.
No Rosetta anywhere in the stack.

Probe output (`test/d3d12_probe_nodxgi.exe`, run recipe in `test/run-vkmt-wine.sh`):

```
D3D12CreateDevice(FL_11_0): 0x00000000
max feature level: 0xb000
ResourceBindingTier: 3  TiledResourcesTier: 0  ConservativeRasterizationTier: 0
RaytracingTier: 0  RenderPassesTier: 0
VariableShadingRateTier: 0
PROBE OK
```

### Bugs found and fixed this session

#### 1. New threads started with TEB in x18 (wine, PE-side crash)

`dlls/ntdll/unix/signal_arm64.c::init_syscall_frame` still initialised the
new-thread context with `context.X18 = teb`. With the VKMT pivot, PE keeps
the TEB in x28, so secondary threads (vkd3d worker threads were the first to
hit it) started with a garbage x28 and died in
`RtlInitializeCriticalSection` (`ldr x8, [x28,#0x60]` → wild PEB pointer).
Fixed: set `context.X28 = teb` instead.

#### 2. Stock llvm-mingw CRT clobbers x28 (root cause of the d3d12core crash)

Even with thread init fixed, a vkd3d worker thread crashed with
`x28 = sp+0x1d9` garbage. Disassembly scan showed **477 x28-writing sites in
d3d12core.dll**, all inside static mingw-w64 CRT code
(`__mingw_pformat`, gdtoa, …). The stock toolchain CRT is built for the
standard Windows ABI where x28 is free scratch; every printf-family call
destroyed the TEB register.

Fix: rebuilt mingw-w64-crt (arm64 only) and winpthreads with
`-ffixed-x18 -ffixed-x28` and installed them into the llvm-mingw toolchain
(stock archives backed up under `aarch64-w64-mingw32/lib-backup-stock`).
Script: `scripts/rebuild-mingw-crt.sh`. After relinking, d3d12core.dll has
**zero** x28-writing instructions.

Consequences / rules:

- Any PE binary linked before the CRT fix must be **relinked** (no
  recompile needed — the bad code lives in the static archives).
- `scripts/fix-x18-tls.py` must be re-run on **every freshly linked PE
  binary** (LLVM's Windows TLS lowering still hardcodes `[x18,#0x58]`).
  TODO: wire it into the vkd3d/dxvk meson builds as a post-link step.
- compiler-rt builtins (`libclang_rt.builtins-aarch64.a`) are clean; the
  sanitizer/profile runtimes are not (we don't link them).
- DXVK still needs the same treatment for its C++ runtime (libc++/libc++abi
  from llvm-mingw use x28 as scratch) before its dxgi can load.

#### 3. (Earlier in bring-up, kept in the patch)

- `winevulkan/vulkan_private.h::conversion_context_alloc` returned
  uninitialised memory; MoltenVK walked garbage `pNext` chains. Fixed with
  memset (permanent).
- vkd3d meta compute shaders `cs_emit_nv_memory_decompression_regions{,_workgroups}.comp`
  did `atomicAdd` on a `uvec3` SSBO member → Metal "address of vector
  element" compile error. Replaced with three scalar uints in
  `third_party/vkd3d-proton` (layout-identical).
- Robustness2 requires the VKMT MoltenVK dylib
  (`DYLD_LIBRARY_PATH=third_party/MoltenVK/Package/Release/MoltenVK/dynamic/dylib/macOS`)
  plus `MVK_CONFIG_ADVERTISE_ROBUST_BUFFER_ACCESS_2=1`; homebrew's stock
  MoltenVK reports robustBufferAccess2=0 and vkd3d refuses to init.

### Debug technique that paid off twice

Get the faulting PC from the crash line, the module load base from
`WINEDEBUG=+loaddll`, then:

```
llvm-addr2line -e <dll> -f -C <ImageBase + (faultPC - loadBase)>
```

(vkd3d/wine PE dlls carry DWARF.) For "which register got clobbered"
questions, `WINEDEBUG=+seh` prints the full dispatch context.

### DXVK dxgi (2026-07-25, second pass)

DXVK's dxgi.dll now works for the D3D12 path:

```
CreateDXGIFactory1: 0x00000000
adapter 0: Apple M4 (VID:106b PID:1b000209)
D3D12CreateDevice(FL_11_0): 0x00000000
PROBE OK
```

Required work:

- **libc++/libc++abi/libunwind rebuilt** from llvm-project at the exact
  clang commit (`ca7933e4`) with `-ffixed-x18 -ffixed-x28` and installed
  into the toolchain — the stock ones clobber x28 like the CRT did.
  `scripts/rebuild-mingw-crt.sh cxx` reproduces it. The remaining 2
  "x28 writes" per archive are balanced unwinder context save/restore.
- **DXVK patches** (`patches/dxvk-vkmt-moltenvk.patch`):
  - `geometryShader`, `shaderCullDistance` no longer required (MoltenVK
    lacks both; only two missing required features on Apple M4).
  - `VK_EXT_depth_clip_enable` no longer required. When absent, D3D
    depth-clip semantics are mapped through Metal's clip mode
    (`depthClampEnable = !depthClipEnable`), which is exact for Metal.
  - meson post-link `fix-x18-tls` custom_target (also added to
    vkd3d-proton's meson.build) so freshly linked PE dlls are patched
    automatically on every ninja run.
- Probe exe must be linked against the fixed CRT too (rebuild with
  `-nostartfiles ... -ld3d12 -ldxgi -ldxguid -lole32`).

### Known remaining issues

- First-boot rpcss ordering + a stray `0x7ffe0324` read (intermittent).
- winedbg itself crashes after attaching on aarch64 PE crashes
  ("Internal crash"); use `+seh` register dumps instead.
- DXVK dxgi unusable until libc++/libc++abi are rebuilt with the fixed
  registers (same recipe as the CRT).
- i386/x86_64 guest support via an emulation boundary (GEM/FEX-style) —
  planned, no Rosetta.

### First-boot & debugger hygiene (2026-07-25, third pass)

- **32-bit launches fail cleanly now.** The syswow64 rundll32 that wineboot
  spawns for wine.inf's Wow64Install used to die on `assert(!status)` in
  `build_wow64_parameters` (the sub-2GB wow64 block can't exist on macOS
  arm64). It now logs a clear ERR and exits. This assert was also the
  "winedbg: Internal crash"/hanging seen on crash handling.
- **`0x7ffe0324` stray read:** already fixed by the earlier KUSD relocation;
  kernel32/kernelbase read `0x1:7ffe0000`. Remaining `0x7ffe` hits in the
  tree are AND-masks or the wow64 debug hack at `ntdll/process.c:739`.
- **RpcSs "failed to open" on first boot** is the upstream services race;
  the service registers during boot and starts on demand afterwards
  (verified `sc start rpcss` → RUNNING). Cosmetic.
- **winedbg --auto hang fixed:** the crash dialog (DialogBoxW via winemac)
  blocked forever in unattended sessions. `ShowCrashDialog=0` is now the
  default in new prefixes (wine.inf.in); --auto prints exception, register
  dump, and a symbolized backtrace to stderr and exits. Interactive winedbg
  (bt, info reg) works; `be_arm64_single_step` is still a stub, and
  `info share` on huge DWARF dlls is slow — use `bt`/`info locals` instead.
- **Caveat learned:** `pkill -9 wineserver` loses unflushed registry
  writes; run `wineserver -w` to flush before killing.
