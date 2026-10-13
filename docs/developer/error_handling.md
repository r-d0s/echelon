# ERROR HANDLING AND CODE ISSUES

echelon was designed to be basic & minimal. that means there's `no garbage collector`, `no runtime type checking` and `very little error handling`. this is intentional, because it was a learning project that was never meant to be released. when something didn't work, crashed or seg-faulted it really didn't matter to me, because I had no choice but to fix it & then carry on...

---

## What happens when something does go wrong?

if you make a mistake with an operator..... echelon will `not try to recover anything` for you. it will exit & it's up to you to figure out why. you can allocate memory & R/W anything you want to it, there are `no safety checks` for `types`. it's up to you to know what works & what doesn't.

only recently I added `basic stack checks` to prevent operators from running without enough operands. e.g the `+` operator requires two operands, if you call it with one or zero, it will fail.

when an error is detected, here's what happens:

1) **Stops execution**, the source code halts immediately.
2) **Deallocates program memory**, functions, variables & structs are cleaned up.
3) **Displays the operator & function**: the name of the failing operator & the function it was called from are printed.

**Important:** any memory the user allocated before the failure will `not be deallocated`. there is `no garbage collector`. if you allocate heap memory & then an error occurs before you free it, that `memory will leak`. you always handle the clean-up yourself.

---

## Programs can crash easily!

because echelon lets you access memory directly, it's easy to shoot yourself in the foot. here are a few common mistakes that will crash the program:

```
512 int puts ; seg-fault! expects a null-term string at this address

255 int [peek_32] ; seg-fault! attempt to dereference 4 bytes at address 0xff

{ ...code... } counter peek 100 < loop ; 100 is a *ptr to a string! this is nowhere near the value 0x64!
                                       ; the loop will probably crash. don't forget to use 'int' or 'float'.
```

echelon expects you to know what you're doing. if you give it an invalid address, it will try to read or write to it & the OS will end up killing the program!

---

## Writing and Updating Code at Runtime

the program code strings are stored in the heap. that means it's possible for you to modify them, even if they were originally expected to be treated as 'string literals'

here's an example:

```
func: leave_msg
    "hi!! from leave_msg func..." ; leaves a string on top of the stack
    return

_start:
    leave_msg call_func ; call the function, it leaves a string
    puts_p              ; display & pop

    leave_msg call_func ; call again.. this time, DON'T pop!

    "BYE!" [peek_32]    ; dereference string "BYE!" & place 4 bytes on stack
                        ; stack now looks like: [ *str, BYE! ]
    [poke_32]           ; write 4 bytes "BYE!" into leave_msg's string

    leave_msg call_func
    puts_p              ; message has changed

    leave_msg call_func
    puts_p
```


running this produces this output:

    hi!! from leave_msg func...
    BYE! from leave_msg func...
    BYE! from leave_msg func...

`[poke_32]` overwrites the first 4 bytes. The null-term (5th byte) isn't written because `[poke_32]` only writes 4 bytes, so puts keeps reading into the original string's remaining bytes."

---

## Creating Random Variables

echelon doesn't require you to declare variables before they are used. this was actually something I discovered by accident while testing.

example:

```
_start:
    dump_dict                              ; show initial variables

    0 int count def_i
    {
        100 int rand 10 int rand_str def_i ; random int + random string --> def_i
        1 int count +=
    } count peek 5 int < loop

    dump_dict                              ; display all variables
```


the `def_i` operator consumes the top two values from the stack, in this case, a random integer & a random string. the string becomes the variable name & the integer becomes its value.

running this code produces this output:

    ------------- [START] of dictionary dump -----------v
    [00] ---> name : [argv] | &address : [0x165a6b70] | # of elements : [3] | type : [struct *ptr]
    [01] ---> name : [argc] | value : [3] | type : [int]
    ^------------ [END] of dictionary dump ------------

    ------------- [START] of dictionary dump -----------v
    [00] ---> name : [cmllqodvde] | value : [17] | type : [int]
    [01] ---> name : [uvbvzuubtg] | value : [62] | type : [int]
    [02] ---> name : [axviayqano] | value : [13] | type : [int]
    [03] ---> name : [jmpfclcqgz] | value : [71] | type : [int]
    [04] ---> name : [qqwkkkjixn] | value : [15] | type : [int]
    [05] ---> name : [count] | value : [5] | type : [int]
    [06] ---> name : [argv] | &address : [0x165a6b70] | # of elements : [3] | type : [struct *ptr]
    [07] ---> name : [argc] | value : [3] | type : [int]
    ^------------ [END] of dictionary dump ------------

this is a risky 'feature' (bug?!?), variables are created 'on the fly' with names generated at runtime.

