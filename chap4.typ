#import "@preview/scripst:1.1.1": *

= 多道程序与分时多任务

== 进程和进程模型

#note(subname: [问题])[
  - 操作系统如何管理程序的执行过程？

    在单核 CPU 上，同一时刻实际上只能运行一个指令流（即一条程序指令）。但我们希望多个程序“同时”运行，这就需要操作系统来做管理。这里就引入了*进程（Process）*的概念。
    - *进程的本质*
      - 进程 = 程序 + 执行时的动态环境（运行状态、寄存器内容、内存空间、I/O 等）
        - PID: 进程标识符（Process ID），是操作系统为每个进程分配的唯一标识
      - 程序是静态的代码和数据；进程是程序的动态执行实例
    - *操作系统的职责*
      - *进程的创建与销毁：*负责把一个程序加载进内存并分配资源，运行结束后回收资源
      - *进程的调度：*在多个进程间决定谁先执行、谁后执行。比如采用先来先服务（FCFS）、时间片轮转（RR）、优先级调度等
      - *进程的切换（上下文切换）：*当操作系统决定 CPU 要从一个进程切换到另一个时，需要保存当前进程的上下文（寄存器、程序计数器等），再恢复另一个进程的上下文
      - *进程的通信和同步：*不同进程可能需要交换数据、协调顺序，操作系统提供 IPC（Inter-Process Communication）机制，如管道、消息队列、共享内存、信号量等
      - *资源的分配与保护：*操作系统要为不同进程分配 CPU 时间、内存、文件、I/O 设备，同时避免互相干扰
  - 操作系统关心程序执行中的哪些状态？

    为了管理和调度，操作系统必须记录进程的运行状态。常见的状态模型有：
    - *三态模型*（最基础）
      - 就绪态（Ready）：进程已具备运行条件，只等 CPU
      - 运行态（Running）：进程正在 CPU 上执行
      - 阻塞态（Blocked/Waiting）：进程在等待某个事件（比如 I/O 完成），暂时不能运行
    - *五态模型*（更精细）
      - 新建（New）：进程正在被创建
      - 就绪（Ready）：进程已具备运行条件，只等 CPU
      - 运行（Running）：进程正在 CPU 上执行
      - 阻塞（Blocked/Waiting）：进程在等待某个事件（比如 I/O 完成），暂时不能运行
      - 结束（Terminated/Exit）：进程已完成或被杀死
    - *状态切换*
      - 就绪 → 运行：被调度上 CPU
      - 运行 → 就绪：时间片用完或被抢占
      - 运行 → 阻塞：等待 I/O 或资源
      - 阻塞 → 就绪：等待事件完成
      - 新建 → 就绪：进程创建完成，进入调度队列
      - 运行 → 结束：进程完成或异常退出
]

=== 多道程序与协作式调度

*历史*
- 操作系统的被广泛使用是从大型机向小型机（minicomputer）过渡的时期开始的
  - OS/360是大型机（System/360）时代的多道批处理操作系统
  - 数字设备公司（DEC）的PDP系列小型计算机
- 小型机和多道程序（multiprogramming）成为很普遍的应用场景
  - 一个工作单位内的一群人可能拥有一台计算机
*多道程序（Multiprogramming）*
- 基本思想
  - 在早期的计算机（批处理系统）中，程序是“独占”机器资源的：一个程序没执行完，CPU 就空转等待 I/O，非常浪费
  - 多道程序技术就是在内存中同时装入多个作业（Job），当一个程序等待 I/O 时，CPU 就切换去执行另一个程序，从而提高 CPU 利用率
  ```
  程序 A 在等待磁盘读取；
  操作系统切换去执行程序 B；
  等 A 的磁盘完成后再切回来。
  这样 CPU 和 I/O 能“并行利用”，效率大幅提高。
  ```
- 核心特征
  - *并发（Concurrency）*：多个程序在宏观上“同时运行”，但微观上一个 CPU 还是在做快速切换。
  - *资源共享（Sharing）*：这些程序需要共享 CPU、内存、I/O 设备。
  - *管理机制（Management）*：操作系统必须提供调度、内存管理、I/O 管理等功能。
- 与术语的关系
  - Job（作业）：最早期批处理系统里，一个用户的完整任务（比如“编译并运行一个 Fortran 程序”）就叫作业
  - Task（任务）：后来的称呼，强调它是作业的一部分
  - Multiprogramming：多道程序设计，IBM 在 1960s 提出的概念（System/360 等机型），标志着从单任务 → 多任务的过渡
  - Process（进程）：现代术语，描述程序的一个执行实例
*协作式调度（Cooperative scheduling）*
- 过程
  - 可执行程序*主动放弃*处理器使用
    - 操作系统不会打断正在执行的程序
  - 操作系统*选择下一个作业*使用处理器
- 基本原理
  - 在多道程序系统中，CPU 的分配可以通过调度实现
  - 协作式调度的特点是：*进程主动让出 CPU（主动让权）*
    - 进程运行时，如果它完成了某个阶段或需要等待 I/O，它会主动调用系统调用（比如 `yield`、`wait`），把 CPU 控制权交还给操作系统
    - 操作系统再调度下一个就绪进程
- 优点
  - 实现简单：不需要复杂的硬件支持（不依赖时钟中断来强制抢占）
  - 对程序员“友好”：程序可以控制自己何时放弃 CPU
- 缺点
  - 不可靠：如果一个进程不合作（死循环、不主动让出 CPU），其他程序就无法运行
  - 因此后来出现了*抢占式调度（Preemptive Scheduling）*，由操作系统根据时钟中断强制打断进程，保证公平性和响应性

=== 分时多任务与抢占式调度

*历史*
- 小型机（minicomputer）的普及和广泛使用推动了分时多任务的需求，形成了支持多用户的分时操作系统。
  - DEC公司的PDP、VAX小型机逐渐侵蚀大型机市场
  - DEC公司的VMS操作系统
  - MIT的CTSS操作系统
  - AT&T的UNIX操作系统
*分时多任务（Time Sharing Multitask）*
- *用户视角*
  - 在内存中存在多个可执行程序
  - 各个可执行程序分时*共享处理器*
  - 操作系统按*时间片*（毫秒级）来给各个可执行程序分配CPU使用时间
  - *进程(Process)* ：应用的一次执行过程
- *操作系统视角*
  - *进程(Process) *：一个具有一定*独立功能*的程序在一个*数据集合*上的一次动态*执行过程*；也称为*任务(Task)*
    - 进程 = 程序 + 数据 + 执行状态
    - 一个进程就是一个独立的执行实例
  - 从一个应用程序对应的进程切换到另外一个应用程序对应的进程，称为进程切换
    - 当时间片用完，或者高优先级进程需要运行时，操作系统保存当前进程的上下文（寄存器、程序计数器、堆栈等），再恢复另一个进程的上下文
    - 保存现场（Save Context）
    - 切换 PCB（进程控制块）
    - 恢复现场（Restore Context）

#note(subname: [作业（Job）、任务（Task）和进程（Process）])[
  历史上出现过的术语：Job、Task、Process
  - Task、Process是Multics和UNIX等用于分时多任务提出的概念
  - 进程是一个应用程序的一次执行过程。在操作系统语境下，任务和进程是同义词
  - 作业（目标）是围绕一个共同目标由一组相互关联的程序执行过程（进程、任务）形成的一个整体
]

*抢占式调度（Preemptive Scheduling）*
- 过程
  - 进程*被动*地放弃处理器使用
  - 进程按*时间片*轮流使用处理器，是一种“暂停-继续”组合的执行过程
  - 基于时钟硬件中断机制，操作系统可随时*打断*正在执行的任务
  - 操作系统*选择下一个执行程序*使用处理器
- 本质
  - 抢占式调度是分时多任务的核心机制。
  - 关键点：进程不是主动让出 CPU，而是由操作系统强制打断，剥夺它的 CPU 使用权。

=== 进程的概念

*进程切换*
#figure(
  image("pic/2025-10-16-10-13-54.png", width: 80%),
  numbering: none,
)
*进程的特点*
- *动态性*
  - 开始执行$->$暂停$->$继续$->$结束执行的过程
- *并发性*
  - 一段时间内多个进程在执行
- *有限度的独立性*
  - 进程之间不用感知对方的存在
- 目前还没具备更强大的特点
  - 隔离更彻底、任务间协同工作、任务创建任务......

*进程与程序的组成*

- 进程(任务)与程序的对应关系
  - 进程是操作系统处于执行状态程序的抽象
    - 程序 = 文件 (静态的可执行文件)
    - 进程 = 程序 + 执行状态
  - 同一个程序的多次执行过程对应为不同进程
    - 如命令“ls”的多次执行对应多个进程
  - 进程执行需要的资源
    - 内存：保存代码和数据
    - CPU：执行指令

*进程与程序的区别*
- 进程是动态的，程序是静态的
  - 程序是有序代码的集合
  - 进程是程序的执行
- 进程是暂时的，程序是永久的
  - 进程是一个状态变化的过程
  - 程序可长久保存
- 进程与程序的组成不同
  - *进程*的组成包括*程序、数据和进程控制块*

*进程状态*：进程包含了运行程序的所有状态信息
- 进程执行的*控制流*
  - 代码内容与代码的执行位置（代码段）
- 进程访问的*数据*
  - 被进程读写的内存（堆、栈、数据段）
  - 被进程读写的寄存器
    - 通用寄存器
- 操作系统管理进程的相关数据（进程的*上下文*）
  - 进程切换所需的通用寄存器
  - 进程切换所需的状态寄存器(PC等)
  - 其他信息：进程的栈地址等
  - 其他资源：......

*进程控制块（PCB, Process Control Block）*：操作系统管理进程的核心数据结构，也称为任务控制块（TCB, Task Control Block）
- 操作系统*管理控制进程运行*所用的信息集合
- 操作系统用PCB来描述进程的*基本情况以及运行变化*的过程
- PCB是进程存在的唯一标志
- 每个进程都在操作系统中有一个对应的PCB
#figure(
  image("pic/2025-10-16-10-24-51.png", width: 80%),
  numbering: none,
)

=== 进程模型

- 进程状态：*创建和就绪*
  - 创建 $->$ 就绪
    - 何时创建
      - 用户启动程序（如运行一个命令）
      - 系统创建新任务（如守护进程、后台任务）
      - 父进程通过 `fork()` 派生子进程
    - 如何创建
      - 系统分配进程控制块（PCB, Process Control Block）
      - 分配内存空间、加载程序代码和数据
      - 初始化寄存器、堆栈等运行环境
      - 将进程状态设置为就绪
- 进程状态：*运行*
  - 创建 $->$ 就绪 $->$ 执行
    - 内核选择一个就绪的任务
    - CPU 开始执行该进程的指令，程序计数器 PC 不断更新
- 进程状态：*等待*
  - 创建 $->$ 就绪 $->$ 执行 $->$ 等待
  - 任务进入等待的原因?
    - 自身：主动等待I/O、sleep、等待锁等
    - 外界：被阻塞、资源不可用（如内存不足）
- 进程状态变迁：*唤醒*
  - 创建 $->$ 就绪 $->$ 执行 $->$ 等待 $->$ 唤醒
  - 唤醒任务的原因
    - 自身：等待的事件完成（I/O结束、信号到达）
    - 外界：其他进程或内核主动唤醒
- 进程状态变迁：*抢占*
  - 创建 $->$ 就绪 $->$ 执行 $->$ 抢占
  - 任务被抢占的原因
    - 时间片到期
    - 更高优先级进程到来
  - 被抢占的进程回到就绪队列等待再次调度
- 进程状态：*退出*
  - 创建 $->$ 就绪 $->$ 执行 $->$ ...... $->$ 结束
  - 任务退出的原因
    - 正常结束：程序运行到 `return/exit`
    - 异常结束：非法操作、段错误
    - 外部终止：被 `kill`
  - 退出时系统会：
    - 回收分配的资源（内存、文件描述符等）
    - 从调度队列移除该PCB
    - 通知父进程（`wait()` 或 `waitpid()`）

#figure(
  image("pic/2025-09-29-16-06-11.png", width: 80%),
  caption: [进程的三状态模型],
)

*进程状态变迁与系统调用*
- #three-line-table[
    | 状态变迁              | 触发系统调用 / 事件                             | 说明                    |
    | ----------------- | --------------------------------------- | --------------------- |
    | *创建 → 就绪*       | `fork()`、`exec()`                       | 创建新进程或加载新程序           |
    | *就绪 → 运行*       | （由调度器完成）                                | 非直接系统调用，而是内核调度行为      |
    | *运行 → 等待*       | `sleep()`、`read()`、`wait()`、`pause()` 等 | 进程主动或被动进入阻塞           |
    | *等待 → 就绪（唤醒）*   | 内核事件完成、中断处理                             | I/O完成、信号到达、`wakeup()` |
    | *运行 → 抢占（返回就绪）* | 时钟中断、调度器触发                              | 非用户调用，而是内核自动中断        |
    | *运行 → 退出*       | `exit()`、`_exit()`                      | 正常或异常终止，释放资源          |
    | *被外部终止*         | `kill()`（由其他进程发起）                       | 接收到信号后终止执行            |
  ]
- ```
         fork() / exec()
       ┌───────────────┐
       │          创建 New          │
       └──────┬────────┘
                    │
                    ▼
                  就绪 Ready
                    │
     ┌────────┴───┐
     │                      │
   schedule()             wake_up()
     │                      │
     ▼                      │
    运行 Running ──────┘
     │   │   │
     │   │   │
     │   │   └─→ exit(), kill() → 退出
     │   └─────→ sleep(), read() → 等待
     └──────────→ 抢占 → 就绪

  ```

*进程状态变迁与进程切换*

- #three-line-table[
    | 触发情景  | 状态变化    | 是否发生任务切换 | 原因             |
    | ----- | ------- | -------- | -------------- |
    | 创建新进程 | 创建 → 就绪 | 否（除非抢占）  | 新进程等待调度        |
    | 调度运行  | 就绪 → 运行 | ✅ 是      | 调度器选择任务        |
    | 阻塞等待  | 运行 → 等待 | ✅ 是      | 当前进程无法继续执行     |
    | 被唤醒   | 等待 → 就绪 | 可能       | 若优先级高，可能立即切换   |
    | 被抢占   | 运行 → 就绪 | ✅ 是      | 时间片到期 / 高优进程到达 |
    | 正常退出  | 运行 → 退出 | ✅ 是      | 释放CPU，调度下一个进程  |
  ]

*进程切换*

#figure(
  image("pic/2025-10-16-10-37-02.png", width: 80%),
  numbering: none,
)

#note(subname: [小结])[
  - 进程：程序的执行过程
  - 进程调度：协作式调度和抢占式调度
  - 进程模型：就绪、运行、等待、创建和退出
  - 进程切换：进程上下文的保存和恢复
]

== 实践：多道程序与分时多任务操作系统

https://rcore-os.cn/rCore-Tutorial-Book-v3/chapter3/index.html

=== 实验目标和步骤

==== 实验目标

实验目标
- MultiprogOS目标
  - 进一步提高系统中多个应用的总体性能和效率
- BatchOS目标
  - 让APP与OS隔离，提高系统的安全性和效率
- LibOS目标
  - 让应用与硬件隔离，简化应用访问硬件的难度和复杂性
总体思路
- 编译：应用程序和内核独立编译，合并为一个镜像
- 编译：应用程序需要各自的起始地址
- 构造：系统调用服务请求接口，进程的管理与初始化
- 构造：*进程控制块*，进程上下文/状态管理
- 运行：*特权级切换*，进程与OS相互切换
- 运行：进程通过系统调用/中断实现*主动/被动切换*

#figure(
  image("pic/2025-10-16-10-42-17.png", width: 80%),
  numbering: none,
)


==== 实践步骤

*实践步骤（基于BatchOS）*
- 修改APP的链接脚本(定制起始地址)
- 加载&执行应用
- 切换任务
*三个应用程序交替执行*
```sh
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch3-coop
```
包含三个应用程序，大家谦让着交替执行
```
user/src/bin/
├── 00write_a.rs # 5次显示 AAAAAAAAAA 字符串
├── 01write_b.rs # 2次显示 BBBBBBBBBB 字符串
└── 02write_c.rs # 3次显示 CCCCCCCCCC 字符串
```
运行结果
```
[RustSBI output]
[kernel] Hello, world!
AAAAAAAAAA [1/5]
BBBBBBBBBB [1/2]
....
CCCCCCCCCC [2/3]
AAAAAAAAAA [3/5]
Test write_b OK!
[kernel] Application exited with code 0
CCCCCCCCCC [3/3]
...
[kernel] Application exited with code 0
[kernel] Panicked at src/task/mod.rs:106 All applications completed!
```

=== 多道批处理操作系统设计

*代码结构：应用程序*
- 构建应用
  ```
  └── user
      ├── build.py(新增：使用 build.py 构建应用使得它们占用的物理地址区间不相交)
      ├── Makefile(修改：使用 build.py 构建应用)
      └── src (各种应用程序)
  ```
- 改进OS：`Loader`模块加载和执行程序
  ```
  ├── os
  │   └── src
  │       ├── batch.rs(移除：功能分别拆分到 loader 和 task 两个子模块)
  │       ├── config.rs(新增：保存内核的一些配置)
  │       ├── loader.rs(新增：将应用加载到内存并进行管理)
  │       ├── main.rs(修改：主函数进行了修改)
  │       ├── syscall(修改：新增若干 syscall)
  ```
- 改进OS：`TaskManager`模块管理/切换程序的执行
  ```
  ├── os
  │   └── src
  │       ├── task(新增：task 子模块，主要负责任务管理)
  │       │   ├── context.rs(引入 Task 上下文 TaskContext)
  │       │   ├── mod.rs(全局任务管理器和提供给其他模块的接口)
  │       │   ├── switch.rs(将任务切换的汇编代码解释为 Rust 接口 __switch)
  │       │   ├── switch.S(任务切换的汇编代码)
  │       │   └── task.rs(任务控制块 TaskControlBlock 和任务状态 TaskStatus 的定义)
  ```
  用汇编的原因是为了实现高效的上下文切换和任务调度，避免不必要的性能损失

=== 应用程序设计

*应用程序项目结构*
- 没有更新 应用名称有数字编号
  ```
  user/src/bin/
  ├── 00write_a.rs # 5次显示 AAAAAAAAAA 字符串
  ├── 01write_b.rs # 2次显示 BBBBBBBBBB 字符串
  └── 02write_c.rs # 3次显示 CCCCCCCCCC 字符串
  ```
*应用程序的内存布局*
- 由于每个应用被加载到的位置都不同，也就导致它们的链接脚本 linker.ld 中的 BASE_ADDRESS 都是不同的。
- 写一个脚本定制工具 build.py ，为每个应用定制了各自的链接脚本
  - `应用起始地址 = 基址 + 数字编号 * 0x20000`

*yield系统调用*
```rs
//00write_a.rs
fn main() -> i32 {
    for i in 0..HEIGHT {
        for _ in 0..WIDTH {
            print!("A");
        }
        println!(" [{}/{}]", i + 1, HEIGHT);
        yield_(); //放弃处理器
    }
    println!("Test write_a OK!");
    0
}
```
- 应用之间是相互不知道的
- 应用需要主动让出处理器
- 需要通过新的系统调用实现
  ```rust
  const SYSCALL_YIELD: usize = 124;
  pub fn sys_yield() -> isize {
      syscall(SYSCALL_YIELD, [0, 0, 0])
  }
  pub fn yield_() -> isize {
      sys_yield()
  }
  ```

=== LibOS：支持应用程序加载

LibOS支持在内存中驻留多个应用，形成多道程序操作系统

*多道程序加载*
- 应用的加载方式有不同
- 所有的应用在内核初始化的时候就一并被加载到内存中
- 为了避免覆盖，它们自然需要被*加载到不同的物理地址*
```rust
fn get_base_i(app_id: usize) -> usize {
    APP_BASE_ADDRESS + app_id * APP_SIZE_LIMIT
}

let base_i = get_base_i(i);
// load app from data section to memory
let src = (app_start[i]..app_start[i + 1]);
let dst = (base_i.. base_i+src.len());
dst.copy_from_slice(src);
```
#newpara()

*执行程序*
- 执行时机
  - 当多道程序的初始化放置工作完成
  - 某个应用程序运行结束或出错的时
- 执行方式
  - 调用 `run_next_app` 函数*切换*到第一个/下一个应用程序

*切换下一个程序*
- 内核态到用户态
- 用户态到内核态
- 跳转到编号i的应用程序编号i的入口点 `entry(i)`
- 将使用的栈切换到用户栈`stack(i)`

=== BatchOS：支持多道程序协作调度

==== 任务切换

*支持多道程序协作式调度*
- 协作式多道程序：应用程序*主动放弃 CPU 并切换*到另一个应用继续执行，从而提高系统整体执行效率
- *进程(Process) *：一个具有一定独立功能的程序在一个数据集合上的一次动态执行过程。也称为任务(Task)
- *时间片（time slice）*:应用执行过程中的一个时间片段称为时间片
- *任务片（task slice）*: 应用执行过程中的一个时间片段上的执行片段或空闲片段，称为“计算任务片”或“空闲任务片”，统称任务片
*任务运行状态*
- 在一个时间片内的应用执行情况
  ```rust
  pub enum TaskStatus {
      UnInit,
      Ready,
      Running,
      Exited,
  }
  ```
*任务切换*
- 从一个应用的执行过程切换到另外一个应用的执行过程
  - *暂停*一个应用的执行过程（当前任务）
  - *继续*另一应用的执行过程（下一任务）
*任务上下文（Task Context）*
- 应用运行在某一时刻的执行状态（上下文）
  - 应用要暂停时，执行状态（上下文）可以被保存
  - 应用要继续时，执行状态（上下文）可以被恢复
  ```rust
  // os/src/task/context.rs
  pub struct TaskContext {
      ra: usize,      //函数返回地址
      sp: usize,      //task内核栈指针
      s: [usize; 12], //属于Callee函数保存的寄存器集s0~s11
  }
  ```
  ```rust
  // os/src/trap/context.rs
  pub struct TrapContext {
      pub x: [usize; 32],
      pub sstatus: Sstatus,
      pub sepc: usize,
  }
  ```

*不同类型上下文*
- 函数调用上下文
- Trap上下文
- 任务（Task）上下文
#three-line-table[
  | 对比项        | 函数调用上下文           | Trap上下文                    | 任务上下文                        |
  | ---------- | ----------------- | -------------------------- | ---------------------------- |
  | *触发方式*   | `call` / `ret` 指令 | 系统调用 / 中断 / 异常             | 任务调度 / 抢占                    |
  | *作用范围*   | 函数内               | 当前进程（用户↔内核）                | 不同进程（或线程）                    |
  | *保存位置*   | 用户栈（Stack Frame）  | 内核栈（Trap Frame）            | PCB（进程控制块）                   |
  | *保存者*    | 编译器 / 调用约定        | CPU + 内核                   | 操作系统内核                       |
  | *特权级变化*  | 无                 | 用户态→内核态                    | 内核态→内核态（不同任务）                |
  | *开销*     | 极低                | 中等                         | 较高                           |
  | *典型指令*   | `call` / `ret`    | `syscall` / `int` / `iret` | `schedule()` / `switch_to()` |
  | *是否改变进程* | 否                 | 否                          | 是                            |
]
- 任务（Task）上下文 vs 系统调用（Trap）上下文
  - 任务切换是来自两个不同应用在内核中的 Trap 控制流之间的切换
  - 任务切换不涉及特权级切换；Trap切换涉及特权级切换
  - 任务切换只保存编译器约定的callee函数应该保存的部分寄存器；而Trap切换需要保存所有通用寄存器
  - 任务切换和Trap切换都是对应用是透明的
  - Trap切换需要硬件参与，任务切换完全由软件完成

*控制流*
- 程序的控制流 (Flow of Control or Control Flow) --编译原理
  - 以一个程序的指令、语句或基本块为单位的*执行序列*
- 处理器的控制流 --计算机组成原理
  - 处理器中程序计数器的*控制转移序列*
*从应用程序员的角度来看控制流*
- *普通控制流*
  - 普通控制流 (CCF，Common Control Flow) 是指程序中的常规控制流程，比如顺序执行、条件判断、循环等基本结构。是程序员编写的程序的*执行序列*，这些序列是程序员*预设好的*
  - 普通控制流是可预测的
  - 普通控制流是程序正常运行所遵循的流
- *异常控制流*
  - 应用程序在执行过程中，如果发出系统调用请求，或出现外设中断、CPU 异常等情况，会出现前一条指令还在应用程序的代码段中，后一条指令就跑到*操作系统的代码段*中去了
  - 这是一种控制流的“*突变*”，即控制流脱离了其所在的执行环境，并产生*执行环境的切换*
  - 这种“突变”的控制流称为*异常控制流*(ECF, Exceptional Control Flow)
  - 在RISC-V场景中，*异常控制流 == Trap控制流*
*控制流上下文（执行环境的状态）*：从硬件的角度来看普通控制流或异常控制流的执行过程
- 从控制流起始的某条指令执行开始，指令可访问的所有物理资源的内容，包括自带的所有通用寄存器、特权级相关特殊寄存器、以及指令访问的内存等，会随着指令的执行而逐渐发生变化
- 把控制流在执行完某指令时的物理资源内容，即确保下一时刻能继续正确执行控制流指令的物理/虚拟资源内容称为*控制流上下文*(Context)，也可称为控制流所在执行环境的状态
- 对于当前实践的OS，没有虚拟资源，而物理资源内容就是通用寄存器/CSR寄存器

==== Trap控制流切换

*OS面临的挑战：任务切换*

在分属不同任务的两个Trap控制流之间进行hacker级操作，即进行*Trap上下文切换*，从而实现任务切换。

*Trap控制流切换*
- 一个特殊的函数`__switch()`
- *暂停运行*
  - 调用 `__switch()` 之后直到它返回前的这段时间，原 Trap 控制流 A 会先被暂停并被切换出去， CPU 转而运行另一个应用在内核中的 Trap 控制流 B
- *恢复运行*
  - 然后在某个合适的时机，原 Trap 控制流 A 才会从某一条 Trap 控制流 C （很有可能不是它之前切换到的 B ）切换回来继续执行并最终返回
- 从实现的角度讲， `__switch()` 函数和一个普通的函数之间的核心差别仅仅是它会换栈

*Trap控制流切换函数`__switch()`*

#figure(
  image("pic/2025-10-16-11-16-48.png", width: 80%),
  numbering: none,
)
- 切换前的状态
  - 阶段[1]：在 Trap 控制流 A 调用`__switch()`之前，A 的*内核栈*上只有 Trap 上下文和 Trap 处理函数的调用栈信息，而 B 是之前被切换出去的
- 保存A任务上下文
  - 阶段 [2]：A 在 A 任务上下文空间在里面保存 *CPU 当前的寄存器快照*
- 恢复B任务上下文
  - 阶段 [3]：读取 `next_task_cx_ptr` 指向的 B 任务上下文，恢复 `ra` 寄存器、`s0~s11` 寄存器以及 `sp` 寄存器
  - 这一步做完后， `__switch()` 才能做到一个函数跨两条控制流执行，即通过*换栈*也就实现了控制流的切换
- 执行B任务代码
  - 阶段 [4]：当 CPU 执行 `ret` 汇编伪指令完成 `__switch()` 函数返回后，任务 B 可以从调用 `__switch()` 的位置继续向下执行。
  - `__switch()`通过恢复 `sp` 寄存器换到了任务 B 的内核栈上，实现了控制流的切换，从而做到一个函数跨两条控制流执行
- `__switch()`的接口
  ```rust
  // os/src/task/switch.rs

  global_asm!(include_str!("switch.S"));

  use super::TaskContext;

  extern "C" {
      pub fn __switch(
          current_task_cx_ptr: *mut TaskContext,
          next_task_cx_ptr: *const TaskContext
      );
  }
  ```
- `__switch()`的实现
  ```asm
  __switch:
    # 阶段 [1]
    # __switch(
    #     current_task_cx_ptr: *mut TaskContext,
    #     next_task_cx_ptr: *const TaskContext
    # )
    # 阶段 [2]
    # save kernel stack of current task
    sd sp, 8(a0)
    # save ra & s0~s11 of current execution
    sd ra, 0(a0)
    .set n, 0
    .rept 12
        SAVE_SN %n
        .set n, n + 1
    .endr
    # 阶段 [3]
    # restore ra & s0~s11 of next execution
    ld ra, 0(a1)
    .set n, 0
    .rept 12
        LOAD_SN %n
        .set n, n + 1
    .endr
    # restore kernel stack of next task
    ld sp, 8(a1)
    # 阶段 [4]
    ret
  ```

==== 协作式调度

*任务控制块*：操作系统管理控制进程运行所用的信息集合
```rust
pub struct TaskControlBlock {
    pub task_status: TaskStatus,
    pub task_cx: TaskContext,
}
struct TaskManagerInner {
    tasks: [TaskControlBlock; MAX_APP_NUM],
    current_task: usize,
}
```
#newpara()
*协作式调度*
- `sys_yield`和`sys_exit`系统调用
  ```rust
  pub fn sys_yield() -> isize {
      suspend_current_and_run_next();
      0
  }
  pub fn sys_exit(exit_code: i32) -> ! {
      println!("[kernel] Application exited with code {}", exit_code);
      exit_current_and_run_next();
      panic!("Unreachable in sys_exit!");
  }

  // os/src/task/mod.rs

  pub fn suspend_current_and_run_next() {
      mark_current_suspended();
      run_next_task();
  }

  pub fn exit_current_and_run_next() {
      mark_current_exited();
      run_next_task();
  }

  fn run_next_task(&self) {
  ......
  unsafe {
      __switch(
          current_task_cx_ptr, //当前任务上下文
          next_task_cx_ptr,    //下个任务上下文
      );
  }
  ```

=== MultiprogOS：分时多任务OS

*MultiprogOS的基本思路*
- 设置时钟中断
- 在收到时钟中断后统计任务的使用时间片
- 在时间片用完后，切换任务

*时钟中断与计时器*
- 设置时钟中断
  ```rust
  // os/src/sbi.rs
  pub fn set_timer(timer: usize) {
      sbi_call(SBI_SET_TIMER, timer, 0, 0);
  }
  // os/src/timer.rs
  pub fn set_next_trigger() {
      set_timer(get_time() + CLOCK_FREQ / TICKS_PER_SEC);
  }
  pub fn rust_main() -> ! {
      trap::enable_timer_interrupt();
      timer::set_next_trigger();
  }
  ```
*抢占式调度*
```rust
// os/src/trap/mod.rs trap_handler函数
......
match scause.cause() {
    Trap::Interrupt(Interrupt::SupervisorTimer) => {
        set_next_trigger();
        suspend_current_and_run_next();
    }
}
```

#note(subname: [小结])[
  - 进程概念与进程控制块PCB数据结构相对应
  - 协作式调度：`yield()`系统调用
  - 抢占式调度：时钟中断触发进程切换
  - 任务与任务切换：`taskContext & switch_to()`
]
