# From a typo to an interpreter..

this project started with a typo. On Fedora, I meant to type `cd` to send me to '~', but I accidentally typed `dc` instead. I was dropped into its window & I had no clue what it was. I looked up `dc` it's desktop calculator using **RPN**, Reverse Polish Notation. I used it a few times & thought to myself, "why don't I write my own?".

so I began writing the code, just like `dc`, using tokens, operands & the main 4 maths operators: `+`, `-`, `*`, `/`.

`9 int 3 int + print_i` --> 12.

it worked & I was genuinely thrilled. but then I realised something, each time I'm allocating 8 bytes for each stack slot, these 64 bit slots can hold 'anything'. e.g integers, chars and most importantly a pointer to 'anything'.

so I pushed a string operand onto the stack: `"hello how are u???"` followed by operator `print_str`. it worked perfectly & that's when the project took over most of my spare time.

straight away I thought to myself: "why can't I grow this? why can't it do **loops**, **if/else**, **function calls**, handle **variables**, **heap allocations** & even **syscalls**?"

for almost two months, I had a pen & paper - sitting on my sofa, drawing stacks, marking pointers, working out how to track, where to repeat & where to carry on etc etc. I got both '**loops**' and a basic '**if**' block working pretty quickly, all on a single stack. so I challenged myself to get **everything** working on a **single** stack (that's why I originally called the project: 0ne_stacK).

but... here's the problem, whenever I tried nested **loops** or nested **ifs** or permutations of either, it broke. just as I thought I'd finally solved it, something else would break & this was extremely frustrating. I tried everything & basically I hit a wall. I gave up because it was too difficult!

the 'one-stack' challenge was too complicated for me, so I thought, "I'll cheat a bit & add just one more stack..". by adding that extra stack (used just for tracking pointers), it solved all the problems immediately. 

besides that, it showed me something I hadn't really thought about or appreciated before - `two-stack architecture` is simple yet very powerful & effective! 

most of the development journey can be found in the handwritten notes (handwriting isn't the best, but the diagrams helped me get through this project), anything that wasn't written down I've added in the same folder.

originally I called this project 0ne_stacK (out of frustration), but later I wanted something shorter & liked the name: 'talon'. a few months ago I discovered this name is widely used in software development, so I wanted something that sounded similar to 'talon'. 

I found `escalon` & `echelon`, both have a definition/link to step/ladder-rung! `echelon` is easier to say, so I renamed it..
