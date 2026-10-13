# Architecture Overview

echelon is a stack-based RPN interpreter written in x86-64 assembly

## Data Flow

```
source file --> tokeniser --> token array --> jump-table dispatcher --> (either pushes operand or runs operator code)
```

## Major Sections

1) `tokeniser`: reads .ech source, strips comments, splits into tokens & stores in token array.

2) `init stage`: builds operator hashset, casts numerical values, mark operands & operators in token type
   dispatch table. builds brace-matching table.

3) `runtime stack (rts)`: holds all operands during execution. operators pop from here & results are pushed back here.

4) `dictionary stack (dict)`: holds variables and their values.

5) `function stack (funcs)`: holds function entry points.

6) `dispatcher`: reads token type and either pushes value onto rts, or runs operator code. Uses r15 (token array ptr)
   & r12 (current index).

7) `operator code handler`: 260+ asm functions that manipulate the stacks, call libc, or perform syscalls etc...

```
;-----------------------------------------------------------------------
; echelon basic architecture overview
;
; 3 stages from source file to execution:
;
; stage 1: tokeniser
; ------------------
;
; source file           token code array
; -----------           ----------------
; "10 int 20 int +" --> ["10", "int", "20", "int", "+"]
;
;
; stage 2a: type marking in token_type dispatch array
; ---------------------------------------------------
;
; token array                         token_type array
; -----------                         ----------------
; ["10", "int", "20", "int", "+"] --> [0xff00,  0x0003,  0xff00,  0x0003, 0x0007]
;                                        ^        ^        ^        ^       ^
;                                        |        |        |        |       |
;                                     operand  operator  operand operator operator
;
; values <  0xff00 in token_type are indexes to call the operator's function directly
; values == 0xff00 in token_type are operands to push onto the stack
;
;
; stage 2b: casting numbers in token array
; ----------------------------------------
;
; token array                         token array
; -----------                         -----------
; ["10", "int", "20", "int", "+"] --> [0x0a, "int", 0x14, "int", "+"]
;                                       ^            ^
;                                       |            |
;                                      cast         cast
;
; stage 3: execution loop
; -----------------------
; r15 --> token array base
; r12 --> current token index
;
; dispatcher reads token at r12, either pushes operands onto the rts, or jumps to operator's function
;
; the stacks being used:
;
;   rts        [ operand stack ]  <-- all data lives here during execution
;   dict       [ variables     ]  <-- variables (def_i, def_f, etc)
;   funcs      [ function ptrs ]  <-- entry points for call_func
;   base_ptr   [ saved frames  ]  <-- for stack-pointers (bp_0..bp_7)
;   local_dict [ dict ptrs     ]  <-- handling local scope & global variables
;
; example of execution flow:
;
;   token: 10 int     rts: [ 10 ]
;   token: 20 int     rts: [ 10, 20 ]
;   token: +          rts: [ 30 ]
;
;-----------------------------------------------------------------------
```
