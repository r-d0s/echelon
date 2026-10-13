# Adding a New Operator to echelon

Adding a new operator is quite simple, just follow these steps:

---

## Step 1: Add Operator Name

decide on your new operator name and add it to the .rodata segment **before** the dummy operators (`_start:`, `func:`, `break`, etc.)

example: adding a new operator called `rd0s`:

BEFORE WE ADD THE NEW OPERATOR:

```nasm
operator_264:	db "pop_bp_clear", 0x00
operator_265:   db "rand_str_batch", 0x00
operator_266:   db "func_name", 0x00
;----------------------------------			; IGNORE THESE DUMMY OPERATORS FROM HERE
operator_267:	db "_start:", 0x00
operator_268:	db "func:", 0x00
operator_269:	db "break", 0x00
operator_270:	db "return", 0x00
operator_271:	db "}", 0x00
operator_272:	db "if", 0x00
operator_273:	db "loop", 0x00
operator_274:	db "break_cond_if", 0x00
operator_275:	db "break_if", 0x00
operator_276:	db "}else{", 0x00
```

AFTER WE'VE ADDED THE NEW OPERATOR:

the new operator (rd0s) should be placed as shown below:

```nasm
operator_264:	db "pop_bp_clear", 0x00
operator_265:   db "rand_str_batch", 0x00
operator_266:   db "func_name", 0x00
operator_267:   db "rd0s", 0x00				; <----- INSERT YOUR NEW OPERATOR HERE (BEFORE THE DUMMY ONES!)
;----------------------------------			; IGNORE THESE DUMMY OPERATORS FROM HERE
operator_268:	db "_start:", 0x00
operator_269:	db "func:", 0x00
operator_270:	db "break", 0x00
operator_271:	db "return", 0x00
operator_272:	db "}", 0x00
operator_273:	db "if", 0x00
operator_274:	db "loop", 0x00
operator_275:	db "break_cond_if", 0x00
operator_276:	db "break_if", 0x00
operator_277:	db "}else{", 0x00
```

notice how all the operator values below the new operator are incremented AFTER we insert it. each operator is unique.

- _start: went from operator_267 --> operator_268
- func:   went from operator_268 --> operator_269 etc..

---

## Step 2: Update all_ops array

now insert a new entry to the `all_ops` array (**operator_277**):

```
BEFORE: ..., operator_273, operator_274, operator_275, operator_276, NULL

AFTER:  ..., operator_273, operator_274, operator_275, operator_276, operator_277, NULL
```

---

## Step 3: Update map_funcs array

in the `map_funcs` array, add the new function name (e.g `rd0s_demo_func`) for this new operator, JUST BEFORE the FIRST dummy_func

    BEFORE: ..., rand_string_batch, ret_func_name, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, NULL

    AFTER:  ..., rand_string_batch, ret_func_name, rd0s_demo_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, NULL

---

## Step 4: Increment Constants

add **1** to each of these constants, they're all grouped together.

BEFORE:

```nasm
OP_SIZE:                equ 0x115   ; total # of operators inc dummy ones
operator_KEYWORD:       equ 0x10b   ; all operators are < this number

start_KEYWORD:          equ 0x10b   ; "_start:",0x00
func_KEYWORD:           equ 0x10c   ; "func:",0x00
break_KEYWORD:          equ 0x10d   ; "break",0x00
return_KEYWORD:         equ 0x10e   ; "return",0x00
close_brace_KEYWORD:    equ 0x10f   ; "}",0x00
if_KEYWORD:             equ 0x110   ; "if",0x00
loop_KEYWORD:           equ 0x111   ; "loop",0x00
break_cond_if_KEYWORD:  equ 0x112   ; "break_cond",0x00
break_if_KEYWORD:       equ 0x113   ; "break_if",0x00
if_else_brace_KEYWORD:  equ 0x114   ; "}else{",0x00
```

AFTER (adding 1 to these constants):

```nasm
OP_SIZE:                equ 0x116   ; total # of operators inc dummy ones
operator_KEYWORD:       equ 0x10c   ; all operators are < this number

start_KEYWORD:          equ 0x10c   ; "_start:",0x00
func_KEYWORD:           equ 0x10d   ; "func:",0x00
break_KEYWORD:          equ 0x10e   ; "break",0x00
return_KEYWORD:         equ 0x10f   ; "return",0x00
close_brace_KEYWORD:    equ 0x110   ; "}",0x00
if_KEYWORD:             equ 0x111   ; "if",0x00
loop_KEYWORD:           equ 0x112   ; "loop",0x00
break_cond_if_KEYWORD:  equ 0x113   ; "break_cond",0x00
break_if_KEYWORD:       equ 0x114   ; "break_if",0x00
if_else_brace_KEYWORD:  equ 0x115   ; "}else{",0x00
```

Please remember: OP_SIZE must always be one more than the highest operator index.

---

## Step 5: Write Function Code.

Write your operator function in the .text segment (near the bottom of the file is fine).

example: `rd0s` operator takes two integers, adds them & doubles the result. I've not added any error checks for this example.

e.g stack: `[ 7, 5 ] --> [ 12 ] --> [ 24 ]`

```nasm
rd0s_demo_func:
	mov     r12, [rts_tos]          ; <-- [rts_tos] always points to the top of the stack's **ADDRESS**
	mov     rdi, [r12]              ; deref the top value
	mov     rax, [r12 - 0x08]       ; deref the value below
	;-----------------------
	add     rax, rdi                ; add both operands
	imul    rax, 0x02               ; double result
	;-----------------------
	sub     r12, 0x08               ; pop off the top of the stack
	mov     [r12], rax              ; push on the result
	mov     [rts_tos], r12          ; update top of stack pointer
	;-----------------------
	xor     ebx, ebx                ; xor to resume from correct point after this function ends
	ret
```

---

## Step 6: Build Interpreter

	make

---

## Step 7: Test New Operator

Create a test file, e.g **new_func_test.ech** :

```
_start:

    3 int  5 int rd0s      ; expected 2 * (3 + 5)   =  16
    9 int 11 int rd0s      ; expected 2 * (9 + 11)  =  40
  -10 int  4 int rd0s      ; expected 2 * (-10 + 4) = -12

    dump_i
```

---

## Step 8: Run Valgrind

	ubuntu_adm@EliteDesk[~/final_tests/new_operator]
	Thu Aug 13 [19:50:19]$ valgrind -s --track-origins=yes --leak-check=full ./echelon -f new_func_test.ech
	==6712== Memcheck, a memory error detector
	==6712== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
	==6712== Using Valgrind-3.18.1 and LibVEX; rerun with -h for copyright info
	==6712== Command: ./echelon -f new_func_test.ech
	==6712==

	-------- [START] of run_time_stack dump ------v
	rts index [00] ---> [-12]
	rts index [01] ---> [40]
	rts index [02] ---> [16]
	^------- [END] of run_time_stack dump -------

	==6712==
	==6712== HEAP SUMMARY:
	==6712==     in use at exit: 0 bytes in 0 blocks
	==6712==   total heap usage: 309 allocs, 309 frees, 10,846 bytes allocated
	==6712==
	==6712== All heap blocks were freed -- no leaks are possible
	==6712==
	==6712== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)

---

## Step 9: Debugging

if you find errors or leaks, have a go fixing them. here are some common problems:

- stack underflow (not enough operands?)
- type mismatches (using wrong operand types? e.g '100' and '100 int' are totally different!)
- memory leaks (forgetting to free heap allocations?)

remember to use `dump_rts` or `dump_ptr` to inspect the stack at any point during testing/execution.

---
