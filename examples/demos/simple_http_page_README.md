# BASIC NETWORKING WEB SERVER (simple_http_page.ech)

this is a basic TCP web server using system calls. it listens on port **8080** & serves a simple HTML page to anyone that connects. when a browser connects with **http://localhost:8080** it gets a response

---

## SETTING UP THE SOCKET STRUCT

because echelon doesn't have any networking libraries, we build the sockaddr_in struct ourselves using memory offsets & **[poke_16/32/64]**.

it's quite easy, take a look at the 16 byte struct:

```
offset    bytes    what it stores
------    -----    --------------
[0]       2        AF_INET (2) IPv4
[2]       2        port number (network byte order, BIG-endian)
[4]       4        IP address (0.0.0.0)
[8]       8        padding (null out)
```

x86 CPUs use little-endian, but the network expects BIG-endian. so port **8080** gets converted to **0x1F90** (36895 in decimal) before being written.

---

## THE NETWORK PROCESS

the server follows these steps (system calls):

```
step      system-call    number    description
----      -----------    ------    -----------
  1       sys_socket        41     create socket (get fd)
              |
              v
  2        sys_bind         49     attach socket to IP & port
              |
              v
  3       sys_listen        50     start listening for connection
              |
              v
  4       sys_accept        43     wait for client to connect (blocking)
              |
              v
  5       sys_write          1     send HTTP response to client
              |
              v
  6       sys_close          3     close connection
```

---

## MEMORY CLEAN-UP

every allocation is freed at the end of the program, that means no leaks or errors.

---
