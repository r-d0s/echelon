# MULTI-PROCESS FORKING

echelon creates new procs (e.g copying itself) using Linux system calls. this is used to make things run in parallel e.g multiple fibonacci calcs happening at the same time.

---

## FORK PROCESS (sys_fork)

when you call `sys_fork` (syscall 57), the Linux kernel clones your **entire** proc, that includes code, variables, stack, basically everything. it copies the entire program during execution. the **only** difference between the original (**parent**) & the copy (**child**) is the return value from the fork() call.

look at this code:

```
57 int 1 int sys_call        ; sys_fork (57)
fork_id poke                 ; store sys_fork return value (0 = child, >0 = parent)
```

   1) In the parent code (original proc), `fork_id` = child proc's id.

   2) In the child code (cloned proc), `fork_id` = 0 (NULL).

```
            [ main prog PID:3000 ]
                     |
                     v
                  [ sys_fork ]
                     |
         +-----------+-----------+
         |                       |
         v                       v
   [ CHILD PID:9100 ]       [ PARENT PID:3000 ]
      fork_id: 0              fork_id: 9100
```

storing the return value `fork_id` from `sys_fork` syscall is a great way to handle the code, because we can easily tell if the proc we're currently 'running' is either a parent or a child. basic conditional checks make this easy:

```
{
   ; handle code for the CHILD proc
   ; e.g calling funcs / running bin
} fork_id peek ! if                 ; if (fork_id == NULL) <-- CHILD

{
   ; handle code for the PARENT proc
   ; e.g wait for the CHILD proc to finish
} fork_id peek if                   ; if (fork_id != NULL) <-- PARENT
```

this guarantees the parent and child proc will always run their own code blocks. when a parent proc is waiting for the child proc to complete, we can use `sys_wait4` (syscall: 61)

```
{
   0 int                ; (unused reg)
   0 int                ; (unused reg)
   0 int                ; rdx = options (0 = blocking wait)
   0 int                ; rsi = status ptr (NULL)
   61 int               ; sys_wait4 (61)
   5 int sys_call       ; run the syscall
} fork_id peek if       ; PARENT code..
```

this allows the parent proc to continue processing once their child proc ends.


### MEMORY & INTERLEAVING

after `sys_fork`, the child proc gets its own memory space. any vars changed in the parent **don't** affect the child and vice versa. when multiple children print output at the same time, the terminal output gets randomly mixed-up (interleaved). that's fine, because the OS decides what it prints & when to print it:

```
+--------------------------------------------------------------------+
| CHILD process pid: 13325 ** FINISHED fibonacci series [10] ---> 55 |
| CHILD process pid: 13328 ** FINISHED fibonacci series [9]  ---> 34 |
| CHILD process pid: 13331 ** FINISHED fibonacci series [2]  ---> 1  |
| CHILD process pid: 13331 ** FINISHED fibonacci series [3]  ---> 2  |
| CHILD process pid: 13331 ** FINISHED fibonacci series [4]  ---> 3  |
| CHILD process pid: 13331 ** FINISHED fibonacci series [5]  ---> 5  |
| CHILD process pid: 13328 ** FINISHED fibonacci series [10] ---> 55 |
+--------------------------------------------------------------------+
```

here's an example of the the terminal output interleaving

---

### time -v OUTPUT

this shows interleaving happening in the `time -v` command:

```
   User time (seconds): 0.00
   System time (seconds): 0.00
   Percent of CPU this job got: 0%
   Elapsed (wall clock) time (h:mm:ss or m:ss): 0:01.43
   Maximum resident set size (kbytes): 1920
   CHILD process pid: 13355 ** FINISHED fib(20) ---> 6765
   sending now..
   CHILD process pid: 13354 ** FINISHED fib(20) ---> 6765
```

### VALGRIND WITH CHILD PROCS

Valgrind will only check the parent proc. if you want to check the child procs, you'll need to add extra param:

```
valgrind -s --leak-check=full --trace-children=yes ./echelon -f <your_script_name.ech>
```

then you'll see heap summaries for all child procs & they should all show:

```
   ==13329== HEAP SUMMARY:
   ==13329==     in use at exit: 0 bytes in 0 blocks
   ==13329==   total heap usage: 527 allocs, 527 frees, 19,376 bytes allocated
   ==13329== All heap blocks were freed -- no leaks are possible
   ==13329== ERROR SUMMARY: 0 errors from 0 contexts

   ==13326== HEAP SUMMARY:
   ==13326==     in use at exit: 0 bytes in 0 blocks
   ==13326==   total heap usage: 527 allocs, 527 frees, 19,376 bytes allocated
   ==13326== All heap blocks were freed -- no leaks are possible
   ==13326== ERROR SUMMARY: 0 errors from 0 contexts
```
