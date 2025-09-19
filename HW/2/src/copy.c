
// copy.c: copy input to output.

#include <stdlib.h>
#include <unistd.h>

int main() {
  char buf[64];

  while (1) {
    int n = read(0, buf, sizeof(buf));
    if (n <= 0)
      break;
    write(1, buf, n);
  }

  exit(0);
}
