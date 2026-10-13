# KERNEL SYSTEM CALLS FOR FILES & DIRECTORIES

to create, rename or delete files & directories, use these syscalls:

```
+---------------+-----------------+-------------------------------+
| syscall name  | syscall number  | register parameters           |
+---------------+-----------------+-------------------------------+
| sys_rename    | rax = 82        | rdi = oldpath,  rsi = newpath |
| sys_mkdir     | rax = 83        | rdi = pathname, rsi = mode    |
| sys_rmdir     | rax = 84        | rdi = pathname                |
| sys_creat     | rax = 85        | rdi = pathname, rsi = mode    |
+---------------+-----------------+-------------------------------+
```

## RETURN VALUES & ERROR CODES

sometimes a syscall fails e.g if you try to create a directory that already exists, the kernel returns a negative error code to tell you what went wrong.

in echelon these error codes are pushed on the stack as 64 bit numbers, like this:

0xffffffffffffffef

in signed decimal this is -17, the Linux kernel error table -17 means:

    EEXIST = -17 --> "File exists"

so if you see -17 on the stack after a `sys_mkdir` call, it means the directory you tried to create already exists. this can be useful because you can check the return value & decide what to do next. e.g you can print the return value using print_ptr or check it with 'if', or just pop-it if you're not bothered!

echelon always returns these codes (from rax) on top of the stack.

other examples of error codes:

    EPERM  = -1 --> "operation not permitted"
    ENOENT = -2 --> "no such file or directory"
