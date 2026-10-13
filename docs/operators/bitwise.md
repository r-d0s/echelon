# BITWISE & LOGICAL OPERATORS

## LOGICAL OPERATORS

---

### &&
`[a, b] -> [1] or [0]`

Logical AND. Returns 1 if both values are non-zero, otherwise 0.

```
1 int 1 int && print_i   ; 1
0 int 1 int && print_i   ; 0
```

---

### ||
`[a, b] -> [1] or [0]`

Logical OR. Returns 1 if either value is non-zero, otherwise 0.

```
0 int 1 int || print_i   ; 1
```

---

### !
`[a] -> [1] or [0]`

Logical NOT. Returns 1 if the value is 0, otherwise 0.

```
1 int ! print_i   ; 0
0 int ! print_i   ; 1
```

---

### xor
`[a, b] -> [1] or [0]`

Logical XOR. Returns 1 if exactly one value is non-zero, otherwise 0.

```
1 int 0 int xor print_i   ; 1
1 int 1 int xor print_i   ; 0
```


## BITWISE OPERATORS

---

### ~
`[value, n] -> [result]`

Bitwise NOT using a bit size 'n'.

```
0 int 8 int ~   ; 255
0 int 16 int ~  ; 65535
0 int 64 int ~  ; -1
```

Important: bit sizes are 8, 16, 32 or 64.

---

### |
`[value1, value2, n] -> [result]`

Bitwise OR using bit size 'n'.

```
523 int 288 int 8 int |   ; 43 (8 bit: 11 | 32 = 43)
523 int 288 int 16 int |  ; 811 (16 bit: 523 | 288 = 811)
```

Important: bit sizes are 8, 16, 32 or 64.

---

### &
`[value1, value2, n] -> [result]`

Bitwise AND using bit size 'n'.

```
19 int 7 int 8 int &   ; 3
```

Important: bit sizes are 8, 16, 32 or 64.

---

### ^
`[value1, value2, n] -> [result]`

Bitwise XOR using bit size 'n'.

```
15 int 21 int 8 int ^   ; 26
```

Important: bit sizes are 8, 16, 32 or 64.


## SHIFT OPERATORS

---

### <<
`[value, n] -> [result]`

Logical shift left by 'n' bits.

```
2 int 1 int <<   ; 4
```

Important: shift range is 1-64.

---

### >>
`[value, n] -> [result]`

Logical shift right by 'n' bits.

```
4 int 1 int >>   ; 2
```

Important: shift range is 1-64.

---

### ->>
`[value, n] -> [result]`

Arithmetic shift right by 'n' bits, preserves sign bit.

```
-16 int 2 int ->>   ; -4
```

Important: shift range is 1-64.
