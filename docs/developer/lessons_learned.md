# LESSONS LEARNED

---

### Implementing Regex

I had never worked with regular expressions before and didn't realise how powerful they actually were. adding them to echelon was one of the most frustrating parts of the project. they would work 'randomly', sometimes working perfectly & other times failing for no reason. after much debugging, the fix turned out to be stack alignment issues. by forcing 16 byte alignment (using `and rsp, -16`) before calling `regex` functions, immediately fixed the crashes and made regex reliable.

---

### Cross-Platform Crashes

most of the early development was done on Fedora & CentOS, where everything worked perfectly. but when I started testing on Ubuntu, I came across random crashes in places that had always been stable!

after tracing the crashes back to `libc` calls, I found out that **x86-64 System V ABI** requires the stack to be 16 byte aligned before any function call. on Fedora the stack was often aligned purely by luck (I guess..), but on Ubuntu it wasn't. the fix was a simple macro wrapper used for every `libc` call:

```asm
%macro call_libc 1
    push    rbp
    mov     rbp, rsp
    and     rsp, -16          ; align stack to 16 bytes
    call    %1
    mov     rsp, rbp
    pop     rbp
%endmacro
```

this change completely fixed the cross-platform crashes. this macro is now used for every libc call.

---

### Running Binaries with sys_execve without Deallocations

using this file: 'examples/demos/exec_binary.ech' I realised that memory allocations made before the `sys_execve` call, are automatically deallocated for us!

this script 'exec_binary.ech' allocated memory on the heap and even though I **didn't** deallocate it, Valgrind would report all heap blocks were freed! so I deliberately allocated much more memory, a few thousand bytes and Valgrind would still report 'no leaks' e.g

```
==8664==
==8664== HEAP SUMMARY:
==8664==     in use at exit: 0 bytes in 0 blocks
==8664==   total heap usage: 1 allocs, 1 frees, 1,024 bytes allocated
==8664==
==8664== All heap blocks were freed -- no leaks are possible
==8664==
==8664== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

I discovered that `sys_execve` wipes all our program memory for us, but it should NOT be seen as some sort of garbage collector! if `sys_execve` fails, then you'll be left with all the leaks.

---

### Forgetting to Prepare & Clean-Up the Stack-Frame

when tracking unexpected crashes & seg-faults, the issue was often found in the code. for example, I would have forgotten to prepare the stack-frame:

    push    rbp
    mov     rbp, rsp

and then reading/writing to the stack `[rsp]` would cause problems! or I might have ended a function (with a correctly prepared stack-frame) and then forgotten to do the proper clean-up, leaving a corrupt stack:


    ret     ; missing leave before ret!!

---

### Missing the obvious & forgetting to comment code!

I was testing new operators & started to debug the code to make sure it worked properly. I wrote some test scripts, including these lines:

```
"depth 1 test..." str  def_i
"depth 2 test..." str2 def_i
"depth 3 test..." str3 def_i
```

the interpreter was now crashing and randomly seg-faulting. when I changed test data, or removed parts of the test script (incl these 3 lines), it worked perfectly. I couldn't work out what was happening and thought the interpreter was broken!

after a lot of debugging, I realised the variable name I chose: `str` (something I've done for years) was an operator that takes an int & converts it to a heap allocated string! changing it fixed the issue.

a lack of comments in the code is probably the most painful lesson I've learned. code is easy to follow while it's fresh in your mind, but 18 months later it can become hard-work figuring out why certain decisions were made, especially when some of the logic doesn't seem to make sense.

