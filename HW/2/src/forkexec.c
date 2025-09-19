
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/wait.h>

// forkexec.c: fork then exec

int main() {
  int pid, status;

  pid = fork();
  if (pid == 0) {
    char *argv[] = {"echo", "THIS", "IS", "ECHO", 0};
    execvp("echo", argv);
    printf("exec failed!\n");
    exit(1);
  } else {
    printf("parent waiting\n");
    wait(&status);
    printf("the child exited with status %d\n", status);
  }

  exit(0);
}
