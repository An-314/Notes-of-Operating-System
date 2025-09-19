
// exec.c: replace a process with an executable file

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
  char *argv[] = {"echo", "this", "is", "echo", 0};

  execvp("echo", argv);

  printf("exec failed!\n");

  exit(0);
}
