# CONTROL FLOW OPERATORS

echelon has a simple rule for conditional checks:

**TRUE**: Any non-zero value

**FALSE**: A zero value

Examples:

    0 int       ; FALSE
    0 float     ; FALSE

    0           ; TRUE (pointer to string "0\0")
    -1 int      ; TRUE (not zero)
    -1 float    ; TRUE (not zero)
    NULL        ; TRUE (pointer to string "NULL\0")
    3.142 float ; TRUE (not zero)
    250 int     ; TRUE (not zero)

---

### {
`[...] -> [...]`

Opens an `if` or `loop` block. Must be closed with `}`.

```
{ code } condition if/loop
```

---

### }
`[...] -> [...]`

Closes an `if` or `loop` block. Must have a matching `{`.

```
{ code } condition if/loop
```

---

### _start:
`[] -> []`

The entry point of the program. Code execution starts from this point

```
_start:
```

Important: All functions must be declared BEFORE _start:.

---

### if
`[block, condition] -> []`

Executes the code block if the condition is true (non-zero).

```
{ "True! 10 is < 20" print_str } 10 int 20 int < if
```

Important: Skips the block if the condition is 0 (false).

---

### else
`[block1, block2, condition] -> []`

Executes block #1 if condition is true.

Executes block #2 if condition is false.

```
{
    "True statement!" puts_p    ; block #1
}else{                          ; no spaces between '}else{'
    "False statement!" puts_p   ; block #2
} 10 int 20 int < if            ; if(10 < 20){ ... }else{ ... }
```

---

### loop
`[block, condition] -> []`

Repeatedly executes code block as long as the condition is true (non-zero).

```
1 int val def_i
{
    1 int val +=            ; val++
} val peek 10 int < loop    ; while(val < 10)...
```

---

### true_false
`[true_value, false_value, condition] -> [selected_value]`

Ternary operator. Keeps the true_value if the condition is true, otherwise keeps the false_value.

```
"a < b" "a >= b" 9 int 10 int < true_false print_str   ; displays: "a < b"
```

Important: similar to C's ternary (condition ? true_value : false_value).

---

### break
`[] -> []`

Exits the current function immediately.

```
{ count peek 10 int == break } loop
```

Important: Using this inside _start: will end the program immediately.

---

### break_if
`[condition] -> []`

Exits the current function immediately if the condition is true (non-zero).

```
count peek 10 int == break_if
```

---

### break_cond_if
`[condition] -> []`

Exits the current block immediately if the condition is true (non-zero).

```
{ count peek 5 int == break_cond_if } 1 int loop
```

Important: Only works inside an active block (like a `loop` or `if` statement) & is ignored anywhere else.
