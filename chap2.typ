#import "@preview/scripst:1.1.1": *

= 实践与实验介绍

== 实践与实验简要分析

满足应用逐渐增加的需求
- LibOS
- 批处理OS
- 多道程序与分时多任务OS
逐步体现操作系统的概念抽象
- 地址空间抽象的OS
- 进程抽象的OS
- 文件抽象的OS
逐步体现操作系统的关键能力
- 可进程间通信的OS
- 可并发的OS
- 管理I/O设备的OS

#link("https://learningos.cn/rCore-Tutorial-Book-v3")[rCore实验手册]

== Compiler与OS

=== 硬件环境

- 开发的硬件环境
  - x86
- 目标硬件环境
  - RISC-V

=== 应用程序执行环境

#grid(columns: (1fr, 1fr))[
  #figure(
    image("pic/2025-09-22-15-35-18.png", width: 100%),
    numbering: none,
  )

][
  - 编译器工作
    - 源码$->$汇编码
  - Assembler（汇编器）工作
    - 汇编码 $->$ 机器码
  - Linker（链接器）工作
    - 多个机器码目标文件 $->$ 单个机器码执行文件
  - OS工作
    - 加载/执行/管理机器码执行文件
]
#note(subname: [应用程序执行环境的分层结构])[
  - 硬件平台（Hardware）
    - 最底层是真实的硬件（CPU、内存、磁盘、网卡等）
    - 硬件只能识别机器码（binary instructions），由指令集架构（ISA, Instruction Set Architecture）规定
  - 指令集（ISA）
    - ISA 定义了 CPU 能执行的指令种类（如 mov, add, jmp 等）
    - 高级语言最终都要被编译成 ISA 层面的机器指令
    - 常见 ISA：x86-64、ARM、RISC-V
  - 内核 / 操作系统（Kernel / OS）
    - 管理硬件资源（CPU 调度、内存管理、I/O 设备）
    - 提供系统调用(syscall)接口，让用户程序能安全访问硬件
    - 举例：Linux 的 `read, write, fork`，Windows 的 `CreateFile, CreateProcess`
  - 系统调用（System Calls）
    - 这是应用程序访问操作系统的“桥梁”
    - 例如 C 的 `open()` 调用会转化成 `sys_open` 系统调用，由内核处理磁盘文件操作
    - 系统调用属于 用户态 → 内核态 的切换
  - 标准库（Standard Library）
    - 封装系统调用和常用功能，提供易用的 API
    - 例如：
      - C 的 `glibc`，把 `printf → write` 系统调用。
      - Rust 的 `std`，把 `std::fs::File::open` → OS 文件 API
    - 程序员写代码时主要用标准库，而不是直接调用系统调用
  - 函数调用（Function Calls）
    - 应用程序里定义的函数、或者库函数
    - 函数调用最终会通过编译器生成对应的机器指令，可能进一步调用标准库或系统调用
  - 应用程序（Application）
    - 最顶层是源代码编译生成的程序
    - 应用程序利用标准库和系统调用访问硬件资源，实现业务逻辑
]

#note(subname: [编译])[

  以一个简单的 *C 程序* 为例，把它从源代码到运行的全过程细致拆开。比如程序：

  ```c
  #include <stdio.h>

  int main() {
      printf("Hello, world!\n");
      return 0;
  }
  ```
  - *源代码（Source Code）*
    - 人类可读，用 C 语法写
    - 文件扩展名 `.c`
    - 这里调用了标准库函数 `printf`
  - *编译全过程*
    - *预处理（Preprocessing）*
      - 工具：`cpp`（C Preprocessor）。
      - 主要工作：
        - 展开 `#include`：把 `<stdio.h>` 的内容复制进来。
        - 宏展开（`#define`）。
        - 条件编译（`#ifdef`）。
      - 结果：得到一个纯粹的 C 源文件（不再有 `#include` 等指令）。
      - 输出：预处理后的 C 源码（通常可以用 `gcc -E` 查看）
    - *编译（Compilation）*
      - 工具：`cc1`（GCC 内部）、`clang` 等。
      - 主要工作：
        - 把预处理后的 C 代码翻译成 *汇编代码*（Assembly）
        - 做词法分析、语法分析、语义检查、优化
      - 例子：
        `main()` 里的 `printf("Hello, world!\n");` 可能编译成类似：
        ```asm
        mov edi, OFFSET FLAT:.LC0   ; 把字符串地址放到寄存器 edi
        call printf                 ; 调用 printf
        mov eax, 0                  ; return 0
        ret
        ```
      - 输出：汇编文件 `.s`（可用 `gcc -S` 查看）
    - *汇编（Assembly）*
      - 工具：`as`（GNU Assembler）
      - 主要工作：把汇编代码翻译成 *机器码指令*
      - 结果：生成 *目标文件* `.o`
      - `.o` 文件内容：
        - 已编译好的机器码（对应函数体）
        - 但函数 `printf` 还没有定义，留有“未解析的符号”。
      - 输出：目标文件 `.o`（可用 `objdump -d` 反汇编查看）
    - *链接（Linking）*
      - 工具：`ld`（Linker）
      - 主要工作：
        - 把多个 `.o` 文件和库文件（如 `libc.so`）组合成一个完整程序
        - 解决外部符号（比如 `printf` 在 `glibc` 里）
        - 布局内存段（`.text` 指令段、`.data` 数据段、`.bss` 未初始化数据段）
      - 最终得到可执行文件（Linux 下是 *ELF 格式*，Windows 下是 *PE 格式*）
      - 输出：可执行文件 `a.out` 或自定义名称
    - *操作系统加载（Loading）*
      - 当我们运行 `./a.out` 时，操作系统执行以下步骤：
        + *解析可执行文件头*（ELF Header）：确定入口点（`main` 不是入口点，真正入口是 `_start`）
        + *内存映射*：把 `.text`（代码）、`.data`（初始化数据）、`.bss`（零填充）、堆和栈都映射到虚拟内存
        + *加载动态库*：比如 `libc.so`，以便运行时能找到 `printf`
        + *设置运行环境*：初始化栈，传入 `argc`、`argv`、环境变量
        + *跳转到入口点 `_start`*：
          - `_start` 调用运行时库初始化函数（`__libc_start_main`）
          - 再调用用户定义的 `main`
    - *程序运行（Execution）*
      + CPU 开始执行 `main`：
        - `printf("Hello, world!\n")` → 触发标准库调用 → 进一步触发系统调用 `write`
        - 系统调用进入内核态，把字符串写到终端（文件描述符 `stdout`）
      + `main` 返回 `0` → 传递给 `exit` 系统调用 → 通知 OS 进程结束
      + 操作系统清理进程资源
    ```
    源码 (.c)
      │  [预处理器]
      ▼
    预处理后的源码
      │  [编译器]
      ▼
    汇编代码 (.s)
      │  [汇编器]
      ▼
    目标文件 (.o)
      │  [链接器]
      ▼
    可执行文件 (ELF/PE)
      │  [操作系统加载器]
      ▼
    进程 (内存中)
      │  [CPU 执行指令]
      ▼
    程序运行 → 输出 "Hello, world!"
    ```
]

#note(subname: [动态&静态链接])[

  在现代操作系统中，C 标准库（`libc`）通常以 *动态链接库*（`libc.so`）的形式存在，而不是静态链接库（`libc.a`）。

  - 静态链接 vs 动态链接
    - *静态链接*（`gcc -static`）

      把 `libc.a` 里的代码直接拷贝到可执行文件里
      - 优点：独立可运行，不依赖外部库
      - 缺点：每个程序都有一份完整 `libc`，磁盘和内存都浪费
    - *动态链接*（默认情况，用 `libc.so`）

      程序里只保留对 `libc.so` 的引用，不拷贝实现。运行时由动态链接器（Linux 上是 `ld-linux.so`）加载 `libc.so`，并把函数地址修正
      - 优点：共享库代码，不重复拷贝；更新库更容易
      - 缺点：运行时需要加载和绑定，启动时稍有开销
  - 内存共享机制

    当多个程序都使用 `libc.so` 时，操作系统采用 *内存映射（memory mapping）+ 页表共享* 技术，避免浪费：

    - *只读段共享*

      `libc.so` 中的代码段（.text）是 *只读* 的，不会被修改。
      OS 把这部分映射进内存后，可以让多个进程共享同一份物理内存页面。

    - *可写段独立*

      `libc.so` 中的全局变量（.data/.bss）需要写操作。
      每个进程会得到*自己的副本*（写时复制，Copy-on-Write）。
      所以这里会有内存消耗，但远远比复制整个库要少。
  - 运行时加载流程
    + 程序启动时，OS 通过 ELF 文件头知道它需要 `libc.so.6`。
    + 动态链接器 `ld-linux.so` 查找并映射 `libc.so` 到内存。
    + 修改符号表，修复函数调用地址（比如 `printf`）。
    + 多个进程映射到同一个物理内存里的 `libc.so` 代码区。
]

=== 操作系统执行环境

*编译器/汇编器/链接器工作*
- 源码 $->$ 汇编码 $->$ 机器码 $->$ 执行程序
- Bootloader加载OS执行
#note(subname: [从硬件启动到操作系统执行])[

  这里引入了 Bootloader，即引导加载程序（比如 x86 上常见的 GRUB，嵌入式上是 U-Boot）

  1. 上电 & 固件初始化
    - 计算机加电后，CPU 从固定地址（x86 是 BIOS/UEFI 的固件代码）开始执行
    - 固件完成硬件初始化（内存检测、设备初始化），然后找到存储介质上的引导扇区
  2. Bootloader 阶段
    - Bootloader 是一个非常小的程序，它的唯一任务就是把操作系统内核加载到内存
    - 功能包括：
      - 读取磁盘文件系统，找到内核镜像（Linux 内核镜像 vmlinuz）
      - 把内核加载到内存的合适位置
      - 切换 CPU 到合适模式（保护模式 / 长模式）
      - 跳转到内核入口函数（entry point）
  3. 内核加载与初始化
    - 内核开始执行，接管 CPU
    - 内核初始化：
      - 内存管理（MMU + 页表）
      - 进程管理（调度器）
      - 驱动初始化（磁盘、网络、显卡）
      - 文件系统挂载（挂载 `/` 根文件系统）
    - 内核完成后会启动第一个用户态进程（Linux 上是 `init` 或 `systemd`）
  4. 操作系统模块与库
    - OS模块：内核子系统（进程管理、内存管理、文件系统、网络协议栈…）
    - OS库：操作系统为应用提供的 API（系统调用接口 + runtime 支持库）
  5. 应用程序执行
    - 用户输入 `./a.out`，OS 加载可执行文件，分配进程空间，建立栈和堆，链接动态库（如 `libc.so`）
    - CPU 跳转到入口点开始执行
    - 程序在 应用程序执行环境 中运行，而整个环境是由 操作系统执行环境 提供支持
]

*可执行文件格式*
- 三元组
  - CPU 架构/厂商/操作系统
    ```bash
    rustc --print target-list | grep riscv
    riscv32gc-unknown-linux-gnu
    ...
    riscv64gc-unknown-linux-gnu
    riscv64imac-unknown-none-elf
    <arch>-<vendor>-<os>[-<abi>]
    ```
  - ELF: Executable and Linkable Format
    - ELF 文件能作为：
      - 可执行文件 (executable)：可以直接运行
      - 目标文件 (relocatable object)：`.o` 文件，等待链接
      - 共享库 (shared object)：`.so` 文件，动态链接库

#figure(
  image("pic/2025-09-22-15-42-14.png", width: 80%),
  numbering: none,
)

*链接和执行*

#figure(
  image("pic/2025-09-24-02-02-11.png", width: 80%),
  numbering: none,
)
ELF 文件既要让链接器（ld）工作，又要让操作系统加载器（loader）工作。因此，它有两种“解读方式”：
- 链接视图（Linking View）
  - 面向编译器/链接器
  - 关注的是 Section（节），比如 `.text`（代码）、`.data`（已初始化数据）、`.bss`（未初始化数据）、`.rodata`（只读数据）、`.symtab`（符号表）、`.rel.text`（重定位信息）
  - 链接器通过 Section Header Table 找到这些节，把多个目标文件拼装成一个完整的可执行文件
- 执行视图（Execution View）
  - 面向操作系统加载器
  - 关注的是 Segment（段），可执行代码段、可读写数据段、只读数据段
  - Loader 根据 Program Header Table 来决定如何把文件内容映射到进程的虚拟地址空间
    - `Segment 1` 映射到内存的可执行区域（对应 `.text`）
    - `Segment 2` 映射到内存的可读写区域（对应 `.data` 和 `.bss`）

*函数库*
- 标准库：依赖操作系统
  - 里面有大量对 OS 的调用封装
  - 提供功能：文件 I/O、网络、线程、进程、内存分配等等
    - Rust: `std` 标准库
    - C：`glibc, musl libc`
- 核心库：与操作系统无关
  - 适合运行在裸机或内核态
  - 提供的功能更底层：基本类型、算术、集合、错误处理。没有文件/线程/网络，因为这些都依赖 OS。
    - Rust: `core` 核心库
    - C: `Linux/BSD kernel libc`
  - 裸机程序
    - 与操作系统无关的OS类型的程序（Bare Metal program, 裸机程序）
    ```rust
    // os/src/main.rs
    #![no_std]
    #![no_main]

    mod lang_items;

    // os/src/lang_items.rs
    use core::panic::PanicInfo;

    #[panic_handler]
    fn panic(_info: &PanicInfo) -> ! {
        loop {}
    }
    ```
    这样的程序可以被编译成 裸机镜像，直接由 Bootloader 或硬件加载运行，不需要操作系统支持。


*ELF文件格式*
- 文件格式
  ```bash
  file target/riscv64gc-unknown-none-elf/debug/os
  target/riscv64gc-unknown-none-elf/debug/os: ELF 64-bit LSB executable, UCB RISC-V, ......
  ```
- #link("https://wiki.osdev.org/ELF")[ELF文件格式] Executable and Linkable Format
  - 静态阶段（文件视角）：它是磁盘上的二进制文件，包含头部、各个 section（节）
  - 动态阶段（执行视角）：加载器根据 ELF 的 Program Header 把对应段映射到虚拟内存，形成进程的运行时布局
  #figure(
    image("pic/2025-09-24-02-26-59.png", width: 80%),
    numbering: none,
  )

*App/OS内存布局*：运行时内存区域，由操作系统在加载 ELF 时建立
- `.text`: 代码段
  - 内容：程序的机器指令（编译器生成的目标代码）
  - 属性：只读、可执行（`r-x`）
  - 特点：
    - 存放函数体，比如 `main` 的指令序列。
    - 为了安全，现代系统禁止对 `.text` 段写入（W^X 原则：Write XOR Execute）
- `.rodata`: 已初始化数据段，只读的全局数据（常数或者是常量字符串）
  - 内容：已初始化但只读的全局数据
  - 属性：只读，不可执行（`r--`）
- `.data`: 可修改的全局数据
  - 内容：已初始化的全局/静态变量（非 const）
  - 属性：可读写，不可执行（`rw-`）
  - 特点：
    - 存储在可执行文件里（带有初始值）
    - 程序运行时被加载到内存，可被修改
- `.bss`: 未初始化数据段（Block Started by Symbol）
  - 内容：未初始化或初始化为 0 的全局/静态变量
  - 属性：可读写，不可执行（`rw-`）
  - 特点：
    - 在 ELF 文件中不占磁盘空间，只记录大小
    - 程序运行时被加载到内存，初始值为 0
- 堆 （heap）
  - 内容：动态分配的内存（`malloc, new`）
  - 属性：可读可写，不可执行（`rw-`）
  - 特点：
    - 向高地址增长
    - 管理由运行时库（如`glibc malloc`）或程序员自己负责
- 栈 （stack）
  - 内容：函数调用的局部变量、返回地址、函数参数、寄存器保存区
  - 属性：可读可写，不可执行（NX stack）
  - 特点：
    - 向低地址增长
    - 由编译器自动管理（函数调用时分配，函数返回时释放）
    - 每个线程有独立栈
```
高地址
+-------------------+
|       栈 (Stack)  |  向下增长
+-------------------+
|       堆 (Heap)   |  向上增长 (malloc)
+-------------------+
|       .bss        |  未初始化全局变量
+-------------------+
|       .data       |  已初始化全局变量
+-------------------+
|       .rodata     |  常量、只读数据
+-------------------+
|       .text       |  代码段（指令）
+-------------------+
低地址
```
#note(subname: [ELF的节和段])[
  ELF 文件有两个“视角”，正好对应 链接视图 (section) 和 执行视图 (segment)：
  - Section（节）
    - 面向 编译器/链接器
    - 逻辑划分，存储源代码级别的编译产物
    - 例如：`.text`、`.data`、`.bss`、`.rodata`、`.symtab`、`.rel.text`
    - 这些信息用来完成 符号解析、重定位、调试
    - 在最终运行时，有些 section 根本不会加载进内存（比如 `.symtab` 符号表）
  - Segment（段）
    - 面向 操作系统加载器。
    - 物理划分，描述如何把 ELF 映射到内存。
    - 由 Program Header Table 定义，比如：
      - `PT_LOAD`：可装载段（把文件里的字节映射到进程地址空间）
      - `PT_DYNAMIC`：动态链接需要的信息
    - 一个 segment 可以包含多个 section
      - `.text` + `.rodata` 可能放到同一个 只读可执行段里。
      - `.data` + `.bss` 放到同一个 可读写段里。
]

#note(subname: [堆栈分析 (stack frame analysis)])[
  ```rust
  fn foo(a: i32) -> i32 {
      let b = 20;
      let c = &a;
      b + *c
  }

  fn main() {
      let x = 10;
      let y = foo(x);
      println!("{}", y);
  }
  ```
  调用 `main` 时的栈帧：CPU 通过 `call main` 指令进入 `main`，栈帧内容大致如下
  ```
  高地址
  |------------------|
  | 返回地址 (OS -> main) |
  |------------------|
  | 局部变量 x = 10  |
  | 局部变量 y = ?   |
  |------------------|
  低地址
  ```
  `main` 调用 `foo(x)`：执行 `foo(x)` 时，CPU 会：
  把 `main` 的下一条指令地址压入栈（作为返回地址）。把参数 `x=10` 传给 `foo`（在栈上或寄存器里，这里假设压栈）
  ```
  高地址
  |------------------|
  | 返回地址 (OS -> main) |
  | 局部变量 x = 10  |
  | 局部变量 y = ?   |
  |------------------| ← main 栈底
  | 返回地址 (main -> foo) |
  | 参数 a = 10      |
  | 局部变量 b = 20  |
  | 局部变量 c = &a  |
  |------------------| ← foo 栈底
  低地址
  ```
  `foo` 返回时：`foo` 计算结果 `b + *c = 20 + 10 = 30`，返回值通常放在寄存器（比如 `eax/rax`）。`ret` 指令会弹出“返回地址 `(main -> foo)`”，跳回到 `main`。栈帧恢复到 `main` 的状态。
  ```
  高地址
  |------------------|
  | 返回地址 (OS -> main) |
  | 局部变量 x = 10  |
  | 局部变量 y = 30  |
  |------------------| ← main 栈底
  低地址
  ```
  `main` 打印结果：`println!` 调用库函数，依赖标准库，背后会进一步进入 OS 的系统调用层。栈帧会继续展开，但逻辑和 `foo` 的过程类似。
]

#note(subname: [组成原理知识回顾])[
  - CPU（中央处理器）
    - 主要组成：
      - 控制单元 (Control Unit)：解释并执行指令（fetch-decode-execute）
      - 算术逻辑单元 ALU (Arithmetic Logic Unit)：进行加减乘除、逻辑运算
      - 寄存器组 Register File：超高速的存储单元，用来保存正在处理的数据
    - 作用：从内存取指令 → 解码 → 执行 → 结果再写回寄存器或内存
    - CPU 本身不“长期存储”数据，它主要负责运算和控制
  - 寄存器（Register）
    - CPU 内部的极小容量、极高速的存储单元
    - 特点：
      - 每个寄存器可能只有 32 位或 64 位宽度
      - 访问速度比内存快几个数量级（纳秒级 vs 百纳秒级）
    - 常见寄存器：
      - 通用寄存器：存放临时数据（x86 的 eax, ebx；RISC-V 的 x1, x2 等）
      - 程序计数器 (PC / RIP)：存放下一条要执行的指令地址
      - 栈指针 (SP)：指向当前函数调用的栈顶
      - 基址寄存器 / 帧指针 (BP / FP)：指向当前函数栈帧的基准位置
      - 状态寄存器 (FLAGS/EFLAGS)：保存比较/运算的结果（如零标志 ZF、进位标志 CF）
    - 计算机里几乎所有的指令，都需要寄存器作为操作数
  - 内存（Memory）
    - 外部的存储器（RAM, 主存）
    - 特点：
      - 容量大（GB 级别），但访问速度比寄存器慢
      - 通过地址访问，按字节寻址
    - 作用：
      - 存放程序指令（机器码）
      - 存放全局变量、堆、栈数据
    - CPU 通过地址总线和数据总线与内存交互
    - CPU 无法直接处理硬盘上的数据，必须先把数据加载到内存，然后才能用寄存器参与运算

  以一条汇编指令为例：
  ```asm
  mov eax, [ebx + 4]
  ```
  - 这条指令的含义是：把内存地址 `ebx + 4` 处的 4 字节数据加载到寄存器 `eax`
  - 执行过程：
    1. CPU 从寄存器 `ebx` 读取值，加上偏移 `4`，得到内存地址
    2. CPU 通过地址总线访问内存，读取该地址处的 4 字节数据
    3. CPU 把读取到的数据写入寄存器 `eax`
]

#note(subname: [寄存器])[
  - 通用寄存器 (General Purpose Registers)
    - 用途：保存临时数据、函数参数、运算结果
    - 特点：没有固定的单一功能，由编译器或程序员自由使用
    - 例子：
      - x86：`eax, ebx, ecx, edx`（历史上有专门用途，但现代都算通用）
      - RISC-V：`x0~x31`（其中 `x0` 永远是常数 0）
      ```asm
      mov eax, 5      ; eax = 5
      mov ebx, 7      ; ebx = 7
      add eax, ebx    ; eax = eax + ebx = 12
      ```
  - 程序计数器 (PC, Program Counter) / RIP (x86-64)
    - 用途：保存下一条要执行的指令地址
    - 特点：每执行一条指令，PC 会自动更新到下一条
      - 执行一条指令后自动递增（顺序执行）
      - 遇到跳转（`jmp`、`call`、`ret`）时，PC 会被修改成目标地址
    - 例子：
      ```asm
      0x400100: mov eax, 1     ; 开始时PC = 0x400100，执行第一条指令
      0x400105: add eax, 2     ; 执行后 PC 自动变成 0x400105
      0x40010a: jmp 0x400120   ; jmp 修改 PC = 0x400120，跳转执行
      ```
  - 栈指针 (SP, Stack Pointer)
    - 用途：指向当前函数调用栈的顶部（栈顶地址）
    - 特点：
      - 压栈 (push) → SP 向低地址移动
      - 出栈 (pop) → SP 向高地址移动
      - 所有局部变量、返回地址、保存的寄存器，都是通过 SP 来定位的
    - 例子：
      ```asm
      call foo     ; 压入返回地址，跳转到 foo
      ```
      进入 `foo` 前后栈的变化
      ```
      调用前：
      SP → | .... |
            | ret_addr (main继续执行的地址) |

      foo 内部：
      SP → | .... |
            | 局部变量 |
      ```
  - 基址寄存器 / 帧指针 (BP / FP, Base/Frame Pointer)
    - 用途：指向当前函数栈帧的固定基准位置
    - 特点：
      - 在函数调用时保存上一个函数的 BP，然后更新为新的栈帧基准
      - 方便访问局部变量和参数（通过固定偏移量）
    - 例子：
      ```asm
      foo:
        push ebp         ; 保存旧的帧指针
        mov ebp, esp     ; 新函数栈帧基准
        sub esp, 8       ; 给局部变量分配空间

        mov DWORD PTR [ebp-4], 10   ; 局部变量
        mov eax, [ebp+8]            ; 函数参数

        mov esp, ebp     ; 恢复栈帧
        pop ebp
        ret
      ```
      - 这里 `ebp` 指向栈帧底部，局部变量在 `ebp` 之下，参数在 `ebp` 之上
  - 状态寄存器 (FLAGS / EFLAGS / RFLAGS)
    - 用途：保存算术/逻辑运算的结果状态
    - 常见标志位：
      - ZF (Zero Flag)：结果是否为零
      - CF (Carry Flag)：是否产生进位/借位
      - SF (Sign Flag)：结果是否为负数
      - OF (Overflow Flag)：是否有溢出
    - 例子：
      ```asm
      cmp eax, ebx   ; 比较 eax 和 ebx
      je equal       ; 如果 ZF=1，则跳转 equal
      ```
      - `cmp` 实际上做 `eax - ebx` ，但只设置标志位：zf=1如果结果为0，SF=1如果结果为负
      - `je` 检查 ZF 是否为 1 来决定是否跳转
]

#note(subname: [小结])[
  - 编译过程
    - 编译器、汇编器、链接器
  - 程序加载
    - 应用程序加载
    - 裸机程序加载
  - 可执行文件格式ELF
    - ELF文件头
    - 段表（Program Header Table）
    - 节表（Section Header Table）
]

== 硬件启动与软件启动

=== RISC-V开发板

=== QEMU启动参数和流程

QEMU模拟器
- 使用软件 qemu-system-riscv64 来模拟一台 64 位 RISC-V 架构的计算机，它包含:
  - 一个 CPU（可调整为多核）
  - 一块物理内存
  - 若干 I/O 外设
#note(subname: [RISC-V])[
  RISC-V（读作 risk-five）是一种精简指令集计算机 (RISC, Reduced Instruction Set Computer) 的开放指令集架构 (ISA)
  - 指令集架构 (ISA, Instruction Set Architecture)
    - ISA 是一份“契约”，定义了 CPU 能理解的 指令种类、格式、语义
    - 内容包括：
      - 有多少寄存器、寄存器位宽
      - 每条指令怎么编码（二进制格式）
      - 指令的行为（比如 ADD 是把两个寄存器的值相加）
    - 例子（RISC-V ISA 里有这样的规定）：
      - `ADD rd, rs1, rs2`：把寄存器 `rs1` 和 `rs2` 的值相加，结果写到寄存器 `rd`
        - 指令编码是一个 32 位二进制字：`0000000 rs2 rs1 000 rd 0110011`
  - 汇编语言 (Assembly Language)
    - 汇编语言是对 ISA 的人类可读表示
    - 作用：让程序员不必直接写二进制，而是用助记符
    - 例子
      - RISC-V 汇编
        ```asm
        add x5, x6, x7   # x5 = x6 + x7
        ```
      - x86 汇编
        ```asm
        add eax, ebx     # eax = eax + ebx
        ```
]
QEMU启动参数
```bash
qemu-system-riscv64 \
    -machine virt \
    -nographic \
    -bios ../bootloader/rustsbi-qemu.bin \
    -device loader,file=target/riscv64gc-unknown-none-elf/release/os.bin,addr=0x80200000
```
- `machine virt` 表示将模拟的 64 位 RISC-V 计算机设置为名为 `virt` 的虚拟计算机
- 物理内存的默认大小为 128MiB
- `nographic` 表示模拟器不需要提供图形界面，而只需要对外输出字符流
- `bios` 可以设置 QEMU 模拟器开机时用来初始化的引导加载程序（bootloader）
- 这里使用预编译好的 `rustsbi-qemu.bin`
- `device` 的 `loader` 参数可以在 QEMU 模拟器开机之前将一个宿主机上的文件载入到 QEMU 的物理内存的指定位置中
- `file` 和 `addr` 参数分别可以设置待载入文件的路径以及将文件载入到的 QEMU 物理内存上的物理地址
- 通常计算机加电之后的启动流程可以分成若干个阶段，每个阶段均由一层软件负责；每一层软件在完成它承担的初始化工作，然后跳转到下一层软件的入口地址，将计算机的控制权移交给了下一层软件。

QEMU 模拟的启动流程则可以分为三个阶段：
- 由固化在#link("https://github.com/LearningOS/qemu/blob/386b2a5767f7642521cd07930c681ec8a6057e60/hw/riscv/virt.c#L59")[QEMU模拟的计算机内存]中的#link("https://github.com/LearningOS/qemu/blob/386b2a5767f7642521cd07930c681ec8a6057e60/hw/riscv/virt.c#L536")[一小段汇编程序]初始化并跳转执行bootloader；
- 由 bootloader 负责，初始化并加载OS，跳转OS执行；
- 由内核执行初始化工作。

=== x86启动流程

*真实计算机(x86)的启动流程*

基于x86的PC的启动固件的引导流程，从IBM PC机诞生第一天起，本质上就没有改变过。
- Rom Stage：直接在ROM上运行BIOS代码
  - 位置：主板上的只读存储器（早期是 ROM，现在是可刷写的 Flash）
  - 内容：BIOS 或 UEFI 固件代码
  - 工作：
    - CPU 上电后，程序计数器 PC 被硬编码为某个固定地址（x86 通常是`0xFFFF0`），从这里开始执行 BIOS 指令
    - BIOS 进行最基本的初始化
      - 切换 CPU 到实模式
      - 初始化南桥/北桥（芯片组）
      - 执行 POST (Power-On Self Test)，检测内存、显卡、键盘等是否正常
- Ram Stage：在RAM上运行代码，检测并初始化芯片组、主板等
  - 位置：此时固件会把更多代码加载到 RAM 中执行
  - 工作：
    - 内存检测：确认多少可用 RAM
    - 初始化主板和外设控制器
    - 建立中断向量表（方便后续 I/O 中断）
    - 进入 BIOS/UEFI 的“setup”界面，允许用户配置启动顺序
- Bootloader Stage：在存储设备上找到Bootloader，加载执行Bootloader
  - 位置：存储设备（硬盘、SSD、U盘等）的引导扇区
  - 内容：Bootloader 代码（如 GRUB、Syslinux、Windows Boot Manager）
    - MBR 里的代码就是最原始的 Bootloader 第一阶段
    - 它功能有限（512B），通常只负责加载更复杂的 Bootloader（如 GRUB、LILO）
    - 现代 UEFI：不再使用 MBR，而是直接从 EFI 分区加载 `.efi` 程序作为 Bootloader
  - 工作：
    - BIOS/UEFI 按照启动顺序查找可引导设备（硬盘、光盘、U 盘、网络）
    - 在启动设备上读取 第一个扇区 (MBR, 512B)，把它加载到内存的 `0x7C00` 地址
    - CPU 跳转执行这个引导扇区里的机器码
- OS Stage：Bootloader初始化外设，在存储设备上找到OS，加载执行OS
  - Bootloader 的任务：
    - 初始化更多外设（显卡、磁盘控制器、文件系统驱动）
    - 找到操作系统内核镜像（如 Linux 的 vmlinuz）
    - 把内核加载到内存合适位置
    - 设置好内核参数（比如内核命令行、根文件系统路径）
    - 跳转到内核入口地址（`_start_`）
  - OS 内核启动：
    - 接管 CPU，切换到保护模式（或长模式）
    - 初始化虚拟内存管理、驱动、文件系统
    - 最终启动第一个用户进程（Linux 的 `init` / `systemd`）。

#note(subname: [BIOS和UEFI])[
  - MBR（Master Boot Record，主引导记录）
    - 位置：磁盘的第一个扇区（LBA 0，大小 512 字节）
    - 内容：
      - Bootloader 第一阶段代码（446B 左右）
      - 分区表（64B，描述磁盘最多 4 个主分区）
      - 结束标志 `0x55AA`（2B）
    - 作用：
      - 当 BIOS 确定要从硬盘启动时，会把磁盘 0 扇区的 512B 读到内存 `0x7C00`，并跳转执行
      - 这段小代码会进一步加载更完整的 Bootloader（例如 GRUB）
  - BIOS（Basic Input/Output System）
    - 最传统的 PC 启动固件，存放在主板的 ROM/Flash 里
    - 工作流程：
      - 上电自检(POST)：检测 CPU、内存、显卡、键盘
      - 初始化外设：显卡模式、磁盘控制器、中断向量表
      - 选择启动设备（根据启动顺序设置）
      - 加载MBR：从启动设备读取 0 扇区到内存 `0x7C00` 并执行
    - 特点：
      - 运行在实模式 (real mode)，只能访问 1MB 内存空间
      - 接口老旧（基于中断调用，如 `INT 13h` 读磁盘）
  - UEFI（Unified Extensible Firmware Interface）
    - BIOS 的现代替代品，由 Intel 主导发展
    - 改进点：
      - 运行在保护模式/长模式，可直接用 32/64 位指令，突破 BIOS 1MB 限制。
      - 使用 GPT (GUID Partition Table) 替代 MBR：
        - 理论上支持无限分区（常见 128 个）
        - 支持大于 2TB 的磁盘
      - 模块化：UEFI 是一个小型操作系统，提供驱动、网络启动、图形界面
      - Bootloader 直接是一个 `.efi` 可执行文件，存放在 EFI 分区（FAT32 格式）
]

#note(subname: [小结])[
  - 操作系统的启动过程
    - CPU、主板和外设初始化
    - 多阶段的OS启动
  - 操作系统启动过程的多阶段形成一个功能不断增强的执行环境
]

== 实践：裸机程序 -- LibOS

=== 实验目标和思路

*LibOS的实验目标*

裸机程序（Bare Metal Program ）：与操作系统无关的OS类型的程序
- 建立应用程序的执行环境
  - 让应用与硬件隔离
  - 简化应用访问硬件的难度和复杂性
- *执行环境(Execution Environment)*：负责给在其上执行的软件提供相应的功能与资源的多层次软硬件系统

*LibOS总体思路*
- 编译：通过设置编译器支持编译裸机程序
- 构造：建立裸机程序的栈和SBI（Supervisor Binary Interface）服务请求接口
- 运行：OS的起始地址和执行环境初始化

=== 实验要求

*理解LibOS的执行过程*
- 会编写/编译/运行裸机程序
- 懂基于裸机程序的函数调用
- 能看懂汇编代码伪代码
- 能看懂内嵌汇编代码
- 初步理解SBI调用
*掌握基本概念*
- ABI: Application Binary Interface
- SBI: Supervisor Binary Interface
#note(subname: [API和ABI])[

]
*分析执行细节*
- 在机器级层面理解函数
  - 寄存器（registers）
  - 函数调用/返回(call/return)
  - 函数进入/离开(enter/exit)
  - 函数序言/收尾(prologue/epilogue)
OS不总是软件的最底层

=== 内存布局

bss段
- bss段（bss segment）通常是指用来存放程序中未初始化的全局变量的一块内存区域
- bss是英文Block Started by Symbol的简称
- bss段属于静态内存分配
data段
- 数据段（data segment）通常是指用来存放程序中已初始化的全局变量的一块内存区域
- 数据段属于静态内存分配
text段
- 代码段（code segment/text segment）是指存放执行代码的内存区域
- 这部分区域的大小确定，通常属于只读
- 在代码段中，也有可能包含一些只读的常数变量(?)
堆（heap）
- 堆是用于动态分配的内存段，可动态扩张或缩减
- 程序调用malloc等函数新分配的内存被动态添加到堆上
- 调用free等函数释放的内存从堆中被剔除
栈(stack)
- 栈又称堆栈，是用户存放程序临时创建的局部变量
- 函数被调用时，其参数和函数的返回值也会放到栈中
- 由于栈的先进后出特点，所以栈特别方便用来保存/恢复当前执行状态
- 可以把堆栈看成一个寄存和交换临时数据的内存区
OS编程与应用编程的一个显著区别是，OS编程需要理解栈上的物理内存结构和机器级内容（相关寄存器和指令）。

