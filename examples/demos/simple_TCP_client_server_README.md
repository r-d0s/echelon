# NETWORKING

instead of using C libs, we can talk straight to the Linux kernel to handle TCP connections

here's an example of [two way messaging in echelon](../../benchmarks/TCP_client_server/simple_TCP_client_server_valgrind.txt)

this example used the following [client_code](simple_TCP_client.ech) & [server_code](simple_TCP_server.ech)


## TALKING DIRECTLY TO THE KERNEL (sys_call)

the sys_call operator takes values right off the stack & places them into the exact CPU registers that Linux expects. here's a simple Reverse Polish Notation (RPN) order for 3 args & syscall number:

```
[arg_3] --> [arg_2] --> [arg_1] --> [syscall_number] --> [register_count] --> sys_call
```

how the args map to registers:

```
stack order:   [arg_3] --> [arg_2] --> [arg_1] --> [syscall #] --> [count]

CPU registers: rdx <-- arg_3
               rsi <-- arg_2
               rdi <-- arg_1
               rax <-- syscall num
```

## SOME NETWORKING SYSTEM CALLS

when you make a system call, the data indexes & sizes **must** match up with what the kernel expects. here are some x86-64 networking operations:

```
+---------------+----------------+--------------------------------------------------------------------------+
| syscall name  | syscall number | register parameters                                                      |
+---------------+----------------+--------------------------------------------------------------------------+
| sys_read      | rax = 0        | rdi = fd, rsi = buff ptr, rdx = buff size                                |
| sys_write     | rax = 1        | rdi = fd, rsi = buff ptr, rdx = exact msg length                         |
| sys_close     | rax = 3        | rdi = fd                                                                 | 
| sys_socket    | rax = 41       | rdi = family (AF_INET=2), rsi = type (SOCK_STREAM=1), rdx = protocol (0) |
| sys_connect   | rax = 42       | rdi = fd, rsi = struct ptr, rdx = length (16)                            |
| sys_accept    | rax = 43       | rdi = fd, rsi = struct ptr, rdx = length ptr                             |
| sys_bind      | rax = 49       | rdi = fd, rsi = struct ptr, rdx = length (16)                            |
| sys_listen    | rax = 50       | rdi = fd, rsi = backlog limit                                            |
+---------------+----------------+--------------------------------------------------------------------------+
```

## SETTING UP SOCKET ADDRESSES (sockaddr_in)

Linux networking expects a 16 byte block to store connection details like IP addresses & port numbers, using little-endian byte ordering.

16 byte heap layout:

```
    offsets  [0-1]: address Family ([02][00] for AF_INET)
    offsets  [2-3]: port Number ([90][1f] for port 8080)  <-- uses BIG ENDIAN
    offsets  [4-7]: IP Address ([7f][00][00][01])
    offsets [8-15]: zero-padding
```

---

server set-up (accepts any IP):

```
    16 int mem_alloc sockaddr_in def_i
    sockaddr_in peek
    dup 2 int [poke_16]                 ; offset [0]: AF_INET Family (2)
    dup 2 int + 36895 int [poke_16]     ; offset [2]: port 8080 (0x901f)
    dup 4 int + 0 int [poke_32]         ; offset [4]: IP (0.0.0.0)
    dup 8 int + 0 int [poke_64]         ; offset [8]: NULL bytes
```

---

client set-up (connect to localhost):

```
    16 int mem_alloc sockaddr_in def_i
    sockaddr_in peek
    dup 2 int [poke_16]                 ; offset [0]: AF_INET Family (2)
    dup 2 int + 36895 int [poke_16]     ; offset [2]: port 8080 (0x901f)
    dup 4 int + 16777343 int [poke_32]  ; offset [4]: IP (127.0.0.1)
    dup 8 int + 0 int [poke_64]         ; offset [8]: NULL bytes
```

---

## FAST COMMAND CHECKING (QUIT)

instead of looping through strings or doing a strcmp to check if a user typed "QUIT", the program reads the first 4 bytes & pushes them onto the stack as a single dword integer. because "QUIT" can fit perfectly into 4 bytes (0x54495551), the server can check for exit commands instantly.

---
