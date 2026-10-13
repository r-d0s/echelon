# QSORT OPERATOR

Important: The `qsort` operator directly modifies the source array.

---

### qsort
`[element_size, count, base_ptr, order, sort_type, inner_bytes] -> []`

Sorts an array struct using libc qsort_r algorithm.

```
4 int 50 int ptr_1 peek 1 int 2 int 0 int qsort
```

Params:
```
- element_size: 1, 2, 4 or 8 (byte, word, dword or qword)
- count: total number of array elements
- base_ptr: source address ptr to array
- order: sorting order(0 = ascending, 1 = descending)
- sort_type: comparison data type:
        0 = Signed 8 bit byte
        1 = Signed 16 bit word
        2 = Signed 32 bit dword
        3 = Signed 64 bit qword
        4 = String NULL-term (char *)
        5 = Unsigned 8 bit byte
        6 = Unsigned 16 bit word
        7 = Unsigned 32 bit dword
        8 = Unsigned 64 bit qword
        9 = Float 64 bit qword
- inner_bytes: number of bytes to skip inside structs before we compare (0 = immediate comparison)
```

## EXAMPLES

```
    ; ----- sort ints (asc) -----
    200 int mem_alloc arr def_i     ; 200 bytes = 50 dwords

    0 int i def_i                   ; counter = 0
    {
        arr peek i peek 4 int * +   ; get *ptr to correct index using 'i'
        4000000000 int rand         ; gen rand(4bn) value
        [poke_32]                   ; write dword rand num into *ptr
        1 int i +=                  ; inc counter++
    } i peek 50 int < loop          ; (while counter < 50)...


    4 int       ; element_size = 4 dword
    50 int      ; count = 50
    arr peek    ; base_ptr
    0 int       ; order = ascending
    2 int       ; sort_type = signed dword
    0 int       ; inner_bytes = 0
    qsort       ; run qsort operator

                                        ; now display output
    0 int i =                           ; reset counter, don't re-declare it
    {
        arr peek i peek 4 int * +       ; get *ptr to correct index using 'i'
        [peek_32s] "%d, " printf pop    ; read signed dword, print & pop
        1 int i +=                      ; inc counter++
    } i peek 50 int < loop              ; (while counter < 50)...
    nl

    arr peek pop_free                   ; deallocate 200 bytes

    ; ----- sort strings (desc) -----
    clear

    64 int mem_alloc string_arr def_i   ; 8 strings = 8 qwords
    string_arr peek build_arr def_i     ; build_arr points to --> string_arr

    fig grapes oranges banana cherry dates apple mango  ; push these onto the stack

    {
        build_arr peek swap [poke_64]   ; after swap, write &fruit --> build_arr
                                        ; then 1 fruit gets consumed frm stack.
        8 int build_arr +=              ; build_arr += 8
    } stack_size loop                   ; while(!empty stack)

    8 int           ; element_size = 8 (qword = char*)
    8 int           ; count = 8
    string_arr peek ; base_ptr
    1 int           ; order = descending
    4 int           ; sort_type = string (char*)
    0 int           ; inner_bytes = 0
    qsort           ; run qsort operator

    string_arr peek build_arr =
    0 int index def_i       ; counter = 0

    {                                       ; display results
        build_arr peek [peek_64] puts_p     ; use puts_p to pop off
        8 int build_arr +=                  ; build_arr += 8 (bytes)
        1 int index +=                      ; inc counter++
    } index peek 8 int < loop               ; while(counter < 8)

    string_arr peek pop_free                ; deallocate 64 bytes

    dump_rts
```
