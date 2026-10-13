# echelon Operator Reference

Click a category below to jump to that section:

## Table of Contents

- [Integer Arithmetic](#integer-arithmetic)
- [Stack Manipulation](#stack-manipulation)
- [Bitwise & Logical](#bitwise--logical)
- [Type Casting](#type-casting)
- [Comparisons](#comparisons)
- [Environment](#environment)
- [Stack Pointers](#stack-pointers)
- [File I/O](#file-io)
- [Float Operators](#float-operators)
- [Graphs](#graphs)
- [Hashsets](#hashsets)
- [Control Flow](#control-flow)
- [Memory Operators](#memory-operators)
- [QSort](#qsort)
- [Regex](#regex)
- [String Operators](#string-operators)
- [System/Misc](#systemmisc)
- [Trig/Advanced Math](#trigadvanced-math)
- [User Input](#user-input)
- [Variables](#variables)
- [Stack Display/Output](#stack-displayoutput)

---

## Integer Arithmetic
`+`, `-`, `*`, `/`, `%`, `++`, `--`, `abs`, `min`, `max`, `is_even`, `is_odd`, `hcf`, `lcm`, `is_prime`

## Stack Manipulation
`pop`, `clear`, `swap`, `dup`, `dup_n`, `rev`, `clear_above`, `clear_below`, `shift_up`, `shift_down`, `shift_up_n`, `shift_down_n`, `stack_size`, `swap_top_n`, `swap_bottom_n`, `swap_pos`, `value_at`, `[value_at]`, `dup_args`, `pop_n`

## Bitwise & Logical
`&&`, `||`, `!`, `xor`, `~`, `&`, `|`, `^`, `<<`, `>>`, `->>`

## Type Casting
`int`, `str`, `float`, `i_float`, `fl_int`, `str_int`, `hex_int`, `hex_to_ip`, `hex_to_ip_port`, `ip_port_to_int`

## Comparisons
`<`, `>`, `==`, `!=`, `<=`, `>=`, `<i>`, `<f>`, `<f`, `>f`, `<=f`, `>=f`, `==f`, `!=f`, `<f>`

## Environment
`get_env_ptr`, `get_env`, `set_env`

## Stack Pointers
`push_bp`, `pop_bp`, `pop_bp_clear`, `get_bp`, `dump_bp`, `bp_0..7`, `[bp_0..7]`

## File I/O
`open_file`, `open_file_app`, `close_file`, `read_file`, `str_to_file`, `bytes_to_file`, `write_bin`, `write_bin_ptr`, `write_nl`, `write_64b_num`, `file_size`

## Float Operators
`float`, `+f`, `-f`, `*f`, `/f`, `++f`, `--f`, `sqrt`, `i_float`, `fl_int`

## Graphs
`create_graph`, `delete_graph`, `dump_graph`, `graph_add_node`, `graph_del_node`, `graph_node_exists`, `graph_add_edge`, `graph_add_edge_weight`, `graph_del_edge`, `graph_edge_exists`, `graph_get_weight`, `graph_set_weight`, `graph_get_weight_ptr`, `graph_get_fwd_links`, `graph_get_back_links`, `graph_get_fwd_weight_links`, `graph_get_fwd_count`, `graph_get_back_count`, `graph_get_nodes`, `graph_node_count`, `graph_edge_count`

## Hashsets
`new_hash`, `add_hash`, `add_hash_fix`, `get_hash`, `hash_exists`, `del_hash`, `del_hashset`, `clear_hashset`, `dump_hashset`

## Control Flow
`{`, `}`, `_start:`, `if`, `else`, `loop`, `true_false`, `break`, `break_if`, `break_cond_if`

## Memory Operators
`mem_alloc`, `pop_free`, `pop_free_n`, `fill_mem`, `del_str_set`, `copy_bytes`, `stack_to_mem`, `get_stack_addr`, `[peek_8]`, `[peek_16]`, `[peek_32]`, `[peek_64]`, `[peek_8s]`, `[peek_16s]`, `[peek_32s]`, `[poke_8]`, `[poke_16]`, `[poke_32]`, `[poke_64]`

## QSort
`qsort`

## Regex
`regex`, `regex_sub`, `regex_multi`

## String Operators
`len_str`, `add_str`, `cpy_str`, `upd_str`, `sub_str`, `cmp_str`, `cmp_str_u`, `cmp_str_i`, `index_str`, `starts_with`, `ends_with`, `to_upper`, `to_lower`, `trim_str`, `replace_str`, `join_str`, `split_str`, `split_str_delim`, `get_lines`, `smash_str`, `smash_str_ascii`, `sprintf`, `sprintf_p`

## System/Misc
`sys_call`, `sleep`, `epoch`, `exit`, `rand`, `rand_str`, `rand_str_batch`, `create_struct`, `def_struct`, `struct_size`

## Trig/Advanced Math
`sin`, `cos`, `tan`, `pow`, `acos`, `asin`, `atan`, `atan2`, `exp`, `exp2`, `expm1`, `log`, `log2`, `log10`, `log1p`, `fabs`, `fmin`, `fmax`, `floor`, `ceil`, `round`, `trunc`, `sinh`, `cosh`, `tanh`, `hypot`, `fma`

## User Input
`read_i`, `read_f`, `read_str`

## Variables
`def_i`, `def_f`, `def_str`, `peek`, `poke`, `=`, `+=`, `-=`, `*=`, `/=`, `+=f`, `-=f`, `*=f`, `/=f`, `dump_dict`, `&[var_addr]`

## Stack Display/Output
`dump_i`, `dump_str`, `dump_rts`, `dump_ptr`, `print_i`, `print_fl`, `print_str`, `print_ptr`, `nl`, `hex_str`, `hex_mem_n`, `puts`, `puts_p`, `printf`, `printf_p`, `printf_f`, `printf_fp`, `fflush`
