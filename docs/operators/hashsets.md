# HASHSET OPERATORS

---

### new_hash
`[size] -> [hashset_ptr]`

Creates a new empty hashset. The capacity is rounded up to the next power of 2 with a minimum size of 64 buckets.

```
27 int new_hash ptr def_i   ; creates hashset with capacity of 64, even though 27 was selected.
```

Important: The hashset is heap-allocated, so use `del_hashset` to free it.

Hashset node layout (25 bytes total):

- offset [0]:  KEY (8 bytes)
- offset [8]:  VALUE (8 bytes)
- offset [16]: *next pointer (8 bytes)
- offset [24]: memory clean-up flag (1 byte)

---

### add_hash
`[ptr, key, value, flag] -> []`

Adds a Key-Value pair to the hashset. Automatically doubles bucket capacity if total node count > 75% capacity

```
ptr peek "Xabi Alonso" "Stamford Bridge, SW6" 0 int add_hash
```

Important: 'Keys' are strings [0-9a-z]. 'Values' can be anything integers, floats, strings or pointers.
The flag param is stored per node and decides how clean-up operators handle the 'Key' and 'Value' fields when deallocating.

Node Clean-up Flags:

```
0 = leave KEY and leave VALUE
1 = free KEY and leave VALUE
2 = leave KEY and free VALUE
3 = free KEY and free VALUE
```

The key "Xabi Alonso" & value "Stamford Bridge, SW6" are strings within the actual program code. They will be automatically freed when the program exits. If we tried to free them (by using FLAG 1 or 3), this would cause a double-free crash because the program would try to free them **again** at exit!

So use FLAG 0, which tells the program to leave both 'Key' & 'Value' when cleaning-up.

When to use other FLAGS?

If your key or value were heap-allocated (e.g: `mem_alloc`, `str`, `add_str`, `read_file`, etc..), then they won't be freed automatically, so it's up to **you** to manage them. In those cases, you may want the hashset to deal with the clean-up by using:

- FLAG 1 --> Free KEY only
- FLAG 2 --> Free VALUE only
- FLAG 3 --> Free KEY & VALUE


Remember: If the 'Key' or 'Value' are part of your program code (like "hello, world!"), or maybe 'value' is an `int: -321` or `float: 3.142` then you must use FLAG 0 or 1. If you allocated **either** of them yourself, then select the right FLAG & let the program free it for you. Or if you prefer, deallocate them manually!

Important: Overwrite existing 'Value' if the same 'Key' already exists.

---

### add_hash_fix
`[ptr, key, value, flag] -> []`

Same as add_hash but does NOT check or expand hashset capacity. Use this when you need a **fixed** capacity hashset.

```
ptr peek "Moises Caicedo" "Chelsea FC" 0 int add_hash_fix
```

---

### get_hash
`[ptr, key] -> [value, 1] or [0]`

Looks up a value by its 'key' string. Returns the value, followed by 1 (true) if found. Otherwise 0 if the 'key' is not found.

```
ptr peek "Moises Caicedo" get_hash   ; stack: ["Chelsea FC", 1]
ptr peek "Rodri" get_hash            ; stack: [0]
```

---

### hash_exists
`[ptr, key] -> [value_ptr_ptr] or [0]`

Checks if a 'key' exists. Returns double pointer (**ptr) to the 'value' if found, otherwise 0.

```
ptr peek "Moises Caicedo" hash_exists   ; returns pointer to value pointer
ptr peek "Mbappe" hash_exists           ; returns 0
```

Important: Returns **ptr (pointer to pointer) value. use `[peek_64]` to deref & get the actual value.

**zero** = false/not found, **non-zero** = true (a **ptr).

dereferencing example:

```
ptr peek "Joao Pedro" hash_exists
{
    [peek_64] puts_p
}else{
    "Not found" puts_p
} if
```

---

### del_hash
`[ptr, key] -> [1] or [0]`

Deletes a node (key-value pair) from the hashset by searching for the 'key'. Returns 1 if the node was found & deleted, 0 if not.

```
ptr peek "Rodri" del_hash              ; returns 0 (not found)
ptr peek "Moises Caicedo" del_hash     ; returns 1 (deleted)
```

Important: The node is deleted, however, the node flag is checked to handle key & value deallocations correctly.

---

### del_hashset
`[ptr] -> []`

Deletes the entire hashset allocation & frees all nodes from heap memory.

```
ptr peek del_hashset
```

Important: Scans all bucket lists and checks each node flag to free keys and values correctly.

---

### clear_hashset
`[ptr] -> []`

Deletes all nodes from the hashset and leaves the hashset bucket structure for re-use.

```
ptr peek clear_hashset
```

Important: Resets the node counter to 0 & bucket capacity to 64.

---

### dump_hashset
`[ptr] -> []`

Debug tracking tool. Displays the complete hashset map containing all nodes, collisions & values.

```
ptr peek dump_hashset
```


## HASHSET STRUCTURE

Header Struct (16 bytes total):

- bytes [0-7]:   **buckets (Pointer to array of bucket pointers)
- bytes [8-11]:  node counter (4 byte unsigned integer)
- bytes [12-15]: bucket capacity (4 byte unsigned integer)

Node Struct (25 bytes total):

- bytes [0-7]:   KEY string pointer
- bytes [8-15]:  VALUE pointer
- bytes [16-23]: *next node address pointer
- byte  [24]:    memory clean-up flag byte


## HASHSET STRUCT DIAGRAM

example: 8 bucket capacity array with 3 nodes, with collision chain at index[2].

```
hashset [0x6000]
  |
  |--> [0x6000] ----> bucket array [0x5000]
  |                   |
  |                   |--> [0x5000] bucket 0: NULL
  |                   |--> [0x5008] bucket 1: NULL
  |                   |--> [0x5010] bucket 2: --> Node 1 [0x7000] --> Node 2 [0x7200]
  |                   |--> [0x5018] bucket 3: NULL
  |                   |--> [0x5020] bucket 4: NULL
  |                   |--> [0x5028] bucket 5: NULL
  |                   |--> [0x5030] bucket 6: --> Node 3 [0x7400]
  |                   `--> [0x5038] bucket 7: NULL
  |
  |--> [0x6008] #nodes = 3
  `--> [0x600c] capacity = 8


bucket 2 [0x5010] --> Node 1 [0x7000]
                      |
                      |--> KEY:     "Xabi Alonso"
                      |--> VALUE:   "Stamford Bridge"
                      |--> *next:   0x7200
                      `--> FLAG:    0   |
                                        |
                                        `--> Node 2 [0x7200]
                                             |
                                             |--> KEY:     "Moises Caicedo"
                                             |--> VALUE:   "Chelsea FC"
                                             |--> *next:   NULL
                                             `--> FLAG:    0

bucket 6 [0x5030] --> Node 3 [0x7400]
                      |
                      |--> KEY:     "Joao Pedro"
                      |--> VALUE:   "Striker #20"
                      |--> *next:   NULL
                      `--> FLAG:    0
```
