# STDOUT, PIPES & BUFFERS OVERVIEW

## DETAILS:

This script grabs `ls -ltr` output straight into a memory buffer using pipes & forks, instead of using temp files.

here are the steps involved:

1) `sys_dup` saves a copy of the original stdout fd (file descriptor)

2) `sys_pipe` creates a pipe (**read** end & **write** end)

3) `sys_dup2` redirects stdout to the **write** end of the pipe

4) the **child** uses `sys_execve` to run /usr/bin/ls -ltr /boot/ /tmp/ //

5) the **parent** reads the output from the **read** end of the pipe using `sys_read`

6) `sys_dup2` restores stdout to its original state

7) the buffered output is printed & deallocated

---

## RUN COMMAND:

```
./echelon -f examples/demos/stdout_fork_to_buffer.ech
```

---

## VALGRIND ERRORS:

please remember, if you're running this script using Valgrind `--trace-children=yes` the child procs (ls -ltr) will show "still reachable" memory.

ignore this, these aren't leaks or anything to worry about, because the OS clears it up once the proc finishes.
