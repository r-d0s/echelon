# Planned Improvements To The Code

this project started out as a learning exercise in programming languages. I used the classic "Just get it working!" approach & only thought about improvements after adding more complex features. here are some improvements I've already planned:

---

### Easier Array Accessing

accessing an array index involves the user pushing the pointer on the stack, calculating its offset and then dereferencing it:

    ptr_1 peek                  ; push the ptr onto the stack
    index peek 4 int * +        ; add (index X 4) to the address
    [peek_32]                   ; deref dword


that's 9 tokens in total & I feel that it's too much code to simply do something like this: `*(ptr_1 + 48)`

I want to simplify it. instead of using peek and doing the maths ourselves, I need to change `[peek_8/16/32/64]`. it will look at the top two values on the stack, a pointer & an index and handle the rest automatically.

so this code:

    ptr_1 peek index peek 4 int * + [peek_32]

becomes:

    ptr_1 index [peek_32]       ; [peek_32] is a dword, so it knows to * 4 the 'index'


the operator takes the pointer, adds (index * 4) (dword) & returns the value. three tokens instead of nine --> much easier & cleaner!

the same goes for writes:

    ptr_1 index 5000 int [poke_16]

This writes 5000 as a 16 bit value at ptr_1 + (index * 2). the operator will handle the offset calculation itself.

this change will make the code shorter, easier to read & faster to execute. the offset calcs happen in a single function instead of multiple stack operations (functions).

---

### Limited Function Scope for Variables

when you declare a variable inside a function, its lifetime continues until the end of that function, at which point it is deallocated and removed. this works fine for functions, however, we get problems with **block scope** variable declarations, for example:

```
0 int loop_var def_i
{
    score_1 peek score_2 peek
    + temp_total def_i          ; <-- local variable declared INSIDE block scope!

    temp_total peek print_i pop ; display both scores added
    1 int loop_var +=
} loop_var peek 10 int < loop
```

in the above example, we'd normally expect `temp_total` to be local to the block scope of the loop. however, `temp_total` is saved for each iteration **until the function ends**. on iteration #2, when `loop_var` = 1, the program attempts to create `temp_total` again, then reports a duplicate variable error & halts.

to fix this problem, I'll add block scope variable declarations, allow R/W & deallocate when the block finishes.

---

### Constant Variables

most languages let you create constant values, these are variables that can't be changed after being declared. this is something I want to add too.

the plan is simple, each variable already has a 1 byte 'type' field that stores its type (int, float, string etc...). I can use one of the spare bits in that field to mark a variable as 'constant'. then whenever someone tries to update it with `poke` or `=`, the code checks that one bit (usin bitwise or). if it's set, it raises an error & the update fails, otherwise it goes through.

I'm still deciding on the syntax. there are two options:

    100 int foo const def_i

or

    100 int foo def_i_const

the first one feels more natural & reads like English.. "100 int foo constant define". the second is shorter & keeps everything in one token. either way, once a constant is declared, it can't be changed.

---

### File Descriptor Limitations

echelon allows a single file descriptor to be open at one time. if you close the file descriptor, you can immediately open another, but opening multiple file descriptors simultaneously is not currently possible. a workaround is to use sys-calls & store the file descriptor yourself.

I'll implement a change allowing multiple file descriptors to be open at the same time.

---

### Sending Errors to stderr

currently all errors are displayed using `stdout`. I'll make changes to the code, so that errors are sent to `stderr` instead.

---
