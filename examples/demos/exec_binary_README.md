# EXECUTABLE CONTROL

the script uses the `sys_execve` system call to replace the current running program with a new one. this is how you run other binaries from echelon.

name: **sys_execve** syscall number: **59**

    CPU Registers:
    --------------
    rdi --> path to binary (e.g "/bin/ls")
    rsi --> ptr to argument list (argv)
    rdx --> ptr to environment variables (envp)

---

## ARGUMENT & ENVIRONMENT VARIABLES

when you call sys_execve, the entire echelon proc is replaced by the new binary. before this happens, we build two structs that we pass to the binary.

1) a 40 byte struct on the heap to hold the env vars.

```
offset [0]  : ptr to "echelon_hEAP_aLLOC=1MB"
offset [8]  : ptr to "echelon_sTACK_sPACE=0.25MB"
offset [16] : ptr to "valgrind_errors=..."
offset [24] : ptr to "valgrind_leaks=..."
offset [32] : NULL-term
```
---

2) a 24 byte struct on the heap to hold the arg vars.

```
offset [0]  : ptr to "a sPECiAL mSG fR0M echelon!"
offset [8]  : ptr to "<3 CFC <3"
offset [16] : NULL-term
```

the env list is passed to rdx and the argv list to rsi. by using our own struct blocks, we can **overwrite** the parent shell's default environment for the new proc.

---

## VALGRIND & MEMORY CLEANUP

inside 'call_sys_execve' function, two heap blocks are allocated. there is NO matching pop_free for these blocks in the code & that's perfectly fine!

but.. why is that? because sys_execve REPLACES the entire proc with a new binary, when that happens:

- the kernel destroys ALL memory mappings which belong to the old proc.
- any heap memory allocations by echelon are automatically freed by the OS!
- the new binary starts with a new/clean memory layout.

this means you can safely run external commands without worrying about memory deallocations/leaks. Valgrind will report zero leaks because the allocated memory is freed when the proc is replaced..

