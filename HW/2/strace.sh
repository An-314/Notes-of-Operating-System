#!/bin/bash

##### copy #####
echo -e "hello\nworld" | strace -o log/copy.log bin/copy

##### echo #####
strace -o log/echo.log bin/echo "hello world"

##### exec #####
strace -o log/exec.log bin/exec
strace -e trace=execve,write,exit_group -o log/exec.short.log bin/exec

##### fork #####
strace -o log/fork.log bin/fork
strace -f -e trace=clone,clone3,fork,vfork,write,exit_group -o log/fork.short.log bin/fork

##### forkexec #####
strace -o log/forkexec.log bin/forkexec
strace -f \
  -e trace=clone,clone3,fork,vfork,execve,wait4,write,exit_group \
  -o log/forkexec.short.log \
  bin/forkexec

##### list #####
strace -o log/list.log bin/list
strace -e trace=openat,getdents64,read,close,write,exit_group -o log/list.short.log bin/list

##### open #####
strace -o log/open.log bin/open
strace -e trace=openat,write,close -o log/open.short.log bin/open

##### pipe1 #####
strace -o log/pipe1.log bin/pipe1
strace -e trace=pipe,pipe2,read,write,close,exit_group -o log/pipe1.short.log bin/pipe1

##### pipe2 #####
strace -o log/pipe2.log bin/pipe2
strace -f -e trace=pipe,clone,clone3,fork,read,write,close,exit_group -o log/pipe2.short.log bin/pipe2

##### redirect #####
strace -o log/redirect.log bin/redirect
strace -f \
  -e trace=clone,clone3,fork,close,openat,execve,write,wait4,exit_group \
  -o log/redirect.short.log \
  bin/redirect
