# Performance Optimisation Journey

the first time I ran recursive fibonacci(38), it took **9 minutes** and **34 seconds** to complete. at the time, I wasn't concerned about the slow performance, the fact that it actually completed was a **massive** win for me, especially with over 100+ million function calls being made. once the interpreter became stable, I began looking at optimising the code & changing some of the architecture.

after several changes, the same fibonacci(38) test now finishes in under **6 seconds**.

---

## Planned Optimisations

most of the optimisations are covered in the handwritten design notes (e.g moving from a linear array of operator/operand tokens with strcmp look-ups, to a hashset-based look-up & then to a jmp-table dispatch array). but here are some optimisations planned for the future:

---

### Remove **xor ebx, ebx** from the End of Each Function

currently, each function ends with:

```
xor ebx, ebx
```

this acts as a resume-flag & tells the interpreter which token (operand or operator) to start reading after an operator is called. the problem is that it ties up `rbx` register unnecessarily. I'll find another way to set this flag without wasting `rbx`. by freeing `rbx`, I can use it in other optimisations I have planned (see below).

---

### Storing the Top-of-Stack Pointer to a Register

at the moment, the top of the stack is stored in `[rts_tos]`, a pointer to the 'address' of the top of the stack. every single value we peek, poke or pop involves reading & writing to this address, e.g:

```
mov r8, [rts_tos]   ; point to address
mov r9, [r8]        ; deref to get the value from address
```

I'm planning to keep a preserved register (e.g `rbx`) fixed & pointing directly to the top of the stack. every single stack operation, e.g reads, write, pushes & pops should become faster.

---

### AVX Instructions for Bulk Operations

AVX (Advanced Vector Extensions) can process multiple data elements per instruction (8 ints or 4 floats at a time). This should speed up loops, especially in string ops (e.g `cmp_str`, `starts_with`, `to_upper`), bulk memory fills/copies & sorting/loops. I'll experiment with AVX and then look to add them later.

---

### Shuffling Code Layout for Optimisation

while I was testing, I copied & pasted an existing function & renamed it 'function_ORIG' to test a different implementation. to my surprise...

- collatz (1M) execution time **increased** by about 2 seconds!
- fibonacci (38) execution time **dropped** to almost 4.6 seconds!

after I deleted the dummy 'function_ORIG', both tests returned to their normal times!

this shows that code layout affects performance in 'non-obvious' ways. I then experimented with moving functions around, shuffling them from the top of the source file to the bottom & rearranging them. the results were a little confusing:

- some graph or hashset tests slightly improved
- other tests improved significantly
- some tests would worsen using the same binary

I haven't found a clear pattern yet, but there has to be some logic to it, maybe linked to cache alignment & instruction cache?

---

### rep stosb vs rep stosq.

when filling large allocations (3GB..6GB), I expected `rep stosq` (8 byte writes) to outperform `rep stosb` (1 byte writes) by a significant amount. however, in **every single** test (including many terabytes of writes over nested loops), `rep stosb` consistently beat `rep stosq`! maybe some CPUs are optimising `rep stosb` or maybe I'm not running the right tests for `rep stosq`?

---

### Combining the token_type array with argv_ptr array

I added a jump-table dispatch array to improve performance. it's basically a word array that has register `r12` set to it, to return the token type (operand or operator). currently it's separate from `argv_ptr` array that contains all the (code) tokens values (data). I'll merge this word array with the data array, so that token type look-ups will become faster.

---

## Implemented Optimisations

Here are some of the optimisations implemented already.

---

### Replacing rand/srand with LCG

the standard C library's `rand()` & `srand()` were simple to use, but they added overhead, especially in tight loops. I switched these to a 64 bit `LCG` (Linear Congruential Generator). this change improved performance in benchmarks like hashset insertion & random string generation.

---

### cmovcc & setcc

by updating some of the code to use `cmovcc` & `setcc`, I noticed improvements in performance, especially within hot loops. reducing the number of conditional branches definitely makes the code run quicker. I still have about half the code to review and update/replace with `cmovcc` & `setcc` where necessary.

---

### Replacing the Resume Stack with the program's Stack-Frame.

I had included a `resume` stack that would pop off `r12`/`r15` register values for the program to resume, after calling an operator (function). just before a function would end, these values would be popped off this stack so that the program would flow correctly. before the function started, the `r12`/`r15` values would be pushed on.

I decided to remove this `resume` stack and instead push these values in the `calling function's` actual Stack-Frame. then use `ebx` as a `resume FLAG`, where `0 = pop saved registers` and continue processing using their values. `ebx 1 = keep the current r12/r15 values` because we just exited an `if/loop` block. this change made a significant improvement to performance.
