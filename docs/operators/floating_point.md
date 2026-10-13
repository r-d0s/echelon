# FLOAT OPERATORS

## These operators use xmm registers for fast math.

---

### +f
`[a, b] -> [a + b]`

Adds two floats together.

```
3.5 float 2.5 float +f print_fl   ; 6.000000
```

---

### -f
`[a, b] -> [a - b]`

Subtracts two floats (second value minus the top value).

```
5.5 float 2.0 float -f print_fl   ; 3.500000
```

Important: Order is important.

---

### *f
`[a, b] -> [a * b]`

Multiplies two floats.

```
3.0 float 4.0 float *f print_fl   ; 12.000000
```

---

### /f
`[a, b] -> [a / b]`

Divides two floats (second value divided by the top value).

```
15.0 float 3.0 float /f print_fl   ; 5.000000
```

Important: Order is important. division by zero results in silent 'inf' error.

---

### ==f
`[a, b] -> [1] or [0]`

Checks if a == b. Returns 1 if true, 0 if false.

```
3.5 float 3.5 float ==f print_i   ; 1
```

---

### !=f
`[a, b] -> [1] or [0]`

Checks if a != b. Returns 1 if true, 0 if false.

```
3.5 float 4.2 float !=f print_i   ; 1
```

---

### <f
`[a, b] -> [1] or [0]`

Checks if a < b. Returns 1 if true, 0 if false.

```
3.5 float 4.2 float <f print_i   ; 1
```

---

### >f
`[a, b] -> [1] or [0]`

Checks if a > b. Returns 1 if true, 0 if false.

```
5.5 float 4.2 float >f print_i   ; 1
```

---

### <=f
`[a, b] -> [1] or [0]`

Checks if a <= b. Returns 1 if true, 0 if false.

```
3.5 float 3.5 float <=f print_i   ; 1
```

---

### >=f
`[a, b] -> [1] or [0]`

Checks if a >= b. Returns 1 if true, 0 if false.

```
5.5 float 5.5 float >=f print_i   ; 1
```

---

### <f>
`[a, b] -> [result]`

Compares two floats. Returns -1 if a < b, 0 if a == b, or 1 if a > b.

```
3.5 float 4.2 float <f> print_i   ; -1
4.2 float 3.5 float <f> print_i   ; 1
3.5 float 3.5 float <f> print_i   ; 0
```

---

### ++f
`[x] -> [x + 1.0]`

Increments a float by 1.0.

```
3.5 float ++f print_fl   ; 4.500000
```

---

### --f
`[x] -> [x - 1.0]`

Decrements a float by 1.0.

```
3.5 float --f print_fl   ; 2.500000
```

---

### fabs
`[x] -> [float]`

Absolute value of a float. (Negative values become positive).

```
-3.14 float fabs print_fl     ; 3.140000
3.14 float fabs print_fl      ; 3.140000
```

Important: Use `abs` for integers.

---

### fmin
`[a, b] -> [float]`

Returns the smaller of two values.

```
3.5 float 4.2 float fmin print_fl    ; 3.500000
-5.5 float 2.0 float fmin print_fl   ; -5.500000
```

---

### fmax
`[a, b] -> [float]`

Returns the larger of two values.

```
3.5 float 4.2 float fmax print_fl    ; 4.200000
-5.5 float 2.0 float fmax print_fl   ; 2.000000
```

---

### floor
`[x] -> [float]`

Round down to the nearest whole number.

```
3.9 float floor print_fl      ; 3.000000
-3.1 float floor print_fl     ; -4.000000
```

---

### ceil
`[x] -> [float]`

Round up to the nearest whole number.

```
3.1 float ceil print_fl       ; 4.000000
-3.9 float ceil print_fl      ; -3.000000
```

---

### round
`[x] -> [float]`

Rounds to the nearest whole number (1/2 up).

```
3.5 float round print_fl      ; 4.000000
3.4 float round print_fl      ; 3.000000
-3.5 float round print_fl     ; -4.000000
```

---

### trunc
`[x] -> [float]`

Removes decimal part.

```
3.9 float trunc print_fl      ; 3.000000
-3.9 float trunc print_fl     ; -3.000000
```

---


### sqrt
`[float] -> [float]`

Returns the square root of a float.

```
136 float sqrt print_fl   ; 11.661904
```

Important: negative numbers will cause a silent -nan error.
