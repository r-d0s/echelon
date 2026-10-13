# REGULAR EXPRESSION OPERATORS

By default echelon allocates a fixed amount of memory for storing regex matches:

- default allocation: 256 KB
- override using `-b` cmd-line args: `-b <bytes>`

eg: `./echelon -f script.ech -b 650000`

Use this option when you are matching large files or expect **larger** result sets from regex matches.

Please note:

1) `regex` & `regex_sub` both return heap-allocated strings. these **must** be deallocated with `pop_free`
2) `regex_multi` returns a heap-allocated 16 byte block. this **must** be deallocated properly.
3) errors return (`-1`), regex engine compilation error, (`-2`) out of memory error.

---

### **regex**
`[str, regex] -> [result] or [0] or [-1]`

A single regex match & returns the matched substring, `0` if no match, or `-1` on errors.

```
"apple banana cherry date figs guava" "(c)(\w+)" regex   ; "cherry"
"hello world" "xyz" regex   ; 0
"aaaabaaa" "[z-a]" regex    ; -1 (regex error)
```

Important: error handling explained later.

---

### **regex_sub**
`[str, search, replace] -> [new_str] or [-1]`

Replaces all instances of 'search' with 'replace'. returns new string or `-1` on errors.

```
"options oliver opinions oil orange oscar" "o" "0" regex_sub
; "0pti0ns 0liver 0pini0ns 0il 0range 0scar"

"options oliver opinions oil orange oscar" "[z-a]" "0" regex_sub
; -1 (regex error)
```

Important: error handling explained later.

---

### **regex_multi**
`[str, regex] -> [block_ptr] or [0] or [-1]`

A multi-line regex match & returns a 16 byte block struct with all matches & capture groups/data.

```
"apple cherry date figs" "(a)(\w+)" regex_multi
```

Important: returns `0` if no results, `-1` on errors. remember to free the **entire block**.

Here's the layout of the 16 byte Result Block Struct, although it's far easier to understand if you look at the end of this document.

**Result Block Struct (16 bytes):**
- bytes [0-7]: pointer to String Array (char** & last entry is NULL)
- bytes [8-15]: pointer to Stats Block & Pair Offsets.

Stats Block:
- bytes [0-7]:  dword, dword `[match_count, total_matches]` (where rc = number of match iterations)
- bytes [8-15]: dword, dword `[capture_groups, total_string_matches]`

Pair offsets:
- each pair is 8 bytes: `[start_offset, end_offset]`
- total pairs = total_matches

Important: Pair Offsets is part of the Stats Block, it begins form offset[16]. see Regex Multi Struct Diagram below

String Array:
- each entry is 8 bytes: pointer to a string
- last entry is NULL (0x00)

---

### del_regex
`[block_ptr] -> []`

Deallocates the 16 byte result block struct & all its matched strings returned from `regex_multi`.

---

### Tokeniser Bypass Method (For Special Characters)

Problem: operator symbols written within quotes e.g `"+"`, `"*"` are **still** interpreted by the tokeniser as instructions.

Solution: push a safe string e.g (`"X"`), then use `[poke_8]` to overwrite byte 0 with the ASCII symbol.

```
; replace all vowels with '+'
"Assembly Language Engine"        ; target string
"[aeiouAEIOU]"                    ; regex pattern
"X" dup                           ; dup 'X', as [poke_8] consumes a cpy
43 int [poke_8]                   ; overwrite 'X' with '+' (ASCII 43)
regex_sub                         ; run regex
print_str pop_free                ; "+ss+mbly L+ngu+g+ +ng+n+"
```

this is a temporary workaround until I get the tokeniser fixed.

---

## Error Handling

If regex compilation fails, it pushes:

1) `-1` (error indicator)
2) PCRE2 error msg (string)
3) failed regex pattern (string)

Do **not** free the error message or regex pattern, they're not heap-allocated. Just pop them when you're finished.

See the examples below.

---

## SOME EXAMPLES

```
; ----- regex: a single match -----
{
    "Matched: %s\n" printf pop_free
}else{
    "No match found" puts_p
} "apple banana cherry date figs guava" "(c)(\w+)" regex dup if

; ----- regex_sub: substitution -----
{
    "Result: %s\n" printf pop_free
}else{
    "Regex error: -1" puts_p
} "options oliver opinions oil orange oscar" "o" "0" regex_sub dup -1 int != if

; ----- regex_multi: multi-line match -----
"apple banana cherry date figs guava"
"(a)(\w+)"
"regex -> [%s]\nstring -> [%s]\n" printf

regex_multi print_ptr result_ptr def_i
{
    dup [peek_64] string_ptr def_i
    8 int + [peek_64] stats_ptr def_i

    stats_ptr peek 12 int + [peek_32] limit def_i
    0 int index def_i
    {
        string_ptr peek [peek_64] puts_p
        8 int string_ptr +=
        1 int index +=
    } index peek limit peek < loop

    result_ptr peek del_regex
}else{
    "no results found" swap "error in regex" swap
    0 int == true_false puts_p
} result_ptr peek dup 0 int > if

; ----- regex_multi: iterating through -----
"apple banana cherry date figs guava"
"(a)(\w+)"
"regex -> [%s]\nstring -> [%s]\n" printf

regex_multi result_ptr def_i
{
    dup 8 int + [peek_64] stats_ptr def_i
    stats_ptr peek 12 int + [peek_32] limit def_i

    0 int index def_i
    16 int stats_ptr +=
    {
        stats_ptr peek dup 4 int + [peek_32] swap [peek_32]
        "%d <- start/end -> %d\n" printf pop pop
        8 int stats_ptr +=
        1 int index +=
    } index peek limit peek < loop

    result_ptr peek del_regex
}else{
    "no results found" swap "error in regex" swap
    0 int == true_false puts_p
} result_ptr peek dup 0 int > if
```

---

## Regex Multi Struct Diagram

```
----- regex_multi: result block struct diagram -----
"apple cherry date figs" "(a)(\w+)" regex_multi

  index:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17
  *char:  a  p  p  l  e     c  h  e  r  r  y     d  a  t  e

0x2000  [3, 2]          ; rc = 3 matches, matches = 2
0x2008  [2, 6]          ; groups = 2, total_matches = 6
0x2010  [0, 5]          ; pair 0: whole match "apple"
0x2018  [0, 1]          ; pair 1: group 1 "a"
0x2020  [1, 5]          ; pair 2: group 2 "pple"
0x2028  [14, 17]        ; pair 3: whole match "ate"
0x2030  [14, 15]        ; pair 4: group 1 "a"
0x2038  [15, 17]        ; pair 5: group 2 "te"

0x5000  [0xa1000] --> "apple"
0x5008  [0xa1020] --> "a"
0x5010  [0xa1040] --> "pple"
0x5018  [0xa1060] --> "ate"
0x5020  [0xa1080] --> "a"
0x5028  [0xa10a0] --> "te"
0x5030  [NULL]              ; <-- END of results marker


result block struct
    [0x6000]
      |
      |--> [0x6000] --> char** [0x5000]
      |                   |
      |                   |--> [0x5000] --> "apple"
      |                   |--> [0x5008] --> "a"
      |                   |--> [0x5010] --> "pple"
      |                   |--> [0x5018] --> "ate"
      |                   |--> [0x5020] --> "a"
      |                   |--> [0x5028] --> "te"
      |                   `--> [0x5030] --> NULL (end of results marker)
      |
      `--> [0x6008] --> stats block [0x2000]
                         |
                         |--> [0x2000]   rc = 3, matches = 2
                         |--> [0x2008]   groups = 2, total_matches = 6
                         |
                         |--> pair 0: [0x2010] 00, [0x2014] 05  --> "apple"
                         |--> pair 1: [0x2018] 00, [0x201c] 01  --> "a"
                         |--> pair 2: [0x2020] 01, [0x2024] 05  --> "pple"
                         |--> pair 3: [0x2028] 14, [0x202c] 17  --> "ate"
                         |--> pair 4: [0x2030] 14, [0x2034] 15  --> "a"
                         `--> pair 5: [0x2038] 15, [0x203c] 17  --> "te"
```

---

## Error Handling Example

this regex substitution failed because the search pattern `[a-g` is missing a closing `]`

```
"hello world"        ; original string
"[a-g"               ; invalid regex pattern, missing ']' !!
"X"                  ; replacement string
regex_sub

dump_ptr             ; view the whole stack: -1, error msg, regex pattern
pop                  ; pop -1 (error indicator)
puts_p               ; print error message & pop it
puts_p               ; print failed regex pattern & pop it
```

---

the error message and regex pattern are not heap-allocated, do **not** free them.

Output:

```
-------- [START] of run_time_stack dump ------v
rts index [00] ---> [0xffffffffffffffff]        <-- error code
rts index [01] ---> [0x41a498]                  <-- error message
rts index [02] ---> [0x4c19d80]                 <-- regex pattern
^------- [END] of run_time_stack dump -------

missing terminating ] for character class
[a-g
```
