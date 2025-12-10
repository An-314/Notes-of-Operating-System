#import "@preview/scripst:1.1.1": *

= 设备管理

== 设备接口

=== I/O子系统

*要解决的问题*
- 为何设备的差异性那么大？
- 为何要管理设备？
- 如何统一对设备的访问接口？
- 为何要对设备建立抽象？
- 如何感知设备的状态并管理设备？
- 如何提高 CPU 与设备的访问性能？
- 如何保证 I/O 操作的可靠性？

*内核 I/O 结构*

#figure(
  image("pic/2025-12-10-16-04-30.png", width: 80%),
  numbering: none,
)

*常见设备接口类型*

- 设备的发展历史
  - 简单设备：CPU 可通过 I/O 接口直接控制 I/O 设备
  - 多设备：CPU 与 I/O 设备之间增加了一层 I/O 控制器和总线 BUS
  - 支持中断的设备：提高 CPU 利用率
  - 高吞吐量设备：支持 DMA
  - 各种其他设备：GPU、声卡、智能网卡、RDMA
  - 连接方式：直连、（设备/中断）控制器、总线、分布式
- 常见设备：字符设备 块设备 网络设备
  - 字符设备：如GPIO（General Purpose Input/Output）, 键盘/鼠标, 串口等
    - GPIO LED light
    - 键盘
    - UART（Universal Asynchronous Receiver/Transmitter） 串口通信
  - 块设备：如: 磁盘驱动器、磁带驱动器、光驱等
    - 磁盘
  - 网络设备：如ethernet、wifi、bluetooth 等
    - 网卡

*设备访问特征*
- 字符设备
  - 以字节为单位顺序访问
  - I/O 命令：get()、put() 等
  - 通常使用文件访问接口和语义
- 块设备
  - 均匀的数据块访问
  - I/O 命令：原始 I/O 或文件系统接口、内存映射文件访问
  - 通常使用文件访问接口和语义
- 网络设备
  - 格式化报文交换
  - I/O 命令：send/receive 网络报文，通过网络接口支持多种网络协议
  - 通常使用 socket 访问接口和语义

=== 设备传输方式

- 程序控制 I/O(PIO, Programmed I/O)
- Interrupt based I/O
- 直接内存访问 (DMA)
  #figure(
    image("pic/2025-12-10-16-16-32.png", width: 80%),
    numbering: none,
  )

*程序控制 I/O(PIO, Programmed I/O)*
- Port-mapped 的 PIO(PMIO)：通过 CPU 的 in/out 指令
- Memory-mapped 的 PIO(MMIO)：通过 load/store 传输所有数据
- 硬件简单，编程容易
- 消耗的 CPU 时间和数据量成正比
- 适用于简单的、小型的设备 I/O
- I/O 设备通知 CPU：PIO 方式的轮询
  ```c
  while (!device.ready())
      ;
  data = device.read_port();   // 或者 mem[address]
  ```

*中断传输方式*
- I/O 设备想通知 CPU ，便会发出中断请求信号
- 可中断的设备和中断类型逐步增加
- 除了需要设置 CPU，还需设置中断控制器
- 编程比较麻烦
- CPU 利用率高
- 适用于比较复杂的 I/O 设备
- I/O 设备通知 CPU：中断方式的提醒
  #figure(
    image("pic/2025-12-10-16-17-27.png", width: 80%),
    numbering: none,
  )
  ```c
  // CPU 执行 I/O 请求
  device.start_io(cmd);

  // 等待中断（CPU 可以做别的事）

  // 中断发生
  interrupt_handler() {
      result = device.read_status();
      wake_up_waiting_process(result);
  }
  ```

*DMA 传输方式(DMA（Direct Memory Access）)*
- 设备控制器可直接访问系统总线
- 控制器直接与内存互相传输数据
- 除了需要设置 CPU，还需设置中断控制器
- 编程比较麻烦，需要 CPU 参与设置
- 设备传输数据不影响 CPU
- 适用于高吞吐量 I/O 设备
  ```c
  // CPU 初始化 DMA 传输
  dma.src = device_port;
  dma.dst = memory_addr;
  dma.len = size;
  dma.start();

  // CPU 可以去做别的事情

  // DMA 完成触发中断
  dma_interrupt_handler() {
      notify_process_done();
  }
  ```
  CPU 不参与数据搬运 → 高吞吐设备必备（磁盘、网卡、GPU）

*CPU 与设备的连接*
#figure(
  image("pic/2025-12-10-16-18-24.png", width: 80%),
  numbering: none,
)
- 轮询（Polling / Programmed I/O）
  - CPU 不停询问设备状态寄存器（Status Register）：
    ```
    loop:
        status = device.STATUS
        if status == READY:
            read/write data
    ```
- 中断方式（Interrupt-based I/O）
  - 设备控制器产生中断信号
  - 中断控制器转发给 CPU
  - CPU 触发中断处理程序（ISR）
- DMA 方式（Direct Memory Access）
  - CPU 给 DMA 控制器下命令：“从地址 A 的设备取 N 字节写到内存地址 B”
  - DMA 控制器自动完成传输
  - 完成后 DMA 产生一次中断通知 CPU

*读取磁盘数据的例子*
#figure(
  image("pic/2025-12-10-16-18-39.png", width: 80%),
  numbering: none,
)
- CPU 初始化磁盘 I/O 请求（PIO）
  - `disk_controller.start_read(LBA, buffer_addr, size)`
- 磁盘控制器开始从硬盘读数据
  - 磁头寻道 → 旋转到目标扇区 → 读数据到控制器缓存（内部 buffer）
- 磁盘控制器将数据传送给 DMA 控制器
  - DMA 接管数据传输
- DMA 控制器执行内存写入操作
  - DMA 按字节或按块：`memory[addr + i] = disk_buffer[i]`写到内存 X。
- DMA 完成传输 → 产生中断
  - 告诉 CPU：“数据已写入内存！”
- CPU 的 ISR（中断服务例程）运行
  - 记录 I/O 完成
  - 唤醒被阻塞的进程

*I/O 请求生存周期*
#figure(
  image("pic/2025-12-10-16-19-05.png", width: 80%),
  numbering: none,
)
- 用户线程发起 I/O（系统调用）
  - CPU 切入内核
- 内核 I/O 子系统处理请求
  - 检查是否能立即完成？
  - 是否请求已命中缓存？
  - 是否需要发起新的 I/O？
  - 如果需要发起设备 I/O —— 进入下一阶段。
- 设备驱动程序执行 I/O 命令
  - 选择 PIO / 中断 / DMA 方式
  - 命令设备控制器执行操作
  - 用户线程被挂起（阻塞）
- 硬件执行 I/O 操作
- 设备完成 → 产生中断
  - 设备控制器向 CPU 发 interrupt。
- 中断处理程序（ISR）运行
  - 保存/写回数据
  - 修改 I/O 状态为 “完成”
  - 唤醒阻塞的用户线程
- 系统调用返回到用户态
  - 用户线程继续运行，读取结果完成。

=== I/O执行模型

*I/O 接口的交互协议*
- 基于轮询的抽象设备接口：状态 命令 数据
  ```c
  while STATUS == BUSY {}; // 等待设备执行完毕
  DATA = data; // 把数据传给设备
  COMMAND = command; // 发命令给设备
  while STATUS == BUSY {}; // 等待设备执行完毕
  ```
- 基于中断的抽象设备接口：状态 命令 数据 中断
  ```c
  DATA = data; // 把数据传给设备
  COMMAND = command; // 发命令给设备
  do_otherwork(); // 做其它事情
  ··· // I/O设备完成I/O操作,并产生中断
  ··· // CPU执行被打断以响应中断
  trap_handler(); // 执行中断处理例程中的相关I/0中断处理
  restore_do_otherwork(); //恢复CPU之前被打断的执行
  ··· // 可继续进行I/0操作
  ```
*设备抽象*
- *基于文件的 I/O 设备抽象*
  - 访问接口：open/close/read/write
  - 特别的系统调用：ioctl ：input/output control
  - ioctl 系统调用很灵活，但太灵活了，请求码的定义无规律可循
  - ioctl 提供了一种强大但复杂的机制，用于执行特定于设备的操作，允许用户空间程序执行那些标准读写操作无法完成的任务。
  - 文件的接口太面向用户应用，不足覆盖到OS对设备进行管理的过程
- *基于流的 I/O 设备抽象*
  - 流是用户进程和设备或伪设备之间的全双工连接
  - 特别的系统调用：ioctl ：input/output control
  - ioctl 系统调用很灵活，但太灵活了，请求码的定义无规律可循
  - Dennis M. Ritchie 写出了“A Stream Input-Output System”，1984
  #figure(
    image("pic/2025-12-10-16-55-35.png", width: 80%),
    numbering: none,
  )
- *基于virtio的 I/O 设备抽象*
  - Rusty Russell 在 2008 年提出通用 I/O 设备抽象–virtio 规范
  - 虚拟机提供 virtio 设备的实现，virtio 设备有着统一的 virtio 接口
  - OS 只要能够实现这些通用的接口，就可管理和控制各种 virtio 设备
  #figure(
    image("pic/2025-12-10-16-56-04.png", width: 80%),
    numbering: none,
  )
*分类*
- 当一个用户进程发出一个 read I/O 系统调用时，主要经历两个阶段：
  - 等待数据准备好；
  - 把数据从内核拷贝到用户进程中
- 进程执行状态：阻塞/非阻塞：进程执行系统调用后会被阻塞/非阻塞
- 消息通信机制：
  - 同步：用户进程与操作系统之间的操作是经过双方协调的，步调一致的
  - 异步：用户进程与操作系统之间并不需要协调，都可以随意进行各自的操作
- I/O 模型分类
  - blocking I/O
  - nonblocking I/O
  - I/O multiplexing
  - signal driven I/O
  - asynchronous I/O

*阻塞 I/O*
#figure(
  image("pic/2025-12-10-16-57-49.png", width: 80%),
  numbering: none,
)
- 基于阻塞 I/O（blocking I/O）模型的文件读系统调用–read 的执行过程是：
  + 用户进程发出 read 系统调用；
  + 内核发现所需数据没在 I/O 缓冲区中，需要向磁盘驱动程序发出 I/O 操作，并让用户进程处于阻塞状态；
  + 磁盘驱动程序把数据从磁盘传到 I/O 缓冲区后，通知内核（一般通过中断机制），内核会把数据从 I/O 缓冲区拷贝到用户进程的 buffer 中，并唤醒用户进程（即用户进程处于就绪态）；
  + 内核从内核态返回到用户态进程，此时 read 系统调用完成。
- sys_read → 设备未准备好 → 进程阻塞；DMA 完成传输 → 中断通知 OS；内核复制数据 → 返回用户态

*非阻塞 I/O*
#figure(
  image("pic/2025-12-10-16-58-21.png", width: 80%),
  numbering: none,
)
- 基于非阻塞 IO（non-blocking I/O）模型的文件读系统调用–read 的执行过程：
  + 用户进程发出 read 系统调用；
  + 内核发现所需数据没在 I/O 缓冲区中，需要向磁盘驱动程序发出 I/O 操作，并不会让用户进程处于阻塞状态，而是立刻返回一个 error；
  + 用户进程判断结果是一个 error 时，它就知道数据还没有准备好，于是它可以再次发送 read 操作（这一步操作可以重复多次）；
  + 磁盘驱动程序把数据从磁盘传到 I/O 缓冲区后，通知内核（一般通过中断机制），内核在收到通知且再次收到了用户进程的 system call 后，会马上把数据从 I/O 缓冲区拷贝到用户进程的 buffer 中；
  + 内核从内核态返回到用户态的用户态进程，此时 read 系统调用完成。
- 所以，在非阻塞式 I/O 的特点是用户进程不会被内核阻塞，而是需要不断的主动询问内核所需数据准备好了没有
- 进程必须不断重复调用 read() 做轮询

*多路复用 I/O*
#figure(
  image("pic/2025-12-10-16-59-06.png", width: 80%),
  numbering: none,
)
- 多路复用 I/O（I/O multiplexing）的文件读系统调用–read 的执行过程：
  + 对应的 I/O 系统调用是 select 和 epoll 等，可有效处理大量并发的I/O操作；
  + 通过 select 或 epoll 系统调用，用户进程会被阻塞；当某个文件句柄或 socket 有数据到达了，select 或 epoll 系统调用就会返回到用户进程，用户进程再调用 read 系统调用，让内核将数据从内核的I/O 缓冲区拷贝到用户进程的 buffer 中。
- 阻塞于 select/epoll，而不是阻塞于 read
- 适用于高并发连接场景，如高性能服务器

*信号驱动 I/O*
#figure(
  image("pic/2025-12-10-16-59-28.png", width: 80%),
  numbering: none,
)
+ 当进程发出一个 read 系统调用时，会向内核注册一个信号处理函数，然后系统调用返回，进程不会被阻塞，而是继续执行。
+ 当内核中的 IO 数据就绪时，会发送一个信号给进程，进程便在信号处理函数中调用 IO 读取数据。
- 此模型的特点是，采用了回调机制，这样开发和调试应用的难度加大。

*异步 I/O*
#figure(
  image("pic/2025-12-10-16-59-52.png", width: 80%),
  numbering: none,
)
+ 用户进程发起 read 异步系统调用之后，立刻就可以开始去做其它的事。
+ 从内核的角度看，当它收到一个 read 异步系统调用之后，首先它会立刻返回，所以不会对用户进程产生任何阻塞情况。
+ kernel 会等待数据准备完成，然后将数据拷贝到用户内存。
+ 当这一切都完成之后，kernel 会通知用户进程，告诉它 read 操作完成了。

*比较*
#figure(
  image("pic/2025-12-10-17-00-15.png", width: 80%),
  numbering: none,
)
+ 阻塞 I/O：在用户进程发出 I/O 系统调用后，进程会等待该 IO 操作完成，而使得进程的其他操作无法执行。
+ 非阻塞 I/O：在用户进程发出 I/O 系统调用后，如果数据没准备好，该 I/O 操作会立即返回，之后进程可以进行其他操作；如果数据准备好了，用户进程会通过系统调用完成数据拷贝并接着进行数据处理。
+ 多路复用 I/O：将多个非阻塞 I/O 请求的轮询操作合并到一个 select 或 epoll系统调用中进行。
+ 信号驱动 I/O：利用信号机制完成从内核到应用进程的事件通知。
+ 异步 I/O：不会导致请求进程阻塞。
  #three-line-table[
    | I/O 模型          | 等待数据阶段           | 数据复制阶段   | 总体是否阻塞进程  | 实际常用程度             |
    | --------------- | ---------------- | -------- | --------- | ------------------ |
    | *阻塞 I/O*      | 阻塞               | 阻塞       | ✔ 完全阻塞    | ★★★（简单场景）          |
    | *非阻塞 I/O*     | ❌ 不阻塞（不断轮询）      | 阻塞       | ❌ 不完全阻塞   | ★（很少单独用）           |
    | *多路复用 I/O*    | 阻塞于 select/epoll | 阻塞于 read | ✔ 阻塞（可并发） | ★★★★★（服务器标配）       |
    | *信号驱动 I/O*    | 不阻塞（靠信号通知）       | 阻塞于 read | ❌ 不完全阻塞   | ★（较少用）             |
    | *异步 I/O（AIO）* | 不阻塞              | 不阻塞      | ❌ 完全不阻塞   | ★★★（未来趋势，io_uring） |
  ]

== 磁盘子系统

=== 概述

*磁盘工作机制和性能参数*
#figure(
  image("pic/2025-12-10-19-43-00.png", width: 80%),
  numbering: none,
)
*磁盘 I/O 传输时间*
#figure(
  image("pic/2025-12-10-19-43-44.png", width: 80%),
  numbering: none,
)
$
  T_a = T_s + 1/(2r) + b/(r N)
$
- $T_a$：访问时间
- $T_s$：寻道时间
- $1/2r$：旋转延迟
  - $1/r$旋转一周的时间
- $b/(r N)$：传输时间
  - $b$：传输的比特数
  - $N$：磁道上每转的比特数
  - $r$：磁盘转数

=== 磁盘调度算法

通过优化磁盘访问请求顺序来提高磁盘访问性能
- *寻道时间*是磁盘访问最耗时的部分
- 同时会有多个在同一磁盘上的 I/O 请求
- 随机处理磁盘访问请求的性能表现很差

*FIFO*
#figure(
  image("pic/2025-12-10-19-55-47.png", width: 80%),
  numbering: none,
)
- 先进先出 (FIFO) 算法
- 按顺序处理请求
- 公平对待所有进程
- 在有很多进程的情况下，接近随机调度的性能

*最短服务时间优先 (SSTF)*
#figure(
  image("pic/2025-12-10-19-56-08.png", width: 80%),
  numbering: none,
)
- 选择从磁臂当前位置需要移动最少的 I/O 请求
- 总是选择最短寻道时间

*扫描算法 (SCAN)*
#figure(
  image("pic/2025-12-10-19-56-27.png", width: 80%),
  numbering: none,
)
- 磁臂在一个方向上移动，访问所有未完成的请求
- 直到磁臂到达该方向上最后的磁道，调换方向
- 也称为电梯算法 (elevator algorithm)

*循环扫描算法 (C-SCAN)*
- 限制了仅在一个方向上扫描
- 当最后一个磁道也被访问过了后，磁臂返回到磁盘的另外一端再次进行C-LOOK 算法
- 磁臂先到达该方向上最后一个请求处，然后立即反转，而不是先到最后点路径上的所有请求

*循环扫描算法 (N-step-SCAN)*
- 磁头粘着 (Arm Stickiness) 现象
  - SSTF、SCAN 及 CSCAN 等算法中，可能出现磁头停留在某处不动的情况
- N 步扫描算法
  - 将磁盘请求队列分成长度为 N 的子队列
  - 按 FIFO 算法依次处理所有子队列
  - 扫描算法处理每个队列

*双队列扫描算法 (FSCAN)*
- FSCAN 算法
  - 把磁盘 I/O 请求分成两个队列
  - 交替使用扫描算法处理一个队列
  - 新生成的磁盘 I/O 请求放入另一队列中
  - 所有的新请求都将被推迟到下一次扫描时处理
- FSCAN 算法是 N 步扫描算法的简化
- FSCAN 只将磁盘请求队列分成两个子队列
  #three-line-table[
    | 算法          | 思想         | 优点     | 缺点        |
    | ----------- | ---------- | ------ | --------- |
    | FIFO        | 按到达顺序      | 公平、简单  | 性能差       |
    | SSTF        | 最近磁道优先     | 性能较好   | 可能饥饿      |
    | SCAN（电梯）    | 单方向扫描      | 公平、不饥饿 | 边缘请求等待时间长 |
    | C-SCAN      | 单方向扫描 + 跳回 | 延迟更均匀  | 回跳需要额外移动  |
    | N-step-SCAN | 分批处理       | 防粘着    | 需要维护队列    |
    | FSCAN       | 双队列扫描      | 稳定、高性能 | 实现稍复杂     |
  ]

== 实践：支持device的OS（DOS）

=== 进化目标

*进化目标 vs 以往目标*

DOS需要支持对多种外设的高效访问
- 在内核中响应外设中断
- 在内核中保证对全局变量的互斥访问
- 基于中断机制的串口驱动
- 基于中断机制的Virtio-Block驱动
- 其它外设驱动
#figure(
  image("pic/2025-12-10-20-14-20.png", width: 80%),
  numbering: none,
)
- SMOS：在多线程中支持对共享资源的同步互斥访
- TCOS：支持线程和协程
- IPC OS：进程间交互
- Filesystem OS：支持数据持久保存
- Process OS: 增强进程管理和资源管理
- Address Space OS: 隔离APP访问的内存地址空间
- multiprog & time-sharing OS: 让APP共享CPU资源
- BatchOS： 让APP与OS隔离，加强系统安全，提高执行效率
- LibOS: 让APP与HW隔离，简化应用访问硬件的难度和复杂性

*历史背景*
- UNIX诞生是从磁盘驱动程序开始的
- 贝尔实验室的Ken Tompson先在一台闲置的PDP-7计算机的磁盘驱动器写了一个包含磁盘调度算法的磁盘驱动程序，希望提高磁盘I/O读写速度。为了测试磁盘访问性能，他花了三周时间写了一个操作系统，这就是Unix的诞生。
- 写磁盘驱动程序包括如下一些操作：
  + 数据结构：包括设备信息、状态、操作标识等
  + 初始化：即配置设备，分配I/O所需内存，完成设备初始化
  + 中断响应：如果设备产生中断，响应中断并完成I/O操作后续工作
  + 设备操作：根据内核模块（如文件系统）的要求（如读/写磁盘数据），给I/O设备发出命令
  + 内部交互：与操作系统上层模块或应用进行交互，完成上层模块或应用的要求（如接受文件系统下达的I/O请求，上传读出的磁盘数据）

=== 相关硬件

*相关硬件*
- PLIC(Platform-Level Interrupt Controller)
  - 处理各种外设中断
- CLINT(Core Local Interruptor)
  - Software Intr
  - Timer Intr
  #figure(
    image("pic/2025-12-10-20-24-45.png", width: 80%),
    numbering: none,
  )
*系统中的外设*
```bash
$ qemu-system-riscv64 -machine virt -machine dumpdtb=riscv64-virt.dtb -bios default
   qemu-system-riscv64: info: dtb dumped to riscv64-virt.dtb. Exiting.
$ dtc -I dtb -O dts -o riscv64-virt.dts riscv64-virt.dtb
$ less riscv64-virt.dts
```
PLIC设备
```
                plic@c000000 {
                        phandle = <0x03>;
                        riscv,ndev = <0x35>;
                        reg = <0x00 0xc000000 0x00 0x600000>;
                        interrupts-extended = <0x02 0x0b 0x02 0x09>;
                        interrupt-controller;
                        ...
                };
```
virtio-blk磁盘块设备
```
                virtio_mmio@10008000 {
                        interrupts = <0x08>;
                        interrupt-parent = <0x03>;
                        reg = <0x00 0x10008000 0x00 0x1000>;
                        compatible = "virtio,mmio";
                };
```
UART串口设备
```
                uart@10000000 {
                        interrupts = <0x0a>;
                        interrupt-parent = <0x03>;
                        clock-frequency = <0x384000>;
                        reg = <0x00 0x10000000 0x00 0x100>;
                        compatible = "ns16550a";
                };
```
virtio-input 键盘设备
```
                virtio_mmio@10005000 {
                        interrupts = <0x05>;
                        interrupt-parent = <0x03>;
                        reg = <0x00 0x10005000 0x00 0x1000>;
                        compatible = "virtio,mmio";
                };
```
virtio-input 鼠标设备
```
                virtio_mmio@10006000 {
                        interrupts = <0x06>;
                        interrupt-parent = <0x03>;
                        reg = <0x00 0x10006000 0x00 0x1000>;
                        compatible = "virtio,mmio";
                };
```
virtio-gpu 显示设备
```
                virtio_mmio@10007000 {
                        interrupts = <0x07>;
                        interrupt-parent = <0x03>;
                        reg = <0x00 0x10007000 0x00 0x1000>;
                        compatible = "virtio,mmio";
                };
```
#newpara()

*PLIC*
- PLIC中断源
  - PLIC支持多个中断源，每个中断源可以是不同触发类型，电平触发或者边沿触发、PLIC为每个中断源分配一个不同的编号。
  #figure(
    image("pic/2025-12-10-20-28-38.png", width: 80%),
    numbering: none,
  )
- PLIC中断处理流程
  - 接收来自外设的中断信号（Interrupt Source）
    - 每个外设对应一个中断 ID（1~N）
    - 例如：
      #three-line-table[
        | 设备                | DTS 中断号 | 含义         |
        | ----------------- | ------- | ---------- |
        | UART              | 10      | PLIC ID=10 |
        | virtio-blk        | 8       | 磁盘中断       |
        | virtio-input (键盘) | 5       | 键盘中断       |
        | virtio-input (鼠标) | 6       | 鼠标中断       |
        | virtio-gpu        | 7       | GPU 中断     |
      ]
  - 闸口 Gateway — 负责把外设电平/边沿信号转成统一格式
    - PLIC 不关心外设如何发中断（电平触发、边沿触发），
    - Gateway 会：
      - 收到中断后设置 IP（Interrupt Pending）寄存器位为1
      - 阻止同一个中断源重复进来（防抖）
      - 等待 CPU 来 claim 才允许新中断进入
- 优先级判断 Priority
  - 每个中断源对应一个 priority 寄存器
  - 优先级越大，越先处理
  - priority=0 表示永远不会触发
- 每个 CPU（或核的模式）有一个 Enable 位图
#figure(
  image("pic/2025-12-10-20-29-02.png", width: 80%),
  numbering: none,
)
#three-line-table[
  | 阶段                              | 描述                                            |
  | ------------------------------- | --------------------------------------------- |
  | *① 外设产生中断*                    | Gateway 将信号 → 设置 IP[x]=1                      |
  | *② PLIC 判断优先级*                | 若该中断的优先级 > CPU 的 interrupt threshold → 通知 CPU |
  | *③ CPU 收到 External Interrupt* | 进入 trap handler（内核）                           |
  | *④ 内核读取 PLIC_CLAIM 寄存器*       | 得到中断 ID，并自动清除 IP[x] （硬件操作）                    |
  | *⑤ 内核根据 ID 调对应驱动的中断处理例程 ISR*  | 如 UART ISR、Block ISR 等                        |
  | *⑥ 处理完成后写回 PLIC_COMPLETE 寄存器* | 告诉 PLIC：我处理完了，可以允许下一个同源中断                     |
]
- 闸口（Gateway）和IP寄存器（中断源的等待标志寄存器）
- 编号（ID）
- 优先级（priority）
- 使能（Enable）
- PLIC中断源
  - 闸口（Gateway）将不同类型的外部中断传换成统一的内部中断请求
  - 闸口保证只发送一个中断请求，中断请求经过闸口发送后，硬件自动将对应的IP寄存器置高
  - 闸口发送一个中断请求后则启动屏蔽，如果此中断没有被处理完成，则后续的中断将会被闸口屏蔽
  - PLIC为每个中断源分配编号（ID）。ID编号0被预留，作为表示“不存在的中断”，因此有效的中断ID从1开始
  - 每个中断源的优先级寄存器应该是存储器地址映射的可读可写寄存器，从而使得软件可以对其编程配置不同的优先级
  - PLIC支持多个优先级，优先级的数字越大，表示优先级越高
  - 优先级0意味着“不可能中断”，相当于中断源屏蔽
  - 每个中断目标的中断源均分配了一个中断使能（IE）寄存器，IE寄存器是可读写寄存器，从而使得软件对其编程
    - 如果IE寄存器被配置为0，则意味着此中断源对应中断目标被屏蔽
    - 如果IE寄存器被配置为1，则意味着此中断源对应中断目标被打开

=== 总体思路

- 为何支持外设中断
  - 提高系统的整体执行效率
- 为何在内核态响应外设中断
  - 提高OS对外设IO请求的响应速度
- 潜在的问题
  - 内核态能响应中断后，不能保证对全局变量的互斥访问
  - 原因：中断会打断当前执行，并切换到另一控制流访问全局变量
- 解决方案
  - 在访问全局变量起始前屏蔽中断，结束后使能中断

=== 实践步骤

```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch9
```
应用程序没有改变，但在串口输入输出、块设备读写的IO操作上是基于中断方式实现的。

=== 软件架构

内核的主要修改 （ `os/src` ）
```
├── boards
│   └── qemu.rs  // UART、VIRTIO、PLIC的MMIO地址
├── console.rs  //基于UART的STDIO
├── drivers
│   ├── block
│   │   └── virtio_blk.rs //基于中断/DMA方式的VIRTIO-BLK驱动
│   ├── chardev
│   │   └── ns16550a.rs //基于中断方式的串口驱动
│   └── plic.rs //PLIC驱动
├── main.rs  //外设中断相关初始化
└── trap
    ├── mod.rs //支持处理外设中断
    └── trap.S //支持内核态响应外设中断
```

=== 程序设计

设备直接相关（提供）
- 外设初始化操作
- 外设中断处理操作
- 外设I/O读写（或配置）操作
OS交互相关（需求）
- 内存分配/映射服务
- 中断/调度/同步互斥/文件系统等服务

*系统设备管理*
- 了解各个设备的基本信息
  - 控制寄存器地址范围(控制寄存器基址，中断号)
    ```rust
    const VIRT_PLIC: usize = 0xC00_0000;   // PLIC
    const VIRT_UART: usize = 0x1000_0000;  // UART
    const VIRTIO0: usize = 0x10008000;     // VIRTIO_BLOCK
    const VIRTIO5: usize = 0x10005000;     // VIRTIO_KEYBOARD
    const VIRTIO6: usize = 0x10006000;     // VIRTIO_MOUSE
    const VIRTIO7: usize = 0x10007000;     // VIRTIO_GPU
    // 在总中断处理例程中对不同外设的中断进行响应
    match intr_src_id {
       5 => KEYBOARD_DEVICE.handle_irq(),
       6 => MOUSE_DEVICE.handle_irq(),
       8 => BLOCK_DEVICE.handle_irq(),
       10 => UART.handle_irq(),
    ```
  - 设备中断号
- 对PLIC进行配置
  - 使能中断
  - 设置中断优先级
- 系统设备管理初始化
  - 配置PLIC:
    - 设置接收中断优先级的下限
    - 使能S-Mode下的响应外设中断号：5/6/8/10
    - 设置外设中断号的优先级
  - 配置CPU
    - 设置 `sie` CSR寄存器，使能响应外部中断
    - `os/src/drivers/plic.rs` 和 `os/src/boards/qemu.rs::devices_init()`

*UART设备驱动*
- UART设备驱动的核心数据结构
  ```rust
  pub struct NS16550a<const BASE_ADDR: usize> {
      inner: UPIntrFreeCell<NS16550aInner>,
      condvar: Condvar, //用于挂起/唤醒读字符的经常
  }
  struct NS16550aInner {
      ns16550a: NS16550aRaw,
      read_buffer: VecDeque<u8>, //用于缓存读取的字符
  }
  pub struct NS16550aRaw {
      base_addr: usize, //控制寄存器基址
  }
  ```
- 字符类设备需要实现的接口
  ```rust
  pub trait CharDevice {
      fn init(&self);
      fn read(&self) -> u8;
      fn write(&self, ch: u8);
      fn handle_irq(&self);
  }
  ```
- UART初始化操作
  ```rust
  impl<const BASE_ADDR: usize> CharDevice for NS16550a<BASE_ADDR> {
      fn init(&self) {
          let mut inner = self.inner.exclusive_access(); //独占访问
          inner.ns16550a.init(); //调用ns16550a的UART初始化函数
          drop(inner);
      }
  ```
- UART中断处理操作
  ```rust
  fn handle_irq(&self) {
    let mut count = 0;
    self.inner.exclusive_session(|inner| {
        //调用ns16550a中读字符函数
        while let Some(ch) = inner.ns16550a.read() {
              count += 1;
              inner.read_buffer.push_back(ch);
    ...
    if count > 0 {
        // 唤醒等待读取字符的进程
        self.condvar.signal();
    ...
  ```
- UART I/O读写（或配置）操作
  ```rust
  fn read(&self) -> u8 {
    loop {
        let mut inner = self.inner.exclusive_access();
        if let Some(ch) = inner.read_buffer.pop_front() {
              return ch;
        } else {
              let task_cx_ptr = self.condvar.wait_no_sched();
              drop(inner);
              schedule(task_cx_ptr);
      ...

      fn write(&self, ch: u8) {
      let mut inner = self.inner.exclusive_access();
      inner.ns16550a.write(ch);
  }
  ```
*virtio_blk块设备驱动*
- virtio_blk设备驱动的核心数据结构
  ```rust
  pub struct VirtIOBlock {
      virtio_blk: UPIntrFreeCell<VirtIOBlk<'static, VirtioHal>>,
      condvars: BTreeMap<u16, Condvar>, //<虚拟队列号，条件变量>映射
  }
  ```
- 存储类设备要实现的接口
  ```rust
  pub trait BlockDevice: Send + Sync + Any {
      fn read_block(&self, block_id: usize, buf: &mut [u8]);
      fn write_block(&self, block_id: usize, buf: &[u8]);
      fn handle_irq(&self);
  }
  ```
- virtio_blk初始化操作
  ```rust
  pub fn new() -> Self {
     let virtio_blk = unsafe {
        UPIntrFreeCell::new(
              // 初始化vritio_drivers中的VirtIOBlk块设备
              VirtIOBlk::<VirtioHal>::new(&mut *(VIRTIO0 as *mut VirtIOHeader)).unwrap(),)
     let mut condvars = BTreeMap::new();
     let channels = virtio_blk.exclusive_access().virt_queue_size();
     // 建立虚拟队列号与条件变量的映射
     for i in 0..channels {
        let condvar = Condvar::new();
        condvars.insert(i, condvar);
     }
     ...
  ```
- virtio_blk中断处理操作
  ```rust
  fn handle_irq(&self) {
    self.virtio_blk.exclusive_session(|blk| {
        //获得块访问完成的虚拟队列号
        while let Ok(token) = blk.pop_used() {
              // 根据队列号对应的信号量，唤醒等待块访问结束的挂起进程
              self.condvars.get(&token).unwrap().signal();
        }
    ...
  ```
- virtio_blk I/O读写（或配置）操作
  ```rust
  fn read_block(&self, block_id: usize, buf: &mut [u8]) {
    ...
        let mut resp = BlkResp::default();// 生成一个块访问命令
        let task_cx_ptr = self.virtio_blk.exclusive_session(|blk| {
              // 调用virtio_drivers库中VirtIOBlk的read_block_nb函数，发出读块命令
              let token = unsafe { blk.read_block_nb(block_id, buf, &mut resp).unwrap() };
              // 通过条件变量挂起当前进程，等待块访问结束
              self.condvars.get(&token).unwrap().wait_no_sched()
        });
        // 唤醒等待块访问结束的进程
        schedule(task_cx_ptr);
    ...
  }
  fn write_block(&self, block_id: usize, buf: &[u8]) {
    ...
        let mut resp = BlkResp::default(); // 生成一个块访问命令
        let task_cx_ptr = self.virtio_blk.exclusive_session(|blk| {
              // 调用virtio_drivers库中VirtIOBlk的read_block_nb函数，发出写块命令
              let token = unsafe { blk.write_block_nb(block_id, buf, &mut resp).unwrap() };
              // 通过条件变量挂起当前进程，等待块访问结束
              self.condvars.get(&token).unwrap().wait_no_sched()
        });
        // 唤醒等待块访问结束的进程
        schedule(task_cx_ptr);
    ...
  ```
