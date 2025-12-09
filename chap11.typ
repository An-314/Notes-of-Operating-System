#import "@preview/scripst:1.1.1": *

= 线程与协程

== 线程

#note(subname: [问题])[
  现代程序通常需要同时做多件事情：
  - 浏览器：渲染、脚本执行、网络请求、视频播放
  - 游戏：物理引擎、渲染引擎、AI、音效
  - Web服务器：处理多个请求、日志写入、后台清理
  如果只有“进程”这一种单位，那么：
  - 一个进程只能有 一个执行流（单一 PC 寄存器）
  - 想同时干两件事情，只能依靠 多进程
  但多进程有两个大问题：
  - 进程创建/切换成本太高
    - PCB 结构庞大（页表、文件描述符表、信号等）
    - 切换进程时需要切换页表（TLB flush）
    - fork/exec 本身也很昂贵
  - 多进程不共享内存
    - 每个子进程一个独立地址空间
    - 数据共享困难（需要 IPC，如共享内存 / pipe 等）

  *线程是什么？*
  - 线程是：
    - 进程内的最小执行单元
    - 轻量级的 CPU 执行流
  - 线程具有自己的：
    - 程序计数器（PC）
    - 寄存器现场
    - 栈（每个线程有独立栈）
  - 线程共享进程的：
    - 代码段（text）
    - 全局变量（data/bss）
    - 堆（heap）
    - 文件描述符
    - 地址空间
  - 进程 = 资源单位，线程 = 执行单位
  *如何在一个进程内实现多个程序执行流的并发执行？*
  - 同一个进程内的多个“函数调用栈”
  - 多个独立的执行上下文
  - 在 CPU 上抢占式地调度
  - 内核调度线程，就像调度进程一样：
    ```
    Thread 1 → running
    Thread 2 → ready
    Thread 3 → blocked
    ```
  *进程内的并发执行流服务由谁提供？*
  - 用户库、内核、语言、硬件？
  - 用户级线程（User-Level Thread, ULT）
    - 由语言/库实现，内核完全不知道线程存在
    - Java 早期绿线程（Green Thread），Go 协程（goroutine），Rust async task，Python 早期的绿色线程，libco、libtask 等用户空间线程库
      #three-line-table[
        | 特性            | 说明                          |
        | ------------- | --------------------------- |
        | 切换在用户态完成      | 不需要内核参与，开销小                 |
        | 内核只看到一个 LWP   | 所有用户级线程共同占用一个 kernel thread |
        | I/O 阻塞会阻塞全部线程 | 因为内核只看到一个线程                 |
      ]
  - 内核级线程（Kernel Thread）
    - Linux pthread（POSIX Thread）、Windows thread、MacOS thread
      #three-line-table[
        | 特性          | 说明           |
        | ----------- | ------------ |
        | 内核调度每个线程    | 真正的并发执行      |
        | 阻塞一个不会阻塞全部  | 每个线程是内核可调度对象 |
        | 切换成本比 ULT 高 | 需要内核态切换      |
      ]
  - 多对多模型（M:N Threading）
    - Go：goroutine ↔ 内核线程（GOMAXPROCS）、Java 虚拟线程（Project Loom）、Erlang BEAM actor
    - 语言运行时维护 M 个轻量线程 → 映射到 N 个内核线程上
  - 现代 CPU 支持：
    - 多核 → 多线程可真正并行
    - 超线程（Hyper-Threading） → 一个核心提供两个逻辑核
    - 上下文切换的硬件支持 → 保存/恢复寄存器
]

=== 为何需要线程？

*进程存在的不足*
- 进程之间地址空间隔离
- 通过IPC共享/交换数据不方便
- 管理进程开销大
- 创建/删除/切换
- 并行/并发处理困难
  ```c
  while(TRUE) {
    Read();         // I/O-bound
    Decompress();   // CPU-bound
    Play();         // I/O-bound
  }
  ```
  在一个进程中只有一条控制流（单线程），一旦阻塞，整个程序都被阻塞。
*为何需要线程？*
- 在应用中可能同时发生多种活动，且某些活动会被阻塞
- 将*程序分解成可并行运行的多个顺序控制流*
  - 可提高执行*效率*
  - 程序设计模型也会变得更*简单*
  #figure(
    image("pic/2025-12-02-19-50-17.png", width: 80%),
    numbering: none,
  )
- 永远存在的用户需求 -- 性能！
  - 并行实体（多个顺序控制流）共享同一个地址空间和所有可用数据
  - 访问数据和共享资源方便
  - 切换控制流轻量
  - 管理不同控制流便捷
*线程 vs 进程*
- 进程是资源（包括内存、打开的文件等）分配的单位，线程是 CPU 调度的单位；
- 进程拥有一个完整的资源平台，而线程只独享必不可少的资源，如寄存器和栈；
- 线程同样具有就绪、阻塞、执行三种基本状态，同样具有状态之间的转换关系；
- 线程能减少并发执行的时间和空间开销；
- 一个进程中可以同时存在多个线程；
- 各个线程之间可以并发执行；
- 各个线程之间可以共享地址空间和文件等资源；
- 当进程中的一个线程崩溃时，会导致其所属进程的所有线程崩溃（这里是针对 C/C++ 语言，Java语言中的线程崩溃不会造成进程崩溃）。
  #three-line-table[
    | 比较项  | 进程（Process） | 线程（Thread）   |
    | ---- | ----------- | ------------ |
    | 定义   | 资源管理单位      | CPU 调度单位     |
    | 地址空间 | 独立          | 共享           |
    | 数据共享 | 需要 IPC      | 直接共享         |
    | 切换成本 | 高           | 低            |
    | 并发效率 | 较低          | 较高           |
    | 崩溃影响 | 只影响本进程      | 影响整个进程中的所有线程 |
    | 适用场景 | 隔离、独立服务     | 并发、高性能、资源共享  |
  ]

=== 线程的概念

==== 线程的定义

*线程的定义*
- 线程是*进程内的指令执行流*
  - 进程中指令执行流的基本单元
  - CPU调度的*基本单位*
  #figure(
    image("pic/2025-12-02-20-25-41.png", width: 80%),
    numbering: none,
  )
*进程和线程的角色*
- 进程的*资源分配*角色
  - 进程由一组相关资源构成，包括地址空间（代码段、数据段）、打开的文件等各种资源
- 线程的*处理机调度*角色
  - 线程描述在进程资源环境中的指令流执行状态

*进程和线程的关系*：进程 = 线程 + 共享资源
- 一个进程中可存在多个线程
- 线程共享进程的地址空间
- 线程共享进程的资源
- 线程崩溃会导致进程崩溃
- 线程是一个调度实体 Scheduling Entry
  - User-SE v.s. Kernel-SE

*线程与进程的比较*
- 进程是资源分配单位，线程是CPU调度单位
- 进程拥有一个完整的资源平台，而线程只独享指令流执行的必要资源，如寄存器和栈
- 线程具有就绪、等待和运行三种基本状态和状态间的转换关系
- 线程能减少并发执行的时间和空间开销
  - 线程的创建/终止/切换时间比进程短
  - 同一进程的各线程间共享内存和文件资源，可不通过内核进行直接通信

==== 线程管理

*用户态管理的线程与内核态管理的线程*

#figure(
  image("pic/2025-12-02-22-40-07.png", width: 80%),
  numbering: none,
)
- 用户态线程（User-Level Thread, ULT）
  - 线程由*用户库*实现
  - 内核不知道线程的存在，只看到一个进程
  - 上下文切换无需系统调用，速度极快
  - 但一个线程阻塞（如 read），整个进程都会阻塞
- 内核态线程（Kernel-Level Thread, KLT）
  - 线程由*内核*管理（Linux pthread）
  - 每个线程都有内核调度实体（Kernel-SE）
  - 线程阻塞不会影响同进程其他线程
  - 切换需要陷入内核 → 成本高于用户线程，但比进程低得多
  - 现代 OS（Linux、Windows、macOS）都使用这个模型。

*线程控制块(TCB, Thread Control Block)*
```c
typedef struct
{
       int                       detachstate;   // 线程的分离状态
       int                       schedpolicy;   // 线程调度策略 FIFO、RR等
       structsched_param         schedparam;    // 线程的调度参数 优先级
       int                       inheritsched;  // 线程的继承性
       int                       scope;         // 线程的作用域进程级、系统级
       size_t                    guardsize;     // 线程栈末尾的警戒缓冲区大小
       int                       stackaddr_set; // 线程的栈设置
       void*                     stackaddr;     // 线程栈的位置，起始地址
       size_t                    stacksize;     // 线程栈的大小
} pthread_attr_t;
```
#newpara()
*创建线程API*
- 创建线程：成功返回零，否则返回非零值
  ```c
  #include <pthread.h>
  int pthread_create(      pthread_t *        thread,
                const pthread_attr_t *       attr,
                      void *                 (*start_routine)(void*),
                      void *                 arg);
  ```
  - thread指向pthread_t结构类型的指针
  - attr用于指定该线程可能具有的任何属性
  - start_routine是线程开始运行的函数指针
  - arg是要传递给线程开始执行的函数的参数
*等待线程API*
- 等待线程：一直阻塞调用它的线程，直至目标线程执行结束
  ```c
  #include <pthread.h>
  int pthread_join(pthread_t thread, void *retval);
  ```
  - thread指向pthread_t结构类型的指针
  - retval是指向返回值的指针
- 调用 pthread_join 的线程会阻塞，直到目标线程终止。

=== 使用线程

*线程示例*
```c
void *mythread(void *arg) {
    printf("%s\n", (char *) arg);
    return NULL;
}
int main(int argc, char *argv[]) {
   pthread_t p1, p2;
   int rc;
   printf("main: begin\n");
   rc = pthread_create(&p1, NULL, mythread, "A"); assert(rc == 0);
   rc = pthread_create(&p2, NULL, mythread, "B"); assert(rc == 0);
   // join waits for the threads to finish
   rc = pthread_join(p1, NULL); assert(rc == 0);
   rc = pthread_join(p2, NULL); assert(rc == 0);
   printf("main: end\n");
   return 0;
}
```
*线程示例输出*：一个程序，它创建两个线程，每个线程都做了一些独立的工作，在这例子中，打印“A”或“B”。
```
❯ ./t0
main: begin
A
B
main: end
```

=== 线程的设计实现

*线程的几种实现方式*
- 用户态管理且用户态运行的线程（内核不可见的用户线程）
  - Thread managed&running in User-Mode
- 内核态管理且用户态运行的线程（内核可见的用户线程）
  - Thread managed in Kernel-Mode&running in User-Mode
- 内核态管理且内核态运行的线程（内核线程）
  - Thread managed&running in Kernel-Mode
- 混合管理且运行的线程（轻量级进程，混合线程）
  - Thread managed&running in Mixed-Mode

==== 用户态管理且用户态运行的线程

*用户态管理且用户态运行的线程*
- 在用户态实现线程的管理与运行，操作系统感知不到这类线程的存在
  - GNU Pth (Portable Threads)，Mach C-threads，Solaris threads
  - 别名：用户态线程(User-level Thread)、绿色线程(Green Thread)、有栈协程(Stackful Coroutine)、纤程(Fiber)
- 由一组*用户级的线程库函数*来完成线程的管理，包括线程的创建、终止、同步和调度等

*用户态管理线程的优点*
- 线程的调度不需要内核直接参与，控制简单
- 可以在不支持线程的操作系统中实现
- 创建和销毁线程、线程切换等线程管理的代价比内核线程少得多
- 允许每个进程定制自己的调度算法，线程管理比较灵活
- 同一进程中只能同时有一个线程在运行，如果有一个线程使用了系统调用而阻塞，那么整个进程都会被挂起

*用户态管理线程的不足*
- 一个线程发起系统调用而阻塞时，则整个进程进入等待
- 不支持基于线程的处理机抢占
- 只能按进程分配CPU时间
- 多个处理机下，同一个进程中的线程只能在同一个处理机下分时复用

#figure(
  image("pic/2025-12-03-12-38-24.png", width: 80%),
  numbering: none,
)

==== 内核态管理且用户态运行的线程

*内核态管理且用户态运行的线程*
- *每个用户线程都有一个对应的内核线程*
- 由内核通过系统调用实现的线程机制，由内核完成线程的创建、终止和管理
- 由内核维护线程控制块TCB，在内核实现
- 线程执行系统调用而被阻塞不影响其他线程
- 一个进程中可以包括多个线程
  - Windows NT 内核支持线程，每个线程都是内核对象
  - Linux-2.6 + glibc-2.3开始支持POSIX thread标准
  - rCore/uCore内核的设计
  - 主流：一个用户线程对应一个内核的线程控制块，由内核管理和调度

*线程的上下文切换*
- 线程是调度的基本单位，而进程则是资源拥有的基本单位
  - 不同进程中的线程切换：进程*上下文（如页表等）*需要切换
  - 相同进程中的线程切换：虚拟内存等*进程资源*不需切换，只需要*切换线程的私有数据、寄存器*等不共享的数据

*内核态管理且用户态运行线程的不足*
- 在一般情况下，线程切换开销与进程切换开销相差不大，大于用户态管理且用户态允许的线程切换开销
- 与传统的进程管理机制会产生一些矛盾，一些系统调用的实现功能/语义上会不协调
  - fork()、signal() ...

*多线程`fork()`引起的问题*
- 多线程应用程序中，建议谨慎使用`fork()`
  - 竞态条件：线程正在修改共享变量或资源时调用了`fork()`，会导致子进程继承这个状态和资源的不一致性。例如全局变量被多个线程修改
  - 死锁：线程正在持有某个锁或资源时调用`fork()`，可能导致子进程无法获得该锁而导致死锁。例如子进程中没有持有锁的线程会死锁。
  - 内存占用：多线程`fork()`会复制整个进程的地址空间，包括所有线程所拥有的栈、寄存器和锁等资源
  - 性能下降：多线程`fork()`的开销较大，可能会影响应用程序的性能
- 可采用：限制线程中调用`fork()`、使用 `pthread_atfork()` 在 `fork()` 前后统一加/解锁来防止子进程死锁等方法，来避免这些问题。

#figure(
  image("pic/2025-12-03-20-02-49.png", width: 80%),
  numbering: none,
)

==== 内核态管理且内核态运行的线程

*内核态管理且内核态运行的线程（简称：内核线程）*
- 由内核实现线程机制，由内核完成线程的创建、终止和管理
- 由内核维护TCB, 在内核实现
- 线程在内核中执行
  - 如：Linux的内核线程
- 一个内核线程可分时/并行处理一件内核任务
- 内核线程的调度由内核负责，一个内核线程处于阻塞状态时不影响其他的内核线程

*内核态管理且内核态运行线程的作用*
- 执行周期性的任务
  - 把Buffer-Cache定期写回到存储设备上
  - 在可用物理内存页很少情况下执行虚存交换操作
  - 实现文件系统的事务日志
  - ......

#figure(
  image("pic/2025-12-03-21-43-45.png", width: 80%),
  numbering: none,
)

==== 混合管理且运行的线程

*轻量级进程：双态管理的线程*
- 轻量级进程（Light-Weight Process，LWP）
  - 定义：LWP 是用户线程库与内核线程之间的中间数据结构，向用户线程库呈现为“可调度虚拟 CPU”。用户线程可被映射到一个或多个 LWP 上，由用户态调度器在这些 LWP 上切换执行。
  - 每个 LWP 是跟内核线程一对一映射的，即一个LWP 绑定到一个内核线程。
  - 一个进程可包含多个LWP，一个LWP 可对应多个用户线程，一个用户线程也可对应多个LWP。
*轻量级进程与用户线程的对应关系*
- 1 : 1（主流），即一个用户线程对应一个LWP。如Linux内核管理和调度用户线程
- M : 1（非主流），即多个用户线程对应一个LWP。如Green Thread，内核仅管理包含多个线程的进程，用户态的线程运行时管理线程。
- M : N（非主流），即多个用户线程对应多个LWP。如Solaris OS通过用户态线程运行时和内核协同，对用户态线程进行管理和调度。
  #figure(
    image("pic/2025-12-03-21-45-54.png", width: 80%),
    numbering: none,
  )
*轻量级进程管理*
- *编程人员*决定内核线程与用户级线程的对应关系
- *用户级线程*由用户线程管理库管理
- *内核*只识别内核级线程/进程，并对其进行调度
- 内核与用户态线程管理库交互
- 具有最大灵活度和实现复杂性
  #figure(
    image("pic/2025-12-03-21-46-28.png", width: 80%),
    numbering: none,
  )
*轻量级进程实例（M : N线程模型）*
- Solaris 操作系统+C线程运行时库
- 曾在 Solaris（≤ 8）、HP-UX（11i v1.6+）、AIX（4.3.1–7.3）、IRIX、Tru64 UNIX 中得到过真实应用
- 实现复杂度高：调试和维护难度大
- 性能不稳定：切换代价和同步开销往往抵消 M:N 本应带来的优势
- 现代硬件多核/多处理器环境下，1:1 模型能更直接地映射并行需求

#align(center)[
  #three-line-table[
    | 模型                | 优点            | 缺点         | 代表                        |
    | ----------------- | ------------- | ---------- | ------------------------- |
    | *ULT（用户级）*      | 快、不陷入内核       | 系统调用阻塞整个进程 | 绿色线程、Fiber、协程             |
    | *KLT（内核级）*      | 真并行、阻塞不影响其他线程 | 切换开销大      | pthread、Windows thread    |
    | *Kernel Thread* | 内核后台任务        | 不能运行用户代码   | Linux kthreads            |
    | *M:N（LWP）*      | 综合两者优势        | 实现复杂，难调试   | Solaris、Go runtime（现代改进版） |
  ]
]
== 协程（Coroutine）

#note(subname: [问题])[
  - *堆栈必须是CPU调度对象的属性吗？*
    - 因为线程执行的每一次函数调用、局部变量、返回地址，全都记录在：
      - 线程自己的栈（Stack） 上
      - 而 CPU 在执行线程切换时，需要保存/恢复：
      - 寄存器（包括 SP 指向的栈顶）
      - 程序计数器 (PC)
      - 栈内容
    - 即 Thread Context = PC + SP + Registers + Stack
    - 因此在线程模型中：
      - 线程 = 执行流 + 栈 + 寄存器上下文
      - 栈是线程（CPU 调度实体）固有的一部分
    - *困惑：堆栈是内存资源，但却是CPU调度对象的属性*
    - *有可能把堆栈从CPU调度对象中去除吗？*
      - 这就是协程 Coroutine 的核心突破
        - 线程：CPU 调度对象 = 必须拥有自己的栈
          - CPU 调度线程 → 切换线程 → 恢复线程栈；因此线程必须持有栈。
        - 协作式调度对象 = 不一定需要拥有独立栈
          - 协程的创新点是：协程不一定是 CPU 调度对象；协程的调度，不需要 CPU 参与（非抢占），而是由程序自己切换
]

=== 协程的概念

*线程存在的不足*
- 大规模并发I/O操作场景
  - 大量线程占内存总量大
  - 管理线程程开销大
    - 创建/删除/切换
  - 访问共享数据易错
  #figure(
    image("pic/2025-12-03-22-26-08.png", width: 80%),
    numbering: none,
  )

*协程(coroutine)的提出*
- 协程由Melvin Conway在1963年提出并实现
  - 作者对协程的描述是“行为与主程序相似的子例程(subroutine)”
  - 协程采用同步编程方式支持大规模并发I/O异步操作
- Donald Knuth ：子例程是协程的特例
  #figure(
    image("pic/2025-12-03-22-26-25.png", width: 80%),
    numbering: none,
  )

*协程（Stackless Coroutine）的定义*
- 本课程中的协程限指无栈协程。
- 协程是一种通过*状态机*来管理执行流上下文，以支持在*指定位置挂起和恢复执行流*的轻量级并发编程结构。
- 协程的核心思想：控制流的主动让出与恢复

*协程（异步函数）与函数（同步函数）*
- 相比普通函数，协程的函数体可以挂起并在任意时刻恢复执行
  - 无栈协程是普通函数的泛化
  #figure(
    image("pic/2025-12-03-22-26-50.png", width: 80%),
    numbering: none,
  )
  - 普通函数（同步）
    ```
    call → ...... → return
    ```
  - 协程（异步，有挂起点）
    ```
    call → suspend → resume → suspend → resume → return
    ```

*协程与用户线程的比较*
- 协程的内存占用比线程小
  - 线程数量越多，协程的性能优势越明显
- 不需要多线程的锁机制，不存在同时写变量冲突，在协程中控制共享资源不加锁，只需要判断状态，所以执行效率比多线程高很多
  #figure(
    image("pic/2025-12-03-22-37-03.png", width: 80%),
    numbering: none,
  )
- 协程*不是操作系统调度对象*，调度由：
  - 用户态运行时控制
  - 不需要内核参与

*协程示例(python)*
```python
def func()://普通函数
  print("a")
  print("b")
  print("c")

def func()://协程函数
  print("a")
  yield
  print("b")
  yield
  print("c")
```
#figure(
  image("pic/2025-12-03-22-37-48.png", width: 30%),
  numbering: none,
)
协程的本质：状态机 + 调度器
- 在实现意义上：
  - 无栈协程本质是 编译器把协程拆成状态机
  - 挂起点（await/yield）变成状态跳转
  - 一个事件循环（reactor）负责恢复协程
- 这是 async/await 的底层机制。

=== 协程的实现

*协程的实现方式*
- 2004年Lua的作者Ana Lucia de Moura和Roberto Ierusalimschy发表论文“Revisiting Coroutines”，提出依照三个因素来对协程进行分类：
  - 控制传递（Control-transfer）机制
  - 栈式（Stackful）构造
  - 编程语言中第一类（First-class）对象
*基于控制传递的协程*
- 控制传递机制：对称（Symmetric） v.s. 非对称（Asymmetric）协程
- *对称协程*：控制流是双向的，没有固定的主-从关系
  - 只提供一种*传递*操作，用于在协程间直接传递控制
  - 对称协程都是*平等*的，控制权直接在对称协程之间进行传递
  - 对称协程在挂起时主动指明另外一个对称协程来接收控制权
    ```
    A → B
    B → C
    C → A
    ```
- *非对称协程*（半对称(Semi-symmetric)协程）：主-从协程
  - 提供*调用和挂起*两种操作，非对称协程挂起时将控制返回给调用者
  - 调用者或上层管理者根据某调度策略调用其他非对称协程
  ```
  main → coroutine → main → coroutine → main
  ```
- *对称协程的控制传递：每个协程可直接转移到其他任何一个协程*
  #figure(
    image("pic/2025-12-03-22-42-15.png", width: 80%),
    numbering: none,
  )
- *非对称协程的控制传递：只能将控制权“yield”回给启动它的协程*
  #figure(
    image("pic/2025-12-03-22-43-04.png", width: 80%),
    numbering: none,
  )
- *对称协程*
  - *对称协程*是指所有协程都是对等的，每个协程可以主动挂起自己，并让出处理器给其他协程执行。对称协程*不需要操作系统内核的支持，可以在用户空间中实现*，具有更快的上下文切换速度和更小的内存开销。
    - 优点：简单易用，没有复杂的调度逻辑。
    - 缺点：如果某个协程死循环或阻塞，会导致整个进程挂起。
- *非对称协程*
  - 非对称协程是指*协程和线程一起使用，协程作为线程的子任务来执行*。只有线程可以主动挂起自己，而协程则由线程控制其执行状态。
    - 优点：
      - 支持并发执行，可以通过多线程实现更高的并发性。
      - 协程之间不会相互阻塞，可处理一些长时间任务。
    - 缺点：
      - 实现较为复杂。
      - 需要通过锁等机制来保证协程之间的同步和互斥。
*有栈(stackful)协程和无栈(stackless)协程*
- 无栈协程：指可挂起/恢复的*函数*
  - 无独立的上下文空间（栈），数据保存在堆上
  - 开销：函数调用的开销
- 有栈协程：用户态管理并运行的*线程*
  - 有独立的上下文空间（栈）
  - 开销：用户态切换线程的开销

*基于第一类语言对象的协程*
- 第一类（First-class）语言对象：First-class对象 v.s. second-class对象 (是否可以作为参数传递)
- First-class对象 : 协程被在语言中作为first-class对象
  - 可作为参数被传递，由函数创建并返回，并存储在一个数据结构中供后续操作
  - 提供了良好的编程表达力，方便开发者对协程进行操作
- 受限协程
  - 特定用途而实现的协程，协程对象限制在指定的代码结构中
*第一类（First-class）语言对象*
- 可被赋值给一个变量
- 可嵌入到数据结构中
- 可作为参数传递给函数
- 可作为值被函数返回
- First-class 对象优势：
  - 可作为函数参数传递，使得代码更加灵活
  - 可作为函数返回值返回，方便编写高阶函数
  - 可被赋值给变量或存储在数据结构中，方便编写复杂的数据结构
- First-class 对象劣势：
  - 可能会增加程序的开销和复杂度
  - 可能存在安全性问题，例如对象被篡改等
  - 可能会导致内存泄漏和性能问题
*第二类（Second-class）语言对象：不能将其作为参数传递*
- Second-class 对象优势：
  - 可以通过类型系统来保证程序的正确性
  - 可以减少程序的复杂度和开销
  - 可以提高程序的运行效率和性能
- Second-class 对象劣势：
  - 缺乏灵活性，不能像 First-class 对象一样灵活使用
  - 不太适合处理复杂的数据结构和算法
  - 不支持函数式编程和面向对象编程的高级特性（例如不支持多态）

*Rust语言中的协程Future*
- A future is a representation of some operation which will complete in the future.
- Rust 的 Future 实现了 Async Trait，它包含了三个方法：
  - `poll`: 用于检查 `Future` 是否完成。
  - `map`: 用于将 `Future` 的结果转换为另一个类型。
  - `and_then`: 用于将 `Future` 的结果传递给下一个 `Future`。
- 使用 `Future` 时，可以通过链式调用的方式对多个异步任务进行串联。
  ```rust
  use futures::future::Future;

  fn main() {
      let future1 = async { 1 + 2 };
      let future2 = async { 3 + 4 };

      let result = future1
          .and_then(|x| future2.map(move |y| x + y))
          .await;

      println!("Result: {}", result);
  }
  ```
  #figure(
    image("pic/2025-12-03-22-54-17.png", width: 60%),
    numbering: none,
  )
- *基于有限状态机的Rust协程实现*
  ```rust
  async fn example(min_len: usize) -> String {
      let content = async_read_file("foo.txt").await;
      if content.len() < min_len {
          content + &async_read_file("bar.txt").await
      } else {
          content
      }
  }
  ```
  #figure(
    image("pic/2025-12-03-22-54-57.png", width: 80%),
    numbering: none,
  )
- 基于有限状态机（FSM）的 Stackless Coroutine
  - 编译器将 async 函数变成：
    ```
    enum StateMachine {
        Start,
        AfterFoo,
        AfterBar,
    }
    ```
  - `poll()` 调用会不断驱动状态机前进：
    ```
    Pending → Pending → Ready(Output)
    ```

*基于轮询的 Future的异步执行过程*
#figure(
  image("pic/2025-12-03-22-55-14.png", width: 80%),
  numbering: none,
)
- 轮询 poll()
  - Executor 主动问 future：`你准备好了吗？`
  - 答复：`Pending（继续等） 或 Ready（可以返回）`
- 等待
  - Future 告诉 reactor：`帮我监听某个事件（如一个 socket）`
- 唤醒
  - 事件发生 → Reactor 调用 Future 的 waker → Future 再次进入可调度队列
- 最终形成：`poll → Pending → 等待 → 唤醒 → poll → Ready`

*协程的优点*
- 协程创建成本小，降低了内存消耗
- 协程自己的调度器，减少了 CPU 上下文切换的开销，提高了 CPU 缓存命中率
- 减少同步加锁，整体上提高了性能
- 可按照同步思维写异步代码
  - 用同步的逻辑，写由协程调度的回调

*协程 vs 线程 vs 进程*
- 切换
  - 进程：页表，堆，栈，寄存器
  - 线程：栈，寄存器
  - 协程：寄存器，不换栈
  #figure(
    image("pic/2025-12-03-22-56-48.png", width: 80%),
    numbering: none,
  )
  #three-line-table[
    | 特性     | 进程          | 线程       | 协程        |
    | ------ | ----------- | -------- | --------- |
    | 切换成本   | 高（页表+栈+寄存器） | 中（栈+寄存器） | 极低（有限状态机） |
    | 是否内核参与 | 是           | 是        | 否         |
    | 是否可抢占  | 可抢占         | 可抢占      | 不可抢占（协作式） |
    | 最佳场景   | 隔离性         | CPU 并发   | I/O 并发    |
    | 数量级    | 上千          | 上万       | 上百万       |
  ]
- 协程适合IO密集型场景
  #figure(
    image("pic/2025-12-03-22-57-06.png", width: 80%),
    numbering: none,
  )

=== 协程示例

*支持协程的编程语言*
- 无栈协程：Rust、C++20、C、Python、Java、Javascript等
- 有栈协程（即线程）：Go、Java2022、Python、Lua
- *GO协程(goroutine)*
  ```go
  ... //https://gobyexample-cn.github.io/goroutines
  func f(from string) {
      for i := 0; i < 3; i++ {
          fmt.Println(from, ":", i)
      }
  }
  func main() {
      f("direct")
      go f("goroutine")
      go func(msg string) {
          fmt.Println(msg)
      }("going")
      time.Sleep(time.Second)
      fmt.Println("done")
  }
  ```
- *python协程*
  ```python
  URL = 'https://httpbin.org/uuid'
  async def fetch(session, url):
      async with session.get(url) as response:
          json_response = await response.json()
          print(json_response['uuid'])
  async def main():
      async with aiohttp.ClientSession() as session:
          tasks = [fetch(session, URL) for _ in range(100)]
          await asyncio.gather(*tasks)
  def func():
      asyncio.run(main())
  ```
- *Rust协程*
  ```rust
  use futures::executor::block_on;

  async fn hello_world() {
      println!("hello, world!");
  }

  fn main() {
      let future = hello_world(); // Nothing is printed
      block_on(future); // `future` is run and "hello, world!" is printed
  }
  ```
- *Rust线程与协程的示例*
  - Multi-threaded concurrent webserver
    ```rust
    fn main() {
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap(); // bind listener
        let pool = ThreadPool::new(100); // same number as max concurrent requests

        let mut count = 0; // count used to introduce delays

        // listen to all incoming request streams
        for stream in listener.incoming() {
            let stream = stream.unwrap();
            count = count + 1;
            pool.execute(move || {
                handle_connection(stream, count); // spawning each connection in a new thread
            });
        }
    }
    ```
  - Asynchronous concurrent webserver
    ```rust
    #[async_std::main]
    async fn main() {
        let listener = TcpListener::bind("127.0.0.1:8080").await.unwrap(); // bind listener
        let mut count = 0; // count used to introduce delays

        loop {
            count = count + 1;
            // Listen for an incoming connection.
            let (stream, _) = listener.accept().await.unwrap();
            // spawn a new task to handle the connection
            task::spawn(handle_connection(stream, count));
        }
    }
    ```
    ```rust
    fn main() { //Asynchronous multi-threaded concurrent webserver
        let listener = TcpListener::bind("127.0.0.1:8080").unwrap(); // bind listener

        let mut pool_builder = ThreadPoolBuilder::new();
        pool_builder.pool_size(100);
        let pool = pool_builder.create().expect("couldn't create threadpool");
        let mut count = 0; // count used to introduce delays

        // Listen for an incoming connection.
        for stream in listener.incoming() {
            let stream = stream.unwrap();
            count = count + 1;
            let count_n = Box::new(count);

            // spawning each connection in a new thread asynchronously
            pool.spawn_ok(async {
                handle_connection(stream, count_n).await;
            });
        }
    }
    ```

== 实践：支持线程/协程的OS(TCOS)

=== 实验目标

#figure(
  image("pic/2025-12-09-15-55-52.png", width: 80%),
  numbering: none,
)

*以往目标*
- 提高性能、简化开发、加强安全、支持数据持久保存、支持应用的灵活性，支持进程间交互
- IPC OS：进程间交互
- Filesystem OS：支持数据持久保存
- Process OS: 增强进程管理和资源管理
- Address Space OS: 隔离APP访问的内存地址空间
- multiprog & time-sharing OS: 让APP共享CPU资源
- BatchOS: 让APP与OS隔离，加强系统安全，提高执行效率
- LibOS: 让APP与HW隔离，简化应用访问硬件的难度和复杂性

*进化目标*
- 提高*并发执行效率*，支持线程和协程
  - 在进程内实现多个控制流（线程/协程）的执行
  - 在用户态或内核态管理多个控制流（线程/协程）

=== 用户态管理的用户线程

==== 实践步骤

#figure(
  image("pic/2025-12-09-16-04-51.png", width: 80%),
  numbering: none,
)

*如何管理协程/线程/进程？*
- 任务上下文
- 用户态管理
- 内核态管理

*用户态管理线程的任务控制块*
- 与任务控制块类似
- 由用户态的Runtime管理
  ```rust
  struct Task {
      id: usize,
      stack: Vec<u8>,
      ctx: TaskContext,
      state: State,
  }
  ```

*实践步骤*
```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch8
```
包含一个应用程序
```
user/src/bin/
├──  stackful_coroutine.rs
```
执行这个应用程序
```
Rust user shell
>> stackful_coroutine
stackful_coroutine begin...
TASK  0(Runtime) STARTING
TASK  1 STARTING
task: 1 counter: 0
TASK 2 STARTING
task: 2 counter: 0
TASK 3 STARTING
task: 3 counter: 0
TASK 4 STARTING
task: 4 counter: 0
...
```

==== 用户态管理的线程结构

*简单的用户态管理多线程应用*
- 简单的用户态管理多线程应用 `stackful_coroutine.rs`
  ```rust
  pub fn main()  {
      let mut runtime = Runtime::new(); //创建线程管理子系统
      runtime.init();  // 初始化线程管理子系统
      runtime.spawn(|| {  //创建一个用户态线程
          println!("TASK  1 STARTING");
          let id = 1;
          for i in 0..4 {
              println!("task: {} counter: {}", id, i);
              yield_task();  //主动让出处理器
          }
          println!("TASK 1 FINISHED");
      }); //... 继续创建第2~4个用户态线程
      runtime.run(); //调度执行各个线程
  }
  ```
*用户态管理的线程结构与执行状态*
- 线程控制块
  ```rust
  struct Task { //线程控制块
      id: usize,
      stack: Vec<u8>,
      ctx: TaskContext,
      state: State,
  }
  ```
- 线程上下文
  ```rust
  pub struct TaskContext { //线程上下文
      x1: u64,  //ra: return addres
      x2: u64,  //sp
      ...,  //s[0..11] 寄存器
      nx1: u64, //new return addres
  }
  ```
- 线程状态
  ```rust
  enum State { //线程状态
      Available,
      Running,
      Ready,
  }
  ```

==== 用户态管理的线程控制接口和实现

*用户态线程管理运行时初始化*
- `Runtime::new()` 主要有三个步骤：
  - 设置主线程：初始化应用主线程控制块（TID为 0 ），并设置其状态为 Running；
  - 设置调度队列：初始化线程控制块向量(线程调度队列)，加入应用主线程控制块和空闲线程控制块，为后续的线程运行做好准备；
  - 设置当前运行线程id：设置Runtime 结构变量中的 current 值为0， 表示当前正在运行的线程是应用主线程。
*用户态线程管理运行时初始化*
- `Runtime::init()` 把Rutime结构变量的地址赋值给全局可变变量`RUNTIME`，以便在后续执行中会根据`RUNTIME`找到对应的Runtime结构变量。
- 在应用的 main() 函数中，首先会依次调用上述两个函数（new和init），完成线程管理运行时的初始化过程。这样正在运行的TID为 0 的主线程就可代表线程运行时进行后续创建线程等一系列工作。
*用户态管理的线程创建*
```rust
    pub fn spawn(&mut self, f: fn()) { // f函数是线程入口
        let available = self
            .tasks.iter_mut()  //遍历队列中的任务
            .find(|t| t.state == State::Available) //查找可用的任务
            .expect("no available task.");
        let size = available.stack.len();
        unsafe {
            let s_ptr = available.stack.as_mut_ptr().offset(size as isize);
            let s_ptr = (s_ptr as usize & !7) as *mut u8; // 栈按8字节对齐
            available.ctx.x1 = guard as u64;  //ctx.x1  is old return address
            available.ctx.nx1 = f as u64;     //ctx.nx2 is new return address
            available.ctx.x2 = s_ptr.offset(-32) as u64; //cxt.x2 is sp
        }
        available.state = State::Ready; //设置任务为就绪态
    }
}
```
- 在线程向量中查找一个状态为 Available 的空闲线程控制块
- 初始化该空闲线程的线程控制块的线程上下文
  - `x1`寄存器：老的返回地址 -- `guard`函数地址
  - `nx1`寄存器：新的返回地址 -- 输入参数 `f` 函数地址
  - `x2`寄存器：新的栈地址 -- available.stack+size
```rust
fn guard() {
    unsafe {
        let rt_ptr = RUNTIME as *mut Runtime;
        (*rt_ptr).t_return();
    };
}
fn t_return(&mut self) {
    if self.current != 0 {
        self.tasks[self.current].state = State::Available;
        self.t_yield();
    }
}
```
`guard`函数意味着传入的`f`函数（线程的主体）已经返回，线程已完成运行任务，进而取消引用我们的运行时并调用`t_return()`。

*用户态管理的线程切换*
- 当应用要切换线程时，会调用 `yield_task` 函数，通过 `runtime.t_yield` 函数来完成具体的切换过程。`runtime.t_yield()` 函数主要完成的功能：
  - 在线程向量中查找一个状态为 Ready 的线程控制块
  - 把当前运行的线程的状态改为Ready，把新就绪线程的状态改为Running，把 runtime 的 current 设置为新就绪线程控制块的id
  - 调用函数 `switch` ，完成两个线程的栈和上下文的切换；
  ```rust
  fn t_yield(&mut self) -> bool {
          ...
      self.tasks[pos].state = State::Running;
      let old_pos = self.current;
      self.current = pos;

      unsafe {
          switch(&mut self.tasks[old_pos].ctx, &self.tasks[pos].ctx);
      }
      ...
  ```
*switch主要完成的工作*
- 完成当前指令指针(PC)的切换；
- 完成栈指针的切换；
- 完成通用寄存器集合的切换；
  ```rust
  unsafe fn switch(old: *mut TaskContext, new: *const TaskContext)  {
      // a0: _old, a1: _new
      asm!("
          sd x1, 0x00(a0)
          ...
          sd x1, 0x70(a0)
          ld x1, 0x00(a1)
          ...
          ld t0, 0x70(a1)
          jr t0
      ...
  ```
*用户态管理的线程执行&调度*
```rust
    pub fn run(&mut self){
        while self.t_yield() {}
       println!("All tasks finished!");
    }
```

=== 内核态管理的用户线程

==== 实践步骤

*内核态管理的用户线程的线程控制块*
- 与任务控制块类似
- 重构：进程中有多个代表线程的任务控制块
  ```rust
  pub struct ProcessControlBlockInner {
      pub tasks: Vec<Option<Arc<TaskControlBlock>>>,
      ...
  }
  ```
*实践步骤*
```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch8
```
包含几个与内核态管理的用户线程相关的应用程序
```
user/src/bin/
├──  threads.rs
├──  threads_arg.rs
```
执行`threads_arg`应用程序
```
Rust user shell
>> threads_arg
aaa...bbb...ccc...aaa...bbb...ccc...
thread#1 exited with code 1
thread#2 exited with code 2
ccc...thread#3 exited with code 3
main thread exited.
...
```

==== 内核态管理的线程控制接口

*简单的内核态管理多线程应用*
- 简单的内核态管理多线程应用`threads_arg.rs`
  ```rust
  fn thread_print(arg: *const Argument) -> ! { //线程的函数主体
      ...
      exit(arg.rc)
  }
  pub fn main() -> i32 {
      let mut v = Vec::new();
      for arg in args.iter() {
          v.push(thread_create( thread_print, arg ));  //创建线程
      ...
      for tid in v.iter() {
          let exit_code = waittid(*tid as usize); //等待线程结束
      ...
  }
  ```
*创建线程系统调用*
- 进程运行过程中，可创建多个属于这个进程的线程，每个线程有自己的线程标识符（TID，Thread Identifier）。
- 系统调用 `thread_create` 的原型：
  ```rust
  /// 功能：当前进程创建一个新的线程
  /// 参数：entry 表示线程的入口函数地址
  /// 参数：arg：表示线程的一个参数
  pub fn sys_thread_create(entry: usize, arg: usize) -> isize
  ```
  - 创建线程不需要建立新的地址空间
  - 属于同一进程中的线程之间没有父子关系
*线程退出系统调用*
- 线程执行完代表它的功能后，会通过 exit 系统调用退出。进程/主线程调用 waittid 来回收其资源，来彻底销毁整个线程。
- 系统调用 `waittid` 的原型：
  ```rust
  /// 参数：tid表示线程id
  /// 返回值：如果线程不存在，返回-1；如果线程还没退出，返回-2；其他情况下，返回结束线程的退出码
  pub fn sys_waittid(tid: usize) -> i32
  ```
  - 进程/主线程通过 waittid 来等待它创建出来的线程（不是主线程）结束并回收它们在内核中的资源
  - 如果进程/主线程先调用了 exit 系统调用来退出，那么整个进程（包括所属的所有线程）都会退出

==== 线程管理与进程管理

*线程管理与进程管理的关系*
- 引入了线程机制后，进程相关的重要系统调用：fork 、 exec 、 waitpid 接口上没有变化，但*完成的功能上需要有一定的扩展*。
  - 把以前进程中与处理器执行相关的部分拆分到线程中
  - fork 创建进程意味着要单独建立一个主线程来使用处理器，并为以后创建新的线程建立相应的线程控制块向量
  - exec 和 waitpid 改动较少，还是按照与之前进程的处理方式来进行
- 进程相关的这三个系统调用还是保持了已有的进程操作的语义，并没有由于引入了线程，而带来大的变化

*fork与多个线程*
- 问题：“被fork的子进程是否要复制父进程的多个线程？”
  - 选择A：要复制多个线程；
  - 选择B：不复制，只复制当前执行fork的这个线程；
  - 选择C：不支持多线程进程执行fork这种情况
- 目前的rcore tutorial ，选择了C，简化了应用的使用场景，即在使用fork和create_thread（以及基于线程的信号量，条件变量等）是不会同时出现的。如果有fork，假定是这个应用是单线程的进程，所以只拷贝了这个单线程的结构。这种简化设计虽然是一种鸵鸟做法，但也避免了一些允许fork和create_thread共存而导致的比较复杂的情况：...

*fork与多个线程*
- 场景：在fork前，有三个线程Main thread， thread X, thread Y, 且Thread X拿到一个lock，在临界区中执行；Thread Y正在写一个文件。Main thread执行fork.
  - 选择A：会出现子进程的Thread Y和 父进程的Thread Y都在写一个文件的情况。
  - 选择B，则子进程中只有Main Thread，当它想得到Thread X的那个lock时，这个lock是得不到的（因为Thread X 在子进程中不存在，没法释放锁），会陷入到持续忙等中。

==== 内核态管理的线程的实现

*线程管理数据结构*
- 改进现有进程管理的一些数据结构包含的内容及接口，把进程中与处理器相关的部分分拆出来，形成线程相关的部分。
  - 任务控制块 `TaskControlBlock` ：表示线程的核心数据结构
  - 任务管理器 `TaskManager` ：管理线程集合的核心数据结构
  - 处理器管理结构 `Processor` ：用于线程调度，维护线程的处理器状态

*线程控制块*
```rust
pub struct TaskControlBlock {
    pub process: Weak<ProcessControlBlock>, //线程所属的进程控制块
    pub kstack: KernelStack,//任务（线程）的内核栈
    inner: UPSafeCell<TaskControlBlockInner>,
}
pub struct TaskControlBlockInner {
    pub res: Option<TaskUserRes>,  //任务（线程）用户态资源
    pub trap_cx_ppn: PhysPageNum,//trap上下文地址
    pub task_cx: TaskContext,//任务（线程）上下文
    pub task_status: TaskStatus,//任务（线程）状态
    pub exit_code: Option<i32>,//任务（线程）退出码
}
```
#newpara()
*进程控制块*
```rust
pub struct ProcessControlBlock {
    pub pid: PidHandle,
    inner: UPSafeCell<ProcessControlBlockInner>,
}
pub struct ProcessControlBlockInner {
    pub tasks: Vec<Option<Arc<TaskControlBlock>>>,
    pub task_res_allocator: RecycleAllocator,
    ...
}
```
RecycleAllocator是PidAllocator的升级版，即一个相对通用的资源分配器，可用于分配进程标识符（PID）和线程的内核栈（KernelStack）。

*线程创建`sys_thread_create`*
- 当一个进程执行中发出系统调用 `sys_thread_create` 后，操作系统就需要在当前进程的基础上创建一个线程，即在线程控制块中初始化各个成员变量，建立好进程和线程的关系等，关键要素包括：
  - 线程的用户态栈：确保在用户态的线程能正常执行函数调用
  - 线程的内核态栈：确保线程陷入内核后能正常执行函数调用
  - 线程的跳板页：确保线程能正确的进行用户态<–>内核态切换
  - 线程上下文：即线程用到的寄存器信息，用于线程切换
  ```rust
  pub fn sys_thread_create(entry: usize, arg: usize) -> isize {
      // create a new thread
      let new_task = Arc::new(TaskControlBlock::new(...
      // add new task to scheduler
      add_task(Arc::clone(&new_task));
      // add new thread to current process
      let tasks = &mut process_inner.tasks;
      tasks[new_task_tid] = Some(Arc::clone(&new_task));
      *new_task_trap_cx = TrapContext::app_init_context( //建立trap/task上下文
          entry,
          new_task_res.ustack_top(),
          kernel_token(),
      ...
  ```
*线程退出`sys_exit`*
- 当一个非主线程的其他线程发出 `sys_exit` 系统调用时，内核会调用 `exit_current_and_run_next` 函数退出当前线程并切换到下一个线程，但不会导致其所属进程的退出。
- 当主线程 即进程发出这个系统调用，当内核收到这个系统调用后，会回收整个进程（这包括了其管理的所有线程）资源，并退出。
  ```rust
  pub fn sys_exit(exit_code: i32) -> ! {
      exit_current_and_run_next(exit_code); ...
  pub fn exit_current_and_run_next(exit_code: i32) {
      let task = take_current_task().unwrap();
      let mut task_inner = task.inner_exclusive_access();
      drop(task_inner); //释放线程资源
      drop(task);  //释放线程控制块
      if tid == 0 {
          // 释放当前进程的所有线程资源
          // 释放当前进程的资源
  ...
  ```
*等待线程结束`sys_waittid`*
- 如果找到 tid 对应的线程，则尝试收集该线程的退出码 exit_tid ，否则返回错误（退出线程不存在）。
- 如果退出码存在(意味该线程确实退出了)，则清空进程中对应此线程的线程控制块（至此，线程所占资源算是全部清空了），否则返回错误（线程还没退出）。
  ```rust
  pub fn sys_waittid(tid: usize) -> i32 {
      ...
      if let Some(waited_task) = waited_task {
          if let Some(waited_exit_code) = waited_task.....exit_code {
              exit_code = Some(waited_exit_code);
          }
      } else {
          return -1; // waited thread does not exist
      }
      if let Some(exit_code) = exit_code {
          process_inner.tasks[tid] = None; //dealloc the exited thread
          exit_code
      } else {
          -2 // waited thread has not exited
      }
  ```
*线程执行中的特权级切换和调度切换*
- 线程执行中的特权级切换与第四讲中介绍的任务切换的设计与实现是一致的
- 线程执行中的调度切换过程与第七讲中介绍的进程调度机制是一致的

== 关于任务模型的思考

#note(subname: [问题])[
  *进程、线程和协程的调度有可能统一起来吗？*
  - 三者的本质差异（为何传统 OS 中不能统一）
    #three-line-table[
      | 类型     | 谁调度      | 切换代价            | 执行栈                        | 阻塞行为     | 内核是否可见    |
      | ------ | -------- | --------------- | -------------------------- | -------- | --------- |
      | *进程* | 内核       | 最重（页表切换）        | 独立用户栈 + 独立地址空间             | 内核阻塞整个进程 | 可见        |
      | *线程* | 内核（或用户态） | 中等（用户栈 / 内核栈切换） | 各有各栈                       | 阻塞该线程    | 可见        |
      | *协程* | *用户态*  | 最轻（寄存器切换）       | 无栈或独立栈（stackless/stackful） | 用户态阻塞    | *内核不可见* |
    ]
    根本差异：
    - 进程和线程属于内核资源调度单位
    - 协程属于用户态运行时的调度单位
    - 协程不能阻塞在内核 API 上（read/write/sleep 等），否则整个线程会阻塞，导致所有协程卡死。
]

=== 操作系统中的任务模型

*如何描述CPU上的执行流及其生命周期的状态变化？*
- 进程(Process)是一个具有一定独立功能的程序在一个数据集合上的一次动态执行过程。也称为任务(Task)。
  - 进程 = 程序 + 执行状态
- 线程是操作系统调度调度的指令执行流的最小单元。
- CPU调度基本单位的演化
  - 进程
  - 线程（包括栈）+ 进程（资源）
  - 协程+进程（栈、资源）

*关于执行流的几个刁钻问题*
- 中断处理函数是线程吗？
  - 不是线程。中断服务例程（ISR）具有以下特点：
    - 没有独立的栈（使用当前正在运行线程/进程的内核栈）
    - 没有独立的调度权
    - 没有独立的执行上下文（只是一段代码，中断到来时执行）
    - 不能被 OS 正常调度
  - 它属于：硬件强制执行的、附着在当前线程上的临时执行流
- 内核是一个进程吗？
  - 内核有自己独立的页表
  - 内核的地址空间是共享的
  - 内核是一个特殊的进程，或者所有进行共享的部分
- 调度器的功能是进程调度。调度代码算是哪个进程（线程、协程）的？
  - 调度器属于“内核执行流的一部分”

*并发机制*
- 内核线程：内核实现
- 用户线程：用户库实现、语言支持
- 协程：用户库实现、语言支持

*上下文切换与调度器：执行流控制*
- 中断上下文保存与恢复：基于中断（硬件）
- 进程切换：基于时钟中断、主动让权（应用、内核）
- 线程切换：基于时钟中断、主动让权
- 协程切换：主动让权（语言）

*异常和错误处理*
- 内核中断机制：硬件与操作系统协作
  - 用户态中断：硬件、操作系统和应用协作管理
- rust中的option：程序设计语言管理
- 信号：操作系统和应用协作管理

*操作系统课描述执行流的词汇*
- task任务、job作业、process进程、LWP轻权进程
- thread线程（user-level thread用户级线程、kernel-level thread内核级线程）、hyperthread超线程、fiber纤程
- function函数、subroutine子程序、subprogram子程序、coroutine协程（stackless coroutine无栈协程、stackful coroutine有栈协程）、
- context上下文（函数调用上下文、trap context中断上下文、process context进程上下文、thread context线程上下文）

*时钟中断*
- 时钟中断是由硬件时钟设备产生的一种按设定时间间隔触发的中断信号，用于CPU资源的分时复用。
  #figure(
    image("pic/2025-12-09-19-09-20.png", width: 80%),
    numbering: none,
  )
  - 问题：中断处理函数的执行是一个独立的执行流吗？
    - 是的，可以看作外部设备调用的中断服务函数的函数调用

*信号（Signal）*用户态的异常处理机制
- 信号（Signal）响应时机
  - 发送信号并没有发生硬中断，只是把信号挂载到目标进程的信号 pending 队列
  - 信号执行时机：进程执行完异常/中断返回用户态的时刻

*函数调用栈（Call Stack）*
- 函数调用栈（Call Stack）记录了当前执行流正在执行的函数状态和函数调用顺序。
  - 问题：每个函数的执行是一个独立的执行流吗？
    - 是的，函数调用子函数认为是一个切换

*系统调用 (System Call)*
- 系统调用是内核向用户程序提供服务的受控访问接口。系统调用可通过中断或陷入机制实现，用户程序执行特殊指令会引发中断，将 CPU 控制权转移到内核。
  #figure(
    image("pic/2025-12-09-19-25-13.png", width: 80%),
    numbering: none,
  )

*进程切换*
- 先切换特权级、再切换进程上下文
  - 问题：
    - 每个地址空间只能有一个执行流吗？
    - 第一个用户进程如何创建?
      - 内核启动
      - 内核创建第一个进程的地址空间
      - 加载 user init 程序
      - 创建它的第一个 TCB（主线程）
      - 调度它运行
  #figure(
    image("pic/2025-12-09-19-25-41.png", width: 80%),
    numbering: none,
  )
- *挑战*
  - 进程切换开销、并发执行性能
    - 为什么进程切换只能在内核态进行？
    - 进程概念依赖的硬件支持？
    - 硬件可能直接支持进程切换吗？
    - 进程的实现目前只是由操作系统内核支持，可能在用户态支持吗？
    - 硬件感知到什么程度？

*线程概念*
- 线程是进程的*一部分*，描述指令流*执行状态*。它是进程中的指令执行流的基本单元，是*CPU调度的基本单位*。
- 挑战
  - 超线程在操作系统看来是什么？
  - 线程实现可能在用户库（语言支持）、内核支持、CPU硬件支持吗？它们能结合吗？
  - 高并发场景下栈开销？
  - 栈到底算是内存资源的一种，还是执行流的上下文？
  - 中断处理函数（程序）是一个独立的线程吗？

*协程的概念*
- 有栈协程：与用户级线程是等价的概念
- 无线协程：把栈视为CPU执行需要的资源，而不是附属于执行流的资源；实现栈复用；
- 同步函数和异步函数：区分函数执行中的暂停支持机制；
- 挑战：Rust、C++和Java等语言支持协程。
  - 操作系统和CPU硬件都不感知协程。可以感知吗？
  - 操作系统和CPU感知协程能带来什么好处？

=== 异步操作系统
