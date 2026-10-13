# STRING OPERATORS

Important: Many string operators create heap-allocated strings. All allocations **must** be deallocated using `pop_free`.

---

### len_str
`[str] -> [length]`

Returns the length of the string, excluding the null-term '\0'.

```
"hello" len_str print_i   ; 5
```

---

### add_str
`[str1, str2] -> [new_str]`

Concatenates two strings into a heap-allocated string.

```
"World-" "Cup!" add_str print_str pop_free   ; "World-Cup!"
```

Important: Deallocate using `pop_free`.

---

### cpy_str
`[str] -> [copy]`

Creates a heap-allocated copy of the string.

```
apple cpy_str print_str pop_free   ; apple
```

Important: Deallocate using `pop_free`.

---

### upd_str
`[str, replacement, indx] -> [new_str]`

Replaces chars starting from the index 'indx'. Returns a heap-allocated string.

```
abcdefg "123" 2 int upd_str print_str pop_free   ; ab123fg
```

Important: Do not overwrite or remove the null-term '\0'.

---

### sub_str
`[str, start, length] -> [substring]`

Gets substring starting at 'start' index for 'length' chars. Returns a heap-allocated string.

```
"the cat chased the dog!" 4 int 10 int sub_str   ; "cat chased"
abcdefghi 1 int 4 int sub_str   ; bcde
```

---

### cmp_str
`[str1, str2] -> [result]`

Compares two strings based on ASCII order. Returns -1, 0, or 1.

```
"aab" "aaa" cmp_str print_i   ; 1
"aaa" "aaa" cmp_str print_i   ; 0
"aaa" "aab" cmp_str print_i   ; -1
```

---

### cmp_str_u
`[str1, str2] -> [result]`

Compares two strings using UNSIGNED bytes (0-255). Returns -1, 0, or 1.

```
"aab" "aaa" cmp_str_u print_i   ; 1
"aaa" "aaa" cmp_str_u print_i   ; 0
"aaa" "aab" cmp_str_u print_i   ; -1
```

---

### cmp_str_i
`[str1, str2] -> [result]`

Case insensitive string comparison. Returns -1, 0, or 1.

```
HELLO hello cmp_str_i    ; 0
abc DEF cmp_str_i        ; -1
```

---

### index_str
`[str, substr] -> [index] or [-1]`

Returns index of the first occurrence of substr, or -1 if not found.

```
abcdef cd index_str print_i   ; 2
abcdef xyz index_str print_i  ; -1
```

---

### starts_with
`[str, prefix] -> [1] or [0]`

Returns 1 if the string starts with 'prefix', otherwise 0.

```
foobar foo starts_with   ; 1
foobar baz starts_with   ; 0
```

---

### ends_with
`[str, suffix] -> [1] or [0]`

Returns 1 if the string ends with 'suffix', otherwise 0.

```
foobar bar ends_with   ; 1
foobar foo ends_with   ; 0
```

---

### to_upper
`[str] -> [new_str]`

Converts lowercase chars (a-z) to uppercase. Returns a heap-allocated string.

```
HeLlO_123! to_upper   ; HELLO_123!
```

---

### to_lower
`[str] -> [new_str]`

Converts uppercase chars (A-Z) to lowercase. Returns a heap-allocated string.

```
HeLlO_123! to_lower   ; hello_123!
```

---

### trim_str
`[str] -> [new_str] or [0]`

Trims leading and trailing whitespaces. Returns a heap-allocated string, or NULL if the string contained only whitespace.

```
"  hello  " trim_str   ; "hello"
```

---

### replace_str
`[str, old, new] -> [new_str]`

Replaces all occurrences of the old substring with new substring. Returns a heap-allocated string.

```
"banana" "a" "i" replace_str   ; binini
"cat" "a" "ome" replace_str    ; comet
```

---

### join_str
`[str1, str2, ..., str_n, delim, count] -> [new_str]`

Joins 'count' strings together using 'delim' string. Returns a heap-allocated string.

```
"aaa" "bbb" "ccc" ":" 3 int join_str   ; "aaa:bbb:ccc"
"A" "A" "A" "A" "#" 4 int join_str     ; "A#A#A#A"
```

---

### split_str
`[str] -> [word1, word2, ...]`

Splits a string into words using spaces, tabs and newlines. Every word is heap-allocated.

```
"The dog chased the cat!" split_str
; Result: "The" "dog" "chased" "the" "cat!"
```

---

### split_str_delim
`[str, delims] -> [block_address]`

Splits a string using a set of 'delims' chars.

Returns a 16 byte data block struct :

```
[0] char** (array of pointers)
[8] count.
```

```
",,%,,hello,%%,how,%%,,are:,%%%%,,you?!?,::"
",:%" split_str_delim
```

Important: Use `del_str_set` to deallocate the entire block struct. The **array last entry is NULL, this helps during iterations.

---

### get_lines
`[str] -> [block_address]`

Splits a string by newline chars (\n). Returns a 16 byte block struct using the same layout as `split_str_delim`

```
"First Line\nSecond Line\nThird Line\nFourth Line" get_lines
```

Important: Use `del_str_set` to deallocate the entire block struct.

---

### smash_str
`[str] -> [char1, char2, ..., char_n]`

Splits a string into null-term single-char strings on the stack. Each char (string) is heap-allocated.

```
clear "hello" smash_str   ; "h" "e" "l" "l" "o"
```

---

### smash_str_ascii
`[str] -> [ascii1, ascii2, ..., ascii_n]`

Splits a string into ASCII integer values pushed onto the stack.

```
"ABC def" smash_str_ascii   ; 65 66 67 32 100 101 102
```

---

### sprintf
`[params..., format_string, dest] -> []`

Writes a formatted string into a dest buffer. Params are left on the stack.

```
100 int mem_alloc out_ptr def_i
12 int "The total is %d\n" out_ptr peek sprintf
```

Important: The dest buffer must be allocated before using sprintf. Use sprintf_p to automatically pop args.

---

### sprintf_p
`[params..., format_string, dest, count] -> []`

Identical to sprintf, but pops the format string and 'count' args from the stack.

```
100 int mem_alloc out_ptr def_i
22 int "The total is %d\n" out_ptr peek 2 int sprintf_p ; pops format string and 2 params
```


## SOME EXAMPLES

```
; ----- length -----
"hello" len_str print_i pop   ; 5

; ----- concat -----
"Hello" " World" add_str puts pop_free   ; Hello World

; ----- substr -----
"abcdefghi" 1 int 4 int sub_str puts pop_free   ; bcde

; ----- UPPER/lower -----
"Hello World!" to_upper puts pop_free   ; HELLO WORLD!
"Hello World!" to_lower puts pop_free   ; hello world!

; ----- compare -----
"hello" "world" cmp_str print_i pop   ; -1
"hello" "hello" cmp_str print_i pop   ; 0

; ----- find -----
"hello world" "world" index_str print_i pop   ; 6

; ----- trim -----
"  hello  " trim_str puts pop_free   ; hello

; ----- split -----
"The dog chased the cat!" split_str
dump_str   ; "The" "dog" "chased" "the" "cat!"
5 int pop_free_n

; ----- smash -----
"hello" smash_str
dump_str   ; "h" "e" "l" "l" "o"
5 int pop_free_n

; ----- sprintf -----
100 int mem_alloc out_ptr def_i
21 int "The value is %d\n" out_ptr peek sprintf
out_ptr peek puts pop_free
```
