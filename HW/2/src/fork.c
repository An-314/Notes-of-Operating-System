
// fork.c: create a new process

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
  int pid;

  pid = fork();

  printf("fork() returned %d\n", pid);

  if (pid == 0) {
    printf("child\n");
  } else {
    printf("parent\n");
  }

  exit(0);
}
