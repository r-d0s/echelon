# Token Marking Limitations

---

when the program is running and a function is called, the name of the function is looked up and the token ID (its `index` in the array) is returned. the program then continues processing from the token ID that has just `been returned`. for example, take a look at this code:

```
func: foo
    hello
    return

_start:
    foo call_func
    puts
```

---

the **code array** contains these strings tokens & is set up like this:

    [0] --> "func:"
    [1] --> "foo"
    [2] --> "hello"
    [3] --> "return"
    [4] --> "_start:"
    [5] --> "foo"
    [6] --> "call_func"
    [7] --> "puts"
    [8] --> NULL

it's possible to remove the function name look-up completely. before the program starts, we can **replace** the function name with its `index` in the **code array**, allowing immediate access. i managed to get this working. here's how it would change when a `call_func` token is seen, the **previous** token is replaced with its `index` in the **code array**:

    [0] --> "func:"
    [1] --> "foo"       <---- when call_func runs, send it HERE (index 0x01)
    [2] --> "hello"
    [3] --> "return"
    [4] --> "_start:"
    [5] --> 0x01        <---- "foo" string REPLACED with its array index (0x01)
    [6] --> "call_func"
    [7] --> "puts"
    [8] --> NULL

---

the catch is that this only works when the `call target` is known `statically`. the moment a function name is `chosen at runtime`, e.g pulled off the stack, then there's nothing to mark ahead of time, because the name doesn't exist until execution reaches that point..

the following example shows where this approach totally breaks down:

```
func: welcome
    "hello there!" puts_p
    return

func: goodbye
    "take care, see you later!" puts_p
    return

func: run_some_functions
    call_func   ; <-- expands to 'welcome call_func' (welcome is on top of the stack)
    call_func   ; <-- expands to 'goodbye call_func' (welcome was popped, goodbye is now on top)
    return

_start:
    goodbye     ; pushed first
    welcome     ; pushed second
    run_some_functions call_func
```

looking at function `run_some_functions`, it takes 2 values from the stack and runs `call_func` on them. how can we decide where to replace `welcome` and `goodbye` with their array index values without running the code and figuring everything out beforehand? I had thought about scanning the code and marking every instance of a function name with its index. this 'might' work in 'some' cases, but printing a string with the same name as a function, would fail:

```
welcome puts    ; both strings replaced with function index = seg-fault.
goodbye puts
```


another example where token **marking** becomes more complex, creating an int variable `x_pos` with a value of 200.

```
200 int x_pos def_i

500 int 200 int 100 int rev pop swap pop x_pos def_i
```

these two lines of code are `identical` & the stack ends up clean in both cases. by looking at the first line, how could we know that it's identical to the second line without running the operators in order?

the only way to make this work reliably would be to remove some operators from the language e.g `pop`, `swap`, `shift_up` and many others, although this would make stack manipulation far more difficult!

I believe the trade-off is unavoidable... either you have some sort of 'capable' stack-based language.. or you have an optimised 'marked' system where every operand is known before we run the program.


### Optimising Variable Look-ups

currently when we're accessing a variable, we use a linear search to find it in a dictionary, this is carried out by several `strcmp` operations. this is quite slow and effects the performance. I've previously considered using a new hashset for each function, setting it up & pushing variables inside it for faster access.

there are arguments both for & against this choice. there would be faster look-ups in functions with many variables, but functions with a few would probably perform the same. there's also additional work in setting up and clearing the hashsets after each function call.

when does it become worth adding a temporary hashset per function call? some functions have a few variables, others have none & some could have a dozen or more. adding a hashset for every function might be wasteful.

one approach would be to add a temporary hashset per function and fire it off **only** when we come across a `def_i`, `def_f`, `def_str` or `def_struct`. then measure whether the performance gains are worth the implementation. another solution would be to scan the code after the tokeniser has finished (before we actually run the code) and search for `def_i/f/str/struct` inside all functions. then 'mark' these functions (that declare variables) and have the hashset ready just before we call the function at runtime.

### Alternative approach, use the Stack-Frame Storage

ideally I'd much prefer to use the actual Stack-Frame of the echelon.asm code to make space & store variables directly (as most languages do), using this example:

```
100 int foo def_i
-1  int bar def_i
```

make space & store **only** their values in the stack-frame like this, assuming r8 (100) & r9 (-1) already grabbed the values off the stack:

```
sub     rsp, 0x10
mov     [rsp], r8           ; <--- foo's value (r8, 100) pushed onto stack-frame
mov     [rsp + 0x08], r9    ; <--- bar's value (r9, -1) pushed onto stack-frame
```

when accessing the variables:

```
foo peek bar peek +
```

the actual token code is **changed** now, the var name is replaced with an int: `rsp + offset`

```
0x00 peek 0x08 peek +   ; foo's value saved in [rsp + 0x00], bar's values saved in [rsp + 0x08]
```

the variable name `foo` is **mapped** to the ASM code `[rsp + 0x00]`.

the same for variable `bar`, it's **mapped** to `[rsp + 0x08]` & the next variable declared would be mapped to `[rsp + 0x10]`.

whenever the program would see `peek` it would automatically carry out `[rsp + offset]` and push that onto the stack.

in reality, each variable in echelon stores:
- an 8 byte name pointer
- an 8 byte value
-  a 1 byte var type

so the actual stack space required would be slightly larger (by 1 byte, name pointer isn't really needed), the examples above are simplified just to show the logic.

global variables would need to be stored elsewhere, as the stack-frame offsets for their values would only work while the program is running in the main (_start:) function. the same way they're declared in `.data`, `.rodata` or `.bss` in other languages, means we need to store these globals on the heap and have offsets mapped to their indexes. another option would be to make space for approx 100 qwords in `.bss` (avoiding the heap) just for global variables?

overall I thought this approach was the best.. it's fast, simple & tidy!

unfortunately... this is **not** possible with the language right now. the problem is the same one described in the token marking section. if the variable's value or position isn't known until runtime, then there's nothing to resolve ahead of time.

I implemented stack-pointers `[bp_0->bp_7]` which are faster than variables, but are more difficult to keep track of. sometimes you can easily forget their values & you always need to map each one to something meaningful (e.g a diagram in the code). in some tests they performed almost 3x faster than regular variables.
