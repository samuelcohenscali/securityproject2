#!/bin/bash
objdump -d shell | sed -n '/needle0/,/needle1/p' > output
# needle0 and needle1 conveniently mark the beginning and end of our program
edges=($(grep needle output | cut -d' ' -f1 | awk '{print "0x" $0}'))
rm output
difference=$((${edges[1]}-${edges[0]}))
#I guess we need the last 2 bytes
beginning=$(printf '0x%x' $((${edges[0]}&0xFFFF)))
#round to next multiple of 8
padding=$((($difference+7)/8*8))
xxd -s$beginning -l$padding -p shell shellcode
