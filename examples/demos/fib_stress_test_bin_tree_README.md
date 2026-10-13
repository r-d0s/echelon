# Fibonacci Binary Tree Stress Test

this test is designed to stress the call stack. it builds a Binary Search Tree (BST) using recursive functions, which stresses the stack, memory allocation & ptr look-ups.

the tree is deliberately built to be 'unbalanced' & skewed. the reason is simple.. we want to push the recursion depth quite far before we actually fire off the recursive fibonacci functions. during traversal, we stop at each node, run fibonacci, print the result, then resume & repeat.. again & again....

this creates nesting within nestings! the depth of the skewed tree, plus the depth of the fibonacci recursion itself. it's a great way to find any problms with deep recursion, memory management & ptr chasing.

---

## Node Layout

each node in the tree is a 32 byte block allocated on the heap. the layout is fixed:

```
offset [0]  : value (random int range --> 21..35)
offset [8]  : fibonacci result (calculated later)
offset [16] : *ptr to left child (LESS)
offset [24] : *ptr to right child (MORE)
```

---

## Processing Steps

- ternary insertion: the insertion code calculates the offset (+16/24) based on a greater or less than comparison.

- traversal order: when printing the tree, it uses pre-order: current node, then left subtree & then right subtree. this makes it easy to see the structure in the logs.

- deallocating nodes: when cleaning up, it uses post-order: left subtree, then right subtree & then current node. this guarantees that child nodes are freed BEFORE their parent, preventing leaks or even dangling ptrs.

---

## Memory Management

to make sure everything works properly, run these time & memory commands:

```
/usr/bin/time -v ./echelon -f examples/demos/fib_stress_test_bin_tree.ech
```

memory leak/error check using Valgrind:

```
valgrind --leak-check=full --show-leak-kinds=all ./echelon -f examples/demos/fib_stress_test_bin_tree.ech
```

---
