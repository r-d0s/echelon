# ARITHMETIC OPERATORS (INTEGER)

---

### +
`[a, b] -> [a + b]`

Adds two integers together.

```
10 int 20 int + print_i   ; 30
```

---

### -
`[a, b] -> [a - b]`

Subtracts two integers (second value minus the top value).

```
20 int 10 int - print_i   ; 10
```

Important: Order is important.

---

### *
`[a, b] -> [a * b]`

Multiplies two integers.

```
5 int 6 int * print_i   ; 30
```

---

### /
`[a, b] -> [a / b]`

Divides two integers (second value divided by the top value).

```
15 int 3 int / print_i   ; 5
```

Important: Order is important.

---

### ++
`[x] -> [x + 1]`

Increments an integer by 1.

```
10 int ++ print_i   ; 11
```

---

### --
`[x] -> [x - 1]`

Decrements an integer by 1

```
10 int -- print_i   ; 9
```

---

### %
`[a, b] -> [int]`

Returns the remainder after integer division (second value divided by the top value).

```
30 int 11 int % print_i   ; 8
```

---

### abs
`[int] -> [int]`

Returns the absolute value of an integer. (Negative values become positive).

```
-123 int abs print_i   ; 123
-900 int abs print_i   ; 900
15 int abs print_i     ; 15
```

---

### min
`[a, b] -> [int]`

Returns the smaller of two values.

```
2 int 3 int min print_i   ; 2
22 int 13 int min print_i ; 13
```

---

### max
`[a, b] -> [int]`

Returns the larger of two values.

```
22 int 13 int max print_i   ; 22
2 int 3 int max print_i     ; 3
```

---

### is_even
`[int] -> [1] or [0]`

Checks if integer is even. Returns 1 if true, 0 if false.

```
20 int is_even print_i   ; 1
21 int is_even print_i   ; 0
```

---

### is_odd
`[int] -> [1] or [0]`

Checks if integer is odd. Returns 1 if true, 0 if false.

```
20 int is_odd print_i   ; 0
21 int is_odd print_i   ; 1
```

---

### hcf
`[a, b] -> [int]`

Returns the Highest Common Factor (Greatest Common Divisor) of two integers.

```
12 int 18 int hcf print_i   ; 6
-12 int -18 int hcf print_i ; 6
```

---

### lcm
`[a, b] -> [int]`

Returns the Lowest Common Multiple of two integers

```
12 int 18 int lcm print_i  ; 36
12 int -18 int lcm print_i ; 36
```

---

### is_prime
`[int] -> [1] or [0]`

Checks if integer is prime. Returns 1 if true, 0 if false.

```
2 int is_prime print_i   ; 1
4 int is_prime print_i   ; 0
7 int is_prime print_i   ; 1
9 int is_prime print_i   ; 0
```

---
