# STACK-POINTERS (bp_0 .. bp_7)

Stack-Pointers give you direct access to stack indexes without going through (slow) variables. They are called 'stack' because they skip the normal dictionary look-up for variables & read/write to the stack directly.

If you know assembler, then the idea is similar:

x86-64 Assembler:

```nasm
push    rbp
mov     rbp, rsp
sub     rsp, 24            ; make space
mov     rsi, [rbp - 8]     ; read
mov     [rbp - 16], rdi    ; write
```

echelon:

```
push_bp              ; mark current stack position
bp_1                 ; read
30 int [bp_2]        ; write
```

bp stands for base pointer, which works on a similar idea as assembly.

Important: `bp_0` through `bp_7` are fast but risky. They read and write directly to the stack and will crash your program if you misuse them. Always call `push_bp` first, use `pop_bp` or `pop_bp_clear` when you are done and never touch them without calling a `push_bp` frame.

---

### push_bp
`[...] -> [...]`

Marks the current top of the stack & sets up `bp_0` through `bp_7`. `bp_0` is the top value on the stack and `bp_7` is seven slots down.

Nest up to 255 frames.

---

### pop_bp
`[...] -> [...]`

Restores the previous frame. This only resets the pointers, the stack is left exactly as it is.

---

### pop_bp_clear
`[...] -> [...]`

Restores the previous frame & cuts the stack back to the size it was **at** the matching `push_bp` call. Anything pushed onto the stack after that `push_bp` call is automatically popped-off.

---

### get_bp
`[] -> [address]`

Pushes the memory address of the current base-pointer frame onto the stack. Useful for debugging.

---

### dump_bp
`[...] -> [...]` (stack unchanged)

Prints all active base-pointer frames for debugging.

---

### USING bp_0..bp_7

Once you have called push_bp:

- bp_n   --> pushes the value at that stack position to the top
- [bp_n] --> writes a new value into that stack position

Mapping Layout:

```
bp_0  -> writes using `[bp_0]`  (maps to [rbp] in x86 code)
bp_1  -> writes using `[bp_1]`  (maps to [rbp - 8] in x86 code)
bp_2  -> writes using `[bp_2]`  (maps to [rbp - 16] in x86 code)
bp_3  -> writes using `[bp_3]`  (maps to [rbp - 24] in x86 code)
bp_4  -> writes using `[bp_4]`  (maps to [rbp - 32] in x86 code)
bp_5  -> writes using `[bp_5]`  (maps to [rbp - 40] in x86 code)
bp_6  -> writes using `[bp_6]`  (maps to [rbp - 48] in x86 code)
bp_7  -> writes using `[bp_7]`  (maps to [rbp - 56] in x86 code)
```

## SOME EXAMPLES

```
; ----- push some values -----
10 int 20 int 30 int 40 int 50 int 60 int 70 int 80 int 90 int 100 int

push_bp

; stack after push_bp:
; [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
;          bp7 bp6 bp5 bp4 bp3 bp2 bp1 bp0

bp_0 print_i pop          ; 100
bp_4 print_i pop          ; 60
bp_7 print_i pop          ; 30

99 int [bp_0]             ; change top value
-5 int [bp_4]

bp_0 print_i pop          ; 99
bp_4 print_i pop          ; -5
```


; ----- pop_bp vs pop_bp_clear -----

```
push_bp                   ; frame A
; ... push more stuff ...
push_bp                   ; frame B
; ... push even more ...
push_bp                   ; frame C

pop_bp_clear              ; back to frame B, extra values from C are gone
pop_bp                    ; back to frame A (stack size stays the same)
pop_bp                    ; no more frames, bp_0..bp_7 all become NULL
```

Rule of thumb: Variables are clearer, whereas `bp_0..bp_7` are faster but much easier to shoot yourself in the foot with. Use them when you actually need faster processing and be extra careful whenever using the clear operator with them.

