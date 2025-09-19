
// // open.c: create a file, write to it.

// #include "kernel/fcntl.h"
// #include "kernel/types.h"
// #include "user/user.h"

// int main() {
//   int fd = open("output.txt", O_WRONLY | O_CREATE);
//   write(fd, "ooo\n", 4);

//   exit(0);
// }

#include <fcntl.h> // open, O_WRONLY, O_CREAT, O_TRUNC
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h> // write, close

int main(void) {
  // O_CREAT 要带上 mode 参数（比如 0644）
  int fd = open("output.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) {
    perror("open");
    exit(1);
  }

  if (write(fd, "ooo\n", 4) != 4) {
    perror("write");
    close(fd);
    exit(1);
  }

  close(fd);
  return 0;
}
