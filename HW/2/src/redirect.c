
// #include "kernel/types.h"
// #include "user/user.h"
// #include "kernel/fcntl.h"

// // redirect.c: run a command with output redirected

// int
// main()
// {
//   int pid;

//   pid = fork();
//   if(pid == 0){
//     close(1);
//     open("output.txt", O_WRONLY|O_CREATE);

//     char *argv[] = { "echo", "this", "is", "redirected", "echo", 0 };
//     exec("echo", argv);
//     printf("exec failed!\n");
//     exit(1);
//   } else {
//     wait((int *) 0);
//   }

//   exit(0);
// }

#include <fcntl.h> // open, O_WRONLY, O_CREAT
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h> // wait
#include <unistd.h>

int main(void) {
  int pid = fork();
  if (pid < 0) {
    perror("fork");
    exit(1);
  }

  if (pid == 0) {
    // 子进程: 重定向 stdout 到文件
    close(STDOUT_FILENO);
    if (open("output.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644) < 0) {
      perror("open");
      exit(1);
    }

    // 要执行的命令参数
    char *argv[] = {"echo", "this", "is", "redirected", "echo", NULL};

    // execvp 会在 PATH 中搜索 "echo"
    execvp(argv[0], argv);

    // execvp 失败才会执行到这里
    perror("execvp");
    exit(1);
  } else {
    // 父进程: 等待子进程结束
    wait(NULL);
  }

  return 0;
}
