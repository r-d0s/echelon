# TRIGONOMETRY & ADVANCED MATH

## Uses radians for angles.

---

### sin
`[float] -> [float]`

Sine of a float value.

```
0.0 float sin print_fl        ; 0.000000
1.570796 float sin print_fl   ; 1.000000
```

---

### cos
`[float] -> [float]`

Cosine of a float value.

```
0.0 float cos print_fl        ; 1.000000
3.14159 float cos print_fl    ; -1.000000
```

---

### tan
`[float] -> [float]`

Tangent of a float value.

```
0.0 float tan print_fl        ; 0.000000
```

Important: undefined for pi/2 + n*pi.

---

### acos
`[float] -> [float]`

Inverse cosine.

```
1.0 float acos print_fl       ; 0.000000
0.0 float acos print_fl       ; 1.570796
```

Important: Input must be between -1 and 1.

---

### asin
`[float] -> [float]`

Inverse sine.

```
1.0 float asin print_fl       ; 1.570796
0.0 float asin print_fl       ; 0.000000
```

---

### atan
`[float] -> [float]`

Inverse tangent.

```
1.0 float atan print_fl       ; 0.785398
```

Important: Result is in range [-pi/2, pi/2]

---

### atan2
`[y, x] -> [float]`

Inverse tangent of y/x.

```
1.0 float 1.0 float atan2 print_fl   ; 0.785398
```

---

### expm1
`[x] -> [float]`

Calculates e^x - 1.

```
0.0 float expm1 print_fl      ; 0.000000
1.0 float expm1 print_fl      ; 1.718282
```

---

### log
`[x] -> [float]`

Natural log (ln).

```
1.0 float log print_fl        ; 0.000000
2.718282 float log print_fl   ; 1.000000
```

Important: input must be > 0.

---

### log2
`[x] -> [float]`

Base-2 logarithm.

```
8.0 float log2 print_fl       ; 3.000000
2.0 float log2 print_fl       ; 1.000000
```

---

### log10
`[x] -> [float]`

Base-10 logarithm.

```
100.0 float log10 print_fl    ; 2.000000
10.0 float log10 print_fl     ; 1.000000
```

---

### log1p
`[x] -> [float]`

Natural logarithm of (1 + x).

```
0.0 float log1p print_fl      ; 0.000000
1.0 float log1p print_fl      ; 0.693147
```

---

### sinh
`[x] -> [float]`

Hyperbolic sine.

```
0.0 float sinh print_fl       ; 0.000000
1.0 float sinh print_fl       ; 1.175201
```

---

### cosh
`[x] -> [float]`

Hyperbolic cosine.

```
0.0 float cosh print_fl       ; 1.000000
1.0 float cosh print_fl       ; 1.543081
```

---

### tanh
`[x] -> [float]`

Hyperbolic tangent.

```
0.0 float tanh print_fl       ; 0.000000
1.0 float tanh print_fl       ; 0.761594
```

---

### hypot
`[x, y] -> [float]`

Hypotenuse calc: sqrt(x^2 + y^2)

```
3.0 float 4.0 float hypot print_fl   ; 5.000000
5.0 float 12.0 float hypot print_fl  ; 13.000000
```

---

### fma
`[a, b, c] -> [float]`

Fused multiply-add logic calc: (a * b) + c.

```
2.0 float 3.0 float 4.0 float fma print_fl   ; 10.000000
2.5 float 4.0 float 3.5 float fma print_fl   ; 13.500000
```

---

### pow
`[base, exp] -> [float]`

Raises base to the power of exponent.

```
2.0 float 3.0 float pow print_fl     ; 8.000000
4.0 float 0.5 float pow print_fl     ; 2.000000
```

---

### exp
`[x] -> [float]`

Calculates e^x.

```
1.0 float exp print_fl        ; 2.718282
0.0 float exp print_fl        ; 1.000000
```

---

### exp2
`[x] -> [float]`

Calculates 2^x.

```
3.0 float exp2 print_fl       ; 8.000000
0.0 float exp2 print_fl       ; 1.000000
```

---

### sqrt
`[x] -> [float]`

Square root.

```
16.0 float sqrt print_fl      ; 4.000000
```

Important: silent -nan error for negative numbers

---
