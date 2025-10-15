#import "@preview/scripst:1.1.1": *

= 基于特权级的隔离与批处理

== 从OS角度看计算机系统

#note(subname: [问题])[
  - 什么是计算机系统的层次结构？
    - 硬件层
      - 最底层：CPU、内存、I/O 设备
      - 提供最基础的算力和存储能力
    - 操作系统 (OS) 层
      - 在硬件之上运行，管理 CPU、内存和设备
      - 提供抽象（文件、进程、线程、虚拟内存、网络接口等）
    - 系统库 / 运行时层
      - 标准库（libc、Rust std 等），把 OS 接口打包成更好用的 API
      - 运行时（如 JVM、.NET CLR）也属于这一层
    - 应用程序层
      - 用户真正编写和运行的程序
      - 通过系统调用 / 库函数与操作系统交互
  - 层次结构中相邻层次间有什么区别？
    - 功能：下层提供抽象和服务，上层利用这些服务实现更复杂的功能
    - 访问方式：上层不能直接操作下层，只能通过规定好的接口（API/ABI/SBI）
    - 特权性：越往下的层次，越接近硬件，权限越高
  - 层次结构中相邻层次间的边界是什么？
    - 硬件 vs. 软件
      - 边界是*指令集架构 (ISA)*
      - ISA 定义了软件能用哪些指令、寄存器、内存访问方式
      - 不同 CPU 架构（x86, ARM, RISC-V）就是不同的 ISA
    - 操作系统 vs. 应用程序
      - 边界是*系统调用接口 (System Call Interface, SCI)*
      - 应用程序通过 `syscall/ecall` 进入内核，请求服务（如读文件、开线程）
      - OS 内核则在特权态执行，直接管理硬件
]

=== OS与硬件的关系

*计算机系统*
- 计算机系统（computer architecture）是一种抽象层次的设计，用于实现可有效使用现有制造技术的信息处理应用。
*计算机系统抽象层次*
- 硬件 支持 OS 支持 应用
  - 操作系统位于硬件（HW）和应用（APP）之间
  - 只有理解OS与HW/APP的关系，才能更好掌握OS
*指令集：软硬件接口*
- 硬件与OS的边界：指令集+寄存器
- OS是对硬件的虚拟与抽象
*RISC-V处理器架构*

#note(subname: [RISC-V 处理器内部架构图])[

  + *接口层 (左边灰色方块)*
    - *Instruction Interface*
      - 指令接口，从内存中取指令（通过总线或缓存）。
      - CPU 每一条执行的机器码指令就是从这里取来的。
    - *Data Interface*
      - 数据接口，用来访问主存或外设数据。
      - 比如执行 `lw`（load word）时，会通过数据接口访问内存。
    - *Debug Unit*
      - 调试单元，支持调试器 (GDB/JTAG) 与 CPU 通信。
      - 可用于设置断点、单步运行、读取寄存器状态。
    - *Configurable / Optional Unit*
      - 可配置接口和可选单元，用来扩展自定义指令或加速器。
      - RISC-V 的开放性在这里体现：用户可加定制逻辑。
  + *核心状态部件 (中间蓝色方块)*
    - *CPU State*
      - 记录当前 CPU 的运行状态（程序计数器 PC、模式位等）。
    - *Register File*
      - 通用寄存器组（RISC-V 有 32 个 64 位寄存器，如 `x0-x31`）。
      - 指令的操作数和结果会保存在寄存器里，比内存快得多。
    - *Instruction Cache (I-Cache)*
      - 指令缓存，减少从主存取指的延迟。
  + *流水线 (Execution Pipeline)*

    RISC-V 是一个典型的 *流水线 CPU*，每条指令经过一系列阶段：

    1. *Fetch*
      - 取指，从指令缓存或内存中拿到机器码。
    2. *Pre-Decode*
      - 预解码，初步识别指令类型。
    3. *Decode/Optimize*
      - 解码，把机器码翻译成内部控制信号。
      - 同时进行一些调度、优化（比如乱序执行的准备）。
    4. *Execute*
      - 在 ALU（算术逻辑单元）里执行运算。
      - 比如 `add x1, x2, x3` 就在这里做整数加法。
    5. *Memory Access*
      - 对需要访存的指令，在这里访问数据缓存 (D-Cache) 或内存。
    6. *Write Back*
      - 把运算/访存结果写回寄存器文件。


  + *性能优化单元 (右上角黄色方块)*

    - *Branch Predictor*
      - 分支预测器，用来预测分支指令（如 `if/else`、循环跳转）的走向。
      - 避免流水线停顿，提高性能。
    - *Data Cache (D-Cache)*
      - 数据缓存，加速访存。
      - 比如执行 `lw/sw` 时，先查缓存，不命中再去内存。


  *整体工作流程*
  1. *取指*：Instruction Interface → I-Cache → Fetch。
  2. *解码/执行*：Decode → Execute → Memory Access。
  3. *访存/写回*：数据通过 D-Cache 访问，结果写回寄存器。
  4. *性能优化*：分支预测减少停顿，缓存减少访存延迟。

]

=== OS与应用程序的关系

*OS对应用程序执行的支持*
- *提供服务*
  - 系统调用(System Call)
    - 应用程序不能直接操作硬件（磁盘、网卡、内存）
    - 过系统调用（syscall/ecall）向 OS 请求服务
  - 地址空间布局
    - 每个应用都在自己的虚拟地址空间里运行
    - 通过 MMU (Memory Management Unit) + 页表，虚拟地址会被映射到物理内存
      - 应用之间互不干扰（隔离）
      - 程序可以认为自己有“独占”的线性内存空间

#note(subname: [RISC-V的中断过程响应过程中执行了什么操作])[
  当应用程序运行时，如果发生*中断/异常*（例如 I/O 完成、非法指令、系统调用），CPU 会立即*切换到 OS 内核*来处理。

  过程大致如下：

  + 陷入 (Trap Enter)
    - CPU 保存当前执行状态：
      - 当前 pc（保存在 `sepc` CSR）
      - 异常原因（写入 `scause` CSR）
      - 其它必要寄存器
    - 切换到更高特权级（User → Supervisor）
    - 跳转到 OS 设置的中断向量表入口 (`stvec`)
  + 处理中断/异常
    - OS 内核在中断处理函数里，根据 `scause` 分析原因
    - 如果是系统调用 (`ecall` from U-mode)：进入内核，执行对应的服务（如 `read`）
    - 如果是外设中断（如时钟中断）：触发调度器，可能切换进程
  + 恢复 (Trap Return)
    - OS 执行 `sret` 指令：
      - 恢复 `sepc` 里的 PC，返回到用户态
      - 恢复用户态寄存器/栈
    - 应用程序从“被打断的下一条指令”继续运行
  其中：
  - `ecall`：RISC-V 指令集 (ISA) 的特权指令，Environment Call（环境调用），触发一个 陷入 (trap)，从用户态进入更高特权级（通常是内核态 Supervisor mode）
  - `sret`：RISC-V 特权指令，Supervisor Return 指令，从内核态返回用户态
  - CSR（Control and Status Registers）：RISC-V 的控制状态寄存器，用于保存特权级状态、中断信息等
  - `sepc`：属于 CSR，Supervisor Exception Program Counter，当 trap（中断/异常/系统调用）发生时，CPU 自动把触发 trap 的指令地址 存到 `sepc`
  - `scause`：属于 CSR，Supervisor Cause Register，保存引发 trap 的原因（中断号或异常代码）
]

#newpara()

*OS为应用程序提供服务*
- 通过系统调用来提供服务
- 系统调用：OS/APP的接口（边界之一）

- *系统调用如何实现？*
  - 系统调用如何实现？系统调用（system call）是应用程序访问内核功能（文件、进程、网络等）的唯一正规途径。它的核心机制是 特权级切换：
    + 应用程序调用 C 库函数（如 `read`、`write`），这些函数不是直接操作硬件，而是封装了系统调用接口
    + C 库内部发出一条陷入指令（在 RISC-V 中是 `ecall`，在 x86 中是 `int 0x80` 或 `syscall`）
    + CPU 检测到 `ecall` → 触发 陷入 (trap)，硬件自动：
      - 保存当前 PC 到 `sepc`
      - 写入 `scause`，说明是系统调用
      - 跳转到内核事先设置好的入口（`stvec` 指向的 trap handler）
    + 内核 trap handler 解析系统调用号和参数（从寄存器里取出）
    + 内核执行对应的服务逻辑（比如读文件、调度进程）
    + 内核完成后，用 `sret` 返回 → 从 `sepc` 继续执行应用代码
    - 实现了*用户态 → 内核态 → 用户态*的受控切换
  - 调用`ssize_t read(int fd, void *buf, size_t count);`会发生什么？
    + 用户写下：`read(fd, buf, count);`
    + 编译后的程序实际上会调用 glibc 提供的封装函数 `read`
    + `glibc::read` 内部：
      - 把参数放入指定寄存器（RISC-V 里 `a0=fd`, `a1=buf`, `a2=count`）
      - 把系统调用号（`__NR_read`，比如 63）放到 `a7`
      - 执行 `ecall`
    + CPU 硬件陷入内核 → 内核 trap handler 看到 `a7=63`，知道这是 `sys_read`
    + 内核根据 `fd` 找到文件对象，从磁盘/缓存里读数据，写入 `buf` 指向的用户内存
    + 返回实际读取的字节数，放到 `a0`
    + CPU 执行 `sret` → 回到用户态，用户得到 `read()` 的返回值
  - 可以在应用程序中直接调用内核的函数吗？
    - 不可以，至少不能像调用普通函数那样直接调用。原因：
      - 地址空间隔离：用户程序根本看不到内核的物理地址，直接调用会导致非法访问（segfault）
      - 特权级限制：即使知道内核函数地址，用户态也没有权限执行那些特权指令或访问受保护资源
      - 必须通过*系统调用接口（ecall）*来间接使用内核的功能
  - 可以在内核中使用应用程序普通的函数调用吗？
    - 也不行，原因不同：
      - 应用程序代码不在内核可信的执行路径里，内核不能随便跳过去执行用户代码，否则安全性崩溃
      - 内核和应用处于不同的执行上下文，内核只会：
        - 读写应用内存（经过地址检查）
        - 调用自己的内核函数（比如 sys_read、schedule）
      - 内核不会像调用内部函数那样直接调用用户函数
    - 隔离
- *引入系统调用的目的是增强安全性和可靠性*
  - 函数调用的特征
    - 好处
      - 执行很快；
      - 灵活-易于传递和返回复杂数据类型；
      - 程序员熟悉的机制,...
    - 坏处：应用程序不可靠，可能有恶意，有崩溃的风险

*进程的地址空间*
- 进程的*地址空间*（memory layout）是界定了OS/APP的*边界*
  - 用户空间 (User Space)
    - 每个应用程序都有自己独立的用户空间地址，通常从 `0x00000000` 到某个高地址（例如 `0xBFFFFFFF`）
    - 应用程序的代码、数据、堆、栈都在这里
    - 应用只能在这里运行，不能直接操作硬件或访问内核空间
  - 内核空间 (Kernel Space)
    - 系统中所有进程共享的高地址部分（如 `0xC0000000` 以上， `0xFFFFFFFF` 往下）
    - 内核代码、设备驱动、内核数据结构、页表、I/O 缓冲区都在这里
    - 只有在内核态时才能访问
- OS内核与应用进程的地址空间划分
  #figure(
    image("pic/2025-09-25-10-32-53.png", width: 80%),
    numbering: none,
  )
  - 1-3用户程序准备参数：把 `nbytes`、`&buffer`、`fd` 压入栈。
  - 4调用库函数 `read`
  - 5`read`（glibc 封装）会把这些参数放到寄存器，并设置系统调用号
  - 6是陷入指令`ecall`，从用户态进入内核态
  - CPU 硬件自动保存用户态的执行上下文（如 PC → `sepc`，原因码 → `scause`）
  - 7分派器根据系统调用号找到对应的内核函数，比如 `sys_read`
  - 8内核执行具体的操作：检查 fd，从文件系统 / 设备驱动读取数据，写入用户缓冲区
  - 内核完成后，将返回值写到寄存器 `a0`
  - 9执行 `sret`，恢复到用户态
  - 10应用程序从 `read` 调用返回，继续执行
  - 系统调用用软中断实现

=== 隔离机制

*隔离要解决的问题*
- 防止程序 X 破坏或监视程序 Y
  - 读/写内存，使用 100％的 CPU，更改文件描述符
- 防止进程干扰操作系统
- 防止恶意程序、病毒、木马和 bug
  - 错误的过程可能会试图欺骗硬件或内核
*隔离*（Isolation）
- 指操作系统通过软硬件机制确保不同的进程、用户或虚拟机相互独立运行，避免彼此之间在执行、数据或资源使用上的干扰或未经授权的访问。
- 隔离的本质
  - 不同实体间具备交换或共享信息、资源的情况下，如何确保彼此之间的安全和独立运行
- 隔离并不意味着不要共享
*隔离边界*：隔离需要建立边界（boundary）
- 边界决定了各自的势力范围
  - 跨界即有风险的共享资源
- 强制隔离
  - 避免有问题的单元对整个系统的安全影响
- 隔离的单位
  - 通常是运行的程序
*隔离方法*：隔离的方法分类
- 基于软件的隔离
- 基于硬件的隔离
- 基于网络的隔离
#three-line-table[
  | 属性	| 描述 |
  | ---- | ---- |
  | 地址空间隔离（Address Space Isolation） | 页表。进程只能访问自己的内存空间，不能直接访问其他进程的地址空间。如使用虚拟内存实现隔离。 |
  | 文件系统隔离（File System Isolation） | 进程或容器只能访问自己的文件系统，不能访问其他进程的文件。例如，Linux 的 chroot 机制或容器的 OverlayFS。 |
  | 用户身份隔离(User Isolation) | 通过用户权限控制（如 UNIX 的 UID/GID）确保不同用户之间的资源访问受到限制。 |
  | 进程隔离（Process Isolation） | 进程之间通过进程表和内存管理保持独立，防止数据泄露和未授权访问。 |
  | 网络隔离（Network Isolation） | 通过防火墙、虚拟局域网（VLAN）或网络命名空间（Linux Namespace）限制不同进程、容器或 VM 之间的网络访问。 |
  | 计算资源隔离（Compute Resource Isolation） | 通过 CPU 亲和性（CPU Affinity）、cgroups（Control Groups）等技术限制进程或容器的 CPU、内存、磁盘 I/O 使用。 |
  | 时间隔离（Temporal Isolation） | 时钟中断。在实时系统或云计算环境中，确保任务获得预期的 CPU 时间片，避免一个任务长期占用 CPU 而影响其他任务。 |
]
- 对数据的隔离：*地址空间*
  - 用户地址空间 vs 内核地址空间
- 对控制的隔离：*特权级机制*
  - 用户态 vs 内核态
- 对时间的隔离：*时钟中断处理*
  - 随时打断正在执行的用户态App
- 对破坏隔离的处理：*异常处理*
  - OS在内核态及时处理用户态App的异常行为

- *数据隔离：地址空间*
  - 地址空间 address spaces
    - 一个程序仅寻址其自己的内存
    - 若无许可，则每个程序无法访问不属于自己的内存
  - 虚拟内存需要解决的问题
    - 读写内存的安全性问题
    - 进程间的安全问题
    - 内存空间利用率的问题
    - 内存读写的效率问题
  #figure(
    image("pic/2025-09-25-10-48-24.png", width: 80%),
    numbering: none,
  )
- *控制隔离：特权模式*
  - 特权模式是 CPU 提供的一种机制，它将 CPU 的执行权限划分为不同的级别，防止低权限代码访问或修改高权限的系统资源。
  - CPU 硬件中的特权模式
    - *保护操作系统内核*，防止应用直接访问关键数据或执行特权指令
    - *防止应用恶意或错误访问硬件状态*：控制寄存器、内存管理单元
    - *提供受控的系统调用接口*：应用可受限制地请求操作系统服务
  - CPU 硬件支持不同的*特权模式*
    - *Kernel Mode（内核态） vs User Mode（用户态）*
    - 内核态可以执行用户态无法执行的特权操作
      - 访问外设
      - 配置地址空间（虚拟内存）
      - 读/写特殊系统级寄存器
    - OS内核运行在*内核态*
    - 应用程序运行在*用户态*
    - 每个微处理器都有类似的用户/内核模式标志
- *时间隔离：时钟中断 --v.s.-- 控制隔离：异常和陷入*
  - CPU 硬件支持中断/异常的处理
    - 异常(Exception）： CPU 执行指令时*检测到错误*（如除零错误、缺页异常），立即触发异常处理例程
      - 异常是同步发生，是由由程序指令直接触发的错误或异常情况
    - 中断(Interrupt）： 是一种用于处理*外部或内部事件*的机制。当中断发生时，CPU 暂停当前执行的指令流，转而执行相应的中断处理例程
      - 时钟中断：定时器超时产生的中断，可控制CPU时间片
        - Timer 可以稳定定时地产生中断
          - 防止应用程序死占着 CPU 不放
          - 让OS内核能周期性地进行资源管理
      - 中断是异步发生，由外部设备或异步事件触发，而非程序主动调用，这使得它们与当前指令流无直接关系
    - 陷入(Trap）： 也称*系统调用(Syscall)*，进程*主动*请求操作系统服务，需要从用户模式切换到内核模式
      - 陷入是同步触发的，因为它是程序主动发起的
  - *中断处理例程*（interrupt handle）：硬件中断/异常的处理程序
    + I/O 设备通过向处理器芯片的一个引脚发信号，并将异常号放到系统总线上，以触发中断；
    + 在当前指令执行完后，处理器从系统总线读取异常号，保存现场，切换到*内核态*；
    + 调用中断处理例程，当中断处理程序完成后，它将控制返回给下一条本来要执行的指令。
    - 触发中断
    - 保存现场，切换到内核态运行
    - 返回，恢复中断前下一条指令
  - *异常处理例程*
    - 根据异常编号去查询处理程序
    - 保存现场
    - 异常处理：杀死产生异常的程序；或者 重新执行异常指令
    - 恢复现场
  - *陷入/系统调用处理例程*
    - 查找系统调用程序
    - 用户态切换到内核态
    - 栈切换，上下文保存
      - 分为用户栈和内核栈
      - 内核栈负责系统调用，大多数时间是空的
    - 执行内核态
    - 返回用户态
  #three-line-table[
    | \ | 中断 | 异常 | 陷入/系统调用 |
    | ---- | ---- | ---- | ---- |
    | 发起者 | 外设、定时器 | 应用程序 | 应用程序 |
    | 触发机制 | 被动触发 | 内部异常、故障 | 自愿请求 |
    | 处理机制 | 持续，用户透明 | 杀死或重新执行 | 等待和持续 |
  ]

#note(subname: [小结])[
  - 计算机硬件与操作系统的关系：接口/边界
    - 指令集
  - 操作系统与应用程序的关系：接口/边界
    - 系统调用
  - 操作系统如何隔离与限制应用程序
    - 时间、空间、权限
]

== 从OS角度看RISC-V

#note(subname: [问题])[
  - RISC-V的各特权级的特征有什么异同？

    RISC-V 一共定义了四个特权级，但一般实现只用其中的 3 个：
    #three-line-table[
      | 特权级    | 简写                  | 特点          | 主要用途                                     |
      | ------ | ------------------- | ----------- | ---------------------------------------- |
      | M-mode | Machine mode        | 最高特权，直接接管硬件 | 固件、引导程序、SBI（Supervisor Binary Interface） |
      | S-mode | Supervisor mode     | 中等特权，控制资源   | 操作系统内核（进程管理、虚拟内存、文件系统）                   |
      | U-mode | User mode           | 最低特权        | 应用程序运行环境                                 |
      | H-mode | Hypervisor mode（可选） | 虚拟化支持       | 用于运行多个操作系统（类似 KVM/VMX）                   |
    ]
    - M态类似 BIOS/UEFI，负责初始化硬件，加载操作系统，内核panic时也会切到M态；M态有监控程序（Monitor），可以给机器加载镜像
    - S态是操作系统内核运行的地方，负责管理进程、内存、文件等
    - U态是用户应用程序运行的地方，权限最低，只能通过系统调用请求内核服务
  - 如何跨越特权级？

    RISC-V 的跨越特权级依靠*陷入 (trap) 机制*和*返回指令*：
    - 向下切换（进入内核态/更高特权）
      - 应用在 U-mode 调用 `ecall`（系统调用）。
      - 硬件保存上下文（PC → `sepc`，原因 → `scause`），切换到 S-mode，跳转到 `stvec` 指定的 trap handler。
    - 如果是硬件事件（如时钟中断），也会触发相应的陷入。
      - 向上返回（回到用户态/低特权）
      - 内核执行完后，用 `sret` 返回 U-mode。
      - 硬件恢复 `sepc` 指定的指令位置，继续执行用户代码。
    - M-mode 切换
      - 设备中断或异常时，如果配置了委托（delegation），M-mode 可以把异常/中断转交给 S-mode，否则自己处理。
      - M-mode 一般只负责底层初始化，运行时大部分工作交给 S-mode。
  - 各特权级的特有软件功能有哪些？

  不同特权级拥有不同的 寄存器集合和软件功能，分别支持不同的软件栈：
  - M-mode（机器模式）
    - 最高权限，可访问所有 CSR（控制寄存器）。
    - 典型功能：
      - 初始化 CPU、内存、外设（BootLoader）。
      - 设置中断委托（medeleg、mideleg）。
      - 提供 SBI（Supervisor Binary Interface），作为 S-mode 的硬件抽象层。
    - 软件示例：OpenSBI、固件（firmware）。
  - S-mode（监管模式）
    - 主要运行 操作系统内核。
    - 特有功能：
      - 虚拟内存管理：配置页表基址寄存器 satp，控制地址空间。
      - 系统调用处理：处理中断、异常、ecall。
      - 调度/资源管理：时钟中断驱动进程调度。
    - 软件示例：Linux 内核、内核态驱动。
  - U-mode（用户模式）
    - 运行 应用程序，权限最小。
    - 特有功能：
      - 只能执行非特权指令。
      - 只能访问用户态内存区域。
      - 发起系统调用时必须通过 ecall 陷入到内核。
    - 软件示例：用户应用程序（Rust/C 程序、Shell、浏览器等）。
]

=== 主流CPU比较

#note(subname: [本节主要目标])[
  - 了解 RISC-V 特权级和硬件隔离方式
  - 了解 RISC-V 的 M-Mode 和 S-Mode 的基本特征
  - 了解OS在 M-Mode 和 S-Mode 下如何访问和控制计算机系统
  - 了解不同软件如何在 M-Mode<–>S-Mode<–>U-Mode 之间进行切换
]

*主流CPU比较*
#figure(
  image("pic/2025-09-28-10-04-47.png", width: 80%),
  numbering: none,
)
- 由于兼容性和历史原因，导致x86和ARM的设计实现复杂
- RISC-V简洁/灵活/可扩展

=== RISC-V系统模式

==== 概述

*RISC-V 系统模式*与系统编程相关的RISC-V模式
#figure(
  image("pic/2025-09-28-10-13-27.png", width: 80%),
  numbering: none,
)
- ABI/SBI/HBI:Application/Supervisor/Hypervisor Bianry Interface
  - 应用程序二进制接口 ABI (Application Binary Interface)
    - 应用和 OS 之间的接口
    - 定义了函数调用规则、系统调用约定、寄存器传参规则
    - 例如：应用调用 read()，通过 ABI → 系统调用 → OS
  - 内核二进制接口 SBI (Supervisor Binary Interface)
    - OS 和 M-mode 软件（如 OpenSBI）之间的接口
    - S-mode 内核无法直接操作硬件（因为硬件通常只允许 M-mode 访问）
    - SBI 提供一套调用，比如：
      - `sbi_console_putchar` → 打印字符
      - `sbi_set_timer` → 设置定时器
    - SBI 提供了对 M-mode 的调用接口，屏蔽底层硬件细节。
  - 虚拟机监控器二进制接口 HBI (Hypervisor Binary Interface)
    - OS 和 Hypervisor 之间的接口
    - 用于管理虚拟机、虚拟 CPU、虚拟内存
- AEE/SEE/HEE:Application/Superv/Hyperv Execution Environment
  - 应用执行环境 AEE (Application Execution Environment)
    - 用户态执行环境，运行应用程序
    - 依赖 ABI（Application Binary Interface）
    - 例如：Linux 用户空间、glibc、Rust std
  - 内核执行环境 SEE (Supervisor Execution Environment)
    - 监管态执行环境，运行操作系统
    - 依赖 SBI（Supervisor Binary Interface）
    - 示例：Linux 内核、BSD 内核
  - 虚拟机监控器执行环境 HEE (Hypervisor Execution Environment)
    - 虚拟化执行环境，运行多个 OS
    - 依赖 HBI（Hypervisor Binary Interface）
    - 示例：KVM、Xen 在 RISC-V 上的实现

- HAL：Hardware Abstraction Layer
  - 硬件抽象层，把具体 CPU/SoC 的细节封装起来
  - 提供统一接口，让上层软件不用直接操作硬件寄存器
  - 在 RISC-V 中，HAL 往往由固件（M-mode 软件，比如 OpenSBI）来实现
- Hypervisor，虚拟机监视器（virtual machine monitor，VMM）

- *单应用场景* Bare Metal 应用
  - 不同软件层有清晰的特权级硬件隔离支持
  - 左侧的*单个应用程序*被编码在ABI上运行
  - ABI是用户级ISA(Instruction Set Architecture)和AEE交互的接口
  - ABI对应用程序隐藏了AEE的细节，使得AEE具有更大的灵活性
- *操作系统场景*
  - 中间加了一个*传统的操作系统*，可支持多个应用程序的多道运行
  - 每个应用程序通过*ABI*和OS进行通信
  - RISC-V操作系统通过*SBI*和*SEE*进行通信
  - *SBI*是OS内核与*SEE*交互的接口，支持OS的ISA
- *虚拟机场景*
  - 右侧是虚拟机场景，可支持多个操作系统
#note(subname: [RISC-V 三种典型系统模式总结])[
  - 左图（最简单的情况：Bare Metal 应用）
    - 结构：Application + ABI + AEE + HAL + Hardware
    - 含义：
      - 应用直接跑在硬件上，中间没有 OS
      - AEE = Application Execution Environment，就是应用自己的运行时环境
      - HAL = 硬件抽象层，提供基础的硬件访问封装
    - 例子：
      - 一个裸机程序（Bare Metal），比如 `Rust #![no_std]` 内核，直接跑在 RISC-V 开发板上
      - 没有 Linux，没有多任务，应用直接操作硬件
  - 中间（带操作系统）
    - 结构：Application + ABI + OS + SBI + SEE + HAL + Hardware
    - 含义：
      - 应用程序通过 ABI 调用操作系统提供的系统调用接口
      - OS（通常跑在 S-mode）提供进程管理、内存管理、文件系统等
      - OS 通过 SBI (Supervisor Binary Interface) 调用 M-mode 固件（如 OpenSBI）
      - SEE = Supervisor Execution Environment，也就是 OS 运行的环境
      - HAL 仍然在最底层，由 M-mode 管理
    - 例子：
      - Linux on RISC-V（最常见）
      - 应用 → 系统调用 → Linux 内核 → SBI → OpenSBI → 硬件
  - 右图（带 Hypervisor，虚拟化场景）
    - 结构：Application + ABI + OS + SBI + Hypervisor + HBI + HEE + HAL + Hardware
    - 含义：
      - 在前一种模式上，再加一层 Hypervisor（虚拟机监视器）
      - Hypervisor 运行在更高特权级（H-mode），为多个 OS 提供虚拟化支持
      - HBI = Hypervisor Binary Interface，是 OS 和 Hypervisor 的交互接口
      - HEE = Hypervisor Execution Environment，就是虚拟化执行环境
      - 每个虚拟机里都可以跑一个 OS（Linux/BSD）
    - 例子：
      - KVM on RISC-V
      - 可以在一台物理 RISC-V 机器上同时运行多个 Linux 虚拟机
]
- *应用场景*
  - M Mode：小型设备（蓝牙耳机等）
  - U+M Mode：嵌入式设备（电视遥控器、刷卡机等）
  - U+S+M Mode：手机
  - U+S+H+M Mode：数据中心服务器
- *控制权接管*
  - 特权级是为不同的软件栈部件提供的一种保护机制
  - 当处理器执行当前特权模式不允许的操作时将产生一个*异常*，这些异常通常会产生自陷（trap）导致*下层执行环境接管控制权*

#note(subname: [intel x86的特权级])[
  - Intel x86的特权级
    - 4个特权级：0-3
      - 0：内核态（Ring 0）
      - 1：驱动态（Ring 1）
      - 2：服务态（Ring 2）
      - 3：用户态（Ring 3）
    - Ring 0 拥有最高权限，能执行所有指令和访问所有资源
    - Ring 3 拥有最低权限，只能执行非特权指令，访问受限资源
    - Ring 1 和 Ring 2 很少使用，主要用于某些驱动或服务
    - 特权级切换通过中断、异常、系统调用等机制实现
    - x86 的复杂性导致了更多的安全漏洞和性能开销
    - Ring 0 被分为 root 和 non-root 两个子级别来区分虚拟机监控器和操作系统
]

==== 特权级

*多个特权级*
- 现代处理器一般具有多个特权级的模式（Mode）
- U：User | S: Supervisor | H: Hypervisor | M: Machine
*执行环境*
- #three-line-table[
    | 执行环境 | 编码 | 含义 | 跨越特权级 |
    | ---- | ---- | ---- | ---- |
    | APP | 00 | User/Application | `ecall` |
    | OS | 01 | Supervisor | `ecall` `sret` |
    | VMM | 10 | Hypervisor | --- |
    | BIOS | 11 | Machine | `ecall` `mret` |
  ]
- M, S, U 组合在一起的硬件系统适合运行类似UNIX的操作系统
*特权级的灵活组合*
- 随着应用的需求变化，需要灵活和可组合的硬件构造
- 所以就出现了上述4种模式，且模式间可以组合的灵活硬件设计
*用户态* U-Mode （User Mode，用户模式、用户态）
- 应用程序运行的用户态CPU执行模式
- 非特权级模式（Unprivileged Mode）：基本计算
- 不能执行特权指令，不能直接影响其他应用程序执行
*内核态* S-Mode（Supervisor Mode, Kernel Mode，内核态，内核模式）
- 操作系统运行的内核态CPU执行模式
- 在内核态的操作系统具有足够强大的硬件控制能力
- 特权级模式（Privileged Mode）：限制APP的执行与内存访问
- 能执行内核态特权指令，能直接影响应用程序执行
  - 依靠报错和异常来保护应用程序
*H-Mode* H-Mode(Hypervisor Mode, Virtual Machine Mode，虚拟机监控器)
- 虚拟机监控器运行的Hypervisor Mode CPU执行模式
- 特权级模式：限制OS访问的内存空间的访问范围和访问方式
- 可执行H-Mode特权指令，能直接影响OS执行
*M-Mode* M-Mode（Machine Mode, Physical Machine Mode）
- *Bootloader/BIOS运行*的Machine Mode CPU执行模式
- 特权级模式：*控制物理内存*，直接*关机*
- 能执行M-Mode特权指令，能直接影响上述其他软件的执行

==== CSR寄存器

*RISC-V CSR寄存器分类*
- *通用寄存器* `x0-x31`
  - 一般指令访问
  - 非特权指令可以使用的速度最快的存储单元
- *控制状态寄存器*(CSR：Control and Status Registers)
  - 通过*控制状态寄存器*指令访问，可以有4096个CSR
  - 运行在*用户态的应用程序*不能访问大部分的CSR寄存器
  - 运行在*内核态的操作系统*通过访问CSR寄存器控制计算机
*通过CSR寄存器实现的隔离* OS通过硬件隔离手段（三防）来保障计算机的安全可靠
- 设置 CSR(控制状态寄存器) 实现隔离
  - 控制：防止应用访问系统管控相关寄存器
    - *地址空间控制*寄存器：mstatus/sstatus CSR(中断及状态)
  - 时间：防止应用长期使用 100％的 CPU
    - *中断配置*寄存器：sstatus/stvec CSR（中断跳转地址）
  - 数据：防止应用破坏窃取数据
    - *地址空间配置*寄存器：sstatus/stvec/satp CSR （分页系统）
- CSR寄存器功能
  - 信息类：主要用于获取当前芯片id和cpu核id等信息
    - `misa`：表示支持的 ISA 特性（比如 RV64IMAC）
    - `mhartid`：当前 CPU 核 ID
    - `mvendorid`：当前 CPU 的厂商 ID
    - `marchid`：当前 CPU 的架构 ID
  - Trap#footnote[Risc-V中异常和中断统称Trap]设置：用于设置中断和异常相关寄存器
    - `mtvec`：Machine Trap Vector，M-Mode中断向量表地址
    - `stvec`：Supervisor Trap Vector，S-Mode中断向量表地址
  - Trap处理：用于处理中断和异常相关寄存器
    - `sepc`：Supervisor Exception Program Counter，异常程序计数器
    - `scause`：Supervisor Cause，异常原因寄存器
    - `sstatus`：Supervisor Status，状态寄存器
    - `sret`：Supervisor Return，异常返回指令，用来恢复`sepc`并回到用户态。
  - 内存保护：有效保护内存资源
    - `satp`：Supervisor Address Translation and Protection，地址空间标识符，控制虚拟内存和页表地址

=== RISC-V系统编程：用户态编程

*系统编程简述*
- 系统编程需要了解处理器的*特权级架构*，熟悉各个特权级能够访问的寄存器资源、内存资源和外设资源
- *编写内核级代码*，构造操作系统，支持应用程序执行
  - 内存管理 进程调度
  - 异常处理 中断处理
  - 系统调用 外设控制
- 系统编程通常*没有*广泛用户*编程库*和方便的动态*调试手段*的支持
- 本课程的系统编程主要集中在 RISC-V 的 S-Mode 和 U-Mode，涉及部分对M-Mode的理解
  #note(subname: [系统编程 vs 普通编程])[
    - 普通编程（用户态）
      - 写应用程序，比如编辑器、游戏、浏览器
      - 有丰富的标准库（glibc、Rust std）
      - 程序只运行在 U-Mode，不能直接访问硬件寄存器和设备
      - 开发者很少关心 CPU 内部细节
    - 系统编程（内核态）
      - 写操作系统、驱动、hypervisor
      - 直接控制硬件：内存管理单元（MMU）、时钟中断、磁盘控制器等
      - 通常没有完整的库支持，调试难度大（只能依赖串口/调试器）
      - 必须了解 CPU 特权级架构（RISC-V M/S/U）和 CSR 的用法
  ]

*RISC-V U-Mode编程：使用系统调用*
- U-Mode 下的应用程序不能够直接使用计算机的物理资源
- 环境调用异常：在执行 `ecall` 的时候发生，相当于系统调用
- 操作系统可以直接访问物理资源
- 如果应用程序需要使用硬件资源怎么办？
  - 在屏幕上打印 "hello world"
  - 从文件中读入数据
- 通过*系统调用*从操作系统中获得服务
*U-Mode编程第一个例子：“hello world”*
- 在#link("https://github.com/chyyuu/os_kernel_lab/tree/v4-illegal-priv-code-csr-in-u-mode-app-v2/os/src")[用户态打印 "hello world"] 的大致执行流
  #figure(
    image("pic/2025-09-28-21-14-16.png", width: 80%),
    numbering: none,
  )
- 启动执行流
  #figure(
    image("pic/2025-09-28-21-18-21.png", width: 80%),
    numbering: none,
  )
*U-Mode编程第二个例子：在用户态执行特权指令*
- 在用户态执行特权指令的启动与执行流程
  #figure(
    image("pic/2025-09-28-21-20-43.png", width: 80%),
    numbering: none,
  )
  当用户程序在 U-Mode 下尝试执行*特权指*（例如 `csrw` 写 CSR，或者 `mret`），会触发*非法指令异常*(Illegal Instruction Trap)
*特权操作*
- 特权操作：特权指令和CSR读写操作
- 指令非常少：
  - `mret` 机器模式返回
  - `sret` 监管者模式返回
  - `wfi` 等待中断 (wait for interupt)
  - `sfence.vma` 虚拟地址屏障(barrier)指令，用于虚拟内存无效和同步
- 很多其他的系统管理功能通过读写控制状态寄存器来实现#footnote[`fence.i`是i-cache屏障(barrier)指令，非特权指令，属于 “Zifencei”扩展规范，用于i-cache和d-cache一致性]

=== RISC-V系统编程：M-Mode编程

==== 中断机制和异常机制

*M-Mode编程*
- M-Mode是 RISC-V 中 hart（hardware thread）的*最高权限模式*
- M-Mode下，hart 对计算机系统的底层功能有*完全的使用权*
- M-Mode最重要的特性是*拦截和处理中断/异常*
  - *同步的异常*：执行期间产生，访问无效的寄存器地址，或执行无效操作码的指令
    - 暂停CPU的流水线，保存现场，转到异常处理程序；对异常进行处理后，恢复现场，继续执行
  - *异步的中断*：指令流异步的外部事件，中断，如时钟中断
- RISC-V 要求实现*精确异常*：保证异常之前的所有指令都完整执行，后续指令都没有开始执行
*中断/异常的硬件响应*
- 硬件
  - 设置中断标记
  - 依据*中断向量*调用相应*中断服务*
- 软件
  - 保存当前处理状态
  - 执行中断程序
  - 清除中断标记
    - 尽可能早、保证安全
    - 有优先级
  - 恢复之前的保存状态
- 中断向量表：中断--中断服务，异常--异常服务，系统调用
  - 每个中断/异常都有一个编号（Cause ID）
  - OS 或固件会建立一个 向量表 (vector table)：编号 → 处理函数
  - 常见映射：
    - 中断：时钟中断、UART 中断、磁盘中断
    - 异常：缺页异常、非法指令、环境调用 (`ecall`)
*中断/异常开销*
- *Trap 分派开销*：建立中断/异常/系统调用号与对应服务的开销
- *堆栈切换*：内核堆栈的建立
- *参数验证*：验证系统调用参数
- *数据拷贝*：内核态数据拷贝到用户态
- *TLB/Cache 刷新*：内存状态改变（Cache/TLB 刷新的开销）
#note(subname: [组成原理的回顾])[
  - *Cache（高速缓存）*
    - 作用：解决*CPU 与内存速度差距大*的矛盾
    - 原理：把经常访问的数据（指令/数据）放在更靠近 CPU 的高速存储器里（L1/L2/L3 Cache）
    - 特点：
      - 命中（Hit）：CPU 访问的数据在 Cache 里 → 速度快（纳秒级）
      - 未命中（Miss）：需要去主存（DRAM）里取 → 速度慢（百纳秒）
    - 影响：
      - Cache 命中率越高，CPU 性能越好
      - 上下文切换、地址空间切换可能导致 Cache 失效（需要重新加载）
  - *TLB（Translation Lookaside Buffer，快表）*
    - 作用：加速*虚拟地址 → 物理地址*的转换
    - 背景：现代系统用*虚拟内存*，每次访问内存都需要经过 MMU（内存管理单元）查页表（多级页表查找很慢）
    - 原理：TLB 是一个*缓存页表项的小型 Cache*，存放最近使用的虚拟地址到物理地址的映射
    - 特点：
      - TLB 命中：直接得到物理地址 → 快
      - TLB Miss：需要查页表（多次内存访问） → 慢
    - 影响：
      - 上下文切换、地址空间切换可能导致 TLB 失效 (TLB flush)
      - OS 在切换进程时往往需要清空或刷新 TLB
]
#newpara()
*M-Mode的中断控制和状态寄存器*
- `mtvec`(MachineTrapVector)保存发生中断/异常时要跳转到的*中断处理例程入口地址*
- `mie`(Machine Interrupt Enable)中断*使能*寄存器
- `mip`(Machine Interrupt Pending)中断*请求*寄存器
- `mstatus`(Machine Status)保存全局中断以及其他的*状态*
- `mepc`(Machine Exception PC)指向*发生中断/异常时的指令*
- `mcause`(Machine Exception Cause)指示发生*中断/异常的种类*
- `mtval`(Machine Trap Value)保存陷入(trap)*附加信息*
- `mscratch`(Machine Scratch)它暂时存放一个字大小的*数据*
- *mstatus CSR寄存器*：mstatus(Machine Status)保存全局中断以及其他的状态
  - SIE控制S-Mode下全局中断，MIE控制M-Mode下全局中断。
  - SPIE、MPIE记录发生中断之前*MIE和SIE*的值。
  - SPP表示变化之前的特权级别是S-Mode还是U-Mode
  - MPP表示变化之前是S-Mode还是U-Mode还是M-Mode
  - PP：Previous Privilege
  #figure(
    image("pic/2025-09-29-01-23-54.png", width: 80%),
    numbering: none,
  )
- *mcause CSR寄存器*
  - 当发生异常时，mcause CSR中被写入一个指示导致异常的事件的代码，如果事件由中断引起，则置上`Interrupt`位，`Exception Code`字段包含指示最后一个异常的编码。
  #figure(
    image("pic/2025-09-29-01-25-15.png", width: 80%),
    numbering: none,
  )
*M-Mode时钟中断Timer*
- 中断是异步发生的
  - 来自处理器外部的 I/O 设备的信号
- Timer 可以稳定定时地产生中断
  - 防止应用程序死占着 CPU 不放, 让 OS Kernel 能得到执行权
  - 由*高特权模式下的软件*获得 CPU 控制权
  - 高特权模式下的软件可*授权*低特权模式软件处理中断

==== 中断/异常的硬件响应

*M-Mode中断的硬件响应过程*
- *异常/中断指令的PC*被保存在`mepc`中，PC设置为`mtvec`
  - 对于同步异常，`mepc`指向导致异常的指令；
  - 对于中断，指向中断处理后应该恢复执行的位置。
- 根据*异常/中断来源*设置 `mcause`，并将 `mtval` 设置为出错的地址或者其它适用于*特定异常的信息字*
- 把`mstatus[MIE位]`置零以*禁用中断*，并*保留先前MIE值*到MPIE中
  - SIE控制S模式下全局中断，MIE控制M模式下全局中断；
  - SPIE记录的是SIE中断之前的值，MPIE记录的是MIE中断之前的值
- *保留发生异常之前的权限模式*到 `mstatus` 的 MPP 域中，然后*更改权限模式*为M（MPP表示变化之前的特权级别是S、M or U模式）
- *跳转到* `mtvec` CSR设置的地址继续执行
*M-Mode中断分类*
- 通过 `mcause` 寄存器的不同位（`mie`）来获取中断的类型。
  - *软件中断*：通过向内存映射寄存器写入数据来触发，一个 hart 中断另外一个hart（处理器间中断）
  - *时钟中断*：hart 的时间计数器寄存器 `mtime` 大于时间比较寄存器 `mtimecmp`
  - *外部中断*：由中断控制器触发，大部分情况下的外设都会连到这个中断控制器
- RISC-V 的中断/异常
  - 通过 `mcause` 寄存器的不同位来获取*中断源/导致异常*的信息
  - #three-line-table[
      | 中断 | 中断ID | 中断含义 |
      | --- | --- | --- |
      | 1 | 1 | Supervisor software interrupt |
      | 1 | 3 | Machine software interrupt |
      | 1 | 5 | Supervisor timer interrupt |
      | 1 | 7 | Machine timer interrupt |
      | 1 | 9 | Supervisor external interrupt |
      | 1 | 11 | Machine external interrupt |
    ]
  - #three-line-table[
      | 异常 | 中断ID | 中断含义 |
      | --- | --- | --- |
      | 0 | 0 | Instruction address misaligned |
      | 0 | 1 | Instruction access fault |
      | 0 | 2 | Illegal instruction |
      | 0 | 3 | Breakpoint |
      | 0 | 4 | Load address misaligned |
      | 0 | 5 | Load access fault |
      | 0 | 6 | Store/AMO address misaligned |
      | 0 | 7 | Store/AMO access fault |
      | 0 | 8 | Environment call from U-mode |
      | 0 | 9 | Environment call from S-mode |
      | 0 | 11 | Environment call from M-mode |
      | 0 | 12 | Instruction page fault |
      | 0 | 13 | Load page fault |
      | 0 | 15 | Store page fault |
    ]

==== 中断/异常处理的控制权移交

*M-Mode中断/异常处理的控制权移交*
- 默认情况下，所有的中断/异常都使得控制权移交到 M-Mode的中断/异常处理例程
- M-Mode的*中断/异常处理例程*可以将中断/异常重新*导向 S-Mode*
- 但是这些额外的操作会*减慢中断/异常的处理速度*
- RISC-V 提供一种*中断/异常委托机制*，通过该机制可以选择性地将中断/异常交给 S-Mode处理，而*完全绕过 M-Mode*
*M-Mode中断/异常处理的控制权移交*
- *mideleg/medeleg* (Machine Interrupt/Exception *Delegation*）CSR 控制将哪些中断/异常委托给 S-Mode处理
- mideleg/medeleg 中的每个位对应一个中断/异常
  - 如 mideleg[5] 对应于 S-Mode的时钟中断，如果把它置位，S-Mode的时钟中断将会移交 S-Mode的中断/异常处理程序，而不是 M-Mode的中断/异常处理程序
  - 委托给 S-Mode的任何中断都可以被 S-Mode的软件屏蔽。
    - sie(Supervisor Interrupt Enable) 和 sip（Supervisor Interrupt Pending）CSR 是 S-Mode的控制状态寄存器
- *中断委托寄存器mideleg*
  - mideleg (Machine Interrupt Delegation）控制将哪些中断委托给 S 模式处理
  - mideleg 中的每个为对应一个中断/异常
    - mideleg[1]用于控制是否将*核间中断*交给s模式处理
    - mideleg[5]用于控制是否将*定时中断*交给s模式处理
    - mideleg[9]用于控制是否将*外部中断*交给s模式处理
- *异常委托寄存器medeleg*
  - medeleg (Machine Exception Delegation）控制将哪些异常委托给 S 模式处理
  - medeleg 中的每个为对应一个中断/异常
    - medeleg[1]用于控制是否将*指令获取错误异常*交给s模式处理
    - medeleg[12]用于控制是否将*指令页异常*交给s模式处理
    - medeleg[9]用于控制是否将*数据页异常*交给s模式处理

*中断/异常处理的控制权移交*
- 发生中断/异常时，处理器控制权*通常*不会移交给权限更低的模式
  - 例如 medeleg[15] 会把 store page fault 委托给 S-Mode
  - M-Mode下发生的异常总是在 M-Mode下处理
  - S-Mode下发生的异常总是在 M-Mode，或者在 S-Mode下处理
  - 上述两种模式发生的异常不会由 U-Mode处理

#note(subname: [思考题])[
  - 如何通过断点异常来实现调试器的断点调试功能？
    - 假设我们有一个被调试的用户程序（U-Mode），我们希望在某一行代码执行时中断：
    - (1) 插入断点指令：调试器在目标地址（例如函数入口或某一语句）处：
      - 保存原始指令；
      - 写入一条 `ebreak` 指令。
      当程序运行到这里，`ebreak` 被执行：
      - → 硬件触发 Breakpoint Exception
      - → 控制权转移到 M-Mode 或 S-Mode trap handler（取决于是否委托）。
    - (2) Trap Handler 做的事情
      - 保存程序上下文（寄存器、状态等）；
      - 判断异常类型（`mcause == Breakpoint`）；
      - 将控制权转移到 调试器（debug monitor）；
      - 调试器打印状态（寄存器内容、内存、PC、堆栈），等待用户操作。
    - (3) 恢复执行
      - 当用户输入“继续运行（continue）”：
      - 调试器恢复断点位置的原始指令；
      - 调整 `mepc` 指向断点地址；
      - 使用 `mret/sret` 返回执行。
  - 如何实现单步跟踪？
    - 调试器从当前 `mepc` 读取下一条将执行的指令；
    - 在 下一条指令地址 上临时插入一个 `ebreak`；
    - 恢复当前断点位置的原始指令；
    - 使用 `mret` 返回执行；
    - 执行完一条指令后，再次触发 `ebreak`；
    - 调试器再次进入 trap，用户看到“下一步执行状态”。
]

=== RISC-V系统编程：内核编程

==== 中断/异常机制

*S-Mode的中断控制和状态寄存器*
- `stvec`(SupervisorTrapVector)保存发生中断/异常时要跳转到的地址
- `sie`(Supervisor Interrupt Enable)中断使能寄存器
- `sip`(Supervisor Interrupt Pending)中断请求寄存器
- `sstatus`(Supervisor Status)保存全局中断以及其他的状态
- `sepc`(Supervisor Exception PC)指向发生中断/异常时的指令
- `scause`(Supervisor Exception Cause)指示发生中断/异常的种类
- `stval`(Supervisor Trap Value)保存陷入(trap)附加信息
- `sscratch`(Supervisor Scratch)不同mode交换数据中转站
- *sstatus寄存器*：sstatus的SIE和SPIE位分别保存了当前的和中断/异常发生之前的中断使能状态
  #figure(
    image("pic/2025-10-14-15-36-46.png", width: 80%),
    numbering: none,
  )
- *sie & sip 寄存器*是用于保存*待处理中断*和*中断使能*情况的CSR
  - `sie` （supervisor interrupt-enabled register）
  - `sip` （supervisor interrupt-pending register）
  #figure(
    image("pic/2025-10-14-15-38-30.png", width: 80%),
    numbering: none,
  )
- *scause寄存器*：当发生异常时，CSR中被写入一个指示导致中断/异常的事件编号，记录在`Exception Code`字段中；如果事件由中断引起，则置`Interrupt`位。
  #figure(
    image("pic/2025-10-14-15-39-30.png", width: 80%),
    numbering: none,
  )
- *stvec 寄存器*：中断/异常向量（trap-vector）基地址寄存器stvec CSR用于配置*`trap_handler`地址*
  - 包括向量基址（BASE）和向量模式（MODE）：BASE 域中的值按 4 字节对齐
    - MODE = 0 表示一个`trap_handler`处理所有的中断/异常
    - MODE = 1 表示每个中断/异常有一个对应的`trap_handler`
  #figure(
    image("pic/2025-10-14-15-40-37.png", width: 80%),
    numbering: none,
  )

==== 中断/异常的处理

*S-Mode中断/异常的硬件响应*

*硬件执行内容*：hart 接受了中断/异常，并需要委派给 S-Mode，那么硬件会原子性的经历下面的状态转换
- *发生中断/异常的指令PC*被存入 `sepc`，且 PC 被设置为 `stvec`
- `scause` 设置中断/异常*类型*，`stval`被设置为出错的地址/异常*相关信息*
- 把`sstatus`中的 SIE 位置零，屏蔽中断，SIE位之前的值被保存在 SPIE 位中
- *发生例外前的特权模式*被保存在`sstatus`的 SPP（previous privilege）域，然后设置当前特权模式为S-Mode
- *跳转*到stvec CSR设置的地址继续执行

*S-Mode中断/异常的软件处理*
- 初始化
  - 编写中断/异常的处理例程（如`trap_handler`）
  - 设置`trap_handler`地址给`stvec`
- 软件执行
  - 处理器跳转到`trap_handler`
  - `trap_handler`处理中断/异常/系统调用等
  - 返回到之前的指令和之前的特权级继续执行

==== 虚存机制

*S-Mode虚拟内存系统*
- 虚拟地址将内存划分为*固定大小的页*来进行*地址转换*和*内容保护*
  - 虚拟地址分成*页号 (VPN)*和*页内偏移 (Page Offset)*，通过*页表 (Page Table)*把 VPN 翻译为物理页号 (PPN)
- `satp`（Supervisor Address Translation and Protection，监管者地址转换和保护）S模式控制状态寄存器控制分页。satp 有三个域：
  - MODE 域可以开启分页并选择页表级数
    - 0 → Bare（不开启分页）
    - 8 → Sv39（三层页表）
    - 9 → Sv48（四层页表）
    - 10 → Sv57（五层页表）
  - ASID（Address Space Identifier，地址空间标识符）域是可选的，避免了切换进程时将TLB刷新的问题，降低上下文切换的开销
  - PPN 字段保存了根页表的物理页号
  #figure(
    image("pic/2025-09-29-15-04-59.png", width: 80%),
    numbering: none,
  )
- 页表的基本作用
  - 页表就是一个“映射表”，把*虚拟页号 (VPN)*转换为*物理页号 (PPN)*
    - 每个进程有一张“根页表”（root page table）
    - 根页表的地址放在 `satp.PPN`
    - 页表可以多级嵌套，就像文件夹套文件夹

#note(subname: [32位与64位])[
  - 32位和64位指总线宽度
  - 32位系统的地址空间是4GB（$2^32$），64位系统的地址空间是16EB（$2^64$）
  - 64位每个指针占8字节，32位每个指针占4字节
  - 64位每个时钟周期可以处理更多的数据，寄存器更多，指令集更丰富
]

*S-Mode虚存机制*
- 计算机内存（RAM）是连续的一段物理地址，比如：
  ```
  物理地址：
  0x0000_0000  →  0xFFFF_FFFF
  ```
  如果操作系统允许应用程序直接访问这些物理地址，那不同程序会互相干扰、篡改数据、甚至崩溃。所以 OS 发明了一个“虚拟内存”的概念：
  - 每个程序都“看到”自己独立的一段地址空间（虚拟地址空间）
  - CPU 实际访问物理内存时，由硬件（MMU）根据页表(Page Table) 把虚拟地址 → 物理地址
- 虚拟内存的划分：页（Page）
  - 内存不是以字节为单位管理的，而是以页 (Page)为单位
    ```
    1 页 = 4 KB = 4096 字节 = 2^12 字节
    ```
    于是，虚拟地址就分成两部分：
    ```
    +---------------------+----------------+
    | 虚拟页号 (VPN)     | 页内偏移 (Offset) |
    +---------------------+----------------+
    ```
    - 页内偏移 (12 位)：页内第几个字节（0～4095）。
    - 虚拟页号 VPN：页的编号，用来查页表。
- 页表的存储结构：*页表*存在物理内存中，每个页表页大小固定*4 KB*
  - 一个页表页里面放很多*页表项 (PTE, Page Table Entry)*
  - 一个 PTE = 8 字节 = 64 位(bits)
  - 一页 4 KB ÷ 8 B = 512 个 PTE
  - 所以每一级页表最多能管理 512 个子节点，每级索引是 9 位
- 页表项 (PTE) 的结构
  - PTE 的基本结构包括：有效位、权限位、物理页号 (PPN)
    ```
    63        10  9   8  7 6 5 4 3 2 1 0 bit
    +-----------+---+---+---------------+
    | PPN (44)  |RSW| D | A | X W R V   |
    +-----------+---+---+---------------+
    ```
  - PPN (Physical Page Number, 44 bits) → 指向下一级页表，或直接指向物理页
  - 控制位 (低 10 bits)
    - V (Valid)：是否有效
    - R/W/X：可读/写/执行
    - A/D：访问过 / 被修改过
    - RSW：软件保留位（OS 自己用）
- 多级页表的组织方式
  - 以 Sv39 (三级页表) 为例，虚拟地址被拆成：
    ```
      38       30  29       21  20       12  11       0
    +------------+------------+------------+------------- +
    | VPN[2]     | VPN[1]     | VPN[0]     | Page Offset  |
    +------------+------------+------------+------------- +
    9 bits      9 bits      9 bits      12 bits
    ```
- RISC-V 64 支持以下虚拟地址转换方案：
  #three-line-table[
    | 模式 | 虚拟地址位宽 | 页表级数 | 每级索引位数 | 物理地址位宽 |
    | ---- | ---- | ---- | ---- | ---- |
    | Sv39 | 39 位 | 3 级 | 9-9-9 | 56 位 |
    | Sv48 | 48 位 | 4 级 | 9-9-9-9 | 56 位 |
    | Sv57 | 57 位 | 5 级 | 9-9-9-9-9 | 56 位 |
  ]
  - 不同的模式仅影响虚拟地址的解析，物理地址仍然受处理器实现的物理地址宽度（通常为 56 位）
  - 地址偏离量：页内偏移，页表项索引
  - 44位PPN+12位页内偏移$->$56位物理地址
  - 每一页$2^12=4096$字节，每级页表有$2^9=512$个页表项
- 通过`satp` CSR建立页表基址
- 建立OS和APP的页表
- 处理内存访问异常
  #figure(
    image("pic/2025-10-15-22-45-59.png", width: 80%),
    numbering: none,
  )

*S-Mode虚存的地址转换*
- 读取 satp CSR
  - satp.PPN 给出了*L2页表基地址的物理页号*（Physical Page Number, PPN）
  - satp.MODE（4 bits）：8（Sv39）、9（Sv48）、10（Sv57）
    ```
    L2页表基地址 = PPN × 4 KiB
    ```
- 三级地址翻译步骤：
  - 假设：
    - `satp.PPN = 0x12345`
    - `VA = 0x0000_0987_6543_21`
    - `VPN[2]=0x026(9 bits) VPN[1]=0x03B(9 bits) VPN[0]=0x094(9 bits) Page Offset = 0x321`
  - `VPN[2] = VA [38:30]`，给出了L2页表的索引号
    ```
    L2页表的页表项(L2-PTE)地址= (satp.PPN × 4 KiB) + (VPN[2] × 8)
    L2-PTE.PPN = L1页表基址的物理页号

    L2 页表基地址 = satp.PPN × 4 KiB = 0x12345 × 0x1000 = 0x12345000
    索引号 = VPN[2] = 0x26
    该 PTE 的地址 = L2 基址 + VPN[2] × 8 = 0x12345000 + 0x26×8 = 0x12345130
    ```
    CPU 从这个地址取出 L2-PTE，假设读出的 L2-PTE 里：`PPN = 0x20000`
  - `VPN[1] = VA [29:21]`，给出了L1页表的索引号
    ```
    L1页表的页表项(L1-PTE)地址= (L2-PTE.PPN × 4 KiB) + (VPN[1] × 8)
    L1-PTE.PPN = L0页表基址的物理页号

    L1 页表基地址 = L2-PTE.PPN × 4 KiB = 0x20000 × 0x1000 = 0x20000000
    索引号 = VPN[1] = 0x3B
    该 PTE 的地址 = L1 基址 + VPN[1] × 8 = 0x20000000 + 0x3B×8 = 0x20000000 + 0x1D8 = 0x200001D8
    ```
    假设该 PTE 内容：`PPN = 0x30000`
  - `VPN[0] = VA [20:12]`，给出了L0页表的索引号
    ```
    L0页表的页表项(L0-PTE)地址= (L1-PTE.PPN × 4 KiB) + (VPN[0] × 8)
    L0-PTE.PPN = 最终物理地址的物理页号

    L0 页表基地址 = L1-PTE.PPN × 4 KiB = 0x30000 × 0x1000 = 0x30000000
    索引号 = VPN[0] = 0x094
    该 PTE 的地址 = L0 基址 + VPN[0] × 8 = 0x30000000 + 0x94×8 = 0x300004A0
    ```
    假设该 PTE 内容：`PPN = 0x40000`
  - 计算物理地址
    ```
    虚地址对应的最终物理地址 = (L0 PTE.PPN × 4 KiB) + Page Offset

    L0-PTE.PPN = 0x40000

    PA  = PPN × 4 KiB + Offset
        = 0x40000 × 0x1000 + 0x321
        = 0x40000000 + 0x321
        = 0x40000321
    ```

#note(subname: [小结])[
  - RISC-V 特权级
    - M-Mode, (H-Mode) S-Mode, U-Mode
  - RISC-V 的 M-Mode 和 S-Mode 的基本特征
    - 中断使能、委托和配置；页表使能和配置
  - 不同软件如何在 M-Mode<–>S-Mode<–>U-Mode 之间进行切换
    - `ecall, mret, sret`
  - 中断响应过程
  - 虚实地址转换过程
    - 手工计算地址转换
]

== 实践：批处理操作系统

详见：https://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/index.html

=== 实验目标

*批处理操作系统的结构*
#figure(
  image("pic/2025-10-14-14-50-32.png", width: 80%),
  numbering: none,
)

*批处理OS目标*
- 让APP与OS隔离
- 自动加载并运行多个程序
  - *批处理（batch）*

*实验要求*
- 理解运行其他软件的软件
- 理解特权级和特权级切换
- 理解系统调用

*总体思路*
- 编译：应用程序和内核*独立编译*，合并为一个镜像
- 构造：*系统调用*服务请求接口，*应用管理与初始化*
- 运行：OS一个一个地*执行应用*
- 运行：应用发出*系统调用*请求，OS完成*系统调用*
- 运行：应用与OS基于硬件特权级机制进行*特权级切换*

=== 实践步骤

*步骤*
- 构造包含OS和多个APP的*单一执行镜像*
- 通过批处理支持多个*APP的自动加载和运行*
- 利用硬件特权级机制实现对操作系统自身的*保护*
- 支持跨特权级的*系统调用*
- 实现*特权级的切换*
编译步骤
```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch2

cd os
make run
```
参考运行结果
```log
...
[kernel] num_app = 5
[kernel] app_0 [0x8020a038, 0x8020af90)
...
[kernel] Loading app_0
Hello, world!
[kernel] Application exited with code 0
[kernel] Loading app_1
...
[kernel] Panicked at src/batch.rs:58 All applications completed!
```

=== 软件架构

*软件架构变动*
- 构建应用：把多个应用合在一起与OS形成一个二进制镜像
  ```
  ├── os
  │   ├── build.rs(新增：生成 link_app.S 将应用作为一个数据段链接到内核)
  │   ├── Cargo.toml
  │   ├── Makefile(修改：构建内核之前先构建应用)
  │   └── src
  │       ├── link_app.S(构建产物，由 os/build.rs 输出)
  ```
- 改进OS：加载和执行程序、特权级上下文切换
  ```
  ├── os
  │   └── src
  │       ├── batch.rs(新增：实现了一个简单的批处理系统)
  │       ├── main.rs(修改：主函数中需要初始化 Trap 处理并加载和执行应用)
  │       └── trap(新增：Trap 相关子模块 trap)
  │           ├── context.rs(包含 Trap 上下文 TrapContext)
  │           ├── mod.rs(包含 Trap 处理入口 trap_handler)
  │           └── trap.S(包含 Trap 上下文保存与恢复的汇编代码)
  ```
- 系统调用
  ```
  ├── os
  │   └── src
  │       ├── syscall(新增：系统调用子模块 syscall)
  │       │   ├── fs.rs(包含文件 I/O 相关的 syscall)
  │       │   ├── mod.rs(提供 syscall 方法根据 syscall ID 进行分发处理)
  │       │   └── process.rs(包含任务处理相关的 syscall)
  ```
- 添加应用：批处理OS会按照文件名开头的数字顺序依次加载并运行它们
  ```
  └── user(新增：应用测例保存在 user 目录下)
    └── src
        ├── bin(基于用户库 user_lib 开发的应用，每个应用放在一个源文件中)
        │   ├── 00hello_world.rs # 显示字符串的应用
        │   ├── 01store_fault.rs # 非法写操作的应用
        │   ├── 02power.rs       # 计算与I/O频繁交替的应用
        │   ├── 03priv_inst.rs   # 执行特权指令的应用
        │   └── 04priv_csr.rs    # 执行CSR操作指令的应用
  ```
- 应用库和编译应用支持
  ```
  └── user(新增：应用测例保存在 user 目录下)
    └── src
        ├── console.rs              # 支持println!的相关函数与宏
        ├── lang_items.rs           # 实现panic_handler函数
        ├── lib.rs(用户库 user_lib)  # 应用调用函数的底层支撑库
        ├── linker.ld               # 应用的链接脚本
        └── syscall.rs(包含 syscall 方法生成实际用于系统调用的汇编指令，
                      各个具体的 syscall 都是通过 syscall 来实现的)
  ```

=== 相关硬件

*RISC-V陷入(trap)类指令*
- `ecall`： 随着 CPU 当前特权级而触发不同的陷入异常
- `ebreak`：触发断点陷入异常
*RISC-V特权指令*
- `sret`： 随着 CPU 当前特权级而触发不同的陷入异常

#figure(
  image("pic/2025-10-15-23-16-53.png", width: 40%),
  numbering: none,
)

=== 应用程序设计

==== 项目结构

*应用与底层支撑库分离*
```
└── user(应用程序和底层支撑库)
   └── src
      ├── bin(该目录放置基于用户库 user_lib 开发的应用)
      ├── lib.rs(用户库 user_lib)  # 库函数的底层支撑库
      ├── ......                  # 支撑库相关文件
      └── linker.ld               # 应用的链接脚本
```
#newpara()
*引入外部库*
```rust
#[macro_use]
extern crate user_lib;
```
#newpara()
*设计支撑库* 在`lib.rs`中我们定义了用户库的入口点 `_start` ：
```rust
#[no_mangle]
#[link_section = ".text.entry"]
pub extern "C" fn _start() -> ! {
    clear_bss();
    exit(main());
    panic!("unreachable after sys_exit!");
}
```

==== 内存布局

*设计支撑库*`user/src/linker.ld`
- 将程序的起始物理地址调整为 `0x80400000` ，应用程序都会被加载到这个物理地址上运行
- 将 `_start` 所在的 `.text.entry` 放在整个程序的开头，也就是说批处理系统只要在加载之后跳转到 `0x80400000` 就已经进入了用户库的入口点，并会在初始化之后跳转到应用程序主逻辑
- 提供了最终生成可执行文件的 `.bss` 段的起始和终止地址，方便 `clear_bss` 函数使用
其余的部分与之前相同

==== 系统调用

*应用程序的系统调用执行流*
- 在子模块`syscall`中，应用程序通过`ecall`调用批处理系统提供的接口
- `ecall`指令会触发 名为 Environment call from U-mode 的异常
- Trap 进入 S 模式执行批处理系统针对这个异常特别提供的服务代码
- `a0~a6`保存系统调用的参数，`a0`保存返回值，`a7`用来传递`syscall ID`
#figure(
  image("pic/2025-10-15-23-32-47.png", width: 40%),
  numbering: none,
)
*系统调用支撑库*
```rust
/// 功能：将内存中缓冲区中的数据写入文件。
/// 参数：`fd` 表示待写入文件的文件描述符；
///      `buf` 表示内存中缓冲区的起始地址；
///      `len` 表示内存中缓冲区的长度。
/// 返回值：返回成功写入的长度。
/// syscall ID：64
fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize;

/// 功能：退出应用程序并将返回值告知批处理系统。
/// 参数：`xstate` 表示应用程序的返回值。
/// 返回值：该系统调用不应该返回。
/// syscall ID：93
fn sys_exit(xstate: usize) -> !;
```
#newpara()
*系统调用参数传递*
```rust
fn syscall(id: usize, args: [usize; 3]) -> isize {
    let mut ret: isize;
    unsafe {
        asm!(
            "ecall",
            inlateout("x10") args[0] => ret, //第一个参数&返回值
            in("x11") args[1],               //第二个参数
            in("x12") args[2],               //第三个参数
            in("x17") id                     //syscall编号
        );
    }
    ret //返回值
}
```
#newpara()
*系统调用封装*
```rust
const SYSCALL_WRITE: usize = 64;
const SYSCALL_EXIT: usize = 93;
//对系统调用的封装
pub fn sys_write(fd: usize, buffer: &[u8]) -> isize {
    syscall(SYSCALL_WRITE, [fd, buffer.as_ptr() as usize, buffer.len()])
}
pub fn sys_exit(xstate: i32) -> isize {
    syscall(SYSCALL_EXIT, [xstate as usize, 0, 0])
}

pub fn write(fd: usize, buf: &[u8]) -> isize { sys_write(fd, buf) }

const STDOUT: usize = 1;

impl Write for Stdout {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        write(STDOUT, s.as_bytes());
        Ok(())
    }
}
```

=== 内核程序设计

==== 应用管理和加载

*将应用程序映像链接到内核*
```asm
# os/src/link_app.S 由脚本 os/build.rs 生成
    .section .data
    .global _num_app
_num_app:
    .quad 5
    .quad app_0_start
    ...
    .quad app_4_end
    .section .data
    .global app_0_start
    .global app_0_end
app_0_start:
    .incbin "../user/target/riscv64gc-unknown-none-elf/release/00hello_world.bin"
app_0_end:
```
#newpara()
*应用程序管理数据结构*
```rust
// os/src/batch.rs

struct AppManager {
    num_app: usize,
    current_app: usize,
    app_start: [usize; MAX_APP_NUM + 1],
}
```
#newpara()
*找到应用程序二进制码*
- 找到 `link_app.S` 中提供的符号 `_num_app`
```rust
lazy_static! {
    static ref APP_MANAGER: UPSafeCell<AppManager> = unsafe { UPSafeCell::new({
        extern "C" { fn _num_app(); }
        let num_app_ptr = _num_app as usize as *const usize;
        ...
        app_start[..=num_app].copy_from_slice(app_start_raw);
        AppManager {
            num_app,
            current_app: 0,
            app_start,
        }
```
```rust
unsafe fn load_app(&self, app_id: usize) {
    // clear icache
    asm!("fence.i");
    // clear app area
    ...
    let app_src = core::slice::from_raw_parts(
        self.app_start[app_id] as *const u8,
        self.app_start[app_id + 1] - self.app_start[app_id] );
    let app_dst = core::slice::from_raw_parts_mut(
        APP_BASE_ADDRESS as *mut u8,
        app_src.len() );
    app_dst.copy_from_slice(app_src);
}
```
- `fence.i`#footnote[`fence.i`是i-cache屏障(barrier)指令，非特权指令，属于 “Zifencei”扩展规范] ：用来清理 i-cache
- `fence.i` 是一条专门用于保持指令缓存一致性的指令，它通常用于程序需要在运行时修改代码或者生成新的代码片段的情境下，确保修改后的代码能够被正确地从内存中取出并执行
- 对于大多数普通应用程序，不涉及自修改代码或 JIT 编译的场景，`fence.i` 不会经常被使用
- CPU 对物理内存所做的缓存又分成d-cache和i-cache
- OS将修改会被 CPU 取指的内存区域，这会使得 i-cache 中含有与内存中不一致的内容
- OS在这里必须使用 fence.i 指令手动清空 i-cache ，让里面所有的内容全部失效，才能够*保证CPU访问内存数据和代码的正确性*

==== 特权级切换

*特权级切换相关CSR*
#three-line-table[
  | CSR 名 | 该 CSR 与 Trap 相关的功能 |
  | :--- | :--- |
  | `sstatus` | SPP 等字段给出 Trap 发生之前 CPU 的特权级（S/U）等 |
  | `sepc` | 记录 Trap 发生之前执行的最后一条指令的地址 |
  | `scause` | 描述 Trap 的原因 |
  | `stval` | 给出 Trap 附加信息（例如出错地址） |
  | `stvec` | 控制 Trap 处理代码的入口地址 |
]
#newpara()
*特权级切换后的硬件逻辑*
- `sstatus` 的 SPP 字段会被修改为 CPU 当前的特权级（U/S） -- 用于记录和恢复trap前的状态
- `sepc` 会被修改为产生 Trap 的指令地址
- `scause`/`stval` 分别会被修改成这次 Trap 的原因以及相关的附加信息 -- `scause`用于存储trap种类（中断、异常）和类型（时钟、外设、page fault；如果是page fault，`stval`记录对应的虚拟地址）
- CPU 将当前特权级设为 S，跳到 `stvec` 所设置的 Trap 处理入口地址
*特权级切换与用户栈和内核栈*
- 使用两个不同的栈？安全
```rust
const USER_STACK_SIZE: usize = 4096 * 2;
const KERNEL_STACK_SIZE: usize = 4096 * 2;

static KERNEL_STACK: KernelStack = KernelStack { data: [0; KERNEL_STACK_SIZE] };
static USER_STACK: UserStack = UserStack { data: [0; USER_STACK_SIZE] };
```
#newpara()
*特权级切换中的换栈*
```rust
impl UserStack {
    fn get_sp(&self) -> usize {
        self.data.as_ptr() as usize + USER_STACK_SIZE
    }
}
RegSP = USER_STACK.get_sp();
RegSP = KERNEL_STACK.get_sp();
```

==== Trap上下文

*Trap上下文数据结构*
```rust
#[repr(C)]
pub struct TrapContext {
    pub x: [usize; 32],
    pub sstatus: Sstatus,
    pub sepc: usize,
}
```
- 对于通用寄存器而言，应用程序/内核控制流运行在不同的特权级
- 进入 Trap 的时候，*硬件会立即覆盖掉* `scause/stval/sstatus/sepc`
*特权级切换后的Trap入口点*
```rust
pub fn init() {
    extern "C" { fn __alltraps(); }
    unsafe {
        stvec::write(__alltraps as usize, TrapMode::Direct);
    }
}
```
#newpara()
*系统调用过程中的Trap上下文处理*
- *应用程序*通过 `ecall` 进入到内核状态时，*操作系统*保存被打断的应用程序的 Trap 上下文
- *操作系统*根据Trap相关的CSR寄存器内容，完成系统调用服务的分发与处理
- *操作系统*完成系统调用后，恢复被打断的应用程序的Trap 上下文，通过`sret`指令让应用程序继续执行
*用户栈到内核栈的切换*
- `sscratch` CSR 重要的中转寄存器
  - 暂时保存内核栈的地址
  - 作为一个中转站让 `sp` （目前指向的用户栈的地址）的值可以暂时保存在 `sscratch`
  - 仅需一条 `csrrw sp, sscratch, sp // 交换对 sp 和 sscratch 两个寄存器内容`
  - 完成用户栈-->内核栈的切换
*保存Trap上下文中的通用寄存器*
- 保存通用寄存器的宏
```asm
# os/src/trap/trap.S
.macro SAVE_GP n
    sd x\n, \n*8(sp)
.endm
```

==== Trap处理流程

*Trap处理流程*
- Trap 处理的总体流程如下：
  - 首先通过 `__alltraps` 将 Trap 上下文保存在内核栈上
  - 然后跳转到 `trap_handler` 函数完成 Trap 分发及处理
```asm
__alltraps:
    csrrw sp, sscratch, sp
    # now sp->kernel stack, sscratch->user stack

    # allocate a TrapContext on kernel stack
    addi sp, sp, -34*8
```
#newpara()
*保存Trap上下文*
- 保存通用寄存器
  ```asm
  # save general-purpose registers
  sd x1, 1*8(sp)
  # skip sp(x2), we will save it later
  sd x3, 3*8(sp)
  # skip tp(x4), application does not use it
  # save x5~x31
  .set n, 5
  .rept 27
      SAVE_GP %n
      .set n, n+1
  .endr
  ```
- 保存 `sstatus` 和 `sepc`
  ```asm
  # we can use t0/t1/t2 freely, because they were saved on kernel stack
  csrr t0, sstatus
  csrr t1, sepc
  sd t0, 32*8(sp)
  sd t1, 33*8(sp)
  ```
- 保存 user SP
  ```asm
  # read user stack from sscratch and save it on the kernel stack
  csrr t2, sscratch
  sd t2, 2*8(sp)
  ```
  ```rust
  pub struct TrapContext {
      pub x: [usize; 32],
      pub sstatus: Sstatus,
      pub sepc: usize,
  }
  ```
*调用trap_handler*
```
# set input argument of trap_handler(cx: &mut TrapContext)
mv a0, sp
call trap_handler
```
让寄存器 `a0` 指向内核栈的栈指针也就是我们刚刚保存的 Trap 上下文的地址，这是由于我们接下来要调用 `trap_handler` 进行 Trap 处理，它的第一个参数 `cx` 由调用规范要从 `a0` 中获取。
#newpara()
*恢复Trap上下文*
- 大部分是保存寄存器的反向操作；
- 最后一步是`sret`指令 `//从内核态返回到用户态`
*`trap_handler`处理syscall*
```rust
#[no_mangle]
pub fn trap_handler(cx: &mut TrapContext) -> &mut TrapContext {
    let scause = scause::read();
    let stval = stval::read();
    match scause.cause() {
        Trap::Exception(Exception::UserEnvCall) => {
            cx.sepc += 4;
            cx.x[10] = syscall(cx.x[17], [cx.x[10], cx.x[11], cx.x[12]]) as usize;
        }
    ...
    }
    cx
}

pub fn sys_exit(xstate: i32) -> ! {
    println!("[kernel] Application exited with code {}", xstate);
    run_next_app()
}
```

==== 执行应用程序

*应用程序的执行时机*
- 当批处理操作系统初始化完成
- 某个应用程序运行结束或出错
*让应用程序执行*
- 从内核态切换到用户态
  - 准备好应用的上下文`Trap上下文`
  - 恢复应用的相关寄存器
  - 特别是应用用户栈指针和执行地址
  - *返回用户态让应用执行*
*返回用户态让应用执行*
- 从内核态切换到用户态
  - `sret`指令的硬件逻辑：
    - 恢复响应中断/异常
    - CPU Mode从S-Mode 回到U-Mode
    - `pc <-- spec` CSR
    - 继续运行
*切换到下一个应用程序*
- 调用 `run_next_app` 函数切换到下一个应用程序：
  - 构造应用程序开始执行所需的 Trap 上下文
  - 通过 `__restore` 函数，从刚构造的 Trap 上下文中，恢复应用程序执行的部分寄存器
  - 设置 `sepc` CSR的内容为应用程序入口点 `0x80400000`
  - 切换 `scratch` 和 `sp` 寄存器，设置 `sp` 指向应用程序用户栈
  - 执行 `sret` 从 S 特权级切换到 U 特权级
*构造Trap上下文*
```rust
impl TrapContext {
    pub fn set_sp(&mut self, sp: usize) { self.x[2] = sp; }
    pub fn app_init_context(entry: usize, sp: usize) -> Self {
        let mut sstatus = sstatus::read();
        sstatus.set_spp(SPP::User);
        let mut cx = Self {
            x: [0; 32],
            sstatus,
            sepc: entry,
        };
        cx.set_sp(sp);
        cx
```
#newpara()
*运行下一程序*
```rust
ub fn run_next_app() -> ! {
    ...
    unsafe {
        app_manager.load_app(current_app);
    }
    ...
    unsafe {
        __restore(KERNEL_STACK.push_context(
            TrapContext::app_init_context(APP_BASE_ADDRESS, USER_STACK.get_sp())
        ) as *const _ as usize);
    }
    panic!("Unreachable in batch::run_current_app!");
}
```
```asm
__restore:
    # case1: start running app by __restore
    # case2: back to U after handling trap
    mv sp, a0
    # now sp->kernel stack(after allocated), sscratch->user stack
    # restore sstatus/sepc
    ld t0, 32*8(sp)
    ld t1, 33*8(sp)
    ld t2, 2*8(sp)
    csrw sstatus, t0
    csrw sepc, t1
    csrw sscratch, t2
# restore general-purpuse registers except sp/tp
    ld x1, 1*8(sp)
    ld x3, 3*8(sp)
    .set n, 5
    .rept 27
        LOAD_GP %n
        .set n, n+1
    .endr
    # release TrapContext on kernel stack
    addi sp, sp, 34*8
    # now sp->kernel stack, sscratch->user stack
    csrrw sp, sscratch, sp
    sret
```

#note(subname: [小结])[
  - 编译过程
    - 应用、内核
  - 数据结构
    - `app_manager, TrapContext`
  - 系统调用执行过程
  - 第一次从内核态到用户态的切换过程
]
