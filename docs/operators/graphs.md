# GRAPH OPERATORS

## These graph operators work on a similar system as the hashset operators.

For most of these operators, I decided to raise a silent error when a node is **not** found in the graph.

The user can review the error/missing node or missing edge, but the program continues to run.

e.g:

```
Error: unable to locate graph node: [test123], please check this!
Error: no edge found between [foo] ---> [bar] in graph!
```

---

### create_graph
`[size] -> [graph_ptr]`

Creates a new empty graph. The size is rounded up to the next power of 2 with a minimum size of 64 buckets.

```
10 int create_graph g_ptr def_i
```

Important: Returns a pointer to the graph structure. Use `delete_graph` to free it.

---

### delete_graph
`[graph_ptr] -> []`

Deletes the entire graph and frees all memory including nodes & edges.

```
g_ptr peek delete_graph
```

Important: Frees all heap allocations & uses the node 'flag' to handle KEY and VALUE data.

---

### graph_add_node
`[graph_ptr, node_id, flag] -> []`

Adds a new node to the graph 'graph_ptr' using a string 'node_id' and a clean-up 'flag'.

```
g_ptr peek "A" 2 int graph_add_node
```

```
Important: The flag byte handles node memory cleanup:
  0 = leave KEY and leave VALUE
  1 = free KEY and leave VALUE
  2 = leave KEY and free VALUE (most common setting for our examples)
  3 = free KEY and free VALUE
```

---

### graph_del_node
`[graph_ptr, node_id] -> [1] or [0]`

Deletes 'node_id' & all connected edges. Deallocates the node based on its clean-up 'flag'.

Returns 1 if 'node_id' found, 0 if not.

```
g_ptr peek "A" graph_del_node
```

Important: Removes all connected forward & backward edges.

---

### graph_node_exists
`[graph_ptr, node_id] -> [ptr] or [0]`

Checks if a node 'node_id' exists. Returns a pointer to the node if found, otherwise returns 0.

```
g_ptr peek "A" graph_node_exists   ; returns node ptr
g_ptr peek "Z" graph_node_exists   ; returns 0
```

---

### graph_add_edge
`[graph_ptr, dest, src] -> []`

Adds an unweighted edge linking 'src' node to 'dest' node. If the edge already exists, it does not change the weight.

```
g_ptr peek "B" "A" graph_add_edge
```

Important: Creates forward link from 'src' to 'dest' & backward link from 'dest' to 'src'.

---

### graph_add_edge_weight
`[graph_ptr, dest, src, weight] -> []`

Adds a weighted edge from 'src' node to 'dest' node. If the edge already exists, it does not update the weight.

```
g_ptr peek "D" "A" 10 int graph_add_edge_weight
```

Important: The weight param can be anything, integer, a float, pointer to anything.

---

### graph_del_edge
`[graph_ptr, dest, src] -> []`

Deletes the edge linking 'src' to 'dest'. Removes both forward & backward links.

```
g_ptr peek "B" "A" graph_del_edge
```

---

### graph_edge_exists
`[graph_ptr, dest, src] -> [1] or [0]`

Returns 1 if an edge exists from 'src' to 'dest', 0 if not.

```
g_ptr peek "B" "A" graph_edge_exists   ; 1
g_ptr peek "A" "B" graph_edge_exists   ; 0
```

---

### graph_get_weight
`[graph_ptr, dest, src] -> [weight]`

Returns the weight value of edge linking 'src' to 'dest'. Silent error if edge does not exist.

```
g_ptr peek "D" "A" graph_get_weight   ; 10
```

---

### graph_set_weight
`[graph_ptr, dest, src, weight] -> []`

Updates the weight value of an existing edge linking 'src' to 'dest'.

```
g_ptr peek "D" "A" 99 int graph_set_weight
```

---

### graph_get_weight_ptr
`[graph_ptr, dest, src] -> [weight_ptr] or [0]`

Returns a pointer to the weight of an edge, or 0 if the edge does not exist.

```
g_ptr peek "D" "A" graph_get_weight_ptr
[peek_64] print_i   ; dereference to see weight
```

---

### graph_get_fwd_links
`[graph_ptr, node_id] -> [block_ptr] or [0]`

Returns a 16 byte tracking block containing an array of node pointers for forward links. Returns 0 if there are no forward links.

```
g_ptr peek "A" graph_get_fwd_links
```

Important: Tracking block memory layout:
- offset [0]: pointer to node array (**ptr)
- offset [8]: total number of forward nodes (int)

---

### graph_get_back_links
`[graph_ptr, node_id] -> [block_ptr] or [0]`

Returns a 16 byte tracking block containing an array of node pointers for backward links. Returns 0 if there are no backward links.

```
g_ptr peek "D" graph_get_back_links
```

Important: Tracking block memory layout:
- offset [0]: pointer to node array (**ptr)
- offset [8]: total number of backward nodes (int)

---

### graph_get_fwd_weight_links
`[graph_ptr, node_id] -> [block_ptr] or [0]`

Returns a data block containing forward node pointers and their weights. Returns 0 if no links exist.

```
g_ptr peek "A" graph_get_fwd_weight_links
```

Important: Each entry in the array takes up 16 bytes: `[node_ptr (8 bytes)], [weight (8 bytes)]`.


Use `16 int +` to jmp to the next entry in the list.

---

### graph_get_fwd_count
`[graph_ptr, node_id] -> [count] or [-1]`

Returns the total count of forward links moving out from 'node_id'. Returns -1 if 'node_id' is not found.

```
g_ptr peek "A" graph_get_fwd_count print_i   ; 3
```

---

### graph_get_back_count
`[graph_ptr, node_id] -> [count] or [-1]`

Returns the total count of backward links pointing into 'node_id'. Returns -1 if 'node_id' is not found.

```
g_ptr peek "D" graph_get_back_count print_i   ; 2
```

---

### graph_get_nodes
`[graph_ptr] -> [block_ptr]`

Returns a 16 byte tracking block pointing to an array of ALL node pointers in the graph.

```
g_ptr peek graph_get_nodes
```

Important: Tracking block memory layout:
- Offset [0]: pointer to node array (**ptr)
- Offset [8]: total number of nodes in graph

---

### graph_node_count
`[graph_ptr] -> [count]`

Returns the total number of nodes inside the graph.

```
g_ptr peek graph_node_count print_i
```

---

### graph_edge_count
`[graph_ptr] -> [count]`

Returns the total number of edges inside the graph.

```
g_ptr peek graph_edge_count print_i
```

---

### dump_graph
`[graph_ptr] -> []`

Prints the entire graph structure, including fwd/back links & weights.

```
g_ptr peek dump_graph
```

---

## Graph Node Diagram (Single Node & Deletion)

---

```
    +------------+
    | GRAPH NODE |
    +------------+
    | KEY        | --> "X"
    | VALUE      | --> 0x3C000 [32 byte DATA BLOCK] --.
    | *next      | --> collision chain                |
    | FLAG       | --> 2 (leave KEY & free VALUE)     |
    +------------+                                    |
                                                      |
                                                      v
          +----------------------------------------------------------------+
          |             DATA BLOCK (32 bytes) 0x3C000                      |
          +---------------------+------------------------------------------+
          | [0] fwd_link_ptr    | 0x9000 --> [Forward Link Array]          |
          | [8] back_link_ptr   | 0xBA00 --> [Backward Link Array]         |
          | [16] fwd_arr_size   |      8 --> current capacity (4 bytes)    |
          | [20] back_arr_size  |      8 --> current capacity (4 bytes)    |
          | [24] next_fwd_pos   |      3 --> next insertion indx (4 bytes) |
          | [28] next_back_pos  |      2 --> next insertion indx (4 bytes) |
          +---------------------+------------------------------------------+
                    |                               |
                    v                               v
          +-----------------------+        +---------------------+
          |       0x9000          |        |        0xBA00       |
          |  FORWARD LINK ARRAY   |        | BACKWARD LINK ARRAY |
          |   (16 bytes entry)    |        |   (8 bytes entry)   |
          +-----------+-----------+        +---------------------+
          | dest_ptr  |    weight |        |   src_ptr           |
          +-----------+-----------+        +---------------------+
          |   0x7400  |       29  |        |   0x7700            |
          |   0x7500  |        7  |        |   0x7800            |
          |   0x7600  |       99  |        |     NULL            |
          |     NULL  |        0  |        +---------------------+
          +-----------+-----------+
```

---

deleting NODE_A (0x7400) from NODE_X's forward link array:

```

1) find NODE_A in NODE_X's forward link array
   +------------------------------------------------------+
   | NODE_X's FORWARD LINK ARRAY                          |
   +------------------------------------------------------+
   | [0] --> NODE_A (0x7400), weight: 29  <-- remove this |
   | [1] --> NODE_B (0x7500), weight: 7                   |
   | [2] --> NODE_C (0x7600), weight: 99  <-- LAST entry  |
   +------------------------------------------------------+
                     |
                     v

2) cpy the LAST entry (NODE_C) over NODE_A's index:
   +--------------------------------------------------------+
   | [0] --> NODE_C (0x7600), weight: 99  <-- overwritten   |
   | [1] --> NODE_B (0x7500), weight: 7                     |
   | [2] --> NODE_C (0x7600), weight: 99  <-- still exists! |
   +--------------------------------------------------------+
                      |
                      v

3) decrement next_fwd_pos-- (3 -> 2)
   +-----------------------------------------------------------+
   | next_fwd_pos: 2  <-- next insert will overwrite index [2] |
   +-----------------------------------------------------------+


4) updated forward link array:
   +----------------------------------------------------------+
   | [0] --> NODE_C (0x7600), weight: 99   <-- ok             |
   | [1] --> NODE_B (0x7500), weight: 7    <-- ok             |
   | [2] --> NODE_C (0x7600), weight: 99   <-- now AVAILABLE! |
   +----------------------------------------------------------+
```

NODE_A is gone, NODE_C is still there, it was just copied.
the next array insertion will overwrite index [2] with the new entry.
