# Stress Test: 16-Level Nested If/Else

this tests whether echelon's control flow & memory management break under heavy nesting.

examples are [here](nested_16_levels_IF_ELSE_100_iterations_valgrind.txt) and docker/Valgrind results can be seen [here](docker_valgrind_nested_16_levels_IF_ELSE).

it uses file: `nested_16_levels_IF_ELSE.ech`, however this needs to be uncompressed before you can run it.

## Details of test:

- 16 levels of nested `if`/`else` blocks
- each level generates a rand int (odd/even). the total `subtracts odd numbers` and `adds even numbers`. once the 16 levels are completed the `total is displayed`.
- before starting each of the 16 nested levels, a `function is called` & 10,000 iteration loop starts adding random (0..9) numbers. 
  the sum for each iteration is displayed (it should be apprx 45,000).
- the whole test repeats 10,000 times from `_start`.
- variables are created inside the called function.
- the source code (32M) has `> 300,000 lines` of code.


16 levels of nested IF/ELSE is quite deep & firing off 10,000 iterations at every level will definitely show any memory leaks. repeating this 10,000 times deliberately stresses the call stack, resume stack & variable dictionary. Valgrind will easily pick up on leaking memory or any corrupt memory R/W. the source file is 32M, so this will stress the tokeniser & program code array.

## Instructions to use the source file:

file: `nested_16_levels_IF_ELSE.ech.gz` needs to be uncompressed using `gunzip` in the terminal:

```
gunzip nested_16_levels_IF_ELSE.ech.gz
```

verify the file using checksum `md5sum`:

```
Wed Sep 30 [19:02:34]$ md5sum nested_16_levels_IF_ELSE.ech
e5484d1006780b8df07fa098412d0eb3  nested_16_levels_IF_ELSE.ech
```

if you're running Valgrind with this file, reduce the iteration loop in `_start:` from 10,000 to something smaller like 100-->1,000:

```
valgrind -s --leak-check=full ./echelon -f benchmarks/nested_if_else/nested_16_levels_IF_ELSE.ech
```

or you can run without Valgrind for speed (send output to /dev/null):

```
/usr/bin/time -v ./echelon -f benchmarks/nested_if_else/nested_16_levels_IF_ELSE.ech >/dev/null
```

## Valgrind should report

```
All heap blocks were freed -- no leaks are possible
ERROR SUMMARY: 0 errors from 0 contexts
```

if you see anything else, echelon has a bug!
