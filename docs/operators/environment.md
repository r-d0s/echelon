# ENVIRONMENT OPERATORS

Important:
1) `get_env` returns a memory pointer owned by the system environment. Do **not** deallocate this pointer using pop_free!
2) `set_env` return 0 on successful operations & a non-zero value on failure.
3) `get_env_ptr` returns a pointer to the system char** environ array struct.

---

### get_env_ptr
`[] -> [address]`

Returns pointer to the system environment variables array (char** environ).

Dereference using `[peek_64]` to iterate or extract strings.

```
get_env_ptr env_ptr def_i
```

---

### get_env
`[var_name] -> [value] or [0]`

Checks the environment array for 'var_name' variable. Returns a pointer if found, otherwise 0.

Do not free the return pointer.

```
OLDPWD get_env print_str pop
```

---

### set_env
`[flag, value, var_name] -> [result]`

Updates a system environment 'var_name' variable.

The override 'flag' value: 1 lets you overwrite existing values.

```
1 int /UPDATED/DIR/ OLDPWD set_env
```


## SOME EXAMPLES

```
; ----- get & print env vars -----
{
    "USER: %s\n" printf pop
}else{
    "USER not set" puts_p
} USER get_env dup if

; ----- set env vars (override) -----
{
    "MY_PATH set successfully" puts_p
}else{
    "Failed to set MY_PATH" puts_p
} 1 int /NEW_PATH/ MY_PATH set_env ! if

; ----- set env vars (no override) -----
{
    "MY_PATH was not overwritten" puts_p
}else{
    "Failed" puts_p
} 0 int /KEEP_OLD/ MY_PATH set_env ! if

; ----- iterate over all env vars -----
get_env_ptr env_ptr def_i           ; store *ptr as an int (env_ptr)
0 int i def_i                       ; counter = 0
{
    env_ptr peek i peek 8 int * +   ; shift ptr addr by using 'i' as qword index
    [peek_64] dup                   ; deref 8 bytes (dup for next cond check)
    0 int == break_cond_if          ; have we reached NULL? if so, break this loop
    puts_p                          ; 'if' failed, so print & pop the string we deref
    1 int i +=                      ; counter++
} 1 int loop                        : while(1)...
```
