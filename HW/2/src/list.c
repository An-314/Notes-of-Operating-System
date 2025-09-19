
// #include "kernel/types.h"
// #include "user/user.h"

// // list.c: list file names in the current directory

// struct dirent {
//   ushort inum;
//   char name[14];
// };

// int main() {
//   int fd;
//   struct dirent e;

//   fd = open(".", 0);
//   while (read(fd, &e, sizeof(e)) == sizeof(e)) {
//     if (e.name[0] != '\0') {
//       printf("%s\n", e.name);
//     }
//   }
//   exit(0);
// }

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <dirent.h>

// list.c: list file names in the current directory

int main(void) {
  DIR *dp;
  struct dirent *entry;

  // 打开当前目录
  dp = opendir(".");
  if (dp == NULL) {
    perror("opendir");
    exit(1);
  }

  // 逐个读取目录项
  while ((entry = readdir(dp)) != NULL) {
    // 跳过 "." 和 ".." 可以加判断
    printf("%s\n", entry->d_name);
  }

  closedir(dp);
  return 0;
}
