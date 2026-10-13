# FILE I/O OPERATORS

Important: Only one file descriptor can be opened at a time using these operators. Alternatively you can use sys-calls for opening more than one at a time. Don't forget to close them once you're finished.

The `read_file` operator allocates memory on the heap & this needs to be deallocated using `pop_free`.

---

### open_file
`[filename] -> [fd]`

Opens a file for writing (creates/overwrites). Output file descriptor should be popped or stored.

```
"/tmp/data.txt" open_file fd def_i
```

Important: Close using close_file.

---

### open_file_app
`[filename] -> [fd]`

Opens a file for writing in append mode (creates file if it doesn't exist). Output file descriptor should be popped or stored.

```
"/tmp/data.txt" open_file_app fd def_i
```

Important: Close using close_file.

---

### close_file
`[] -> []`

Closes the currently active open file descriptor.

```
close_file
```

---

### read_file
`[filename] -> [address]`

Reads an entire file into a heap-allocated buffer & automatically adds the null-term.

```
"/tmp/data.txt" read_file data_ptr def_i
```

Important: buffer must be deallocated using `pop_free`.

---

### str_to_file
`[str] -> [bytes_written]`

Writes a string to the active/open file descriptor.

```
"Hello, World!" str_to_file pop
```

---

### bytes_to_file
`[data, count] -> []`

Writes 'count' number of bytes to the file descriptor. Does not halt at null-term.

```
ptr_data peek 10 int bytes_to_file
```

---

### write_bin
`[val1, val2, ..., val_n, count] -> []`

Writes bytes to the active file descriptor. The 'count' param must be a multiple of 8.

```
15 int 31 int 127 int 255 int 32 int write_bin
```

---

### write_bin_ptr
`[data..., offset, count] -> []`

Writes 'count' number of bytes from stack memory to a file, beginning at 'offset' number of bytes from the top of the stack.

```
100 int 200 int 300 int 400 int 500 int 32 int 40 int write_bin_ptr
```

---

### write_nl
`[] -> []`

Writes a newline character to the open file descriptor.

```
write_nl
```

---

### write_64b_num
`[value] -> []`

Writes a 64 bit number value directly from the stack, to the file descriptor.

```
123456789012345 int write_64b_num
```

---

### file_size
`[] -> [size]`

Pushes the byte 'size' of the most recently opened or read file descriptor onto the stack.

```
read_file file_size print_i pop
```


## SOME EXAMPLES

```
; ----- write to file -----
"/tmp/test.txt" open_file pop
"Hello, " str_to_file pop
"World!" str_to_file pop
write_nl
"This is a test." str_to_file pop
write_nl
close_file

; ----- read from file -----
"/tmp/test.txt" read_file ptr def_i
ptr peek puts
ptr peek pop_free

; ----- append to file -----
"/tmp/test.txt" open_file_app pop
"This line is appended!" str_to_file pop
write_nl
close_file

; ----- write bin data -----
"/tmp/binary.dat" open_file pop
15 int 31 int 127 int 255 int 32 int write_bin
close_file

; ----- read bin data -----
"/tmp/binary.dat" read_file data_ptr def_i
data_ptr peek 32 int hex_mem_n
data_ptr peek pop_free

; ----- write raw bytes (bytes_to_file) -----
"we are going to write some bytes" data def_str
"/tmp/raw.dat" open_file pop
data peek 10 int bytes_to_file
close_file

; reading back (use hex_mem_n, not puts, because no null term EOS!)
"/tmp/raw.dat" read_file ptr def_i
ptr peek 10 int hex_mem_n
ptr peek pop_free

; ----- get file size -----
"/tmp/test.txt" read_file ptr def_i
file_size print_i pop
ptr peek pop_free

; ----- read, modify & write.. -----
"/tmp/upper_case_text.dat" open_file pop
"/tmp/test.txt" read_file data_ptr def_i
data_ptr peek to_upper dup
str_to_file pop
close_file
pop_free
data_ptr peek pop_free
```
