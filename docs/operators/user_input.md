# USER INPUT OPERATORS

## Reads user input from stdin.

---

### read_i
`[ ] -> [int]`

Reads an integer.

```
read_i print_i
```

---

### read_f
`[ ] -> [float]`

Reads a float.

```
read_f print_fl
```

---

### read_str
`[ ] -> [str]`

Reads a string.

```
read_str puts pop_free  ; reads user input, displays string & deallocates it.
```

Important: Allocates 256 bytes on the heap, this memory must be deallocated using `pop_free`.
