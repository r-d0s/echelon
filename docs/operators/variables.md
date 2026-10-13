# VARIABLE DECLARATION & UPDATE OPERATORS

## Global and local variable allocation.

---

### def_i
`[value, name] -> []`

Creates an integer variable.

```
200 int max_value def_i     ; max_value stores an integer value 200
```

---

### def_f
`[value, name] -> []`

Creates a float variable.

```
3.142 float pi def_f
```

---

### def_str
`[value, name] -> []`

Creates a string variable.

```
"hello world!" greeting def_str
```

---

### peek
`[name] -> [value]`

Pushes a copy of the variable's value onto the stack.

```
"limit" peek print_i
```

---

### poke / =
`[value, name] -> []`

Updates an existing variable's value.

```
400 int limit poke  ; limit = 400
600 int limit =     ; limit = 600
```

---

### +=
`[amount, name] -> []`

Adds an integer value to an integer variable.

```
15 int foo +=       ; foo += 15
```

---

### -=
`[amount, name] -> []`

Subtracts an integer value from an integer variable.

```
10 int foo -=       ; foo -= 10
```

---

### *=
`[amount, name] -> []`

Multiplies an integer variable by an integer value.

```
3 int foo *=
```

---

### /=
`[amount, name] -> []`

Divides an integer variable by an integer value.

```
4 int foo /=
```

---

### +=f
`[amount, name] -> []`

Adds a float value to a float variable.

```
2.5 float fscore +=f
```

---

### -=f
`[amount, name] -> []`

Subtracts a float value from a float variable.

```
1.5 float fscore -=f
```

---

### *=f
`[amount, name] -> []`

Multiplies a float variable by a float value.

```
2.0 float fscore *=f
```

---

### /=f
`[amount, name] -> []`

Divides a float variable by a float value.

```
2.0 float fscore /=f
```

---

### dump_dict
`[...] -> [...]` (stack unchanged)

Prints all variables currently in the dictionary with their values & types.

```
dump_dict
```

---

### &[var_addr]
`[name] -> [address]`

Pushes the memory address of a variable.

```
500 int foo def_i   ; declare variable
foo &[var_addr]     ; push address of variable onto stack
[peek_64] print_i   ; deref qword [peek_64] prints: 500
```
