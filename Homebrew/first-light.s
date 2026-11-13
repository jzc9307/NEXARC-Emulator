// This is Switch guest code, not a Mac executable.
// We use direct system calls, so no Nintendo SDK, keys, or firmware is needed.
// The builder puts these instructions after the NRO header.
.text
.global _first_light
_first_light:
    mov x9, #21
    add x9, x9, x9
    cmp x9, #42
    b.ne Lfailure

    // Test a conditional branch and a small counting loop.
    mov x10, #0
    mov x11, #10
Lcount:
    add x10, x10, #1
    subs x11, x11, #1
    b.ne Lcount
    cmp x10, #10
    b.ne Lfailure

    // The stack belongs to guest virtual memory. Store a value, then read it.
    sub sp, sp, #16
    str x9, [sp]
    ldr x12, [sp]
    add sp, sp, #16
    cmp x12, #42
    b.ne Lfailure

    adr x0, Lsuccess
    mov x1, #(LLsuccess_end-Lsuccess)
    svc #0x27                  // OutputDebugString(pointer, length)
    svc #0x07                  // ExitProcess()
Lfailure:
    adr x0, Lfailed
    mov x1, #(LLfailed_end-Lfailed)
    svc #0x27
    svc #0x07
Lsuccess:
    .ascii "HELIO_DIAGNOSTIC_PASS | arithmetic=42 loop=10 memory=42 svc=ok\n"
LLsuccess_end:
Lfailed:
    .ascii "HELIO_DIAGNOSTIC_FAIL\n"
LLfailed_end:
