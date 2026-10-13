# COMPARISON OPERATORS

## Used for conditional and comparison checks.

---

### <
`[a, b] -> [1] or [0]`

Checks if a < b. Returns 1 if true, 0 if false.

```
10 int 12 int < print_i   ; 1
```

---

### >
`[a, b] -> [1] or [0]`

Checks if a > b. Returns 1 if true, 0 if false.

```
15 int 13 int > print_i   ; 1
```

---

### ==
`[a, b] -> [1] or [0]`

Checks if a == b. Returns 1 if true, 0 if false.

```
19 int 19 int == print_i   ; 1
```

---

### !=
`[a, b] -> [1] or [0]`

Checks if a != b. Returns 1 if true, 0 if false.

```
11 int 12 int != print_i   ; 1
```

---

### <=
`[a, b] -> [1] or [0]`

Checks if a <= b. Returns 1 if true, 0 if false.


```
11 int 12 int <= print_i   ; 1
```

---

### >=
`[a, b] -> [1] or [0]`

Checks if a >= b. Returns 1 if true, 0 if false.

```
19 int 19 int >= print_i   ; 1
```

---

### \<i\>
`[a, b] -> [result]`

Compares two integers. Returns -1 if a < b, 0 if a == b, or 1 if a > b.

```
19 int 23 int <i> print_i   ; -1
19 int 13 int <i> print_i   ; 1
19 int 19 int <i> print_i   ; 0
```

---

### <f
`[a, b] -> [1] or [0]`

Checks if a < b (for floats). Returns 1 if true, 0 if false.

```
3.5 float 4.2 float <f print_i   ; 1
```

---

### >f
`[a, b] -> [1] or [0]`

Checks if a > b (for floats). Returns 1 if true, 0 if false.

```
5.5 float 4.2 float >f print_i   ; 1
```

---

### ==f
`[a, b] -> [1] or [0]`

Checks if a == b (for floats). Returns 1 if true, 0 if false.

```
3.5 float 3.5 float ==f print_i   ; 1
```

---

### !=f
`[a, b] -> [1] or [0]`

Checks if a != b (for floats). Returns 1 if true, 0 if false.

```
3.5 float 4.2 float !=f print_i   ; 1
```

---

### <=f
`[a, b] -> [1] or [0]`

Checks if a <= b (for floats). Returns 1 if true, 0 if false.

```
3.5 float 3.5 float <=f print_i   ; 1
```

---

### >=f
`[a, b] -> [1] or [0]`

Checks if a >= b (for floats). Returns 1 if true, 0 if false.

```
5.5 float 5.5 float >=f print_i   ; 1
```

---

### \<f\>
`[a, b] -> [result]`

Compares two floats. Returns -1 if a < b, 0 if a == b, or 1 if a > b.

```
3.5 float 4.2 float <f> print_i   ; -1
4.2 float 3.5 float <f> print_i   ; 1
3.5 float 3.5 float <f> print_i   ; 0
```
