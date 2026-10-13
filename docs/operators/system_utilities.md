# SYSTEM OPERATORS

Important:
1) `sys_call` connects directly with the OS kernel. passing incorrect params can result in seg-faults or program crashes.
2) both `rand_str` & `rand_str_batch` generate structures on the heap & must be deallocated using `pop_free`.

---

### sys_call
`[params..., syscall_num, pop_count] -> [result]`

Runs a Linux syscall & pops 'pop_count' values from the stack.

```
39 int 1 int sys_call                 ; getpid (pop 1 values: syscall_num)
0 int 60 int 2 int sys_call           ; exit(0) (pop 2 values: 0, 60)
```

Important: 'pop_count' must equal the total number of args + 1 (that includes the system call number).
      The syscall return value `rax` is automatically pushed onto the stack.

```
some common x86-64 Linux system calls:

       0 = read
       1 = write
       2 = open
       3 = close
      39 = getpid
      60 = exit
      61 = wait4
```

---

### sleep
`[seconds, nano_seconds] -> []`

Suspends execution (sleeping...) for a certain time.

```
2 int 0 int sleep         ; sleep for 2 seconds
0 int 500000000 int sleep ; sleep for 0.5 seconds
```

Important: 'seconds' value must be 0 or higher, 'nano_seconds' value must fall in range 0..999,999,999.

---

### epoch
`[mode] -> [value]`

Returns time measurements from the system clock.

- Mode 0 pushes the Unix epoch value as an integer.
- Mode 1 pushes a pointer to a 16 byte system owned time struct

```
0 int epoch print_i    ; returns epoch seconds
1 int epoch print_ptr  ; returns ptr to 16 byte struct.

                         offsets --> dwords [0] secs
                                            [4] mins
                                            [8] hours
```

Important: The 16 byte memory struct is owned by the system environment. Do **not** attempt to free this address using `pop_free`!

---

### exit
`[code] -> []`

Ends the program immediately & returns the status code to the OS.

```
0 int exit   ; exit with code 0 (success)
1 int exit   ; exit with code 1 (error)
```

Important: check return value in the shell terminal using `echo $?`.

---

### rand
`[range] -> [random]`

Generates a random integer value between 0 and 'range'-1.

```
100 int rand print_i pop   ; returns 0-99
5 int rand print_i pop     ; returns 0-4
-99 int rand print_i pop   ; 'range' <2 defaults to 2 & returns 0-1
```

Important: uses LCG, if the 'range' param <= 1, it defaults to a range of 2 (returning 0/1).

---

### rand_str
`[length] -> [str]`

Generates a random, lowercase alpha string with 'length' chars. Automatically adds extra byte for null-term '\0'.

```
10 int rand_str print_str pop_free   ; shows 10 random chars
-5 int rand_str print_str pop_free   ; defaults to 8 chars
```

Important: Passing a length value <= 0 causes the generator to default 'length' to 8 chars.

---

### rand_str_batch
`[length, count] -> [block_ptr]`

Generates an entire batch of random strings inside a single heap memory block. Useful when testing large volumes of data.

```
8 int 50000 int rand_str_batch block def_i      ; 50000 * 8 chars (+'\0') in a single heap allocation.
```

Important: Each string entry inside the block allocation is null-terminated. To index the block array, calc the pointer address offset using:

- base_address + (index * (length + 1))

---

### create_struct
`[val1, val2, ..., val_n, count] -> [count, address]`

Pops 'count' values from the stack & packs them into an 8 byte aligned, heap-allocated struct.

```
Playstation 200 int -123 int Hello! 4 int create_struct
```

Important: the result of `create_struct` is used by `def_struct` to create the structure.

---

### def_struct
`[address, count, "name"] -> []`

Links a variable 'name' to an allocated memory struct.

```
Playstation 200 int -123 int Hello! 4 int create_struct
my_info def_struct          ; use create_struct first to make the struct then call def_struct
```

---

### struct_size
`["struct_name"] -> [size]`

Returns the size of 8 byte (64 bit) field elements within the 'struct_name' structure variable.

```
"my_info" struct_size print_i   ; shows 4
```


## SOME EXAMPLES

```
; ----- sys_call: getpid -----
39 int 1 int sys_call
"PID: %d\n" printf pop

; ----- sys_call: exit -----
;4 int 60 int 2 int sys_call     ; echo $? -> 4

; ----- sys_call: write to stdout -----
"Hello from syscall!\n" msg def_str
msg peek len_str   ; count
msg peek           ; buf
1 int              ; fd = stdout
1 int              ; syscall_num = write
4 int sys_call     ; pop 4 values

; ----- sleep -----
2 int 0 int sleep          ; sleep 2 secs
0 int 500000000 int sleep  ; sleep 0.5 secs

; ----- epoch -----
1 int epoch
dup [peek_32]                 ; read SS
swap dup 4 int + [peek_32]    ; read MM
swap 8 int + [peek_32]        ; read HH
"\nCurrent time: [%02d:%02d:%02d]\n" 3 int printf_p

0 int epoch print_i pop       ; epoch seconds

; ----- rand -----
10 int rand print_i pop   ; 0-9
100 int rand print_i pop  ; 0-99

; ----- rand_str -----
10 int rand_str print_str pop_free

; ----- rand_str_batch -----
8 int 5000 int rand_str_batch block def_i   ; 5000 * 8 char strings.
block peek puts                     ; first string
block peek 4 int 9 int * + puts     ; 5th string
block peek pop_free                 ; free all

; ----- create_struct & def_struct -----
"Playstation" 200 int -123 int "Hello!" 4 int create_struct
my_struct def_struct

my_struct peek [peek_64] print_str          ; "Hello!"
my_struct peek 8 int + [peek_64] print_i    ; 200
my_struct peek 16 int + [peek_64] print_i   ; -123
my_struct peek 24 int + [peek_64] print_str ; "Playstation"

; ----- struct_size -----
my_struct struct_size print_i pop   ; 4
```
