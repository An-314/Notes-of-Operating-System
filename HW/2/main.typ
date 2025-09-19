#import "@preview/scripst:1.1.1": *

#show: scripst.with(
  title: [操作系统第2次作业],
  author: "Anzreww",
  time: "2025/9/18",
  contents: true,
)

= 第一题

#exercise[
  熟练使用开发环境是顺利和高效完成操作系统课实验的必要条件。请从互联网搜索你需要的信息，以逐渐熟练使用qemu、shell、vim（也可以是其他你喜欢的代码编辑工具）和git等工具。然后回答如下问题。
  + 简要介绍一个模拟器工具，并查找相关的配置使用帮助；
  2. 简要介绍一个命令行工具，并查找相关的配置使用帮助；
  3. 简要介绍一个代码编辑工具，并查找相关的配置使用帮助；
  4. 简要介绍一个代码版本维护工具，并查找相关的配置使用帮助；
]

#solution[
  + QEMU(Quick EMUlator)是一个开源的虚拟机模拟器，支持x86、ARM、RISC-V等架构，可以模拟完整的计算机系统。在实验中我们要用的是`qemu-system-riscv64`。QEMU的官方网站是 https://www.qemu.org/documentation/ ，提供了详细的文档和使用指南；archlinux的wiki https://wiki.archlinuxcn.org/wiki/QEMU 提供了安装、配置和使用方式的详细说明；以及详细的中文介绍 https://zhuanlan.zhihu.com/p/580681197 。
  2. Bash(Bourne Again SHell)是Linux和Unix系统中常用的命令行解释器，提供了强大的脚本编写和命令执行功能。Bash的官方网站是 https://www.gnu.org/software/bash/ ，提供了完整的文档和手册；archlinux的wiki https://wiki.archlinuxcn.org/wiki/Bash 提供了安装、配置和使用方式的详细说明。 zsh(Z Shell)是另一个功能强大的命令行解释器，具有更丰富的功能和插件支持。zsh的官方网站是 https://www.zsh.org/ ，提供了详细的文档和使用指南；archlinux的wiki https://wiki.archlinuxcn.org/wiki/Zsh 提供了安装、配置和使用方式的详细说明。
  3. VSCode(Visual Studio Code)是一个由微软开发的开源代码编辑器，支持多种编程语言和扩展插件，对各种编程任务提供了强大的支持。VSCode的官方网站是 https://code.visualstudio.com/ 。
  4. Git是一个分布式版本控制系统，用于跟踪文件的更改和协作开发。Git的官方网站是 https://git-scm.com/ ，提供了完整的文档和手册；Pro Git电子书 https://git-scm.com/book/zh/v2 提供了详细的中文介绍和使用指南。
]

= 第二题

#exercise[
  下面是一组使用系统调用服务的应用程序。请尝试运行和分析其中的一个你有兴趣小例子的执行过程，利用Linux系统中的#link("https://zhuanlan.zhihu.com/p/69527356")[strace]工具来确定该应用程序在执行时调用了哪些系统调用。

  #link("https://pdos.csail.mit.edu/6.828/2021/lec/l-ovexrview/")[使用操作系统的系统调用服务的应用程序示例列表]（出处：MIT的操作系统课）
]

先将这些引用程序下载，并编译。在过程中发现其头文件
```c
#include "kernel/types.h"
#include "user/user.h"
```
是 MIT 教学用的一个简化版 Unix 操作系统 xv6 的专用头文件，将其替换成 glibc 的头文件
```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
```
后成功编译。

== `copy.c`

```c
// 实现了一个简单的复制程序，从标准输入读取数据并写入标准输出，直到遇到EOF。

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
```
编译
```bash
gcc -o bin/copy src/copy.c
```
后利用strace跟踪其系统调用，并将日志保存到`log/copy.log`
```bash
strace -o log/copy.log bin/copy
```
输入`hello`和`world`，然后按`Ctrl+D`发送 EOF，结束输入。日志内容如下
```log
execve("bin/copy", ["bin/copy"], 0x7ffc6a5c4490 /* 91 vars */) = 0
brk(NULL)                               = 0x5639bb67a000
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (没有那个文件或目录)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=275743, ...}) = 0
mmap(NULL, 275743, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f1d0844d000
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0000x\2\0\0\0\0\0"..., 832) = 832
pread64(3, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 896, 64) = 896
fstat(3, {st_mode=S_IFREG|0755, st_size=2149728, ...}) = 0
mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f1d0844b000
pread64(3, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 896, 64) = 896
mmap(NULL, 2174000, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f1d08200000
mmap(0x7f1d08224000, 1515520, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x24000) = 0x7f1d08224000
mmap(0x7f1d08396000, 454656, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x196000) = 0x7f1d08396000
mmap(0x7f1d08405000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x204000) = 0x7f1d08405000
mmap(0x7f1d0840b000, 31792, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f1d0840b000
close(3)                                = 0
mmap(NULL, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f1d08448000
arch_prctl(ARCH_SET_FS, 0x7f1d08448740) = 0
set_tid_address(0x7f1d08448a10)         = 2438036
set_robust_list(0x7f1d08448a20, 24)     = 0
rseq(0x7f1d08448680, 0x20, 0, 0x53053053) = 0
mprotect(0x7f1d08405000, 16384, PROT_READ) = 0
mprotect(0x563990bee000, 4096, PROT_READ) = 0
mprotect(0x7f1d084d2000, 8192, PROT_READ) = 0
prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
getrandom("\x64\x96\xe9\x94\xaa\x1c\xa1\xf5", 8, GRND_NONBLOCK) = 8
munmap(0x7f1d0844d000, 275743)          = 0
read(0, "hello\n", 64)                  = 6
write(1, "hello\n", 6)                  = 6
read(0, "world\n", 64)                  = 6
write(1, "world\n", 6)                  = 6
read(0, "", 64)                         = 0
exit_group(0)                           = ?
+++ exited with 0 +++
```

查阅资料与询问AI#footnote[下面内容基本上都是与ChatGPT5的对话结果]，仔细研究每一行的输出，下面是对日志的逐行分析：
+ `execve("bin/copy", ["bin/copy"], 0x7ffc... /* 91 vars */) = 0`
  ```c
  int execve(const char *pathname, char *const argv[], char *const envp[]);
  ```
  执行程序的系统调用

  加载并开始执行可执行文件，把参数与环境变量传给新进程。Shell 进程调用 `execve("bin/copy", ...)`，用 `bin/copy` 程序 替换掉自己，从此开始运行 `copy` 这个程序，带着参数列表`argv`和 91 个环境变量

+ `brk(NULL) = 0x5639...`

  ```c
  int brk(void *addr);
  ```
  堆内存管理系统调用，控制进程数据段（heap）的顶端位置

  查询当前进程数据段顶端位置，glibc启动时会了解堆的初始位置

+ `access("/etc/ld.so.preload", R_OK) = -1 ENOENT`

  ```c
  int access(const char *pathname, int mode);
  ```
  检查调用进程是否对某个文件有指定的访问权限（不打开文件）

  `access` 检查调用进程是否对某个文件有指定的访问权限，动态链接器检查是否有 `ld.so.preload` 预加载库；没有就报不存在

+ `openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3`

  ```c
  int openat(int dirfd, const char *pathname, int flags);
  ```
  允许指定一个目录作为基准路径，打开一个文件

  `/etc/ld.so.cache` 是动态链接器的库缓存文件，以便快速定位要加载的共享库文件；打开方式为`O_RDONLY`只读和`O_CLOEXEC`在执行`execve()`时自动关闭这个文件描述符（在 Linux/Unix 中，一切皆文件；内核不会直接把文件对象给用户态，而是通过一个整数编号来代表它，这个编号就是文件描述符(fd)）

  内核返回文件描述符3（0,1,2 已经被 stdin, stdout, stderr 占用；所以新打开的文件一般从 3 开始）

+ `fstat(3, ...) = 0`

  ```c
  int fstat(int fd, struct stat *statbuf);
  ```
  根据fd获取文件的元数据，结果写到struct stat结构体里，包括：c文件类型（普通文件、目录、socket…），权限（rwx），文件大小（以字节计），最后访问/修改时间，inode 编号、设备号等

  获取该缓存文件的元数据（大小、权限等），返回值 0 表示调用成功

+ `mmap(NULL, 275743, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f1d0844d000`

  ```c
  void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
  ```
  内存映射系统调用，把一个文件或一段匿名内存区域直接映射到进程的虚拟地址空间

  把 `ld.so.cache` 映射进内存以便读取，内核返回了这段映射在虚拟内存中的起始地址

+ `close(3) = 0`

  ```c
  int close(int fd);
  ```
  关闭一个打开的文件描述符，释放内核资源

  关闭 fd=3（缓存保持映射即可），返回 0 表示成功；这一步使文件内容可以直接通过内存访问；内核会保证内存和文件的关联，即使 fd 关闭，映射仍然有效。

+ `openat(..., "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3`

  （动态链接器先前查`/etc/ld.so.cache`，发现`libc`的路径在`/usr/lib/libc.so.6`，）打开`libc`共享库，复用文件描述符 3

+ `read(3, "\177ELF..." , 832) = 832`

  ```c
  ssize_t read(int fd, void *buf, size_t count);
  ```
  从文件描述符`fd`里读`count`字节到缓冲区`buf`，成功时返回实际读到的字节数。

  读 ELF 头`0x7F 'E' 'L' 'F'`，确认与解析段信息。

+ `pread64(3, ..., 896, 64) = 896`

  ```c
  ssize_t pread64(int fd, void *buf, size_t count, off_t offset);
  ```
  从文件`fd`的指定偏移`offset`处读`count`字节到`buf`，不改变文件的“当前读写位置”（不动文件指针的定点读取）

  按偏移读取更多 ELF 结构：x86_64 上，ELF 文件头 (ELF header) 大小通常是 64 字节，定点把后续关键表（程序头表等）读进来，且不打乱其他线程可能在用的文件位置

+ `fstat(3, {... st_size=2149728 ...}) = 0`

  获取 libc 文件元数据。

+ `mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)`

  给动态链接器/线程局部等准备一小块匿名内存，给程序分配一块干净的私有内存，不对应任何磁盘文件

+ `pread64(...) = 896`

  继续解析 ELF。

+ 一系列 `mmap(..., PROT_READ/EXEC/WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, offset)`

  把 `libc.so.6` 的不同段按权限映射到内存：
  - `PROT_READ|PROT_EXEC` → 代码段
  - `PROT_READ` → 只读数据
  - `PROT_READ|PROT_WRITE` → 可写数据/bss
  - `MAP_ANONYMOUS` 作为 bss/零填充或内部用区
  因为每个段的权限不同、对齐不同、在文件中的偏移不同，所以必须分开映射

+ `close(3) = 0`

  加载完 `libc`，关闭其文件描述符

+ `mmap(NULL, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)`

  再分配一小块匿名内存，来放置运行时数据结构，是给动态链接器准备内部使用的小工作区

+ `arch_prctl(ARCH_SET_FS, 0x7f1d08448740) = 0`

  ```c
  int arch_prctl(int code, unsigned long addr);
  ```
  x86_64 特有的体系结构相关调用，`ARCH_SET_FS` 用于设置 x86_64 的 FS 基址寄存器，`addr` 是线程本地存储 (TLS) 的基址

  在 x86_64 Linux 上，用户态的 TLS（Thread-Local Storage，线程本地存储）通过`%fs`段寄存器实现，把FS基址指向当前线程的线程控制块TCB，用户态代码就能用`%fs:offset`的方式，常数时间访问当前线程的私有数据；是glibc/动态链接器的启动阶段

+ `set_tid_address(0x7f1d08448a10) = 2438036`

  ```c
  int set_tid_address(int *tidptr);
  ```
  为当前线程登记一个用户态地址，当这个线程退出时，内核会：
  - 把该地址处的整型值写成0
  - 对该地址执行一次`futex_wake`（唤醒在此地址上等待的线程）

  向内核登记清理 futex 等的地址（线程/退出时用）

+ `set_robust_list(0x7f1d08448a20, 24) = 0`

  ```c
  int set_robust_list(struct robust_list_head *head, size_t len);
  ```
  为当前线程登记一个 robust futex 列表，`head` 指向一个`struct robust_list_head`结构体，`len`是该结构体的大小

  设置 robust futex 列表（线程崩溃时内核能自动解锁）

+ `rseq(0x7f1d08448680, 0x20, 0, 0x53053053) = 0`

  ```c
  int rseq(struct rseq *rseq, uint32_t len, int flags, uint32_t sig);
  ```
  注册一个 restartable sequences 结构体，`rseq` 指向一个`struct rseq`结构体，`len`是该结构体的大小，`flags`一般为0，`sig`是一个魔数，用于验证结构体的完整性

  让用户态能在一个很短的临界区里执行一些指令，如果中途被调度/抢占，就由内核帮你重新开始执行，避免写锁/原子操作的复杂性；glibc 在初始化时会检测内核是否支持 rseq

+ `mprotect(..., PROT_READ) = 0`

  ```c
  int mprotect(void *addr, size_t len, int prot);
  ```
  改变一段内存区域的访问权限

  把先前可写的段改成只读等最终权限，完成初始化后，这些段不应该再可写，否则程序运行中被改写可能导致漏洞；这一类`mprotect`出现在ELF加载的收尾阶段

+ `prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, ...}) = 0`

  ```c
  int prlimit64(pid_t pid, int resource, const struct rlimit *new_limit, struct rlimit *old_limit);
  ```
  用于获取或设置进程的资源限制

  glibc初始化时会做一些自检，包括：
  - 确认当前栈空间够大（某些线程/库调用需要大栈）
  - 根据栈上限调整线程属性（比如 pthread 默认栈大小 ≤ 进程栈上限）
  - 避免后续调用时因为栈不足导致崩溃
  glibc会用这个信息来初始化线程库，确保后续栈分配安全

+ `getrandom("\x64\x96...", 8, GRND_NONBLOCK) = 8`

  ```c
  ssize_t getrandom(void *buf, size_t buflen, unsigned int flags);
  ```
  直接从内核的 CSPRNG（cryptographically secure pseudo-random number generator）获取随机字节

  从内核取随机数，用于栈 canary、ASLR 相关随机化、glibc 初始化等安全用途

+ `munmap(0x7f1d0844d000, 275743) = 0`

  ```c
  int munmap(void *addr, size_t length);
  ```
  解除内存映射，释放内核资源

  用完 `ld.so.cache` 的映射后解除映射

#note(subname: [总结])[

  1. 程序装入入口
    - `execve("bin/copy", ["bin/copy"], envp)`
      → Shell 调用 `execve`，把自身替换为 `copy` 程序，传入 argv/envp，内核开始加载 ELF 文件
  2. 动态链接器准备
    - `brk(NULL)`
      → 查询/初始化堆顶位置，glibc 记录起始堆边界
    - `access("/etc/ld.so.preload")`
      → 检查是否有预加载库（无）
    - `openat("/etc/ld.so.cache")` → `fstat` → `mmap` → `close`
      → 打开并映射动态链接器的缓存，获取要加载的共享库路径
  3. 加载 C 标准库 `libc.so.6`
    - `openat("/usr/lib/libc.so.6")`
      → 打开 libc 共享库
    - `read("\177ELF...")` + `pread64(..., offset=64)`
      → 读取 ELF 头和程序头表，解析段布局
    - `fstat`
      → 获取 libc 文件大小、权限等元数据
    - 多次 `mmap(... PROT_R/X/W, MAP_FIXED ...)`
      → 按段把代码段、只读数据段、可写数据段、bss 区等映射进内存
    - `close(3)`
      → 文件加载完成后关闭 fd
  4. 链接器/运行时的额外准备
    - 多次 `mmap(MAP_ANONYMOUS)`
      → 分配小块匿名内存作为 TLS、链接器内部结构、bss 补齐等
    - `arch_prctl(ARCH_SET_FS, ...)`
      → 设置 FS 基址寄存器，启用线程本地存储 (TLS)
    - `set_tid_address`
      → 登记线程退出时通知地址（清零并 futex_wake），支持 `pthread_join`
    - `set_robust_list`
      → 登记 robust futex 列表，线程崩溃时内核自动解锁，避免死锁
    - `rseq`
      → 注册 restartable sequences，支持高性能的用户态短临界区
  5. 收尾 & 安全检查
    - `mprotect(..., PROT_READ)`
      → 收紧段权限（W^X 策略），禁止写入代码/只读数据段
    - `prlimit64(..., RLIMIT_STACK)`
      → 查询栈大小限制，glibc 用于初始化线程库配置
    - `getrandom(..., 8)`
      → 获取随机数，用于栈 canary、ASLR 偏移等安全机制
    - `munmap(ld.so.cache)`
      → 链接器用完 `/etc/ld.so.cache` 后释放映射

  然后控制权转交到 *`main()`*，`copy`程序正式进入用户代码，开始执行`read(0,...)` / `write(1,...)`循环。
]

上面是*启动阶段*：动态装载 libc、设置 TLS、权限、限制与安全随机数等。接下来才到`./copy`的用户代码阶段，即`main()`函数的执行：

+ `read(0, "hello\n", 64) = 6`

  从fd=0(stdin)读到 6 字节

+ `write(1, "hello\n", 6) = 6`

  ```c
  ssize_t write(int fd, const void *buf, size_t count);
  ```
  #newpara()
  向fd=1(stdout)写回 6 字节

+ `read(0, "world\n", 64) = 6`

  再次读取输入

+ `write(1, "world\n", 6) = 6`

  写回

+ `read(0, "", 64) = 0`

  读到EOF返回0，循环`break`

+ `exit_group(0) = ?`

  `exit(0)` 最终在 glibc 里调用 `exit_group` 结束整个进程/线程组，进程以状态码 0 退出；`strace` 用 `?` 表示这调用没有“返回到用户态”，因为进程已终止

+ `+++ exited with 0 +++`

== echo.c

```log
write(1, "hello", 5)                    = 5
write(1, " ", 1)                        = 1
write(1, "world", 5)                    = 5
write(1, "\n", 1)                       = 1
exit_group(0)                           = ?
+++ exited with 0 +++
```

== exec.c

```log
execve("bin/exec", ["bin/exec"], 0x7fff0b638360 /* 91 vars */) = 0
execve("/usr/local/sbin/echo", ["echo", "this", "is", "echo"], 0x7ffe0f0fdb78 /* 91 vars */) = -1 ENOENT (没有那个文件或目录)
execve("/usr/local/bin/echo", ["echo", "this", "is", "echo"], 0x7ffe0f0fdb78 /* 91 vars */) = -1 ENOENT (没有那个文件或目录)
execve("/usr/bin/echo", ["echo", "this", "is", "echo"], 0x7ffe0f0fdb78 /* 91 vars */) = 0
write(1, "this is echo\n", 13)          = 13
exit_group(0)                           = ?
+++ exited with 0 +++
```

== fork.c

```log
3349944 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f6053e2aa10) = 3349945
3349944 write(1, "fork() returned 3349945\n", 24) = 24
3349944 write(1, "parent\n", 7)         = 7
3349944 exit_group(0)                   = ?
3349945 write(1, "fork() returned 0\n", 18) = 18
3349945 write(1, "child\n", 6 <unfinished ...>
3349944 +++ exited with 0 +++
3349945 <... write resumed>)            = 6
3349945 exit_group(0)                   = ?
3349945 +++ exited with 0 +++
```

== forkexec.c

```log
3355350 execve("bin/forkexec", ["bin/forkexec"], 0x7fff32bfaf38 /* 91 vars */) = 0
3355350 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7fd1e78dfa10) = 3355351
3355350 write(1, "parent waiting\n", 15 <unfinished ...>
3355351 execve("/usr/local/sbin/echo", ["echo", "THIS", "IS", "ECHO"], 0x7ffd079aba18 /* 91 vars */ <unfinished ...>
3355350 <... write resumed>)            = 15
3355351 <... execve resumed>)           = -1 ENOENT (没有那个文件或目录)
3355350 wait4(-1 <unfinished ...>
3355351 execve("/usr/local/bin/echo", ["echo", "THIS", "IS", "ECHO"], 0x7ffd079aba18 /* 91 vars */) = -1 ENOENT (没有那个文件或目录)
3355351 execve("/usr/bin/echo", ["echo", "THIS", "IS", "ECHO"], 0x7ffd079aba18 /* 91 vars */) = 0
3355351 write(1, "THIS IS ECHO\n", 13)  = 13
3355351 exit_group(0)                   = ?
3355351 +++ exited with 0 +++
3355350 <... wait4 resumed>, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 3355351
3355350 --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=3355351, si_uid=1000, si_status=0, si_utime=0, si_stime=0} ---
3355350 write(1, "the child exited with status 0\n", 31) = 31
3355350 exit_group(0)                   = ?
3355350 +++ exited with 0 +++
```

== list.c

```log
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0000x\2\0\0\0\0\0"..., 832) = 832
close(3)                                = 0
openat(AT_FDCWD, ".", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
getdents64(3, 0x55abb08e1040 /* 9 entries */, 32768) = 248
write(1, "makefile\n", 9)               = 9
write(1, ".gitignore\n", 11)            = 11
write(1, "strace.sh\n", 10)             = 10
write(1, "log\n", 4)                    = 4
write(1, "src\n", 4)                    = 4
write(1, "..\n", 3)                     = 3
write(1, ".\n", 2)                      = 2
write(1, "bin\n", 4)                    = 4
write(1, "main.typ\n", 9)               = 9
getdents64(3, 0x55abb08e1040 /* 0 entries */, 32768) = 0
close(3)                                = 0
exit_group(0)                           = ?
+++ exited with 0 +++
```

== open.c

```log
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
close(3)                                = 0
openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
close(3)                                = 0
openat(AT_FDCWD, "output.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 3
write(3, "ooo\n", 4)                    = 4
close(3)                                = 0
+++ exited with 0 +++
```

== pipe1.c

```log
close(3)                                = 0
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0000x\2\0\0\0\0\0"..., 832) = 832
close(3)                                = 0
pipe2([3, 4], 0)                        = 0
write(4, "this is pipe1\n", 14)         = 14
read(3, "this is pipe1\n", 100)         = 14
write(1, "this is pipe1\n", 14)         = 14
exit_group(0)                           = ?
+++ exited with 0 +++
```

== pipe2.c

```log
3374318 close(3)                        = 0
3374318 read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0000x\2\0\0\0\0\0"..., 832) = 832
3374318 close(3)                        = 0
3374318 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f0cac964a10) = 3374319
3374318 read(3 <unfinished ...>
3374319 write(4, "this is pipe2\n", 14 <unfinished ...>
3374318 <... read resumed>, "this is pipe2\n", 100) = 14
3374319 <... write resumed>)            = 14
3374318 write(1, "this is pipe2\n", 14) = 14
3374319 exit_group(0 <unfinished ...>
3374318 exit_group(0 <unfinished ...>
3374319 <... exit_group resumed>)       = ?
3374318 <... exit_group resumed>)       = ?
3374319 +++ exited with 0 +++
3374318 +++ exited with 0 +++
```

== redirect.c

```log
3374326 execve("bin/redirect", ["bin/redirect"], 0x7ffcdfca19c8 /* 91 vars */) = 0
3374326 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
3374326 close(3)                        = 0
3374326 openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
3374326 close(3)                        = 0
3374326 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f605b74ea10) = 3374327
3374326 wait4(-1 <unfinished ...>
3374327 close(1)                        = 0
3374327 openat(AT_FDCWD, "output.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 1
3374327 execve("/usr/local/sbin/echo", ["echo", "this", "is", "redirected", "echo"], 0x7ffc965b4788 /* 91 vars */) = -1 ENOENT (没有那个文件或目录)
3374327 execve("/usr/local/bin/echo", ["echo", "this", "is", "redirected", "echo"], 0x7ffc965b4788 /* 91 vars */) = -1 ENOENT (没有那个文件或目录)
3374327 execve("/usr/bin/echo", ["echo", "this", "is", "redirected", "echo"], 0x7ffc965b4788 /* 91 vars */) = 0
3374327 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
3374327 close(3)                        = 0
3374327 openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
3374327 close(3)                        = 0
3374327 openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
3374327 close(3)                        = 0
3374327 write(1, "this is redirected echo\n", 24) = 24
3374327 close(1)                        = 0
3374327 close(2)                        = 0
3374327 exit_group(0)                   = ?
3374327 +++ exited with 0 +++
3374326 <... wait4 resumed>, NULL, 0, NULL) = 3374327
3374326 --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=3374327, si_uid=1000, si_status=0, si_utime=0, si_stime=0} ---
3374326 exit_group(0)                   = ?
3374326 +++ exited with 0 +++
```

== strace.sh

```bash
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
```
