# UPDATES TO THE HANDWRITTEN NOTES

these handwritten notes are old documents. I would usually begin writing them as soon as I finished certain sections of the project. many operators were added after these documents were written & the interpreter has changed quite a lot since then. here are some of the changes made:

---

### Updating Heap Memory

- reading from memory changed to `[peek_n]` where 'n' is bits: 8, 8s, 16, 16s, 32, 32s, 64. (signed/un-signed)
- writing to memory changed to   `[poke_n]` where 'n' is bits: 8, 16, 32, 64.

- I no longer use create_struct or def_struct and might remove these operators in the future. the easiest and most simple way to work with structs is:

```    
200 int mem_alloc ptr def_i
```
 now you have 200 bytes on the heap, you're able to R/W anything from/to there. any size of 8, 16, 32 or 64 bytes & any type signed/un-signed. free it when you're done

---

### GCC Libraries Used

- these have increased because we needed to add maths & PCRE2 regex libraries.

---

### Printing Output

- eventually `puts` and `printf` were used, so any mention of e.g `print_str_nnl` (print string no-newline) can be ignored. to begin with I would have to use an operator for every single variable & string to print them on the same line! printf's frmt string solved this problem.

---

### Marking the Dispatch Array

- to begin with, the operand value was set to 0xc8 (200) in the dispatch table. this changed after the number of operators increased. now the size of the operand/operator value in the dispatch array has increased to 16 bits. the default operand value is now 0xff00, any value below this is the operator's function offset.
  
---

### Replacing the Resume-Stack

- this was removed & the Stack-Frame from the calling function was used instead to store values. register ebx became a resume-flag at the end of each function.

---

### Operator/Operand Mix-Up

- when I started writing this document, I started using operand and operators in the OPPOSITE/WRONG way, I only noticed after the first few chapters!

---

### Parsing input File (mistake)

- at the time I thought parsing was tokenising! so this chapter is all about building the tokens we save/use as program code. no parsing was carried out.

---

### Stack-Pointers

- at the end of the Optimisation document, I mentioned base_ptr & base_ptr_tos. it wasn't long after I was experimenting with this, that I added Stack-Pointers [bp_0..bp_7] to the interpreter.

---

### ASM Code Errors

- these notes do have some asm code errors, but they were mainly used to fix bugs and find solutions. looking at the diagrams was very useful & saved me a lot of time.

---

### My Recommendations....

- if you're able to read my handwriting (apologies, it was a while back!!) & you're interested in this kind of work, then I'd suggest you take a look at these 3 docs:

    - [if/loops](06_iterations_conditional_checks.pdf)
    - [function calls](05_function_calls.pdf)
    - [variable scoping](07_scoping.pdf)

  I'm confident that anyone looking at these docs will be able to understand how I implemented them. 

---
