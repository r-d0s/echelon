# ECHELON OPERATOR REFERENCE

<details>
<summary><b>1. Integer Arithmetic</b></summary>

* `+`, `-`, `*`, `/`, `%`, `++`, `--`, `abs`, `min`, `max`, `is_even`, `is_odd`, `hcf`, `lcm`, `is_prime`

</details>

<details>
<summary><b>2. Stack Manipulation</b></summary>

* `pop`, `clear`, `swap`, `dup`, `dup_n`, `rev`, `clear_above`, `clear_below`, `shift_up`, `shift_down`, `shift_up_n`, `shift_down_n`, `stack_size`, `swap_top_n`, `swap_bottom_n`, `swap_pos`, `value_at`, `[value_at]`, `dup_args`, `pop_n`

</details>

<details>
<summary><b>3. Bitwise & Logical</b></summary>

* `&&`, `||`, `!`, `xor`, `~`, `&`, `|`, `^`, `<<`, `>>`, `->>`

</details>

<details>
<summary><b>4. Type Casting</b></summary>

* `int`, `str`, `float`, `i_float`, `fl_int`, `str_int`, `hex_int`, `hex_to_ip`, `hex_to_ip_port`, `ip_port_to_int`

</details>

<details>
<summary><b>5. Comparisons</b></summary>

* `<`, `>`, `==`, `!=`, `<=`, `>=`, `<i>`, `<f>`, `<f`, `>f`, `<=f`, `>=f`, `==f`, `!=f`

</details>

<details>
<summary><b>6. Environment</b></summary>

* `get_env_ptr`, `get_env`, `set_env`

</details>

<details>
<summary><b>7. Stack Pointers</b></summary>

* `push_bp`, `pop_bp`, `pop_bp_clear`, `get_bp`, `dump_bp`, `bp_0..7`, `[bp_0..7]`

</details>

<details>
<summary><b>8. File I/O</b></summary>

* `open_file`, `open_file_app`, `close_file`, `read_file`, `str_to_file`, `bytes_to_file`, `write_bin`, `write_bin_ptr`, `write_nl`, `write_64b_num`, `file_size`

</details>

<details>
<summary><b>9. Float Operators</b></summary>

* `float`, `+f`, `-f`, `*f`, `/f`, `++f`, `--f`, `sqrt`, `i_float`, `fl_int`

</details>

<details>
<summary><b>10. Graphs</b></summary>

* `create_graph`, `delete_graph`, `dump_graph`, `graph_add_node`, `graph_del_node`, `graph_node_exists`, `graph_add_edge`, `graph_add_edge_weight`, `graph_del_edge`, `graph_edge_exists`, `graph_get_weight`, `graph_set_weight`, `graph_get_weight_ptr`, `graph_get_fwd_links`, `graph_get_back_links`, `graph_get_fwd_weight_links`, `graph_get_fwd_count`, `graph_get_back_count`, `graph_get_nodes`, `graph_node_count`, `graph_edge_count`

</details>

<details>
<summary><b>11. Hashsets</b></summary>

* `new_hash`, `add_hash`, `add_hash_fix`, `get_hash`, `hash_exists`, `del_hash`, `del_hashset`, `clear_hashset`, `dump_hashset`

</details>

<details>
<summary><b>12. Control Flow</b></summary>

* `{`, `}`, `_start:`, `if`, `else`, `loop`, `true_false`, `break`, `break_if`, `break_cond_if`

</details>

<details>
<summary><b>13. Memory Operators</b></summary>

* `mem_alloc`, `pop_free`, `pop_free_n`, `fill_mem`, `del_str_set`, `copy_bytes`, `stack_to_mem`, `get_stack_addr`, `[peek_8]`, `[peek_16]`, `[peek_32]`, `[peek_64]`, `[peek_8s]`, `[peek_16s]`, `[peek_32s]`, `[poke_8]`, `[poke_16]`, `[poke_32]`, `[poke_64]`

</details>

<details>
<summary><b>14. QSort</b></summary>

* `qsort`

</details>

<details>
<summary><b>15. Regex</b></summary>

* `regex`, `regex_sub`, `regex_multi`

</details>

<details>
<summary><b>16. String Operators</b></summary>

* `len_str`, `add_str`, `cpy_str`, `upd_str`, `sub_str`, `cmp_str`, `cmp_str_u`, `cmp_str_i`, `index_str`, `starts_with`, `ends_with`, `to_upper`, `to_lower`, `trim_str`, `replace_str`, `join_str`, `split_str`, `split_str_delim`, `get_lines`, `smash_str`, `smash_str_ascii`, `sprintf`, `sprintf_p`

</details>

<details>
<summary><b>17. System/Misc</b></summary>

* `sys_call`, `sleep`, `epoch`, `exit`, `rand`, `rand_str`, `rand_str_batch`, `create_struct`, `def_struct`, `struct_size`

</details>

<details>
<summary><b>18. Trig/Advanced Math</b></summary>

* `sin`, `cos`, `tan`, `pow`, `acos`, `asin`, `atan`, `atan2`, `exp`, `exp2`, `expm1`, `log`, `log2`, `log10`, `log1p`, `fabs`, `fmin`, `fmax`, `floor`, `ceil`, `round`, `trunc`, `sinh`, `cosh`, `tanh`, `hypot`, `fma`

</details>

<details>
<summary><b>19. User Input</b></summary>

* `read_i`, `read_f`, `read_str`

</details>

<details>
<summary><b>20. Variables</b></summary>

* `def_i`, `def_f`, `def_str`, `peek`, `poke`, `=`, `+=`, `-=`, `*=`, `/=`, `+=f`, `-=f`, `*=f`, `/=f`, `dump_dict`, `&[var_addr]`

</details>

<details>
<summary><b>21. Stack Display/Output</b></summary>

* `dump_i`, `dump_str`, `dump_rts`, `dump_ptr`, `print_i`, `print_fl`, `print_str`, `print_ptr`, `nl`, `hex_str`, `hex_mem_n`, `puts`, `puts_p`, `printf`, `printf_p`, `printf_f`, `printf_fp`, `fflush`

</details>
