# MEMORY OPERATORS

Important: These operators allow low-level access to memory. Make sure all memory addresses being read from/written to, have been allocated correctly. Out of bounds array or pointer arithmetic will cause seg-faults or unexpected results.

---

### mem_alloc
`[size] -> [address]`

Allocates 'size' number of bytes on the heap & returns the address pointer (similar to C's `malloc`).

```
100 int mem_alloc ptr def_i   ; allocates 100 bytes, stores pointer in ptr
```

---

### pop_free
`[address] -> []`

Pops the top-most pointer address & deallocates its heap memory (similar to C's `free`).

```
500 int mem_alloc print_ptr pop_free   ; shows allocated 500 bytes memory address then frees it
```

Important: only use on heap-allocated memory, using this on **program code** or **non-heap** allocated memory will crash the system or double-free!

---

### pop_free_n
`[address_n, ..., address1, n] -> []`

Frees 'count' number of heap-allocated addresses popped from the stack.

```
100 int mem_alloc 200 int mem_alloc
dump_ptr
2 int pop_free_n               ; frees both (100 byte & 200 byte) heap memory
```

---

### fill_mem
`[dest, byte, count] -> []`

Fills a 'dest' memory block with 'count' number of single-byte 'byte' values.

```
ptr peek 65 int 100 int fill_mem   ; fill 100 bytes with 'A'
```

Important: 'dest' address, 'byte' value (0-255) & 'count' are all popped from stack.

---

### del_str_set
`[block_address] -> []`

Deallocates a string set (struct) created by `split_str_delim` or `get_lines`.

```
my_ptr peek del_str_set
```

Important: Frees all strings (char **) & the whole block struct.

---

### copy_bytes
`[src, dest, count] -> []`

Copies 'count' number of bytes directly from 'src' memory address to 'dest' memory address.

```
user_details peek my_data peek 11 int copy_bytes    ; copy 11 bytes from user_details --> my_data
```

---

### stack_to_mem
`[dest, count, offset] -> []`

Copies 'count' bytes directly from stack into heap 'dest' memory, starting at a specific byte 'offset' from the top of stack.

```
a_ptr peek 24 int 32 int stack_to_mem
```

---

### get_stack_addr
`[...] -> [..., address]`

Pushes the current top-of-stack pointer address onto the stack.

```
get_stack_addr   ; returns address at top of stack
```

---

### [peek_8]
`[address] -> [byte]`

Reads 1 byte (8 bits) from the memory 'address' and pushes it onto the stack as unsigned integer value (0-255).

```
ptr peek 16 int + [peek_8]   ; reads byte at offset [16]
```

---

### [peek_16]
`[address] -> [word]`

Reads 2 bytes (16 bit) from the memory 'address' and pushes it onto the stack as unsigned integer value (0-65535).

```
ptr peek 16 int + [peek_16]  ; reads word at offset [16]
```

---

### [peek_32]
`[address] -> [dword]`

Reads 4 bytes (32 bit) from the memory 'address' and pushes it onto the stack as unsigned integer value (0-4294967295).

```
ptr peek 16 int + [peek_32]  ; reads dword at offset [16]
```

---

### [peek_64]
`[address] -> [qword]`

Reads 8 bytes (64 bit) from the memory 'address' and pushes the value onto the stack.

```
ptr peek 16 int + [peek_64]  ; reads qword at offset [16]
```

---

### [peek_8s]
`[address] -> [byte]`

Reads 1 byte from memory 'address', sign-extends it, then pushes it onto the stack (-128 to 127).

```
ptr peek 37 int + [peek_8s]  ; reads signed byte at offset [37]
```

Important: uses movsx operator, as do [peek_16s] & [peek_32s].

---

### [peek_16s]
`[address] -> [word]`

Reads 2 bytes from memory 'address', sign-extends it, then pushes it onto the stack (-32,768 to 32,767).

```
ptr peek 37 int + [peek_16s] ; reads signed word at offset [37]
```

---

### [peek_32s]
`[address] -> [dword]`

Reads 4 bytes from memory 'address', sign-extends it, then pushes it onto the stack (-2,147,483,648 to 2,147,483,647).

```
ptr peek 37 int + [peek_32s] ; reads signed dword at offset [37]
```

---

### [poke_8]
`[address, value] -> []`

Writes 1 byte 'value' directly to the dest memory 'address'.

```
ptr peek 16 int + 65 int [poke_8]   ; writes 'A' at offset [16]
```

---

### [poke_16]
`[address, value] -> []`

Writes 2 byte word 'value' directly to the dest memory 'address'.

```
ptr peek 16 int + 0x4243 hex_int [poke_16]   ; writes "BC" at offset [16]
```

---

### [poke_32]
`[address, value] -> []`

Writes 4 byte dword 'value' directly to the dest memory 'address'.

```
ptr peek 16 int + 0x44454647 hex_int [poke_32]   ; writes "DEFG" at offset [16]
```

---

### [poke_64]
`[address, value] -> []`

Writes 8 byte qword 'value' directly to the dest memory 'address'.

```
ptr peek 16 int + 0x48494A4B4C4D4E4F hex_int [poke_64]   ; writes "HIJKLMNO"
```


## EXAMPLES

```
;--- allocate 100 bytes ---
100 int mem_alloc ptr def_i

;--- write dword data at offset +16 ---
ptr peek 16 int + 0x44454647 hex_int [poke_32]   ; writes "DEFG"

;--- read it back (dword) ---
ptr peek 16 int + [peek_32] print_ptr            ; shows 0x44454647

;--- write byte data at offset +37 ---
ptr peek 37 int + -99 int [poke_8]               ; write 1 byte -99

;--- move ptr +37 bytes & read signed byte ---
ptr peek 37 int + [peek_8s] print_i              ; read 1 byte signed -99

; --- move ptr +37 bytes & read unsigned byte ---
ptr peek 37 int + [peek_8] print_i               ; read same 1 byte unsigned 157

; --- clean up/deallocate ---
ptr peek pop_free
```
