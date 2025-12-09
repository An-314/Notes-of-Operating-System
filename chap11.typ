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
  int pthread_join(pthread_t thread, void **retval);
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
- 由一组用户级的线程库函数来完成线程的管理，包括线程的创建、终止、同步和调度等

*用户态管理线程的优点*
- 线程的调度不需要内核直接参与，控制简单
- 可以在不支持线程的操作系统中实现
- 创建和销毁线程、线程切换等线程管理的代价比内核线程少得多
- 允许每个进程定制自己的调度算法，线程管理比较灵活
- 同一进程中只能同时有一个线程在运行，如果有一个线程使用了系统调用而阻塞，那么整个进程都会被挂起C

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
- 不同进程中的线程切换：进程上下文（如页表等）需要切换
- 相同进程中的线程切换：虚拟内存等进程资源不需切换，只需要切换线程的私有数据、寄存器等不共享的数据

*内核态管理且用户态运行线程的不足*
- 在一般情况下，线程切换开销与进程切换开销相差不大，大于用户态管理且用户态允许的线程切换开销
- 与传统的进程管理机制会产生一些矛盾，一些系统调用的实现功能/语义上会不协调
  - fork()、signal() ...

*多线程fork()引起的问题*
- 多线程应用程序中，建议谨慎使用 fork()
  - 竞态条件：线程正在修改共享变量或资源时调用了fork()，会导致子进程继承这个状态和资源的不一致性。例如全局变量被多个线程修改
  - 死锁：线程正在持有某个锁或资源时调用fork()，可能导致子进程无法获得该锁而导致死锁。例如子进程中没有持有锁的线程会死锁。
  - 内存占用：多线程fork()会复制整个进程的地址空间，包括所有线程所拥有的栈、寄存器和锁等资源
  - 性能下降：多线程fork()的开销较大，可能会影响应用程序的性能
- 可采用：限制线程中调用 fork()、使用 pthread_atfork() 在 fork() 前后统一加/解锁来防止子进程死锁等方法，来避免这些问题。

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
- 编程人员决定内核线程与用户级线程的对应关系
- 用户级线程由用户线程管理库管理
- 内核只识别内核级线程/进程，并对其进行调度
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

== 协程（Coroutine）

#note(subname: [问题])[
  - 堆栈必须是CPU调度对象的属性吗？
    - 困惑：堆栈是内存资源，但却是CPU调度对象的属性
    - 有可能把堆栈从CPU调度对象中去除吗？
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
- 协程是一种通过状态机来管理执行流上下文，以支持在指定位置挂起和恢复执行流的轻量级并发编程结构。
- 协程的核心思想：控制流的主动让出与恢复

*协程（异步函数）与函数（同步函数）*
- 相比普通函数，协程的函数体可以挂起并在任意时刻恢复执行
  - 无栈协程是普通函数的泛化
  #figure(
    image("pic/2025-12-03-22-26-50.png", width: 80%),
    numbering: none,
  )

*协程与用户线程的比较*
- 协程的内存占用比线程小
  - 线程数量越多，协程的性能优势越明显
- 不需要多线程的锁机制，不存在同时写变量冲突，在协程中控制共享资源不加锁，只需要判断状态，所以执行效率比多线程高很多
  #figure(
    image("pic/2025-12-03-22-37-03.png", width: 80%),
    numbering: none,
  )

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
  image("pic/2025-12-03-22-37-48.png", width: 80%),
  numbering: none,
)

=== 协程的实现

*协程的实现方式*
- 2004年Lua的作者Ana Lucia de Moura和Roberto Ierusalimschy发表论文“Revisiting Coroutines”，提出依照三个因素来对协程进行分类：
  - 控制传递（Control-transfer）机制
  - 栈式（Stackful）构造
  - 编程语言中第一类（First-class）对象
*基于控制传递的协程*
- 控制传递机制：对称（Symmetric） v.s. 非对称（Asymmetric）协程
- 对称协程：控制流是双向的，没有固定的主-从关系
  - 只提供一种传递操作，用于在协程间直接传递控制
  - 对称协程都是平等的，控制权直接在对称协程之间进行传递
  - 对称协程在挂起时主动指明另外一个对称协程来接收控制权
- 非对称协程（半对称(Semi-symmetric)协程）：主-从协程
  - 提供调用和挂起两种操作，非对称协程挂起时将控制返回给调用者
  - 调用者或上层管理者根据某调度策略调用其他非对称协程
*对称协程的控制传递：每个协程可直接转移到其他任何一个协程*
#figure(
  image("pic/2025-12-03-22-42-15.png", width: 80%),
  numbering: none,
)
*非对称协程的控制传递：只能将控制权“yield”回给启动它的协程*
#figure(
  image("pic/2025-12-03-22-43-04.png", width: 80%),
  numbering: none,
)
*对称协程*
- 对称协程是指所有协程都是对等的，每个协程可以主动挂起自己，并让出处理器给其他协程执行。对称协程不需要操作系统内核的支持，可以在用户空间中实现，具有更快的上下文切换速度和更小的内存开销。
  - 优点：简单易用，没有复杂的调度逻辑。
  - 缺点：如果某个协程死循环或阻塞，会导致整个进程挂起。
*非对称协程*
- 非对称协程是指协程和线程一起使用，协程作为线程的子任务来执行。只有线程可以主动挂起自己，而协程则由线程控制其执行状态。
  - 优点：
    - 支持并发执行，可以通过多线程实现更高的并发性。
    - 协程之间不会相互阻塞，可处理一些长时间任务。
  - 缺点：
    - 实现较为复杂。
    - 需要通过锁等机制来保证协程之间的同步和互斥。
*有栈(stackful)协程和无栈(stackless)协程*
- 无栈协程：指可挂起/恢复的函数
  - 无独立的上下文空间（栈），数据保存在堆上
  - 开销：函数调用的开销
- 有栈协程：用户态管理并运行的线程
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
  - poll: 用于检查 Future 是否完成。
  - map: 用于将 Future 的结果转换为另一个类型。
  - and_then: 用于将 Future 的结果传递给下一个 Future。
- 使用 Future 时，可以通过链式调用的方式对多个异步任务进行串联。
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
    image("pic/2025-12-03-22-54-17.png", width: 80%),
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

*基于轮询的 Future的异步执行过程*
#figure(
  image("pic/2025-12-03-22-55-14.png", width: 80%),
  numbering: none,
)

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
