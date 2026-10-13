;-----------------------------------------------------------------------  -
; echelon.asm - a single file x86-64 interpreter....
;
; to do list:
;   1) split this source into e.g tokeniser.inc, init.inc, main_loop.inc,
;      clean_up.inc etc & then '%include' them.
;   2) handle allocation checks for every single malloc, apart from regex
;   3) handle all syscalls incase they fail
;   4) some other stuff too......
;-----------------------------------------------------------------------

%macro printLine 1-6
    ;-------------------------------
    %if %0 < 1 || %0 > 6
        %error "** printLine only accepts 1-->6 params! **"
    %endif
    ;-------------------------------
    mov rdi, %1
    ;-------------------------------
    %if %0 >= 2
        mov rsi, %2
    %endif
    ;-------------------------------
    %if %0 >= 3
        mov rdx, %3
    %endif
    ;-------------------------------
    %if %0 >= 4
        mov rcx, %4
    %endif
    ;-------------------------------
    %if %0 >= 5
        mov r8, %5
    %endif
    ;-------------------------------
    %if %0 >= 6
        mov r9, %6
    %endif
    ;-------------------------------
    xor     rax, rax
    call_libc printf

%endmacro

%macro call_libc 1      ; creates 0 --> 16 byte buffer before we call libc
    push    rbp
    mov     rbp, rsp
    and     rsp, -16    ; null out 1st 4 bits --> 16 byte boundary
    call    %1
    mov     rsp, rbp
    pop     rbp
%endmacro


global      main


extern printf, sprintf, puts, malloc, free, fflush, stdout, strtod, qsort_r      ; standard C lib
extern cos, sin, tan, acos, asin, atan, atan2                                    ; math lib funcs (-lm)
extern exp, exp2, expm1, log, log2, log10, log1p
extern pow, fabs, fmin, fmax
extern floor, ceil, round, trunc
extern sinh, cosh, tanh, hypot, fma
extern pcre2_compile_8, pcre2_substitute_8, pcre2_match_8                        ; PCRE2 regex
extern pcre2_match_data_create_from_pattern_8, pcre2_get_ovector_pointer_8
extern pcre2_match_data_free_8, pcre2_code_free_8, pcre2_get_error_message_8
extern setenv, getenv, localtime, time                                           ; sys & env

section .rodata             ; the r/o strings below aren't in order, sorry!

    badOpErr:               db "** [%s] is a bad operator!!! **", 0x0a, 0x00
    OpData:                 db "operator [%s]", 0x09, " has index of: [%d]", 0x0a, 0x00
    OpData2:                db "operator [%s]", 0x09, " links to [map_funcs + %d * 0x08]", 0x0a, 0x00

    debug_error_located:    db "       Occurred inside function: [%s]", 0x0a, 0x00
    err_single_operand:     db "ERROR: '%s' needs 1 operand (stack underflow)", 0x0a, 0x00
    err_mult_operands:      db "ERROR: '%s' needs %d operands (stack underflow)", 0x0a, 0x00
    division_by_0_err:      db "ERROR: '%s' caused a 'division by zero'", 0x0a, 0x00
    print_empty_stack:      db "- Attempt to print empty stack, inside function: [%s] -", 0x0a, 0x00
    empty_ptr_err:          db "ERROR: '%s' can't dereference null ptr", 0x0a, 0x00

    start_str:              db "_start:", 0x00

    disp_graph_fwd_link:    db "index:[%d] fwd:[%p] weight:[%p]", 0x0a, 0x00
    disp_graph_back_link:   db "index:[%d] back:[%p]", 0x0a, 0x00
    link_capacity_fwd:      db "fwd link size: [%d]", 0x0a, 0x00
    link_capacity_back:     db "back link size: [%d]", 0x0a, 0x00
    edge_node_not_found:    db "Error: unable to locate graph node: [%s], please check this!", 0x0a, 0x00
    no_edge_between_nodes:  db "Error: no edge found between [%s] ---> [%s] in graph!", 0x0a, 0x00
    node_already_exist:     db "Error: node [%s] already exists in graph!", 0x0a, 0x00
    edge_already_exist_err: db "Error: edge already exists between [%s] ---> [%s]!", 0x0a, 0x00

    expectedPtrToFree:  db "** ERROR! EXPECTED *ptr to FREE! **", 0x0a, 0x00

    base_ptr_title:     db 0x0a, "-----------***** DISPLAY BASE POINTER *****-----------", 0x0a, 0x00
    base_ptr_footer:    db "-----------***** END BASE POINTER *****-----------", 0x0a, 0x0a, 0x00
    dump_base_ptrs:     db "base pointer mem_loc [%p] holds address ---> [%p] holds value ---> [%p]", 0x0a, 0x00

    testNL:             db "", 0x0a, 0x00
    intOut:             db "the int is [%lld]", 0x0a, 0x00

    debugCharSameLine:  db "[%c]", 0x00
    debugInsertPos:     db "** MAX NUMBER of tokens is: [%d], so MAX insert pos is < this", 0x0a, 0x0a, 0x00

    debugSourceFile:    db "** SOURCE FILE: [%s] **", 0x0a, 0x00
    debugStatus:        db "** SWITCHING DEBUG MODE ON **", 0x0a, 0x00
    parsingStr:         db "Reading this file to parse ---> [%s]", 0x0a, 0x00
    parsingStrClean:    db "Updated file (comments removed) to parse ---> [%s]", 0x0a, 0x00
    strCleanHeader:     db "Updated file (comments removed):", 0x09, 0x00

    hexHeader:          db "String as HEX bytes:", 0x0a, 0x00
    hexOut:             db "[%02hhx]", 0x00
    ovectorDebug:       db "** DEBUG ovector pair total match#[%d] match#[%d] index#[%d]: %d <-- start/end --> %d **", 0x0a, 0x00

    commentsRemoved:    db "comment bytes being removed are:", 0x0a, 0x00
    notAStruct:         db "ERROR! Variable is not a struct: [%s]", 0x0a, 0x00
    fileOpenErr:        db "ERROR! can't open the file: [%s], does it exist?", 0x0a, 0x00

    argvSize:           db "tokens in argv is: [%d]", 0x0a, 0x00

    cleaningFuncs:      db "*** CLEANING FUNCTIONS ***", 0x0a, 0x00
    cleaningARGV:       db "*** CLEANING ARGV ***", 0x0a, 0x00
    cleaningGlobVars:   db "*** CLEANING GLOBAL VARS ***", 0x0a, 0x00

    indexMemLoc:        db "index: [%d] memory location: [%p] value: [%s]", 0x0a, 0x00
    no_start_in_code:   db "** MISSING _start: IN CODE!! **", 0x0a, 0x00

    freeingMem:         db "freeing this function id: [%s] [%p]", 0x0a, 0x00            ; for FUNCTIONS
    freeingMemGlobal:   db "freeing this memory global var: [%s] [%p]", 0x0a, 0x00      ; for GLOBAL vars
    freeingMem3:        db "freeing this argv_ptr token index: [%d], memory location: [%p]", 0x0a, 0x00 ; for argv_ptr, NEVER use %s, due to casting!!
    freeingMemLocal:    db "freeing this memory local var: [%s] [%p]", 0x0a, 0x00       ; for LOCAL vars

    stringOut2:         db "rts index [%02d] ---> [%s]", 0x0a, 0x00
    intOut2:            db "rts index [%02d] ---> [%lld]", 0x0a, 0x00
    ptrOut2:            db "rts index [%02d] ---> [%p]", 0x0a, 0x00

    funcDebug:          db "function name: [%s] and index: [%d]", 0x0a, 0x00
    debug_hashset:      db "__DEBUG__ hashset for OPERATORS __DEBUG__", 0x0a, 0x00
    debug_hashData:     db "index[%d]   node_address --> [%p]   op_name -->[%s] *next_ptr --> [%p]      func_lookup --> [%d]", 0x0a, 0x00
    debug_hashEmpty:    db "index[%d]   node_address --> [%p]", 0x0a, 0x00

    disp_title_hashset: db "--------[START]_DUMP_USER_%s_(capacity: [%d] # of nodes: [%d])-------v", 0x0a, 0x00
    disp_user_hashset:  db "index[%02d]   node_address --> [%p]  hash_key --> [%s]  hash_val --> [%p]   *next_ptr --> [%p]", 0x0a, 0x00
    disp_foot_hashset:  db "^-----------------------[END]_DUMP_USER_%s_--------------------------", 0x0a, 0x00

    graph_heading:      db "GRAPH", 0x00
    hash_heading:       db "HASHSET", 0x00

    dealloc_hashset:    db "__DEBUG__ 1st deallocate all nodes in hashset for OPERATORS __DEBUG__", 0x0a, 0x00
    dealloc_hashData:   db "** FREE MEMORY ** index[%d] node_address --> [%p]   op_name -->[%s] *next_ptr --> [%p]    func_lookup --> [%d]", 0x0a, 0x00
    dealloc_empty:      db "** IGNORE NULL ** index[%d] node_address --> [%p]", 0x0a, 0x00
    dealloc_hash_arr:   db "** FREE WHOLE HASHSET MEMORY ** deallocated entire hashset for OPERATORS --> [%p]", 0x0a, 0x00

    error_missing_quote_msg:    db "** ERROR, MISSING END QUOTE, NOT FOUND IN SOURCE FILE!! [%s] ** ", 0x0a, 0x00
    disp_token_type_operator:   db " ** token_type[%d] is OPERATOR & calls [map_funcs + %hhu * 0x08] --> [%s]", 0x0a, 0x00
    disp_token_type_operand:    db " ** token_type[%d] is OPERAND & token GROUP [%hhu] --> [%p], token TYPE: [%hhu]", 0x0a, 0x00
    error_brace_not_located:    db "**** ERROR! source code brace '{' at index [%lld] needs a matching brace in curly_brace_table!! ****", 0x0a, 0x00

    need_to_set_up_ptrs:        db "** ERROR! bp_0, bp_1...bp_07 aren't set up, call 'push_bp' before using them! **", 0x0a, 0x00
    empty_stack_err_bp_n:       db "** ERROR! Unable to call 'push_bp' on an empty stack! **", 0x0a, 0x00

    indexMemLocPtr:         db "index: [%d] memory location: [%p] value: [%p]", 0x0a, 0x00

    dumpCurlyBracesTitle:   db "***** DUMPING CURLY BRACES MAPPINGS *****", 0x0a, 0x00
    dispayMatchedBrace:     db "curly brace '{' at [%d] maps with '}' at [%d]", 0x0a, 0x00
    dispayMatchedBraceElse: db "curly brace '{' at [%d] maps with '}' at [%d] and else '}{' at [%d]", 0x0a, 0x00

    newLine:                db 0x0a, 0x00
    intFMT:                 db "%lld", 0x0a, 0x00
    strFMT:                 db "%s", 0x0a, 0x00
    ptrFMT:                 db "%p", 0x0a, 0x00
    charFMTnnl:             db "%c", 0x00
    floatFMT:               db "%.15f", 0x0a, 0x00

    tab2:                   db 0x09, 0x00
    bytesMalloc:            db "for argv_ptr we malloc'd this many bytes: [%d]", 0x0a, 0x00

    dict_header:            db 0x0a, "------------- [START] of dictionary dump -----------v", 0x0a, 0x00
    dictFMTs:               db "[%02d] ---> name : [%s] | value : [%s] | type : [str]", 0x0a, 0x00
    dictFMTi:               db "[%02d] ---> name : [%s] | value : [%d] | type : [int]", 0x0a, 0x00
    dictFMTf:               db "[%02d] ---> name : [%s] | value : [%.15f] | type : [float]", 0x0a, 0x00
    dictFMTstrct:           db "[%02d] ---> name : [%s] | &address : [%p] | # of elements : [%d] | type : [struct *ptr]", 0x0a, 0x00
    dict_ended:             db "^------------ [END] of dictionary dump ------------", 0x0a, 0x0a, 0x00

    ptrOut:                 db "ptr ---> [%p]", 0x0a, 0x00
    hashset_expanded:       db "** HASHSET EXPANDED FROM [%d] ----> [%d] # NODES [%d] **", 0x0a, 0x00
    replace_subst_str_err:  db "** ERROR, NULL search string for search/replace. string:[%s] search:[%s] replace:[%s]", 0x0a, 0x00

    missingSpeech:          db "ERROR : missing end speech mark in source code", 0x0a, 0x00
    varExistsError:         db "ERROR : variable already exists ---> [%s]", 0x0a, 0x00
    varExistsError2:        db "ERROR : variable doesn't exist ---> [%s]", 0x0a, 0x00
    funcError:              db "ERROR : function doesn't exist ---> [%s]", 0x0a, 0x00
    funcError2:             db "ERROR : function already exists ---> [%s]", 0x0a, 0x00
    numberIsBad:            db "ERROR : this number is > 19 digits!?!", 0x0a, 0x00
    fileCreateError:        db "ERROR : file desc open/already used, close it before creating a file!", 0x0a, 0x00

    dump_rts_string:        db " rts index [%02d] is a string ----> [%s]", 0x0a, 0x00
    dump_rts_struct:        db " rts index [%02d] is a struct ----> [%p]", 0x0a, 0x00
    dump_rts_float:         db " rts index [%02d] is a float  ----> [%.15f]", 0x0a, 0x00
    dump_rts_int:           db " rts index [%02d] is an int   ----> [%lld]", 0x0a, 0x00

    debug_dump_rts_start:   db 0x0a, "-------- [START] of run_time_stack dump ------v", 0x0a, 0x00
    debug_dump_rts_ended:   db "^------- [END] of run_time_stack dump -------", 0x0a, 0x0a, 0x00

    defaultSourceFile:      db "prog.ech", 0x00     ; ech = echelon!
    dashes2:                db "------------------------------------------------------", 0x0a, 0x00

    inputFile:              db "-f", 0x00
    debugCheck:             db "-d", 0x00
    regexCheck:             db "-b", 0x00

    argcStr:                db "argc", 0x00
    argvStr:                db "argv", 0x00
    ;------------------------------------
    ; the operators below are in random order. adding a new operartor is easy
    ; read the document: docs/developer/adding_a_new_operator.md
    ;-----------------------------------
    operator_00:    db "pop", 0x00
    operator_01:    db "dump_i", 0x00
    operator_02:    db "dump_str", 0x00
    operator_03:    db "int", 0x00
    operator_04:    db "clear", 0x00
    operator_05:    db "print_i", 0x00
    operator_06:    db "print_str", 0x00
    operator_07:    db "+", 0x00
    operator_08:    db "-", 0x00
    operator_09:    db "*", 0x00
    operator_10:    db "/", 0x00
    operator_11:    db "swap", 0x00
    operator_12:    db "dup", 0x00
    operator_13:    db "dup_n", 0x00
    operator_14:    db "++", 0x00
    operator_15:    db "--", 0x00
    operator_16:    db "rev", 0x00
    operator_17:    db "clear_above", 0x00
    operator_18:    db "clear_below", 0x00
    operator_19:    db "shift_up", 0x00
    operator_20:    db "shift_down", 0x00
    operator_21:    db "def_i", 0x00
    operator_22:    db "def_str", 0x00
    operator_23:    db "dump_dict", 0x00
    operator_24:    db "peek", 0x00
    operator_25:    db "poke", 0x00
    operator_26:    db "{", 0x00
    operator_27:    db "<", 0x00
    operator_28:    db ">", 0x00
    operator_29:    db "==", 0x00
    operator_30:    db "!=", 0x00
    operator_31:    db "<=", 0x00
    operator_32:    db ">=", 0x00
    operator_33:    db "read_i", 0x00
    operator_34:    db "read_str", 0x00
    operator_35:    db "call_func", 0x00
    operator_36:    db "&&", 0x00
    operator_37:    db "||", 0x00
    operator_38:    db "!", 0x00
    operator_39:    db "dump_rts", 0x00
    operator_40:    db "shift_up_n", 0x00
    operator_41:    db "shift_down_n", 0x00
    operator_42:    db "stack_size", 0x00
    operator_43:    db "swap_top_n", 0x00
    operator_44:    db "swap_bottom_n", 0x00
    operator_45:    db "true_false", 0x00
    operator_46:    db "cmp_str", 0x00
    operator_47:    db "len_str", 0x00
    operator_48:    db "add_str", 0x00
    operator_49:    db "cpy_str", 0x00
    operator_50:    db "upd_str", 0x00
    operator_51:    db "create_struct", 0x00
    operator_52:    db "def_struct", 0x00
    operator_53:    db "add_hash", 0x00
    operator_54:    db "dump_hashset", 0x00
    operator_55:    db "get_hash", 0x00
    operator_56:    db "del_hash", 0x00
    operator_57:    db "read_file", 0x00
    operator_58:    db "nl", 0x00
    operator_59:    db "split_str", 0x00        ; works with input file and string on rts
    operator_60:    db "rand", 0x00
    operator_61:    db "str", 0x00
    operator_62:    db "open_file", 0x00
    operator_63:    db "str_to_file", 0x00
    operator_64:    db "close_file", 0x00
    operator_65:    db "write_nl", 0x00
    operator_66:    db "write_bin", 0x00
    operator_67:    db "pop_free", 0x00
    operator_68:    db "print_ptr", 0x00
    operator_69:    db "struct_size", 0x00
    operator_70:    db "hex_str", 0x00
    operator_71:    db "swap_pos", 0x00
    operator_72:    db "value_at", 0x00
    operator_73:    db "sub_str", 0x00
    operator_74:    db "smash_str", 0x00
    operator_75:    db "[peek_8]", 0x00     ; char_at/byte_at
    operator_76:    db "[poke_8]", 0x00     ; upd_byte
    operator_77:    db "~", 0x00            ; bitwise NOT
    operator_78:    db "|", 0x00            ; bitwise OR
    operator_79:    db "&", 0x00            ; bitwise AND
    operator_80:    db "^", 0x00            ; bitwise XOR
    operator_81:    db "<<", 0x00           ; bitwise SHL
    operator_82:    db ">>", 0x00           ; bitwise SHR
    operator_83:    db "write_bin_ptr", 0x00
    operator_84:    db "mem_alloc", 0x00
    operator_85:    db "copy_bytes", 0x00
    operator_86:    db "stack_to_mem", 0x00
    operator_87:    db "hex_mem_n", 0x00
    operator_88:    db "get_stack_addr", 0x00
    operator_89:    db "[peek_16]", 0x00    ; word_at
    operator_90:    db "[peek_32]", 0x00    ; dword_at
    operator_91:    db "[peek_64]", 0x00    ; qword_at
    operator_92:    db "[poke_16]", 0x00    ; upd_word
    operator_93:    db "[poke_32]", 0x00    ; upd_dword
    operator_94:    db "[poke_64]", 0x00    ; upd_qword
    operator_95:    db "rand_str", 0x00
    operator_96:    db "file_size", 0x00
    operator_97:    db "bytes_to_file", 0x00
    operator_98:    db "sleep", 0x00
    operator_99:    db "epoch", 0x00
    operator_100:   db "sys_call", 0x00
    operator_101:   db "printf_p", 0x00
    operator_102:   db "printf", 0x00
    operator_103:   db "sprintf_p", 0x00
    operator_104:   db "sprintf", 0x00
    operator_105:   db "puts_p", 0x00
    operator_106:   db "puts", 0x00
    operator_107:   db "&[var_addr]", 0x00
    operator_108:   db "dump_ptr", 0x00
    operator_109:   db "smash_str_ascii", 0x00
    operator_110:   db "fflush", 0x00
    operator_111:   db "push_bp", 0x00
    operator_112:   db "get_bp", 0x00
    operator_113:   db "pop_bp", 0x00
    operator_114:   db "dump_bp", 0x00
    operator_115:   db "[value_at]", 0x00
    operator_116:   db "float", 0x00
    operator_117:   db "printf_f", 0x00
    operator_118:   db "i_float", 0x00
    operator_119:   db "+f", 0x00
    operator_120:   db "-f", 0x00
    operator_121:   db "*f", 0x00
    operator_122:   db "/f", 0x00
    operator_123:   db "sqrt", 0x00
    operator_124:   db "def_f", 0x00
    operator_125:   db "==f", 0x00
    operator_126:   db "!=f", 0x00
    operator_127:   db "<f", 0x00
    operator_128:   db ">f", 0x00
    operator_129:   db "<=f", 0x00
    operator_130:   db ">=f", 0x00
    operator_131:   db "++f", 0x00
    operator_132:   db "--f", 0x00
    operator_133:   db "read_f", 0x00
    operator_134:   db "printf_fp", 0x00
    operator_135:   db "qsort", 0x00
    operator_136:   db "min", 0x00
    operator_137:   db "max", 0x00
    operator_138:   db "abs", 0x00
    operator_139:   db "%", 0x00
    operator_140:   db "sin", 0x00
    operator_141:   db "cos", 0x00
    operator_142:   db "tan", 0x00
    operator_143:   db "pow", 0x00  ; 143 = 8f
    ;----------------------------------
    ;acos, asin, atan, atan2, exp, exp2, expm1, log, log2, log10, log1p, fabs,
    ;fmin, fmax, floor, ceil, round, trunc, sinh, cosh, tanh, hypot, fma
    ;----------------------------------
    operator_144:   db "acos", 0x00
    operator_145:   db "asin", 0x00
    operator_146:   db "atan", 0x00
    operator_147:   db "atan2", 0x00
    operator_148:   db "exp", 0x00
    operator_149:   db "exp2", 0x00
    operator_150:   db "expm1", 0x00
    operator_151:   db "log", 0x00
    operator_152:   db "log2", 0x00
    operator_153:   db "log10", 0x00
    operator_154:   db "log1p", 0x00
    operator_155:   db "fabs", 0x00
    operator_156:   db "fmin", 0x00
    operator_157:   db "fmax", 0x00
    operator_158:   db "floor", 0x00
    operator_159:   db "ceil", 0x00
    operator_160:   db "round", 0x00
    operator_161:   db "trunc", 0x00
    operator_162:   db "sinh", 0x00
    operator_163:   db "cosh", 0x00
    operator_164:   db "tanh", 0x00
    operator_165:   db "hypot", 0x00
    operator_166:   db "fma", 0x00
    operator_167:   db "print_fl", 0x00
    operator_168:   db "fill_mem", 0x00
    operator_169:   db "regex", 0x00
    operator_170:   db "regex_mult", 0x00
    operator_171:   db "regex_sub", 0x00
    operator_172:   db "get_env_ptr", 0x00
    operator_173:   db "get_env", 0x00
    operator_174:   db "set_env", 0x00
    operator_175:   db "exit", 0x00
    operator_176:   db "=", 0x00
    operator_177:   db "+=", 0x00
    operator_178:   db "-=", 0x00
    operator_179:   db "*=", 0x00
    operator_180:   db "/=", 0x00
    operator_181:   db "+=f", 0x00
    operator_182:   db "-=f", 0x00
    operator_183:   db "*=f", 0x00
    operator_184:   db "/=f", 0x00
    operator_185:   db "dup_args", 0x00
    operator_186:   db "new_hash", 0x00
    operator_187:   db "del_hashset", 0x00
    operator_188:   db "clear_hashset", 0x00
    operator_189:   db "hex_int", 0x00
    operator_190:   db "split_str_delim", 0x00
    operator_191:   db "get_lines", 0x00
    operator_192:   db "bp_0", 0x00
    operator_193:   db "[bp_0]", 0x00
    operator_194:   db "bp_1", 0x00
    operator_195:   db "[bp_1]", 0x00
    operator_196:   db "bp_2", 0x00
    operator_197:   db "[bp_2]", 0x00
    operator_198:   db "bp_3", 0x00
    operator_199:   db "[bp_3]", 0x00
    operator_200:   db "bp_4", 0x00
    operator_201:   db "[bp_4]", 0x00
    operator_202:   db "bp_5", 0x00
    operator_203:   db "[bp_5]", 0x00
    operator_204:   db "trim_str", 0x00
    operator_205:   db "replace_str", 0x00
    operator_206:   db "join_str", 0x00
    operator_207:   db "hex_to_ip", 0x00
    operator_208:   db "is_even", 0x00
    operator_209:   db "is_odd", 0x00
    operator_210:   db "index_str", 0x00
    operator_211:   db "to_upper", 0x00
    operator_212:   db "to_lower", 0x00
    operator_213:   db "starts_with", 0x00
    operator_214:   db "ends_with", 0x00
    operator_215:   db "cmp_str_i", 0x00
    operator_216:   db "hcf", 0x00
    operator_217:   db "lcm", 0x00
    operator_218:   db "hex_to_ip_port", 0x00
    operator_219:   db "is_prime", 0x00
    operator_220:   db "ip_port_to_int", 0x00
    operator_221:   db "open_file_app", 0x00
    operator_222:   db "write_64b_num", 0x00
    operator_223:   db "del_regex", 0x00
    operator_224:   db "del_str_set", 0x00
    operator_225:   db "fl_int", 0x00
    operator_226:   db "xor", 0x00
    operator_227:   db "pop_n", 0x00
    operator_228:   db "pop_free_n", 0x00
    operator_229:   db "str_int", 0x00
    operator_230:   db "add_hash_fix", 0x00
    operator_231:   db "hash_exists", 0x00
    operator_232:   db "cmp_str_u", 0x00
    operator_233:   db "<i>", 0x00
    operator_234:   db "<f>", 0x00
    operator_235:   db "create_graph", 0x00
    operator_236:   db "graph_add_node", 0x00
    operator_237:   db "delete_graph", 0x00
    operator_238:   db "dump_graph", 0x00
    operator_239:   db "graph_add_edge", 0x00
    operator_240:   db "graph_del_edge", 0x00
    operator_241:   db "graph_del_node", 0x00
    operator_242:   db "graph_get_back_links", 0x00
    operator_243:   db "graph_get_fwd_links", 0x00
    operator_244:   db "graph_get_fwd_weight_links", 0x00
    operator_245:   db "graph_node_exists", 0x00
    operator_246:   db "graph_edge_exists", 0x00
    operator_247:   db "graph_get_weight", 0x00
    operator_248:   db "graph_set_weight", 0x00
    operator_249:   db "graph_get_weight_ptr", 0x00
    operator_250:   db "graph_add_edge_weight", 0x00
    operator_251:   db "graph_get_fwd_count", 0x00
    operator_252:   db "graph_get_back_count", 0x00
    operator_253:   db "graph_node_count", 0x00
    operator_254:   db "graph_edge_count", 0x00
    operator_255:   db "graph_get_nodes", 0x00
    operator_256:   db "bp_6", 0x00
    operator_257:   db "bp_7", 0x00
    operator_258:   db "[bp_6]", 0x00
    operator_259:   db "[bp_7]", 0x00
    operator_260:   db "->>", 0x00          ; SAR signed
    operator_261:   db "[peek_8s]", 0x00    ; signed byte
    operator_262:   db "[peek_16s]", 0x00   ; signed word
    operator_263:   db "[peek_32s]", 0x00   ; signed dword
    operator_264:   db "pop_bp_clear", 0x00
    operator_265:   db "rand_str_batch", 0x00
    operator_266:   db "func_name", 0x00
    ;----------------------------------         ; IGNORE THESE DUMMY OPERATORS FROM HERE
    operator_267:   db "_start:", 0x00
    operator_268:   db "func:", 0x00
    operator_269:   db "break", 0x00
    operator_270:   db "return", 0x00
    operator_271:   db "}", 0x00
    operator_272:   db "if", 0x00
    operator_273:   db "loop", 0x00
    operator_274:   db "break_cond_if", 0x00
    operator_275:   db "break_if", 0x00
    operator_276:   db "}else{", 0x00

    all_ops: dq  operator_00, operator_01, operator_02, operator_03, operator_04, operator_05, operator_06, operator_07, operator_08, operator_09, operator_10, operator_11, operator_12, operator_13, operator_14, operator_15, operator_16, operator_17, operator_18, operator_19, operator_20, operator_21, operator_22, operator_23, operator_24, operator_25, operator_26, operator_27, operator_28, operator_29, operator_30, operator_31, operator_32, operator_33, operator_34, operator_35, operator_36, operator_37, operator_38, operator_39, operator_40, operator_41, operator_42, operator_43, operator_44, operator_45, operator_46, operator_47, operator_48, operator_49, operator_50, operator_51, operator_52, operator_53, operator_54, operator_55, operator_56, operator_57, operator_58, operator_59, operator_60, operator_61, operator_62, operator_63, operator_64, operator_65, operator_66, operator_67, operator_68, operator_69, operator_70, operator_71, operator_72, operator_73, operator_74, operator_75, operator_76, operator_77, operator_78, operator_79, operator_80, operator_81, operator_82, operator_83, operator_84, operator_85, operator_86, operator_87, operator_88, operator_89, operator_90, operator_91, operator_92, operator_93, operator_94, operator_95, operator_96, operator_97, operator_98, operator_99, operator_100, operator_101, operator_102, operator_103, operator_104, operator_105, operator_106, operator_107, operator_108, operator_109, operator_110, operator_111, operator_112, operator_113, operator_114, operator_115, operator_116, operator_117, operator_118, operator_119, operator_120, operator_121, operator_122, operator_123, operator_124, operator_125, operator_126, operator_127, operator_128, operator_129, operator_130, operator_131, operator_132, operator_133, operator_134, operator_135, operator_136, operator_137, operator_138, operator_139, operator_140, operator_141, operator_142, operator_143, operator_144, operator_145, operator_146, operator_147, operator_148, operator_149, operator_150, operator_151, operator_152, operator_153, operator_154, operator_155, operator_156, operator_157, operator_158, operator_159, operator_160, operator_161, operator_162, operator_163, operator_164, operator_165, operator_166, operator_167, operator_168, operator_169, operator_170, operator_171, operator_172, operator_173, operator_174, operator_175, operator_176, operator_177, operator_178, operator_179, operator_180, operator_181, operator_182, operator_183, operator_184, operator_185, operator_186, operator_187, operator_188, operator_189, operator_190, operator_191, operator_192, operator_193, operator_194, operator_195, operator_196, operator_197, operator_198, operator_199, operator_200, operator_201, operator_202, operator_203, operator_204, operator_205, operator_206, operator_207, operator_208, operator_209, operator_210, operator_211, operator_212, operator_213, operator_214, operator_215, operator_216, operator_217, operator_218, operator_219, operator_220, operator_221, operator_222, operator_223, operator_224, operator_225, operator_226, operator_227, operator_228, operator_229, operator_230, operator_231, operator_232, operator_233, operator_234, operator_235, operator_236, operator_237, operator_238, operator_239, operator_240, operator_241, operator_242, operator_243, operator_244, operator_245, operator_246, operator_247, operator_248, operator_249, operator_250, operator_251, operator_252, operator_253, operator_254, operator_255, operator_256, operator_257, operator_258, operator_259, operator_260, operator_261, operator_262, operator_263, operator_264, operator_265, operator_266, operator_267, operator_268, operator_269, operator_270, operator_271, operator_272, operator_273, operator_274, operator_275, operator_276, NULL

    map_funcs:  dq pop_off, dump_i, dump_str, deref_str_to_int, clear_stack, print_top_i, print_top_str, add_int, sub_int, mult_int, div_int, swap_top, dup_top, dup_top_n, inc_int, dec_int, rev_stack, clr_above, clr_below, shift_forward, shift_backwards, define_i, define_str, dump_dictionary, peek_var, poke_var, if_loop_func, less_than, more_than, equal_to, not_equal_to, less_than_or_equal_to, more_than_or_equal_to, reading_i, reading_str, call_function, and_operator, or_operator, not_operator, dump_rts_all, shift_forward_top_N, shift_backwards_top_N, the_stack_size, swap_the_top_n, swap_the_bottom_n, tern_func, str_compare, my_str_len, append_str, copy_str, update_str, packed_data, define_struct, add_node_hashset, dump_user_hashset, get_node_hashset, delete_node_hashset, open_user_file, print_nl, split_string, rand_int, cast_int_to_str, open_file_trunc, write_to_file, close_file_write, write_NL_file, write_bin_num, pop_off_free, print_top_ptr, get_struct_sz, hex_string, swap_positions, value_at_index, sub_string, smash_str_up, get_char_from_ptr, update_byte, bitwise_not, bitwise_or, bitwise_and, bitwise_xor, bitwise_shl, bitwise_shr, write_bin_num_ptr, malloc_bytes, copy_these_bytes, heap_update, hex_string_n, get_stack_address, get_word_from_ptr, get_dword_from_ptr, get_qword_from_ptr, update_word, update_dword, update_qword, random_string, get_file_byte_size, write_bytes_file, sleeping, get_epoch, syscall_handler, my_printf_pop, my_printf, my_sprintf_pop, my_sprintf, my_puts_pop, my_puts, address_var, dump_rts_ptr, smash_str_to_ascii, fflush_op, set_base_ptr, get_base_ptr, del_base_ptr, dump_base_pointer_tab, value_at_index_upd, deref_str_to_float, printf_float, int_to_float, add_float, sub_float, mult_float, div_float, square_root, define_f, float_equal, float_not_equal, float_less_than, float_more_than, float_less_than_eq, float_more_than_eq, inc_float, dec_float, reading_f, printf_float_pop, q_sort_op, min_op, max_op, abs_op, mod_op, sinf_op, cosf_op, tanf_op, powf_op, acos_op, asin_op, atan_op, atan2_op, exp_op, exp2_op, expm1_op, log_op, log2_op, log10_op, log1p_op, fabs_op, fmin_op, fmax_op, floor_op, ceil_op, round_op, trunc_op, sinh_op, cosh_op, tanh_op, hypot_op, fma_op, print_single_float, fill_memory, regex_match, regex_multiple, regex_substitute, get_the_envptr, get_env_var, set_env_var, exit_func, poke_var, poke_var_add, poke_var_sub, poke_var_mul, poke_var_div, poke_var_add_float, poke_var_sub_float, poke_var_mul_float, poke_var_div_float, duplicate_args, create_user_hashset, delete_user_hashset, clear_user_hashset, string_hex_to_int, split_string_delims, get_all_lines, get_bp_0, set_bp_0, get_bp_1, set_bp_1, get_bp_2, set_bp_2, get_bp_3, set_bp_3, get_bp_4, set_bp_4, get_bp_5, set_bp_5, trim_string, replace_subst_str, join_string, conv_hex_to_ip, is_even_tos, is_odd_tos, find_str_index, str_to_upper, str_to_lower, starts_with_str, ends_with_str, str_compare_i, the_high_common_factor, lowest_comm_mult, conv_hex_to_ip_port, check_is_prime, string_to_sockaddr, open_file_append, write_8_bytes, delete_regex_multi, delete_string_set, float_to_int, xor_int, pop_off_n, pop_off_free_n, string_to_int, add_node_hashset_fixed, hashset_node_exists, str_compare_u, three_way_op_int, three_way_op_float, create_user_hashset, add_graph_node, delete_user_graph, dump_user_graph, add_graph_edge, delete_graph_edge, delete_graph_node, get_graph_back_links, get_graph_fwd_links, get_graph_fwd_links_weights, does_graph_node_exist, does_graph_edge_exist, get_graph_weight, set_graph_weight, get_graph_weight_ptr, add_graph_edge_weight, count_fwd_links, count_back_links, total_node_count, total_edge_fwd_graph_count, grab_all_graph_nodes, get_bp_6, get_bp_7, set_bp_6, set_bp_7, bitwise_sar, get_char_from_ptr_signed, get_word_from_ptr_signed, get_dword_from_ptr_signed, del_base_ptr_clear, rand_string_batch, ret_func_name, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, dummy_func, NULL

    FLOAT_0NE:              dq  1.0

    OP_SIZE:                equ 0x115   ; total # of operators inc dummy ones
    operator_KEYWORD:       equ 0x10b   ; all operators are < this number

    start_KEYWORD:          equ 0x10b   ; "_start:",0x00
    func_KEYWORD:           equ 0x10c   ; "func:",0x00
    break_KEYWORD:          equ 0x10d   ; "break",0x00
    return_KEYWORD:         equ 0x10e   ; "return",0x00
    close_brace_KEYWORD:    equ 0x10f   ; "}",0x00
    if_KEYWORD:             equ 0x110   ; "if",0x00
    loop_KEYWORD:           equ 0x111   ; "loop",0x00
    break_cond_if_KEYWORD:  equ 0x112   ; "break_cond",0x00
    break_if_KEYWORD:       equ 0x113   ; "break_if",0x00
    if_else_brace_KEYWORD:  equ 0x114   ; "}else{",0x00

    operand_KEYWORD:        equ 0xff00  ; ALL operands are marked as this value
    open_brace_KEYWORD:     equ 0x1a    ; "{", 0x00

    MAX_READ_STR_SIZE:      equ 0x100   ; 256 bytes for read string
    MAX_HASH_SET:           equ 0x200   ; 512 approx OP_SIZE * 0x03
    NULL:                   equ 0x00

    NEW_LINE:               equ 0x0a    ; ascii 10
    A_TAB:                  equ 0x09    ; ascii 09
    A_SPACE:                equ 0x20    ; ascii 32
    V_TAB:                  equ 0x0b    ; ascii 11

    DELIMS:                 db  A_SPACE, NEW_LINE, A_TAB, V_TAB, NULL
    DELIMS_SIZE:            equ 0x04    ; 4 = space, tab, NL & null_byte

    SEEK_END:               equ 0x02 ; 2
    SYS_READ:               equ 0x00 ; 0
    SYS_WRITE:              equ 0x01 ; 1
    SYS_OPEN:               equ 0x02 ; 2
    SYS_CLOSE:              equ 0x03 ; 2
    SYS_FSTAT:              equ 0x05 ; 8
    SYS_LSEEK:              equ 0x08 ; 8
    SYS_EXIT:               equ 0x3c ; 60
    SYS_NANOSLEEP:          equ 0x23 ; 35

    comment:                equ 0x3b    ; hex for ';'
    newline:                equ 0x0a    ; hex for '\n'
    speechQuote:            equ 0x22    ; hex for '"'
    tab:                    equ 0x09    ; hex for '\t'
    backSlash:              equ 0x5c    ; hex for '\'


section .data                           ; nano-sleep expects *ptr to 2 * qwords,
    struc timespec                      ; so lets use this struct to make it easier for us
        .seconds            resq 0x01
        .nano_seconds       resq 0x01
    endstruc

    timeStructure:              ; make instance of timespec struct
        istruc  timespec
        iend

    regexSize:              dq  0x40000     ; default 256K, use command line param -b to change this


section .bss

    file_desc:              resq 0x01
    heap_alloc_file:        resq 0x01
    size_of_file:           resq 0x01
    argv_ptr:               resq 0x01
    argv_len:               resq 0x01
    INS_POS:                resq 0x01

    rts:                    resq 0x400  ; 1024 X 8 bytes
    rts_tos:                resq 0x01

    dict:                   resq 0x400
    dict_tos:               resq 0x01

    func_name:              resq 0x400
    func_name_tos:          resq 0x01

    funcs:                  resq 0x400
    funcs_tos:              resq 0x01

    local_dict:             resq 0xff
    local_dict_tos:         resq 0x01

    base_ptr:               resq 0xff
    base_ptr_tos:           resq 0x01

    last_glob_var:          resq 0x01
    break_flag:             resq 0x01

    malloc_str:             resq 0x01
    write_fd:               resq 0x01

    debug_mode:             resq 0x01   ; just a flag

    argc_passed:            resq 0x01
    argv_passed:            resq 0x01
    envp_passed:            resq 0x01

    f_byte_size:            resq 0x01
    source_file:            resq 0x01   ; source read from here

    op_hashset:             resq 0x01   ; main hashset allocated and accessed here

    token_type:             resq 0x01   ; strcmps & casts = too slow, try usin this
    curly_brace_table:      resq 0x01   ; speeds up matching '{' with '}'

    member_offset:          resq 0x01
    member_type_index:      resq 0x01
    asc_or_desc:            resq 0x01

    lcg_state:              resq 0x01
    err_code:               resq 0x01
    err_off:                resq 0x01
    p_code:                 resq 0x01
    p_mdata:                resq 0x01

    out_length:             resq 0x01
    regex_1st_run:          resq 0x01
    regex_num_match:        resq 0x01
    regex_heap_strings:     resq 0x01

    regex_offsets:          resq 0x01
    rts_position:           resq 0x01

    index_0:                resq 0x01
    index_1:                resq 0x01

    regex_num_match_all:    resq 0x01
    exit_status:            resq 0x01
    temp_linked_list:       resq 0x01

    base_ptr_0:             resq 0x01
    base_ptr_1:             resq 0x01
    base_ptr_2:             resq 0x01
    base_ptr_3:             resq 0x01
    base_ptr_4:             resq 0x01
    base_ptr_5:             resq 0x01
    base_ptr_6:             resq 0x01
    base_ptr_7:             resq 0x01

    START_INDEX:            resq 0x01

    delim_table:            resb 0x80
    ascii_esc_table:        resb 0x80
    err_buffer:             resb 0xff

section .text

main:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     [argc_passed], rdi
    mov     [argv_passed], rsi
    mov     [envp_passed], rdx
    ;-----------------------
    mov     rsi, defaultSourceFile      ; use default source unless we pass one with -f
    mov     qword [source_file], rsi
    ;-----------------------              passed parameter?
    cmp     rdi, 0x01
    je      .startReading               ; no params passed, so start
    ;-----------------------              debug mode and source file?
    call    init_debug_and_input_file
    ;-----------------------
    cmp     qword [debug_mode], NULL
    je      .startReading
    printLine   debugSourceFile, [source_file]
    .startReading:
    ;-----------------------              opens file
    mov     rdi, [source_file]          ; defaultSourceFile
    mov     rax, SYS_OPEN
    xor     rsi, rsi                    ; read only
    syscall
    ;-----------------------
    test    rax, rax
    jns     .getByteSize                ; jmp if -ve sign flag is NOT set
    ;-----------------------
    printLine   fileOpenErr, [source_file]      ; source file not found!
    jmp     exit
    ;-----------------------
    .getByteSize:                       ; gets byteSize of valid file
    mov     [file_desc], rax
    mov     rdi, rax
    call    file_byte_size
    ;-----------------------              opens file
    inc     rax                         ; to allow for \0
    mov     [size_of_file], rax
    ;-----------------------              allocate heap
    mov     rdi, rax
    call_libc malloc
    mov     [heap_alloc_file], rax
    ;-----------------------              reset file desc
    mov     rdi, [file_desc]
    xor     rsi, rsi
    xor     rdx, rdx
    mov     rax, SYS_LSEEK
    syscall
    ;-----------------------              copy file contents to heap
    mov     rdi, [file_desc]
    mov     rsi, [heap_alloc_file]
    mov     rdx, [size_of_file]
    dec     rdx
    mov     rax, SYS_READ
    syscall
    ;-----------------------              add \0 to str
    mov     r8, [heap_alloc_file]
    mov     r9, [size_of_file]
    dec     r9
    add     r8, r9
    mov     byte [r8], NULL
    ;----------------------------------
    setup_table:
    mov     byte [ascii_esc_table + 0x61], 0x07     ; '\a' (bell)
    mov     byte [ascii_esc_table + 0x62], 0x08     ; '\b' (backspace)
    mov     byte [ascii_esc_table + 0x74], 0x09     ; '\t' (horiz tab)
    mov     byte [ascii_esc_table + 0x6e], 0x0a     ; '\n' (new line)
    mov     byte [ascii_esc_table + 0x76], 0x0b     ; '\v' (vert tab)
    mov     byte [ascii_esc_table + 0x66], 0x0c     ; '\f' (form feed)
    mov     byte [ascii_esc_table + 0x72], 0x0d     ; '\r' (carriage ret)
    ;mov    byte [ascii_esc_table + 0x22], 0x22     ; '\"' --> '"' ; leave for now, fix another time
    mov     byte [ascii_esc_table + 0x5c], 0x5c     ; '\\' --> '\'
    ;----------------------------------
    setup_delim_table:
    mov     byte [delim_table + 0x00], 0x01         ; NULL
    mov     byte [delim_table + 0x09], 0x01         ; '\t' horiz tab
    mov     byte [delim_table + 0x0a], 0x01         ; '\n' new line
    mov     byte [delim_table + 0x0b], 0x01         ; '\v' vert tab
    mov     byte [delim_table + 0x0d], 0x01         ; '\r'
    mov     byte [delim_table + 0x20], 0x01         ; ' '  a space
    ;----------------------------------
    cmp     qword [debug_mode], NULL
    je      .removeComments
    ;----------------------------------
    printLine dashes2
    printLine parsingStr, [heap_alloc_file]
    printLine dashes2
    ;----------------------------------
    .removeComments:
    call    strip_out_comments      ; remove all comments, every single ';' until '\n' or EOF
    cmp     qword [debug_mode], NULL
    je      .tokenLen
    ;----------------------------------
    printLine dashes2
    printLine parsingStrClean, [heap_alloc_file]
    printLine dashes2
    printLine strCleanHeader
    ;----------------------------------
    mov      rdi, [heap_alloc_file]
    call     hex_dump_str
    printLine dashes2
    ;----------------------------------
    .tokenLen:
    call    find_tokens_len
    inc     qword[argv_len]
    cmp     qword [debug_mode], NULL
    je      .mallocPart
    ;----------------------------------
    printLine dashes2
    printLine argvSize, [argv_len]
    printLine dashes2
    ;----------------------------------
    .mallocPart:
    mov     rdi, [argv_len]
    shl     rdi, 0x03               ; * 8 for 8 bytes
    call_libc malloc
    mov     [argv_ptr], rax
    ;----------------------------------
    mov     rdi, rax
    mov     rdx, [argv_len]
    call    null_out_heap           ; null whole [argv_ptr] with NULL's
    ;----------------------------------
    cmp     qword [debug_mode], NULL
    je      .splitTok
    call    dump_tokens             ; added for debug
    ;----------------------------------
    .splitTok:
    call    split_tokens
    ;---------------------------------- to begin with all *_tos pointers, point -8 bytes BELOW their stack
    lea     rsi, [rts - 0x08]           ; below rts[0] = empty
    mov     [rts_tos], rsi
    ;-----------------------
    lea     rsi, [dict - 0x08]          ; below dict[0] = empty
    mov     [dict_tos], rsi
    ;-----------------------
    lea     rsi, [func_name - 0x08]     ; below func_name[0] = empty
    mov     [func_name_tos], rsi
    ;-----------------------
    lea     rsi, [funcs - 0x08]         ; below funcs[0] = empty
    mov     [funcs_tos], rsi
    ;-----------------------
    lea     rsi, [local_dict - 0x08]    ; below local_dict[0] = empty
    mov     [local_dict_tos], rsi
    ;-----------------------
    lea     rsi, [base_ptr - 0x08]      ; below base_ptr[0] = empty
    mov     [base_ptr_tos], rsi
    ;-----------------------
    cmp     qword [debug_mode], NULL
    je      .checkLen
    call    dump_tokens         ; added for debug
    ;-----------------------
    .checkLen:
    mov     rdi, [argv_ptr]
    call    check_argv_len
    ;-----------------------
    cmp     qword [debug_mode], NULL
    je      .createOperatorHash
    ;-----------------------
    printLine dashes2
    printLine argvSize, [argv_len]  ; added for debug
    printLine dashes2
    ;-----------------------
    .createOperatorHash:            ; make nodes of 18 bytes: 1st 8 bytes = operator name string
    ;----------------------------   ; 2nd 8 bytes = ptr to next node, last 2 bytes = index of matching function in map_funcs array
    mov     rdi, MAX_HASH_SET       ; hashset will be 3 * larger than # of operators
    shl     rdi, 0x03               ; multiply * 8 as we need to hold addresses of the nodes (8 bytes for each *ptr addr)
    ;----------------------------
    call_libc malloc
    mov     qword [op_hashset], rax
    call    create_operator_hashset       ; init hashset for operator look-ups in 'check_is_operator'
    ;----------------------------
    cmp     qword [debug_mode], NULL
    je      .funcList
    printLine   dashes2
    call    dump_operator_hashset
    printLine   dashes2
    call    check_hashset_ok
    ;----------------------------
    .funcList:
    ;mov     rdi, strTest; strTest2; operator_00; operator_01; operator_121; operator_122;
    ;call    check_is_operator
    ;----------------------------
    cmp     qword [debug_mode], NULL
    je      .token_type_set_up
    printLine   dashes2
    call    dump_func_list          ; added for debug
    ;-----------------------
    .token_type_set_up:
    call    init_token_type_mapping
    call    remove_casts_and_init_token_type
    ;-----------------------
    .createFuncs:
    call    create_func_list        ; init funcs and their start index for rip (r12)
    cmp     qword [debug_mode], NULL
    je      .initBraces
    printLine   dashes2
    call    dump_func_list          ; added for debug
    ;-----------------------
    .initBraces:
    mov     rdi, [argv_ptr]
    ;call   init_curly_braces
    call    create_and_init_curly_braces
    ;-----------------------                ; set random
    rdtsc
    shl      rdx, 0x20          ; shift high 32 bits
    or       rax, rdx           ; combine low 32 bits rax
    or       rax, 0x01          ; can never be 0
    mov      [lcg_state], rax
    ;-----------------------
    cmp     qword [debug_mode], NULL
    je      .argvStack
    printLine   dashes2
    call    dump_token_type_mapping
    call    dump_tokens_ptr
    printLine   dashes2
    ;-----------------------
    mov     rdi, [curly_brace_table]
    call    dump_curly_braces
    printLine   dashes2
    ;-----------------------
    .argvStack:
    call    init_argc_and_argv
    call    dealloc_operator_hashset    ; No longer needed, we have token_type array with direct mappings.
    call    argv_onto_stack             ; *MAIN LOOP HERE!* argv has the code, now use them in order on the rts
    ;-----------------------
    .clearMemEtc:
    call    deallocate_mem_tidy_up      ; code ended... now start freeing all allocations
    ;-----------------------
    .finish:
    jmp     exit


get_current_func_name:      ; sets r8 = func name we're currently in, could be added as an op??
    mov     r10, [func_name_tos]
    cmp     r10, func_name
    jl      .in_main_func
    ;-----------------------
    mov     r8, [r10]       ; get func name
    ret
    ;-----------------------
    .in_main_func:
    mov     r8, start_str   ; func must be _start: so pass that str
    ret

error_push_bp_empty_stack:
    printLine   empty_stack_err_bp_n
    jmp     exit_error_cleanly

error_stack_pts_not_set:
    printLine   need_to_set_up_ptrs
    jmp     exit_error_cleanly

error_need_valid_ptr:
    printLine   empty_ptr_err, rsi
    jmp     exit_error_cleanly

division_by_0:
    printLine   division_by_0_err, rsi
    jmp     exit_error_cleanly

error_need_1_operand:
    ;-----------------------v
    printLine   err_single_operand, rsi
    jmp     exit_error_cleanly

error_need_mult_operands:
    ;-----------------------
    printLine   err_mult_operands, rsi, rdx

exit_error_cleanly:
    ;-----------------------
    ;call   dump_direct_token_mapping_brief
    ;call   dump_func_list                  ; added for debug
    call    get_current_func_name
    printLine   debug_error_located, r8     ; display func name where error occured
    call    deallocate_mem_tidy_up
    jmp     exit

deallocate_mem_tidy_up:
    ;-----------------------
    call    clean_up_heap                   ; clean up function stack etc
    ;-----------------------
    mov     rdi, [token_type]
    call_libc free
    ;-----------------------
    mov     rdi, [curly_brace_table]
    call_libc free
    ;-----------------------
    mov     rdi, [argv_ptr]                 ; deallocate the qword's for argv
    call_libc free
    ;-----------------------
    mov     rdi, [heap_alloc_file]          ; deallocate the source code
    call_libc free
    ;-----------------------
    cmp     qword [write_fd], NULL          ; has write file desc been closed?
    je      .handle_file_desc
    ;-----------------------
    printLine fileCreateError
    .handle_file_desc:
    call    close_file_write                ; file desc needs closing
    ;-----------------------
    ret

copy_graph_data:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    ; rdi --> dest ptr
    ; rsi --> source ptr
    ; rcx --> # of 8 byte node ptr's to cpy
    ;-----------------------
    push    r13
    .loop_64_bytes:             ; grab original node data
        mov     rax, [rsi]
        mov     rdx, [rsi + 0x08]
        mov     r8,  [rsi + 0x10]
        mov     r9,  [rsi + 0x18]
        mov     r10, [rsi + 0x20]
        mov     r11, [rsi + 0x28]
        mov     r12, [rsi + 0x30]
        mov     r13, [rsi + 0x38]
        ;-----------------------
        mov     [rdi], rax      ; cpy across to new double heap
        mov     [rdi + 0x08], rdx
        mov     [rdi + 0x10], r8
        mov     [rdi + 0x18], r9
        mov     [rdi + 0x20], r10
        mov     [rdi + 0x28], r11
        mov     [rdi + 0x30], r12
        mov     [rdi + 0x38], r13
        ;-----------------------
        add     rsi, 0x40       ; +64 bytes
        add     rdi, 0x40       ; +64 bytes
        dec     rcx             ; dec block counter--
        jnz     .loop_64_bytes
    ;-----------------------
    .finished:
    pop     r13
    leave
    ret

add_graph_node:         ; [graph_struct, id (alphaNum), FLAG
    ;-----------------------
    mov     r13, [rts_tos]
    lea     r10, [rts + 0x10]           ; needs at least 3 items on stack
    cmp     r13, r10
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [r13 - 0x08]
    mov     rsi, [r13 - 0x10]
    call    find_node_graph
    test    rax, rax
    jnz     .node_already_in_graph
    ;----------------------- SPEC FOR GRAPH STRUCT 32 BYTES
    ;  [0] fwd_links
    ;  [8] back_links
    ; [16] size_fwd,       [20] size_back,
    ; [24] insert_pos_fwd, [28] insert_pos_back
    ;-----------------------
    mov     rdi, 0x20
    call_libc   malloc
    mov     rbx, rax                    ; array of fwd links, add these to the struct later.
    ;-----------------------            ; 8 bytes for fwd links & 8 bytes for it's weighting data (if needed?)
    mov     rdi, 0x80                   ; [0] *fwd_1 [8] weight_1 [0] *fwd_2 [16] weight_2 [24] ... (8 links = 8 * 16 bytes each)
    call_libc   malloc
    mov     [rbx], rax
    ;-----------------------
    mov     rdi, 0x40                   ; back links are only 8 bytes each, because no weights are needed!
    call_libc   malloc
    mov     [rbx + 0x08], rax
    ;-----------------------
    xor     r8, r8
    mov     [rbx + 0x18], r8            ; null out both index markers for back/fwd arrays
    mov     dword [rbx + 0x10], 0x08    ; start array size fwd links  = 8
    mov     dword [rbx + 0x14], 0x08    ; start array size back links = 8
    lea     r8, [r13 + 0x08]
    mov     r9, [r13]                   ; shift FLAG to top of stack
    mov     [r8], r9
    mov     [rts_tos], r8               ; fix top of stack *ptr
    mov     [r13], rbx                  ; push VALUE struct below top of stack
    ;-----------------------
    call    add_node_hashset            ; add this node into hashset
    xor     ebx, ebx
    ret
    ;-----------------------
    .node_already_in_graph:
    sub     qword [rts_tos], 0x18
    printLine   node_already_exist, [r13 - 0x08]
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_236
    jmp     error_need_mult_operands


grab_all_graph_nodes:           ; expects a 16 byte hashset datatype on top of stack.
    ;----------------------------
    mov     r15, [rts_tos]
    cmp     r15, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     rbx, [r15]
    test    rbx, rbx
    jz      .empty_hash_error
    ;----------------------------
    mov     rdi, 0x10                       ; alloc 16 bytes, 1st 8 byte = **ptr --> node ptrs
    call_libc malloc                        ; next 2nd 8 bytes = # of nodes
    mov     r13, rax
    mov     [r15], rax                      ; save this heap on top of stack
    ;----------------------------
    mov     dword esi, [rbx + 0x0c]
    mov     [r13 + 0x08], rsi               ; save # of nodes
    shl     rsi, 0x03                       ; * 8 (qwords)
    mov     rdi, rsi
    call_libc malloc
    mov     [r13], rax                      ; save main array of node ptrs at [0]
    ;----------------------------
    mov     dword r9d, [rbx + 0x08]         ; size of hashset
    mov     rsi, [rbx]                      ; 1st 8 bytes = *ptr to hashset
    xor     rbx, rbx                        ; counter
    xor     r11, r11                        ; insert pos for node ptrs
    ;----------------------------
    .looping:                               ; loop through, if empty ignore, if !empty then total += fwd_links
        cmp     rbx, r9                     ; counter < hashset size
        jge     .ended
        ;----------------------------
        cmp     qword [rsi + rbx * 0x08], NULL
        je      .nextHash
        ;----------------------------       ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                         ; not an empty slot
        mov     rcx, [rsi + rbx * 0x08]     ; r13 on the node, r14 points to next node
        mov     rdx, [rcx + 0x10]
        ;----------------------------
        .scanning:
            ;----------------------------
            mov     [rax + r11], rcx        ; get node ptr
            add     r11, 0x08
            ;----------------------------
            test    rdx, rdx                ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash               ; no more nodes attached, continue
            ;----------------------------
            mov     rcx, rdx
            mov     rdx, [rdx + 0x10]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ;----------------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rsi, operator_255
    jmp     error_need_1_operand
    ;----------------------------
    .empty_hash_error:
    mov     rsi, operator_255
    jmp     error_need_valid_ptr

total_edge_fwd_graph_count:         ; expects 16 byte hashset datatype on top of stack
    ;----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     r8, [rdi]
    test    r8, r8
    jz      .empty_hash_error
    ;----------------------------
    mov     r9d, [r8 + 0x08]                ; size of hashset
    mov     rsi, [r8]                       ; deref main *ptr, 1st 8 bytes = *ptr to hashset
    xor     rbx, rbx                        ; counter
    xor     rax, rax                        ; total fwd links
    ;----------------------------
    .looping:                               ; loop through, if empty ignore, if !empty then total += fwd_links
        cmp     rbx, r9                     ; counter < hashset size
        jge     .ended
        ;----------------------------
        cmp     qword [rsi + rbx * 0x08], NULL
        je      .nextHash
        ;----------------------------       ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                         ; not an empty slot
        mov     r13, [rsi + rbx * 0x08]     ; r13 on the node, r14 points to next node
        mov     r14, [r13 + 0x10]
        ;----------------------------
        .scanning:
            ;----------------------------
            mov     r12, [r13 + 0x08]       ; get value
            mov     dword r8d, [r12 + 0x18] ; insert index/pos fwd = num of
            add     rax, r8
            ;----------------------------
            test    r14, r14                ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash               ; no more nodes attached, continue
            ;----------------------------
            mov     r13, r14
            mov     r14, [r14 + 0x10]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     [rdi], rax                      ; push result on top of stack
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rsi, operator_254
    jmp     error_need_1_operand
    ;----------------------------
    .empty_hash_error:
    mov     rsi, operator_254
    jmp     error_need_valid_ptr


dump_user_graph:            ; expcts 16 byte hashset datatype on top of stack
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x10
    ;----------------------------
    mov     r15, [rts_tos]
    cmp     r15, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     r8, [r15]
    test    r8, r8
    jz      .empty_hash_error
    ;----------------------------
    sub     qword [rts_tos], 0x08
    ;----------------------------
    mov     r9d, [r8 + 0x08]
    mov     [rsp], r9                   ; 2nd 8 bytes = size of hashset
    ;----------------------------
    mov     r9d, [r8 + 0x0c]            ; # of nodes in hashset
    mov     r10, [r15]                  ; deref main *ptr
    mov     r15, [r10]                  ; 1st 8 bytes = *ptr to hashset
    xor     rbx, rbx                    ; counter
    ;----------------------------
    printLine   disp_title_hashset, graph_heading, [rsp], r9
    .looping:                       ; loop through, if empty ignore, if !empty then print node & all others linked to it
        cmp     rbx, [rsp]          ; MAX_HASH_SET
        jge     .ended
        ;----------------------------
        cmp     qword [r15 + rbx * 0x08], NULL
        jne     .nodeFound
        ;----------------------------
        jmp     .nextHash
        ;----------------------------       ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                         ; not an empty slot
        mov     r13, [r15 + rbx * 0x08]     ; r13 on the node, r14 points to next node
        mov     r14, [r13 + 0x10]
        ;----------------------------
        .scanning:
            ;----------------------------
            printLine   disp_user_hashset, rbx, r13, [r13], [r13 + 0x08], r14
            mov     r12, [r13 + 0x08]   ; get value
            mov     dword r8d, [r12 + 0x10]
            printLine   link_capacity_fwd, r8
            xor     rcx, rcx
            ;----------------------------
            .disp_array_fwd:
                cmp     dword ecx, [r12 + 0x18]
                je      .completed_fwd
                ;----------------------------
                push    rcx
                mov     r8, [r12]
                mov     r9, rcx
                mov     r10, rcx
                shl     r9, 0x04
                printLine   disp_graph_fwd_link, r10, [r8 + r9], [r8 + r9 + 0x08]
                pop     rcx
                ;----------------------------
                inc     rcx
                jmp     .disp_array_fwd
            ;----------------------------
            .completed_fwd:
            mov     dword r8d, [r12 + 0x14]
            printLine   link_capacity_back, r8
            xor     rcx, rcx
            ;----------------------------
            .disp_array_back:
                cmp     dword ecx, [r12 + 0x1c]
                je      .completed_back
                ;----------------------------
                push    rcx
                mov     r8, [r12 + 0x08]
                mov     r9, [r8 + rcx * 0x08]
                printLine   disp_graph_back_link, rcx, r9
                pop     rcx
                ;----------------------------
                inc     rcx
                jmp     .disp_array_back
            ;----------------------------
            .completed_back:
            printLine   dashes2
            test    r14, r14                ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash               ; no more nodes attached, cont with r15
            ;----------------------------
            .moveToNextNode:
            mov     r13, r14
            mov     r14, [r14 + 0x10]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ;----------------------------
    printLine disp_foot_hashset, graph_heading
    xor     ebx, ebx
    ;----------------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_238
    jmp     error_need_1_operand
    .empty_hash_error:
    mov     rsi, operator_238
    jmp     error_need_valid_ptr


add_graph_edge_weight:
    ;------------------------------------------------------
    ; create edge link between from_node --> to_node. [ptr_graph, to_node, from_node weight]
    ; fwd_link from_node --> to_node & set weight. back_link to_node --> from_node
    ;------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x18]
    cmp     r13, rsi
    jl      .prepare_for_error      ; need 4 items on stack
    ;-----------------------
    sub     qword [rts_tos], 0x08
    sub     rsp, 0x08
    mov     rdi, [r13]
    mov     [rsp], rdi              ; store weight before we pop off
    call    add_graph_edge          ; call func and update *ptr with weight if poss
    ;-----------------------
    test    r11, r11                ; returned from func, do we have *ptr weight or null/err??
    jz      .ended
    mov     rsi, [rsp]              ; push stored weight as edge value
    mov     [r11], rsi
    ;-----------------------
    .ended:
    leave
    ret
    ;----------------------------
    .prepare_for_error:             ; stack frame??
    mov     rdx, 0x04
    mov     rsi, operator_250
    jmp     error_need_mult_operands


add_graph_edge:
    ;------------------------------------------------------
    ; create edge link between from_node --> to_node. [ptr_graph, to_node, from_node]
    ; fwd_link from_node --> to_node. back_link to_node --> from_node
    ;------------------------------------------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     r13, rsi
    jl      .prepare_for_error      ; need 3 items on stack
    ;----------------------------
    mov     r13, [rts_tos]
    mov     rdi, [r13]              ; from_node
    mov     rsi, [r13 - 0x10]       ; *ptr to graph
    sub     qword [rts_tos], 0x18   ; pop off for now.
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; Did we find it?
    ;----------------------------
    jz      .err_node_not_found
    mov     r15, rax                ; save *ptr from_node
    ;----------------------------
    sub     r13, 0x08
    mov     rdi, [r13]              ; to_node
    mov     rsi, [r13 - 0x08]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_not_found
    mov     r13, rax                ; save *ptr to_node
    ;----------------------------   ; is there space in fwd_links?
    mov     r10, [r15 + 0x08]       ; get to VALUE
    mov     dword r8d, [r10 + 0x10] ; size of arr
    mov     dword r9d, [r10 + 0x18] ; next insert pos for this arr
    ;----------------------------   ; 1st check, do we already have an edge between these nodes?
    mov     rdi, r13
    mov     rsi, [r10]
    mov     rdx, 0x10               ; scan fwd links
    mov     rcx, r9
    call    scan_graph_array_for_node   ; rsi = array, rdi = search node, rcx = size (qwords). rdx = inc size (8/16), rax = result 0/1
    test    rax, rax
    jns     .edge_already_exists        ; An edge between nodes already exists
    ;----------------------------
    cmp     r9, r8
    jl      .fwd_has_enough_space
    ;----------------------------   ; Need to expnd array & update the stats
    mov     rbx, r10                ; ptr to fwd array
    mov     r14, r8                 ; need this value after we malloc
    mov     rdi, r8
    shl     rdi, 0x05               ; *2 (each index = 16 bytes)
    call_libc malloc
    ;----------------------------
    lea     rcx, [r14 * 0x02]       ; *2 because we need to cpy weightings too
    shr     rcx, 0x03
    mov     r14, rax                ; save new heap array *2
    mov     rdi, rax
    mov     rsi, [rbx]
    call    copy_graph_data         ; rdi --> dest ptr; rsi --> source ptr; rcx --> # of 8 byte node ptr's to cpy
    ;----------------------------
    mov     rdi, [rbx]
    call_libc free
    mov     [rbx], r14                  ; update fwd arr with new X2 array
    mov     r10, [r15 + 0x08]           ; get to VALUE
    shl     dword [r10 + 0x10], 0x01    ; double arr size
    ;----------------------------
    .fwd_has_enough_space:              ; now check back_link arr size in link_to node, enough space?
    mov     r10, [r13 + 0x08]           ; get to VALUE
    mov     dword r8d, [r10 + 0x14]     ; size of arr
    mov     dword r9d, [r10 + 0x1c]     ; next insert pos for this arr
    cmp     r9, r8
    jl      .ready_to_make_links
    ;----------------------------
    lea     rbx, [r10 + 0x08]       ; ptr to back array
    mov     r14, r8                 ; need this value after we malloc
    mov     rdi, r8
    shl     rdi, 0x04               ; *2 (each index = 8 bytes)
    call_libc malloc
    ;----------------------------
    mov     rcx, r14                ; just *ptrs to nodes, no weightings in back_links
    shr     rcx, 0x03
    mov     r14, rax                ; save new heap array *2
    mov     rdi, rax
    mov     rsi, [rbx]
    call    copy_graph_data         ; rdi --> dest ptr; rsi --> source ptr; rcx --> # of 8 byte node ptr's to cpy
    ;----------------------------
    mov     rdi, [rbx]
    call_libc free
    mov     [rbx], r14                  ; update fwd arr with new X2 array
    mov     r10, [r13 + 0x08]           ; get to VALUE
    shl     dword [r10 + 0x14], 0x01    ; double arr size
    ;----------------------------
    .ready_to_make_links:
    mov     rdi, [r15 + 0x08]           ; in VALUE
    mov     dword esi, [rdi + 0x18]     ; next insert slot
    shl     rsi, 0x04
    mov     r8, [rdi]
    mov     [r8 + rsi], r13
    xor     r9, r9
    ;mov    [r8 + rsi + 0x08], r9       ; *** WEIGHTING IS SET HERE! *** default = null out
    lea     r11, [r8 + rsi + 0x08]      ; null out **WEIGHTING** & set ptr now, maybe it's returnd to add_graph_edge_weight?
    mov     [r11], r9
    inc     dword [rdi + 0x18]
    ;----------------------------
    mov     rdi, [r13 + 0x08]           ; in VALUE
    mov     dword esi, [rdi + 0x1c]     ; next insert slot
    shl     rsi, 0x03
    mov     r8, [rdi + 0x08]
    mov     [r8 + rsi], r15
    inc     dword [rdi + 0x1c]
    .ended:
    ;----------------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .edge_already_exists:
    printLine   edge_already_exist_err, [r13], [r15]
    xor     r11, r11                        ; in case being called by add_graph_edge_weight, return null
    xor     ebx, ebx
    ret
    ;----------------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    xor     r11, r11                        ; used for err FLAG if being called by add_graph_edge_weight
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_239
    jmp     error_need_mult_operands


get_graph_weight:
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     r13, rsi
    jl      .prepare_for_error      ; need 3 items on stack
    ;----------------------------
    mov     rdi, [r13]              ; from_node
    mov     rsi, [r13 - 0x10]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_1_not_found
    mov     r15, rax                ; save *ptr from_node
    ;----------------------------
    sub     r13, 0x08
    mov     rdi, [r13]              ; to_node
    mov     rsi, [r13 - 0x08]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_2_not_found
    mov     rdi, rax                ; save *ptr to_node, needed for scan_graph_array_for_node
    ;----------------------------   ; Is there space in fwd_links?
    mov     r10, [r15 + 0x08]       ; get to VALUE
    mov     dword r8d, [r10 + 0x10] ; size of arr
    mov     dword r9d, [r10 + 0x18] ; next insert pos for this arr
    ;----------------------------   ; 1st check whether we have an existing edge between nodes?
    mov     rsi, [r10]
    mov     rdx, 0x10               ; scan fwd links
    mov     rcx, r9
    call    scan_graph_array_for_node
    test    rax, rax
    js      .no_link_exists         ; -1 = no link found
    ;-----------------------
    sub     r13, 0x08
    mov     [r13], rcx              ; push weight onto stack
    mov     [rts_tos], r13
    ;-----------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .no_link_exists:
    printLine   no_edge_between_nodes, [r15], [r13]
    sub     qword [rts_tos], 0x18
    xor     ebx, ebx
    ret
    ;----------------------------
    .err_node_1_not_found:
    sub     qword [rts_tos], 0x08
    .err_node_2_not_found:
    printLine   edge_node_not_found, [r13]
    sub     qword [rts_tos], 0x10
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_247
    jmp     error_need_mult_operands
    ret

get_graph_weight_ptr:
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     r13, rsi
    jl      .prepare_for_error      ; need 3 items on stack
    ;----------------------------
    mov     rdi, [r13]              ; from_node
    mov     rsi, [r13 - 0x10]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_1_not_found
    mov     r15, rax                ; save *ptr from_node
    ;----------------------------
    sub     r13, 0x08
    mov     rdi, [r13]              ; to_node
    mov     rsi, [r13 - 0x08]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_2_not_found
    mov     rdi, rax                ; save *ptr to_node, needed for scan_graph_array_for_node
    ;----------------------------   ; is there space in fwd_links?
    mov     r10, [r15 + 0x08]       ; get to VALUE
    mov     dword r8d, [r10 + 0x10] ; size of arr
    mov     dword r9d, [r10 + 0x18] ; next insert pos for this arr
    ;----------------------------   ; 1st check if we already have an edge between nodes?
    mov     rsi, [r10]
    mov     rdx, 0x10               ; scan fwd links
    mov     rcx, r9
    call    scan_graph_array_for_node
    test    rax, rax
    js      .no_link_exists         ; -1 = no link found
    ;-----------------------
    sub     r13, 0x08
    mov     [r13], rdx              ; push *ptr to weight onto stack
    mov     [rts_tos], r13
    ;-----------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .no_link_exists:
    printLine   no_edge_between_nodes, [r15], [r13]
    sub     qword [rts_tos], 0x18
    xor     ebx, ebx
    ret
    ;----------------------------
    .err_node_1_not_found:
    sub     qword [rts_tos], 0x08
    .err_node_2_not_found:
    printLine   edge_node_not_found, [r13]
    sub     qword [rts_tos], 0x10
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_249
    jmp     error_need_mult_operands
    ret

set_graph_weight:                   ; [graph, to_node, from_node, weight]
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x18]
    cmp     r13, rsi
    jl      .prepare_for_error      ; Need 4 items on stack
    ;----------------------------
    mov     rdi, [r13 - 0x08]       ; from_node
    mov     rsi, [r13 - 0x18]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_1_not_found
    mov     r15, rax                ; save *ptr from_node
    ;----------------------------
    mov     rdi, [r13 - 0x10]       ; to_node
    mov     rsi, [r13 - 0x18]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_2_not_found
    mov     rdi, rax                ; save *ptr to_node, needed for scan_graph_array_for_node
    ;----------------------------   ; is there space in fwd_links?
    mov     r10, [r15 + 0x08]       ; get to VALUE
    mov     dword r8d, [r10 + 0x10] ; size of arr
    mov     dword r9d, [r10 + 0x18] ; next insert pos for this arr
    ;----------------------------   ; 1st check if we already have an edge between nodes?
    mov     rsi, [r10]
    mov     rdx, 0x10               ; scan fwd links
    mov     rcx, r9
    call    scan_graph_array_for_node
    test    rax, rax
    js      .no_link_exists         ; -1 = no link found = can't add the weight
    ;-----------------------
    mov     rdi, [r13]              ; get weight
    mov     [rdx], rdi              ; deref *ptr update weight for this edge pair in fwd_link
    sub     qword [rts_tos], 0x20
    ;-----------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .no_link_exists:
    printLine   no_edge_between_nodes, [r13 - 0x10], [r13 - 0x08]
    sub     qword [rts_tos], 0x20
    xor     ebx, ebx
    ret
    ;----------------------------
    .err_node_1_not_found:
    mov     r8, [r13 - 0x08]
    jmp     .cont
    .err_node_2_not_found:
    mov     r8, [r13 - 0x10]
    .cont:
    printLine   edge_node_not_found, r8
    sub     qword [rts_tos], 0x20
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x04
    mov     rsi, operator_248
    jmp     error_need_mult_operands

does_graph_edge_exist:          ; top of stack = ptr to node or NULL if not found
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     r13, rsi
    jl      .prepare_for_error      ; need 3 items on stack
    ;----------------------------
    mov     rdi, [r13]              ; from_node
    mov     rsi, [r13 - 0x10]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_not_found
    mov     r15, rax                ; save *ptr from_node
    ;----------------------------
    sub     r13, 0x08
    mov     rdi, [r13]              ; to_node
    mov     rsi, [r13 - 0x08]       ; *ptr to graph
    ;----------------------------
    call    find_node_graph
    test    rax, rax                ; did we find it?
    ;----------------------------
    jz      .err_node_not_found
    mov     rdi, rax                ; save *ptr to_node, needed for scan_graph_array_for_node
    ;----------------------------   ; is there space in fwd_links?
    mov     r10, [r15 + 0x08]       ; Get to VALUE
    mov     dword r8d, [r10 + 0x10] ; size of arr
    mov     dword r9d, [r10 + 0x18] ; next insert pos for this arr
    ;----------------------------   ; 1st check, do we already have an edge between nodes?
    mov     rsi, [r10]
    mov     rdx, 0x10               ; scan fwd links
    mov     rcx, r9
    call    scan_graph_array_for_node
    test    rax, rax
    setns   al                      ; if sign FLAG (rax) is NOT set, al = 1, else al = 0
    movzx   esi, al                 ; zero out rest of bytes
    sub     r13, 0x08
    mov     [r13], rsi
    mov     [rts_tos], r13
    ;-----------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .err_node_not_found:            ; error and pop off all 3 operands on stack
    printLine   edge_node_not_found, [r13]
    mov     rdi, [rts_tos]
    sub     rdi, 0x10
    mov     qword [rdi], NULL
    mov     [rts_tos], rdi
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_246
    jmp     error_need_mult_operands

does_graph_node_exist:          ; [graph, search node_key] result = *ptr to node or NULL if not found
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]
    mov     rsi, [r13 - 0x08]
    sub     r13, 0x08
    mov     qword [rts_tos], r13
    ;-----------------------
    call    find_node_graph
    mov     [r13], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_245
    jmp     error_need_mult_operands

find_node_graph:        ; rdi = KEY (string) & rsi = graph
                        ; if found in graph *ptr to node returned on rax, else rax = NULL
    ;----------------------------
    mov     rbx, rsi                    ; save ptr to graph
    mov     r12, rdi                    ; save node KEY/string
    ;----------------------------
    mov     dword esi, [rsi + 0x08]     ; get SIZE of graph
    call    generate_str_checksum       ; returns checksum on rax
    ;----------------------------
    mov     rbx, [rbx]
    mov     r14, [rbx + rax * 0x08]     ; move to that slot
    ;----------------------------
    test    r14, r14                    ; An empty slot?
    jz      .keyNotFound
    ;----------------------------
    .looping:
        test    r14, r14                ; reached end of linked list?
        jz      .keyNotFound
        ;----------------------------
        mov     rdi, r12
        mov     rsi, [r14]
        call    my_str_cmp
        ;----------------------------
        test    rax, rax
        jnz     .carryOn
        ;----------------------------
        mov     rax, r14                ; return *ptr to node
        jmp     .finish
        ;----------------------------
        .carryOn:
        mov     r14, [r14 + 0x10]       ; set to next.next
        jmp     .looping
    ;----------------------------
    .keyNotFound:
    xor     rax, rax
    ;----------------------------
    .finish:
    ret

build_fwd_back_links_in_heap:
    ;----------------------------
    ; r15 = # of elements to copy (qwords)
    ; r14 = source array ptr (either back_links/fwd_links)
    ; rbx = FLAG = 0 if contiguous, or 1 if we're skip 8 bytes
    ; rsi = return the start of new heap for callin func
    ;----------------------------
    mov     rdi, 0x10
    call_libc malloc
    mov     r12, rax
    mov     [rax + 0x08], r15   ; save # of nodes at [8]
    ;----------------------------
    mov     rdi, r15
    shl     rdi, 0x03           ; * 8
    call_libc malloc            ; heap we add to and return
    ;----------------------------
    mov     [r12], rax          ; store results *ptr at [0]
    mov     rdi, rax            ; rdi = dest ptr
    mov     rsi, r12            ; rsi = save **ptr block, inc dest ptr/heap
    ;----------------------------
    test    rbx, rbx
    jnz     .skip_path          ; if FLAG != 0 then go to the skip 8 bytes cpy
    ;----------------------------
    .contiguous_path:
    cmp     r15, 0x08
    jl      .remainder_contiguous
    ;----------------------------
    .loop_64_bytes:             ; grab 64 bytes each iteration
        mov     rax, [r14]
        mov     rcx, [r14 + 0x08]
        mov     rdx, [r14 + 0x10]
        mov     r8,  [r14 + 0x18]
        mov     r9,  [r14 + 0x20]
        mov     r10, [r14 + 0x28]
        mov     r11, [r14 + 0x30]
        mov     r12, [r14 + 0x38]
        ;----------------------------; write 64 bytes
        mov     [rdi], rax
        mov     [rdi + 0x08], rcx
        mov     [rdi + 0x10], rdx
        mov     [rdi + 0x18], r8
        mov     [rdi + 0x20], r9
        mov     [rdi + 0x28], r10
        mov     [rdi + 0x30], r11
        mov     [rdi + 0x38], r12
        ;----------------------------    ; inc ptrs
        add     rdi, 0x40
        add     r14, 0x40
        sub     r15, 0x08
        cmp     r15, 0x08
        jge     .loop_64_bytes
    ;----------------------------
    .remainder_contiguous:
    test    r15, r15
    jz      .ended
    ;----------------------------
    .rem_cont_loop:
        mov     rax, [r14]          ; read source
        mov     [rdi], rax          ; write to heap
        add     r14, 0x08
        add     rdi, 0x08
        dec     r15
        jnz     .rem_cont_loop
        jmp     .ended
    ;----------------------------
    ; for skip path, still load 8 registers at once, but skip 8 bytes each time we grab data
    ; so offsets we read are every other QWORD [0], [2], [4] ...
    ;----------------------------
    .skip_path:
    cmp     r15, 0x08
    jl      .remainder_skip
    ;----------------------------
    .loop_skip_64_bytes:            ; same as before, grab 64 bytes each iteration
        mov     rax, [r14]
        mov     rcx, [r14 + 0x10]
        mov     rdx, [r14 + 0x20]
        mov     r8,  [r14 + 0x30]
        mov     r9,  [r14 + 0x40]
        mov     r10, [r14 + 0x50]
        mov     r11, [r14 + 0x60]
        mov     r12, [r14 + 0x70]
        ;----------------------------   ; write 64 bytes
        mov     [rdi], rax
        mov     [rdi + 0x08], rcx
        mov     [rdi + 0x10], rdx
        mov     [rdi + 0x18], r8
        mov     [rdi + 0x20], r9
        mov     [rdi + 0x28], r10
        mov     [rdi + 0x30], r11
        mov     [rdi + 0x38], r12
        ;----------------------------
        add     rdi, 0x40               ; dest += 64 bytes
        add     r14, 0x80               ; source ptr += 128 bytes
        sub     r15, 0x08
        cmp     r15, 0x08
        jge     .loop_skip_64_bytes
        ;----------------------------
    .remainder_skip:
    test    r15, r15
    jz      .ended
    ;----------------------------
    .rem_skip_loop:
        mov     rax, [r14]
        mov     [rdi], rax
        add     r14, 0x10           ; source ptr += 16 bytes (skip 1 qword)
        add     rdi, 0x08           ; dest ptr += 8
        ;----------------------------
        dec     r15
        jnz     .rem_skip_loop
    ;----------------------------
    .ended:
    ret

get_graph_fwd_links_weights:                ; return count value = each edge & pair as 2, NOT as a single pair.
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]                      ; node to delete
    mov     rsi, [r13 - 0x08]               ; graph
    call    find_node_graph
    ;-----------------------
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     rdi, rax
    mov     rsi, [rdi + 0x08]               ; get VALUE node
    mov     dword r15d, [rsi + 0x18]        ; get next ins pos (# of elements already in array)
    shl     r15, 0x01                       ; * 2 size because we're adding WEIGHTS too
    test    r15, r15
    jz      .empty_back_link
    ;-----------------------
    xor     ebx, ebx                        ; get the fwd nodes AND WEIGHTS!
    mov     r14, [rsi]                      ; ptr to fwd_links
    call    build_fwd_back_links_in_heap    ; r15 size, r14 = array
    sub     r13, 0x08
    mov     [r13], rsi                      ; put the block of nodes at top of stack
    mov     [rts_tos], r13
    jmp     .ended
    ;-----------------------
    .empty_back_link:
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     [r13], r15
    ;-----------------------
    .ended:
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     qword [r13], NULL
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_244
    jmp     error_need_mult_operands


get_graph_fwd_links:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]                      ; node to delete
    ;-----------------------
    mov     rsi, [r13 - 0x08]               ; graph
    call    find_node_graph
    ;-----------------------
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     rdi, rax
    mov     rsi, [rdi + 0x08]               ; get VALUE node
    mov     dword r15d, [rsi + 0x18]        ; get next ins pos (# of elemnts already in array)
    test    r15, r15
    jz      .empty_back_link
    ;-----------------------
    mov     rbx, 0x01                       ; just get the fwd nodes (NO WEIGHTS!)
    mov     r14, [rsi]                      ; ptr to fwd_links
    call    build_fwd_back_links_in_heap    ; r15 size, r14 = array
    sub     r13, 0x08
    mov     [r13], rsi                      ; put the block of nodes at top of stack
    mov     [rts_tos], r13
    jmp     .ended
    ;-----------------------
    .empty_back_link:
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     [r13], r15
    ;-----------------------
    .ended:
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     qword [r13], NULL
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_243
    jmp     error_need_mult_operands


get_graph_back_links:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]                      ; node to delete
    ;-----------------------
    mov     rsi, [r13 - 0x08]               ; graph
    call    find_node_graph
    ;-----------------------
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     rdi, rax
    mov     rsi, [rdi + 0x08]               ; get VALUE node
    mov     dword r15d, [rsi + 0x1c]        ; get next ins pos (# of elemnts already in array)
    test    r15, r15
    jz      .empty_back_link
    ;-----------------------
    xor     ebx, ebx
    mov     r14, [rsi + 0x08]               ; ptr to back_links
    call    build_fwd_back_links_in_heap    ; r15 size, r14 = array
    sub     r13, 0x08
    mov     [r13], rsi                      ; put the block of nodes at top of stack
    mov     [rts_tos], r13
    jmp     .ended
    ;-----------------------
    .empty_back_link:
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     [r13], r15                      ; push NULL on stack
    ;-----------------------
    .ended:
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     qword [r13], NULL
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_242
    jmp     error_need_mult_operands


delete_graph_node:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]                  ; Node/KEY selected for deletion
    ;-----------------------
    mov     rsi, [r13 - 0x08]           ; point to graph
    call    find_node_graph
    ;-----------------------
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     r12, rax                    ; node to delete
    mov     rsi, [r12 + 0x08]
    mov     r15, [rsi]                  ; fwd_arr
    mov     dword r14d, [rsi + 0x18]    ; fwd_link next ins position
    xor     rbx, rbx
    ;-----------------------
    .remove_links_fwd:
        cmp     ebx, r14d
        je      .deleted_fwd_links
        ;-----------------------
        mov     r10, rbx
        shl     r10, 0x04
        mov     rdi, [r15 + r10]        ; a node in the fwd list
        mov     r8, [rdi + 0x08]        ; Get to its VALUE
        mov     rsi, [r8 + 0x08]        ; get to its back_link
        mov     dword ecx, [r8 + 0x1c]  ; Next insert position, use as limit
        xor     r9, r9
        ;-----------------------
        .find_and_remove_node_fwd:          ; Scan the array & remove node (r12) frm their back link array.
            cmp     dword r9d, ecx
            je      .next_entry_check_fwd
            ;-----------------------
            cmp     [rsi + r9 * 0x08], r12
            jne     .next_index_check_fwd
            ;-----------------------
            dec     rcx
            mov     rdi, [rsi + rcx * 0x08]     ; Retrieve the last node entry
            mov     [rsi + r9 * 0x08], rdi      ; Now place it in the slot we're deleting
            dec     dword [r8 + 0x1c]           ; dec next ins position--
            jmp     .next_entry_check_fwd
            ;-----------------------
            .next_index_check_fwd:
            inc     r9
            jmp     .find_and_remove_node_fwd
        ;-----------------------
        .next_entry_check_fwd:
        inc     rbx
        jmp     .remove_links_fwd
    ;-----------------------
    .deleted_fwd_links:
    mov     rdi, r15
    call_libc free
    mov     rsi, [r12 + 0x08]
    mov     r15, [rsi + 0x08]           ; back arr
    mov     dword r14d, [rsi + 0x1c]    ; back_link next insert pos
    xor     rbx, rbx
    ;-----------------------
    .remove_links_back:
        cmp     ebx, r14d
        je      .deleted_back_links
        ;-----------------------
        mov     rdi, [r15 + rbx * 0x08] ; a node in the back array
        mov     r8, [rdi + 0x08]        ; get to its VALUE
        mov     rsi, [r8]               ; get to its fwd_link
        mov     dword ecx, [r8 + 0x18]  ; Next ins position, use this as the limit
        xor     r9, r9
        ;-----------------------
        .find_and_remove_node_back:         ; Scan array & remove node r12 frm their fwd link array
            cmp     dword r9d, ecx
            je      .next_entry_check_back
            ;-----------------------
            mov     r10, r9
            shl     r10, 0x04
            cmp     [rsi + r10], r12
            jne     .next_back_link_check
            ;-----------------------
            dec     rcx
            shl     rcx, 0x04
            mov     rdi, [rsi + rcx]            ; get last node entry
            mov     rdx, [rsi + rcx + 0x08]     ; get last node weight
            shl     r9, 0x04
            mov     [rsi + r9], rdi             ; and place it in the one we delete
            mov     [rsi + r9 + 0x08], rdx      ; and place it in the one we delete
            dec     dword [r8 + 0x18]           ; dec next ins pos--
            jmp     .next_entry_check_back
            ;-----------------------
            .next_back_link_check:
            inc     r9
            jmp     .find_and_remove_node_back
        ;-----------------------
        .next_entry_check_back:
        inc     rbx
        jmp     .remove_links_back

    .deleted_back_links:
    mov     rdi, r15
    call_libc free
    call    delete_node_hashset
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     [rts_tos], r13
    mov     qword [r13], NULL
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rsi, operator_241
    jmp     error_need_1_operand

delete_graph_edge:      ;[ptr_graph, to_node, from_node]
    ;-----------------------
    mov     r13, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     r13, rsi
    jl      .prepare_for_error
    ;-----------------------
    sub     qword [rts_tos], 0x18
    mov     rdi, [r13]          ; from_node
    ;-----------------------
    mov     rsi, [r13 - 0x10]   ; graph
    call    find_node_graph
    test    rax, rax
    jz      .err_node_not_found
    mov     r15, rax            ; store from_node
    ;----------------------------
    sub     r13, 0x08
    mov     rdi, [r13]          ; to_node
    mov     rsi, [r13 - 0x08]   ; graph
    call    find_node_graph
    test    rax, rax
    jz      .err_node_not_found
    ;----------------------------       ; valid nodes
    mov     r14, rax                    ; store to_node
    mov     rdi, r14                    ; find this node
    mov     r10, [r15 + 0x08]
    mov     rsi, [r10]                  ; get to fwd arr
    mov     rdx, 0x10                   ; size for fwd_links = 16
    mov     dword ecx, [r10 + 0x18]     ; next insert_pos (size of array = valgrind moaning)
    call    scan_graph_array_for_node
    test    rax, rax
    js      .no_link_exists             ; no link exists!
    ;----------------------------
    mov     rsi, [r10]
    shl     rax, 0x04
    lea     r9, [rsi + rax]                 ; ptr to node (edge) that requires deleting
    mov     dword r8d, [r10 + 0x18]         ; next_insert pos
    dec     r8
    shl     r8, 0x04
    mov     rdi, [rsi + r8]                 ; grab last edge to overwrite deleted edge
    mov     rdx, [rsi + r8 + 0x08]          ; grab last weight to overwrite deleted edge
    mov     [r9], rdi
    mov     [r9 + 0x08], rdx
    dec     dword [r10 + 0x18]              ; dec next_insert pos--
    ;----------------------------
    mov     rdi, r15                        ; find this node
    mov     r10, [r14 + 0x08]
    mov     rsi, [r10 + 0x08]               ; get to back arr
    mov     rdx, 0x08                       ; size for back_links = 8
    mov     dword ecx, [r10 + 0x1c]         ; next insert_pos (size of array = valgrind moaning)
    call    scan_graph_array_for_node
    test    rax, rax
    js      .no_link_exists                 ; no link exists!
    ;----------------------------           ; back links have NO weighting, so just insert last edge
    mov     rsi, [r10 + 0x08]
    lea     r9, [rsi + rax * 0x08]          ; ptr to node (edge) that needs deleting
    mov     dword r8d, [r10 + 0x1c]         ; next_insert pos
    dec     r8
    shl     r8, 0x03
    mov     rdi, [rsi + r8]                 ; grab last edge to overwrite deleted edge
    mov     [r9], rdi
    dec     dword [r10 + 0x1c]              ; dec next_insert pos--
    ;----------------------------
    .ended:
    xor     ebx, ebx
    ret
    ;----------------------------
    .no_link_exists:
    printLine   no_edge_between_nodes, [r15], [r14]
    xor     ebx, ebx
    ret
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    xor     ebx, ebx
    ret
    ;----------------------------
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_240
    jmp     error_need_mult_operands

scan_graph_array_for_node:  ; rsi = array, rdi = search node, rcx = size (qwords). rdx = inc size (8/16)
    xor rax, rax            ; rax = result, indx where node was found (weight & *ptr weight set) or -1 if not found
    ;----------------------------
    .scanning:
        cmp     rax, rcx
        je      .notFound
        cmp     [rsi], rdi
        je      .found      ; we have index in rax
        ;----------------------------
        add     rsi, rdx
        inc     rax
        jmp     .scanning
    ;----------------------------
    .notFound:
    mov     rax, -1             ; node not found rax = -1
    ret
    ;----------------------------
    .found:                     ; node was found, also set weight & ptr to weight
    mov     rcx, [rsi + 0x08]   ; pass weight
    lea     rdx, [rsi + 0x08]   ; pass *ptr to weight
    ret

total_node_count:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]              ; node
    ;-----------------------
    mov     dword r9d, [rdi + 0x0c]
    mov     [r13], r9               ; dword [+12 bytes] of hashset/graph = size of hashset/graph
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rsi, operator_253
    jmp     error_need_1_operand


count_fwd_links:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]              ; node
    ;-----------------------
    mov     rsi, [r13 - 0x08]       ; graph
    call    find_node_graph
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     rsi, [rax + 0x08]       ; *VALUE
    mov     dword edi, [rsi + 0x18] ; next ins pos of fwd_links
    sub     r13, 0x08
    mov     [r13], rdi
    mov     [rts_tos], r13
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     qword [r13], -1
    mov     [rts_tos], r13
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_251
    jmp     error_need_mult_operands

count_back_links:
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rdi, [r13]              ; node
    ;-----------------------
    mov     rsi, [r13 - 0x08]       ; graph
    call    find_node_graph
    test    rax, rax
    jz      .err_node_not_found
    ;-----------------------
    mov     rsi, [rax + 0x08]       ; *VALUE
    mov     dword edi, [rsi + 0x1c] ; next ins pos of back_links
    sub     r13, 0x08
    mov     [r13], rdi
    mov     [rts_tos], r13
    xor     ebx, ebx
    ret
    ;-----------------------
    .err_node_not_found:
    printLine   edge_node_not_found, [r13]
    sub     r13, 0x08
    mov     qword [r13], -1
    mov     [rts_tos], r13
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_252
    jmp     error_need_mult_operands


three_way_op_int:           ; cmp top 2 items, check if [<, ==, >] -->  [-1, 0, 1]
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     r12, [r13 - 0x08]
    cmp     r12, [r13]
    ;-----------------------
    setl    dl
    setg    al
    movzx   rax, al
    movzx   rdx, dl
    sub     rax, rdx
    ;-----------------------
    .ended:
    sub     r13, 0x08               ; pop off & push on result
    mov     qword [r13], rax
    mov     [rts_tos], r13
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_233
    jmp     error_need_mult_operands


three_way_op_float:         ; cmp top 2 items, check if [<, ==, >] -->  [-1, 0, 1]
    ;-----------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------
    movsd   xmm0, [r13 - 0x08]
    movsd   xmm1, [r13]
    comisd  xmm0, xmm1              ; cmp floats set flags
    ;-----------------------
    setb    dl                      ; set to -1 if 1st < 2nd
    seta    al                      ; set tp  1 if 1st > 2nd
    movzx   rax, al
    movzx   rdx, dl
    sub     rax, rdx                ; in case both cases failed (0-0 = 0)
    ;-----------------------
    .ended:
    sub     r13, 0x08               ; pop off & push on result
    mov     qword [r13], rax
    mov     [rts_tos], r13
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_234
    jmp     error_need_mult_operands


check_is_prime:             ; r14 = T/F result
    ;-----------------------
    mov     r12, [rts_tos]      ; r12 ptr to top of stack
    cmp     r12, rts
    jl      .prepare_for_error
    mov     r13, [r12]          ; r13 original val
    mov     r14, 0x01           ; default = true
    ; ;-----------------------
    cmp     r13, 0x02
    jl      .not_prime
    je      .ended              ; is prime
    ;-----------------------
    cmp     r13, 0x03
    je      .ended              ; is prime
    ;-----------------------
    test    r13, 0x01           ; is the 1st bit set to 0 = even?
    jz      .not_prime
    ;-----------------------
    xor     rdx, rdx
    mov     rax, r13
    mov     r8, 0x03
    div     r8
    test    rdx, rdx
    jz      .not_prime          ; / 3 == 0 ? = false
    ;-----------------------
    mov     rbx, 0x05           ; loop var
    ;-----------------------
    .looping:
        mov     rax, rbx
        mul     rbx
        ;-----------------------
        test    rdx, rdx        ; did square overflow 64 bits?
        jnz     .ended          ; is prime
        ;-----------------------
        cmp     rax, r13
        ja      .ended          ; is prime
        ;-----------------------
        xor     rdx, rdx
        mov     rax, r13
        div     rbx
        test    rdx, rdx
        jz      .not_prime
        ;-----------------------
        xor     rdx, rdx
        mov     rax, r13
        lea     r8, [rbx + 0x02]
        div     r8
        test    rdx, rdx
        jz      .not_prime
        ;-----------------------
        add     rbx, 0x06
        jmp     .looping
    ;-----------------------
    .not_prime:
    xor     r14, r14
    ;-----------------------
    .ended:
    mov     [r12], r14          ; replace top of stack with T/F
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_219
    jmp     error_need_1_operand

lowest_comm_mult:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     r12, [rdi]
    mov     r13, [rdi - 0x08]
    ;-----------------------        ; -ve broke previous version
    neg     r12
    cmovs   r12, [rdi]              ; r12 was positive? restore it
    neg     r13
    cmovs   r13, [rdi - 0x08]       ; r13 was positive? restore it
    ;-----------------------
    mov     r8, r12
    mov     r9, r13
    call    high_comm_fact
    mov     rbx, rax
    ;-----------------------
    mov     rcx, rax
    mov     rax, r12
    xor     rdx, rdx
    div     rcx
    ;-----------------------
    mul     r13
    ;-----------------------
    sub     rdi, 0x08
    mov     [rdi], rax
    mov     [rts_tos], rdi
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_217
    jmp     error_need_mult_operands

the_high_common_factor:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     r8, [rdi]
    mov     r9, [rdi - 0x08]
    ;-----------------------    ; -ve broke previous version
    neg     r8
    cmovs   r8, [rdi]
    neg     r9
    cmovs   r9, [rdi - 0x08]
    ;-----------------------
    call    high_comm_fact
    ;-----------------------
    sub     rdi, 0x08
    mov     [rdi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_216
    jmp     error_need_mult_operands


high_comm_fact:                 ; pass 1st num on r8, 2nd num on r9
    ;-----------------------
    test    r8, r8
    jnz     .test_r9
    ;-----------------------
    mov     rax, r9
    jmp     .ended
    ;-----------------------
    .test_r9:
    test    r9, r9
    jnz     .begin
    ;-----------------------
    mov     rax, r8
    jmp     .ended
    ;-----------------------
    .begin:
    xor     rcx, rcx        ; shift counter
    ;-----------------------
    .do_shifting:
        test    r8, 0x01
        jnz     .shift_first_num
        ;-----------------------
        test    r9, 0x01
        jnz     .shift_first_num
        ;-----------------------
        shr     r8, 0x01
        shr     r9, 0x01
        inc     rcx         ; shift counter ++
        jmp     .do_shifting
    ;-----------------------
    .shift_first_num:
        test    r8, 0x01
        jnz     .main_loop
        ;-----------------------
        shr     r8, 0x01
        jmp     .shift_first_num
    ;-----------------------
    .main_loop:
        test    r9, r9
        jz      .restore_factor
        ;-----------------------
        .shift_second_num:
            test    r9, 0x01
            jnz     .next_check
            ;-----------------------
            shr     r9, 0x01
            jmp     .shift_second_num
        ;-----------------------
        .next_check:
        cmp     r8, r9
        jng     .update_second
        ;-----------------------
        xchg    r8, r9
        .update_second:
        sub     r9, r8
        jmp     .main_loop
    ;-----------------------
    .restore_factor:
    mov     rax, r8
    shl     rax, cl
    ;-----------------------
    .ended:
    ret

string_hex_to_int:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    mov     rsi, [rdi]              ; get string on top of stack
    ;-----------------------
    call    hex_to_int
    mov     [rdi], rax
    xor     ebx, ebx
    ;-----------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_189
    jmp     error_need_1_operand

hex_to_int:         ; pass on rsi the hex string, rax = hex converted to int
    ;-----------------------
    xor     rax, rax                ; check for '0x' or '0X'
    cmp     word [rsi], 0x7830      ; '0x'
    je      .skip_prefix
    cmp     word [rsi], 0x5830      ; '0X'
    jne     .loop
    ;-----------------------
    .skip_prefix:
    add     rsi, 0x02
    ;-----------------------
    .loop:
        movzx   rdx, byte [rsi]     ; grab char
        inc     rsi
        test    dl, dl              ; check EOS null term
        jz      .finished
        ;-----------------------
        sub     dl, 0x30            ; ascii '0' is 0x30
        js      .finished           ; if < 0 it's invalid!!
        cmp     dl, 0x09
        jbe     .add_nibble         ; if 0-9, done
        ;-----------------------
        sub     dl, 0x11            ; 'A' 0x41 - 0x30 = 0x11. so now 'A' = 0
        js      .finished           ; char  > '9' &&  < 'A' = invalid!!
        cmp     dl, 0x06            ; in range 0-5 [A-F]?
        jb      .letter_found       ; is uppercase
        ;-----------------------    ; deal with [a-f]
        sub     dl, 0x20            ; 'a' - 0x20  = 'A'. so now 'a' = 0
        cmp     dl, 0x06            ; is in range 0-5 [a-f] ?
        jae     .finished           ; above 'f' = invalid!!
        ;-----------------------
        .letter_found:
        add     dl, 0x0a            ; make [0-5] --> 10-15 [0x0A-0x0F]
        ;-----------------------
        .add_nibble:                ; 1/2 byte segmnts..
        shl     rax, 0x04
        or      rax, rdx
        jmp     .loop
    ;-----------------------
    .finished:
    ret


set_bp_0:
    ;-----------------------
    mov     rsi, [base_ptr_0]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_1:
    ;-----------------------
    mov     rsi, [base_ptr_1]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_2:
    ;-----------------------
    mov     rsi, [base_ptr_2]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_3:
    ;-----------------------
    mov     rsi, [base_ptr_3]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_4:
    ;-----------------------
    mov     rsi, [base_ptr_4]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_5:
    ;-----------------------
    mov     rsi, [base_ptr_5]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

regex_substitute:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16    ; force 16-byte alignment
    sub     rsp, 0x30   ; 48 bytes locals *MUST BE A MULTIPLE OF 16 ELSE IT'LL CRASH!*
    ;---------------------------------------------------
    ; local vars:
    ; [rbp - 0x08]  replace_len
    ; [rbp - 0x10]  p_code      *removed globals frm .bss & put p_code/p_mdata here
    ; [rbp - 0x18]  p_mdata
    ; [rbp - 0x20]  out_length
    ; [rbp - 0x28]  string * (replace_len+1) +1 handles worst case scenario
    ;---------------------------------------------------
    xor     rax, rax
    mov     [rbp - 0x10], rax
    mov     [rbp - 0x18], rax
    ;---------------------------------------------------
    ; stack [string, search_pattern, replace]
    ;---------------------------------------------------
    mov     r14, [rts_tos]
    lea     r12, [r14 - 0x10]       ; get to string
    mov     r14, [r14]              ; r14 = replace string ptr
    sub     qword [rts_tos], 0x08   ; pop replace
    ;-----------------------
    mov     rdi, r14
    call    str_len
    mov     [rbp - 0x08], rax       ; replace length
    lea     r13, [rax + 0x01]
    ;-----------------------
    mov     rdi, [r12]              ; calc len of entire string
    call    str_len
    mov     r12, rax
    ;-----------------------
    imul    r13, r12            ; string * (replace_len + 1)
    inc     r13
    mov     [rbp - 0x28], r13
    ;-----------------------    ; COMPILE
    mov     rdi, [rts_tos]
    mov     rdi, [rdi]
    mov     rsi, -1
    xor     rdx, rdx
    lea     rcx, [err_code]
    lea     r8, [err_off]
    xor     r9, r9
    call    pcre2_compile_8
    ;-----------------------
    test    rax, rax
    jz      .error_compiling_regex
    mov     [rbp - 0x10], rax   ; p_code
    ;-----------------------    ; CREATE MATCH DATA
    mov     rdi, rax
    xor     rsi, rsi
    call    pcre2_match_data_create_from_pattern_8
    test    rax, rax
    ;-----------------------
    jz      .oom_match_data
    mov     [rbp - 0x18], rax   ; p_mdata
    ;-----------------------
    mov     rbx, [rts_tos]
    sub     rbx, 0x08
    mov     rbx, [rbx]          ; string ptr
    ;-----------------------
    mov     rdi, [rbp - 0x28]   ; <-- calc value instead of using glob REPLACE_STR_LEN
    call_libc malloc
    test    rax, rax
    jz      .oom_buffer
    mov     r13, rax
    ;-----------------------    ; CALL pcre2_substitute_8
    lea     rax, [rbp - 0x28]   ; set buffer length
    ;-----------------------------------------------------------
    ; 11 args: 6 in regs, 5 on stack + 1 dummy = 6 pushes NEEDED for alignment!
    ;-----------------------------------------------------------
    push    NULL                ; dummy alignment
    push    rax                 ; arg 11 --> &buffer_length
    push    r13                 ; arg 10 --> buffer
    push    qword [rbp - 0x08]  ; arg 9  --> rlength
    push    r14                 ; arg 8  --> replacement
    push    NULL                ; arg 7  --> mcontext
    ;-----------------------
    mov     rdi, [rbp - 0x10]   ; arg 1  --> p_code
    mov     rsi, rbx            ; arg 2  --> subject
    mov     rdx, -1             ; arg 3  --> length
    xor     rcx, rcx            ; arg 4  --> start_offset
    mov     r8d, 0x00000100     ; arg 5  --> PCRE2_SUBSTITUTE_GLOBAL
    mov     r9, [rbp - 0x18]    ; arg 6  --> p_mdata
    call    pcre2_substitute_8
    add     rsp, 0x30           ; clean up 6 pushes
    ;-----------------------
    test    eax, eax
    jl      .sub_error          ; negative --> error
    ;-----------------------------------
    ; pop search_pattern & overwrite string with result
    ;-----------------------------------
    sub     qword [rts_tos], 0x08  ; pop pattern. stack: [string] --> [result]
    mov     rdi, [rts_tos]
    mov     [rdi], r13          ; overwrite string slot with result
    jmp     .cleanup_success
    ;----------------------
    ; handle errors below
    ;----------------------
    .sub_error:
    mov     [err_code], eax     ; save pcre2's error code
    mov     rdi, r13
    call_libc free
    jmp     .cleanup_error
    ;-----------------------
    .oom_match_data:
    mov     rdi, [rbp - 0x10]
    call    pcre2_code_free_8
    sub     qword [rts_tos], 0x08
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2     ; push -2 (Out Of Mem error)
    jmp     .exit
    ;-----------------------
    .oom_buffer:
    mov     rdi, [rbp - 0x18]
    test    rdi, rdi
    jz      .skip_oom_mdata
    call    pcre2_match_data_free_8
    ;-----------------------
    .skip_oom_mdata:
    mov     rdi, [rbp - 0x10]
    test    rdi, rdi
    jz      .skip_oom_code
    call    pcre2_code_free_8
    .skip_oom_code:
    ;-----------------------
    sub     qword [rts_tos], 0x08
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2
    jmp     .exit
    ;-----------------------
    .cleanup_error:    ; stack --> [string, pattern] pass to regex_error_handler
    mov     rdi, [rbp - 0x18]
    test    rdi, rdi
    jz      .skip_mdata
    call    pcre2_match_data_free_8
    ;-----------------------
    .skip_mdata:
    mov     rdi, [rbp - 0x10]
    test    rdi, rdi
    jz      .skip_code_error
    call    pcre2_code_free_8
    ;-----------------------
    .skip_code_error:
    call    regex_error_handler
    jmp     .exit
    ;-----------------------
    .error_compiling_regex:
    call    regex_error_handler
    jmp     .exit
        ;-----------------------
    .cleanup_success:
    mov     rdi, [rbp - 0x18]
    call    pcre2_match_data_free_8
    mov     rdi, [rbp - 0x10]
    call    pcre2_code_free_8
    ;-----------------------
    .exit:
    xor     ebx, ebx
    leave
    ret


regex_multiple:
    push    rbp
    mov     rbp, rsp
    and     rsp, -16    ; force 16-byte alignment
    sub     rsp, 0x40   ; 64 bytes for local vars (*MUST BE MULTIPLE OF 16 ELSE IT'LL CRASH!*)
    ;----------------------------------------------------------------;
    ; [rbp - 0x08]  string ptr
    ; [rbp - 0x10]  p_code
    ; [rbp - 0x18]  p_mdata
    ; [rbp - 0x20]  regex_offsets (malloc buffer)
    ; [rbp - 0x28]  regex_heap_strings (malloc array of string ptrs)
    ; [rbp - 0x30]  regex_num_match
    ; [rbp - 0x38]  regex_num_match_all
    ; [rbp - 0x40]  regex_1st_run
    ;---------------------------------------------------------------;
    xor     rax, rax
    mov     [rbp - 0x10], rax
    mov     [rbp - 0x18], rax
    mov     [rbp - 0x20], rax
    mov     [rbp - 0x28], rax
    mov     [rbp - 0x30], rax
    mov     [rbp - 0x38], rax
    mov     [rbp - 0x40], rax
    ;-----------------------        ; COMPILE
    mov     rdi, [rts_tos]
    mov     rdi, [rdi]              ; pattern ptr
    mov     rsi, -1
    xor     rdx, rdx
    lea     rcx, [err_code]
    lea     r8,  [err_off]
    xor     r9, r9
    call    pcre2_compile_8
    ;-----------------------
    test    rax, rax
    jz      .error_compiling_regex
    mov     [rbp - 0x10], rax       ; p_code
    ;-----------------------        ; default 0x40000 (256K)
    mov     rdi, [regexSize]        ; mov   rdi, 0xffffffffffffff to force oom_offsets;

    call_libc malloc
    test    rax, rax
    ;-----------------------
    jz      .oom_offsets
    mov     [rbp - 0x20], rax
    ;-----------------------
    mov     r12, 0x10               ; start writing offsets after header
    ;-----------------------        ; CREATE MATCH DATA
    mov     rdi, [rbp - 0x10]
    xor     rsi, rsi
    call    pcre2_match_data_create_from_pattern_8
    test    rax, rax
    jz      .oom_match_data
    mov     [rbp - 0x18], rax       ; p_mdata
    ;-----------------------
    sub     qword [rts_tos], 0x08   ; pop pattern
    mov     rdi, [rts_tos]
    mov     rdi, [rdi]
    mov     [rbp - 0x08], rdi       ; save string ptr
    ;-----------------------
    xor     r15, r15                ; current offset
    .outer_loop:
        mov     rsi, [rbp - 0x08]   ; string ptr
        sub     rsp, 0x10           ; alignment padding
        mov     qword [rsp], NULL   ; arg 7 --> mcontext
        mov     rdi, [rbp - 0x10]   ; p_code
        mov     rdx, -1
        mov     rcx, r15            ; start offset
        xor     r8, r8              ; options
        mov     r9, [rbp - 0x18]    ; p_mdata
        call    pcre2_match_8
        add     rsp, 0x10           ; remove padding
        ;-----------------------              1st run init
        cmp     qword [rbp - 0x40], NULL
        jnz     .first_run_done
        inc     qword [rbp - 0x40]
        mov     rsi, [rbp - 0x20]
        mov     dword [rsi], eax              ; rc at [0]
        lea     r8, [rax - 0x01]
        mov     dword [rsi + 0x08], r8d       ; groups = rc-1 at [8]
        ;-----------------------
        .first_run_done:
        test    eax, eax
        js      .check_zero_matches
        ;-----------------------              ; process match
        mov     r13, rax                      ; match count
        inc     qword [rbp - 0x30]            ; regex_num_match++
        ;-----------------------
        mov     rdi, [rbp - 0x18]
        call    pcre2_get_ovector_pointer_8
        mov     r14, rax                      ; ovector ptr
        ;-----------------------
        xor     rcx, rcx                      ; group index
        .inner_group:
            cmp     rcx, r13
            jge     .next_outer
            ;-----------------------
            mov     rax, rcx
            shl     rax, 0x04
            mov     rsi, [r14 + rax]              ; start
            mov     rdx, [r14 + rax + 0x08]       ; end
            ;-----------------------              ; store offsets
            mov     r8, [rbp - 0x20]
            mov     dword [r8 + r12], esi         ; start
            mov     dword [r8 + r12 + 0x04], edx  ; end
            add     r12, 0x08
            ;-----------------------              ; NULL length? then skip
            sub     rdx, rsi
            test    rdx, rdx
            jz      .skip_group
            inc     qword [rbp - 0x38]            ; regex_num_match_all++
            ;-----------------------
            .skip_group:
            inc     rcx
            jmp     .inner_group
        ;-----------------------
        .next_outer:
        mov     rdi, [r14 + 0x08]                 ; end of whole match (group 0)
        cmp     rdi, r15
        jg      .update_pos
        mov     rdi, r15
        inc     rdi
        ;-----------------------
        .update_pos:
        mov     r15, rdi
        jmp     .outer_loop
        ;-----------------------          ; no more matches
    .check_zero_matches:
    cmp     qword [rbp - 0x38], NULL
    je      .push_on_null
    ;-----------------------              ; build result block
    mov     rdi, [rbp - 0x20]
    mov     eax, dword [rbp - 0x30]
    mov     dword [rdi + 0x04], eax       ; num matches at [4]
    mov     eax, dword [rbp - 0x38]
    mov     dword [rdi + 0x0c], eax       ; num groups at [12]
    ;-----------------------              ; allocate string ptr array
    mov     rdi, [rbp - 0x38]
    inc     rdi
    shl     rdi, 0x03                     ; force oom_string_array by: mov rdi, 0xffffffffffffff
    call_libc malloc
    ;-----------------------
    test    rax, rax
    jz      .oom_string_array
    mov     [rbp - 0x28], rax
    mov     [regex_heap_strings], rax     ; <--- SET GLOBAL FOR build_substrings
    ;-----------------------
    mov     rax, [rbp - 0x38]             ; regex_num_match_all
    mov     [regex_num_match_all], rax    ; set global, so builder knows number of strings to build
    mov     r13, [rbp - 0x20]             ; regex_offsets
    mov     r12, [rbp - 0x08]             ; string ptr
    call    build_substrings_from_str
    ;-----------------------               create outer main block for all data & strings
    mov     rdi, 0x10
    call_libc malloc
    ;-----------------------
    mov     r8, [rbp - 0x28]
    mov     [rax], r8               ; place **strings in [0]
    mov     r8, [rbp - 0x20]
    mov     [rax + 0x08], r8        ; place string/match data in [8]
    ;-----------------------
    mov     rdi, [rts_tos]
    mov     [rdi], rax
    jmp     .clean_up
    ;-----------------------
    .push_on_null:                  ; no matches
    mov     rdi, [rbp - 0x20]
    call_libc free
    mov     rdi, [rts_tos]
    mov     qword [rdi], NULL
    jmp     .clean_up
    ;------------------------
    ; handle errors form here
    ;------------------------
    .oom_offsets:
    mov     rdi, [rbp - 0x10]
    call    pcre2_code_free_8
    sub     qword [rts_tos], 0x08   ; pop pattern & overwrite string with error
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2
    jmp     .leaving
    ;-----------------------
    .oom_match_data:
    mov     rdi, [rbp - 0x20]
    call_libc free
    mov     rdi, [rbp - 0x10]
    call    pcre2_code_free_8
    sub     qword [rts_tos], 0x08   ; pop pattern & overwrite string with error
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2
    jmp     .leaving
    ;-----------------------
    .oom_string_array:
    mov     rdi, [rbp - 0x20]
    call_libc free
    ;-----------------------
    mov     rdi, [rbp - 0x18]       ; p_mdata
    test    rdi, rdi
    jz      .skip_oom_string_mdata
    call    pcre2_match_data_free_8
    ;-----------------------
    .skip_oom_string_mdata:
    mov     rdi, [rbp - 0x10]       ; p_code
    test    rdi, rdi
    jz      .skip_oom_string_code
    call    pcre2_code_free_8
    ;-----------------------
    .skip_oom_string_code:
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2
    jmp     .leaving
    ;-----------------------
    .error_compiling_regex:         ; stack [string, pattern] --> compilation failed
    call    regex_error_handler
    jmp     .leaving
    ;-----------------------
    .clean_up:
    mov     rdi, [rbp - 0x18]
    test    rdi, rdi
    jz      .skip_mdata
    call    pcre2_match_data_free_8
    ;-----------------------
    .skip_mdata:
    mov     rdi, [rbp - 0x10]
    test    rdi, rdi
    jz      .leaving
    call    pcre2_code_free_8
    ;-----------------------
    .leaving:
    xor     ebx, ebx
    leave
    ret


build_substrings_from_str:
    ;---------------------------------------------------
    ; builds heap strings for all matches found in regex_multiple
    ; uses globals set by the function
    ;   [regex_heap_strings]  = already allocated array of ptrs
    ;   [regex_num_match_all] = total number substrings build
    ;   r12                   = string ptr
    ;   r13                   = buffer wth start/end offsets (skipping header)
    ;---------------------------------------------------
    xor     rbx, rbx                    ; counter
    add     r13, 0x10                   ; skip 16-byte header (rc, matches, groups, total_matches)
    ;-----------------------
    .building_strings:
        cmp     rbx, [regex_num_match_all]
        jge     .add_NULL_qword
        ;-----------------------        ; calc length --> end - start
        mov     dword r14d, [r13 + rbx * 0x08 + 0x04]   ; end offset (upper 32 bits)
        sub     dword r14d, [r13 + rbx * 0x08]          ; start offset (lower 32 bits) --> r14 = length
        ;-----------------------        ; allocate heap for substring +1 for '\0'
        mov     rdi, r14
        inc     rdi                             ; +1 for '\0'
        call_libc malloc
        ;-----------------------
        mov     r15, rax                        ; save ptr to allocated string
        ;-----------------------                ; cpy substring
        mov     rdi, rax                        ; dest heap
        mov     esi, [r13 + rbx * 0x08]         ; start offset
        add     rsi, r12                        ; string ptr
        mov     rcx, r14
        rep     movsb                           ; copy rcx bytes
        ;-----------------------                ; add NULL-term
        mov     byte [r15 + r14], NULL
        mov     rdi, [regex_heap_strings]       ; store ptr into string array
        lea     rdi, [rdi + rbx * 0x08]         ; array[index]
        mov     [rdi], r15
        ;-----------------------
        inc     rbx
        jmp     .building_strings

    .add_NULL_qword:                           ; add NULL (END OF RECORDS) to array of string ptrs
    mov     rdi, [regex_heap_strings]
    mov     qword [rdi + rbx * 0x08], NULL
    ret


regex_match:
    push    rbp
    mov     rbp, rsp
    ;------------------------------------------------
    ; allocate 32 bytes for local vars & preserve 16 byte alignment
    ; 48 bytes --> a multiple of 16, if its not, you'll get SIGSEGV!
    ;------------------------------------------------
    ; [rbp - 0x08]  ovector ptr
    ; [rbp - 0x10]  string len we malloc
    ; [rbp - 0x18]  p_code  (p_code/p_mdata) added here instead of .bss
    ; [rbp - 0x20]  p_mdata
    ;-----------------------------------
    sub     rsp, 0x30
    ;-----------------------    ; COMPILE!
    mov     rdi, [rts_tos]
    mov     rdi, [rdi]
    ;-----------------------
    mov     rsi, -1
    xor     rdx, rdx
    lea     rcx, [err_code]
    lea     r8, [err_off]
    xor     r9, r9
    call    pcre2_compile_8
    ;-----------------------
    test    rax, rax
    jz      .error_compiling_regex  ; did it fail? leave msg & end func
    mov     [rbp - 0x18], rax       ; p_code
    ;-----------------------        ; CREATE MATCH DATA
    mov     rdi, rax;
    xor     rsi, rsi
    call    pcre2_match_data_create_from_pattern_8
    ;-----------------------
    test    rax, rax
    jz      .exit_fail_free_code
    mov     [rbp - 0x20], rax       ; p_mdata
    ;-----------------------
    sub     qword [rts_tos], 0x08
    mov     rsi, [rts_tos]
    mov     rsi, [rsi]
    ;-----------------------        ; MATCH IT
    mov     rdi, [rbp - 0x18]       ; p_code
    mov     rdx, -1
    xor     rcx, rcx
    xor     r8, r8
    mov     r9, [rbp - 0x20]        ; p_mdata
    ;-----------------------        ; stack alignment for 7th arg (*ENSURES* 16 byte alignmnt before call)
    sub     rsp, 0x08               ; alignment padding
    push    NULL                    ; 7th arg --> mcontext (NULL)
    call    pcre2_match_8
    add     rsp, 0x10               ; clean up 7th arg & padding
    ;-----------------------
    cmp     eax, 0x01
    jl      .not_found
    ;-----------------------        ; OVECTOR EXTRACT
    mov     rdi, [rbp - 0x20]
    call    pcre2_get_ovector_pointer_8
    ;-----------------------
    mov     [rbp - 0x08], rax   ; ovector ptr
    mov     r8, [rax]           ; start offset
    mov     r9, [rax + 0x08]    ; end offset
    mov     rcx, r9
    sub     rcx, r8             ; Len of match
    inc     rcx                 ; +1 for '\0'
    mov     [rbp - 0x10], rcx   ; store len
    ;-----------------------
    mov     rdi, rcx            ; TEST OOM err by replacing rcx-->0x00ffffffffffffff
    call_libc malloc
    ;-----------------------
    test    rax, rax
    jz      .unable_to_malloc
    ;-----------------------
    mov     rbx, rax            ; rbx = dest buffer
    mov     rdx, [rbp - 0x08]   ; ovector ptr
    mov     r8, [rdx]           ; start offset
    mov     rcx, [rbp - 0x10]   ; total length flag
    dec     rcx                 ; len without '\0'
    ;-----------------------
    mov     rsi, [rts_tos]
    mov     rsi, [rsi]
    add     rsi, r8             ; source reading ptr
    mov     rdi, rbx            ; Dest buffer
    ;-----------------------
    test    rcx, rcx
    jz      .zero_length_fill
    rep     movsb
    ;-----------------------
    .zero_length_fill:
    mov     rcx, [rbp - 0x10]   ; length
    dec     rcx
    mov     byte [rbx + rcx], NULL ; EOS '\0'
    ;-----------------------
    mov     rsi, [rts_tos]
    mov     [rsi], rbx
    jmp     .cleanup_success
    ;-----------------------
    .unable_to_malloc:
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2     ; Out Of Mem ERR! updates notes with this!!!
    jmp     .cleanup_all
    ;-----------------------
    .not_found:
    mov     rdi, [rts_tos]
    mov     qword [rdi], NULL
    jmp     .cleanup_all
    ;-----------------------
    .exit_fail_free_code:
    mov     rdi, [rbp - 0x18]
    call    pcre2_code_free_8
    sub     qword [rts_tos], 0x08   ; pop pattern
    mov     rdi, [rts_tos]
    mov     qword [rdi], -2         ; push error -2 (Out Of Mem ERR)
    jmp     .finish
    ;-----------------------
    .error_compiling_regex:
    call    regex_error_handler
    jmp     .finish
    ;-----------------------
    .cleanup_success:
    .cleanup_all:
    mov     rdi, [rbp - 0x20]
    test    rdi, rdi
    jz      .skip_mdata
    call    pcre2_match_data_free_8
    ;-----------------------
    .skip_mdata:
    mov     rdi, [rbp - 0x18]
    test    rdi, rdi
    jz      .finish
    call    pcre2_code_free_8
    ;-----------------------
    .finish:
    xor     ebx, ebx
    leave
    ret


duplicate_args:     ; on top of stack = # of args we want to preserve, so we dup that many.
    ;----------------------- ; read from [rsi] & insert into [rdi]
    call    elements_in_stack
    cmp     rax, 0x02
    mov     rdi, [rts_tos]
    ;cmp    rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    lea     r13, [rax - 0x01]   ; size of stack - dup params
    mov     r9, 0x01
    ;-----------------------
    mov     r8, [rdi]       ; grab # of params we need to dup
    cmp     r8, r9
    cmovl   r8, r9          ; if < 1 then set to 1
    cmp     r8, r13
    cmovg   r8, r13
    ;-----------------------
    shl     r8, 0x03        ; x 0x08
    ;-----------------------
    mov     rsi, rdi
    sub     rsi, r8
    ;-----------------------
    .push_on_args:
        cmp     rsi, [rts_tos]      ; don't go past the current top of stack
        jge     .completed
        ;-----------------------
        mov     r9, [rsi]
        mov     [rdi], r9
        ;-----------------------
        add     rsi, 0x08
        add     rdi, 0x08
        jmp     .push_on_args
        ;-----------------------
    .completed:
    sub     rdi, 0x08                   ; rdi already +8bytes too far
    mov     qword [rts_tos], rdi        ; tidy up & fix top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_185
    jmp     error_need_mult_operands


fill_memory:        ; (addr value size) -- fills size bytes at addr with value (byte)
    ;-----------------------
    ; experimented with using stosq instead of stosb on large allocations (e.g 3GB, 4GB, 5GB)
    ; surprisingly, stosb was ALWAYS as fast & in some cases even FASTER than stosq!
    ; removed code & switched back to orig version
    ;-----------------------
    mov     rbx, [rts_tos]              ; pop size
    lea     rax, [rts + 0x10]
    cmp     rbx, rax
    jl      .prepare_for_error
    ;-----------------------
    mov     rcx, [rbx]                  ; rcx = size (count)
    ;-----------------------            ; pop value (byte)
    movzx   rax, byte [rbx - 0x08]      ; al = byte val (e,g 0xaa = 170)
    mov     rdi, [rbx - 0x10]           ; rdi = dest addr
    ;-----------------------            ; fill with rep stosb
    rep     stosb                       ; al to [rdi], rdi++, rcx-- until rcx=0
    ;-----------------------
    sub     rbx, 0x18
    mov     [rts_tos], rbx              ; pop off all params --> there's NO return val
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_168
    jmp     error_need_mult_operands


print_single_float:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .empty_stack
    ;-----------------------
    mov     rdi, floatFMT
    movsd   xmm0, [rsi]
    mov     rax, 0x01
    call_libc printf
    ;-----------------------
    xor     ebx, ebx
    leave
    ret
    .empty_stack:
    call    get_current_func_name
    printLine   print_empty_stack, r8
    xor     ebx, ebx
    leave
    ret

powf_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm1, [rbx]             ; xmm1 = y
    movq    xmm0, [rbx - 0x08]      ; xmm0 = x
    ;-----------------------
    call    pow                     ; pow(x,y) in xmm0
    ;-----------------------
    sub     rbx, 0x08
    mov     [rts_tos], rbx          ; Pop off and overwrite val with res
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_143
    jmp     error_need_mult_operands

asin_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    asin
    ;-----------------------
    movq    [rbx], xmm0             ; Overwrite top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_145
    jmp     error_need_1_operand


acos_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    acos
    ;-----------------------
    movq    [rbx], xmm0             ; Overwrite top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_144
    jmp     error_need_1_operand

atan_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    atan
    ;-----------------------
    mov     [rts_tos], rbx          ; Overwrite top of stack
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_146
    jmp     error_need_1_operand

atan2_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx - 0x08]      ; xmm0 = C's 1st arg (x)
    movq    xmm1, [rbx]             ; xmm1 = C's 2nd arg (y)
    ;-----------------------
    call    atan2
    ;-----------------------
    sub     rbx, 0x08
    mov     [rts_tos], rbx
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_147
    jmp     error_need_mult_operands

fmin_op:
    mov     rbx, [rts_tos]          ; rbx = top stack item 2nd arg y
    cmp     rbx, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx - 0x08]      ; xmm0 = C's 1st arg
    movq    xmm1, [rbx]             ; xmm1 = C's 2nd arg
    ;-----------------------
    call    fmin
    ;-----------------------
    sub     rbx, 0x08
    mov     [rts_tos], rbx
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_156
    jmp     error_need_mult_operands

fmax_op:
    mov     rbx, [rts_tos]          ; rbx = top stack item 2nd arg y
    cmp     rbx, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx - 0x08]      ; xmm0 = C's 1st arg
    movq    xmm1, [rbx]             ; xmm1 = C's 2nd arg
    ;-----------------------
    call    fmax
    ;-----------------------
    sub     rbx, 0x08
    mov     [rts_tos], rbx
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_157
    jmp     error_need_mult_operands

hypot_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm1, [rbx]             ; xmm1 = y
    movq    xmm0, [rbx - 0x08]      ; xmm0 = x
    ;-----------------------
    call    hypot                   ; hypot(x, y) in xmm0
    sub     rbx, 0x08
    mov     [rts_tos], rbx
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_165
    jmp     error_need_mult_operands

exp_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    exp
    ;-----------------------
    movq    [rbx], xmm0             ; Overwrite top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_148
    jmp     error_need_1_operand

exp2_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    exp2
    ;-----------------------
    movq    [rbx], xmm0             ; Overwrite top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_149
    jmp     error_need_1_operand

expm1_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    expm1
    movq    [rbx], xmm0             ; Overwrite top of stack
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_150
    jmp     error_need_1_operand

sinf_op:
    ;-----------------------
    mov     rbx, [rts_tos]         ; pointer to top stack item
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    sin                    ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_140
    jmp     error_need_1_operand

cosf_op:
    ;-----------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    cos                    ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_141
    jmp     error_need_1_operand


tanf_op:
    ;-----------------------
    mov     rbx, [rts_tos]         ;pointer to top stack item
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    tan                    ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_142
    jmp     error_need_1_operand

log_op:
    ;-----------------------
    mov     rbx, [rts_tos]         ; pointer to top stack item
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    log                    ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_151
    jmp     error_need_1_operand

log2_op:
    ;-----------------------
    mov     rbx, [rts_tos]         ; pointer to top stack item
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    log2                   ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_152
    jmp     error_need_1_operand

log10_op:
    ;-----------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    log10                  ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_153
    jmp     error_need_1_operand


log1p_op:
    ;-----------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    log1p                  ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_154
    jmp     error_need_1_operand

fabs_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    fabs                   ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_155
    jmp     error_need_1_operand

floor_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    floor                  ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_158
    jmp     error_need_1_operand


ceil_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    ceil                   ; returns in xmm0
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_159
    jmp     error_need_1_operand


round_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    round                  ; returns in xmm0
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_160
    jmp     error_need_1_operand

trunc_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    trunc                  ; returns in xmm0
    movq    [rbx], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_161
    jmp     error_need_1_operand

sinh_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    sinh                   ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_162
    jmp     error_need_1_operand

cosh_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    cosh                   ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_163
    jmp     error_need_1_operand

tanh_op:
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rbx]
    call    tanh                   ; returns in xmm0
    movq    [rbx], xmm0            ; store result
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_164
    jmp     error_need_1_operand

mod_op:
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rbx, [r12]              ; rbx = divisor
    mov     rax, [r12 - 0x08]       ; rax = dividend
    ;-----------------------
    test    rbx, rbx
    jz      .div_by_zero
    ;-----------------------
    cqo                             ; sign extnd rax
    idiv    rbx                     ; sign div rdx remainder
    ;-----------------------
    lea     r12, [r12 - 0x08]
    mov     [r12], rdx
    mov     [rts_tos], r12
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_139
    jmp     error_need_mult_operands

    .div_by_zero:
    mov     rsi, operator_139
    jmp     division_by_0


min_op:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rbx, [rdi]          ; rbx = second arg
    mov     rax, [rdi - 0x08]   ; rax = first arg
    ;-----------------------
    cmp     rax, rbx
    cmovge  rax, rbx            ; rax = min(rax, rbx)
    ;-----------------------
    sub     rdi, 0x08
    mov     [rdi], rax          ; push on result
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_136
    jmp     error_need_mult_operands

max_op:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rbx, [rdi]          ; rbx = second arg
    mov     rax, [rdi - 0x08]   ; rax = first arg
    ;-----------------------
    cmp     rax, rbx
    cmovle  rax, rbx            ; rax = max(rax, rbx)
    ;-----------------------
    sub     rdi, 0x08
    mov     [rdi], rax          ; push on result
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_137
    jmp     error_need_mult_operands

abs_op:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rax, [rdi]
    ;-----------------------
    mov     rsi, rax
    sar     rsi, 0x3f           ; shift arithmetic right copies sign bit
    ;-----------------------
    xor     rax, rsi            ; bitwise flip if value is neg
    sub     rax, rsi            ; 2's compl int adjustmnt
    mov     [rdi], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_138
    jmp     error_need_1_operand


fma_op:
    mov     rbx, [rts_tos]
    lea     rax, [rts + 0x10]        ; rts[0]-->[2]
    cmp     rbx, rax
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm2, [rbx]              ; xmm2 = z -> top of stack
    movq    xmm1, [rbx - 0x08]       ; xmm1 = y
    movq    xmm0, [rbx - 0x10]       ; xmm0 = x
    ;-----------------------
    call    fma                      ; (x * y) + z -> left in xmm0
    ;-----------------------
    sub     rbx, 0x10                ; Pop off 2 and store res
    movq    [rbx], xmm0
    mov     [rts_tos], rbx
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_166
    jmp     error_need_mult_operands

q_sort_op:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     rcx, [rts_tos]
    lea     rax, [rts + 0x28]
    cmp     rcx, rax
    jl      .prepare_for_error
    ;-----------------------
    sub     rsp, 0x18
    ;-----------------------
    mov     rax, [rcx]
    mov     [rbp - 0x18], rax       ; [0] offset bytes
    ;-----------------------
    mov     rsi, [rcx - 0x08]
    mov     [rbp - 0x10], rsi       ; [8] type lookup
    ;-----------------------
    mov     rax, [rcx - 0x10]
    mov     [rbp - 0x08], rax       ; [16] sort order flag
    ;-----------------------
    mov     rdi, [rcx - 0x18]       ; arg 1: rdi = base ptr to array
    mov     rsi, [rcx - 0x20]       ; arg 2: rsi = array len
    mov     rdx, [rcx - 0x28]       ; arg 3: rdx = element size
    ;-----------------------
    sub     rcx, 0x30
    mov     [rts_tos], rcx
    ;-----------------------        ; --- GNU LINUX REGULATION LAYER ---
    mov     rcx, compare_func_fast  ; arg 4: rcx = cmp call-back func addr
    lea     r8, [rbp - 0x18]        ; arg 5: r8  = ptr to block
    ;-----------------------
    call_libc qsort_r
    ;-----------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x06
    mov     rsi, operator_135
    jmp     error_need_mult_operands

compare_func_fast:
    ;--------------------------------------------------------------------------------
    ; rdx --> struct ptr that was used by r8 in calling func (Linux 64 system V ABI)
    ;--------------------------------------------------------------------------------
    mov     r8,  [rdx]              ; r8  = member offset
    mov     r9,  [rdx + 0x08]       ; r9  = member type (0->3: signed, 4: string, 5->8: unsigned, 9: float)
    mov     r10, [rdx + 0x10]       ; r10 = asc/descending?
    ;----------------------- check for str cmp
    cmp     r9, 0x04
    je      .cmp_string
    jg      .unsigned_check         ; if type > 4, jmp to UNSIGNED section
    ;------------------------------------------
    ; SIGNED section (member types 0, 1, 2 & 3)
    ;----------------------------------------
    cmp     r9, 0x02
    jg      .cmp_qword
    je      .cmp_dword
    test    r9, r9
    jnz     .cmp_word
    ;-----------------------
    .cmp_byte:
    movsx   rax, byte [rdi + r8]
    movsx   r11, byte [rsi + r8]
    jmp     .signed_math
    ;-----------------------
    .cmp_word:
    movsx   rax, word [rdi + r8]
    movsx   r11, word [rsi + r8]
    jmp     .signed_math
    ;-----------------------
    .cmp_dword:
    movsxd  rax, dword [rdi + r8]   ; movsxd sign-extends 32 bit --> 64 bit
    movsxd  r11, dword [rsi + r8]
    jmp     .signed_math
    ;-----------------------
    .cmp_qword:
    mov     rax, [rdi + r8]
    mov     r11, [rsi + r8]
    ;-----------------------
    .signed_math:
    test    r10, r10
    jz      .signed_cmp
    xchg    rax, r11
    ;-----------------------
    .signed_cmp:
    cmp     rax, r11
    je      .is_equal
    jg      .is_greater              ; signed cmp jmp
    mov     rax, -1
    ret
    ;-------------------------------------------------
    ; UNSIGNED section (member types 5, 6, 7, 8 & 9)
    ;-----------------------------------------------
    .unsigned_check:
    mov     r11, r9
    sub     r11, 0x05               ; convert 5->9 to index 0->4
    ;-----------------------
    cmp     r11, 0x02
    jg      .cmp_qword_unsigned_or_floats
    je      .cmp_dword_unsigned
    test    r11, r11
    jnz     .cmp_word_unsigned
    ;-----------------------
    .cmp_byte_unsigned:
    movzx   rax, byte [rdi + r8]
    movzx   r11, byte [rsi + r8]
    jmp     .unsigned_math
    ;-----------------------
    .cmp_word_unsigned:
    movzx   rax, word [rdi + r8]
    movzx   r11, word [rsi + r8]
    jmp     .unsigned_math
    ;-----------------------
    .cmp_dword_unsigned:
    mov     eax, dword [rdi + r8]   ; zero-extends 32 bit to 64 bit
    mov     r11d, dword [rsi + r8]
    jmp     .unsigned_math
    ;-----------------------
    .cmp_qword_unsigned_or_floats:
    cmp     r11, 0x04
    je      .cmp_floats
    ;-----------------------        ; is unsigned qword
    mov     rax, [rdi + r8]
    mov     r11, [rsi + r8]
    ;-----------------------
    .unsigned_math:
    test    r10, r10
    jz      .unsigned_cmp
    xchg    rax, r11
    ;-----------------------
    .unsigned_cmp:
    cmp     rax, r11
    je      .is_equal
    ja      .is_greater              ; unsigned cmp jump (above)
    mov     rax, -1
    ret
    ;--------------------------------
    ; FLOATS section (member type 9)
    ;--------------------------------
    .cmp_floats:            ; deref offset in struct to get float ptr
    test    r10, r10        ; check order
    jz      .call_cmp_floats
    xchg    rdi, rsi
    ;-----------------------
    .call_cmp_floats:
    movsd   xmm0, [rdi + r8]
    ucomisd xmm0, [rsi + r8]    ; cf=1 if xmm0 < [rdi]
    ;-----------------------
    je      .is_equal
    ja      .is_greater
    ;-----------------------
    mov     rax, -1
    ret
    ;-----------------------
    .is_greater:
    mov     rax, 0x01
    ret
    ;-----------------------
    .is_equal:
    xor     rax, rax
    ret
    ;--------------------------------
    ; STRING section (member type 4)
    ;--------------------------------
    .cmp_string:            ; deref offset in struct to get str ptr (char*)
    mov     rdi, [rdi + r8]
    mov     rsi, [rsi + r8]
    ;----------------------- find sort direction
    test    r10, r10
    jz      .call_string_cmp
    xchg    rdi, rsi
    ;-----------------------
    .call_string_cmp:
    push    r8
    call    my_str_cmp      ; return -1, 0, or 1 in rax
    pop     r8
    ret

syscall_handler:
    ;---------------------------------------------------------------------------------------
    ; param order on stack: [r9, r8, r10, rdx, rsi, rdi, rax, # of params] then --> syscall
    ;--------------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    mov     r12, [rts_tos]          ; 1st param is # of params to remove from the rts
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r9, [r12]               ; # of params (inc syscall) to pop off
    ;-----------------------------
    xor     r8, r8
    cmp     r9, r8
    cmovl   r9, r8                  ; handle <= 0
    ;-----------------------------
    mov     r8, 0x07
    cmp     r9, r8
    cmovg   r9, r8                  ; handle > 7
    shl     r9, 0x03
    ;-----------------------------
    mov     r13, r12
    sub     r13, r9
    mov     [rts_tos], r13          ; pop off params & fix stack ptr
    ;-----------------------------
    mov     rax, [r12 - 0x08]       ; syscall #
    mov     rdi, [r12 - 0x10]
    mov     rsi, [r12 - 0x18]
    mov     rdx, [r12 - 0x20]       ; prev used rcx --> an err!!!
    mov     r10, [r12 - 0x28]
    mov     r8,  [r12 - 0x30]
    mov     r9,  [r12 - 0x38]
    syscall
    ;------------------------------
    mov     [r13], rax
    xor     ebx, ebx
    ;------------------------------
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_100
    jmp     error_need_mult_operands


flash_stack_ptrs:               ; need to make as fast as poss
    ;-----------------------
    mov     rdi, [base_ptr_tos]
    mov     rax, [rdi]          ; grab 1st addr from when we did push_bp
    ;-----------------------    ; instead of waiting for a 1 reg to finish r/w, use 8 to speed up cpying
    lea     r8,  [rax - 0x08]
    lea     r9,  [rax - 0x10]
    lea     r10, [rax - 0x18]
    lea     r11, [rax - 0x20]
    lea     r12, [rax - 0x28]
    lea     r13, [rax - 0x30]
    lea     r14, [rax - 0x38]
    ;-----------------------    ; bulk write
    mov     [base_ptr_0], rax
    mov     [base_ptr_1], r8
    mov     [base_ptr_2], r9
    mov     [base_ptr_3], r10
    mov     [base_ptr_4], r11
    mov     [base_ptr_5], r12
    mov     [base_ptr_6], r13
    mov     [base_ptr_7], r14
    ret

set_base_ptr:
    ;-----------------------
    cmp     qword [rts_tos], rts
    jl      error_push_bp_empty_stack   ; can't prepare bp_0, bp_1..b_7 on an empty stack!
    ;-----------------------
    mov     rcx, base_ptr_tos
    add     qword [rcx], 0x08
    mov     rdx, [rcx]
    ;-----------------------
    mov     r10, [rts_tos]
    mov     [rdx], r10
    call    flash_stack_ptrs
    ;-----------------------
    xor     ebx, ebx
    ret

del_base_ptr:
    ;-----------------------
    mov     rcx, base_ptr_tos
    cmp     qword [rcx], base_ptr
    ;-----------------------
    jl      .ended                  ; if empty can't pop off!
    je      .reset_ptrs             ; if last record, reset ptrs and pop off
    ;-----------------------
    sub     qword [rcx], 0x08
    call    flash_stack_ptrs
    .ended:
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .reset_ptrs:
    sub     qword [rcx], 0x08
    call    null_out_stack_ptrs
    xor     ebx, ebx
    ret

get_base_ptr:
    ;-----------------------
    mov     rdx, [base_ptr_tos]
    mov     rdi, [rdx]
    ;-----------------------
    mov     rsi, [rts_tos]
    add     rsi, 0x08
    mov     [rsi], rdi
    mov     [rts_tos], rsi
    ;-----------------------
    xor     ebx, ebx
    ret

dump_base_pointer_tab:
    ;-----------------------
    mov     rbx, [base_ptr_tos]
    printLine   base_ptr_title
    .looping:
        ;-----------------------
        cmp     rbx, base_ptr
        jl      .ended
        ;-----------------------
        mov     r11, [rbx]
        printLine       dump_base_ptrs, rbx, [rbx], [r11]
        ;-----------------------
        sub     rbx, 0x08
        jmp     .looping
    ;-----------------------
    .ended:
    printLine   base_ptr_footer
    xor     ebx, ebx
    ret

dummy_func:                 ; does... exaclty.... nothing...
    xor     ebx, ebx
    ret

fflush_op:
    mov     rdi, [stdout]   ; or xor rdi, rdi for all streams
    call    fflush
    ;-----------------------
    xor     ebx, ebx
    ret

inc_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rdi]
    addsd   xmm0, [FLOAT_0NE]
    movq    [rdi], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_131
    jmp     error_need_1_operand


dec_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    movq    xmm0, [rdi]
    subsd   xmm0, [FLOAT_0NE]
    movq    [rdi], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_132
    jmp     error_need_1_operand

int_to_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rax, [rdi]
    pxor    xmm0, xmm0
    cvtsi2sd xmm0, rax          ; signed conversion works for 0 to 2 ^ 63 - 1
    ;-----------------------
    movq    rax, xmm0
    mov     [rdi], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_118
    jmp     error_need_1_operand

float_to_int:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rax, [rdi]
    movq    xmm0, rax
    cvttsd2si rax, xmm0             ; Convert float in xmm0 to trunc int in rax
    ;-----------------------
    mov     [rdi], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_225
    jmp     error_need_1_operand

add_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm0, [rdi]
    sub     rdi, 0x08
    movq    xmm1, [rdi]
    ;-----------------------
    addsd   xmm0, xmm1
    ;-----------------------
    movq    [rdi], xmm0
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_119
    jmp     error_need_mult_operands

sub_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm1, [rdi]
    sub     rdi, 0x08
    movq    xmm0, [rdi]
    ;-----------------------
    subsd   xmm0, xmm1
    ;-----------------------
    movq    [rdi], xmm0
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_120
    jmp     error_need_mult_operands

mult_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    movq    xmm0, [rdi]
    sub     rdi, 0x08
    movq    xmm1, [rdi]
    ;-----------------------
    mulsd   xmm0, xmm1
    ;-----------------------
    movq    [rdi], xmm0
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_121
    jmp     error_need_mult_operands

div_float:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;------------------------------------------------------------------
    ; [12 float, 3 float] /f --> xmm0 = 12, xmm1 = 3 --> xmm0 = 12 / 3
    ;------------------------------------------------------------------
    movq    xmm1, [rdi]
    sub     rdi, 0x08
    movq    xmm0, [rdi]
    ;-----------------------
    divsd   xmm0, xmm1
    ;-----------------------
    movq    [rdi], xmm0
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_122
    jmp     error_need_mult_operands

square_root:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------
    sqrtsd  xmm0, [rdi]
    movq    [rdi], xmm0
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_123
    jmp     error_need_1_operand

float_equal:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    xor     r8, r8
    xor     rcx, rcx
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]
    ;-----------------------
    mov     r9, 0x01
    cmove   r8, r9
    cmovp   r8, rcx                 ; IEEE-754: NaN == anything, always --> 0
    ;-----------------------
    mov     [rsi], r8               ; update (0 or 1)
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_125
    jmp     error_need_mult_operands


float_not_equal:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    xor     r8, r8
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]             ; cf=1 if xmm0 < [rdi]
    ;-----------------------
    mov     r9, 0x01
    cmovne  r8, r9
    cmovp   r8, r9                  ; IEEE-754: NaN != anything, must be --> 1 (uses r9!)
    ;-----------------------
    mov     [rsi], r8
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_126
    jmp     error_need_mult_operands


float_less_than:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]             ; cf=1 if xmm0 < [rdi]
    ;-----------------------
    setb    al                      ; al = 1 if cf=1 (xmm0 < [rdi])
    movzx   r8, al                  ; r8 = 0 or 1
    ;-----------------------        ; handle NaN (pf=1)
    setp    al                      ; al = 1 if pf=1 (NaN)
    test    al, al
    jnz     .is_nan
    jmp     .store_result
    ;-----------------------
    .is_nan:
    xor     r8, r8                  ; NaN returns 0
    ;-----------------------
    .store_result:
    mov     [rsi], r8
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_127
    jmp     error_need_mult_operands


float_less_than_eq:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]             ; cf=1 if xmm0 < [rdi], zf=1 if equal
    ;-----------------------
    setbe   al                      ; al = 1 if cf=1 OR zf=1 (xmm0 <= [rdi])
    movzx   r8, al                  ; r8 = 0 or 1
    ;-----------------------        ; handle NaN (pf=1)
    setp    al                      ; al = 1 if pf=1 (NaN)
    test    al, al
    jnz     .is_nan
    jmp     .store_result
    ;-----------------------
    .is_nan:
    xor     r8, r8                  ; NaN returns 0
    ;-----------------------
    .store_result:
    mov     [rsi], r8
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_129
    jmp     error_need_mult_operands


float_more_than:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]             ; cf=1 if xmm0 < [rdi], zf=1 if equal
    ;-----------------------
    seta    al                      ; al = 1 if cf=0 AND zf=0 (xmm0 > [rdi])
    movzx   r8, al                  ; r8 = 0 or 1
    ;-----------------------        ; handle NaN (pf=1)
    setp    al                      ; al = 1 if pf=1 (NaN)
    test    al, al
    jnz     .is_nan
    jmp     .store_result
    ;-----------------------
    .is_nan:
    xor     r8, r8                  ; NaN returns 0
    ;-----------------------
    .store_result:
    mov     [rsi], r8
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_128
    jmp     error_need_mult_operands


float_more_than_eq:
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------
    sub     qword [rts_tos], 0x08
    ;-----------------------
    mov     rsi, [rts_tos]
    movsd   xmm0, [rsi]
    ucomisd xmm0, [rdi]             ; cf=1 if xmm0 < [rdi], zf=1 if equal
    ;-----------------------
    setae   al                      ; al = 1 if cf=0 (xmm0 >= [rdi])
    movzx   r8, al                  ; r8 = 0 or 1
    ;-----------------------        ; Handle NaN (PF=1)
    setp    al                      ; al = 1 if pf=1 (NaN)
    test    al, al
    jnz     .is_nan
    jmp     .store_result
    ;-----------------------
    .is_nan:
    xor     r8, r8                  ; NaN returns 0
    ;-----------------------
    .store_result:
    mov     [rsi], r8
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_130
    jmp     error_need_mult_operands


printf_float:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [r12]          ; frmt str
    ;-----------------------
    movq    xmm0, [r12 - 0x08]  ; 1st param
    movq    xmm1, [r12 - 0x10]  ; 2nd param
    movq    xmm2, [r12 - 0x18]  ; 3rd param
    movq    xmm3, [r12 - 0x20]  ; 4th param
    movq    xmm4, [r12 - 0x28]  ; 5th param
    movq    xmm5, [r12 - 0x30]  ; 6th param
    ;-----------------------
    mov     rax, 0x06
    call_libc printf
    ;-----------------------    ; pops of frmt str
    sub     qword [rts_tos], 0x08
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_117
    jmp     error_need_1_operand

printf_float_pop:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error      ; need 2 params, remember user doesn't HAVE to pass arg/s to "%f %f %f\n" !!
    ;-----------------------------
    mov     r12, [rts_tos]
    mov     r13, [r12]              ; r13 = num to pop off
    ;-----------------------------
    xor     r11, r11
    cmp     r13, r11
    cmovl   r13, r11                ; negative num = 0
    ;-----------------------------
    mov     r11, 0x06
    cmp     r13, r11
    cmovg   r13, r11                ; numbers > 6 = 6
    ;-----------------------------
    mov     rdi, [r12 - 0x08]       ; frmt str
    ;-----------------------
    movq    xmm0, [r12 - 0x10]
    movq    xmm1, [r12 - 0x18]
    movq    xmm2, [r12 - 0x20]
    movq    xmm3, [r12 - 0x28]
    movq    xmm4, [r12 - 0x30]
    movq    xmm5, [r12 - 0x38]
    ;-----------------------
    mov     rax, 0x06               ; 6 floats
    call_libc printf
    ;-----------------------
    mov     r9, r13                 ; pop off args
    add     r9, 0x02                ; +2 for below frmt str
    shl     r9, 0x03                ; * 8
    ;-----------------------
    sub     r12, r9                 ; fix stack ptr
    mov     [rts_tos], r12
    ;-----------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_134
    jmp     error_need_mult_operands

string_to_int:
    ;-----------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, [r12]                  ; convert this str to int
    call    cast_str_to_int
    mov     [r12], rax
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_229
    jmp     error_need_1_operand

cast_str_to_int:                        ; pass on rdi the string to cast
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    ; r11 = -ve flag (1 = negative & NULL = positive)
    ; r13 = total
    ; rdi = ptr to str
    ; rax = return number as an int
    ;-----------------------------
    xor     r11, r11
    cmp     byte [rdi], 0x2d            ; is it a -ve sign ascii 0x2d/45 ?
    jne     .process
    ;-----------------------------
    inc     r11                         ; set negative flag = 1
    inc     rdi                         ; skip negative byte sign
    ;-----------------------------
    .process:
    xor     r13, r13                    ; total = 0
    ;-----------------------------
    .convertToDigit:
        cmp     byte [rdi], NULL
        je      .isItNeg
        ;----------------------------- quicker or slower than imul 10?
        mov     r8, r13
        shl     r8, 0x01        ; total * 2
        shl     r13, 0x03       ; total * 8
        add     r13, r8         ; (total * 2)+(total * 8) = total * 10
        ;-----------------------------
        movzx   r8, byte [rdi]
        sub     r8, 0x30        ; -48 in ascii to get the correct byte value for int
        ;-----------------------------
        add     r13, r8         ; now add to total
        inc     rdi             ; next byte
        jmp     .convertToDigit
    ;-----------------------------
    .isItNeg:
    test    r11, r11
    jz      .finish
    neg     r13                 ; is negative, so switch sign
    ;-----------------------------
    .finish:
    mov     rax, r13
    xor     ebx, ebx
    ;-----------------------------
    leave
    ret

remove_casts_and_init_token_type:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------------------------------------------------------------
    ; go through all the tokens in [argv_ptr], whenever we find an 'int' or 'float' we need to cast.
    ; we cast the string immediately *before* this token & remove the actual 'int' or 'float' casting
    ; token from the [argv_ptr]. this way we only ever cast numbers ONCE!, before the program processes
    ; the code. after we've converted the number (from str --> int/float), 'int' and 'float' just do a
    ; dereference on the heap addr to get value, no more casting needed after this. simple..
    ;-----------------------------------------------------------------------------------;
    mov     r12, [argv_ptr]
    xor     r14, r14
    ;-----------------------------
    .looping:
        cmp     r14, [argv_len]
        je      .fin
        ;-----------------------------
        ; GET THE TOKEN, IF ITS AN OPERATOR, update token_type [r14 * 0x02] with that operator ID
        ; OTHERWISE DEFAULT token_type is 0xff00
        ; **THIS MUST MUST MUST BE DONE BEFORE** WE do the strcmps in 'argv_onto_stack' otherwise,
        ; we can end up with somthing like this disaster!! ---> "38\0" = '&'
        ;-----------------------------
        mov     rdi, [r12 + r14 * 0x08]
        call    check_is_operator           ; pass token rdi, **rbx = index** function & rax=1. if not found rax=0
        test    rax, rax
        jz      .nextToken                  ; an operand, token_type is already 0xff00, so cont loopin...
        ;-----------------------------
        .setTokenTypeToOperator:
        mov     rdx, [token_type]
        mov     word [rdx + r14 * 0x02], bx         ; result of check_is_operator
        ;-----------------------------
        ;.printData:
        ;printLine  cast_convert_iteration, [r12 + r14 * 0x08], rbx
        ;-----------------------------
        .castingCheck:
        mov     rdx, [token_type]
        cmp     word [rdx + r14 * 0x02], 0x03       ; operator_03 = "int\0"
        je      .castInt
        ;-----------------------------
        cmp     word [rdx + r14 * 0x02], 0x74       ; operator_116 = "float\0"
        jne     .nextToken
        ;-----------------------------
        .castFloat:
        dec     r14                             ; back -1 index above "int\0" token is string with the number we CONVERT once!
        ;-----------------------------
        mov     rdi, [r12 + r14 * 0x08]
        call    cast_string_to_float_init
        mov     rbx, rax                        ; store num rax, malloc/free being used
        ;-----------------------------
        jmp     .removeNumberString
        ;-----------------------------
        .castInt:
        dec     r14                             ; back -1 index above "int\0" token is string with the number we CONVERT once!
        ;-----------------------------
        mov     rdi, [r12 + r14 * 0x08]
        call    cast_str_to_int
        mov     rbx, rax                        ; store num rax, malloc/free being used
        ;-----------------------------
        .removeNumberString:
        mov     rdi, [r12 + r14 * 0x08]
        call_libc free
        ;-----------------------------
        mov     rdi, 0x08
        call_libc malloc
        mov     qword [rax], rbx
        ;-----------------------------
        mov     qword [r12 + r14 * 0x08], rax   ; store num straight in here ; store malloc part
        inc     r14
        ;-----------------------------
        .nextToken:
        inc     r14
        jmp     .looping

    mov     qword [r12 + r14 * 0x08], NULL
    ;-----------------------------
    cmp     qword [debug_mode], NULL
    je      .fin
    printLine   debugInsertPos, r14
    ;-----------------------------
    .fin:
    leave
    ret

deref_str_to_float:     ; assume the float is already in heap alloc, so deref that heap (float) & place on top of rts
    ;-----------------------------
    mov     r10, [rts_tos]
    cmp     r10, rts
    jl      error_need_mult_operands
    ;-----------------------------
    mov     r11, [r10]              ; get ptr to heap alloc
    mov     r9, [r11]               ; now get the float NUMBER out of it!
    ;-----------------------------
    .finish:
    mov     r8, [rts_tos]
    mov     qword [r8], r9          ; replace ptr to heap with number, with actual number
    ;-----------------------------
    xor     ebx, ebx
    ret

cast_string_to_float_init:          ; pass on rdi the string and float ready on rax
    ;-----------------------
    xor     rsi, rsi
    call    strtod                  ; double in xmm0
    movq    rax, xmm0
    ;-----------------------
    ret


init_token_type_mapping:        ; alloc amount needed and then null out
    ;-----------------------
    mov     rdi, [argv_len]
    shl     rdi, 0x01           ; double it for 2 bytes (word) for range 0x0000 --> 0xffff
    call_libc malloc
    ;-----------------------
    mov     qword [token_type], rax
    mov     r13, rax
    xor     r8, r8
    ;-----------------------    ; null all bytes first
    mov     rcx, [argv_len]
    .zero_all:
        cmp     r8, rcx
        jge     .done_zeroing
        ;-----------------------
        mov     word [r13 + r8 * 0x02], operand_KEYWORD;  0xff00 ;  <-- this beats LEA and rep stosw!!
        inc     r8
        jmp     .zero_all
    ;-----------------------
    .done_zeroing:
    ret


dump_token_type_mapping:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r13, [token_type]
    xor     r14, r14
    ;-----------------------    ; null all bytes first
    .displayAll:
        cmp     r14, [argv_len]
        je      .ended
        ;-----------------------
        mov     r10, [argv_ptr]
        mov     r10, [r10 + r14 * 0x08]
        movzx   r9, word [r13 + r14 * 0x02] ; the token GROUP   (OPERATOR/OPERAND/IGNORE)
        ;-----------------------
        ; changed the TYPE layout below, its now a simple word (16 bit) operands = 0xff00
        ; & operators now have a possible range: 0x00 --> 0xfeff (up to 65,280 operators)
        ;-----------------------
        ;lea    rcx, [r13 + r14 * 0x02]
        ;inc        rcx                     ; the next byte has the token TYPE (0, 1, 2, etc)
        ;movzx  r8, byte [rcx]              ; zero out 7 other bytes
        ;-----------------------
        cmp     word r9w, operand_KEYWORD   ; cmp with operand LIMIT
        jb      .dispOperator               ; < operand_KEYWORD = operator
        ;-----------------------
        .dispOperand:
        printLine   disp_token_type_operand, r14, r9, r10       ; operand
        jmp     .nextElement
        ;-----------------------    ; has to be operator
        .dispOperator:
        printLine   disp_token_type_operator, r14, r9, r10      ; operator
        jmp     .nextElement
        ;-----------------------
        .nextElement:
        inc     r14
        jmp     .displayAll
    ;-----------------------
    .ended:
    leave
    ret


dump_tokens_ptr:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    xor     r13, r13
    mov     r12, [argv_ptr]
    mov     rbx, [INS_POS]
    printLine intOut, [argv_len]
    ;-----------------------------
    .looping:
        cmp     r13, [argv_len]
        je      .ended
        ;-----------------------------
        mov     r9, [r12 + r13 * 0x08]
        printLine   indexMemLocPtr, r13, [r12 + r13 * 0x08], r9
        inc     r13
        jmp     .looping
    ;-----------------------------
    .ended:
    leave
    ret


check_hashset_ok:
    ;-------------------------------------------------------------------------------------
    ; iterate through (all operators) all_ops list & display the index of their function in map_funcs list
    ;-------------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    xor     r12, r12
    ;-----------------------
    .checkAllOperators:
        mov     r13, [all_ops + r12 * 0x08]
        test    r13, r13
        jz      .ended
        ;-----------------------
        mov     rdi, [all_ops + r12 * 0x08]
        call    check_is_operator
        test    rax, rax
        jz      .error              ; <--- ouch! should NEVER happen!
        ;-----------------------
        mov     r8, rbx
        printLine   OpData2, [all_ops + r12 * 0x08], r8
        ;printLine  OpData, [all_ops + r12 * 0x08], r8
        inc     r12
        jmp     .checkAllOperators
        ;-----------------------
    .ended:
    leave
    ret

    .error:
    printLine   badOpErr, [all_ops + r12 * 0x08] ;rcx
    jmp     exit


init_debug_and_input_file:
    ;------------------------------------------------------
    ; using user selected source file? debug settings? or default settings?
    ;------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    xor     rbx, rbx
    mov     r15, [argv_passed]
    .scanArgv:
        cmp     rbx, [argc_passed]
        jge     .finishedChecks
        ;-----------------------
        mov     rsi, [r15 + rbx * 0x08]
        mov     rdi, debugCheck         ; cmp with "-d" debug param
        call    my_str_cmp
        ;-----------------------
        test    rax, rax
        jnz     .regexSzCheck           ; -b fo regex size array for matchng pair offsets
        ;-----------------------
        inc     qword [debug_mode]      ; switch this flag on
        printLine dashes2
        printLine debugStatus
        jmp     .nextArgv
        ;-----------------------
        .regexSzCheck:
        mov     rsi, [r15 + rbx * 0x08]
        mov     rdi, regexCheck         ; cmp with "-b" regex size
        call    my_str_cmp
        test    rax, rax
        jnz     .inputFileCheck
        ;-----------------------    ; if "-b" is the last argv, with no Kb size after? just use default val 512K
        mov     rdi, [argc_passed]  ; get max # of args
        dec     rdi                 ; get index of last argv value
        cmp     rbx, rdi
        jge     .nextArgv
        ;-----------------------
        mov     rdi, rbx
        inc     rdi
        mov     rsi, [r15 + rdi * 0x08]
        ;-----------------------
        push    rbx
        mov     rdi, rsi
        call    cast_str_to_int
        pop     rbx
        ;-----------------------
        cmp     rax, 0x18           ; must be at least 24 bytes
        jl      .nextArgv           ; use default 512K if size passed < 24 bytes
        mov     [regexSize], rax    ; store user passed -b regex size
        jnz     .nextArgv
        ;-----------------------
        .inputFileCheck:
        mov     rsi, [r15 + rbx * 0x08]
        mov     rdi, inputFile          ; cmp with "-f" input source file param
        call    my_str_cmp
        ;-----------------------
        test    rax, rax
        jnz     .nextArgv
        ;-----------------------    ; if "-f" is the last argv, with no input file after? just use default source file
        mov     rdi, [argc_passed]  ; get max # of args
        dec     rdi                 ; get index of last argv value
        cmp     rbx, rdi
        jge     .nextArgv
        ;-----------------------
        mov     rsi, [argv_passed]
        mov     rdi, rbx
        inc     rdi
        mov     rsi, [r15 + rdi * 0x08]
        mov     qword [source_file], rsi
        ;-----------------------
        .nextArgv:
        inc     rbx
        jmp     .scanArgv
    ;-------------------------
    .finishedChecks:
    leave
    ret


init_argc_and_argv:
    ;------------------------------------------------------------
    ; init argc & argv. argv is char ** so create a struct for this to use later
    ;------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    mov     rdi, [argc_passed]
    call    push_on
    ;-------------------------
    mov     rdi, argcStr
    call    push_on
    ;-------------------------
    call    define_i
    mov     r15, [argv_passed]
    ;-------------------------
    .looping:       ; similar to: while(*argv) printf("%s\n", *argv++); but push *argv instead!
        cmp     qword [r15], NULL
        je      .ended
        ;-------------------------
        mov     rdi, [r15]
        call    push_on
        add     r15, 0x08
        jmp     .looping

    .ended:
    mov     rdi, [argc_passed]
    call    push_on
    call    packed_data
    ;-------------------------
    mov     rdi, argvStr
    call    push_on
    call    define_struct
    ;-------------------------
    leave
    ret

set_env_var:
    ;-------------------------
    mov     r11, [rts_tos]      ; name
    cmp     r11, rts
    jle     .prepare_for_error
    mov     rdi, [r11]
    mov     rsi, [r11 - 0x08]
    ;-------------------------  ; overwrite FLAG, if value for name exists. 0 = no, 1 = yes
    mov     rdx, [r11 - 0x10]
    sub     qword [rts_tos], 0x10
    ;-------------------------
    call    setenv
    ;-------------------------
    mov     rbx, [rts_tos]
    mov     [rbx], rax
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_174
    jmp     error_need_mult_operands


get_env_var:
    ;-------------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    mov     rdi, [rbx]
    call    getenv
    ;-------------------------
    mov     [rbx], rax
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_173
    jmp     error_need_1_operand

get_the_envptr:     ; push **envp onto stack let user check the env vars
    ;-------------------------
    add     qword [rts_tos], 0x08
    mov     rdi, [rts_tos]
    mov     rsi, [envp_passed]
    mov     [rdi], rsi
    xor     ebx, ebx
    ret

heap_update:                ; the dest is heap alloc. on top is # of bytes to copy to dest, then start pos.
    ;-----------------------
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error
    ;-----------------------
    mov     rcx, [rts_tos]          ; on top # of bytes below TOS we start copying from!
    mov     r8, [rcx]
    mov     rdx, [rcx - 0x08]       ; number of bytes to copy
    ;----------------------------
    xor     r9, r9
    cmp     r8, r9
    cmovl   r8, r9                  ; dont allow neg numbers from start point
    add     r9, 0x08
    cmp     rdx, NULL
    cmovl   rdx, r9                 ; dont allow neg numbers, if so, set to 8
    ;----------------------------
    mov     rdi, [rcx - 0x10]       ; dest on the heap
    lea     rsi, [rcx - 0x18]       ; *ptr to the TOS, this is the source and we read from it
    mov     [rts_tos], rsi
    sub     rsi, r8                 ; how many buytes below the TOS do we start copying?
    call    copy_bytes
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_86
    jmp     error_need_mult_operands

sleeping:
    ;----------------------------
    mov     r12, [rts_tos]                  ; # of nano-seconds to sleep
    cmp     r12, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [r12]
    xor     rbx, rbx
    ;----------------------------
    cmp     rdi, rbx                        ; check for negative
    cmovl   rdi, rbx
    ;----------------------------
    mov     rsi, [r12 - 0x08]               ; # of seconds to sleep
    cmp     rsi, rbx                        ; Check for negative
    cmovl   rsi, rbx
    ;----------------------------
    mov     [timeStructure + timespec.nano_seconds], rdi
    mov     [timeStructure + timespec.seconds], rsi
    ;----------------------------
    mov     rax, SYS_NANOSLEEP      ; system call 0x23 (35) = nanosleep
    mov     rdi, timeStructure      ; struct_timespec
    xor     rsi, rsi
    syscall
    ;----------------------------
    lea     rsi, [r12 - 0x08]
    mov     [rsi], rax              ; grab return val
    mov     [rts_tos], rsi          ; fix top of stack
    ret                             ; xor rbx, rbx already done
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_98
    jmp     error_need_mult_operands


get_epoch:              ; top of stack <= 0 returns epoch, >0 = time in 16 bytes HH,MM,SS,
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;----------------------------
    xor     rdi, rdi            ; pass null to time() --> epoch on rax
    call_libc    time
    ;----------------------------
    mov     rdi, [r13]
    test    rdi, rdi
    jle     .push_on_result     ; Only epoch is pushed
    ;----------------------------
    mov     [timeStructure + timespec.seconds], rax
    mov     rdi, timeStructure     ; epoch # of secs is at start
    call_libc   localtime          ; rax points to tm struct filled with details
    ;----------------------------
    .push_on_result:
    mov     [r13], rax          ; return val from syscall
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rdi, operator_99
    jmp     error_need_1_operand

malloc_bytes:
    mov     rbx, [rts_tos]              ; # of bytes to malloc
    cmp     rbx, rts
    jl      .prepare_for_error
    mov     rdi, [rbx]
    ;----------------------------
    call_libc malloc
    ;----------------------------
    mov     [rbx], rax
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_84
    jmp     error_need_1_operand


get_file_byte_size:
    mov     rdi, [f_byte_size]
    call    push_on
    xor     ebx, ebx
    ;----------------------------
    ret

get_stack_address:      ; get the address of the TOS and put it on the TOS!
    ;----------------------------
    xor     rbx, rbx
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    cmovl   rdi, rbx    ; if stack empty, push on 0
    ;----------------------------
    mov     rdi, [rts_tos]
    call    push_on     ; rbx xored here
    ;----------------------------
    ret

bitwise_shr:
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rcx, [r13]          ; # of bits we shift the value
    mov     rdi, 0x01           ; min range 1 bit
    mov     rsi, 0x3f           ; max range 63 bits
    ;----------------------------
    cmp     rcx, rdi
    cmovl   rcx, rdi            ; if rcx < 1 set to 1
    cmp     rcx, rsi
    cmovg   rcx, rsi            ; if rcx > 63 set to 63
    ;----------------------------
    sub     r13, 0x08           ; Move ptr to value
    shr     qword [r13], cl     ; shift right cl bits
    ;----------------------------
    mov     [rts_tos], r13
    ;----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_82
    jmp     error_need_1_operand

bitwise_shl:
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rcx, [r13]          ; # of bits we shift the value
    mov     rdi, 0x01           ; min range 1 bit
    mov     rsi, 0x3f           ; max range 63 bits
    ;----------------------------
    cmp     rcx, rdi
    cmovl   rcx, rdi            ; if rcx < 1 set to 1
    cmp     rcx, rsi
    cmovg   rcx, rsi            ; if rcx > 63 set to 63
    ;----------------------------
    sub     r13, 0x08           ; Move ptr to value
    shl     qword [r13], cl     ; shift right cl bits
    ;----------------------------
    mov     [rts_tos], r13
    ;----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_81
    jmp     error_need_1_operand

bitwise_sar:
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rcx, [r13]          ; # of bits we shift the value
    mov     rdi, 0x01           ; min range 1 bit
    mov     rsi, 0x3f           ; max range 63 bits
    ;----------------------------
    cmp     rcx, rdi
    cmovl   rcx, rdi            ; if rcx < 1 set to 1
    cmp     rcx, rsi
    cmovg   rcx, rsi            ; if rcx > 63 set to 63
    ;----------------------------
    sub     r13, 0x08           ; Move ptr to value
    sar     qword [r13], cl     ; shift right cl bits
    ;----------------------------
    mov     [rts_tos], r13
    ;----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_82
    jmp     error_need_1_operand

generate_mask:                   ; bitwise mask for --> not, and, or & xor
    ;----------------------------
    ; don't know why i restricted bitwise to 2^n before??
    ; needed to change this for user to select anything between [1-->64]
    ; that means we HAVE to use mask to change ONLY them bits we need to flip.
    ; pass in r8 the number of bits you need to do the bitwise op.
    ; the mask is built & returned on rsi to calc bitwise result
    ;----------------------------
    test    r8, r8
    jle     .mask_1_bit
    ;----------------------------
    cmp     r8, 0x40
    jge     .mask_64_bits           ; check r8 >= 64? if yes --> 0xff
    ;----------------------------
    mov     rcx, r8                 ; <-- have to use cl
    mov     rsi, 0x01
    shl     rsi, cl                 ; rsi = 1 << bits
    dec     rsi                     ; rsi = (1 << bits) - 1 (perfect +ve mask!)
    ret
    ;----------------------------
    .mask_1_bit:                    ; check r8 < 1? if yes default --> 0x01
    mov     rsi, 0x01
    ret
    ;----------------------------
    .mask_64_bits:
    mov     rsi, -1                 ; set all bit
    ret


bitwise_xor:            ; top of stack as number of bytes to XOR, below are 2 values to XOR
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     r8, [rdi]               ; # of bits to xor
    mov     r9, [rdi - 0x08]        ; 1st value to or
    mov     r10, [rdi - 0x10]       ; 2nd value to or
    ;----------------------------     check <= 0
    call    generate_mask
    ;----------------------------
    xor     r9, r10                 ; r9 xor only with masked bits in r10
    and     r9, rsi                 ; use mask with final res to clear upper bits
    ;----------------------------   ; put result & fix top of stack
    sub     rdi, 0x10
    mov     [rts_tos], rdi
    mov     [rdi], r9
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_80
    jmp     error_need_1_operand

bitwise_and:            ; top of stack as number of bytes to AND, below are 2 values to AND
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     r8, [rdi]               ; # of bits to and
    mov     r9, [rdi - 0x08]        ; 1st value to and
    mov     r10, [rdi - 0x10]       ; 2nd value to and
    ;----------------------------
    call    generate_mask           ; mask returned on rsi
    ;----------------------------
    and     r9, r10                 ; and on r9
    and     r9, rsi                 ; use mask with final res to clear upper bits
    ;----------------------------   ; put result and fix top of stack
    sub     rdi, 0x10
    mov     [rts_tos], rdi
    mov     [rdi], r9
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_79
    jmp     error_need_1_operand

bitwise_or:         ; top of stack as number of bytes to OR, below are 2 values to OR
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     r8, [rdi]               ; # of bits to or
    mov     r9, [rdi - 0x08]        ; 1st value to and
    mov     r10, [rdi - 0x10]       ; 2nd value to and
    ;----------------------------
    call    generate_mask           ; mask returned on rsi
    ;----------------------------
    or      r9, r10                 ; and on r9
    and     r9, rsi                 ; use mask with final res to clear upper bits
    ;----------------------------   ; put result and fix top of stack
    sub     rdi, 0x10
    mov     [rts_tos], rdi
    mov     [rdi], r9
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_78
    jmp     error_need_1_operand

bitwise_not:        ; top of stack as number of bytes negate/NOT, below is value to negate/NOT
    ;----------------------------     that means we have to use mask to change ONLY them bits we need to flip
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     r8, [rdi]               ; # of bits to negate
    mov     r9, [rdi - 0x08]        ; the value to negate
    ;----------------------------
    call    generate_mask           ; mask returned on rsi
    ;----------------------------
    not     r9                      ; not r9
    and     r9, rsi                 ; use mask with final res to clear upper bits
    ;----------------------------   ; put result and fix top of stack
    sub     rdi, 0x08
    mov     [rts_tos], rdi
    mov     [rdi], r9
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_77
    jmp     error_need_1_operand


;------------------------------------------------------------
; this applies to these funcs:
;
;   - update_byte
;   - update_word
;   - update_dword
;   - update_qword
;
; ** IMPORTANT ** you can easily remove the '\0' EOS term!!
; updates a byte/word/dword/qword in a string/mem loc.
;
; rdi = ptr to mem/string on heap
; rsi = 1/2/4/8 bytes use to overwrite
;
; then modify the string/mem loc with the char/s
;------------------------------------------------------------
update_byte:
    ;----------------------------
    mov     r10, [rts_tos]
    mov     rsi, [r10]                      ; char we want to copy across
    mov     rdi, [r10 - 0x08]               ; string on heap we want to modify
    sub     qword [rts_tos], 0x10
    ;----------------------------
    mov     byte [rdi], sil
    xor     ebx, ebx
    ret

update_word:
    ;----------------------------
    mov     r10, [rts_tos]
    mov     rsi, [r10]                      ; word we want to copy across
    mov     rdi, [r10 - 0x08]               ; string on heap we want to modify
    sub     qword [rts_tos], 0x10
    ;----------------------------
    mov     word [rdi], si
    xor     ebx, ebx
    ret

update_dword:
    ;----------------------------
    mov     r10, [rts_tos]
    mov     rsi, [r10]                      ; dword we want to copy across
    mov     rdi, [r10 - 0x08]               ; string on heap we want to modify
    sub     qword [rts_tos], 0x10
    ;----------------------------
    mov     dword [rdi], esi
    xor     ebx, ebx
    ret

update_qword:
    ;----------------------------
    mov     r10, [rts_tos]
    mov     rsi, [r10]                      ; qword we want to copy across
    mov     rdi, [r10 - 0x08]               ; string on heap we want to modify
    sub     qword [rts_tos], 0x10
    ;----------------------------
    mov     [rdi], rsi
    xor     ebx, ebx
    ret


smash_str_to_ascii:             ; just put ascii chars on the RTS, no mem allocation!
    ;-----------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     r15, [rsi]
    sub     rsi, 0x08
    mov     [rts_tos], rsi
    xor     r12, r12
    ;-----------------------
    .looping:
        cmp     byte [r15 + r12], NULL      ; get to EOS
        je      .ended
        ;-----------------------
        movzx   rdi, byte [r15 + r12]
        call    push_on
        ;-----------------------
        inc     r12
        jmp     .looping
    ;-----------------------
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_109
    jmp     error_need_1_operand


smash_str_up:               ; put the ascii chars form the string as heap allocated chars + '\0'
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;-----------------------
    sub     rsp, 0x08
    ;-----------------------
    mov     rdi, [rts_tos]
    mov     rdi, [rdi]
    mov     qword [rbp - 0x08], rdi     ; string to split
    call    pop_off
    ;-----------------------
    mov     r15, [rbp - 0x08]
    xor     r12, r12

    .looping:
        cmp     byte [r15 + r12], NULL      ; get to EOS
        je      .ended
        ;-----------------------
        xor     rdi, rdi
        add     rdi, 0x02
        call_libc malloc
        ;-----------------------
        mov     r14, rax
        mov     byte [r14 + 0x01], NULL
        ;-----------------------
        xor     r11, r11
        mov     byte r11b, [r15 + r12]
        mov     byte [r14], r11b
        mov     rdi, r14
        call    push_on
        ;-----------------------
        inc     r12
        jmp     .looping
    ;-----------------------
    .ended:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_74
    jmp     error_need_1_operand

sub_string:                                 ; safety checks??
    ;-----------------------
    ; if index < 0 set to 0
    ; if index > str length, set to last char
    ; if length <= 0 set it to string lenght
    ; if index + length >= EOS '\0' then length = (strlen - index)
    ;-----------------------    [string, index, length]
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     r12, [rcx]                          ; r12 = length
    ;-----------------------
    lea     rbx, [rcx - 0x08]
    mov     r13, [rbx]                          ; r13 = index where to copy from
    ;-----------------------
    lea     rbx, [rcx - 0x10]
    mov     r14, [rbx]                          ; r14 = source string
    mov     [rts_tos], rbx
    ;-----------------------
    mov     rdi, r14
    call    str_len                             ; rax = strlen
    ;-----------------------
    xor     r9, r9
    cmp     r13, NULL
    cmovl   r13, r9                             ; index -ve? if so set to 0
    ;-----------------------
    cmp     r12, NULL
    cmovle  r12, rax                            ; length <= 0? set to maximum for now
    ;-----------------------
    lea     rsi, [rax - 0x01]                   ; string length -1
    cmp     r13, rax
    cmovge  r13, rsi                            ; index > strlen? then set to last char
    ;-----------------------
    lea     rcx, [r12 + r13]
    mov     rsi, rax
    sub     rsi, r13                            ; length - start
    cmp     rcx, rax                            ; index + length > string?
    cmovg   r12, rsi                            ; if so, resuce the length
    ;-----------------------
    mov     rdi, r12
    inc     rdi
    call_libc malloc
    mov     r15, rax
    ;-----------------------
    mov     rdi, rax                            ; write to heap
    mov     rsi, r14                            ; get string to copy
    add     rsi, r13                            ; add offset
    mov     rdx, r12                            ; # of bytes to copy
    call    copy_bytes
    ;-----------------------
    mov     byte [r15 + r12], NULL              ; EOS '\0'
    ;-----------------------
    mov     rdi, [rts_tos]
    mov     [rdi], r15
    ;-----------------------
    .finished:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_73
    jmp     error_need_mult_operands


get_char_from_ptr:                      ; grab the char from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    movzx   rdi, byte [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

get_word_from_ptr:                      ; grab the word from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    movzx   rdi, word [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

get_dword_from_ptr:                     ; grab the dword from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    mov     edi, dword [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

get_qword_from_ptr:                     ; grab the qword from the heap on top of the stack
        ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    mov     rdi, [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

value_at_index:         ; looking at the RTS, use the top index to make a copy of that [index] & push TOS
    ;---------------------------------
    mov     r9, [rts_tos]
    cmp     r9, rts
    jl      .prepare_for_error
    ;---------------------------------
    mov     r10, r9                     ; need later
    mov     r8, [r9]                    ; grab top integer index
    sub     r9, 0x08                    ; r9 = index[0]
    ;---------------------------------
    lea     rdx, [rax - 0x02]           ; max/upper limit
    xor     rbx, rbx
    test    r8, r8                      ; r8 < 0 ?
    cmovs   r8, rbx                     ; r8 -ve? set to null
    cmp     r8, rdx                     ; r8 >= rax?
    cmovg   r8, rdx                     ; r8 =  rax-1
    ;---------------------------------
    lea     r11, [r8 * 0x08]
    sub     r9, r11                     ; move ptr down this many indexes
    ;---------------------------------
    mov     r11, [r9]                   ; derefernce & replace top of stack with this value
    mov     [r10], r11
    ;---------------------------------
    ;xor    ebx, ebx                    ; done earlier!
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_72
    jmp     error_need_mult_operands

value_at_index_upd:                     ; looking at the RTS, top = index, val below is what we update to
    ;---------------------------------
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error
    ;---------------------------------
    mov     r9, [rts_tos]
    lea     r10, [r9 - 0x10]            ; need for rts
    mov     [rts_tos], r10
    ;---------------------------------
    mov     r8, [r9]                    ; grab top integer index
    mov     r13, [r9 - 0x08]            ; grab value to replace
    mov     r9, r10                     ; r9 = index[0]
    ;---------------------------------
    lea     rdx, [rax - 0x03]           ; max/upper limit
    xor     rbx, rbx
    test    r8, r8                      ; r8 < 0 ?
    cmovs   r8, rbx                     ; r8 -ve? set to null
    cmp     r8, rdx                     ; r8 >= rax?
    cmovg   r8, rdx                     ; r8 =  rax-1
    ;---------------------------------
    lea     r11, [r8 * 0x08]
    sub     r9, r11                     ; move ptr down this many indexes
    ;---------------------------------
    mov     [r9], r13
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_115
    jmp     error_need_mult_operands

swap_positions:
    ;---------------------------------
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error
    lea     rcx, [rax - 0x03]                   ; rcx = MAX element, 0 = min element
    ;---------------------------------
    mov     r12, [rts_tos]                      ; grab top integer index
    mov     r8, [r12]
    mov     r9, [r12 - 0x08]                    ; grab next integer index
    lea     r13, [r12 - 0x10]                   ; point BELOW the 2 params
    mov     r12, r13
    mov     [rts_tos], r13                      ; pop off params r13 needed later
    ;---------------------------------          ; check ranges & correct e.g (0-->5)
    xor     rbx, rbx
    cmp     r8, rbx
    cmovl   r8, rbx
    cmp     r8, rcx                             ; cmp limit
    cmovg   r8, rcx
    ;---------------------------------          ; check ranges & correct e.g (0-->9)
    cmp     r9, rbx
    cmovl   r9, rbx
    cmp     r9, rcx                             ; cmp limit
    cmovg   r9, rcx
    ;---------------------------------
    shl     r8, 0x03
    shl     r9, 0x03
    sub     r12, r8
    sub     r13, r9
    mov     r8, [r12]
    mov     r9, [r13]
    ;---------------------------------
    mov     [r12], r9
    mov     [r13], r8
    ;---------------------------------
    ;xor        ebx, ebx                        ; done earlier!
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_71
    jmp     error_need_mult_operands

hex_string_n:                       ; displays TOS as hex
    push    rbp
    mov     rbp, rsp
    ;---------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;---------------------------    ; rdi expects the '\0' term string
    mov     rdx, [rdi]              ; # of bytes to print
    ;---------------------------
    xor     r8, r8
    cmp     rdx, r8
    cmovl   rdx, r8                 ; check negative num, set to 0
    ;---------------------------
    lea     rsi, [rdi - 0x08]
    mov     r14, [rsi]              ; start of string
    mov     [rts_tos], rsi
    lea     rbx, [r14 + rdx]        ; marker for print end limit
    ;---------------------------
    printLine hexHeader
    printLine charFMTnnl, [tab2]
    ;---------------------------
    xor     r12, r12                ; counter
    .header:
        cmp     r12, 0x10
        je      .preReadAllString
        ;---------------------------
        printLine   hexOut, r12
        inc     r12
        jmp     .header
    ;---------------------------
    .preReadAllString:
    printLine   testNL
    printLine   testNL
    xor     r12, r12
    xor     r13, r13
    ;-------------------------
    .readAllString:
        cmp     r14, rbx                ; print < limit
        je      .ended
        ;---------------------------
        cmp     r12, NULL
        jne     .printHex
        ;---------------------------
        printLine hexOut, r13
        printLine charFMTnnl, [tab2]
        ;---------------------------
        .printHex:
        movzx   r10, byte [r14]         ; clean out remainding bytes else valgrind moans!
        printLine   hexOut, r10
        inc     r14
        inc     r12
        inc     r13
        ;---------------------------
        cmp     r12, 0x10
        jne     .continue
        ;---------------------------
        printLine   testNL
        xor     r12, r12
        .continue:
        jmp     .readAllString
    ;-------------------------
    .ended:
    printLine   testNL
    ;---------------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_87
    jmp     error_need_1_operand


hex_string:                     ; displays TOS as hex
    push    rbp
    mov     rbp, rsp
    ;---------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    mov     rdi, [rdi]
    call    hex_dump_str
    ;---------------------------
    xor     ebx, ebx
    ;---------------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_70
    jmp     error_need_1_operand

hex_dump_str:                       ; rdi expects the '\0' term string
    push    rbp
    mov     rbp, rsp
    ;---------------------------
    mov     rbx, rdi
    ;---------------------------
    printLine hexHeader
    printLine charFMTnnl, [tab2]
    xor     r12, r12                ; counter
    .header:
        cmp     r12, 0x10           ; cmp to 16
        je      .preReadAllString
        ;---------------------------
        printLine   hexOut, r12
        inc     r12
        jmp     .header
    ;---------------------------
    .preReadAllString:
    printLine   testNL
    printLine   testNL
    xor     r12, r12
    xor     r13, r13
    .readAllString:
        cmp     byte [rbx], NULL
        je      .ended
        ;---------------------------
        cmp     r12, NULL
        jne     .printHex
        printLine   hexOut, r13
        printLine charFMTnnl, [tab2]
        ;---------------------------
        .printHex:
        movzx   r10, byte [rbx]         ; clean out remainding bytes else valgrind moans!
        printLine   hexOut, r10
        inc     rbx
        inc     r12
        inc     r13
        ;---------------------------
        cmp     r12, 0x10
        jne     .continue
        ;---------------------------
        printLine   testNL
        xor     r12, r12
        .continue:
        jmp     .readAllString

    .ended:
    printLine   testNL
    ;---------------------------
    xor     ebx, ebx
    leave
    ret


check_argv_len:             ; pass on rdi the argv ptr, when we find first NULL, thats the end of token list
    push    rbp
    mov     rbp, rsp
    ;---------------------------
    xor     r8, r8          ; counter
    .looping:
        cmp     qword [rdi], NULL
        je      .ended
        ;---------------------------
        add     rdi, 0x08
        inc     r8
        jmp     .looping
    ;---------------------------
    .ended:
    mov     [argv_len], r8
    leave
    ret


pop_off_free:                   ; free the heap allocation at [rts_tos], dangerous be careful!!
    ;-----------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    mov     rdi, [rsi]
    call_libc free
    ;-----------------------
    sub     qword [rts_tos], 0x08
    xor     ebx, ebx
    ;-----------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_67
    jmp     error_need_1_operand

write_bin_num:                  ; writes 8 bytes whatever is on [rts_tos]
    ;-----------------------
    cmp     qword [rts_tos], rts
    jng     .prepare_for_error
    ;-----------------------
    mov     rax, SYS_WRITE      ; syscall #1 = write
    mov     rdi, [write_fd]
    mov     r10, [rts_tos]
    mov     rdx, [r10]          ; how many bytes?
    mov     rsi, r10            ; value at [rts_tos]
    sub     rsi, rdx            ; start from this many bytes below the TOS
    syscall
    ;-----------------------
    sub     qword [rts_tos], 0x08   ; remove the # of bytes to write from the TOS
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_66
    jmp     error_need_1_operand


write_bin_num_ptr:              ; writes 8 bytes whatever is on [rts_tos]
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error  ; FIX ERROR MSG!! 3 operands
    ;-----------------------
    mov     r12, [rts_tos]
    ;-----------------------
    mov     rax, SYS_WRITE          ; syscall #1 = write
    mov     rdi, [write_fd]
    mov     rdx, [r12]              ; how many bytes?
    ;-----------------------
    sub     r12, 0x08
    mov     r9, [r12]
    lea     rsi, [r12 - 0x08]
    sub     rsi, r9                 ; pop off params, start writing rsi # bytes below
    syscall
    ;-----------------------
    mov     [r12], rax              ; result of syscall pushed on stack
    mov     [rts_tos], r12
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_83
    jmp     error_need_mult_operands


open_file_trunc:              ; expects name on top of stack, replaces this with syscall rax
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [r12]
    mov     rsi, 0x0241             ; O_CREAT | O_WRONLY | O_TRUNC
    call    open_file_write
    ;-----------------------
    mov     [r12], rax              ; return val from syscall pushed on
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_62
    jmp     error_need_1_operand

open_file_append:           ; expects name on top of stack, replaces this with syscall rax
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     r12, [rts_tos]
    mov     rdi, [r12]
    mov     rsi, 0x0441             ; O_CREAT | O_WRONLY | O_APPEND
    call    open_file_write
    ;-----------------------
    mov     [r12], rax              ; return val from syscall pushed on
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_221
    jmp     error_need_1_operand

open_file_write:                ; filename on rdi, rsi has params to trunc or append
    ;-----------------------
    cmp     qword [write_fd], NULL  ; check is file desc already open?
    jz      .openCreateFile
    ;-----------------------
    printLine   fileCreateError     ; file desc already used!
    leave
    jmp     exit
    ;---------------------------
    .openCreateFile:
    mov     rax, SYS_OPEN
    mov     rdx, 0x01b6       ; 0q666 octal permissions in case O_CREAT has to create it
    syscall
    ;-----------------------
    mov     [write_fd], rax       ; save file descriptor
    ;sub    qword [rts_tos], 0x08 ; dont move stack pointer, push the syscall return val
    ;-----------------------
    ret

close_file_write:               ; close the [write_fd] and set to NULL
    ;-----------------------    ; close file_desc
    cmp     qword [write_fd], NULL  ; check if fd already held here?
    je      .finish
    ;-----------------------
    mov     rax, SYS_CLOSE
    mov     rdi, [write_fd]
    syscall
    ;-----------------------
    mov     qword [write_fd], NULL  ; set to NULL for next time
    ;-----------------------
    .finish:
    xor     ebx, ebx
    ret

write_to_file:                      ; ptr top of stack, write it (uses length)
    ;-----------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;-----------------------
    mov     r8, [rts_tos]
    mov     rdi, [r8]              ; string ptr
    ;-----------------------
    call    str_len                ; call str len directly!! not through prev func!!
    mov     rdx, rax               ; length for write (rax=length)
    ;-----------------------
    mov     rax, SYS_WRITE         ; sys_write = 1
    mov     rdi, [write_fd]
    mov     rsi, [r8]              ; buffer
    syscall
    ;-----------------------
    mov     rsi, [rts_tos]
    mov     [rsi], rax              ; replace ptr with syscall return val
    xor     ebx, ebx
    ;-----------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_63
    jmp     error_need_1_operand

write_bytes_file:                   ; n bytes & ptr, write it
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    mov     rdx, [r12]               ; number of bytes to write
    mov     rsi, [r12 - 0x08]        ; ptr
    ;-----------------------
    mov     rax, SYS_WRITE
    mov     rdi, [write_fd]
    syscall
    ;-----------------------
    sub     r12, 0x08
    mov     [rts_tos], r12
    mov     [r12], rax              ; overwrite ptr with return val syscall
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_97
    jmp     error_need_mult_operands

write_NL_file:
    ;-----------------------
    cmp     qword [write_fd], NULL
    jz      .ended                  ; don't write if fd == NULL
    ;-----------------------
    mov     rax, SYS_WRITE
    mov     rdi, [write_fd]
    mov     rsi, newLine
    mov     rdx, 0x01
    syscall
    ;-----------------------
    .ended:
    xor     ebx, ebx
    ret


write_8_bytes:
    push    rbp
    mov     rbp, rsp
    ;----------------------------------
    mov     r8, [rts_tos]
    cmp     r8, rts
    jl      .prepare_for_error
    mov     rsi, r8                 ; ptr to the double on stack
    ;----------------------------------
    mov     rax, SYS_WRITE
    mov     rdi, [write_fd]
    mov     rdx, 0x08               ; 8 bytes
    syscall
    ;----------------------------------
    sub     qword [rts_tos], 0x08   ; pop the float
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_222
    jmp     error_need_1_operand


digits_in_string:
    ;----------------------------------
    ; pass on rdi the number
    ; return rax, # of digits
    ; return rbx, 1 = -ve, 0 = +ve
    ; return rsi, num in +ve form
    ;----------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------------
    xor     r8, r8
    xor     rbx, rbx
    ;----------------------------------
    cmp     rdi, NULL
    jge     .isPositive
    neg     rdi                     ; make -ve number +ve
    inc     rbx                     ; it's a -ve number
    ;----------------------------------
    .isPositive:
    xor     r8, r8
    xor     r9, r9
    ;----------------------------------
    add     r9, 0x0a                ; begin with 10 then X 10 each iteration
    inc     r8
    ;----------------------------------
    .checkAllDigits:
        cmp     r8,  0x14           ; error if > 20 digits (largest unsigned# = 18,446,744,073,709,551,615)
        jg      .badDigit
        ;----------------------------------
        cmp     rdi, r9
        jl      .digitSizeFound
        ;----------------------------------
        inc     r8                  ; # of digits is increased
        ;----------------------------------
        mov     rsi, r9
        shl     rsi, 0x03           ; r9 * 8
        shl     r9,  0x01           ; r9 * 2
        add     r9,  rsi            ; (n * 2) + (n * 8) = n * 10
        ;----------------------------------
        jmp     .checkAllDigits
    ;----------------------------------
    .badDigit:
    printLine numberIsBad
    leave                           ; clean this stack frame!
    jmp     exit
    ;----------------------------------
    .digitSizeFound:
    mov     rax, r8                 ; return # of digits in rax
    mov     rsi, rdi
    ;----------------------------------
    leave
    ret

cast_int_to_str:
    push    rbp
    mov     rbp, rsp
    ;----------------------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error          ; FIX THIS ERROR! NEEDS TO BE 1 ELEMENT NEEDED!
    ;----------------------------------
    sub     rsp, 0x30                   ; space for 6 * 8 (48)
    ;----------------------------------
    ; [rbp -  8] --> +/-ve FLAG,
    ; [rbp - 16] --> number in +ve form
    ; [rbp - 24] --> # of digits we convert to ASCII
    ; [rbp - 32] --> divisor  10 ^n (1, 10, 100, 1,000, 10,000 etc)
    ; [rbp - 40] --> ptr to heap alloc, moves +1byte
    ; [rbp - 48] --> fixed ptr to heap alloc
    ;----------------------------------
    mov     rdx, [rts_tos]
    mov     rdi, [rdx]
    call    digits_in_string
    ;----------------------------------
    mov     [rbp - 0x08], rbx   ; 0/1 for +/-ve number
    mov     [rbp - 0x10], rsi   ; get number in +ve form
    mov     [rbp - 0x18], rax   ; # of digits we need for string malloc

    xor     rdi, rdi
    mov     [rbp - 0x20], rdi   ; divisor
    inc     qword [rbp - 0x20]  ; clear and set divisor to 1
    ;----------------------------------
    xor     rbx, rbx                ; counter 0 ---> N
    inc     rbx
    sub     qword [rts_tos], 0x08   ; remove the int from rts_tos
    ;----------------------------------
    .setDivisor:
        cmp     rbx, [rbp - 0x18]
        jge     .divisorBeenSet
        ;----------------------------------
        xor     rax, rax
        mov     rax, [rbp - 0x20]
        xor     rdx, rdx
        xor     rcx, rcx
        ;---------------------------
        or      rcx, 0x0a
        imul    rcx
        mov     [rbp - 0x20], rax
        inc     rbx
        ;----------------------------------
        jmp     .setDivisor

    .divisorBeenSet:                    ; malloc amount of bytes we need
    mov     rdi, [rbp - 0x18]
    inc     rdi                         ; need extra byte for '\0'
    ;----------------------------------
    cmp     qword [rbp - 0x08], 0x01    ; is it a -ve number?
    jne     .mallocBytes
    inc     rdi                         ; need extra byte for sign
    ;----------------------------------
    .mallocBytes:
    call_libc malloc
    mov     [rbp - 0x28], rax           ; scan ptr on heap alloc
    mov     [rbp - 0x30], rax           ; fixed ptr to start of heap alloc
    ;----------------------------------
    cmp     qword [rbp - 0x08], 0x01    ; is it a -ve number?
    jne     .insertDigits
    ;----------------------------------
    mov     r8, [rbp - 0x28]
    mov     byte  [r8], 0x2d            ; 0x2d = 45 = '-' sign
    inc     qword [rbp - 0x28]          ; move ptr 1 byte ahead now
    ;----------------------------------
    .insertDigits:
        cmp     qword [rbp - 0x18], NULL
        jle     .ended
        ;---------------------------------- divide the number by divisor
        xor     rdx, rdx
        xor     rdi, rdi
        mov     rax,  [rbp - 0x10]
        idiv    qword [rbp - 0x20]
        ;----------------------------------
        add     rax, 0x30                   ; 0x30 = +48 to convert digit to ASCii digit
        mov     r8, [rbp - 0x28]
        mov     byte [r8], al               ; update the heap
        sub     rax, 0x30                   ; -48 (0x30) to get back to 0-9
        ;---------------------------------- ; reduce the number by (rax * divisor)
        xor     rdx, rdx
        imul    qword [rbp - 0x20]
        sub     qword [rbp - 0x10], rax
        ;---------------------------------- ; below we divide by 10
        xor     rdx, rdx
        mov     rax, [rbp - 0x20]
        mov     rdi, 0x0a                   ; 10
        idiv    rdi                         ; divide by ten
        ;----------------------------------
        mov     [rbp - 0x20], rax           ; reduce the divisor
        ;----------------------------------
        inc     qword [rbp - 0x28]          ; move ptr 1 byte ahead now
        dec     qword [rbp - 0x18]          ; dec # of iterations
        ;----------------------------------
        jmp     .insertDigits

    .ended:
    mov     r8, [rbp - 0x28]
    mov     byte  [r8], NULL
    mov     rdi, [rbp - 0x30]
    call    push_on                         ; string has been allocated & set, now push on rts
    ;----------------------------------
    xor     ebx, ebx
    ;----------------------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_61
    jmp     error_need_1_operand

print_nl:
    printLine testNL
    xor     ebx, ebx
    ret

rand_int:
    ;------------------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;------------------------------
    mov     rbx, [r12]          ; grab range from top of stack
    mov     rax, 0x02           ; default to 2
    cmp     rbx, 0x02
    cmovl   rbx, rax            ; if rbx < 2, rbx = 2
    ;------------------------------
    mov     rax, [lcg_state]
    mov     rcx, 0x5851F42D4C957F2D
    imul    rax, rcx
    mov     rcx, 0x14057B7EF767814F
    add     rax, rcx
    ;------------------------------
    mov     [lcg_state], rax    ; save new state
    ;------------------------------ no division
    mov     rdx, rax
    shr     rdx, 0x20           ; rdx = high 32 bits of LCG state (0..2^32-1)
    mov     rcx, rbx            ; range
    mul     rcx                 ; rax = low64 (high32 * range), rdx = high64 (high32 * range)
                                ; rdx now gonna be in range 0..range-1
    ;------------------------------
    mov     [r12], rdx          ; store result
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_60
    jmp     error_need_1_operand

random_string:
    ;------------------------------
    ;   generate random string for testing code, TOS = size of string to malloc.
    ;   rax = addr of buffer
    ;   r14 = # of chars to generate, <= 0 defaults to 8 chars!
    ;   only use ascii chars from 33 --> 126
    ;------------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r14, [rdi]
    cmp     r14, NULL
    jg     .start_random
    ;------------------------------
    mov     r14, 0x08           ; default size
    ;------------------------------
    .start_random:
    mov     rdi, r14
    inc     rdi
    call_libc malloc
    mov     r13, rax
    ;------------------------------
    mov     rbx, [lcg_state]            ; rbx --> LCG state
    mov     r10, 0x5851F42D4C957F2D
    mov     r11, 0x14057B7EF767814F
    ;------------------------------
    .loop:
        ;------------------------------; update LCG state
        imul    rbx, r10
        add     rbx, r11
        ;------------------------------; map rbx state to ascii
        mov     r8, rbx
        shr     r8, 0x20                ; 1) keep upper 32 bits
        imul    r8, 0x1a                ; 2) * 26 = 26 * (2^32)
        shr     r8, 0x20                ; 3) leaves us (0..25)
        add     r8b, 0x61               ; 4) +97 = set range (a..z)
        mov     byte [r13], r8b
        ;------------------------------
        inc     r13
        dec     r14                     ; counter--
        jnz     .loop
    ;------------------------------
    .done:
    mov     byte [r13], NULL
    mov     rdi, [rts_tos]
    mov     [rdi], rax              ; push string on stack
    mov     [lcg_state], rbx        ; save the new state
    ;------------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_95
    jmp     error_need_1_operand

null_out_heap:                      ; rdi = ptr to heap, rdx = # of qwords to null out
    ;------------------------------ ; null out 8 regs for bulk clearing
    xor     r8, r8
    xor     r9, r9
    xor     r10, r10
    xor     r11, r11
    xor     rax, rax
    xor     rbx, rbx
    xor     rcx, rcx
    xor     rsi, rsi
    ;------------------------------
    .loop_bulk_8_bytes:
        cmp     rdx, 0x08            ; can we do a bulk null out?
        jb      .loop_remaining      ; if < 8, then jmp to cleanup loop
        ;------------------------------
        mov     [rdi],        r8
        mov     [rdi + 0x08], r9
        mov     [rdi + 0x10], r10
        mov     [rdi + 0x18], r11
        mov     [rdi + 0x20], rax
        mov     [rdi + 0x28], rbx
        mov     [rdi + 0x30], rcx
        mov     [rdi + 0x38], rsi
        ;------------------------------
        add     rdi, 0x40              ; heap pointer += 64 bytes
        sub     rdx, 0x08              ; counter -= 8
        jmp     .loop_bulk_8_bytes
    ;------------------------------
    .loop_remaining:
        test    rdx, rdx            ; rdx < 8 ? null out remaining qwords
        jz      .done               ; finish when 0
        ;------------------------------
        mov     [rdi], r8
        add     rdi, 0x08
        dec     rdx
        jmp     .loop_remaining
        ;------------------------------
    .done:
    ret

open_user_file:             ; rdi has filename on
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;-----------------------
    sub     rsp, 0x90           ; make space for 144 bytes
    ;-----------------------      open the file, syscall #2
    mov     rdi, [rsi]
    mov     rax, SYS_OPEN
    xor     rsi, rsi            ; read-only
    syscall
    ;-----------------------
    test    rax, rax
    jns     .getByteSize        ; jmp if -ve sign flag is NOT set
    ;-----------------------
    mov     r8, [rts_tos]
    printLine   fileOpenErr, [r8]
    leave
    jmp     exit_error_cleanly  ; exit
    ;-----------------------
    .getByteSize:               ; gets byteSize of file
    mov     rbx, rax            ; save file desc
    mov     rax, SYS_FSTAT      ; sys_fstat
    mov     rdi, rbx            ; file desc
    mov     rsi, rsp            ; rsi = stack space
    syscall                     ; call fstat
    ;-----------------------    ; get the size
    mov     r12, [rsp + 0x30]   ; st_size is at offset + 48 bytes
    ;-----------------------    opens file in case its null bytes but has data
    .handleNullByteFileSize:
    test    r12, r12
    jnz     .isNotZero          ; some files (esp system) report NULL byte file size, handle them...
    ;-----------------------    ; if NULL bytes size, lets default to 4095 bytes + 1 byte after
    mov     r12, 0x0fff
    ;-----------------------
    .isNotZero:
    inc     r12                 ; 4096 to allow for \0
    mov     [f_byte_size], r12
    ;----------------------- allocate heap
    mov     rdi, r12
    call_libc malloc
    mov     r13, rax            ; save heap alloc
    ;--------------------------------   if bytes = 4096, then null them out else valgrind moans
    cmp     r12, 0x1000         ; cmp 4096
    jne     .copyToHeap
    ;-----------------------
    .null_out_4096:
    xor     r8, r8
    mov     rdi, r13            ; null out 4096 bytes
    mov     rcx, 0x200          ; 512 = 4096 / 8
    ;-----------------------
    .null_loop:
        mov     [rdi], r8       ; null 8 bytes
        add     rdi, 0x08       ; ptr += 8
        loop    .null_loop      ; rcx-- and jmp != null
    ;-----------------------
    .copyToHeap:
    mov     rax, SYS_READ
    mov     rdi, rbx
    mov     rsi, r13
    lea     rdx, [r12 - 0x01]
    syscall
    ;----------------------- add '\0' term to str
    mov     byte [r13 + rax], NULL
    ;----------------------- close file descriptor
    mov     rax, SYS_CLOSE
    mov     rdi, rbx
    syscall
    ;-----------------------
    sub     qword [rts_tos], 0x08   ; remove filename from rts_tos
    mov     rdi, r13                ; place heap alloc to file contents on rts_tos
    call    push_on
    ;-----------------------
    xor     ebx, ebx
    ;-----------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_57
    jmp     error_need_1_operand


strip_out_comments:
    push    rbp
    mov     rbp, rsp
    ;--------------------------------
    cmp     qword [debug_mode], NULL
    je      .skipHeader
    printLine commentsRemoved
    ;--------------------------------
    .skipHeader:
    sub     rsp, 0x08
    ;--------------------------------
    mov     rdi, qword [size_of_file]
    inc     rdi
    mov     r12, rdi                        ; needed for null out
    call_libc malloc
    ;--------------------------------
    mov     qword [rbp - 0x08], rax         ; store heap alloc
    mov     rbx, rax
    ;--------------------------------
    xor     r8, r8
    mov     rcx, r12
    shr     rcx, 0x03                       ; divide by 8
    jz      .less_than_8_bytes              ; handle < 8 bytes
    ;--------------------------------
    .null_out_mem:
        mov     [rax + rcx * 0x08 - 0x08], r8
        dec     rcx
        jnz     .null_out_mem               ; not jnz as we need to null [0] too
    ;--------------------------------
    mov     [rax + r12 - 0x08], r8          ; end - 8 bytes will fill remaining bytes
    jmp     .heap_null_done
    ;--------------------------------
    .less_than_8_bytes:
        dec     r12
        mov     byte [rax + r12], r8b
        jns     .less_than_8_bytes
    .heap_null_done:
    ;--------------------------------
    mov     rax, rbx
    mov     rbx, [heap_alloc_file]
    ;--------------------------------
    xor     r12, r12                        ; FLAG for SPEECH MARKS, r12 = 0 --> not seen '"', 1 --> have seen a '"'
    ;--------------------------------       ; rax = new string being built, rbx = orig string including comments
    .justGrabTheCode:
        cmp     byte [rbx], NULL            ; reached EOS yet?
        je      .EOS_reached
        ;--------------------------------
        cmp     byte [rbx], speechQuote
        jne     .comment_check
        ;--------------------------------
        xor     r12, 0x01                       ; toggle speech mark FLAG
        ;--------------------------------
        .comment_check:
        cmp     byte [rbx], comment             ; found a ';' ?
        jne     .nonComment
        ;--------------------------------
        test    r12, r12
        jnz     .nonComment                     ; meaning we're in a quote " ??? ", we grab the ; as well
        ;--------------------------------
        .foundAComment:                         ; we have a ';' now scan until EOS or '\n'
            cmp     byte [rbx], NEW_LINE        ; 0x0a newline?
            je      .nonComment
            ;--------------------------------
            cmp     byte [rbx], NULL
            je      .EOS_reached
            ;--------------------------------
            cmp     qword [debug_mode], NULL
            je      .noDebugging
            push    rax
            movzx   rcx, byte [rbx]             ; else valgrind moans if comments are at end of source file
            printLine   debugCharSameLine, rcx
            pop     rax
            .noDebugging:
            inc     rbx
            jmp     .foundAComment
        ;--------------------------------
        .nonComment:
        movzx   r9, byte [rbx]
        ;--------------------------------
        cmp     r9b, backSlash          ; a backslash?
        jne     .reg_char               ; no? Just cpy it.
        ;-------------------------------- escape found? need to check
        movzx   r10, byte [rbx + 0x01]  ; get char after '\'
        test    r10b, r10b
        jz      .reg_char               ; EOS check, is '\' at end of string?, if it is, just copy it
        ;--------------------------------
        movzx   r11, byte [ascii_esc_table + r10]   ; check look up table
        test    r11b, r11b              ; is it a char we've marked? \n, \t \v etc?
        jz      .reg_char               ; r9 still has the '\' char, so write this byte
        ;-------------------------------- look up table has an entry, now write the byte
        .escape_char_found:
        movzx   r9, byte r11b           ; write the REAL byte e.g '\n' --> 0x0a
        inc     rbx                     ; skip the '\' and in a few lines the char 'n' will be skipped too
        ;--------------------------------
        .reg_char:
        mov     byte [rax], r9b
        inc     rax
        inc     rbx
        jmp     .justGrabTheCode
    ;--------------------------------
    .EOS_reached:
    mov     byte [rax], NULL
    ;--------------------------------
    .freeStringWithComments:
    mov     rdi, [heap_alloc_file]
    call_libc free
    ;--------------------------------
    mov     rdi, [rbp - 0x08]
    mov     [heap_alloc_file], rdi
    ;--------------------------------
    test    r12, r12                        ; is the end speech quote still open?? " ???
    jz      .ended
    ;--------------------------------
    printLine   error_missing_quote_msg, [heap_alloc_file]
    jmp     exit
    .ended:
    leave
    ret


define_struct:
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]                      ; get the string address
    call    does_var_already_exist
    ;-------------------------
    test    rax, rax
    jnz     .alreadyDef
    ;-------------------------
    add     qword [dict_tos], 0x08
    mov     rdi, 0x12                       ; 18 because we need 1 more byte for # of qword in struct
    call_libc malloc
    ;-------------------------
    mov     rbx, rax                        ; copy of heap
    mov     rsi, [dict_tos]
    mov     [rsi], rax                      ; insert malloc into dict
    ;-------------------------              ; are we in main or a function?
    cmp     qword [func_name_tos], func_name
    jge     .build_var
    ;-------------------------              ; definitely in main _start, is this first global we added?
    mov     qword [last_glob_var], rsi
    ;-------------------------
    .build_var:                             ; add id/name/type for var
    ; ------------------------
    lea     rdi, [r12 - 0x08]               ; move down to # of items in struct
    mov     r8, [rdi]                       ; grab the value
    ;-------------------------
    lea     rdi, [r12 - 0x10]               ; get the heap alloc containing all items
    mov     r9, [rdi]
    ;-------------------------
    mov     [rbx], r14                      ; id
    mov     [rbx + 0x08], r9                ; heap alloc with all data
    mov     byte [rbx + 0x10], 0x02         ; specify struct = 2
    mov     byte [rbx + 0x11], r8b          ; # of qwords in struct
    ;-------------------------
    lea     rdi, [r12 - 0x18]
    mov     [rts_tos], rdi                  ; adjust top of stack -16 bytes
    ;-------------------------
    .completed:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_52
    jmp     error_need_mult_operands

    .alreadyDef:
    printLine varExistsError, r14
    call    deallocate_mem_tidy_up
    leave
    jmp     exit


packed_data:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    mov     r12, [rdi]          ; # of qword we need to pack
    call    pop_off
    ;-----------------------
    mov     rdi, r12
    shl     rdi, 0x03
    call_libc malloc
    ;-----------------------
    mov     r14, rax
    xor     r13, r13
    ;-----------------------
    .copyValues:
        cmp     r13, r12
        jge     .ended
        ;-----------------------
        mov     rsi, [rts_tos]
        mov     r15, [rsi]
        ;-----------------------
        mov     [r14 + r13 * 0x08], r15
        sub     qword [rts_tos], 0x08
        ;-----------------------
        inc     r13
        jmp     .copyValues
    .ended:
    ;-----------------------
    mov     rdi, r14
    call    push_on
    ;-----------------------
    mov     rdi, r12        ; added this part, push onto rts_tos # of qword's we have in struct
    call    push_on
    ;-----------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_51
    jmp     error_need_mult_operands

get_struct_sz:
    ;------------------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r12, [rts_tos]
    mov     r14, [r12]
    call    does_var_already_exist      ; expects r14 with string to cmp
    ;------------------------------
    test    rax, rax
    jz      .notStructErr
    ;------------------------------
    movzx   rdi, byte [r11 + 0x11]      ; does_var_already_exist gave us r11 (ptr to var), +17 = struct sz
    mov     [r12], rdi                  ; replace var name with struct sz
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .notStructErr:
    printLine   notAStruct, r14
    jmp     exit_error_cleanly
    ;------------------------------
    .prepare_for_error:
    mov     rsi, operator_69
    jmp     error_need_1_operand


clean_up_heap:
    push    rbp
    mov     rbp, rsp
    ;-------------------------------
    cmp     qword [debug_mode], NULL
    je      .cleanFuncLoop
    printLine   dashes2
    printLine   cleaningFuncs
    ;-------------------------------
    .cleanFuncLoop:
        cmp     qword [funcs_tos],  funcs
        jl      .headerGlobVars
        ;-------------------------------
        mov     rbx, [funcs_tos]
        mov     r8, [rbx]
        ;-------------------------------
        mov     rdi, [rbx]
        test    rdi, rdi
        jz      .nextFunc
        ;-------------------------------
        cmp     qword [debug_mode], NULL
        je      .freeFunc
        printLine freeingMem, [r8], [rbx]
        ;-------------------------------
        .freeFunc:
        mov     rdi, [rbx]
        call_libc free
        ;-------------------------------
        .nextFunc:
        sub     qword [funcs_tos], 0x08
        jmp     .cleanFuncLoop
    ;-------------------------------
    .headerGlobVars:
    cmp     qword [debug_mode], NULL
    je      .cleanGlobVars
    printLine   dashes2
    printLine   cleaningGlobVars
    ;-------------------------------
    .cleanGlobVars:
        cmp     qword [dict_tos], dict
        jl      .prepCleanARGV
        ;-------------------------------
        mov     rbx, [dict_tos]
        mov     r8, [rbx]
        ;-------------------------------    ; FAR TOO RISKY, DON'T BOTHER!!!
        ; mov   rdi, [rbx]
        ; test  rdi, rdi
        ; jz        .nextVar
        ; ;----------------------
        ; ; for global vars, check if the string points to somewhere in ARGV?
        ; ; if it does, then fine, otherwise it's been created in this function with read_str probably.
        ; ; so it needs to be deleted from heap
        ; ;----------------------
        ; mov   r8, [rbx]
        ; add   r8, 0x10
        ; cmp   byte [r8], 0x01             ; r8 has variable type. int = 0, str = 1, struct = 2
        ; jne       .nextVar                    ; will need to think about structs too?
        ; ;------------------------------       ; we could handle struct here??!? or let user deal with it?
        ; ;cmp  byte [r8], 0x02
        ; ;jne      .handleStrings
        ; ;------------------------------        ** wrong/bad/dangerous way to handle this!! **
        ; .handleStrings:                       ; will fix and change this totally. can't assume strings
        ; mov   rdi, [rbx]                  ; can be removed here, let user do that!!
        ; add   rdi, 0x08
        ; mov   rdi, [rdi]
        ; call  scanARGVstrings
        ; ;-------------------------------
        ; test  rax, rax
        ; jnz       .freeBlock
        ; ;-------------------------------
        ; mov   r8, [rbx]
        ; add   r8, 0x08
        ; cmp   qword [debug_mode], NULL
        ; je        .skipNotInARGV
        ; ;-------------------------------
        ; printLine notInARGV, [r8], [r8]
        ; .skipNotInARGV:
        ; mov   rdi, [rbx]
        ; add   rdi, 0x08
        ; push  rdi
        ; mov   rdi, [rdi]
        ; call_libc free        ; this is the string that doesnt exist anywhere else!!
        ; ;-------------------------------
        ; pop   r8
        ; mov   qword [r8], NULL
        ; ;----------------------------------
        cmp     byte [r8 + 0x10], 0x02  ; r8 has variable type. int = 0, str = 1, struct = 2, float = 3
        jne     .freeBlock
        ;----------------------------------
        .cleanStruct:
        mov     rdi, [r8 + 0x08]        ; + 8 bytes is where the heap block for all the data is kept
        call_libc free
        ;----------------------------------
        .freeBlock:
        cmp     qword [debug_mode], NULL
        je      .freeBlockGLOB
        ;-------------------------------
        mov     r9, [rbx]
        printLine freeingMemGlobal, [r9], [rbx]
        .freeBlockGLOB:
        mov     rdi, [rbx]
        call_libc free
        ;-------------------------------
        .nextVar:
        sub     qword [dict_tos], 0x08
        jmp     .cleanGlobVars
    ;-------------------------------
    .prepCleanARGV:
    mov     r15, [argv_ptr]
    xor     r12, r12
    ;-------------------------------
    cmp     qword [debug_mode], NULL
    je      .cleanARGV
    printLine   dashes2
    printLine   cleaningARGV
    ;-------------------------------
    .cleanARGV:
        cmp     r12, [argv_len]
        je      .ended
        ;-------------------------------
        mov     r13, [r15 + r12 * 0x08]
        test    r13, r13
        jz      .nextOne
        ;-------------------------------
        cmp     qword [debug_mode], NULL
        je      .freeBlockARGV
        ;-------------------------------
        printLine freeingMem3, r12, r13
        .freeBlockARGV:
        mov     rdi, r13
        call_libc free
        ;-------------------------------
        .nextOne:
        inc     r12
        jmp     .cleanARGV
    .ended:
    ;-------------------------------    ; clean-up the hashset memory for operators
    .cleanOperatorHashset:
    ;-------------------------------
    leave
    ret


copy_these_bytes:
    ;----------------------------------------------------------------------------
    ; # of bytes to copy on TOS, dest ptr TOS - 1, source ptr TOS - 2, all popped off afterwards
    ;----------------------------------------------------------------------------
    call    elements_in_stack
    cmp     rax, 0x03
    jl      .prepare_for_error
    ;----------------------------
    mov     rcx, [rts_tos]
    mov     rdx, [rcx]
    ;----------------------------
    xor     r8, r8
    cmp     rdx, r8
    cmovl   rdx, r8                 ; if # of bytes < 0 set to 0
    ;----------------------------
    mov     rdi, [rcx - 0x08]
    mov     rsi, [rcx - 0x10]
    ;----------------------------
    lea     rbx, [rcx - 0x18]
    mov     [rts_tos], rbx
    ;----------------------------
    call    copy_bytes
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_85
    call    error_need_mult_operands

copy_bytes:
    ;-------------------------------------------------------------------
    ; ** THIS IS RISKY/DANGEROUS ** make sure you term string '\0' else risk seg-fault
    ; rdi = dest, rsi = source, rdx = #bytes to copy from source --> dest
    ;-------------------------------------------------------------------
    test    rdx, rdx            ; check count before we start
    jz      .finished
    ;-------------------------------
    .copying:
        mov     r8b, [rsi]
        mov     [rdi], r8b
        ;-------------------------------
        inc     rsi
        inc     rdi
        dec     rdx            ; --count updates zf
        jnz     .copying
    ;-------------------------------
    .finished:
    ret

update_str:
    ;---------------------------------------------------------------------
    ; ** DANGEROUS ** you can easily remove the '\0' EOS term. update char/s in a string.
    ; rdi = string on heap, rsi = char/s, rdx = index we want to modify char/s from..
    ;---------------------------------------------------------------------
    lea     r8, [rts + 0x10]
    mov     rsi, [rts_tos]
    cmp     rsi, r8
    jl      .prepare_for_error
    ;----------------------------
    mov     r10, [rsi]                  ; number of bytes from start of string to modify (will add checks later!)
    cmp     r10, NULL
    jns     .start_calc                 ; -ve value?
    ;----------------------------
    xor     r10, r10                    ; then set to 0
    ;----------------------------
    .start_calc:
    mov     r9, [rsi - 0x08]            ; string we read from to update heap
    mov     r11, [rsi - 0x10]           ; string on heap we modify
    add     r11, r10
    ;----------------------------
    mov     rdi, r9
    call    str_len                     ; returns on rax the # of bytes
    mov     rdx, rax                    ; number of bytes to modify
    ;----------------------------
    mov     rdi, r11                    ; dest
    mov     rsi, r9                     ; source
    call    copy_bytes
    ;----------------------------
    .ended:
    sub     qword [rts_tos], 0x10       ; pop off everything APART from modified string
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_50
    jmp     error_need_mult_operands


copy_str:
    ;-----------------------
    ; creates a new copy of the heap alloc str and puts this on top of stack.
    ; address we used to copy remains below this new heap address
    ;-----------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;-----------------------
    mov     r12, [rts_tos]
    mov     rdi, [r12]
    call    str_len
    mov     rbx,  rax                   ; length of string [rts_tos] bytes
    ;-----------------------
    lea     rdi, [rax + 0x01]           ; for the null byte
    call_libc malloc
    ;-----------------------
    mov     rdi, rax
    mov     rsi, [r12]
    mov     rdx, rbx
    call    copy_bytes
    ;-----------------------            ; add term '\0'
    mov     byte [rdi], NULL
    add     r12, 0x08
    mov     [r12], rax
    mov     [rts_tos], r12              ; fix top of stack ptr
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_49
    jmp     error_need_1_operand


append_str:             ; ["foo! ","bar!"] both popped off  --> new string pushed ["foo! bar!"]
    ;-----------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;-----------------------
    lea     r13, [r12 - 0x08]
    mov     [rts_tos], r13          ; pop off and get top of stack ready
    ;-----------------------
    mov     rdi, [r12]
    call    str_len
    mov     r14, rax                ; len str1
    ;-----------------------
    mov     rdi, [r13]
    call    str_len
    mov     r15, rax                ; len str2
    ;-----------------------
    lea     rdi, [r14 + r15 + 0x01]
    call_libc malloc
    ;-----------------------
    mov     rdi, rax
    mov     rsi, [r13]
    mov     rdx, r15
    call    copy_bytes              ; copy bottom string 1st
    ;-----------------------        ; rdi stil points to heap at right point!
    mov     rsi, [r12]
    mov     rdx, r14
    call    copy_bytes              ; now copy top of stack string
    ;-----------------------
    mov     byte [rdi], NULL        ; rdi in right pos for EOS term
    mov     [r13], rax
    ;-----------------------
    .finished:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_48
    jmp     error_need_mult_operands


str_len:        ; put on rdi the string and rax has # of bytes excluding '\0'
    xor     rax, rax
    .looping:
        cmp     byte [rdi], NULL
        je      .ended
        ;-------------------
        inc     rax
        inc     rdi
        jmp     .looping
    ;-----------------------
    .ended:
    ret

my_str_len:
    ;-----------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------
    mov     rdi, [rbx]
    ;-----------------------
    call    str_len
    mov     [rbx], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_47
    jmp     error_need_1_operand


str_compare_u:                      ; operator name --> cmp_str_u
    ;-----------------------
    mov     r11, [rts_tos]
    cmp     r11, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rsi, [r11]
    mov     rdi, [r11 - 0x08]
    call    my_str_cmp_u            ; use unsigned logic
    ;-----------------------
    lea     rcx, [r11 - 0x08]
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_232
    jmp     error_need_mult_operands


my_str_cmp_u:
    ;-----------------------
    .checking:
        mov     byte al, byte [rdi]
        mov     byte dl, byte [rsi]
        ;-----------------------
        cmp     byte al, byte dl
        jne     .lastCheck
        ;-----------------------
        test    al, al
        jz      .matched
        ;-----------------------
        inc     rdi
        inc     rsi
        jmp     .checking
    ;-----------------------
    .matched:
    xor     rax, rax
    ret
    ;-----------------------
    .lastCheck:
    cmp     byte al, byte dl
    jb      .lessThan               ; jb --> carry/flag (al < dl)
    mov     rax, 0x01               ; if al > dl, return 1
    ret
    ;-----------------------
    .lessThan:
    mov     rax, -1                 ; if al < dl, return -1
    ret


str_compare:
    ;-----------------------
    mov     r11, [rts_tos]
    cmp     r11, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rsi, [r11]
    mov     rdi, [r11 - 0x08]
    call    my_str_cmp
    ;-----------------------
    lea     rcx, [r11 - 0x08]
    mov     [rts_tos], rcx
    ;-----------------------
    mov     [rcx], rax
    xor     ebx, ebx
    ;-----------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_46
    jmp     error_need_mult_operands


my_str_cmp:                     ; pass strings on rdi and rsi, rax = 0 for match, -1 <, 1 >
    ;-----------------------
    .checking:
        mov     byte al, byte [rdi]
        test    al, al                      ; check for EOS ?
        jz      .lastCheck                  ; if null, go to last check
        ;-----------------------
        cmp     byte al, byte [rsi]
        jne     .lastCheck
        ;-----------------------
        inc     rdi
        inc     rsi
        jmp     .checking
    ;-----------------------
    .lastCheck:
    xor     rax, rax
    mov     byte r8b, [rdi]
    sub     byte r8b, [rsi]                 ; sub has updated the zf & sf
    js      .lessThan                       ; if sub went -ve, the sf is set
    jz      .ended                          ; zf = equal
    ;-----------------------
    or      rax, 0x01
    jmp     .ended
    ;-----------------------
    .lessThan:
    or      rax, -1
    ;-----------------------
    .ended:
    ret

str_compare_i:
    ;-----------------------
    mov     rdx, [rts_tos]
    cmp     rdx, rts
    jle     .prepare_for_error
    ;-----------------------
    mov     rsi, [rdx]
    mov     rdi, [rdx - 0x08]
    ;-----------------------
    call    my_str_cmp_i
    mov     rdi, [rts_tos]
    sub     rdi, 0x08
    mov     [rdi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_215
    jmp     error_need_mult_operands


my_str_cmp_i:                       ; pass strings on rdi and rsi
    ;-----------------------
    .checking:
        mov     byte al, [rdi]          ; if char is UPPERCASE switch to lowercase
        mov     byte dl, [rsi]
        ;-----------------------
        cmp     byte al, 0x41           ; ascii 'A'
        jl      .check_next_str
        cmp     byte al, 0x5a           ; ascii 'Z'
        jg      .check_next_str
        ;-----------------------
        or      byte al, 0x20           ; switch to lowercase
        ;-----------------------
        .check_next_str:
        cmp     byte dl, 0x41           ; ascii 'A'
        jl      .cmp_strings
        cmp     byte dl, 0x5a           ; ascii 'Z'
        jg      .cmp_strings
        ;-----------------------
        or      byte dl, 0x20           ; switch to lowercase
        ;-----------------------
        .cmp_strings:
        cmp     byte al, byte dl
        jne     .set_flag               ; !=
        ;-----------------------
        test    byte al, byte al        ; EOS?
        jz      .matched                ; strings matched
        ;-----------------------
        inc     rdi
        inc     rsi
        jmp     .checking
    ;-----------------------
    .matched:
    xor     rax, rax
    ret
    ;-----------------------; needed changing when tested high ascii vals
    .set_flag:
    cmp     byte al, byte dl            ; cmp to check unsign val
    jb      .lessThan                   ; jb uses carry flag
    mov     rax, 0x01
    ret
    ;-----------------------
    .lessThan:
    mov     rax, -1
    ret

tern_func:
    ;--------------------------------
    mov     rdi, [rts_tos]
    lea     rsi, [rdi - 0x10]           ; top of stack will point here
    ;--------------------------------
    cmp     rsi, rts
    jl      .prepare_for_error
    ;--------------------------------
    mov     r8, [rdi]
    mov     [rts_tos], rsi
    ;--------------------------------
    test    r8, r8                      ; was rts_tos 0 or 1?
    jz      .isFalse
    jmp     .ended                      ; leave top of stack -16 bytes all good
    ;--------------------------------
    .isFalse:
    mov     r8, [rsi + 0x08]
    mov     [rsi], r8
    ;--------------------------------
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_45
    jmp     error_need_mult_operands

swap_the_bottom_n:
    ;--------------------------------
    call    elements_in_stack
    ;--------------------------------
    cmp     rax, 0x03                   ; to do the swap, need 2 elements + 1 value on the top
    jl      .prepare_for_error          ; add string later, need MORE than 1 item on stack to swap!
    ;--------------------------------
    mov     r12, [rts_tos]
    mov     r9, [r12]                   ; Grab swap pos, this must be < (stack size - 2) && >= 0
    xor     r8, r8
    test    r9, r9
    cmovs   r9, r8                      ; set to 0 if -ve
    ;--------------------------------
    lea     r8, [rax - 0x03]            ; The largest index we can swap at
    cmp     r9, r8
    cmovg   r9, r8                      ; fix to max index we can swap at
    ;--------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12              ; pop off index to swap at
    ;--------------------------------
    lea     r12, [rts + r9 * 0x08]      ; Jump to index
    lea     r13, [r12 + 0x08]           ; and index above
    ;--------------------------------
    mov     r8, [r12]
    mov     r9, [r13]
    mov     [r12], r9
    mov     [r13], r8
    ;--------------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_44
    jmp     error_need_mult_operands

swap_the_top_n:
    ;--------------------------------
    call    elements_in_stack
    ;--------------------------------
    cmp     rax, 0x03                   ; to do the swap, need 2 elements + 1 value on the top
    jl      .prepare_for_error          ; add string later, need MORE than 1 item on stack to swap!
    ;--------------------------------
    mov     r12, [rts_tos]
    mov     r9, [r12]                   ; Grab swap pos, this must be < (stack size - 2) && >= 0
    xor     r8, r8
    test    r9, r9
    cmovs   r9, r8                      ; set to 0 if -ve
    ;--------------------------------
    lea     r8, [rax - 0x03]            ; The largest index we can swap at
    cmp     r9, r8
    cmovg   r9, r8                      ; fix to max index we can swap at
    ;--------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12              ; pop off index to swap at
    ;--------------------------------
    lea     r10, [r9 * 0x08]            ; Jump to index
    sub     r12, r10
    lea     r13, [r12 - 0x08]           ; and index below
    ;--------------------------------
    mov     r8, [r12]
    mov     r9, [r13]
    mov     [r12], r9
    mov     [r13], r8
    ;--------------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_43
    jmp     error_need_mult_operands

dump_rts_all:
    push    rbp
    mov     rbp, rsp
    ;--------------------------------
    printLine   debug_dump_rts_start
    push    r14
    push    r13
    ;--------------------------------
    xor     r14, r14
    mov     r13, [rts_tos]
    ;--------------------------------
    .looping:
        cmp     r13, rts
        jl      .ended
        ;--------------------------------
        mov     rdi, [r13]
        call    is_address_in_dict
        ;--------------------------------
        test    rax, rax
        jz      .lastCheck
        ;--------------------------------
        cmp     rdx, 0x01
        jl      .printInteger
        jg      .floatOrStruct
        jmp     .printString
        ;--------------------------------
        ; final chech here. is it in the argv list?
        ;--------------------------------
        .lastCheck:
        mov     rdi, [r13]
        call    does_address_exist_in_ARGV
        ;--------------------------------
        test    rax, rax
        jz      .printInteger
        ;--------------------------------
        .printString:
        printLine   dump_rts_string, qword r14, qword [r13] ; has to be string
        jmp     .nextIteration
        ;--------------------------------
        .floatOrStruct:
        cmp     rdx, 0x02
        jg      .printFloat
        ;--------------------------------
        .printStruct:
        printLine   dump_rts_struct, qword r14, qword [r13] ; has to be struct
        jmp     .nextIteration
        ;--------------------------------
        .printFloat:
        mov     rdi, dump_rts_float
        mov     rsi, r14
        movq    xmm0, [r13]
        mov     rax, 0x01
        call_libc printf
        jmp     .nextIteration
        ;--------------------------------
        .printInteger:
        printLine   dump_rts_int, qword r14, qword [r13]
        ;--------------------------------
        .nextIteration:
        sub     r13, 0x08
        inc     r14
        jmp     .looping
    ;--------------------------------
    .ended:
    printLine   debug_dump_rts_ended
    pop     r13
    pop     r14
    ;--------------------------------
    xor     rax, rax
    xor     ebx, ebx
    leave
    ret

does_address_exist_in_ARGV:     ; pass on rdi the address/value within the RTS
                                ; if found rax is 1 = string, otherwise its not!
    push    rbp
    mov     rbp, rsp
    ;------------------------
    sub     rsp, 0x10           ; rbp - 8 = copy of rbx, rbp - 16 = counter
    xor     rax, rax            ; return status
    ;------------------------
    xor     r8, r8
    mov     [rbp - 0x10], r8    ; counter from 0
    mov     [rbp - 0x08], rbx   ; snapshot/copy of rbx
    mov     rbx, [argv_ptr]
    ;------------------------
    xor     r9, r9
    mov     r9, [argv_len]
    dec     r9
    ;------------------------
    .looping:
        cmp     [rbp - 0x10], r9
        je      .ended                  ; not found, return rax = 0
        ;--------------------------------
        mov     r8, [rbp - 0x10]
        cmp     rdi, [rbx + r8 * 0x08]
        ;--------------------------------
        je      .foundMatch
        inc     qword [rbp - 0x10]      ; inc counter
        jmp     .looping
    ;--------------------------------
    .foundMatch:
    inc     rax             ; it's been found
    ;--------------------------------
    .ended:
    mov     rbx, [rbp - 0x08]
    leave
    ret

the_stack_size:     ; how many qword's are on the stack, before we push on this value?
    ;--------------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .empty
    ;--------------------------------
    mov     rdi, rsi
    sub     rdi, rts
    shr     rdi, 0x03
    inc     rdi
    jmp     .addToStack
    ;--------------------------------
    .empty:
    xor     rdi, rdi
    ;--------------------------------
    .addToStack:
    add     rsi, 0x08
    mov     [rsi], rdi
    mov     [rts_tos], rsi
    ;--------------------------------
    xor     ebx, ebx
    ret

not_operator:
    xor     r9, r9                  ; result true/false, default false
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    mov     rsi, [rdi]
    ;--------------------------------
    test    rsi, rsi
    jnz     .ended                  ; rts_tos = true, now inverse it
    inc     r9                      ; rts_tos = false, now inverse it
    ;--------------------------------
    .ended:
    mov     [rdi], r9               ; push result on top of stack
    ;--------------------------------
    xor     ebx, ebx
    ret
    ;--------------------------------
    .prepare_for_error:
    mov     rsi, operator_38
    jmp     error_need_1_operand

or_operator:
    ;--------------------------------
    xor     r9, r9                          ; return status false 0 by default
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;--------------------------------
    mov     r10, [rdi]
    test    r10, r10
    jnz     .found                          ; found != 0 --> true
    ;--------------------------------
    mov     r11, [rdi - 0x08]
    test    r11, r11
    jz      .ended                          ; both != 0 --> false
    ;--------------------------------
    .found:
    inc     r9
    .ended:
    sub     rdi, 0x08
    mov     [rdi], r9
    mov     [rts_tos], rdi
    ;--------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_37
    jmp     error_need_mult_operands


and_operator:
    ;--------------------------------
    xor     r9, r9                          ; return status false 0 by default
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;--------------------------------
    mov     r10, [rdi]
    test    r10, r10
    jz      .ended
    ;--------------------------------
    mov     r11, [rdi - 0x08]
    test    r11, r11
    jz      .ended
    ;--------------------------------
    inc     r9          ; true && true = 1
    .ended:
    sub     rdi, 0x08
    mov     [rdi], r9
    mov     [rts_tos], rdi
    ;--------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_36
    jmp     error_need_mult_operands

does_func_already_exist:            ; rax = 1 if found, rax = 0 if not found
    push    rbp
    mov     rbp, rsp
    ;--------------------------------
    mov     r15, [funcs_tos]
    xor     rbx, rbx                ; pos downwards from [dict_tos]
    ;--------------------------------
    .looping:
        cmp     r15, funcs
        jl      .ended
        ;--------------------------------
        mov     r11, [r15]
        ;--------------------------------
        mov     rdi, r14
        mov     rsi, [r11]
        call    my_str_cmp
        ;--------------------------------
        test    rax, rax
        jz      .found
        ;--------------------------------
        sub     r15, 0x08
        inc     rbx
        jmp     .looping
    ;--------------------------------
    .found:
    inc     rax
    leave
    ret
    ;--------------------------------
    .ended:
    xor     rax, rax
    leave
    ret


call_function:
    push    rbp
    mov     rbp, rsp
    ;--------------------------------------> SETTING UP LOCAL VARIABLES ----------------------------------------------->;
    ; before we do this, are there any local vars already set up? are there any globals set up?                         ;
    ; need to take into account these scenarios....                                                                     ;
    ; last_glob_var is NULL by default, otherwise it has the LAST var created from _start, that being a GLOBAL variable ;
    ;<------------------------------------------------------------------------------------------------------------------;
    mov     r14, [rts_tos]          ; grab func name from rts_tos & locate it!
    cmp     r14, rts
    jl      .prepare_for_error      ; empty stack??
    ;-----------------------
    add     qword [local_dict_tos], 0x08       ; next position
    mov     r8, [dict_tos]
    mov     r13, [local_dict_tos]
    mov     [r13], r8                   ; [local_dict_tos] now has the LAST var from prev func
    ;---------------------------------- ; FASTER!!
    mov     r13, [funcs_tos]            ; start at the top, then -= 8 per iteration
    ;----------------------------------
    .findFuncName:
        cmp     r13, funcs
        jl      .funcUnknown
        ;------------------------------
        mov     rbx, [r13]
        ;------------------------------
        mov     rdi, [rbx]
        mov     rsi, [r14]              ; has func name on rts_tos
        call    my_str_cmp
        ;------------------------------
        test    rax, rax
        jz      .foundName
        ;------------------------------
        sub     r13, 0x08
        jmp     .findFuncName
    ;----------------------------------
    .foundName:
    mov     rdi, [r14]
    mov     rsi, [func_name_tos]
    mov     [rsi + 0x08], rdi
    add     qword [func_name_tos], 0x08
    ;----------------------------------
    mov     r12, [rbx + 0x08]           ; +8 bytes is the code to this func name
    inc     r12
    sub     qword [rts_tos], 0x08       ; remove func name from rts
    ;----------------------------------
    .looping:
        mov     rbx, [token_type]
        cmp     word [rbx + r12 * 0x02], operator_KEYWORD ; < operator_KEYWORD = an OPERATOR. else IGNORE & dont push these on!
        jb      .runOperatorCode                ; is an OPERATOR
        ;----------------------------------
        cmp     word [rbx + r12 * 0x02], operand_KEYWORD ; < operand_KEYWORD is dummy OPERATOR
        jb      .checkForBreak                  ; is an OPERAND or IGNORE?
        ;-----------------------------------
        jmp     .pushOn                         ; is an OPERAND
        ;-----------------------------------
        .checkForBreak:
        cmp     word [rbx + r12 * 0x02], break_KEYWORD  ; break?
        jz      .funcEnded
        ;-----------------------------------
        cmp     word [rbx + r12 * 0x02], break_if_KEYWORD   ; break_if?
        jnz     .returnCheck
        ;-----------------------------------
        mov     r11, [rts_tos]
        sub     qword [rts_tos], 0x08       ; remove the TOS value. if !=0 this function ends. if == 0 we carry on checking
        ;------------------------------
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        jne     .funcEnded
        jmp     .carryOn
        ;------------------------------
        .returnCheck:
        cmp     word [rbx + r12 * 0x02], return_KEYWORD ; return?
        jz      .funcEnded
        jmp     .carryOn
        ;------------------------------
        .runOperatorCode:
        push    r15
        push    r12
        ;------------------------------
        movzx   rcx, word [rbx + r12 * 0x02]
        call    [map_funcs + rcx * 0x08]
        ;lea        r8, [rbx + r12 * 0x02]
        ;lea        r9, [map_funcs + rcx * 0x08]    ; STRANGE!! faster here but not in do code!!! vice versa for direct call below!!
        ;call   [r9]
        ;----------------------------------
        .encounteredBreak2:
        cmp     qword [break_flag], qword 0x01  ; have we hit a break statement?
        jne     .nextToken
        ;------------------------------         ; we've hit a 'break' statement from { if_else_loop }
        mov     qword [break_flag], NULL        ; re-set this break_flag
        jmp     .funcEnded
        ;----------------------------------
        .nextToken:
        test    rbx, rbx
        jz      .popCarryOn
        ;------------------------------
        add     rsp, 0x10                       ; fix stack frame
        jmp     .carryOn
        ;------------------------------
        .popCarryOn:
        pop     r12
        pop     r15
        jmp     .carryOn
        ;------------------------------
        .pushOn:
        ;printLine DEBUG_CALL_FUNC, r12, [r15 + r12 * 0x08], [r15 + r12 * 0x08]
        ;------------------------------
        mov     rdi, [r15 + r12 * 0x08]
        mov     rcx, [rts_tos]
        lea     rcx, [rcx + 0x08]
        mov     [rcx], rdi
        mov     [rts_tos], rcx
        ;------------------------------
        .carryOn:
        inc     r12
        jmp     .looping
    ;------------------------------
    .funcEnded:
    mov     r13, [local_dict_tos]       ; grab value from [local_dict_tos]
    ;------------------------------
    .deallocLooping:                    ; remove local vars
        mov     rbx, [dict_tos]
        cmp     rbx, [r13]
        jle     .cleanedUpVars
        ;------------------------------
        mov     r8, [rbx]
        cmp     byte [r8 + 0x10], 0x02  ; r8 has variable type. int = 0, str = 1, struct = 2, float = 3
        jne     .freeBlockDebug         ; if != 2 then skip, if == 2 then clean the +8 bytes heap with data held there
        ;----------------------------------
        .cleanStruct:
        mov     rdi, [r8 + 0x08]
        call_libc free
        ;------------------------------ ; in this section we check if heap alloc is referenced elsewhere?
        .freeBlockDebug:
        cmp     qword [debug_mode], NULL
        je      .freeBlock
        ;-------------------------------
        printLine   dashes2
        mov     r9, [rbx]
        printLine freeingMemLocal, [r9], [rbx] ;, [r9]
        ;------------------------------
        .freeBlock:
        mov     rdi, [rbx]
        call_libc free
        ;------------------------------
        sub     qword [dict_tos], 0x08
        jmp     .deallocLooping

    .cleanedUpVars:
    ;----------------------------------     ; local_dict_tos needs updating now function ended
    sub     qword [local_dict_tos], 0x08    ; alter tos -8 bytes
    sub     qword [func_name_tos], 0x08 ; alter tos -8 bytes
    xor     ebx, ebx
    leave
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rsi, operator_35
    jmp     error_need_1_operand
    ;------------------------------
    .funcUnknown:
    mov     r8, [rts_tos]
    printLine   funcError, qword [r8]
    call    deallocate_mem_tidy_up
    leave
    jmp     exit


reading_str:
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    xor     rdi, rdi
    add     rdi, MAX_READ_STR_SIZE      ; 256 bytes
    call_libc malloc
    ;------------------------------
    mov     [malloc_str], rax
    mov     r14, rax
    ;------------------------------
    mov     rax, SYS_READ
    xor     rdi, rdi
    mov     rsi, r14
    mov     rdx, MAX_READ_STR_SIZE      ; 256 bytes
    syscall
    ;------------------------------
    dec     rax
    mov     byte [r14 + rax], NULL      ; EOS byte \0
    ;------------------------------
    mov     rdi, r14
    call    push_on
    xor     ebx, ebx
    leave
    ret

reading_i:
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    xor     rdi, rdi
    add     rdi, 0x64               ; 100 bytes
    call_libc malloc
    ;------------------------------
    mov     [malloc_str], rax
    mov     r14, rax
    ;------------------------------
    mov     rax, SYS_READ
    xor     rdi, rdi
    mov     rsi, r14
    mov     rdx, 0x64               ; 100 bytes
    syscall
    ;------------------------------
    dec     rax
    mov     byte [r14 + rax], NULL
    ;------------------------------
    mov     rdi, r14                ; pass string "number" to convert
    call    cast_str_to_int         ; converts onto r13/rax
    ;------------------------------
    mov     rdi, r14
    call_libc free
    ;------------------------------
    mov     rdi, r13
    call    push_on
    ;------------------------------
    xor     ebx, ebx
    leave
    ret


reading_f:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 0x70               ; make space on stack for 112 bytes
    ;------------------------------
    mov     rax, SYS_READ           ; SYS_READ syscall = 0
    xor     rdi, rdi                ; rdi = 0 (stdin)
    lea     rsi, [rbp - 0x70]       ; ptr to stack buffer
    mov     rdx, 0x64               ; read up to max 100 bytes
    syscall
    ;------------------------------
    cmp     rax, NULL
    jle     .empty_input
    ;------------------------------
    dec     rax
    lea     r14, [rbp - 0x70]
    mov     byte [r14 + rax], NULL  ; EOS '\0'
    ;------------------------------
    mov     rdi, r14
    xor     rsi, rsi
    call    strtod
    ;------------------------------
    mov     rax, [rts_tos]
    add     rax, 0x08
    movq    [rax], xmm0
    mov     [rts_tos], rax
    ;------------------------------
    .empty_input:
    xor     ebx, ebx
    leave                           ; stack cleaned up
    ret


more_than_or_equal_to:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    lea     r14, [r14 - 0x08]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    jnge    .setStatus
    ;----------------------------
    inc     r8                          ; is true, upd return status
    .setStatus:
    ;----------------------------
    mov     [r14], r8
    mov     [rts_tos], r14
    ;----------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_32
    jmp     error_need_mult_operands

less_than_or_equal_to:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    lea     r14, [r14 - 0x08]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    jnle    .setStatus
    ;----------------------------
    inc     r8                          ; is true, upd return status
    .setStatus:
    ;----------------------------
    mov     [r14], r8
    mov     [rts_tos], r14
    ;----------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_31
    jmp     error_need_mult_operands


not_equal_to:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    sub     qword [rts_tos], 0x08
    mov     r14, [rts_tos]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    je      .setStatus
    inc     r8                          ; is true, upd return status
    ;----------------------------
    .setStatus:
    mov     [r14], r8
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_30
    jmp     error_need_mult_operands

equal_to:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    lea     r14, [r14 - 0x08]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    jne     .setStatus
    ;----------------------------
    inc     r8                          ; is true, upd return status
    .setStatus:
    ;----------------------------
    mov     [r14], r8
    mov     [rts_tos], r14
    ;----------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_29
    jmp     error_need_mult_operands

more_than:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    lea     r14, [r14 - 0x08]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    jng     .setStatus
    ;----------------------------
    inc     r8                          ; is true, upd return status
    .setStatus:
    ;----------------------------
    mov     [r14], r8
    mov     [rts_tos], r14
    ;----------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_28
    jmp     error_need_mult_operands

less_than:
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .prepare_for_error
    mov     rdi, [r14]
    ;----------------------------
    lea     r14, [r14 - 0x08]
    ;----------------------------
    xor     r8, r8                      ; return status (false)
    ;----------------------------
    cmp     [r14], rdi
    jnl     .setStatus
    ;----------------------------
    inc     r8                          ; is true, upd return status
    .setStatus:
    ;----------------------------
    mov     [r14], r8
    mov     [rts_tos], r14
    ;----------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_27
    jmp     error_need_mult_operands

get_closing_brace_index:
    ;--------------------------------------------------------------------------------------
    ; optimised this func, no more searches/checksum calcs. just jmp straight to the index
    ; expects: rdi = index of opening '{' brace.
    ; returns: rax = index of matching '}'
    ;          r8  = index of '}else{' or NULL if NONE exist
    ;--------------------------------------------------------------------------------------
    mov     rsi, [curly_brace_table]
    mov     dword eax, [rsi + rdi * 0x08]
    mov     dword r8d, [rsi + rdi * 0x08 + 0x04]
    ;-----------------------
    ret

if_loop_func:
    ;--------------------------------------------
    ; r15 and r12 MUST be preserved at all times!
    ;-------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    sub     rsp, 0x20
    ;------------------------------
    ; rbp -  8: 1st  token AFTER  '{'
    ; rbp - 16: '}'  token
    ; rbp - 24: index of the If/Loop token
    ; rbp - 32: IF = 0 / LOOP = 1 flag, default is 0 (If)
    ;------------------------------
    mov     qword [rbp - 0x20], NULL        ; by default If/Loop flag set to 0 (if)
    ;------------------------------
    inc     r12                             ; we start on '{', so move ahead 1 token
    mov     [rbp - 0x08], r12               ; store entry point to body of function token after '{'
    ;------------------------------
    lea     rdi, [r12 - 0x01]
    call    get_closing_brace_index
    mov     r12, rax
    ;------------------------------
    mov     [rbp - 0x20], r8
    mov     [rbp - 0x10], r12               ; index of curly brace '}' stored
    ;------------------------------
    .theCheckCondition:
    inc     r12                             ; set index to token AFTER '}', the actual condition line before If/Loop
    ;------------------------------
    .findIfKeyword:                         ; we HAVE the '}' from above, now work until if/loop
        mov     rdx, [token_type]
        lea     r10, [rdx + r12 * 0x02]
        movzx   ecx, word [r10]
        cmp     word cx, operand_KEYWORD    ; OPERAND ?
        jz      .pushOn
        ;------------------------------
        cmp     word cx, if_KEYWORD         ; check for 'if' ?
        jz      .checkConditionHERE
        ;------------------------------
        cmp     word cx, loop_KEYWORD       ; check for 'loop' ?
        jz      .setLoopFlag
        ;------------->                     ; check at this point if we have a return/break flag, we jmp to exit
        .encounteredBreak:
        cmp     word cx, break_KEYWORD      ; check for 'break' ?
        jz      .setFlagAndLeave
        ;------------------------------
        .break_ifCheck:
        cmp     word cx, break_if_KEYWORD   ; check for 'break_if' ?
        jnz     .breakCondCheck
        ;-----------------------------------
        mov     r11, [rts_tos]              ; check is TOS 0 or 1? FALSE/TRUE?
        sub     qword [rts_tos], 0x08       ; pop TOS value. if != 0 this func {...} ends. if == 0 carry on
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        jz      .carryOn                    ; 0 = carry on for next check
        ;------------------------------
        .setFlagAndLeave:                   ; 1 = set flag and leave
        mov     qword [break_flag], 0x01    ; have we hit a break statement?
        jmp     .finFunc
        ;------------------------------
        .breakCondCheck:
        cmp     word cx, break_cond_if_KEYWORD  ; need to leave??
        jnz     .operatorCheck
        ;------------------------------
        mov     r11, [rts_tos]              ; check is TOS 0 or 1? FALSE/TRUE?
        sub     qword [rts_tos], 0x08       ; pop TOS value. if != 0 this func {...} ends. if == 0 carry on
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        ;------------------------------
        jnz     .finFunc                    ; NO NEED TO SET FLAG! we just exit THIS { }
        jmp     .carryOn
        ;------------------------------
        .operatorCheck:
        cmp     word cx, operator_KEYWORD   ; is this an OPERATOR?
        jb      .runOperatorCode
        jmp     .carryOn
        ;------------------------------
        .runOperatorCode:
        push    r15
        push    r12
        ;------------------------------
        lea     r9, [map_funcs + rcx * 0x08] ; STRANGE!! faster here but not in do code!!! vice versa for direct call below!!
        call    [r9]
        ;------------------------------
        .encounteredBreak2:
        cmp     qword [break_flag], 0x01    ; have we hit a break statement?
        je      .finFunc                    ; we've hit a 'break' statement from 'somewhere!'
        ;------------------------------
        test    rbx, rbx
        jz      .popCarryOn
        ;------------------------------
        add     rsp, 0x10
        jmp     .carryOn
        ;------------------------------
        .popCarryOn:
        pop     r12
        pop     r15
        jmp     .carryOn
        ;------------------------------
        .pushOn:
        ;printLine DEBUG_PROG_FUNC, r12, [r15 + r12 * 0x08], [r15 + r12 * 0x08]
        ;------------------------------
        lea     r8, [r15 + r12 * 0x08]
        mov     rdi, [r8]
        mov     r9, [rts_tos]
        lea     rcx, [r9 + 0x08]
        mov     [rcx], rdi
        mov     [rts_tos], rcx
        ;------------------------------
        .carryOn:
        inc     r12
        jmp     .findIfKeyword
    ;------------------------------
    .setLoopFlag:
    mov     qword [rbp - 0x20], 0x01        ; update Loop flag = 1,
    ;------------------------------
    .checkConditionHERE:                    ; we have either if/loop, now check if 0/1 are at TOS?
    mov     qword [rbp - 0x18], r12         ; mark where if/loop is
    ;------------------------------
    mov     r11, [rts_tos]
    sub     qword [rts_tos], 0x08           ; remove 0/1 FLAG used for check cond if/loop, [r11] has result
    ;------------------------------
    cmp     qword [rbp - 0x20], 0x01        ; 0 = if, 1 = loop, >1 = if-else
    jle     .checkStackTF
    ;------------------------------         ; has to be if-else
    mov     r8, [rbp - 0x20]                ; r8 has index of '}{' token
    cmp     qword [r11], NULL               ; is the rts_tos 0? If/Loop will check this
    jz      .isFalseElse
    ;------------------------------
    mov     qword [rbp - 0x10], r8          ; its true, so change end '}' index to '}else{' index
    jmp     .setIndexPos
    ;------------------------------
    .isFalseElse:
    inc     r8
    mov     qword [rbp - 0x08], r8          ; its false, so change '{' to token after '}else{'
    jmp     .setIndexPos
    ;------------------------------
    .checkStackTF:                          ; this is a if/loop NOT ifelse
    cmp     qword [r11], NULL               ; is the rts_tos 0? If/Loop will check this
    je      .finFunc
    ;------------------------------
    .setIndexPos:
    mov     r12, [rbp - 0x08]           ; execute the body, 1st token AFTER the '{'
    ;-------------------------
    .doCode:
        cmp     r12, [rbp - 0x10]
        je      .reachedEndBrace
        ;------------->                     ; check at this point if we have a return/break flag, we jmp to exit
        mov     rdx, [token_type]
        lea     r10, [rdx + r12 * 0x02]
        movzx   ecx, word [r10]
        cmp     word cx, operator_KEYWORD   ; < _start: is this an OPERATOR?
        jae     .operandCheck
        ;------------------------------
        .runOperatorCode2:
        push    r15
        push    r12
        ;------------------------------
        ;movzx  r8, byte cl
        ;lea        r9, [map_funcs + rcx * 0x08]
        ;call   [r9]
        call    [map_funcs + rcx * 0x08]
        ;------------->    check for break - can we siMply jmp to .finFunc from here?
        .encounteredBreak4:
        cmp     qword [break_flag], 0x01    ; have we hit a break statement?
        je      .finFunc
        ;------------->
        test    rbx, rbx
        jz      .popCarryOn2
        ;------------------------------
        add     rsp, 0x10               ; restore stack frame
        jmp     .carryOn2
        ;------------------------------
        .popCarryOn2:
        pop     r12
        pop     r15
        jmp     .carryOn2
        ;------------------------------
        .operandCheck:
        cmp     word cx, operand_KEYWORD    ; OPERAND ?
        jz      .pushOn2
        ;------------->                     ; check at this point if we have a return/break flag, we jmp to exit
        .checkForBreak:
        cmp     word cx, break_KEYWORD      ; check for 'break' ?
        jz      .setFlagAndLeave2
        ;------------------------------
        cmp     word cx, break_cond_if_KEYWORD  ; check for 'break_cond' ?
        jnz     .break_ifCheck2
        ;------------------------------
        mov     r11, [rts_tos]
        sub     qword [rts_tos], 0x08       ; remove the 0/1 FLAG used for check cond in If/Loop
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        jz      .carryOn2
        jmp     .finFunc                    ; 0 means we continue, != 0 means we end the condition
        ;------------------------------
        .break_ifCheck2:
        cmp     word cx, break_if_KEYWORD   ; check for 'break_cond' ?
        jnz     .carryOn2
        ;------------------------------
        mov     r11, [rts_tos]
        sub     qword [rts_tos], 0x08       ; remove the 0/1 FLAG used for check cond in If/Loop
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        jz      .carryOn2
        ;------------------------------
        .setFlagAndLeave2:
        mov     qword [break_flag], 0x01    ; have we hit a break statement?
        jmp     .finFunc                    ; we've hit a 'break' statement, leave the loop
        ;------------------------------
        .pushOn2:
        ;printLine DEBUG_PROG_FUNC2, r12, [r15 + r12 * 0x08], [r15 + r12 * 0x08]
        ;------------------------------
        mov     rdi, [r15 + r12 * 0x08]
        mov     r8, [rts_tos]
        lea     rcx, [r8 + 0x08]
        mov     [rcx], rdi
        mov     [rts_tos], rcx
        ;------------------------------
        .carryOn2:
        inc     r12
        jmp     .doCode
    ;------------------------------
    .reachedEndBrace:
    cmp     qword [rbp - 0x20], 0x01
    je      .theCheckCondition
    ;-------------------------
    .finFunc:
    mov     r12, [rbp - 0x18]
    mov     ebx, 0x01
    ;------------------------------
    leave
    ret

poke_var_div:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    mov     rdi, [r12]              ; pop off value
    test    rdi, rdi                ; divisor is 0?
    jz      .handle_div_by_zero     ; handle div/zero
    ;------------------------------
    mov     rax, [r11 + 0x08]       ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    cqo
    idiv    rdi
    mov     [r11 + 0x08], rax
    sub     r12, 0x08
    mov     qword [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_180
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly
    .handle_div_by_zero:
    mov     rsi, operator_180
    jmp     division_by_0


poke_var_mul:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    mov     rdi, [r12]              ; pop off value
    ;------------------------------
    mov     r9, [r11 + 0x08]        ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    imul    r9, rdi
    mov     [r11 + 0x08], r9
    sub     r12, 0x08
    mov     qword [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_179
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly

poke_var_sub:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    mov     rdi, [r12]              ; pop off value
    ;------------------------------
    sub     [r11 + 0x08], rdi       ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    sub     r12, 0x08
    mov     qword [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_178
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly

poke_var_add_float:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    movq    xmm0, [r12]             ; pop off value
    ;------------------------------
    movq    xmm1, [r11 + 0x08]      ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    addsd   xmm0, xmm1
    movq    [r11 + 0x08], xmm0
    ;------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_181
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    printLine varExistsError2, r14
    jmp     exit_error_cleanly


poke_var_sub_float:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    movq    xmm1, [r12]             ; pop off value
    ;------------------------------
    movq    xmm0, [r11 + 0x08]      ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    subsd   xmm0, xmm1
    movq    [r11 + 0x08], xmm0
    ;------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_182
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    printLine varExistsError2, r14
    jmp     exit_error_cleanly


poke_var_mul_float:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    movq    xmm0, [r12]             ; pop off value
    ;------------------------------
    movq    xmm1, [r11 + 0x08]      ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    mulsd   xmm0, xmm1
    movq    [r11 + 0x08], xmm0
    ;------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_183
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, qword [r14]
    jmp     exit_error_cleanly


poke_var_div_float:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    movq    xmm1, [r12]             ; pop off value
    ;------------------------------
    movq    xmm0, [r11 + 0x08]      ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    divsd   xmm0, xmm1
    movq    [r11 + 0x08], xmm0
    ;------------------------------
    sub     r12, 0x08
    mov     [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_184
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, qword [r14]
    jmp     exit_error_cleanly


poke_var_add:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    mov     r14, [r12]
    call    does_var_already_exist
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    sub     r12, 0x08
    mov     rdi, [r12]              ; pop off value
    ;------------------------------
    add     [r11 + 0x08], rdi       ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    sub     r12, 0x08
    mov     qword [rts_tos], r12
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_177
    jmp     error_need_mult_operands
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly


poke_var:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist  ; expects r14 with string to cmp
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    mov     rax, [r12 - 0x08]       ; grab value
    mov     [r11 + 0x08], rax       ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    sub     r12, 0x10
    mov     [rts_tos], r12          ; pop top of 2 items from stack
    ;------------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_25
    jmp     error_need_1_operand
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, qword [r14]
    jmp     exit_error_cleanly


peek_var:
    ;------------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist      ; expects r14 with string to cmp
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    mov     rdi, [r11 + 0x08]           ; does_var_already_exist gave us r11 (ptr to var), +8 = value index
    mov     [r12], rdi                  ; replace var name with value
    ;------------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_24
    jmp     error_need_1_operand
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly


address_var:
    mov     r12, [rts_tos]
    cmp     r12, rts
    jl      .prepare_for_error
    ;------------------------------
    mov     r14, [r12]
    call    does_var_already_exist      ; expects r14 with string to cmp
    ;------------------------------
    test    rax, rax
    jz      .noDefine
    ;------------------------------
    lea     rdi, [r11 + 0x08]           ; does_var_already_exist gave us r11 (ptr to var), lea +8 = ptr to value
    mov     [r12], rdi                  ; replace var name with value
    ;------------------------------
    xor     ebx, ebx
    ret
    ;------------------------------
    .noDefine:
    mov     r14, [rts_tos]
    printLine varExistsError2, [r14]
    jmp     exit_error_cleanly
    ;------------------------------
    .prepare_for_error:
    mov     rsi, operator_107
    jmp     error_need_1_operand

dump_dictionary:
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    xor     rbx, rbx
    mov     r12, [dict_tos]
    printLine   dict_header
    ;-----------------------
    .looping:
        cmp     r12, dict
        jl      .ended
        ;-----------------------
        mov     r13, [r12]
        add     r13, 0x08
        ;-----------------------
        mov     r14, [r12]
        add     r14, 0x10
        ;-----------------------
        cmp     byte [r14], NULL
        je      .printInt
        ;-----------------------
        cmp     byte [r14], 0x02
        je      .printStruct
        ja      .printFloat
        ;-----------------------
        mov     r15, [r12]
        printLine dictFMTs, rbx, [r15], [r13]
        jmp     .carryOn

        .printStruct:
        mov     r15, [r12]
        movzx   r9, byte [r14 + 0x01]
        printLine dictFMTstrct, rbx, [r15], [r13], r9
        jmp     .carryOn
        ;-----------------------
        .printInt:
        mov     r15, r12
        mov     r15, [r15]
        printLine dictFMTi, rbx, [r15], [r13]
        jmp     .carryOn
        ;-----------------------
        ;dictFMTf:      db "[%d] ---> name : [%s] | value : [%lf] | type : [float]", 0x0a, 0x00
        .printFloat:
        mov     r15, r12
        mov     r15, [r15]

        mov     rdi, dictFMTf
        mov     rsi, rbx
        mov     rdx, [r15]
        movq    xmm0, [r13]
        mov     rax, 0x01
        call_libc printf
        ;printLine dictFMTf, rbx, qword [r15], qword [r13]
        ;-----------------------
        .carryOn:
        sub     r12, 0x08
        inc     rbx
        jmp     .looping
    ;-----------------------
    .ended:
    printLine   dict_ended
    xor     ebx, ebx
    leave
    ret


is_address_in_dict:
    ;-----------------------------------------;
    ; rdi = memory address we're searchin
    ; if found rax = 1 & rbx = index in dict where var found
    ;-----------------------------------------;
    push    rbp
    mov     rbp, rsp
    ;-------------------------------- do we have any local vars? anywhere by that matter
    mov     rsi, [dict_tos]
    ;--------------------------------
    .checkAllVars:
        cmp     rsi, dict
        jl      .notFound
        ;--------------------------------
        mov     r9, [rsi]
        add     r9, 0x08
        cmp     [r9], rdi
        je      .foundMemoryAdd
        ;--------------------------------
        sub     rsi, 0x08
        jmp     .checkAllVars
    ;--------------------------------
    .foundMemoryAdd:
    xor     rax, rax
    inc     rax
    ;--------------------------------
    mov     r9, [rsi]
    add     r9, 0x10            ; get the type of var it is
    xor     rdx, rdx
    mov     byte dl, [r9]       ; save it in rdx
    ;--------------------------------
    sub     rsi, dict
    shr     rsi, 0x03
    mov     rbx, rsi            ; index in dict where address is found
    jmp     .ended
    ;--------------------------------
    .notFound:
    xor     rax, rax
    .ended:
    leave
    ret

does_var_already_exist:
    ;-------------------------------------;
    ; r14 = name of var.                  ;
    ; if found rax = 1 else 0             ;
    ;          rbx = index of var in dict ;
    ;          r11 = *ptr to var          ;
    ;-------------------------------------;
    push    rbp
    mov     rbp, rsp
    ;--------------------------------
    cmp     qword [local_dict_tos], local_dict
    jl      .checkGlobals
    ;--------------------------------
    mov     r15, [dict_tos]
    xor     rbx, rbx
    ;-------------------------
    mov     r8, [local_dict_tos]
    mov     r13, [r8]
    ;--------------------------------
    .looping:
        cmp     r15, r13
        jle     .checkGlobals
        ;-------------------------
        mov     rdi, r14
        mov     r11, [r15]
        mov     rsi, [r11]
        call    my_str_cmp
        ;-------------------------
        test    rax, rax
        jz      .found
        ;-------------------------
        sub     r15, 0x08
        inc     rbx
        jmp     .looping
    ;-------------------------
    .checkGlobals:
    cmp     qword [last_glob_var], NULL
    je      .ended
    ;--------------------------------
    mov     r15, [last_glob_var]
    ;-------------------------
    mov     rbx, [dict_tos]
    sub     rbx, [last_glob_var]
    shr     rbx, 0x03
    ;--------------------------------
    .globalLooping:
        cmp     r15, dict
        jl      .ended
        ;-----------------------
        mov     rdi, r14
        mov     r11, [r15]
        mov     rsi, [r11]
        call    my_str_cmp
        ;-----------------------
        test    rax, rax
        jz      .found
        ;-----------------------
        sub     r15, 0x08
        inc     rbx
        jmp     .globalLooping
    ;-------------------------
    .found:
    mov     rax, 0x01
    leave
    ret
    ;-------------------------
    .ended:
    xor     rax, rax
    leave
    ret


define_str:
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;-------------------------
    mov     r14, [r12]                      ; get the string address
    call    does_var_already_exist
    ;-------------------------
    test    rax, rax
    jnz     .alreadyDef
    ;-------------------------
    add     qword [dict_tos], 0x08
    mov     rdi, 0x11                       ; 17 bytes
    call_libc malloc
    ;-------------------------
    mov     rbx, rax                        ; copy of heap
    mov     rsi, [dict_tos]
    mov     [rsi], rax                      ; insert malloc into dict
    ;-------------------------              ; are we in main or a function?
    cmp     qword [func_name_tos], func_name
    jge     .build_var
    ;-------------------------              ; definitely in main _start, is this first global we added?
    mov     qword [last_glob_var], rsi
    ;-------------------------
    .build_var:                             ; add id/name/type for var
    ; ------------------------
    lea     rdi, [r12 - 0x08]               ; mov down to value or var
    mov     r8, [rdi]                       ; grab value out
    ;-------------------------              ; insert into heap values
    mov     [rbx], r14                      ; id
    mov     [rbx + 0x08], r8                ; value
    mov     byte [rbx + 0x10], 0x01         ; specify string = 1
    ;-------------------------
    lea     rdi, [r12 - 0x10]
    mov     [rts_tos], rdi                  ; adjust top of stack -16 bytes
    ;-------------------------
    .completed:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_22
    jmp     error_need_mult_operands

    .alreadyDef:
    printLine varExistsError, r14
    jmp     exit_error_cleanly


define_f:
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;-------------------------
    mov     r14, [r12]                      ; get the string address
    call    does_var_already_exist
    ;-------------------------
    test    rax, rax
    jnz     .alreadyDef
    ;-------------------------
    add     qword [dict_tos], 0x08
    mov     rdi, 0x11                       ; 17 bytes
    call_libc malloc
    ;-------------------------
    mov     rbx, rax                        ; copy of heap
    mov     rsi, [dict_tos]
    mov     [rsi], rax                      ; insert malloc into dict
    ;-------------------------              ; are we in main or a function?
    cmp     qword [func_name_tos], func_name
    jge     .build_var
    ;-------------------------              ; definitely in main _start, is this first global we added?
    mov     qword [last_glob_var], rsi
    ;-------------------------
    .build_var:                             ; add id/name/type for var
    ; ------------------------
    lea     rdi, [r12 - 0x08]               ; mov down to value or var
    movq    xmm0, [rdi]                     ; grab value out
    ;-------------------------              ; insert into heap values
    mov     [rbx], r14                      ; id
    movsd   [rbx + 0x08], xmm0              ; value
    mov     byte [rbx + 0x10], 0x03         ; specify float = 3
    ;-------------------------
    lea     rdi, [r12 - 0x10]
    mov     [rts_tos], rdi                  ; adjust top of stack -16 bytes
    ;-------------------------
    .completed:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_124
    jmp     error_need_mult_operands

    .alreadyDef:
    printLine varExistsError, r14
    jmp     exit_error_cleanly


define_i:
    push    rbp
    mov     rbp, rsp
    ;-------------------------
    mov     r12, [rts_tos]
    cmp     r12, rts
    jle     .prepare_for_error
    ;-------------------------
    mov     r14, [r12]                      ; get the string address
    call    does_var_already_exist
    ;-------------------------
    test    rax, rax
    jnz     .alreadyDef
    ;-------------------------
    add     qword [dict_tos], 0x08
    mov     rdi, 0x11                       ; 17 bytes
    call_libc malloc
    ;-------------------------
    mov     rbx, rax                        ; copy of heap
    mov     rsi, [dict_tos]
    mov     [rsi], rax                      ; insert malloc into dict
    ;-------------------------              ; are we in main or a function?
    cmp     qword [func_name_tos], func_name
    jge     .build_var
    ;-------------------------              ; definitely in main _start, is this first global we added?
    mov     qword [last_glob_var], rsi
    ;-------------------------
    .build_var:                             ; add id/name/type for var
    ; ------------------------
    lea     rdi, [r12 - 0x08]               ; mov down to value or var
    mov     r8, [rdi]                       ; grab value out
    ;-------------------------              ; insert into heap values
    mov     [rbx], r14                      ; id
    mov     [rbx + 0x08], r8                ; value
    mov     byte [rbx + 0x10], 0x00         ; specify int = 0
    ;-------------------------
    lea     rdi, [r12 - 0x10]
    mov     [rts_tos], rdi                  ; adjust top of stack -16 bytes
    ;-------------------------
    .completed:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_21
    jmp     error_need_mult_operands

    .alreadyDef:
    printLine varExistsError, r14
    jmp     exit_error_cleanly


shift_backwards_top_N:           ; need to optimise
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;------------------------------
    mov     rdi, [rdi]
    sub     qword [rts_tos], 0x08
    ;------------------------------
    cmp     rdi, NULL
    jle     .ended
    ;------------------------------
    call    elements_in_stack
    dec     rax,
    cmp     rdi, rax
    cmovg   rdi, rax
    shl     rdi, 0x03
    ;------------------------------
    mov     r15, [rts_tos]
    sub     r15, rdi
    ;------------------------------
    mov     r14, r15            ; from this location going up
    mov     r15, [r15]          ; grab this value
    ;------------------------------
    .loopForwards:
        cmp     r14, [rts_tos]
        je      .finish
        ;------------------------------
        mov     r13, r14
        add     r13, 0x08
        mov     r11, [r13]
        mov     [r14], r11
        ;------------------------------
        add     r14, 0x08
        jmp     .loopForwards
    ;------------------------------
    .finish:
    mov     r14, [rts_tos]
    mov     [r14], r15
    .ended:
    xor     ebx, ebx
    leave
    ret
    ;------------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rdi, operator_41
    jmp     error_need_mult_operands

shift_backwards:
    ;------------------------------
    mov     rbx, rts
    mov     rdi, [rbx]                  ; grab value from bottom
    ;------------------------------
    .loopBack:
        cmp     rbx, [rts_tos]
        je      .finish
        ;------------------------------
        mov     rsi, [rbx + 0x08]
        mov     [rbx], rsi
        ;------------------------------
        add     rbx, 0x08
        jmp     .loopBack
    ;------------------------------
    .finish:
    mov     [rbx], rdi
    xor     ebx, ebx
    ;------------------------------
    ret


elements_in_stack:
    ;------------------------------
    mov     rax, [rts_tos]
    sub     rax, rts            ; diff
    sar     rax, 0x03           ; rax/8
    inc     rax                 ; because of [0] index
    ;------------------------------
    xor     rcx, rcx
    cmovl   rax, rcx            ; empty = 0
    ret


shift_forward_top_N:
    push    rbp
    mov     rbp, rsp
    ;------------------------------
    mov     rsi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    mov     rdi, [rsi]
    ;------------------------------
    cmp     rdi, NULL
    jle     .ended
    ;------------------------------
    call    elements_in_stack
    sub     rax, 0x02
    cmp     rdi, rax
    cmovg   rdi, rax
    ;------------------------------
    .set_up:
    shl     rdi, 0x03
    ;------------------------------
    lea     r10, [rsi - 0x08]
    mov     r15, [r10]              ; grab the top value for later
    mov     r14, r10
    sub     r10, rdi
    ;------------------------------
    .loopBack:
        cmp     r14, r10
        je      .finish
        ;------------------------------
        mov     r13, r14
        sub     r13, 0x08
        ;------------------------------
        mov     r11, [r13]
        mov     [r14], r11
        ;------------------------------
        sub     r14, 0x08
        jmp     .loopBack
    ;------------------------------
    .finish:
    mov     [r10], r15
    .ended:
    sub     qword [rts_tos], 0x08
    xor     ebx, ebx
    ;------------------------------
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_40
    jmp     error_need_mult_operands

shift_forward:
    ;------------------------------
    mov     rbx, [rts_tos]
    mov     rdi, [rbx]                  ; grab value from top
    ;------------------------------
    .loopBack:
        cmp     rbx, rts
        je      .finish
        ;------------------------------
        mov     rsi, [rbx - 0x08]
        mov     [rbx], rsi
        ;------------------------------
        sub     rbx, 0x08
        jmp     .loopBack
    ;------------------------------
    .finish:
    mov     [rbx], rdi
    xor     ebx, ebx
    ;------------------------------
    ret


clr_below:                          ; added safety check
    ;------------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r13, [rdi]
    ;------------------------------
    sub     qword [rts_tos], 0x08
    cmp     r13, NULL
    jle     .finished
    ;------------------------------
    .set_up:
    shl     r13, 0x03
    mov     r15, rts
    add     r15, r13
    ;------------------------------
    mov     r14, rts
    ;------------------------------
    .looping:
        cmp     r15, [rts_tos]
        jg      .ended
        ;------------------------------
        mov     r8, [r15]
        mov     [r14], r8
        ;------------------------------
        add     r15, 0x08
        add     r14, 0x08
        jmp     .looping
    ;------------------------------
    .ended:
    sub     r14, 0x08
    mov     [rts_tos], r14
    ;------------------------------
    .finished:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_18
    jmp     error_need_mult_operands

clr_above:                          ; added safety check
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rsi, [rdi]
    cmp     rsi, NULL
    jge     .set_up
    xor     rsi, rsi
    .set_up:
    ;-----------------------------
    lea     r8, [rsi * 0x08 + 0x10]
    sub     rdi, r8
    lea     rsi, [rts - 0x08]
    ;-----------------------------
    cmp     rdi, rsi
    jl      .empty_stack
    mov     [rts_tos], rdi
    jmp     .ended
    ;-----------------------------
    .empty_stack:
    mov     [rts_tos], rsi
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_17
    jmp     error_need_mult_operands

rev_stack:
    ;-----------------------------
    mov     r15, [rts_tos]
    mov     r14, rts
    cmp     r15, r14            ; does it need reversing? 1 or 0 items on stack?
    jle     .finish
    ;-----------------------------
    .reverse:
        cmp     r15, r14
        jle     .finish
        ;-----------------------------
        mov     r13, [r15]
        mov     r12, [r15 - 0x08]
        mov     r11, [r14 + 0x08]
        mov     r10, [r14]
        ;-----------------------------
        mov     [r15], r10
        mov     [r15 - 0x08], r11
        mov     [r14], r13
        mov     [r14 + 0x08], r12
        ;-----------------------------
        sub     r15, 0x10
        add     r14, 0x10
        jmp     .reverse
    ;-----------------------------
    .finish:
    xor     ebx, ebx
    ;-----------------------------
    ret

dec_int:
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    dec     qword [rdi]
    ;-----------------------------
    xor     ebx, ebx
    ret
    ;-----------------------------
    .prepare_for_error:
    mov     rsi, operator_15
    jmp     error_need_1_operand

inc_int:
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    inc     qword [rdi]
    ;-----------------------------
    xor     ebx, ebx
    ret
    ;-----------------------------
    .prepare_for_error:
    mov     rsi, operator_14
    jmp     error_need_1_operand



dup_top_n:
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error              ; Need at least 2 values on the stack
    ;-----------------------------
    mov     rsi, [rdi]                      ; dup the top how many times?
    sub     rdi, 0x08                       ; pop off top value &
    cmp     rsi, NULL
    jle     .finish
    ;-----------------------------
    cmp     rdi, rts
    jl      .finish
    ;-----------------------------
    mov     r9, [rdi]                       ; grab value below
    xor     r11, r11
    ;-----------------------------
    .duplicate:
        cmp     r11, rsi
        je      .finish
        ;-----------------------------
        add     rdi, 0x08
        mov     [rdi], r9
        inc     r11
        jmp     .duplicate

    .finish:
    mov     [rts_tos], rdi                  ; fix top of stack
    xor     ebx, ebx
    ;-----------------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_13
    jmp     error_need_mult_operands
    ;-----------------------------

dup_top:
    ;-----------------------------
    cmp     qword [rts_tos], rts
    jl      .ended                          ; can't dup if stack is empty!!!
    ;------------------------------
    mov     rdi, [rts_tos]
    mov     r8, [rdi]
    lea     rsi, [rdi + 0x08]
    mov     [rsi], r8
    ;-----------------------------
    mov     [rts_tos], rsi
    ;-----------------------------
    .ended:
    xor     ebx, ebx
    ret

swap_top:
    ;------------------------------
    mov     r14, [rts_tos]
    cmp     r14, rts
    jle     .ended
    ;------------------------------
    mov     r8, [r14]               ; temp hold
    ;------------------------------
    lea     r13, [r14 - 0x08]
    mov     r9, [r13]
    mov     [r14], r9
    mov     [r13], r8
    ;------------------------------
    .ended:
    xor     ebx, ebx
    ret


div_int:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r9, [rsi]               ; get top of stack (the divisor)
    test    r9, r9
    jz      .handle_div_by_zero     ; handle div zero
    ;-----------------------------
    mov     rax, [rsi - 0x08]       ; get top of stack-1 (the dividend)
    cqo
    idiv    r9
    ;-----------------------------
    lea     rsi, [rsi - 0x08]
    mov     [rsi], rax
    mov     [rts_tos], rsi
    ;-----------------------------
    xor     ebx, ebx
    ret
    ;-----------------------------
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_10
    jmp     error_need_mult_operands
    ;-----------------------------
    .handle_div_by_zero:
    mov     rsi, operator_10
    jmp     division_by_0


mult_int:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rax, [rsi]                  ; get top of stack
    lea     rsi, [rsi - 0x08]           ; get top of stack - 1
    mov     rdi, [rsi]
    ;-----------------------------
    imul    rax, rdi
    mov     [rsi], rax
    mov     [rts_tos], rsi
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_09
    jmp     error_need_mult_operands

sub_int:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rdi, [rsi]
    lea     rdx, [rsi - 0x08]
    sub     [rdx], rdi
    ;-----------------------------
    mov     [rts_tos], rdx
    ;-----------------------------
    xor     ebx, ebx
    ret

    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_08
    jmp     error_need_mult_operands

add_int:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rdi, [rsi]
    lea     rdx, [rsi - 0x08]
    add     [rdx], rdi
    ;-----------------------------
    mov     [rts_tos], rdx
    ;-----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_07
    jmp     error_need_mult_operands

xor_int:                        ; xor top 2 on the stack
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    xor     rax, rax            ; null out for result
    xor     rcx, rcx            ; clear for result
    ;-----------------------------
    mov     r8, [rsi]
    test    r8, r8              ; check r8
    setz    al                  ; al = 1 if r8 = null, else al = 0
    ;-----------------------------
    lea     rdi, [rsi - 0x08]
    mov     r9, [rsi - 0x08]
    test    r9, r9              ; check r9
    setz    cl                  ; cl = 1 if r9 = null, else cl = 0
    ;-----------------------------
    xor     rax, rcx            ; xor with (0,1) vals
    mov     [rdi], rax
    mov     [rts_tos], rdi
    ;-----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_226
    jmp     error_need_mult_operands


my_puts_pop:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rsi, [rts_tos]
    mov     rdi, [rsi]
    call    puts
    ;-----------------------------
    sub     qword [rts_tos], 0x08
    xor     ebx, ebx
    ret

    .prepare_for_error:
    mov     rsi, operator_105
    jmp     error_need_1_operand

my_puts:
    ;-----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rsi, [rts_tos]
    mov     rdi, [rsi]
    call    puts
    ;-----------------------------
    xor     ebx, ebx
    ret

    .prepare_for_error:
    mov     rsi, operator_106
    jmp     error_need_1_operand


my_printf_pop:
    ;-----------------------------
    mov     r10, [rts_tos]
    cmp     r10, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r14, [r10]              ; # of params to pop off
    ;-----------------------------
    xor     r8, r8
    cmp     r14, r8
    cmovl   r14, r8                 ; handle <= 0
    shl     r14, 0x03
    ;-----------------------------
    lea     r11, [r10 - 0x10]
    sub     r11, r14
    mov     [rts_tos], r11          ; pop off params & fix stack ptr
    ;-----------------------------
    mov     rdi, [r10 - 0x08]       ; frmt string
    mov     rsi, [r10 - 0x10]
    mov     rdx, [r10 - 0x18]
    mov     rcx, [r10 - 0x20]
    mov     r8,  [r10 - 0x28]
    mov     r9,  [r10 - 0x30]
    ;-----------------------------
    xor     rax, rax
    call_libc printf
    ;-----------------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_101
    jmp     error_need_mult_operands

my_printf:                          ; made bit quicker
    ;-----------------------------
    mov     r10, [rts_tos]
    cmp     r10, rts
    jl      .prepare_for_error
    ;-----------------------------
    lea     r11, [r10 - 0x08]
    mov     [rts_tos], r11          ; pop off frmt string
    ;-----------------------------
    mov     rdi, [r10]              ; frmt string
    mov     rsi, [r10 - 0x08]
    mov     rdx, [r10 - 0x10]
    mov     rcx, [r10 - 0x18]
    mov     r8,  [r10 - 0x20]
    mov     r9,  [r10 - 0x28]
    ;-----------------------------
    xor     rax, rax
    call_libc printf
    ;-----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_102
    jmp     error_need_1_operand


my_sprintf:
    push    rbp
    mov     rbp, rsp                ; prepare STACK-FRAME else it will CRASH!!
    ;-----------------------------
    mov     r10, [rts_tos]
    cmp     r10, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rdi, [r10]              ; frmt string
    mov     rsi, [r10 - 0x08]
    mov     rdx, [r10 - 0x10]
    mov     rcx, [r10 - 0x18]
    mov     r8, [r10 - 0x20]
    mov     r9, [r10 - 0x28]
    ;-----------------------------
    xor     rax, rax
    call_libc sprintf
    ;-----------------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_104
    jmp     error_need_mult_operands

my_sprintf_pop:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     r10, [rts_tos]
    lea     r11, [rts + 0x10]
    cmp     r10, r11
    jl      .prepare_for_error
    ;-----------------------------
    mov     r10, [rts_tos]          ; r10 points to the user value
    mov     r14, [r10]              ; r14 = number of args user wants popped
    ;-----------------------------  ; check range(0..6)
    xor     r11, r11
    cmp     r14, r11
    cmovl   r14, r11                ; handle negative
    ;-----------------------------
    mov     r11, 0x06
    cmp     r14, r11                ; dont pop off > 6 params
    cmovg   r14, r11
    ;-----------------------------  ; calc and pop off args, fix stack ptr
    lea     r11, [r14 + 0x01]       ; popped off + 1
    shl     r11, 0x03               ; X 8
    mov     rsi, r10
    sub     rsi, r11
    mov     [rts_tos], rsi          ; fix stack ptr. # of params to pop off + 1 more for that param too.
    ;-----------------------------
    mov     rdi, [r10 - 0x08]
    mov     rsi, [r10 - 0x10]
    mov     rdx, [r10 - 0x18]
    mov     rcx, [r10 - 0x20]
    mov     r8, [r10 - 0x28]
    mov     r9, [r10 - 0x30]
    ;-----------------------------
    xor     rax, rax
    call_libc sprintf
    ;-----------------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_103
    jmp     error_need_mult_operands


print_top_ptr:
    ;-----------------------------
    mov     r14, [rts_tos]
    cmp     r14, rts
    jl      .empty_stack
    printLine ptrFMT, [r14]
    ;-----------------------------
    xor     ebx, ebx
    ret
    .empty_stack:
    call    get_current_func_name
    printLine   print_empty_stack, r8
    xor     ebx, ebx
    ret

print_top_str:
    ;-----------------------------
    mov     r14, [rts_tos]
    cmp     r14, rts
    jl      .empty_stack
    printLine strFMT, [r14]
    ;-----------------------------
    xor     ebx, ebx
    ret
    .empty_stack:
    call    get_current_func_name
    printLine   print_empty_stack, r8
    xor     ebx, ebx
    ret

print_top_i:
    ;-----------------------------
    mov     r14, [rts_tos]
    cmp     r14, rts
    jl      .empty_stack
    printLine intFMT, [r14]
    ;-----------------------------
    xor     ebx, ebx
    ret
    .empty_stack:
    call    get_current_func_name
    printLine   print_empty_stack, r8
    xor     ebx, ebx
    ret


clear_stack:
    ;-----------------------------
    lea     r9, [rts - 0x08]
    mov     [rts_tos], r9
    ;-----------------------------
    xor     ebx, ebx
    ret

deref_str_to_int:
    ;----------------------------------------------------------------------------------
    ; no need for stack-leak check, this was created with a number already on the stack
    ;----------------------------------------------------------------------------------
    mov     r8, [rts_tos]
    mov     r10, [r8]               ; get ptr to heap alloc
    mov     r11, [r10]              ; now get the NUMBER out of it!
    ;-----------------------------
    mov     [r8], r11               ; replace ptr to heap with number, with actual number
    ;-----------------------------
    xor     ebx, ebx
    ret


dump_i:
    ;-----------------------------
    printLine   debug_dump_rts_start
    xor     r13, r13
    mov     r12, [rts_tos]
    ;-----------------------------
    .looping:
        cmp     r12, rts
        jl      .ended
        ;-----------------------------
        printLine intOut2, r13, [r12]
        ;-----------------------------
        lea     r12, [r12 - 0x08]
        inc     r13
        jmp     .looping
    ;-----------------------------
    .ended:
    printLine   debug_dump_rts_ended
    xor     ebx, ebx
    ;-----------------------------
    ret

dump_rts_ptr:
    ;-----------------------------
    printLine   debug_dump_rts_start
    xor     r13, r13
    mov     r12, [rts_tos]
    ;-----------------------------
    .looping:
        cmp     r12, rts
        jl      .ended
        ;-----------------------------
        printLine ptrOut2, r13, [r12]
        ;-----------------------------
        lea     r12, [r12 - 0x08]
        inc     r13
        jmp     .looping
    ;-----------------------------
    .ended:
    printLine   debug_dump_rts_ended
    xor     ebx, ebx
    ;-----------------------------
    ret

dump_str:
    ;-----------------------------
    printLine   debug_dump_rts_start
    xor     r13, r13
    mov     r12, [rts_tos]
    ;-----------------------------
    .looping:
        cmp     r12, rts
        jl      .ended
        ;-----------------------------
        printLine stringOut2, r13, [r12]
        ;-----------------------------
        lea     r12, [r12 - 0x08]
        inc     r13
        jmp     .looping
    ;-----------------------------
    .ended:
    printLine   debug_dump_rts_ended
    xor     ebx, ebx
    ret

pop_off_free_n:             ; added check for popping off empty stack
    ;-----------------------------
    mov     r13, [rts_tos]          ; # to pop off
    cmp     r13, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r9, [r13]               ; Grab val & check ranges
    xor     r8, r8
    cmp     r9, NULL
    cmovl   r9, r8                  ; if r9 is neg, set to 0
    ;-----------------------------
    mov     r12, r13
    sub     r12, rts                ; entries in stack (x8)
    shr     r12, 0x03               ; #/8
    ;-----------------------------
    cmp     r9, r12                 ; if r9 > max entries then r9 = max entries
    cmovg   r9, r12
    ;-----------------------------
    lea     r12, [r13 - 0x08]       ; start popping/freeing below # user passed
    lea     r10, [r9 * 0x08 + 0x08]
    sub     r13, r10                ; ptr we stop popping off & freeing
    mov     [rts_tos], r13
    ;-----------------------------
    .freeing:
        cmp     r12, r13
        jle     .ended
        ;-----------------------------
        mov     rdi, [r12]
        call_libc free
        sub     r12, 0x08
        jmp     .freeing
        ;-----------------------------
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_228
    jmp     error_need_mult_operands


pop_off_n:          ; added check for popping off empty stack
    ;-----------------------------
    mov     rsi, [rts_tos]          ; # to pop off
    cmp     rsi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r9, [rsi]               ; Grab val & check ranges
    xor     r8, r8
    cmp     r9, NULL
    cmovl   r9, r8                  ; if r9 is neg, set to 0
    ;-----------------------------
    mov     r12, rsi
    sub     r12, rts                ; entries in stack (x8)
    shr     r12, 0x03               ; #/8
    ;-----------------------------
    cmp     r9, r12                 ; if r9 > max entries then r9 = max entries
    cmovg   r9, r12
    ;-----------------------------
    lea     r10, [r9 * 0x08 + 0x08]
    sub     rsi, r10                ; pop off n entries
    mov     [rts_tos], rsi
    ;-----------------------------
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_227
    jmp     error_need_mult_operands

pop_off:            ; added check for popping off empty stack
    ;-----------------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;-----------------------------
    sub     qword [rts_tos], 0x08
    ;-----------------------------
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_00
    jmp     error_need_1_operand

push_on:
    ;----------------------------- rdi = val to push on. error isn't really needed here....
    mov     rsi, [rts_tos]
    add     rsi, 0x08
    mov     [rsi], rdi
    mov     [rts_tos], rsi
    xor     ebx, ebx
    ret


create_func_list:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     r15, [argv_ptr]
    mov     r13, [token_type]
    xor     r12, r12
    ;-----------------------------
    .findGlobalStart:
        ;-----------------------------
        cmp     r12, [argv_len]
        je      .no_start_found
        ;-----------------------------
        cmp     word [r13 + r12 * 0x02], start_KEYWORD
        jz      .finish
        ;-----------------------------
        cmp     word [r13 + r12 * 0x02], func_KEYWORD
        ;----------------------------- debugging...
        ;push   rax
        ;printLine  intOut, rax
        ;pop    rax
        ;-----------------------------
        jnz     .carryOn
        ;-----------------------------
        push    r15
        inc     r12
        ; printLine gotFuncIndex, r12, [r15 + r12 * 0x08]
        ;-----------------------------
        mov     r14, [r15 + r12 * 0x08]
        call    does_func_already_exist
        ;-----------------------------
        pop     r15
        test    rax, rax
        jnz     .leaveProg
        ;-----------------------------
        add     qword [funcs_tos], 0x08
        mov     rdi, 0x10
        call_libc malloc
        ;-----------------------------
        mov     r14, [funcs_tos]
        mov     [r14], rax
        mov     rdi, rax
        ;-----------------------------
        mov     r11, [r15 + r12 * 0x08]     ; add the name of function 1st 8 bytes
        mov     [rdi], r11
        ;-----------------------------
        mov     [rdi + 0x08], r12           ; add the index of function 2nd 8 bytes
        ;-----------------------------
        .carryOn:
        inc     r12
        jmp     .findGlobalStart
    ;-----------------------------
    .finish:                                ; now set the index of start
    mov     [START_INDEX], r12
    leave
    ret
    .no_start_found:
    printLine   no_start_in_code
    call    dealloc_operator_hashset        ; ending prog, but still need to dealloc hashset
    jmp     exit_error_cleanly              ; messy, but works for now..
    ;-----------------------------
    .leaveProg:
    printLine funcError2, [r15 + r12 * 0x08]
    jmp     exit_error_cleanly

dump_func_list:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     rbx, [funcs_tos]
    .dumpFunctions:
        cmp     rbx, funcs
        jl      .completed
        ;-----------------------------
        mov     rcx, [rbx]
        mov     rdx, [rcx]          ; get name of function
        add     rcx, 0x08           ; get argv [index] of function
        ;-----------------------------
        printLine   funcDebug, rdx, [rcx]
        ;-----------------------------
        sub     rbx, 0x08
        jmp     .dumpFunctions
        ;-----------------------------
    .completed:
    leave
    ret

argv_onto_stack:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    .getGlobalStart:
    mov     r12, [START_INDEX]          ; jmp straight there
    .readCode:
    inc     r12                         ; move +1 token past it
    mov     r15, [argv_ptr]             ; the tokens/code array
    ;-----------------------------
    .looping:
        cmp     qword [r15 + r12 * 0x08], NULL
        je      .ended
        ;-----------------------------------
        mov     rdx, [token_type]
        lea     r10, [rdx + r12 * 0x02]
        movzx   ecx, word [r10]
        cmp     word cx, operator_KEYWORD   ; <  means its an OPERATOR
        jb      .runOperatorCode            ; is an OPERATOR
        ;-----------------------------------
        cmp     word cx, operand_KEYWORD    ; < dummy operator
        jb      .checkForBreak
        ;-----------------------------------
        jmp     .pushOn                     ; must be an OPERAND
        ;-----------------------------------
        .checkForBreak:
        cmp     word cx, break_KEYWORD      ; break?
        jz      .ended
        ;-----------------------------------
        cmp     word cx, break_if_KEYWORD   ; break_if?
        jnz     .returnCheck
        mov     r11, [rts_tos]
        sub     qword [rts_tos], 0x08       ; remove the TOS value. if !=0 this function ends. if == 0 we carry on checking
        ;------------------------------
        cmp     qword [r11], NULL           ; is the rts_tos == 0 or != 0?
        jne     .ended                      ; 0 means we continue, != 0 means we end the condition
        ;-----------------------------------
        .returnCheck:
        cmp     word cx, return_KEYWORD     ; return?
        jz      .ended
        ;-----------------------------------
        jmp     .carryOn
        ;-----------------------------------
        .runOperatorCode:                   ; save these until we return & resume...
        push    r15
        push    r12
        ;-----------------------------
        ;movzx  rcx, byte [rcx + r12 * 0x02]
        call    [map_funcs + rcx * 0x08]    ; faster??
        ;-----------------------------
        .checkBreakFlag:
        cmp     qword [break_flag], 0x01    ; have we hit a break statement?
        jne     .checkResumePoint
        ;-----------------------------      ; we've hit a 'break' statement from {prog_code}
        mov     qword [break_flag], NULL    ; re-set this break_flag
        jmp     .ended
        ;-----------------------------
        .checkResumePoint:
        test    rbx, rbx
        jz      .popCarryOn
        ;------------------------------
        add     rsp, 0x10                   ; tidy up frame
        jmp     .carryOn
        ;-----------------------------
        .popCarryOn:                        ; returned, so now resume..
        pop     r12
        pop     r15
        ;-----------------------------
        jmp     .carryOn
        .pushOn:
        ;printLine  DEBUG_ARGV_STACK, r12, [r15 + r12 * 0x08], [r15 + r12 * 0x08]
        ;-----------------------------
        mov     rdi, [r15 + r12 * 0x08]
        mov     rcx, [rts_tos]
        lea     rdx, [rcx + 0x08]
        mov     [rdx], rdi
        mov     [rts_tos], rdx
        ;-----------------------------
        .carryOn:
        inc     r12
        jmp     .looping
    .ended:
    leave
    ret


check_is_operator:
    ;-----------------------------------------------------------------
    ; pass token on rdi, rbx has index of function and rax = 1. if not found rax = 0
    ;-----------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    push    rdi                     ; copy of token str
    mov     rsi, MAX_HASH_SET
    ;----------------------------
    call    generate_str_checksum   ; checksum is generated here, then used for direct lookup in hashset
    mov     r13, [op_hashset]       ; now jump straight to this [checksum index] in the array (using rax)
    ;----------------------------
    cmp     qword [r13 + rax * 0x08], NULL  ; is hashset slot empty or does it have an entry?
    je      .tokenNotOperator
    ;----------------------------
    mov     rdi, [rbp - 0x08]           ; get token str from stack
    mov     r13, [r13 + rax * 0x08]
    mov     rsi, [r13]                  ; rdi alread has token str, we still need to compare against operator name HERE!! ERROR
    call    my_str_cmp
    test    rax, rax
    jz      .tokenMatchedOperator       ; token == operator
    ;----------------------------
    cmp     qword [r13 + 0x08], NULL    ; any other nodes linked that we can we search?
    je      .tokenNotOperator           ; token != operator
    ;----------------------------
    .scanning:
        mov     r13, [r13 + 0x08]       ; point to next node in list
        mov     r8,  [rbp - 0x08]       ; get token str from stack
        mov     rdi, r8
        mov     rsi, [r13]
        ;----------------------------
        call    my_str_cmp
        test    rax, rax
        jz      .tokenMatchedOperator   ; token == operator
        ;----------------------------
        cmp     qword [r13 + 0x08], NULL
        je      .tokenNotOperator
        jmp     .scanning
    ;----------------------------
    .tokenMatchedOperator:
    ;----------------------------
    xor     rax, rax
    inc     rax
    mov     word bx, [r13 + 0x10]   ; put on rbx the index to operator function
    jmp     .ended
    ;----------------------------
    .tokenNotOperator:
    xor     rax, rax
    ;----------------------------
    .ended:
    leave
    ret

dump_operator_hashset:          ; helpful for debugging
    ;----------------------------
    xor     rbx, rbx
    mov     r12, [op_hashset]
    printLine   debug_hashset
    ;----------------------------
    .looping:
        cmp     rbx, MAX_HASH_SET
        je      .ended
        ;----------------------------
        cmp     qword [r12 + rbx * 0x08], NULL
        jne     .nodeFound
        printLine   debug_hashEmpty, rbx, NULL
        jmp     .nextHash
        ;----------------------------           ; is NOT empty, so display the node
        .nodeFound:
        mov     r14, [r12 + rbx * 0x08]
        ;----------------------------
        .scanning:                              ; go through every node in this list
            mov     r8, r14
            xor     r9, r9
            mov     word r9w, [r8 + 0x10],
            printLine   debug_hashData, rbx, r8, [r8], [r8 + 0x08], r9  ; index, addr, op name, *next, checksum
            ;----------------------------
            .moveToNextNode:
            mov     r14, [r14 + 0x08]
            test    r14, r14                    ; go to *next_ptr ONLY if it's non-NULL
            jnz     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ret

dealloc_operator_hashset:           ; op_hashset needs cleaning up
    ;----------------------------
    xor     rbx, rbx
    mov     r15, [op_hashset]
    ;----------------------------
    cmp     qword [debug_mode], NULL
    je      .looping
    printLine   dashes2
    printLine   dealloc_hashset
    ;----------------------------
    .looping:                       ; loop through, if empty ignore, if !empty then deallocate node and any linked to it
        cmp     rbx, MAX_HASH_SET
        je      .ended
        ;----------------------------
        cmp     qword [r15 + rbx * 0x08], NULL
        jne     .nodeFound
        ;----------------------------
        cmp     qword [debug_mode], NULL
        je      .nextHash
        printLine   dealloc_empty, rbx, NULL
        jmp     .nextHash
        ;----------------------------       ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                         ; not an empty slot
        mov     r13, [r15 + rbx * 0x08]     ; r13 on the node, r14 points to next node
        mov     r14, [r13 + 0x08]
        ;----------------------------
        .scanning:
            ;----------------------------
            cmp     qword [debug_mode], NULL
            je      .deallocNode
            ;----------------------------
            mov     r8, r13
            xor     r9, r9
            mov     word r9w, [r8 + 0x10],
            printLine   dealloc_hashData, rbx, r8, [r8], [r8 + 0x08], r9    ; index, addr, op name, *next, checksum
            ;----------------------------
            .deallocNode:
            mov     rdi, r13                ; dealloc mem
            call_libc free
            ;----------------------------
            test    r14, r14                ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash               ; no more nodes attached, continue with r15
            ;----------------------------
            .moveToNextNode:
            mov     r13, r14
            mov     r14, [r14 + 0x08]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ;----------------------------
    cmp     qword [debug_mode], NULL
    je      .deallocAllHash
    ;----------------------------
    printLine   dashes2
    printLine   dealloc_hash_arr, r15
    printLine   dashes2
    ;----------------------------
    .deallocAllHash:
    mov     rdi, r15                    ; deallocate the entire block which has the hashset
    call_libc free
    mov     qword [op_hashset], NULL    ; tidy up!
    ;----------------------------
    ret

create_user_hashset:
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;----------------------------
    sub     rsp, 0x08
    ;----------------------------
    mov     r13, [rts_tos]
    mov     rdi, [r13]              ; grab user hashsize
    mov     rbx, 0x40               ; start with 64 size
    ;----------------------------
    .set_hash_size:
        cmp     rbx, rdi
        jge     .final_hash_size
        ;----------------------------
        shl     rbx, 0x01           ; double each time
        jmp     .set_hash_size
        ;----------------------------
    .final_hash_size:               ; set all hashset values to NULL to start with
    mov     rdi, 0x10               ; [0] is *ptr to hashset [8] is size of hashset
    call_libc malloc
    ;----------------------------
    mov     [rsp], rbx              ; store hashset size
    xor     r8, r8
    mov     [rax + 0x08], r8        ; null out all bytes
    mov     dword [rax + 0x08], ebx ; store hashset size in heap too
    mov     [r13], rax              ; now store this heap alloc on rts
    mov     rbx, rax                ; save 16 byte (ptr to hashset & heap size)
    ;----------------------------
    mov     rdi, [rsp]
    shl     rdi, 0x03               ; X 8
    call_libc malloc
    ;----------------------------
    mov     [rbx], rax              ; save actual hashset in 1st 8 bytes of earlier 16 byte alloc
    ;printLine ptrOut, rax
    ;----------------------------
    mov     rdi, [rbx] ;rax         ; pass heap alloc for hashet
    xor     rax, rax                ; value to store (NULL)
    mov     rcx, [rsp]              ; num of 8-byte qwords
    cld                             ; make sure rdi inc fwd
    rep     stosq                   ; fast NULL out!
    ;----------------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_186       ; need to modify this error to mention hashset/graph
    jmp     error_need_1_operand

delete_user_graph:                  ; expets 16 byte hashset datatype on top of stack
    ;----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     rdi, 0x03                   ; pass 3 flag to DELETE whole hashset
    call    delete_or_clear_user_hashset
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_187
    jmp     error_need_1_operand


delete_user_hashset:                    ; expects 16 byte hashset datatype on top of stack
    ;----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     rdi, 0x01                   ; pass 1 flag to DELETE whole hashset
    call    delete_or_clear_user_hashset
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_187
    jmp     error_need_1_operand

clear_user_hashset:                     ; expects 16 byte hashset datatype on top of stack
    ;----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;----------------------------
    xor     rdi, rdi                    ; pass 0 flag to REPLACE hashset with empty one
    call    delete_or_clear_user_hashset
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_188
    jmp     error_need_1_operand

delete_or_clear_user_hashset:
    ;-------------------------------------------------------------------------------
    ; expects 16 byte hashset datatype on top of stack & rdi = flag (delete/replace)
    ;--------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x20           ; [rsp] = size, [rsp + 0x08] (flag) 0 = reset hashset 1 = full delete
    ;----------------------------
    ; [rsp]                       hashset size
    ; [rsp + 0x08]                flag 0 = reset hashset, 1 = full delete
    ; [rsp + 0x10]                *ptr to hashset
    ; [rsp + 0x18]                flag 0 = *ptr to hashset
    ;----------------------------
    mov     [rsp + 0x08], rdi   ; rdi = flag, 0 = reset hashset 1 = full delete
    ;----------------------------
    mov     r15, [rts_tos]
    mov     r8, [r15]
    sub     qword [rts_tos], 0x08       ; pop off
    mov     [rsp + 0x10], r8            ; store main hashset
    ;----------------------------
    mov     dword r8d, [r8 + 0x08]      ; upper bytes nulled out
    mov     [rsp], r8                   ; + 8 bytes dword = size of hashset
    mov     r9, [r15]                   ; deref main *ptr
    mov     r15, [r9]                   ; 1st 8 bytes = *ptr to hashset
    xor     rbx, rbx                    ; counter
    ;----------------------------------------------------------------------------------
    ; loop through, if empty ignore, if !empty then deallocate node & any linked to it
    ;----------------------------------------------------------------------------------
    .looping:
        cmp     rbx, [rsp]          ; MAX_HASH_SET
        jge     .deallocAllHash
        ;----------------------------
        cmp     qword [r15 + rbx * 0x08], NULL
        je      .nextHash
        ;----------------------------           ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                             ; not an empty slot
        mov     r13, [r15 + rbx * 0x08]         ; r13 on the node, r14 points to next node
        mov     r14, [r13 + 0x10]
        ;----------------------------
        .scanning:
            movzx   r12, byte [r13 + 0x18]      ; get node flag info
            test    r12, 0x01                   ; check 1st bit
            jz      .skip_key                   ; if bit = 0 skip key del
            ;----------------------------
            mov     rdi, [r13]
            call_libc free
            ;----------------------------
            .skip_key:
            test    r12, 0x02                   ; check 2nd bit
            jz      .skip_val                   ; if bit = 0 skip value del
            ;----------------------------
            ;printLine  debug_hashset_free, [r13 + 0x08]    ; need to handle graphs as well
            ;----------------------------
            test    qword [rsp + 0x08], 0x02
            jz      .skip_graph_arrays
            ;----------------------------
            mov     rsi, [r13 + 0x08]
            mov     rdi, [rsi]
            call_libc free
            mov     rsi, [r13 + 0x08]
            mov     rdi, [rsi + 0x08]
            call_libc free
            ;----------------------------
            .skip_graph_arrays:
            mov     rdi, [r13 + 0x08]
            call_libc free
            ;----------------------------
            .skip_val:
            mov     rdi, r13                    ; dealloc mem
            call_libc free
            ;----------------------------
            test    r14, r14                    ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash                   ; no more nodes attached, continue with r15
            ;----------------------------
            .moveToNextNode:
            mov     r13, r14
            mov     r14, [r14 + 0x10]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    ;----------------------------
    .deallocAllHash:
    mov     rdi, r15                        ; clean hashset
    call_libc free
    ;----------------------------
    cmp     qword [rsp + 0x08], NULL
    jne     .full_delete
    ;----------------------------
    .reset_hashset_keep_ptr:
    mov     rdi, 0x40               ; alloc new 64 bucket hashset
    shl     rdi, 0x03               ; x 8
    call_libc malloc
    mov     rbx, rax
    ;----------------------------
    mov     rdi, rax                ; pass heap alloc for hashet
    xor     rax, rax                ; value to store (NULL)
    mov     rcx, 0x40               ; num of 8-byte qwords
    cld                             ; make sure rdi inc fwd
    rep     stosq                   ; fast NULL out!
    ;----------------------------
    mov     rdi, [rsp + 0x10]
    mov     [rdi], rbx              ; replace the deleted hashset with an 64 bucket empty one
    ;----------------------------
    mov     dword [rdi + 0x08], 0x40    ; update header 64 buckets
    mov     dword [rdi + 0x0c], 0x00    ; update header  0 nodes
    jmp     .ended
    ;----------------------------
    .full_delete:
    mov     rdi, [rsp + 0x10]       ; deallocate the entire hashset block
    call_libc free
    ;----------------------------
    .ended:
    leave
    ret

delete_regex_multi:
    ;-------------------------------------------------------------
    ; top of stack has regex ptr, 1st 8 bytes = **ptr to strings
    ; 2nd 8 bytes = *ptr info & then 4 byte offset pairs
    ;------------------------------------------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;----------------------------
    xor     rdi, rdi
    or      rdi, 0x01       ; set FLAG for deleting regex multi
    call    delete_regex_or_str_set
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_223
    jmp     error_need_1_operand

delete_string_set:
    ;----------------------------
    mov     rsi, [rts_tos]
    cmp     rsi, rts
    jl      .prepare_for_error
    ;----------------------------
    xor     rdi, rdi        ; set FLAG for deleting string set
    call    delete_regex_or_str_set
    xor     ebx, ebx
    ;----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_224
    jmp     error_need_1_operand

delete_regex_or_str_set:
    ;------------------------------------------------------------
    ; this will handle deleting regex multi set and string sets.
    ; rdi = FLAG (0 = string set, 1 = regex multi)
    ;------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    push    rdi             ; save FLAG in [rsp]
    ;----------------------------
    mov     rsi, [rts_tos]
    mov     r12, [rsi]
    test    r12, r12
    jz      .err_no_heap_found
    ;----------------------------   ; first remove the strings in 1st 8 bytes **ptr
    mov     r13, [r12]
    xor     r14, r14
    ;----------------------------
    .delete_strings:
        lea     r9, [r13 + r14 * 0x08]
        mov     rdi, [r9]
        test    rdi, rdi            ; reached the NULL entry?
        jz      .deallocated_strings
        ;----------------------------
        call_libc free
        inc     r14
        jmp     .delete_strings
    ;----------------------------
    .deallocated_strings:           ; now free the WHOLE array holding them strings
    mov     rdi, r13
    call_libc free
    ;----------------------------   ; now handle the regex result set with info/matching pairs
    cmp     qword [rsp], 0x01
    jne     .delete_main_block
    ;----------------------------   ; delete regex stats/matching pairs
    mov     rdi, [r12 + 0x08]
    call_libc free
    ;----------------------------
    .delete_main_block:
    mov     rdi, r12
    call_libc free
    ;----------------------------
    sub     qword [rts_tos], 0x08
    jmp     .ended
    ;----------------------------
    .err_no_heap_found:
    printLine   expectedPtrToFree
    call    exit_error_cleanly
    ;----------------------------
    .ended:
    leave
    ret

dump_user_hashset:          ; expects 16 byte hashset datatype on top of stack
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x08
    ;----------------------------
    mov     r15, [rts_tos]
    cmp     r15, rts
    jl      .prepare_for_error
    ;----------------------------
    mov     r8, [r15]
    test    r8, r8
    jz      .empty_hash_error
    ;----------------------------
    sub     qword [rts_tos], 0x08
    ;----------------------------
    mov     r9d, [r8 + 0x08]
    mov     [rsp], r9                   ; 2nd 8 bytes = size of hashset
    ;----------------------------
    mov     r9d, [r8 + 0x0c]            ; # of nodes in hashset
    mov     r10, [r15]                  ; deref main *ptr
    mov     r15, [r10]                  ; 1st 8 bytes = *ptr to hashset
    xor     rbx, rbx                    ; counter
    ;----------------------------
    printLine   disp_title_hashset, hash_heading, [rsp], r9
    ;-------------------------------------------------------------------------------------
    ; loop through, if empty ignore, if !empty then print node and all others linked to it
    ;-------------------------------------------------------------------------------------
    .looping:
        cmp     rbx, [rsp]          ; MAX_HASH_SET
        jge     .ended
        ;----------------------------
        cmp     qword [r15 + rbx * 0x08], NULL
        jne     .nodeFound
        ;----------------------------
        ;printLine  disp_empty_hashset, rbx, [r15 + rbx * 0x08]
        jmp     .nextHash
        ;----------------------------       ; is NOT empty, so free all the node(s) in the list
        .nodeFound:                         ; not an empty slot
        mov     r13, [r15 + rbx * 0x08]     ; r13 on the node, r14 points to next node
        mov     r14, [r13 + 0x10]
        ;----------------------------
        .scanning:
            ;----------------------------
            printLine   disp_user_hashset, rbx, r13, [r13], [r13 + 0x08], r14
            ;movzx      rdx, byte [r13 + 0x18]
            ;printLine  intOut, rdx
            test    r14, r14                ; is *next == NULL? or is it part of a linked list?
            jz      .nextHash               ; no more nodes attached, continue with r15
            ;----------------------------
            .moveToNextNode:
            mov     r13, r14
            mov     r14, [r14 + 0x10]
            jmp     .scanning
        ;----------------------------
        .nextHash:
        inc     rbx
        jmp     .looping
    .ended:
    ;----------------------------
    printLine   disp_foot_hashset, hash_heading
    xor     ebx, ebx
    ;----------------------------
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_54
    jmp     error_need_1_operand
    .empty_hash_error:
    mov     rsi, operator_54
    jmp     error_need_valid_ptr

expand_hashset:
    ;--------------------------------------------------------------------------------
    ; rbx = hashset, rdi = size. if # of nodes >= 0.75 of hashset size, expand it X 2
    ;----------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x18
    ;-----------------------------------;
    ; [rsp]        = orig size          ;
    ; [rsp + 0x08] = double size        ;
    ; [rsp + 0x10] = save whole hashset ;
    ;-----------------------------------;
    mov     [rsp], rdi                  ; original size saved
    shl     rdi, 0x01                   ; double the size
    lea     r8, [rbx + 0x08]
    mov     dword [r8d], edi            ; update the header * 2
    mov     [rsp + 0x08], rdi           ; save the new/double size
    ;----------------------------
    shl     rdi, 0x03                   ; * 8 for qword
    call_libc malloc
    mov     r13, rax                    ; save ptr to new heap heap
    ;----------------------------
    mov     rdi, rax                    ; pass heap alloc for hashet
    xor     rax, rax                    ; value to store (NULL)
    mov     rcx, [rsp + 0x08]           ; num of 8 byte qwords
    cld                                 ; make sure rdi inc fwd
    rep     stosq                       ; fast NULL out!
    ;----------------------------
    xor     r14, r14                    ; counter
    mov     [rsp + 0x10], rbx           ; save the whole hashset
    mov     r15, [rbx]                  ; get actual hashset data (without header)
    ;----------------------------
    .looping:
        cmp     r14, [rsp]
        jge     .finished_scanning
        ;----------------------------
        cmp     qword [r15 + r14 * 0x08], NULL
        jz      .next_slot
        ;----------------------------
        mov     r12, [r15 + r14 * 0x08]         ; 1st node
        ;----------------------------
        .scan_chain:
            test    r12, r12                    ; empty??
            jz      .next_slot
            ;----------------------------
            mov     rdi, r12
            ;----------------------------
            mov     rsi, [rsp + 0x08]           ; double size
            mov     rdx, r13                    ; pass ONLY the hashset part
            call    insert_node_into_hashset    ; rdi = node [rdi] = KEY, rsi = hashset size, rbx = hashset
            ;-------------------------------------------------
            ; ** IMPORTANT, dont check overwrite/new node flag
            ; we're not adding anything, just copyin data
            ;-------------------------------------------------
            mov     r10, [r12 + 0x10]           ; ptr.next
            mov     qword [r12 + 0x10], NULL    ; for now null out ptr.next on this node
            mov     r12, r10
            jmp     .scan_chain
        ;----------------------------
        .next_slot:
        inc     r14
        jmp     .looping
    ;----------------------------
    .finished_scanning:
    mov     rdi, r15                ; delete the old smaller hashset
    call_libc free
    ;----------------------------
    mov     [rbx], r13              ; insert new hashset
    ;----------------------------
    .finish:
    ;movzx  r8, byte [rbx + 0x0c]
    ;printLine  hashset_expanded, [rsp], [rsp + 0x08], r8
    leave
    ret


delete_node_hashset:
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x10
    ;----------------------------
    mov     rdi, [rts_tos]              ; rdi has KEY
    cmp     rdi, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [rdi]
    mov     [rsp], rdi
    sub     qword [rts_tos], 0x08       ; sub rts, 8
    ;----------------------------
    mov     rsi, [rts_tos]              ; rsi has ptr to hashset
    mov     r13, [rsi]                  ; save ptr to hashset
    mov     [rsp + 0x08], r13
    ;----------------------------
    mov     dword esi, [r13 + 0x08]     ; get SIZE of hashset
    call    generate_str_checksum       ; returns checksum on rax
    ;----------------------------
    mov     r13, [r13]                  ; move into hashset
    mov     r14, [r13 + rax * 0x08]     ; move to that slot
    lea     r13, [r13 + rax * 0x08]     ; set this ptr where r14 is stored, each time we move
    ;----------------------------
    test    r14, r14
    jz      .keyNotFound
    ;----------------------------       ; r13 points behind r14. r14 scans nodes until it finds the key
    mov     rdi, [rsp]
    mov     rsi, [r14]
    call    my_str_cmp
    ;----------------------------
    test    rax, rax                    ; matched?
    jnz     .looping
    ;----------------------------
    mov     rbx, [r14 + 0x10]           ; any nodes connected to this?
    ;----------------------------       ; r13 has *ptr to node to delete. check the leave/free FLAG
    mov     r12, [r13]                  ; jmp to node
    movzx   r15, byte [r12 + 0x18]      ; get node flag info
    test    r15, 0x01                   ; check 1st bit
    jz      .skip_key                   ; if bit = 0 skip key del
    ;----------------------------
    mov     rdi, [r12]                  ; free the key ptr
    call_libc free
    ;----------------------------
    .skip_key:
    test    r15, 0x02                   ; check 2nd bit
    jz      .skip_val                   ; if bit = 0 skip value del
    ;----------------------------
    mov     rdi, [r12 + 0x08]           ; free the val
    call_libc free
    ;----------------------------
    .skip_val:
    mov     rdi, r12                    ; dealloc mem
    call_libc free
    mov     qword [r13], NULL           ; important, make slot available
    ;----------------------------
    test    rbx, rbx                    ; no more nodes, so finish
    jz      .keyFound
    mov     [r13], rbx                  ; point prev ptr to deleted node.next
    jmp     .keyFound
    ;----------------------------
    .looping:                           ; wasn't the 1st node, so scan the whole chain
        test    r14, r14
        jz      .keyNotFound
        ;----------------------------
        mov     rdi, [rsp]
        mov     rsi, [r14]
        call    my_str_cmp
        ;----------------------------
        test    rax, rax
        jnz     .carryOn
        ;----------------------------
        mov     rbx, [r14 + 0x10]           ; any nodes connected to this?
        ;----------------------------
        mov     rdi, [r13 + 0x10]           ; Do we free the key/val for this node?
        movzx   r15, byte [rdi + 0x18]      ; get node flag info
        test    r15, 0x01                   ; check 1st bit
        jz      .skip_key_2                 ; if bit = 0 skip key del
        ;----------------------------
        mov     rdi, [r13 + 0x10]           ; free the key ptr
        mov     rdi, [rdi]
        call_libc free
        ;----------------------------
        .skip_key_2:
        test    r15, 0x02                   ; check 2nd bit
        jz      .skip_val_2                 ; if bit = 0 skip value del
        ;----------------------------
        mov     rdi, [r13 + 0x10]
        mov     rdi, [rdi + 0x08]           ; free the val
        call_libc free
        ;----------------------------
        .skip_val_2:                        ; free actual node
        mov     rdi, [r13 + 0x10]
        call_libc free
        mov     qword [r13 + 0x10], NULL    ;  ???
        ;----------------------------
        test    rbx, rbx
        jz      .keyFound
        ;----------------------------
        .connect:
        mov     [r13 + 0x10], rbx
        jmp     .keyFound
        ;----------------------------
        .carryOn:
        mov     r13, r14
        mov     r14, [r14 + 0x10]           ; set to next.next
        jmp     .looping
    ;----------------------------
    .keyFound:
    mov     rdi, [rts_tos]
    mov     qword [rdi], 0x01               ; push status flag 1 = key found
    mov     r9, [rsp + 0x08]
    dec     dword [r9 + 0x0c]               ; stats --> #nodes--
    xor     ebx, ebx
    leave
    ret
    ;----------------------------
    .keyNotFound:
    mov     rdi, [rts_tos]
    mov     qword [rdi], NULL           ; push status flag 0 = key NOT found
    ;----------------------------
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_56
    jmp     error_need_mult_operands


add_node_hashset:
    ;-------------------------------------------------------------------------------------
    ; order top of stack: [ptr, KEY, VALUE, FLAG] calls insert_node_into_hashset to insert
    ;-------------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----> FLAG lets user decide how to handle KEY & VALUE- -------------->;
    ; Does user/prog free these or does the hash funcs deal with dealloc?  ;
    ;                                                                      ;
    ; FLAG 0 = leave KEY & leave VALUE                                     ;
    ; FLAG 1 = FREE KEY & leave VALUE                                      ;
    ; FLAG 2 = leave KEY & FREE VALUE                                      ;
    ; FLAG 3 = FREE KEY & FREE VALUE                                       ;
    ;<---------------------------------------------------------------------;
    mov     rdi, [rts_tos]
    sub     rdi, 0x18
    cmp     rdi, rts
    jl      .prepare_for_error
    ;----------------------------
    sub     rsp, 0x08
    ;----------------------------
    mov     rdi, 0x19
    ;----------------------------------------
    ; 25 byte node:
    ;       [0] = KEY
    ;       [8] = VALUE
    ;       [16] = *ptrNext
    ;       [24] = flag (key/val keep/free?)
    ;----------------------------------------
    call_libc malloc
    mov     qword [rax + 0x10], NULL    ; null out *ptrNext
    mov     byte [rax + 0x18], NULL     ; null out the flag byte# [24]
    mov     [rsp], rax                  ; save node
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     r8,  [rdi]                  ; <--- DELETE FLAG
    mov     r9,  [rdi - 0x08]
    mov     r10, [rdi - 0x10]
    mov     rbx, [rdi - 0x18]           ; ptr to hashset
    ;----------------------------
    mov     byte [rax + 0x18], r8b      ; store the FLAG
    mov     [rax + 0x08], r9            ; store the VALUE
    mov     [rax], r10                  ; store the KEY
    ;----------------------------
    lea     r8, [rdi - 0x20]
    mov     [rts_tos], r8               ; set [rts_tos]
    ;----------------------------
    mov     rdx, [rbx]                  ; pass ONLY the hashset part
    mov     rdi, rax
    mov     dword esi, [rbx + 0x08]
    call    insert_node_into_hashset    ; rdi = node [rdi] = KEY, rsi = hashset size, rbx = hashset
    test    rdx, rdx                    ; return status, 0 = new node added, 1 = overwrite value (& free node)
    jnz     .check_for_expansion        ; finished
    ;----------------------------
    inc     dword [rbx + 0x0c]          ; ++ # of nodes in this hashset
    ;----------------------------
    .check_for_expansion:
    mov     dword edi, [rbx + 0x08]     ; size of hashset
    mov     dword esi, [rbx + 0x0c]     ; # of nodes
    ;----------------------------
    mov     r9, rdi
    shr     rdi, 0x01                   ; 1/2 hashset size
    shr     r9, 0x02                    ; 1/4 hashset size
    add     rdi, r9                     ; 3/4 hashset size
    ;----------------------------
    cmp     rsi, rdi                    ; cmp 3/4 hashset with # of nodes
    jng     .finished
    mov     dword edi, [rbx + 0x08]
    call    expand_hashset
    ;----------------------------
    ; need to recover rsi, rdi, rbx properly here
    ;----------------------------
    .finished:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x04
    mov     rsi, operator_53
    jmp     error_need_mult_operands


add_node_hashset_fixed:
    ;------------------------------------------------------------------------------------
    ; order top of stack: ptr, KEY, VALUE , FLAG calls insert_node_into_hashset to insert
    ;------------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    mov     rdi, [rts_tos]
    sub     rdi, 0x18
    cmp     rdi, rts
    jl      .prepare_for_error
    ;----------------------------
    sub     rsp, 0x08
    ;----------------------------
    mov     rdi, 0x19
    ;------------------------------------
    ; 25 byte node:
    ;   [0] = KEY
    ;   [8] = VALUE
    ;   [16] = *ptrNext
    ;   [24] = flag (key/val keep/free?)
    ;------------------------------------
    call_libc malloc
    mov     qword [rax + 0x10], NULL    ; null out *ptrNext
    mov     byte [rax + 0x18], NULL     ; null out the flag byte# [24]
    mov     [rsp], rax                  ; save node
    ;----------------------------
    mov     rdi, [rts_tos]
    mov     r8,  [rdi]
    mov     r9,  [rdi - 0x08]
    mov     r10, [rdi - 0x10]
    mov     rbx, [rdi - 0x18]           ; ptr to hashset
    ;----------------------------
    mov     byte [rax + 0x18], r8b      ; store the FLAG
    mov     [rax + 0x08], r9            ; store the VALUE
    mov     [rax], r10                  ; store the KEY
    ;----------------------------
    lea     r8, [rdi - 0x20]
    mov     [rts_tos], r8               ; set [rts_tos]
    ;----------------------------
    mov     rdx, [rbx]                  ; pass ONLY the hashset part
    mov     rdi, rax
    mov     dword esi, [rbx + 0x08]
    call    insert_node_into_hashset    ; rdi = node [rdi] = KEY, rsi = hashset size, rbx = hashset
    test    rdx, rdx                    ; return status, 0 = new node added, 1 = overwrite value (and free node)
    jnz     .finished                   ; finished
    ;----------------------------
    inc     dword [rbx + 0x0c]          ; ++ # of nodes in this hashset
    ;----------------------------
    .finished:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x04
    mov     rsi, operator_53
    jmp     error_need_mult_operands


insert_node_into_hashset:
    ;-----------------------------------------------------------
    ; rdi = node [rdi] = KEY
    ; rsi = hashset size
    ; rdx = actual hashset (NOT the 16 byte header + hashset!!)
    ;-----------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    sub     rsp, 0x08
    mov     [rsp], rdi                  ; save copy of node
    ;----------------------------
    mov     rdi, [rdi]                  ; get KEY, size already on rsi
    call    generate_str_checksum       ; returns checksum on rax
    ;----------------------------
    mov     r11, [rdx + rax * 0x08]     ; move to that slot
    test    r11, r11                    ; is the slot free?
    jnz     .insert_into_link
    ;----------------------------
    mov     r8, [rsp]
    mov     [rdx + rax * 0x08], r8      ; save the node in the 1st slot
    xor     rdx, rdx                    ; status flag, no over write, just new node added
    jmp     .finish
    ;----------------------------
    .insert_into_link:
    mov     r10, [rdx + rax * 0x08]     ; points to node
    mov     r11, [r10 + 0x10]           ; points to node.next
    ;----------------------------
    .looping:
        test    r11, r11
        jz      .insert_node
        ;----------------------------
        mov     rdi, [rsp]
        mov     rdi, [rdi]              ; node key
        mov     rsi, [r10]              ; existing node key
        call    my_str_cmp              ; if keys match, DON'T insert, just overwrite val
        ;----------------------------
        test    rax, rax
        jz      .over_write_val
        ;----------------------------
        .next_node:
        mov     r10, r11                ; set to next
        mov     r11, [r10 + 0x10]       ; set to next.next
        jmp     .looping
    ;----------------------------
    .insert_node:
    mov     rdi, [rsp]
    mov     rdi, [rdi]                  ; node key
    mov     rsi, [r10]                  ; existing node key
    call    my_str_cmp                  ; if keys match, DON'T insert, just overwrite val
    ;----------------------------
    test    rax, rax
    jnz     .new_key
    ;----------------------------
    .over_write_val:
    mov     r12, r10
    ;mov        rcx, [r12 + 0x08]
    movzx   r8, byte [r12 + 0x18]
    test    r8, 0x02                    ; should node value be free'd?
    jz      .skip_val_free
    ;----------------------------
    mov     rdi, [r12 + 0x08]           ; 1st FREE old value
    call_libc free
    ;----------------------------
    .skip_val_free:
    mov     rsi, [rsp]
    movzx   r8, byte [rsi + 0x18]
    test    r8, 0x01                    ; should node value be free'd?
    jz      .skip_key_free
    ;----------------------------
    mov     rsi, [rsp]
    mov     rdi, [rsi]                  ; 1st FREE old value
    call_libc free
    ;----------------------------
    .skip_key_free:
    mov     rcx, [rsp]
    mov     rsi, [rcx + 0x08]           ; Grab val
    movzx   rax, byte [rcx + 0x18]      ; Grab FLAG
    mov     [r12 + 0x08], rsi           ; now overwrite value with new value from node
    mov     byte [r12 + 0x18], al       ; now overwrite FLAG with new value from node
    ;----------------------------
    mov     rdi, [rsp]
    call_libc free                      ; deallocate the node!! not needed anymore
    ;----------------------------
    mov     rdx, 0x01                   ; flag for overwrite = 1
    jmp     .finish
    ;----------------------------
    .new_key:
    mov     r8, [rsp]
    mov     [r10 + 0x10], r8
    xor     rdx, rdx                    ; flag for insert = 0
    ;----------------------------
    .finish:
    leave
    ret

hashset_node_exists:
    ;-----------------------------------------------------------------------------------
    ; order on top of stack: ptr, KEY. returns: 0 = not found, != 0 = ptr to VALUE found.
    ;------------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [r13]
    mov     r12, rdi                    ; Save the key...
    sub     r13, 0x08
    mov     [rts_tos], r13              ; pop off stack
    ;----------------------------
    mov     r15, [r13]                  ; save ptr to hashset
    ;----------------------------
    mov     dword esi, [r15 + 0x08]     ; get SIZE of hashset
    call    generate_str_checksum       ; returns checksum on rax
    ;----------------------------
    mov     rdx, [r15]
    mov     r14, [rdx + rax * 0x08]     ; move to that slot
    ;----------------------------
    test    r14, r14
    jz      .keyNotFound
    ;----------------------------
    .looping:
        test    r14, r14
        jz      .keyNotFound
        ;----------------------------
        mov     rdi, r12
        mov     rsi, [r14]
        call    my_str_cmp
        ;----------------------------
        test    rax, rax
        jnz     .carryOn
        ;----------------------------
        lea     rsi, [r14 + 0x08]       ; Get *ptr to value
        mov     [r13], rsi              ; and push it on
        jmp     .finish
        ;----------------------------
        .carryOn:
        mov     r14, [r14 + 0x10]   ; set to next.next
        jmp     .looping
    ;----------------------------
    .keyNotFound:
    mov     qword [r13], NULL       ; null ptr = not found
    ;----------------------------
    .finish:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_231
    jmp     error_need_mult_operands


get_node_hashset:
    ;-------------------------------------------------------------------------------
    ; order on top of stack: ptr, KEY. returns: pushed FLAG 0 = not found, 1 = found.
    ; if found, then below FLAG is VALUE for node key
    ;--------------------------------------------------------------------------------
    push    rbp
    mov     rbp, rsp
    ;----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jle     .prepare_for_error
    ;----------------------------
    mov     rdi, [r13]
    mov     r12, rdi                    ; Save the key...
    sub     r13, 0x08
    mov     [rts_tos], r13              ; pop off stack
    ;----------------------------
    mov     r15, [r13]                  ; save ptr to hashset
    ;----------------------------
    mov     dword esi, [r15 + 0x08]     ; get SIZE of hashset
    call    generate_str_checksum       ; returns checksum on rax
    ;----------------------------
    mov     rdx, [r15]
    mov     r14, [rdx + rax * 0x08]     ; move to that slot
    ;----------------------------
    test    r14, r14
    jz      .keyNotFound
    ;----------------------------
    .looping:
        test    r14, r14
        jz      .keyNotFound
        ;----------------------------
        mov     rdi, r12
        mov     rsi, [r14]
        call    my_str_cmp
        ;----------------------------
        test    rax, rax
        jnz     .carryOn
        ;----------------------------
        mov     rsi, [r14 + 0x08]       ; Get *ptr to value
        mov     [r13], rsi              ; and push it on
        add     r13, 0x08
        mov     qword [r13], 0x01       ; push on found FLAG = 1
        mov     [rts_tos], r13
        jmp     .finish
        ;----------------------------
        .carryOn:
        mov     r14, [r14 + 0x10]   ; set to next.next
        jmp     .looping
    ;----------------------------
    .keyNotFound:
    mov     qword [r13], NULL       ; push on null FLAG = not found
    ;----------------------------
    .finish:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_55
    jmp     error_need_mult_operands


create_operator_hashset:
    push    rbp
    mov     rbp, rsp
    ;----------------------------   ; set all hashset values to NULL to start with
    xor     rbx, rbx                ; counter
    xor     rcx, rcx
    mov     r13, [op_hashset]       ; r13 = ptr to hashset
    ;----------------------------
    .loopingNULL:
        cmp     rbx, MAX_HASH_SET
        je      .addNodes           ; after we NULL all entries, then we add all the operator nodes
        ;----------------------------
        mov     [r13 + rbx * 0x08], rcx
        inc     rbx
        jmp     .loopingNULL
    ;----------------------------
    ;mov    rdi, [op_hashset]       ; ptr to block
    ;xor    rax, rax                ; val to store = NULL
    ;mov    rcx, MAX_HASH_SET       ; num of 8 byte qwords
    ;cld                            ; rdi incs fwd
    ;rep    stosq                   ; fast NULL out
    ;----------------------------
    .addNodes:
    xor     rbx, rbx                ; scan through all the operator names and add them to the hashset
    ;----------------------------
    .loopingAddNodes:
        cmp     rbx, OP_SIZE        ; max number of operators
        je      .ended
        ;----------------------------
        mov     rdi, 0x12           ; 18 bytes for our node
        call_libc malloc
        ;----------------------------
        mov     r12, rax                        ; r12 has ptr to node
        mov     rcx, [all_ops + rbx * 0x08]     ; get the operator name
        mov     [r12], rcx                      ; update 1st 8 bytes with opertor name str
        ;----------------------------
        mov     rdi, rcx
        mov     rsi, MAX_HASH_SET
        call    generate_str_checksum           ; rax = index of where to insert in op_hashset
        mov     word [r12 + 0x10], bx           ; 2 byte index added to find matching func in map_funcs array
        ;----------------------------
        mov     qword [r12 + 0x08], NULL        ; NULL the *next ptr
        ;----------------------------
        cmp     qword [r13 + rax * 0x08], NULL
        je      .firstSlotAvailable
        ;----------------------------           ; we have a clash! so add to the end of the linked list
        mov     r14, [r13 + rax * 0x08]         ; use r14 to scan the linked list
        ;----------------------------
        .findNextAvailableSlot:
            cmp     qword [r14 + 0x08], NULL    ; is there space to add it here?
            jne     .moveToNextLinkedNode
            ;----------------------------
            mov     [r14 + 0x08], r12           ; add new node to this slot
            jmp     .nextNode
            ;----------------------------
            .moveToNextLinkedNode:
            mov     r14, [r14 + 0x08]
            jmp     .findNextAvailableSlot

        .firstSlotAvailable:
        mov     [r13 + rax * 0x08], r12     ; add node straight into hashset
        ;----------------------------
        .nextNode:
        inc     rbx
        jmp     .loopingAddNodes
    ;----------------------------
    .ended:
    leave
    ret

generate_str_checksum:
    ;-----------------------------
    ; **** DON'T DIRECTLY CALL THIS FROM THE ./PROGRAM!! ONLY FROM ANOTHER FUNC!! ****
    ; rdi = string, rsi =  MAX range/size of hashset (must be multiple of 2^n)
    ; rax returns the checksum, we mult by 31 (prime number)
    ; 1) total *= 31 and then 2) total += char (ascii)
    ;-----------------------------
    xor     rax, rax        ; total
    xor     r9, r9          ; byte value in ascii
    .looping:
        cmp     byte [rdi], NULL    ; reached end of string?
        je      .ended
        ;-----------------------------
        mov     r9, rax
        shl     rax, 0x05       ; shl 5 on total = total X 32
        sub     rax, r9         ; total X 32 - total = total X 31
        ;-----------------------------
        movzx   r9, byte [rdi]
        add     rax, r9
        ;-----------------------------
        inc     rdi             ; move along the string
        jmp     .looping
    ;-----------------------------
    .ended:
    ;-----------------------------
    dec     rsi
    and     rax, rsi            ; bitmask and with size - 1 (must be 2^n)
    ret


dump_tokens:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    xor     r13, r13
    mov     r12, qword [argv_ptr]
    ;-----------------------------
    .looping:
        cmp     r13, qword [argv_len]
        je      .ended
        ;-----------------------------
        printLine indexMemLoc, r13, [r12 + r13 * 0x08], [r12 + r13 * 0x08]
        inc     r13
        jmp     .looping
    ;-----------------------------
    .ended:
    leave
    ret

find_tokens_len:                ; [argv_len] is updated with the number of tokens
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    xor     r12, r12
    mov     r8, [heap_alloc_file]
    call    read_delims
    ;-----------------------------
    .looping:
        cmp     byte [r8], NULL
        je      .ended
        ;-----------------------------
        call    read_chars_and_match_quotes
        inc     r12
        ;-----------------------------
        call    read_delims
        jmp     .looping
    ;-----------------------------
    .ended:
    mov     [argv_len], r12
    leave
    ret

read_chars_and_match_quotes:        ; r8 string, halts on a delim
    ;-----------------------------
    .looping:
        cmp     byte [r8], NULL
        je      .ended
        ;-----------------------------
        cmp     byte [r8], speechQuote
        jne     .check_delim
        ;-----------------------------
        inc     r8
        cmp     byte [r8], NULL
        je      .error_missing_quote
        ;-----------------------------
        .match_quote:
            cmp     byte [r8], speechQuote
            jz      .found_ending_quote
            ;-----------------------------
            inc     r8
            jmp     .match_quote
        ;-----------------------------
        .check_delim:
        mov     rdi, r8
        call    is_delim                    ; rax is 0 if not delim, 1 if delim
        ;-----------------------------
        test    rax, rax
        jnz     .ended
        ;-----------------------------
        inc     r8
        jmp     .looping
    ;-----------------------------
    .error_missing_quote:
    printLine   error_missing_quote_msg, r8
    jmp     exit
    ;-----------------------------
    .found_ending_quote:                    ; need to +1 byte or remains on " !!
    inc     r8
    .ended:
    ret

read_chars:                                 ; r8 string, halts on a delim
    ;-----------------------------
    .looping:
        cmp     byte [r8], NULL
        je      .ended
        ;-----------------------------
        mov     rdi, r8
        call    is_delim                    ; rax is 0 if not delim, 1 if delim
        ;-----------------------------
        test    rax, rax
        jnz     .ended
        ;-----------------------------
        inc     r8
        jmp     .looping
    ;-----------------------------
    .ended:
    ret

read_delims:                                ; r8 string, halts on a char
    ;-----------------------------
    .looping:
        cmp     byte [r8], NULL
        je      .ended
        ;-----------------------------
        mov     rdi, r8
        call    is_delim                    ; rax is 0 if not delim, 1 if delim
        ;-----------------------------
        test    rax, rax
        jz      .ended
        ;-----------------------------
        inc     r8
        jmp     .looping
    ;-----------------------------
    .ended:
    ret


halt_on_user_delim_and_quotes:
    ;------------------------------------------------------------------------------------
    ; r8 = input string, r9 = user delims string
    ; stop r8 when char == a delim or EOS, if we find a " then at LEAST find the next one
    ;-------------------------------------------------------------------------------------
    .looping:
        cmp     byte [r8], NULL     ; stop if matched or EOS
        je      .ended
        ;-----------------------------
        cmp     byte [r8], speechQuote
        jne     .prepare_delims
        inc     r8
        ;-----------------------------
        .matching_speech_quote:
            cmp     byte [r8], NULL ; end of string? error! no matching quote found!!
            je      .end_quote_not_found
            ;-----------------------------
            cmp     byte [r8], speechQuote
            je      .prepare_delims
            ;-----------------------------
            inc     r8
            jmp     .matching_speech_quote
        ;-----------------------------
        .prepare_delims:
        mov     r10, r9
        ;-----------------------------
        .check_all_delims:
            cmp     byte [r10], NULL
            je      .carryOn
            ;-----------------------------
            movzx   r11, byte [r10]
            ;-----------------------------
            cmp     byte [r8], r11b
            je      .ended
            ;-----------------------------
            .next_delim:
            inc     r10
            jmp     .check_all_delims
        ;-----------------------------
        .carryOn:
        inc     r8
        jmp     .looping
    ;-----------------------------
    .ended:
    ret
    .end_quote_not_found:
    printLine   missingSpeech
    jmp     exit


ignore_user_delim:                  ; r8 = input string, r9 = user delims string
    ;-----------------------------  ; stop r8 when char != a delim or EOS
    .looping:
        cmp     byte [r8], NULL     ; stop if matched or EOS
        je      .ended
        ;-----------------------------
        mov     r10, r9
        ;-----------------------------
        .check_all_delims:
            cmp     byte [r10], NULL
            je      .ended
            ;-----------------------------
            movzx   r11, byte [r10]
            ;-----------------------------
            cmp     byte [r8], r11b
            je      .carryOn
            ;-----------------------------
            .next_delim:
            inc     r10
            jmp     .check_all_delims
        ;-----------------------------
        .carryOn:
        inc     r8
        jmp     .looping
    ;-----------------------------
    .ended:
    ret


find_next_non_delimRSI:                     ; changes rsi to next NON-delim
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    push    rdi
    .looping:
        cmp     byte [rsi], NULL
        je      .ended
        ;-----------------------------
        mov     rdi, rsi
        call    is_delim                    ; rax is 0 if not delim, 1 if delim
        test    rax, rax
        jz      .ended
        ;-----------------------------
        .carryOn:
        inc     rsi
        jmp     .looping
    ;-----------------------------
    .ended:
    pop     rdi
    leave
    ret

is_delim:
    ;-----------------------------
    movzx   r11, byte [rdi]
    movzx   rax, byte [delim_table + r11]
    ;-----------------------------
    ret

quote_to_quote:             ; we've found a single '"', now shift r10 to the next one or EOF.
    ;-----------------------------
    inc     r10             ; move one byte ahead of the first '"'
    xor     rdx, rdx
    ;-----------------------------
    .looping:
        cmp     byte [r10], NULL
        je      .ended
        ;-----------------------------
        cmp     byte [r10], 0x22        ; 34
        je      .matchedSpeechMark
        ;-----------------------------
        inc     r10
        jmp     .looping

    .matchedSpeechMark:
    inc     rdx         ; let calling func know we found a matching end '"'
    ;-----------------------------
    .ended:
    ret

quote_to_quoteRSI:      ; we've found a single '"', now shift rsi to the next one or EOF.
    ;-----------------------------
    inc     rsi         ; move one byte ahead of the first '"'
    xor     rdx, rdx
    ;-----------------------------
    .looping:
        cmp     byte [rsi], NULL
        je      .ended
        ;-----------------------------
        cmp     byte [rsi], 0x22        ; 34
        je      .matchedSpeechMark
        ;-----------------------------
        inc     rsi
        jmp     .looping

    .matchedSpeechMark:
    inc     rdx         ; let calling func know we found a matching end '"'
    ;-----------------------------
    .ended:
    ret

split_tokens:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    sub     rsp, 0x08                       ; speech mark FLAG
    ;-----------------------------
    mov     r8, [heap_alloc_file]
    call    read_delims                     ; skip delims at start and get to char
    ;-----------------------------
    mov     r15, r8                         ; *fwd
    mov     r14, r8                         ; *start
    mov     r12, [argv_ptr]
    xor     rbx, rbx                        ; insert pos
    mov     [rsp], rbx                      ; speech mark FLAG = false
    ;-----------------------------
    .looping:
        cmp     byte [r15], NULL
        je      .ended
        ;-----------------------------
        cmp     byte [r15], speechQuote
        jne     .regular_token
        ;-----------------------------
        mov     r10, r15
        call    quote_to_quote
        mov     r15, r10                    ; *fwd now on last " of string
        inc     r14                         ; *start ++ after the char "
        inc     qword [rsp]                 ; speech mark FLAG = true
        jmp     .build_token
        ;-----------------------------
        .regular_token:
        mov     r8, r15
        call    read_chars
        mov     r15, r8                     ; *fwd now on last " of string
        ;-----------------------------
        .build_token:
        mov     r13, r15
        sub     r13, r14                    ; how many bytes do we need?
        ;-----------------------------
        cmp     qword [debug_mode], NULL
        je      .mallocBytes
        ;-----------------------------
        lea     r11, [r13 + 0x01]
        printLine   bytesMalloc, r11
        printLine   dashes2
        ;-----------------------------
        .mallocBytes:
        mov     rdi, r13
        inc     rdi
        call_libc malloc
        ;-----------------------------
        mov     [r12 + rbx * 0x08], rax
        mov     byte [rax + r13], NULL
        ;-----------------------------
        mov     rdi, rax                        ; heap
        mov     rsi, r14                        ; start of the string
        mov     rdx, r13                        ; # of bytes we copy (reduced by 1 earlier)
        call    copy_bytes                      ; strncpy
        ;-----------------------------
        cmp     qword [rsp], 0x01               ; did we build a quote string "...." ?
        jne     .skip_delims
        ;-----------------------------
        dec     qword [rsp]                     ; reset speech mark FLAG = false
        inc     r15                             ; go past " onto delim
        ;-----------------------------
        .skip_delims:
        mov     r8, r15
        call    read_delims
        mov     r15, r8
        mov     r14, r8
        ;-----------------------------
        inc     rbx
        jmp     .looping

    .ended:
    mov     qword [r12 + rbx * 0x08], NULL
    ;-----------------------------
    cmp     qword [debug_mode], NULL
    je      .fin
    printLine   debugInsertPos, rbx
    ;-----------------------------
    .fin:
    leave
    ret

trim_string:
    ;-----------------------------
    mov     rbx, [rts_tos]
    cmp     rbx, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     r12, [rbx]              ; r12 = *start_ptr
    mov     r8, r12
    mov     r9, DELIMS              ; space, tab, nl, vtab
    call    ignore_user_delim       ; ++ *start_ptr to 1st non-delim
    ;-----------------------------
    cmp     byte [r8], NULL
    je      .empty_string           ; no data, just white spaces
    ;-----------------------------
    mov     r12, r8
    mov     r13, r12                ; r13 = *end_ptr
    ;-----------------------------
    .get_to_EOS:
        cmp     byte [r13], NULL
        je      .next_check
        ;-----------------------------
        inc     r13
        jmp     .get_to_EOS
    ;-----------------------------
    .next_check:
    dec     r13                     ; non-empty string so start -1 char from EOS
    ;-----------------------------
    .fix_end_ptr:                   ; -- *end_ptr until last non-delim
        cmp     r13, r12
        je      .halt_trim          ; should not happen really!! should break earlier
        ;-----------------------------
        mov     r10, DELIMS
        ;-----------------------------
        .check_for_delims:          ; if *end_ptr is NOT in the list, then halt
            cmp     r10, DELIMS + DELIMS_SIZE
            je      .halt_trim      ; first non-delim matched
            ;-----------------------------
            mov     byte r11b, [r10]
            cmp     byte r11b, [r13]
            je      .next_dec
            ;-----------------------------
            .next_delim:
            inc     r10
            jmp     .check_for_delims
        ;-----------------------------
        .next_dec:
        dec     r13
        jmp     .fix_end_ptr
    ;-----------------------------
    .halt_trim:                     ; calc size & make new string r12 --> r13, then push onto stack
    mov     r14, r13
    sub     r14, r12                ; saved size for copying
    mov     rdi, r14
    add     rdi, 0x02               ; need to inc '\0'
    call_libc malloc
    ;-----------------------------
    mov     [rbx], rax              ; pushed on
    inc     r14
    mov     byte [rax + r14], NULL
    mov     rdx, r14
    mov     rsi, r12
    mov     rdi, rax
    call    copy_bytes
    jmp     .ended
    ;-----------------------------
    .empty_string:
    mov     qword [rbx], NULL
    .ended:
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_204
    jmp     error_need_1_operand


string_to_sockaddr:
    ;-----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, 0x10
    call_libc malloc
    mov     r12, rax
    mov     rdi, [r13]
    ;-----------------------------
    mov     word [r12], 0x02
    xor     r8, r8                      ; store final 32 bit ip
    mov     rcx, 0x04
    ;-----------------------------
    .octet_loop:
        push    rcx                     ; save loop counter
        call    parse_ascii_to_num      ; returns us number in rax, updates rdi
        ;-----------------------------
        shl     r8, 0x08                ; shift bytes up
        or      r8b, al                 ; add new byte at end
        ;-----------------------------
        pop     rcx                     ; resume loop counter
        cmp     rcx, 0x01               ; last oct?
        je      .ip_done                ; if true we're at --> ':'
        inc     rdi                     ; if now skip ip '.'
        loop    .octet_loop
        ;-----------------------------
    .ip_done:                           ; store ip offset + 4
    mov     [r12 + 0x04], r8d           ; offset + 4 bytes
    ;-----------------------------      ; port section
    inc     rdi                         ; go past ':' to get port num
    call    parse_ascii_to_num          ; gives us 16 bit port in ax
    xchg    al, ah                      ; remember!! port is BIG ENDIAN!!
    mov     [r12 + 0x02], ax            ; store port offset 2
    mov     qword [r12 + 0x08], NULL
    ;-----------------------------
    mov     rdx, [rts_tos]
    mov     [rdx], r12
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_220
    jmp     error_need_1_operand

parse_ascii_to_num:
    ;-----------------------------
    xor     rax, rax
    xor     rbx, rbx
    .digit_loop:
    ;-----------------------------
        movzx   rbx, byte [rdi]
        sub     bl, 0x30                 ; '0'
        cmp     bl, 0x09
        ja      .done                    ; If not 0-9, we hit a delimiter (., :, or \0)
        ;-----------------------------
        imul    rax, 0x0a
        add     rax, rbx
        inc     rdi
        jmp     .digit_loop
    ;-----------------------------
    .done:
    ret

conv_hex_to_ip_port:
    ;-----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, 0x16           ; 204.101.199.221:65535\0 = 22 byte
    call_libc malloc
    mov     r12, rax
    mov     r15, rax            ; ptr to start of heap
    mov     rsi, 0x01           ; FLAG
    ;-----------------------------
    mov     rdi, [r13]
    call    hex_to_ip_port
    ;-----------------------------
    mov     rdi, [rts_tos]
    mov     [rdi], r15
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_218
    jmp     error_need_1_operand

conv_hex_to_ip:
    ;-----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, 0x10           ; 204.101.199.221\0 = 16 byte
    call_libc malloc
    mov     r12, rax
    mov     r15, rax            ; ptr to start of heap
    xor     rsi, rsi            ; FLAG
    ;-----------------------------
    mov     rdi, [r13]
    call    hex_to_ip_port
    ;-----------------------------
    mov     rdi, [rts_tos]
    mov     [rdi], r15
    xor     ebx, ebx
    ;-----------------------------
    ret
    .prepare_for_error:
    mov     rsi, operator_207
    jmp     error_need_1_operand

hex_to_ip_port:
    ; -------------------------------------------;
    ; rdi = ptr to hex string                    ;
    ; r12 = ptr to heap                          ;
    ; rsi = FLAG --> 0 = ip only, 1 = ip & port  ;
    ; r12 = result string                        ;
    ; -------------------------------------------;
    mov     rcx, 0x08               ; 8 char
    call    build_hex_to_rax
    ;-----------------------------  ; ip bytes --> str
    mov     rbx, rax
    mov     r13, 0x04               ; do loop for 4 X oct
    ;-----------------------------
    .ip_loop:
        movzx   rax, bl
        call    write_num_to_buf
        ;-----------------------------
        dec     r13
        jz      .check_port         ; end of ip, do we need port?
        mov     byte [r12], 0x2e    ; char '.'
        inc     r12
        shr     rbx, 0x08
        jmp     .ip_loop
    ;-----------------------------
    .check_port:
    test    rsi, rsi                 ; is FLAG zero?
    jz      .done                    ; yes, skip port section
    ;-----------------------------   ; add port
    mov     byte [r12], 0x3a         ; char ':'
    inc     r12
    ;-----------------------------
    mov     rcx, 0x04                ; conv next 4 hex char
    call    build_hex_to_rax
    call    write_num_to_buf
    ;-----------------------------
    .done:
    mov     byte [r12], NULL        ; EOS null term......
    ret


build_hex_to_rax:
    ;-----------------------------
    xor     rax, rax
    ;-----------------------------
    .build_loop:
        shl     rax, 0x04
        movzx   edx, byte [rdi]
        mov     r8b, dl                 ; save orig
        or      dl, 0x20                ; flip to upper
        ;-----------------------------
        cmp     dl, 0x61                ; char 'a'
        jb      .is_digit
        sub     dl, 0x57                ; sub 0x61 - 0x0a = 0x57
        jmp     .next
        ;-----------------------------
        .is_digit:
        mov     dl, r8b
        sub     dl, 0x30                ; char '0'
        ;-----------------------------
        .next:
        or      al, dl
        inc     rdi
        loop    .build_loop
    ret


write_num_to_buf:
    ;-----------------------------
    xor     r10, r10
    mov     r11, 0x0a
    ;-----------------------------
    .div_loop:
        xor     rdx, rdx
        div     r11w
        ;-----------------------------
        push    rdx
        inc     r10
        test    ax, ax
        jnz     .div_loop
    ;-----------------------------
    .write_loop:
        pop     rdx
        add     dl, 0x30                ; char '0'
        ;-----------------------------
        mov     [r12], dl
        inc     r12
        dec     r10
        jnz     .write_loop
    ret


is_even_tos:
    ;-----------------------------
    mov     rax, [rts_tos]      ; get ptr top of stack
    cmp     rax, rts
    jl      .prepare_for_error
    mov     rdx, [rax]          ; grab value into rdx
    ;-----------------------------
    and     rdx, 0x01           ; null out all but 1st bit. rdx = 0 (even) or 1 (odd)
    xor     rdx, 0x01           ; flip rdx = 1 (even) or 0 (odd)
    mov     [rax], rdx          ; update top of stack
    ;-----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_208
    jmp     error_need_1_operand

is_odd_tos:
    ;-----------------------------
    mov     rax, [rts_tos]      ; get ptr top of stack
    cmp     rax, rts
    jl      .prepare_for_error
    mov     rdx, [rax]          ; grab value into rdx
    ;-----------------------------
    and     rdx, 0x01           ; null out all but 1st bit. rdx = 1 (odd) or 0 (even)
    mov     [rax], rdx          ; update top of stack
    ;-----------------------------
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rsi, operator_209
    jmp     error_need_1_operand

str_to_lower:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, [r13]
    xor     rbx, rbx
    call    flip_case_string
    ;-----------------------------
    mov     [r13], rbx
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_212
    jmp     error_need_1_operand

str_to_upper:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     r13, [rts_tos]
    cmp     r13, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     rdi, [r13]
    xor     rbx, rbx
    or      rbx, 0x01
    call    flip_case_string
    ;-----------------------------
    mov     [r13], rbx
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_211
    jmp     error_need_1_operand


starts_with_str:                ; [string, search]
    ;-----------------------------
    xor     rax, rax            ; result
    mov     rdx, [rts_tos]
    cmp     rdx, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rdi, [rdx]
    mov     rsi, [rdx - 0x08]
    ;-----------------------------
    .check_start:
        cmp     byte [rdi], NULL
        je      .matched
        ;-----------------------------
        mov     byte r8b, [rdi]
        cmp     byte [rsi], r8b
        jne     .ended
        ;-----------------------------
        inc     rdi
        inc     rsi
        jmp     .check_start
    .matched:
    inc     rax
    ;-----------------------------
    .ended:
    mov     [rdx - 0x08], rax
    sub     qword [rts_tos], 0x08
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_213
    jmp     error_need_mult_operands

ends_with_str:
    ;-----------------------------
    xor     r14, r14            ; result = 0
    mov     rdx, [rts_tos]
    cmp     rdx, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     rdi, [rdx]          ; rdi = search string
    sub     qword [rts_tos], 0x08
    mov     rdx, [rts_tos]
    mov     rsi, [rdx]          ; rsi = main string
    ;-----------------------------
    mov     r12, rdi            ; save start of search
    mov     r13, rsi            ; save start of main str
    ;-----------------------------
    call    str_len
    mov     r15, rax            ; r15 = search_len
    ;-----------------------------
    mov     rdi, rsi
    call    str_len             ; rax = main_len
    ;-----------------------------
    cmp     rax, r15
    jl      .ended              ; main_len < search_len --> return 0 now!
    ;-----------------------------
    mov     rdi, r12            ; restore str ptr
    ;-----------------------------
    .get_to_end_main:
        cmp     byte [rsi], NULL
        je      .get_to_end_search
        inc     rsi
        jmp     .get_to_end_main
    ;-----------------------------
    .get_to_end_search:
        cmp     byte [rdi], NULL
        je      .check_start
        inc     rdi
        jmp     .get_to_end_search
    ;-----------------------------
    .check_start:
        cmp     rdi, r12
        jl      .matched            ; matched the whole search string len? --> matched
        ;-----------------------------
        mov     byte r8b, [rdi]
        cmp     byte [rsi], r8b
        jne     .ended
        ;-----------------------------
        dec     rdi
        dec     rsi
        jmp     .check_start
    .matched:
    inc     r14
    ;-----------------------------
    .ended:
    mov     rdi, [rts_tos]
    mov     [rdi], r14          ; push on res (0,1)
    xor     ebx, ebx
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_214
    jmp     error_need_mult_operands


flip_case_string:
    ;--------------------------------------------------------
    ; r13/rdi = str.
    ; when rbx = 0 convert to lower, rbx = 1 convert to upper
    ;--------------------------------------------------------
    mov     r14, 0x61               ; 'a'
    mov     r15, 0x7a               ; 'z'
    test    rbx, rbx
    ;-----------------------------
    jnz     .start_convert
    sub     r14, 0x20
    sub     r15, 0x20
    .start_convert:
    ;-----------------------------
    call    str_len
    ;-----------------------------
    test    rax, rax
    jz      .empty_str
    ;-----------------------------
    mov     rdi, rax
    inc     rdi
    call_libc malloc
    mov     rbx, rax
    ;-----------------------------
    mov     rdi, [r13]
    .convert_upper:
        cmp     byte [rdi], NULL
        je      .null_term
        ;-----------------------------
        mov     byte r11b, [rdi]
        cmp     byte r11b, r14b         ; < lower range a/A
        jl      .copy_byte
        ;-----------------------------
        cmp     byte r11b, r15b         ; > upper range z/Z
        jg      .copy_byte
        ;-----------------------------
        xor     byte r11b, 0x20         ; toggle/flip 6th bit #32
        .copy_byte:
        ;-----------------------------
        mov     byte [rax], r11b
        inc     rax
        inc     rdi
        jmp     .convert_upper
    ;-----------------------------
    .null_term:
    mov     byte [rax], NULL
    jmp     .ended
    ;-----------------------------
    .empty_str:
    mov     rdi, 0x01
    call_libc malloc
    mov     byte [rax], NULL
    mov     rbx, rax
    ;-----------------------------
    .ended:
    ret


join_string:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    sub     rsp, 0x20
    ;-----------------------------
    ;[rsp]      --> # of strings to join
    ;[rsp + 8]  --> delim
    ;[rsp + 16] --> marker for last str, use it to iterate until the top
    ;[rsp + 24] --> total bytes
    ;-----------------------------
    mov     rdi, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     rdi, rsi
    jl      .prepare_for_error
    ;-----------------------------
    mov     r8, [rdi]
    ;-----------------------------
    cmp     r8, 0x01
    jle     .join_not_needed
    ;-----------------------------
    mov     [rsp], r8
    ;-----------------------------
    mov     rsi, [rdi - 0x08]
    mov     [rsp + 0x08], rsi
    ;-----------------------------
    lea     r9, [rdi - 0x08]
    shl     r8, 0x03
    sub     r9, r8
    mov     [rsp + 0x10], r9    ; will now be on the index of the last string
    ;-----------------------------
    ;printLine      join_debug, r8, [rsp + 0x08], [r9] ; #, delim, string start
    ;-----------------------------
    xor     rbx, rbx            ; count all string lengths
    ;-----------------------------
    .get_total_string_size:
        test    r8, r8
        jz      .delim_len
        ;-----------------------------
        mov     rdi, [r9]
        call    str_len
        add     rbx, rax
        sub     r8, 0x08
        add     r9, 0x08
        jmp     .get_total_string_size
        ;-----------------------------
    .delim_len:
    mov     [rsp + 0x18], rbx
    mov     rdi, [rsp+ 0x08]
    call    str_len
    ;-----------------------------
    mov     rsi, [rsp]
    dec     rsi
    imul    rsi, rax                        ; n - 1 strings X (delim length)
    add     rbx, rsi
    mov     [rsp + 0x18], rbx               ; store total number of bytes WITHOUT '\0'
    ;printLine      join_debug2, rbx, [r9] ; #, str
    ;-----------------------------
    mov     rdi, rbx
    inc     rdi
    call_libc malloc
    mov     byte [rax + rbx], NULL
    mov     rbx, rax                        ; store final string
    ;-----------------------------
    mov     rdi, [rsp + 0x10]               ; start from the bottom string
    sub     qword [rts_tos], 0x08           ; point to delim, just above the last string
    mov     r12, rbx                        ; ptr to copy chars
    mov     r8, [rsp]                       ; # of delims (counter)
    dec     r8
    ;-----------------------------
    .copy_all_strings_and_delims:
        cmp     rdi, [rts_tos]              ; continue while we're < delims
        jge     .finished_copying
        ;-----------------------------
        mov     rsi, [rdi]                  ; process this string
        .copy_the_bytes:
            cmp     byte [rsi], NULL
            je      .add_delim_part
            ;-----------------------------
            mov     byte r11b, [rsi]
            mov     byte [r12], r11b
            ;-----------------------------
            inc     rsi
            inc     r12
            jmp     .copy_the_bytes
        ;-----------------------------
        .add_delim_part:
        mov     r9, [rsp + 0x08]            ; start of delim
        ;-----------------------------
        .copy_delim_bytes:
            test    r8, r8                  ; do we still need to add a delim?
            jz      .finished_copying
            ;-----------------------------
            cmp     byte [r9], NULL
            je      .delims_completed
            ;-----------------------------
            mov     byte r11b, [r9]
            mov     byte [r12], r11b
            ;-----------------------------
            inc     r12
            inc     r9
            jmp     .copy_delim_bytes
            ;-----------------------------
        .delims_completed:
        dec     r8                          ; delim counter --
        add     rdi, 0x08                   ; next string +8 bytes
        jmp     .copy_all_strings_and_delims
    ;-----------------------------
    .finished_copying:
    mov     rdi, [rsp + 0x10]
    mov     [rdi], rbx
    mov     [rts_tos], rdi
    jmp     .ended
    ;-----------------------------
    .join_not_needed:
    ; leave it or copy it? gotta decide!!???
    sub     rdi, 0x10
    mov     [rts_tos], rdi
    ;-----------------------------
    .ended:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_206
    jmp     error_need_mult_operands

replace_subst_str:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     rdi, [rts_tos]
    lea     rsi, [rts + 0x10]
    cmp     rdi, rsi
    jl      .prepare_for_error
    ;-----------------------------
    sub     rsp, 0x20
    ;---------------------------------;
    ; [rsp]      --> orig string      ;
    ; [rsp + 8]  --> search           ;
    ; [rsp + 16] --> replace          ;
    ; [rsp + 24] --> orig string len  ;
    ;---------------------------------;
    mov     rsi, [rdi]
    mov     [rsp + 0x10], rsi       ; replace (CAN be empty)
    ;-----------------------------
    sub     rdi, 0x08
    mov     rsi, [rdi]
    mov     [rsp + 0x08], rsi       ; search (CAN'T be empty)
    ;-----------------------------
    sub     rdi, 0x08
    mov     rsi, [rdi]
    mov     [rsp], rsi              ; string
    ;-----------------------------  ; pass on rdi, rax = # chars excl '\0'
    mov     rdi, [rsp + 0x08]       ; search empty?
    call    str_len
    ;-----------------------------
    test    rax, rax
    jz      .empty_search_str
    mov     r12, rax                ; store len of search
    ;-----------------------------
    mov     rdi, [rsp]              ; orig string empty?
    call    str_len
    ;-----------------------------
    test    rax, rax
    jz      .empty_search_str
    ;-----------------------------
    mov     [rsp + 0x18], rax       ; store size
    ;-----------------------------
    mov     rdi, [rsp]
    mov     rsi, [rsp + 0x08]
    ;---------------------------------------------------------
    ; ** IMPORTANT! set FLAG = 0
    ; we're checking # of instances! NOT index of 1st match!
    ;---------------------------------------------------------
    xor     rcx, rcx
    call    number_of_substrings_found
    mov     rbx, rax                ; num of search strings found in main str
    test    rax, rax
    jz      .no_instances_just_dup_top
    ;-----------------------------
    mov     rdi, [rsp + 0x10]
    call    str_len
    mov     r13, rax                ; get length of replace
    ;-----------------------------
    sub     r13, r12                ; calc difference between search & replace strings
    imul    r13, rbx                ; need to calc difference # of instances * (r13 - r12)
    add     r13, [rsp + 0x18]       ; add (+/-difference) to original string
    mov     rdi, r13
    inc     rdi                     ; this is the total len of new str
    call_libc malloc
    mov     byte [rax + r13], NULL  ; null byte
    mov     rbx, rax                ; store new str heap alloc
    ;-----------------------------
    mov     rdi, [rsp]              ; orig
    mov     rsi, [rsp + 0x08]       ; search
    mov     rdx, [rsp + 0x10]       ; replace
    call    build_replace_string
    ;-----------------------------
    mov     r15, rbx
    jmp     .push_on_stack
    ;-----------------------------
    .no_instances_just_dup_top:
    mov     rdi, [rsp + 0x18]
    inc     rdi                     ; for the null byte
    call_libc malloc
    ;-----------------------------
    mov     r15, rax
    mov     rdx, [rsp + 0x18]
    mov     byte [rax + rdx], NULL  ; add term '\0'
    mov     rdi, rax
    mov     rsi, [rsp]
    call    copy_bytes
    ;-----------------------------
    .push_on_stack:
    mov     rdi, [rts_tos]
    sub     rdi, 0x10
    mov     [rdi], r15
    mov     [rts_tos], rdi
    jmp     .finished
    ;-----------------------------  ; if error then leave top of stack alone
    .empty_search_str:
    printLine       replace_subst_str_err, [rsp], [rsp + 0x08], [rsp + 0x10]
    ;-----------------------------
    .finished:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x03
    mov     rsi, operator_205
    jmp     error_need_mult_operands

build_replace_string:   ; rdi = orig str, rsi = search, rdx = replace, rbx = final str
    ;-----------------------------
    mov     r11, rbx
    ;-----------------------------
    .scan_main:
        cmp     byte [rdi], NULL
        je      .ended
        ;-----------------------------
        mov     r8, rdi     ; rdi waits here
        mov     r9, rsi
        ;-----------------------------
        .find_sub:
            cmp     byte [r9], NULL
            je      .got_match
            ;-----------------------------
            mov     byte r10b, [r9]
            cmp     byte [r8], r10b
            jne     .next_char
            ;-----------------------------
            inc     r9
            inc     r8
            jmp     .find_sub
        ;-----------------------------
        .got_match:
        mov     r9, rdx
        ;-----------------------------
        .insert_replace_str:
            cmp     byte [r9], NULL
            je      .update_main_str_ptr
            ;-----------------------------
            mov     byte r10b, [r9]
            mov     byte [r11], r10b
            ;-----------------------------
            inc     r11
            inc     r9
            jmp     .insert_replace_str
            ;-----------------------------
        .update_main_str_ptr:
        mov     rdi, r8     ; rdi resumes from here
        jmp     .scan_main
        ;-----------------------------
        .next_char:
        mov     byte cl, [rdi]
        mov     byte [r11], cl
        inc     rdi
        inc     r11
        jmp     .scan_main
    ;-----------------------------
    .ended:
    ret

find_str_index:                     ; rbx = index of first match, or -1 for no match
    ;-----------------------------
    mov     rdx, [rts_tos]
    cmp     rdx, rts
    jle     .prepare_for_error
    mov     rsi, [rdx]
    ;-----------------------------
    mov     rdi, [rdx - 0x08]
    xor     rcx, rcx
    or      rcx, 0x01               ; IMPORTANT! set to 0x01 for correct result
    call    number_of_substrings_found
    ;-----------------------------
    mov     rdi, [rts_tos]
    sub     rdi, 0x08
    ;-----------------------------
    mov     [rdi], rbx              ; result from func
    mov     [rts_tos], rdi
    xor     ebx, ebx
    ;-----------------------------
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_210
    jmp     error_need_mult_operands


number_of_substrings_found:
    ;-------------------------------------------
    ; rdi = main str
    ; rsi = sub str looking for
    ; rax = # of instances
    ; rbx = index 1st match if rcx = 1
    ;
    ; ** IMPORTANT ** if using find str index,
    ; set rcx = 1, otherwise set rcx = 0 **                    ;
    ;-------------------------------------------
    xor     rax, rax            ; total matches
    xor     rbx, rbx            ; grab
    ;-----------------------------
    .scan_main:
        cmp     byte [rdi], NULL
        je      .final_check
        ;-----------------------------
        mov     r8, rdi
        mov     r9, rsi
        ;-----------------------------
        .find_sub:
            cmp     byte [r9], NULL
            je      .inc_matches
            ;-----------------------------
            mov     byte r10b, [r9]
            cmp     byte [r8], r10b
            jne     .next_char
            ;-----------------------------
            inc     r9
            inc     r8
            jmp     .find_sub
        ;-----------------------------
        .inc_matches:
        test    rcx, rcx
        jnz     .ended                  ; we got a match, now return this rbx index
        ;-----------------------------
        inc     rax                     ; total++
        mov     rdi, r8                 ; start after whole match
        jmp     .scan_main
        ;-----------------------------
        .next_char:
        inc     rbx
        inc     rdi
        jmp     .scan_main
    ;-----------------------------
    .final_check:
    test    rcx, rcx
    jz      .ended
    mov     rbx, -1
    ;-----------------------------  ; end of string means we didnt find a match, set rbx -1
    .ended:
    ret


get_all_lines:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    ;-----------------------------
    mov     r13, [rdi]              ; r12 = delim list
    mov     r12, newLine            ; newline delim 0x0a00
    call    split_string_into_tokens
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_191
    jmp     error_need_1_operand

split_string_delims:                ; this version uses 1) the user str 2) the user delim str
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jle     .prepare_for_error
    ;-----------------------------
    mov     r12, [rdi]              ; r12 = delim list
    mov     r13, [rdi - 0x08]       ; r13 = main string
    call    split_string_into_tokens
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_190
    jmp     error_need_mult_operands


split_string_into_tokens:           ; this version uses 1) the user str 2) the user delim str,
    push    rbp                     ; r12 = delim list, r13 = main str
    mov     rbp, rsp
    ;-----------------------------
    sub     rsp, 0x10
    mov     qword [rsp], NULL               ; # of tokens we're building
    mov     qword [rsp + 0x08], NULL        ; temp linked list head
    ;-----------------------------
    mov     r8, r13
    mov     r9, r12
    call    ignore_user_delim
    ;-----------------------------
    mov     r13, r8                 ; r13 = *start_ptr
    mov     r14, r13                ; r14 = *end_ptr
    ;----------------------------
    cmp     byte [r13], NULL    ; did we get to EOS '\0' ??
    je      .no_data_in_string
    ;----------------------------
    .looping:
        cmp     byte [r13], NULL    ; reached end of string NULL?
        je      .make_array_from_list
        ;----------------------------
        .grabbing_chars:                ; scan fwd until token ends
        mov     r8, r14
        mov     r9, r12
        call    halt_on_user_delim_and_quotes
        ;----------------------------
        .saving_tokens:                 ; malloc & store in list
        mov     r14, r8
        mov     rdi, r14
        sub     rdi, r13
        mov     r15, rdi                ; hold size
        inc     rdi
        ;----------------------------
        call_libc malloc
        mov     byte [rax + r15], NULL
        mov     r11, r15
        mov     r15, rax                ; now grab heap
        ;----------------------------
        mov     rdi, rax
        mov     rsi, r13
        mov     rdx, r11
        call    copy_bytes
        ;----------------------------
        mov     rdi, 0x10                   ; set up linked list
        call_libc malloc
        mov     qword [rax + 0x08], NULL    ; node.next = null
        mov     [rax], r15
        ;----------------------------
        cmp     qword [rsp + 0x08], NULL
        jne     .goes_into_list
        ;----------------------------
        mov     [rsp + 0x08], rax
        jmp     .skipping_delim_list
        ;----------------------------
        .goes_into_list:
        mov     rdi, [rsp + 0x08]
        .find_slot_to_add:
            cmp     qword [rdi + 0x08], NULL
            je      .add_in_free_slot
            ;----------------------------
            mov     rdi, [rdi + 0x08]
            jmp     .find_slot_to_add
        ;----------------------------
        .add_in_free_slot:
        mov     [rdi + 0x08], rax
        ;----------------------------
        .skipping_delim_list:           ; scan past anything matching delim list
        mov     r8, r14
        mov     r9, r12
        call    ignore_user_delim
        ;----------------------------
        mov     r14, r8
        mov     r13, r8                 ; move *start_ptr & *end_ptr
        inc     qword [rsp]             ; # of nodes created
        jmp     .looping
    ;----------------------------
    .no_data_in_string:
    mov     rdi, [rts_tos]
    mov     qword [rdi + 0x08], NULL
    add     qword [rts_tos], 0x08
    jmp     .ended
    ;----------------------------
    .make_array_from_list:
    mov     r12, [rsp + 0x08]
    ;----------------------------       ; DEBUGGING
    ; .check_list:
    ;   test    r12, r12
    ;   jz      .build_main_block
    ;   printLine   stringOut, [r12]
    ;   printLine   intOut, [rsp]
    ;   mov     r12, [r12 + 0x08]
    ;   jmp     .check_list
    ;----------------------------
    .build_main_block:
    mov     rdi, [rsp]
    inc     rdi                         ; empty qword slot at the end
    shl     rdi, 0x03
    call_libc malloc
    ;----------------------------
    mov     r15, rax                    ; save heap to *strings, we copy from linked_list to this array!
    xor     r12, r12
    ;mov        rdi, [temp_linked_list] ; get the saved linked list
    mov     rdi, [rsp + 0x08]
    ;----------------------------
    .transfer_nodes:
        cmp     r12, [rsp]
        je      .clear_linked_list
        ;----------------------------
        mov     r8, [rdi]
        mov     [rax + r12 * 0x08], r8
        mov     rdi, [rdi + 0x08]
        ;----------------------------
        inc     r12
        jmp     .transfer_nodes
    ;----------------------------
    .clear_linked_list:
    mov     qword [rax + r12 * 0x08], NULL  ; last entry
    ;mov        r12, [temp_linked_list]
    mov     r12, [rsp + 0x08]
    mov     r13, [r12 + 0x08]
    ;----------------------------
    .delete_link:
        ;----------------------------
        mov     rdi, r12
        call_libc free
        ;----------------------------
        mov     r12, r13
        ;----------------------------
        test    r12, r12
        jz      .add_strings_to_stack
        mov     r13, [r12 + 0x08]
        jmp     .delete_link
    ;----------------------------
    .add_strings_to_stack:
    ;mov        qword [temp_linked_list], NULL  ; clean up for next time
    ;----------------------------
    .final_block:           ; 1st 8 bytes = # of tokens we have. 2nd 8 bytes = ptr to block of strings
    mov     rdi, 0x10
    call_libc malloc
    ;----------------------------
    mov     rsi, [rsp]
    mov     [rax + 0x08], rsi
    mov     [rax], r15  ; save main string block here
    ;----------------------------
    mov     rdi, [rts_tos]
    lea     rsi, [rdi + 0x08]
    mov     [rsi], rax          ; save results
    mov     [rts_tos], rsi
    ;----------------------------
    .ended:
    leave
    ret


split_string:
    push    rbp
    mov     rbp, rsp
    ;-----------------------------
    cmp     qword [rts_tos], rts
    jl      .prepare_for_error
    ;-----------------------------
    sub     rsp, 0x20                   ; need 32 bytes
    ;-----------------------------
    ; rbp - 0x08 --> FLAG for reaching end of speech mark
    ; rbp - 0x10 --> size of string we copy
    ; rbp - 0x18 --> start of string (FIXED pos)
    ; rbp - 0x20 --> end of string (SCANNER pos)
    ;-----------------------------
    xor     r8, r8
    mov     [rbp - 0x08], r8    ; by default zer0
    ;-----------------------------
    mov     r8, [rts_tos]
    mov     r8, [r8]
    mov     [rbp - 0x18], r8    ; start of the string
    sub     qword [rts_tos], 0x08
    ;-----------------------------
    mov     rsi, [rbp - 0x18]       ; fixed
    call    find_next_non_delimRSI
    ;-----------------------------
    mov     [rbp - 0x18], rsi       ; fixed
    mov     [rbp - 0x20], rsi       ; scanner
    ;-----------------------------
    .looping:
        mov     r8, [rbp - 0x18]
        cmp     byte [r8], NULL
        je      .ended
        ;-----------------------------
        mov     rdi, [rbp - 0x20]   ; r15
        call    is_delim                    ; rax is 0 = not delim, 1 = delim
        ;-----------------------------
        test    rax, rax
        jz      .notADelim
        ;-----------------------------
        .foundAWord:                        ; we hit a delim, so grab the word (r14 --> r15) and malloc etc
        mov     r8, [rbp - 0x18]
        cmp     byte [r8], speechQuote      ; byte [rbp - 3 * 0x08], speechQuote
        jne     .buildStandardWord
        ;-----------------------------
        inc     qword [rbp - 0x18]
        dec     qword [rbp - 0x20]
        ;-----------------------------
        .buildStandardWord:
        mov     rdi, [rbp - 0x20]
        mov     [rbp - 0x10], rdi           ; ptr on delim
        ;-----------------------------
        mov     rdi, [rbp - 0x18]
        sub     qword [rbp - 0x10], rdi     ; ptr on start char of word
        ;-----------------------------
        inc     qword [rbp - 0x10]          ; for the nullbyte EOS '\0'
        mov     rdi, [rbp - 0x10]
        call_libc malloc
        ;-----------------------------
        sub     qword [rbp - 0x10], 0x01    ; copy -1 less byte
        ;-----------------------------
        mov     rdi, rax
        call    push_on
        ;-----------------------------
        ; pass on rdi dest, rsi source, rdx = #bytes to copy from source --> dest
        ;-----------------------------
        mov     rdi, rax
        mov     rsi, [rbp - 0x18]
        mov     rdx, [rbp - 0x10]
        call    copy_bytes                  ; rax is ok no lib/sys call here
        ;-----------------------------
        add     rax, [rbp - 0x10]           ; add term '\0'
        mov     byte [rax], NULL
        ;------------------------------
        cmp     qword [rbp - 0x08], 0x01
        jne     .notSpeechMark
        mov     qword [rbp - 0x08], NULL    ; re-set FLAG
        inc     qword [rbp - 0x20]          ; need to go past the '"'
        ;------------------------------
        .notSpeechMark:
        mov     rsi, [rbp - 0x20]
        call    find_next_non_delimRSI
        ;-----------------------------
        mov     [rbp - 0x18], rsi
        mov     [rbp - 0x20], rsi
        .notADelim:
        ;-----------------------            ; if r14 is on a speech mark here, inc it's position.
        mov     r8, [rbp - 0x18]
        cmp     byte [r8], speechQuote      ; byte [rbp - 3 * 0x08], speechQuote
        jne     .nextStep
        ;-----------------------------
        mov     qword [rbp - 0x08], 0x01    ; we have a speech quote match, set FLAG to TRUE
        mov     rsi, [rbp - 0x20]
        call    quote_to_quoteRSI           ; rax = 1 if speech mark found, 0 if no end speech mark (ERROR)
        mov     [rbp - 0x20], rsi
        ;-----------------------------
        test    rdx, rdx
        jz      .errorNoEndSpeechFound
        ;-----------------------------
        .nextStep:
        inc     qword [rbp - 0x20]
        jmp     .looping
    ;-----------------------------
    .errorNoEndSpeechFound:
    printLine   missingSpeech
    leave
    jmp     exit
    ;-----------------------------
    .ended:
    xor     ebx, ebx
    leave
    ret
    .prepare_for_error:
    mov     rsi, operator_59
    jmp     error_need_1_operand

get_bp_0:
    ;-----------------------
    mov     rsi, [base_ptr_0]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

get_bp_1:
    ;-----------------------
    mov     rsi, [base_ptr_1]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret


get_bp_2:
    ;-----------------------
    mov     rsi, [base_ptr_2]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret


get_bp_3:
    ;-----------------------
    mov     rsi, [base_ptr_3]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

get_bp_4:
    ;-----------------------
    mov     rsi, [base_ptr_4]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

get_bp_5:
    ;-----------------------
    mov     rsi, [base_ptr_5]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

get_bp_6:
    ;-----------------------
    mov     rsi, [base_ptr_6]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

get_bp_7:
    ;-----------------------
    mov     rsi, [base_ptr_7]
    test    rsi, rsi
    jz      error_stack_pts_not_set
    ;-----------------------
    mov     rcx, [rts_tos]
    mov     rax, [rsi]
    ;-----------------------
    add     rcx, 0x08
    mov     [rts_tos], rcx
    mov     [rcx], rax
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_6:
    ;-----------------------
    mov     rsi, [base_ptr_6]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

set_bp_7:
    ;-----------------------
    mov     rsi, [base_ptr_7]
    mov     rdi, [rts_tos]
    mov     rax, [rdi]
    ;-----------------------
    sub     rdi, 0x08
    mov     [rsi], rax
    mov     [rts_tos], rdi
    ;-----------------------
    xor     ebx, ebx
    ret

get_char_from_ptr_signed:                       ; grab the char from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    movsx   rdi, byte [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

get_word_from_ptr_signed:                       ; grab the word from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    movsx   rdi, word [r9]
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

get_dword_from_ptr_signed:                      ; grab the dword from the heap on top of the stack
    ;---------------------------------
    mov     r8, [rts_tos]
    mov     r9, [r8]
    ;---------------------------------
    movsxd  rdi, dword [r9]                     ; movsx kept failing.. figured it out.....
    mov     [r8], rdi
    ;---------------------------------
    xor     ebx, ebx
    ret

null_out_stack_ptrs:                            ; ONLY CALL THIS FROM A FUNC, NOT DIRECTLY FROM THE PROG!
    ;-----------------------
    xor     rax, rax
    xor     r8, r8
    xor     r9, r9
    xor     r10, r10
    xor     r11, r11
    xor     r12, r12
    xor     r13, r13
    xor     r14, r14
    ;-----------------------
    mov     [base_ptr_0], rax
    mov     [base_ptr_1], r8
    mov     [base_ptr_2], r9
    mov     [base_ptr_3], r10
    mov     [base_ptr_4], r11
    mov     [base_ptr_5], r12
    mov     [base_ptr_6], r13
    mov     [base_ptr_7], r14
    ;-----------------------
    ret

del_base_ptr_clear:
    ;-----------------------
    mov     rcx, base_ptr_tos
    cmp     qword [rcx], base_ptr
    ;-----------------------
    jl      .ended                  ; if empty can't pop off!
    je      .reset_ptrs             ; if last record, reset ptrs and pop off
    ;-----------------------
    sub     qword [rcx], 0x08
    mov     r11, [rcx]
    mov     r10, [r11]
    mov     [rts_tos], r10
    ;-----------------------
    call    flash_stack_ptrs
    .ended:
    ;-----------------------
    xor     ebx, ebx
    ret
    ;-----------------------
    .reset_ptrs:
    mov     r11, [rcx]
    mov     r10, [r11]
    mov     [rts_tos], r10
    sub     qword [rcx], 0x08
    call    null_out_stack_ptrs
    xor     ebx, ebx
    ret


rand_string_batch:
    ;-----------------------
    cmp     qword [rts_tos], rts
    jle      .prepare_for_error
    mov     r12, [rts_tos]
    mov     r13, [r12]              ; count
    ;-----------------------
    mov     r14, [r12 - 0x08]       ; length (8 bytes below TOS)
    ;-----------------------
    mov     r9, 0x08
    cmp     r13, 0x01               ; is count < 1? default to 8
    cmovl   r13, r9
    cmp     r14, 0x01               ; is length < 1? default to 8
    cmovl   r14, r9
    ;-----------------------
    mov     rax, r14
    inc     rax                     ; length + 1 (null term '\0')
    imul    rax, r13                ; total size = count * (length + 1)
    ;-----------------------
    mov     rdi, rax
    call_libc malloc                ; Allocate for entire block
    mov     r15, rax                ;
    ;-----------------------
    mov     rbx, [lcg_state]        ; load lcg_state
    mov     r10, 0x5851F42D4C957F2D
    mov     r11, 0x14057B7EF767814F
    ;-----------------------
    ; r15 = heap array
    ; r13 = counter (remaining str)
    ; r14 = len per str
    ;-----------------------
    xor     rdi, rdi                ; counter
    .string_loop:
    ;-----------------------
        cmp     rdi, r13
        je      .done_strings
        ;-----------------------
        xor     rsi, rsi            ; str len counter
        .char_loop:
            cmp     rsi, r14
            je      .add_term
            ;----------------------- update lgc
            imul    rbx, r10
            add     rbx, r11
            ;----------------------- generate rand char [a..z], using shift/mul/shift trick.
            mov     r8, rbx
            shr     r8, 0x20        ; 1) Keep upper 32 bits
            imul    r8, 0x1a        ; 2) * 26 = 26 * (2^32)
            shr     r8, 0x20        ; 3) leaves us (0..25)
            add     r8b, 0x61       ; 4) +97 = set range [a..z]
            ;-----------------------
            mov     byte [r15], r8b
            inc     r15
            inc     rsi
            jmp    .char_loop
        ;-----------------------
        .add_term:
        mov     byte [r15], NULL
        inc     r15
        inc     rdi
        jmp     .string_loop
    ;-----------------------
    .done_strings:
    ;---------------------------------- updated LCG state
    mov     [lcg_state], rbx
    sub     r12, 0x08               ; pop off befre we place heap
    mov     [rts_tos], r12
    mov     [r12], rax              ; Replace count with block pointer
    ;----------------------------------
    xor     ebx, ebx
    ret

    .prepare_for_error:
    mov     rdx, 0x02
    mov     rsi, operator_265
    jmp     error_need_mult_operands

regex_error_handler:
    ;-------------------------------------------------------------------------------------------------------
    ; regex, regex_sub & regex_mult have their stack: [string, regex] regex_sub had extra replace string
    ; but this was saved & popped off at the start of the function.
    ; because the regex failed due to an error, we replace string with regex, replace regex with err message
    ; & then push on -1, so the stack looks like this: [regex, err_message, -1]
    ;-------------------------------------------------------------------------------------------------------
    xor     rax, rax
    mov     rdi, [err_code]             ; err code integer
    lea     rsi, [err_buffer]           ; buffer to grab err msg
    mov     rdx, 0xff                   ; max size = 255 bytes
    call_libc    pcre2_get_error_message_8
    ;-----------------------
    mov     rdi, [rts_tos]
    ;-----------------------
    lea     rcx, [rdi - 0x08]
    mov     r8, [rdi]
    mov     [rcx], r8                   ; overwrite string with regex, as we need this after err msg
    ;-----------------------
    mov     rsi, err_buffer             ; now push on err msg in place of regex
    mov     [rdi], rsi
    ;-----------------------
    add     rcx, 0x10                   ; position above rdi
    mov     qword [rcx], -1             ; Push on -1 err code
    mov     [rts_tos], rcx              ; fix top of stack
    ret

dump_curly_braces:          ; pass on rdi token array
    push    rbp
    mov     rbp, rsp
    ;-----------------------
    test    rdi, rdi
    jz      .finished
    ;-----------------------
    mov     r12, [curly_brace_table]
    xor     r13, r13
    printLine   dumpCurlyBracesTitle
    ;-----------------------
    .displayBracePairs:
        cmp     r13, [argv_len]
        jge     .finished
        ;-----------------------
        mov     r8, [r12 + r13 * 0x08]  ; non-zero = '}'
        test    r8, r8
        jz      .next_iteration
        ;-----------------------
        mov     r9, r8
        shr     r9, 0x20                ; if_else if we have one?
        ;-----------------------
        shl     r8, 0x20                ; just the '}'
        shr     r8, 0x20
        ;-----------------------
        test    r9, r9
        jnz     .else_included
        printLine   dispayMatchedBrace, r13, r8
        jmp     .next_iteration
        ;-----------------------
        .else_included:
        printLine   dispayMatchedBraceElse, r13, r8, r9
        ;-----------------------
        .next_iteration:
        inc     r13
        jmp     .displayBracePairs

    .finished:
    ;-----------------------
    leave
    ret

create_and_init_curly_braces:   ; modified version
    push    rbp
    mov     rbp, rsp
    ;-----------------------    first make the array for ending braces '}' use [argv_len]
    mov     rdi, [argv_len]
    inc     rdi
    shl     rdi, 0x03
    call_libc malloc
    mov     [curly_brace_table], rax
    ;-----------------------    null out the entire heap
    mov     rdi, rax
    mov     rdx, [argv_len]
    call    null_out_heap
    mov     rax, [curly_brace_table]    ; grab heap address
    ;-----------------------
    .start_mapping:
    xor     r13, r13            ; go through ALL tokens & find every single '{'
    mov     r14, [argv_len]
    mov     rcx, [token_type]
    ;-----------------------
    .create_brace_mappings:
        cmp     r13, r14
        je      .finished
        ;-----------------------
        cmp     word [rcx + r13 * 0x02], open_brace_KEYWORD     ; operator_26 is a '{'
        jne     .next_token
        ;-----------------------      we have a '{' now get its matching '}'
        lea     r12, [r13 + 0x01]   ; move 1 token ahead        ; check edge case last entry
        mov     rsi, 0x01           ; push/pop tracker. find '{' --> +1, find '}' --> -1, when rsi = 0 match found.
        ;-----------------------
        .match_brace:
            cmp     r12, r14        ; jg = error!
            jge     .error_braces_not_matched
            ;-----------------------
            cmp     rsi, 0x01
            jne     .check_opening
            ;-----------------------
            cmp     word [rcx + r12 * 0x02], if_else_brace_KEYWORD  ; found an if_else '}{' brace pair?
            jnz     .check_opening
            ;-----------------------    the if_else is part of THIS if index.
            mov     dword [rax + r13 * 0x08 + 0x04], r12d
            jmp     .next_iteration
            ;-----------------------
            .check_opening:
            cmp     word [rcx + r12 * 0x02], open_brace_KEYWORD ; found a closed brace?
            jnz     .check_closing
            ;-----------------------
            inc     rsi
            jmp     .next_iteration
            ;-----------------------
            .check_closing:
            cmp     word [rcx + r12 * 0x02], close_brace_KEYWORD    ; found a closed brace?
            jnz     .next_iteration
            ;-----------------------
            dec     rsi
            test    rsi, rsi        ; if push/pop tracker = 0 --> we got matching '}' so insert 1st 4 bytes with index
            jnz     .next_iteration
            ;-----------------------
            mov     dword [rax + r13 * 0x08], r12d  ;upper 32 bits might contain if_else index. so use 'or' to keep them
            jmp     .next_token
            ;-----------------------
            .next_iteration:
            inc     r12
            jmp     .match_brace
        ;----------------------
        .next_token:
        inc     r13
        jmp     .create_brace_mappings
    ;-----------------------
    .finished:
    leave
    ret
    .error_braces_not_matched:              ; should never get here!!!
    printLine   strFMT, [heap_alloc_file]
    printLine   error_brace_not_located, r13
    call    dealloc_operator_hashset
    call    deallocate_mem_tidy_up
    jmp     exit

file_byte_size:           ; expects file_desc on rdi, rax returns # of bytes!
    ;------------------------------
    xor     rsi, rsi
    mov     rax, SYS_LSEEK
    mov     rdx, SEEK_END
    syscall
    ;------------------------------
    ret

ret_func_name:
    ;------------------------------
    call    get_current_func_name
    ;------------------------------
    mov     rsi, [rts_tos]
    add     rsi, 0x08
    mov     [rsi], r8               ; push func name string on stack
    mov     [rts_tos], rsi
    xor     ebx, ebx
    ;------------------------------
    ret

exit_func:
    mov     rdi, [rts_tos]
    cmp     rdi, rts
    jl      .prepare_for_error
    mov     rsi, [rdi]
    mov     [exit_status], rsi
    ;------------------------------
    call    deallocate_mem_tidy_up  ; now go to exit: func below
    jmp     exit
    .prepare_for_error:
    mov     rsi, operator_175
    jmp     error_need_1_operand

exit:
    leave                           ; restore stack from main func
    mov     rax, SYS_EXIT           ; SYS_EXIT = 60
    mov     rdi, [exit_status]      ; 0 by default, user can set this with 'exit' operator
    syscall
