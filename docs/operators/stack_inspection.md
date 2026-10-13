# STACK DISPLAY & OUTPUT OPERATORS

Important: String operators: `dump_str`, `print_str`, `hex_str`, `puts` & `puts_p` all require NULL-terminated strings.

Any strings (without the NULL-term '\0') will cause a seg-fault!

---

### dump_i
`[...] -> [...]` (read-only)

Displays the entire stack as signed integers.

```
1 int 2 int 3 int 4 int 5 int dump_i
```

---

### dump_str
`[...] -> [...]` (read-only)

Displays the entire stack as strings. Requires **every** stack elements to be NULL-terminated strings.

```
hello world dump_str
```

---

### dump_rts
`[...] -> [...]` (read-only)

Displays the entire stack with runtime type IDs. Non-variable values default to 'int'.

```
10 int hello 3.14 float dump_rts
```

---

### dump_ptr
`[...] -> [...]` (read-only)

Displays the entire stack as hex pointers using `%p` format. Safe for mixed-type stacks & great for debugging.

```
10 int hello 3.14 float dump_ptr
```

---

### print_i
`[int] -> [int]` (read-only)

Displays the top-most stack element as signed integer.

```
73 int print_i
```

---

### print_fl
`[float] -> [float]` (read-only)

Displays the top-most stack element as a float.

```
3.14 float print_fl
```

---

### print_str
`[str] -> [str]` (read-only)

Displays the top-most stack element as a NULL-terminated string.

```
"Hello, echelon!" print_str
```

---

### print_ptr
`[ptr] -> [ptr]` (read-only)

Displays the top-most stack element as a hex pointer using `%p` format.

```
"test string" print_ptr
```

---

### nl
`[...] -> [...]` (read-only)

Outputs a newline character.

```
"Line 1" print_str nl "Line 2" print_str nl
```

---

### hex_str
`[str] -> [str]` (read-only)

Displays a NULL-terminated string as a hexadecimal memory dump.

```
"hello, how are you?" hex_str
```

---

### hex_mem_n
`[address, count] -> [address, count]` (read-only)

Displays 'count' bytes from a memory address as hex.

```
hello 5 int hex_mem_n
```

Important: There are no safety checks, so make sure you can read into the 'count' byte offset.

---

### puts
`[str] -> [str]` (read-only)

Prints a string (with an added newline). String is left on the stack.

```
"here's a small string.." puts
```

---

### puts_p
`[str] -> [ ]`

Prints a string (with an added newline) & pops it from the stack.

```
"this string will be popped off!" puts_p
```

---

### printf
`[params..., format_string] -> [params...]`

Formatted text output. The format string is popped, but args are left on the stack.

```
20 int 30 int 40 int "var_a: %d, var_b: %d, var_c: %d\n" printf
```

---

### printf_p
`[params..., format_string, count] -> [ ]`

Formatted text output. Pops the format string and 'count' arg params from the stack.

```
20 int 30 int 40 int "var_a: %d, var_b: %d, var_c: %d\n" 3 int printf_p
```

---

### printf_f
`[float_params..., format_string] -> [float_params...]`

Prints floating-point args using `%f` format. The format string is popped, but float args remain.

```
1.1 float 2.2 float 3.3 float "floats: %f %f %f\n" printf_f
```

---

### printf_fp
`[float6, ..., float1, format_string, count] -> [ ]`

Prints floating-point args. Pops the format string and 'count' float params (maximum 6 floats).

```
1.1 float 2.2 float 3.3 float 4.4 float 5.5 float 6.6 float "Floats: %f %f %f %f %f %f\n" 6 int printf_fp
```

---

### fflush
`[ ] -> [ ]`

Flushes stdout stream buffer.

```
fflush
```
