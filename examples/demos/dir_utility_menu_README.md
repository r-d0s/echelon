# echelon Menu File Listing  (dir_utility_menu.ech)

This script lets the user list directories. It uses `fork` & `execve` to run external programs/commands.

---

## SIMPLE FORK + EXECVE

when you choose an option from the menu, the script creates a child proc using `sys_fork`. now both procs are detached from each other.

the child then replaces itself with the 'command', either `ls -l` or `find -d` using sys_execve.

 - if the child proc's command ever failed, it wouldn't affect the parent proc (main program/menu)
 - the parent proc waits for the child to finish using `sys_wait4`.
 - this is repeated until the user ends the program.

```
    main menu (parent)
        |
        v
    sys_fork --> creates child proc
        |           |
        |           `--> runs sys_execve to run 'ls -l' or 'find -d' --> then ENDS.
        |
        v
     parent --> waits for child to finish (sys_wait4) & writes buffered output to stdout
        |
        v
    back to main menu.. and repeat...
```

---

## MEMORY LAYOUT (40 BYTE STRUCT)

the script uses a 40 byte struct arg list for `sys_execve` (5 * 8 byte ptrs, for: prog path, dir path, two flags/args & NULL term).

```
offset [0]  : prog path (e.g "/usr/bin/ls")
offset [8]  : user entered dir path
offset [16] : 1st arg (e.g "-l" for ls, "-type" for find)
offset [24] : 2nd arg (e.g "d" for find, NULL for ls)
offset [32] : NULL
```

this layout is fixed, so the script knows exactly where to place each argument.

---

## RUNNING VALGRIND

to check echelon itself for leaks:

```
valgrind -s --track-origins=yes --leak-check=full ./echelon -f examples/demos/dir_utility_menu.ech
```

the parent process frees all its allocations, so, you should see:

    All heap blocks were freed -- no leaks are possible

if you want to trace forked child procs (ls, find), then add **--trace-children=yes**:

```
valgrind --trace-children=yes -s --track-origins=yes --leak-check=full ./echelon -f examples/demos/dir_utility_menu.ech
```

IMPORTANT: the child procs may show `still reachable` blocks, these are normal libc buffers & not mem leaks. the OS takes care of these.
