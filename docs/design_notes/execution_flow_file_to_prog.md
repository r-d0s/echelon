# READING THE SOURCE FILE & RUNNING THE PROGRAM - EXECUTION FLOW

---

## STEPS INVOLVED READING THE SOURCE FILE & BEFORE THE MAIN ENTRY LOOP

1) prepare debug settings and input source file

2) `read the source file` (code) and place in `[heap_alloc_file]`

3) `strip out all comments` from the source file (that's anything from a ';' to the newline)

4) calculate the `number of tokens` in the source file, multiply * 8 to hold pointers (qwords) to these tokens

5) `malloc these bytes`, then NULL them out and save in `[argv_ptr]`

6) `split tokens` from the `[heap_alloc_file]` and push each of them into `[argv_ptr]` (e.g [0]"func:", [1]"foo", [2]"100", [3]"int"....)

7) `prepare all stacks` and their `top_of_stack_pointers` in .bss segment. initialise top_of_stack_pointers by pointing
   `below their stack -8 bytes` (meaning their stack is empty).

```
rts <-- [rts_tos]                 ; main stack with all data
dict <-- [dict_tos]               ; stack for storing variables
funcs <-- [funcs_tos]             ; stack for storing function offsets
base_ptr <-- [base_ptr_tos]       ; stack for saving push_bp stack address when using stack-pointers
func_name <-- [func_name_tos]     ; stack for storing the name of the function we're currently in
local_dict <-- [local_dict_tos]   ; stack for handling local scope variables, uses offsets from [dict_tos]
```

8) `create an operator hashset` (used when we scan tokens to identify them as either operands or operators)

9) initialise `token_type jump dispatch array`. to begin with, mark ALL tokens with a value: `0xff00`

10) scan `all tokens`, any operators will have their matching `operator offset replacing 0xff00` in `token_type` array.
    currently operators range from 0x00->0x114.

11) carry out a `one-time cast` on `all ints/floats`. look for operators `'int' and 'float'` then cast the token before
    these operators & replace their `string with their value`.

    e.g: "100\0" --> 0x64

   (yes there's a risk: 100 foo swap int, will of course break this, but it's a risk im prepared to take..)

12) initialise a `curly brace array`. this holds the matching index for any `opening '{'` to its `closing '}'` if there's
    an else statement, that will also be added to this table. no need to scan for '{' and '}' each time we enter an
    if/else/loop block, the offsets are `returned immediately` from a table.

13) run `rdtsc` for random timings

14) initialise `argv` & `argc` params

15) deallocate the operator hashset from step (8)

16) `start the [main loop]` now....

17) when the [main loop] ends, `deallocate & clear up all memory`

---

## STEPS INVOLVED WHEN RUNNING THE PROGRAM CODE

- please note, these diagrams are just an overview, they don't include breaking from an if/loop block and resetting
  the [break_flag].

- the logic for an if/else block has also been removed, as it clutters the diagram.

- the 3 main loops, `main loop`, `call function` and `if/loop` each have their own stack space.
  each time `call function` and `if/loop` are called, we create space for them on the stack-frame.

- the program begins with `main loop` running.

- dummy operators include: `_start:`, `func:`, `break`,	`return`, `}`, `if`, `loop`, `break_cond_if`, `break_if`, & `}else{`.
  we handle these ourselves in the 3 main loops. if they're not handled by us, they call an empty func (it does nothing)
  & program continues processing.


- **r15** --> code array (tokens)
- **r12** --> index of token in code array, currently being processed

---

    [main loop] (until r12 == NULL)
        |
        |`----> [1] operator token: push r12 & r15 & CALL its code (later RESUME at [4])
        |           |
        |           |`----> is operator 'call_func' --> then make a new stack-frame & look at [call function] diagram below..
        |           |
        |            `----> is operator '{' --> then make a new stack-frame & look at [if/loop] diagram below..
        |
        |`----> [2] 'dummy' operator token: ---> only handle 'break', 'break_if' & 'return' --> TERM the [main loop], jmp to [TERM]
        |                                   |
        |                                   `--> other dummy operators are ignored
        |
        |`----> [3] must be an operand: just push it on & cont to next iteration [5]
        |
        |`----> [4] RESUME after CALL ---> [a] ebx is a resume flag: 0 = pop saved registers and continue after the operator
        |                             |
        |                             `--> [b] ebx is a resume flag: 1 = keep current r12/r15 because we just exited a block.
        |
        |`----> [5] next iteration: inc r12 and jmp back to [main loop]
        |
        `----> [TERM] END OF PROGRAM

---

    [call function]
        |
        |`----> [A] prepare local scope var dict stack (which vars are accessible to R/W in this function)
        |
        |`----> [B] save the function name we're currently in & get its token number (set r12) to start processing from.
        |
        |`----> [loop] (if r12 == 'return' or 'break', then jmp to [RETURN] further down..)
        |         |
        |         |`----> [1] operator token: push r12 & r15 & CALL its code (later RESUME at [4])
        |         |           |
        |         |           |`----> is operator 'call_func' --> then make a new stack-frame & look at this [call function] diagram again
        |         |           |
        |         |            `----> is operator '{' --> then make a new stack-frame & look at [if/else/loop] diagram below..
        |         |
        |         |`----> [2] 'dummy' operator token: ---> only handle 'break', 'break_if' & 'return' --> TERM the [main loop] jmp to [RETURN]
        |         |                                   |
        |         |                                   `--> other dummy operators are ignored
        |         |
        |         |`----> [3] must be an operand: just push it on & cont to next iteration [5]
        |         |
        |         |`----> [4] RESUME after CALL ---> [a] ebx is a resume flag: 0 = pop saved registers and continue after the operator
        |         |                             |
        |         |                             `--> [b] ebx is a resume flag: 1 = keep current r12/r15 because we just exited a block.
        |         |
        |         `----> [5] next iteration: inc r12 and jmp back to [loop]
        |
        |
        |`----> [RETURN] deallocate all variables created in this function (using local scope var dict stack)
        |
        |`----> [C] pop local scope var dict stack (these var addresses are out of scope now)
        |
        |`----> [D] pop function name stack, it's not needed anymore, we're leaving this function
        |
        `---->  [E] set ebx resume flag: 0 = pop saved registers and continue after the operator

---

    [if/loop]
        |
        |`----> [A] on the stack save 1) index of '{'
        |                             2) index of '}'
        |                             3) index 'if or loop' operator
        |                             4) TYPE of (if or loop) operator
        |
        |
        |`----> [B] new variables will continue to have scope in this and the calling function
        |
        |`----> [C] set r12 to index +1 after '}' (2)
        |
        |`----> [conditional loop] (until r12 == 'if' or 'loop', then jmp to [TOP OF STACK != NULL] further down..)
        |         |
        |         |`----> [1] operator token: push r12 & r15 & CALL its code (later RESUME at [4])
        |         |           |
        |         |           |`----> is operator 'call_func' --> then make a new stack-frame & look at the [call function] diagram above
        |         |           |
        |         |            `----> is operator '{' --> then make a new stack-frame & look at this [if/loop] diagram again
        |         |
        |         |`----> [2] 'dummy' operator token: ---> only handle 'break', 'break_if' & 'break_cond_if' --> TERM the [conditional loop] jmp to [FINISHED]
        |         |                                   |
        |         |                                   `--> other dummy operators are ignored
        |         |
        |         |`----> [3] must be an operand: just push it on & continue to next iteration [5]
        |         |
        |         |`----> [4] RESUME after CALL ---> [a] ebx is a resume flag: 0 = pop saved registers and continue after the operator
        |         |                             |
        |         |                             `--> [b] ebx is a resume flag: 1 = keep current r12/r15 because we just exited a block.
        |         |
        |         |
        |         `----> [5] next iteration: inc r12 and jmp back to [conditional loop]
        |
        |
        |
        |`----> [TOP OF STACK != NULL] otherwise --> jmp to [FINISHED]
        |         |
        |         |
        |         |`----> [1A] set r12 = token after '{' the start of code block
        |         |
        |       [loop code]  until r12 == '}' token, then check 1) if TYPE = 'if' then jmp to FINISHED (done once, no more..)
        |         |                                             2) if TYPE = 'loop' jmp to [C] above (cont looping while cond is true..)
        |         |
        |         |
        |         |`----> [1B] operator token: push r12 & r15 & CALL its code (later RESUME at [4B])
        |         |           |
        |         |           |`----> is operator 'call_func' --> then make a new stack-frame & look at the [call function] diagram above
        |         |           |
        |         |            `----> is operator '{' --> then make a new stack-frame & look at this [if/loop] diagram again
        |         |
        |         |`----> [2B] 'dummy' operator token: ---> only handle 'break', 'break_if' & 'break_cond_if' --> TERM the [loop code] jmp to [FINISHED]
        |         |                                    |
        |         |                                    `--> other dummy operators are ignored
        |         |
        |         |`----> [3B] must be an operand: just push it on & cont to next iteration [5]
        |         |
        |         |`----> [4B] RESUME after CALL ---> [a] ebx is a resume flag: 0 = pop saved registers and continue after the operator
        |         |                              |
        |         |                              `--> [b] ebx is a resume flag: 1 = keep current r12/r15 because we just exited a block.
        |         |
        |         |
        |         `----> [5B] next iteration: inc r12 and jmp back to [loop code]
        |
        |`----> [FINISHED] set ebx resume flag: 1 = keep current r12/r15 because we just exited a block.

---

