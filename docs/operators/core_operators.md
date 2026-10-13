# STACK MANIPULATION OPERATORS

Important: Calling `pop` on an empty stack will cause an error & terminate the program!

---

### pop
`[10, 20, 30] -> [10, 20]`

Removes the top value from the stack.

```
10 int 20 int 30 int pop pop
```

---

### clear
`[1, 2, 3, 4, 5] -> []`

Removes ALL values from the stack (empties it).

```
1 int 2 int 3 int 4 int 5 int clear
```

---

### swap
`[a, b] -> [b, a]`

Swaps the top two values.

```
10 int 20 int swap
```

---

### dup
`[a] -> [a, a]`

Duplicates the top value.

```
5 int dup * print_i   ; 25 (square)
```

---

### dup_n
`[a, n] -> [a, a, a, ...]`

Creates 'n' duplicates of the top value ('n'+1 copies total).

```
cherries 3 int dup_n   ; stack: cherries x 4
```

---

### rev
`[1, 2, 3, 4, 5] -> [5, 4, 3, 2, 1]`

Reverses the whole stack.

```
1 int 2 int 3 int rev dump_i   ; 3 2 1
```

---

### clear_above
`[1, 2, 3, 4, 5, n] -> [1, 2, 3, 4]` (if n=1)

Removes everything above and including index 'n' from the top. Index 0 is the top-most value.

```
apple banana cherries dates figs 1 int clear_above
```

---

### clear_below
`[1, 2, 3, 4, 5, n] -> [3, 4, 5]` (if n=2)

Removes everything below index 'n' from the bottom. Index 0 is the bottom-most value.

```
apple banana cherries dates figs 2 int clear_below
```

---

### shift_up
`[1, 2, 3, 4, 5] -> [5, 1, 2, 3, 4]`

Shifts all values up by 1 position. The top value drops to the bottom.

```
apple banana cherries dates figs shift_up
```

---

### shift_down
`[1, 2, 3, 4, 5] -> [2, 3, 4, 5, 1]`

Shifts all values down by 1 position. The bottom value jumps to the top.

```
apple banana cherries dates figs shift_down
```

---

### shift_up_n
`[..., n] -> [...]`

Shifts values up by 'n' positions (the top 'n' items drop to the bottom).

```
apple banana cherries dates figs grapes 2 int shift_up_n
; Result: apple banana cherries grapes dates figs
```

---

### shift_down_n
`[..., n] -> [...]`

Shifts values down by 'n' positions (the bottom 'n' item jumps to the top).

```
apple banana cherries dates figs grapes 2 int shift_down_n
; Result: apple banana cherries figs grapes dates
```

---

### stack_size
`[...] -> [..., count]`

Pushes the total number of values currently on the stack.

```
100 int 200 int 300 int 400 int stack_size print_i   ; 4
; Result: 100, 200, 300, 400, 4
```

---

### swap_top_n
`[a, b, c, d, e, n] -> [...]`

Swaps values at positions 'n' and 'n'+1 from the top. When n=0, this swaps the top two items.

```
10 int 20 int 30 int 40 int 50 int 60 int 2 int swap_top_n
; Result: 10 20 40 30 50 60
```

---

### swap_bottom_n
`[a, b, c, d, e, n] -> [...]`

Swaps values at positions 'n' and 'n'+1 from the bottom. When n=0, this swaps the bottom two items.

```
10 int 20 int 30 int 40 int 50 int 60 int 1 int swap_bottom_n
; Result: 10 30 20 40 50 60
```

---

### swap_pos
`[..., idx1, idx2] -> [...]`

Swaps values at the given indexes (0 is the top value).

```
"aaa" "bbb" "ccc" "ddd" 1 int 2 int swap_pos
; Result: "aaa" "ccc" "bbb" "ddd"
```

---

### value_at
`[..., indx] -> [..., copy]`

Copies the value at index 'indx' to the top of the stack.

```
aaa bbb ccc 1 int value_at
; Result: aaa bbb ccc bbb
```

---

### [value_at]
`[value, indx, ...] -> [...]`

Updates/overwrites the value at the index 'indx' (0 is the top value).

```
5 int 10 int 15 int 20 int 25 int 30 int -700 int 3 int [value_at]
; Result: 5, 10, -700, 20, 25, 30
```

---

### dup_args
`[val1, val2, ..., val_n, count] -> [val1, ..., val_n, copies...]`

Duplicates the top 'count' number of args.

```
10 int 20 int 30 int 40 int 50 int 2 int dup_args
; Result: 10, 20, 30, 40, 50, 40, 50
```

---

### pop_n
`[val1, val2, ..., val_n, count] -> [...]`

Removes the top 'count' number of values from the stack.

```
10 int 20 int 30 int 2 int pop_n   ; stack: [10]
```

---
