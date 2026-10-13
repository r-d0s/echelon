# TYPE CASTING & CONVERSION OPERATORS

Operators: `str`, `hex_to_ip`, `hex_to_ip_port`, `ip_port_to_int` all generate heap-allocated structs & must be deallocated using `pop_free`.

---

### int
`[str] -> [int]`

Converts a string to a signed integer.

```
"123" int print_i
```

---

### float
`[str] -> [float]`

Converts a string to a signed float.

```
"-3.14159" float print_fl
```

---

### i_float
`[int] -> [float]`

Converts an integer to a float.

```
95 int i_float print_fl
```

---

### fl_int
`[float] -> [int]`

Converts a float to an integer.

```
3.99 float fl_int print_i
```

---

### str
`[int] -> [str]`

Converts an integer to a heap-allocated string.

```
120 int str print_str pop_free
```

---

### hex_int
`[str] -> [int]`

Converts a hex string to an integer.

```
"ff" hex_int print_i
```

---

### str_int
`[str] -> [int]`

Converts a runtime-built string to an integer.

```
read_str dup        ; read user input (as string), then make copy to free later.
str_int             ; convert this string --> int, push the int above it.
print_i swap        ; display it & swap it with the string below.
pop_free            ; free the string from earlier (using read_str)
```

---

### hex_to_ip
`[str] -> [str]`

Converts a hex string to a heap-allocated IP address string

```
0100007f hex_to_ip print_str pop_free   ; "127.0.0.1"
```

Important: on x86 little-endian arch: "7f000001" --> "1.0.0.127".

to get "127.0.0.1", just pass the byte swapped string "0100007f"

---

### hex_to_ip_port
`[str] -> [str]`

Converts a hex string to a heap-allocated IP:PORT string.

```
0100007f1353 hex_to_ip_port print_str pop_free   ; "127.0.0.1:4947"
```

Important: The first 8 hex chars: IP, the next 4 chars: PORT.

The same little-endian rules expla  ined in `hex_to_ip`.

---

### ip_port_to_int
`[str] -> [block_ptr]`

Converts an IP:PORT string to a 16 byte sockaddr_in struct on the heap.

```
"192.168.0.14:4947" ip_port_to_int
```

Block Layout (16 bytes):

```
offset  size    member
------  ----    ------
 [0-1]     2    sin_family (0x0002 = AF_INET)
 [2-3]     2    Port (BIG-ENDIAN)
 [4-7]     4    IP Address
[8-15]     8    (null-padding)
```

code example:

```
"192.168.0.14:4947" ip_port_to_int sock_block def_i ; stored as sock_block var

sock_block peek
dup 0 int + [peek_16] print_i pop       ; 2 (AF_INET)
dup 2 int + [peek_16] print_i pop       ; 21267 (0x5313, BIG-endian port)
dup 4 int + [peek_32] print_ptr pop     ; 0xc0a8000e (IP)
pop_free                                ; deallocate the block
```

Important: the port member = BIG-endian (0x5313 = 21267).
