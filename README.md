# echelon

a stack-based programming language, written in x86-64 assembly.

echelon is RPN (Reverse Polish Notation), that means operators come after
their operands

```
func: square_it
    dup *
    return

_start:
    "hello world" puts                  ; prints "hello world"
    9 int square_it call_func print_i   ; prints 81
```

it supports recursion, loops, if/else, functions, variables, heap
allocation, hashsets, graphs & file/network I/O. it links against PCRE2,
libc's math functions & malloc/free.

64K stripped binary (only supports x86-64 Linux).

full story of how/why this exists: [how_it_started.md](how_it_started.md)

## Why assembly?

writing a basic RPN calculator seemed like a straight-forward challenge & using NASM
wasn't a problem because I had already written several small projects using it.

once conditional checks & loops were working, it quickly grew from 7/8 operators to 20.
at this point it was too late to re-start the project in C, so I just carried on!


## Build

Needs:
- gcc
- nasm
- make
- libpcre2
- libm (normally already there)

Debian / Ubuntu:

    sudo apt install gcc nasm make libpcre2-dev

Fedora:

    sudo dnf install gcc nasm make pcre2-devel

Build:

    make

For stripped release binary:

    make release

Run (always from repo root):

    ./echelon -f examples/demos/simple_http_page.ech

## Tested

Valgrind clean (0 leaks & 0 errors) using docker with **Ubuntu**, **Debian**, **Fedora**, **Arch**, **Kali**, **openSUSE** & **Rocky/RHEL** including:

- recursive fibonacci(38): 39,088,169
- 100,000,000 byte heap fill/re-write test
- 300,365 malloc/free cycles, apprx 5GB allocated
- 10M index array in place qsort
- hashset with chained buckets, insert/look-up/delete..
- unbalanced binary tree, 41 nodes, recursive fib per node (docker: 21 nodes)
- TCP client/server over raw sockets
- 16 level nested if/else, >300,000 lines of generated source: 10,000 repetitions (docker: 100 repetitions)

full logs in one folder for each test (source, timing & Valgrind): [benchmarks/](benchmarks/)

## Some examples & demos

a few examples that show what it does & how it does it:

- [TCP client/server](examples/demos/simple_TCP_client_server_README.md) - two way messaging
  over raw sockets, the data is hex-dumped, Valgrind clean on both ends.
- [Raw-syscall HTTP server](examples/demos/simple_http_page.ech) - no networking library,
  the sockaddr_in struct is built using `poke_16/32/64`. point a browser at it & it serves a HTML page
- [Replacing the running proc with execve](examples/demos/exec_binary.ech) - the envp & argv structs 
  passed to that binary are built in the script, overriding what the parent shell would have passed down.
- [Parallel fibonacci, 14 forked processes](benchmarks/parallel_fibonacci/) - 399% CPU utilisation,
  with every child proc Valgrind clean.
- [Hashset torture test](benchmarks/hashset_fixed_bucket/) - 1M nodes forced into 64 fixed buckets,
  apprx 15,625 nodes per bucket, 50% look-ups & deletes with 0 leaks.
- [16-level nested if/else stress test](benchmarks/nested_if_else/nested_stress_test_README.md) -
  300,000+ lines of generated source, every branch calls a 10,000 loop. the whole test is repeated
  10,000 times, valgrind clean.
- [Stack-pointers vs variables, benchmarked](tutorials/tutorial_13b_stack_pointers.ech) -
  the same workload but using two implementations, apprx 2.7x time difference, compared across 5 input sizes.


more tests & examples:

- [examples/demos/](examples/demos/)
- [benchmarks/](benchmarks/)
- [tutorials/](tutorials/)


## Docs

- [Architecture overview](docs/design_notes/architecture_overview_diagram.md)
- [Execution flow, source file --> running program](docs/design_notes/execution_flow_file_to_prog.md)
- [Operator reference](docs/operators/)
- [Tutorials](tutorials/) - 14 examples, stack basics through to hashsets & graphs
- [Demos](examples/demos/) - HTTP server, execve, TCP, forking, graphs, basic encryption
- [Operator reference tests](examples/reference/) - every operator, grouped by category
- [Handwritten design notes](docs/design_notes/handwritten_notes/) - the actual planning dev journey, scanned notes
- [Developer notes](docs/developer/) - lessons learned, optimisation journey, design trade-offs,
  error handling & how to add a new operator


## License

MIT see [LICENSE](LICENSE) for details
