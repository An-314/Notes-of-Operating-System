#import "@preview/scripst:1.1.1": *

= 进程间通信

Inter Process Communication, IPC

== 进程间通信(IPC)概述

#note(subname: [问题])[
  *什么是通信？*
  - 在计算机系统中，“通信”指的是*两个或多个执行实体之间交换信息的行为*。
    - 在单机多进程系统中，这里的执行实体就是 进程。
    - 在分布式系统中，也可能是不同机器上的进程。
  - 一句话：IPC = 进程之间交换数据的方式。

  *为什么要进行通信？*
  - 进程之间必须共享数据或协调行为才能完成更复杂的任务。
  - 单个进程能做的事情有限，但多个进程协作能构建更强大的系统。例如：
    #three-line-table[
      | 场景         | 为什么需要通信？                 |
      | ---------- | ------------------------ |
      | shell 执行程序 | shell 命令解析后需要告诉子进程执行哪个程序 |
      | 浏览器和渲染进程   | 浏览器主进程将页面内容交给渲染进程        |
      | 客户端与服务器    | 典型的 socket 通信            |
      | 数据库系统      | 各种 worker、日志线程、检查点线程需要同步 |
    ]
    现代软件系统本质都是由多个协作的进程/线程组成，而协作离不开通信。

  *两个进程间有哪些通信需求？*
  - 基本通信需求
    - 数据传送
      - 一个进程需要把某些信息交给另一个（例如输入数据、计算中间结果）
    - 事件通知
      - “我做完了，你可以开始干你的事情了”
      - 或者：告诉另一个进程一个外部事件发生了（比如中断、SIGCHLD）
    - 同步（synchronization）
      - 保证两个进程按特定顺序执行
      - 避免竞争条件（race condition）
    - 资源共享
      - 多个进程共享内存、文件等，需要一定管理机制以避免冲突
    - 互斥（mutual exclusion）
      - 典型例子：共享缓冲区只能一个进程修改
  - 操作系统需要提供什么来满足这些需求？
    - 操作系统必须提供机制（mechanisms），使得进程可以安全、高效地通信。典型 IPC 机制包括：
    - 管道（pipe）
      - Unix 最经典的方式：`ls | grep txt`
      - 单向，半双工
      - 父子进程可用匿名管道；无亲缘关系进程要用命名管道
    - 消息队列（message queue）
      - 由 OS 管理的消息缓冲区
      - 进程以“消息”为单位收发信息
    - 共享内存（shared memory）
      - 多个进程映射到同一物理内存区域
      - 最快的 IPC 方式
      - 必须配套锁（信号量）
    - 信号（signal）
      - 发送异步通知，如 Ctrl + C 触发 SIGINT
    - 信号量（semaphore）与互斥锁（mutex）
      - 用来做进程间的同步与互斥
    - Socket
      - 最通用的方式
      - 本机跨进程通信 or 网络跨机器通信均可
]

=== 进程间通信概述

*进程间通信的需求*
- 挑战：单个程序的功能有限
- IPC的目标：多进程协作完成复杂应用需求
  - 功能模块化
  - 程序之间相对隔离
  - 多个程序合作可完成复杂任务
- *进程间通信的定义*：进程间通过数据交换（共享或传递）进行*交互*的行为
  #figure(
    image("pic/2025-11-20-20-03-47.png", width: 80%),
    numbering: none,
  )

*进程间的交互关系*
- 独立进程：与其它进程无交互
- 协作进程：两个或多个进程之间有交互
  - 发送者 接收者 / 客户端 服务端
  - `cat README.md | grep rcore`
    - `grep`依赖`cat`：`grep`等`cat`产生的输出作为其输入，来匹配字符串

*进程通信方式*
- *直接通信*：两个进程间不需要通过内核的中转，就可以相互传递信息
  - ```两进程映射同一块物理内存（共享内存段）
    进程 A 写 → 进程 B 立即可读```
  - 典型代表：
    - System V / POSIX 共享内存
    0 mmap 匿名映射
  - 特点：
    - 快（无需复制）
    - 危险（需要同步机制，否则会乱）
- *间接通信*：两个进程间通过系统调用和内核的中转，来相互传递消息
  - `进程 A 写数据 → 系统调用 → 内核缓冲区 → 系统调用 → 进程 B 读数据`
  - 典型代表：
    - pipe（管道）
    - FIFO
    - socket
    - 信号 signal
    - 消息队列 message queue
  - 特点：
    - 安全（数据隔离）
    - 慢（数据复制两次：A→kernel，kernel→B）
*IPC机制*
- 进程间能共享或传递数据就算是进程间通信。
  #three-line-table[
    | IPC机制|含义|通信方式|
    | --- | --- | --- |
    | 信号 (Signal)	|异步发送信号给进程处理|间接通信|
    | 管道 (Pipe)|单方向传输字节流|间接通信|
    | 消息队列 (Message Queue)|通过队列中转收/发消息|间接通信|
    | 套接字 (Socket)|多/单机进程间网络通信|间接通信|
    | 共享内存 (Shared Memory)|多个进程共享一块物理内存|直接通信|
    | 文件 (File)|多个进程可访问同一文件|间接通信|
  ]
- UNIX的典型IPC机制
  - Communication（数据通信）
    - Byte stream（字节流）：数据像水流一样顺序到达，对边界没有严格定义
      - pipe：父子进程常用
      - FIFO：命名管道，无父子关系也可通信
      - stream socket：网络通信的基础（TCP）
    - Message（消息）：消息以独立的 message 单位 传递，可以保留消息边界
      - System V 消息队列
      - POSIX 消息队列
      - datagram socket (UDP)
    - Shared Memory（共享内存）：共享内存是最快 IPC，但必须配合同步机制（例如信号量）
      - System V shared memory
      - POSIX shared memory
      - mmap（匿名映射、文件映射）
  - Signal（信号）
    - 标准信号（如 SIGINT, SIGKILL）
    - 实时信号（可排队，有优先级）
    - 用于：
      - 异步事件通知
      - 程序终止
      - 子进程状态变化（SIGCHLD）
  - Synchronization（同步）：用于协调多个进程对共享资源的访问：
    - 信号量（semaphore）
    - 文件锁（fnctl / flock）
    - 互斥锁（mutex，对于线程）
    - 条件变量（condition variable）
*消息传递的基本接口*
- 送(send)消息
- 收(recv)消息
- 程过程调用(RPC)
- 复(reply)消息
- Remote Procedure Call, RPC = send + recv
*阻塞或非阻塞通信*
- 阻塞通信:
  - 阻塞发送、阻塞接收
  - 进程调用如 read() 后：
    - 若数据未准备好 → 进程进入 sleep 状态
    - 数据 ready 后 → read 返回
  - 优点：逻辑简单
  - 缺点：进程可能被阻塞很久
- 非阻塞通信
  - 非阻塞发送、非阻塞接收
  - 调用 read()：
    - 若数据未准备好 → READ 立即返回（通常返回 EAGAIN）
    - 进程可以去做别的事情
    - 数据准备好后通过某种机制通知进程（如 epoll）
  - 优点：高并发 IO 的基础（现代网络服务器）
  - 缺点：代码复杂，需要事件循环
  #figure(
    image("pic/2025-11-20-20-20-44.png", width: 80%),
    numbering: none,
  )
*IPC的缓冲方式*
- 无限容量：发送方不需要等待
  - 无限缓冲区（理论模型）
  - 假设 Buffer 可以容纳任意数量的数据
  - 发送方永远不会阻塞
- 有限容量：通信链路缓冲队列满时，发送方必须等待
  - Buffer 有限
  - 当满了后，发送方：
    - 阻塞（阻塞模式）
    - 或 返回 EAGAIN（非阻塞模式）
    - PIPE、SOCKET、消息队列都属于这一类
- 0容量: 发送方必须等待接收方
  - 没有中间缓冲
  - 发送方必须等接收方 ready 才能传输
  - 典型例子：
    - rendezvous 模型（同步消息传递）
    - 部分 RPC 实现模式
  #figure(
    image("pic/2025-11-20-20-21-09.png", width: 80%),
    numbering: none,
  )

=== 管道(pipe)

*管道(pipe)*
- 管道是一种进程间通信机制，也称为匿名管道(anonymous pipe)
  - 有读写端的一定大小的*字节队列*
  - *读端*只能用来从管道中读取
  - *写端*只能用来将数据写入管道
  - 读/写端通过*不同文件描述符*表示
  #three-line-table[
    | 特性         | 说明                      |
    | ---------- | ----------------------- |
    | 单向         | 不能同时双向通信（如需双向 → 建立两条管道） |
    | 有限容量       | 管道缓冲区大小一般 64KB（Linux）   |
    | 字节流        | 读写按照字节序列进行，没有消息边界       |
    | 只能在相关进程间使用 | 父子进程、兄弟进程               |
  ]
*创建管道*
```
int pipe(int pipefd[2])
```
返回：
- pipefd[0]：读端
- pipefd[1]：写端
管道本质是一个在内核中申请的 pipe 对象，每个进程拿到两个文件描述符
- 管道可表示为两个文件描述符加一段内核空间中的内存
- 创建管道时，返回两个文件描述符
  - 读管道
  - 写管道
  #figure(
    image("pic/2025-11-20-20-29-16.png", width: 80%),
    numbering: none,
  )
- 它的本质是：
  - 内核中开辟一块缓冲区（字节队列）
  - 两端通过 两个文件描述符 表示：
    - `pipefd[0]` → 读端（read）
    - `pipefd[1]` → 写端（write）
  - 两端是进程，管道在中间：
    ```
    Process A --fd[1]-->  [ pipe buffer ]  -->fd[0]-- Process B
    ```
*管道(pipe)的应用场景*
- 支持有关系的进程间通信
  - 父子进程、兄弟进程等
- 父进程创建管道(两个文件描述符)
  - 子进程会继承文件描述符，执行读写管道
- 通常管道两端的进程会各自关闭管道的一个文件描述符，如
  - 父进程关闭写描述符，只能向管道读数据
  - 子进程关闭读描述符，只能从管道写数据
  #figure(
    image("pic/2025-11-20-20-34-02.png", width: 80%),
    numbering: none,
  )
*管道实现机制*
#figure(
  image("pic/2025-11-20-20-36-10.png", width: 80%),
  numbering: none,
)
- pipe() 在内核中创建一个 pipe 对象
  - 其中包含：
    - 一个循环缓冲区（字节队列）
    - 读端引用计数
    - 写端引用计数
  - 文件描述符表：
    #three-line-table[
      | fd | 指向               |
      | -- | ---------------- |
      | 3  | pipefd[0] → 管道读端 |
      | 4  | pipefd[1] → 管道写端 |
    ]
  - write(pipefd[1], …)
    - 写端（W）将数据写入 pipe 缓冲区
    - 若缓冲区满 → 写阻塞
    - 若无读端 → 返回 SIGPIPE
  - read(pipefd[0], …)
    - 读端（R）从 pipe 缓冲区读出数据
    - 若缓冲区空 → 读阻塞
    - 若写端全部关闭 → read 返回 0（EOF）
*管道的典型用法：Shell 中的 "|"*
- 只需使用一根竖线 "|" 连接两个命令，Shell 做了以下几件事：
  - 调用 `pipe()` 得到读端和写端
  - `fork` 子进程运行 `cat`
    - 子进程 → `stdout` 被重定向到写端
  - `fork` 子进程运行 `grep`
    - 子进程 → `stdin` 被重定向到读端
  - Shell 关闭不需要的端
  - 最终形成数据流：
    ```
    cat stdout → pipe → grep stdin
    ```
*命名管道（named pipe）*
- 在shell中可用`mkfifo`命令创建命名管道，也称为FIFO。
- 匿名管道与命名管道都属于单向通信机制。两者的不同是：
  - 命名管道可以支持任意两个进程间的通信
  - 匿名管道只支持父子进程和兄弟进程间的通信
- 命名管道是阻塞式的单向通信管道
  - 任意一方都可以读、写
  - 只有读、写端同时打开了命名管道时，数据才会写入并被读取
  #three-line-table[
    | 对比项   | 匿名管道    | 命名管道（FIFO）    |
    | ----- | ------- | ------------- |
    | 建立方式  | pipe()  | mkfifo 产生一个文件 |
    | 文件系统  | 不存在     | 是文件（类型为 p）    |
    | 通信进程  | 必须有亲缘关系 | 任意两个进程        |
    | 阻塞    | 是       | 是             |
    | 单向/双向 | 单向      | 单向（如需双向需建两条）  |
  ]
  - 示例
    - Terminal A:
      ```bash
      mkfifo name.fifo
      echo README > name.fifo   # 阻塞等待……
      ```
    - Terminal B:
      ```bash
      cat name.fifo   # 解除 A 的阻塞
      ```
      当 B 打开读端时，A 才能把数据写进去。

=== 消息队列(Message Queue)

*消息队列(Message Queue)*
- 消息队列是由操作系统维护的以结构数据为基本单位的间接通信机制
  - 每个消息(Message)是一个字节序列，有自己的类型标识
  - 相同类型标识的消息组成按先进先出顺序组成一个消息队列
  #figure(
    image("pic/2025-11-21-16-51-09.png", width: 100%),
    numbering: none,
  )
- 多个发送者（P1、P2）可以向消息队列发送消息
- 多个接收者可以根据消息类型读取消息
- 每条消息包含：
  - mtype（消息类型/优先级）
  - mtext（消息内容）
  ```
  P1 ——┐
        ├——> [ 消息队列 MQ ] ——> P3
  P2 ——┘
  ```
  #three-line-table[
    | 特性       | 管道（Pipe） | 消息队列（Message Queue） |
    | -------- | -------- | ------------------- |
    | 数据结构     | 字节流      | 结构化消息（带类型）          |
    | 亲缘关系     | 必须父子或兄弟  | 任意进程                |
    | 是否有类型    | ❌ 没有     | ✔ 有                 |
    | 是否可选择性接收 | ❌ 不可     | ✔ 可按 mtype 接收       |
    | 数据持久性    | 进程结束即关闭  | 内核保存直到删除            |
    | 通信方式     | 阻塞字节流    | 可阻塞/可非阻塞、带优先级       |
  ]
- 消息队列内部结构
  ```
  消息队列头（权限、状态...）
    ↓
  消息链表
    ↓
  [ msg(type=1) ] → [ msg(type=3) ] → ...
  ```
  内核中维护一个：
  - “队列控制块”
  - 多个消息结构体
  - 每条消息配有 mtype 字段，可由用户定义

*消息队列机制*
#figure(
  image("pic/2025-11-21-16-59-28.png", width: 80%),
  numbering: none,
)
- 进程 A/B 的步骤完全对称：
  - 生成 key
    ```c
    key = ftok(pathname, proj_id);
    ```
    - 同一个 pathname + proj_id → 得到相同 key
    - 实现跨进程共享消息队列
  - 创建/获取消息队列
    ```c
    msgid = msgget(key, IPC_CREAT | 0600);
    ```
  - 发送 / 接收消息
    ```c
    msgsnd(msgid, &buf, sizeof(buf), flag);
    msgrcv(msgid, &buf, sizeof(buf), type, flag);
    ```
  - 删除消息队列
    ```c
    msgctl(msgid, IPC_RMID, NULL);
    ```
*ftok*
- ftok 会基于文件的 inode 信息和 proj_id 生成一个唯一的键值
- 两个进程必须使用相同的 pathname 和 proj_id，才能生成相同的键值，从而访问同一个 IPC 资源
```c
key_t ftok(const char *pathname, int proj_id);
```
- `pathname`：一个已存在的文件路径（如进程A和B都能访问的文件）
- `proj_id`：一个用户自定义的整型值（通常是一个字符的 ASCII 码，如 'A'）

*消息队列实现机制*
- 不同消息类型
  - 优先级排序
  - 选择性接收
  - 安全和隔离
- 消息的结构
  ```c
  struct msgbuf {
    long mtype;   /* 消息的类型 */
    char mtext[1];/* 消息正文 */
  };
  ```
*消息队列的系统调用*
- `msgget ( key, flags） //创建息队列`
- `msgsnd ( msgid, buf, size, flags ） //发送消息`
- `msgrcv ( msgid, buf, size, type, flags ） //接收消息`
- `msgctl(msqid, cmd, msqid_ds *buf） // 消息队列控制`
- *创建消息队列*
  ```c
  #include <sys/types.h>
  #include <sys/ipc.h>
  #include <sys/msg.h>

  int msgget(key_t key, int msgflg);
  ```
  - 参数：
    - key: 某个消息队列的名字
    - msgflg:由九个权限标志构成，用法和创建文件时使用的mode模式标志是一样的，IPC_CREAT or IPC_EXCL等
  - 返回值：
    - 成功：msgget将返回一个非负整数，即该消息队列的标识码
    - 失败：则返回“-1”
  - 那么如何获取key值？
    - 通过宏定义key值
    - 通过ftok函数生成key值
- *发送消息*
  ```c
  int  msgsnd(int msgid, const void *msg_ptr, size_t msg_sz, int msgflg);
  ```
  - 参数：
    - msgid: 由msgget函数返回的消息队列标识码
    - msg_ptr:是指向待发送数据的指针
    - msg_sz:是msg_ptr指向的数据长度
    - msgflg:控制着当前消息队列满或到达系统上限时的行为；如：IPC_NOWAIT 表示队列满不等待，返回EAGAIN错误
  - 返回值：
    - 成功返回0
    - 失败则返回-1
- *接收消息*
  ```c
  int  msgrcv(int msgid, void *msg_ptr, size_t msgsz,long int msgtype, int msgflg);
  ```
  - 参数：
    - msgid: 由msgget函数返回的消息队列标识码
    - msg_ptr:是指向准备接收的消息的指针
    - msgsz:是msg_ptr指向的消息长度
    - msgtype:它可以实现接收优先级的简单形式
      - msgtype\=0返回队列第一条信息
      - msgtype\>0返回队列第一条类型等于msgtype的消息
      - msgtype\<0返回队列第一条类型小于等于msgtype绝对值的消息
    - msgflg:控制着队列中没有相应类型的消息可供接收时的行为
      - IPC_NOWAIT，队列没有可读消息不等待，返回ENOMSG错误
      - MSG_NOERROR，消息大小超过msgsz时被截断
  - 返回值：
    - 成功：返回实际放到接收缓冲区里去的字符个数
    - 失败：则返回-1
  - 消息会被第一个调用 msgrcv() 且匹配 mtype 的进程接收。若多个进程监听同一mtype，则操作系统调度随机选择一个进程（存在竞争）。
- *消息队列控制：查询队列状态、修改权限、删除队列等*
  ```c
  int msgctl(int msqid, int cmd, struct msqid_ds *buf);
  ```
  - 消息队列的属性保存在系统维护的数据结构msqid_ds中，可以通过函数msgctl获取或设置消息队列的属性。
  - msgctl：对msgqid标识的消息队列执行cmd操作，3种cmd操作：
    - IPC_STAT：获取消息队列对应的msqid_ds数据结构（保存到buf）
    - IPC_SET：修改消息队列的属性（存储在buf中），包括：msg_perm.uid、 msg_perm.gid、msg_perm.mode、msg_qbytes
    - IPC_RMID：从内核中删除msgqid标识的消息队列
  - buf是指向msgid_ds结构的指针，指向消息队列模式和访问权限
```c
struct msqid_ds {
    struct ipc_perm msg_perm;  // 权限信息
    time_t          msg_stime; // 最后发送消息的时间（单位：秒，从 1970-01-01 起）
    time_t          msg_rtime; // 最后接收消息的时间
    time_t          msg_ctime; // 最后修改队列的时间（如 IPC_SET、IPC_RMID）
    unsigned long   msg_cbytes;// 当前队列中的字节数
    msgqnum_t       msg_qnum;  // 当前队列中的消息数量
    msglen_t        msg_qbytes; // 队列允许的最大字节数
    pid_t           msg_lspid; // 最后发送消息的进程 PID
    pid_t           msg_lrpid; // 最后接收消息的进程 PID
};
```

=== 共享内存(shared memory)

*共享内存(shared memory, shmem)*
- 多个进程将自己的虚拟地址空间中的*某一段映射到同一块物理内存上*，从而共享数据。
  - 每个进程的内存地址空间需明确设置共享内存段
  - 优点：快速、方便地共享数据
  - 不足：需要同步机制协调数据访问
  #figure(
    image("pic/2025-11-22-11-12-23.png", width: 80%),
    numbering: none,
  )

*共享内存实现机制*
#figure(
  image("pic/2025-11-22-11-14-03.png", width: 80%),
  numbering: none,
)
- 进程 A 流程
  - 生成 key
    ```c
    key = ftok(pathname, PID);
    ```
    两个进程只要使用相同 pathname 和 proj_id，就能得到同一个 key
  - 创建共享内存段
    ```c
    shmid = shmget(key, size, IPC_CREAT | IPC_EXCL | 0600);
    ```
  - 将共享内存 attach 到进程空间
    ```c
    char *mem = shmat(shmid, NULL, 0);
    ```
    这一步是关键：内核在 A 的虚拟地址空间中找一块空区域；建立它到共享物理内存的映射（更新页表）
  - 写入数据
    ```c
    Write(mem);
    ```
- 进程 B 流程
  - B 必须使用相同 key：
  - `ftok()`
  - `shmget()` → 得到相同共享内存段
  - `shmat()` → 建立自己的映射
    ```
    进程 A： mem → (物理页)
    进程 B： mem → (物理页)
    ```
  - B 直接读取 A 的数据：
    ```
    Read(mem);
    ```
- detach 和 删除机制
  - detach（取消映射）
    ```c
    shmdt(mem);
    ```
    把共享内存段从进程自己的地址空间中解除映射，但共享内存本身还没删除
  - 删除共享段（只有创建者通常删除）
    ```c
    shmctl(shmid, IPC_RMID, NULL);
    ```
    - 删除共享内存段只是标记
    - 当所有进程都 detach 后，内存才真正被释放

*共享内存的系统调用总结*
- #three-line-table[
    | 系统调用       | 功能           |
    | ---------- | ------------ |
    | *shmget* | 创建或获取共享内存段   |
    | *shmat*  | 将共享内存映射到进程空间 |
    | *shmdt*  | 解除共享内存映射     |
    | *shmctl* | 删除、获取属性、修改权限 |
  ]
  - `shmget( key, size, flags） //创建共享段`
  - `shmat( shmid, *shmaddr, flags） //把共享段映射到进程地址空间`
  - `shmdt( *shmaddr）//取消共享段到进程地址空间的映射`
  - `shmctl(shmid, cmd, shmid_ds *buf） //控制共享段`
  注：需要信号量等同步机制协调共享内存的访问冲突
- *创建共享内存*
  ```c
  #include <sys/ipc.h>
  #include <sys/shm.h>
  int shmget(key_t key, size_t size, int shmflg);
  ```
  - key：进程间通信键值，ftok() 的返回值。
  - size：该共享存储段的长度(字节)。
  - shmflg：标识函数的行为及共享内存的权限，其取值如下：
    - IPC_CREAT：如果不存在就创建
    - IPC_EXCL： 如果已经存在则返回失败
  - 返回值：成功：共享内存标识符；失败：-1。
- *共享内存映射*
  ```c
  #include <sys/types.h>
  #include <sys/shm.h>
  void *shmat(int shmid, const void *shmaddr, int shmflg);
  ```
  - 将一个共享内存段映射到调用进程的数据段中。即：让进程和共享内存建立一种联系，让进程某个指针指向此共享内存。
  - 返回值：
    - 成功：共享内存段映射地址( 相当于这个指针就指向此共享内存 )
    - 失败：-1
  - shmid：共享内存标识符，shmget() 的返回值。
  - shmaddr：共享内存映射地址，若为 NULL 则由系统自动指定
  - shmflg：共享内存段的访问权限和映射条件，取值如下：
    - 0：共享内存具有可读可写权限。
    - SHM_RDONLY：只读。
    - SHM_RND：（shmaddr 非空时才有效）
- *删除共享内存*
  ```c
  int shmdt(const void *shmaddr);
  ```
  - shmaddr是shmat()函数返回的地址指针
  - 调用成功时返回0，失败时返回-1
- *共享内存控制*
  ```c
  int shmctl(int shmid, int cmd, struct shmid_ds *buf);
  ```
  - shm_id是shmget()函数返回的共享内存标识符。
  - cmd是要采取的操作，它可以取下面的三个值 ：
    - IPC_STAT：把shmid_ds结构中的数据设置为共享内存的当前关联值，即用共享内存的当前关联值覆盖shmid_ds的值。
    - IPC_SET：如果进程有足够的权限，就把共享内存的当前关联值设置为shmid_ds结构中给出的值
    - IPC_RMID：删除共享内存段
  - buf是一个结构指针，它指向共享内存模式和访问权限的结构。

相比其他 IPC：
#three-line-table[
  | IPC 方式        | 数据路径              | 是否发生拷贝      |
  | ------------- | ----------------- | ----------- |
  | pipe / socket | 用户 → 内核 → 用户      | ✔ 两次拷贝      |
  | message queue | 用户 → 内核 → 复制 → 内核 | ✔ 多次拷贝      |
  | shared memory | 用户直接访问共享物理页       | *❌ 0 次拷贝* |
]
共享内存速度 ≈ 直接访问内存，因此非常快。

=== 信号(Signal)

*信号(Signal)*
- 信号是中断正在运行的进程的*异步*消息或事件
- 信号机制是一种进程间异步通知机制
- 它最像“软件中断”：
  - 信号会打断一个正在运行的进程，让它立即去处理某个事件
  - 这也是它和之前的 IPC（pipe/msg/shm）最大的不同：信号不是用来传数据的，而是用来通知事件/异常的
  #figure(
    image("pic/2025-11-22-11-38-55.png", width: 80%),
    numbering: none,
  )

*信号发送和响应过程*
#figure(
  image("pic/2025-11-22-11-39-58.png", width: 80%),
  numbering: none,
)
- 进程 A：发送信号
  ```c
  kill(pid, SIGUSR1);
  ```
  步骤：
  - 进程 A 发出 kill() 系统调用
  - 内核记录“要给 B 派发信号 SIGUSR1”
  - 内核将信号加入 B 的 pending 信号集
  - 下一次内核准备返回用户态执行 B 时，会检查是否有信号要处理
- 进程 B：接收信号与执行 handler
  - 进程 B 必须先注册处理函数：
    ```c
    struct sigaction act;
    act.sa_handler = handler_func;
    sigaction(SIGUSR1, &act, NULL);
    ```
  - 之后，当 B 收到信号，流程是：
    - 内核设置 B 的用户栈（构造 signal frame）
    - 内核修改 B 的用户态返回地址 → handler_func
    - 返回用户态时 不继续执行原代码，而是跳到 handler_func
    - handler 执行完：执行 sigreturn() → 再次进入内核
    - 内核恢复原来的执行现场 → 回到原正常代码执行

*信号命名*
- 信号是一个整数编号，这些整数编号都定义了对应的宏名，宏名都是以SIG开头，比如SIGABRT, SIGKILL, SIGSTOP, SIGCONT
*信号发送*
- 进程通过内核发出信号
  - shell通过kill命令向某个进程发送一个信号将其终止
- 内核直接发出信号
  - 某进程从管道读取数据，但是管道的读权限被关闭了，内核会给进程发送一个SIGPIPE信号，提示读管道出错
- 外设通过内核发出
  - 比如按下Ctrl+C按键时，内核收到包含Ctrl+C按键的外设中断，会向正在运行的进程发送SIGINT信号，将其异常终止
  #three-line-table[
    | 来源   | 示例                   |
    | ---- | -------------------- |
    | 用户发送 | kill 命令，`kill()`系统调用  |
    | 内核发送 | 管道写端关闭→触发 SIGPIPE    |
    | 外设触发 | Ctrl+C → 内核发送 SIGINT |
  ]
*信号接收进程的处理方式*
- 忽略：信号没有发生过
- 捕获：进程会调用相应的处理函数进行处理
- 默认：如果不忽略也不捕获，此时进程会使用内核默认的处理方式来处理信号
  - 内核默认的信号处理：在大多情况下就是杀死进程或者直接忽略信号
  #three-line-table[
    | 处理方式              | 说明                          |
    | ----------------- | --------------------------- |
    | *忽略*（ignore）    | 忽略信号（如 SIGCHLD）             |
    | *捕获*（catch）     | 调用用户态 handler               |
    | *默认处理*（default） | 通常是终止进程，如 SIGSEGV / SIGKILL |
  ]

*Linux信号*
- Linux有62个信号
- 每个信号代表着某种事件，一般情况下，当进程收到某个信号时，就表示该信号所代表的事件发生了
  - SIGKILL
  - SIGINT
  - SIGSEGV
  #three-line-table[
    | 信号名      | 信号编号 | 说明                           |
    | --------- | ------ | ---------------------------- |
    | SIGHUP    | 1      | 终端挂断（hang up）                  |
    | SIGINT    | 2      | 中断进程（来自键盘的中断，如 Ctrl+C）        |
    | SIGQUIT   | 3      | 退出进程（来自键盘的退出，如 Ctrl+\\）        |
    | SIGILL    | 4      | 非法指令                         |
    | SIGABRT   | 6      | 异常终止                         |
    | SIGFPE    | 8      | 浮点异常                         |
    | SIGKILL   | 9      | 杀死进程（无法捕获或忽略该信号）            |
    | SIGSEGV   | 11     | 无效内存引用                      |
    | SIGPIPE   | 13     | 管道破裂（写管道时无读端）               |
    | SIGALRM   | 14     | 定时器到期                        |
    | SIGTERM   | 15     | 终止进程（默认终止信号）                |
    | SIGCHLD   | 17     | 子进程状态改变                      |
    | SIGCONT   | 18     | 继续执行（被停止的进程）                 |
    | SIGSTOP   | 19     | 停止进程（无法捕获或忽略该信号）            |
    | SIGTSTP   | 20     | 停止进程（来自键盘的停止，如 Ctrl+Z）        |
    | SIGUSR1   | 30     | 用户自定义信号1                     |
    | SIGUSR2   | 31     | 用户自定义信号2                     |
  ]
*信号实现机制*
#figure(
  image("pic/2025-11-22-12-08-29.png", width: 80%),
  numbering: none,
)
- 册 signal handler
  - 调用 `sigaction()` 设置用户态回调函数
- 派发信号（内核进行）
  - 信号进入 pending 集合
  - 内核调度时检测
  - 内核决定执行 handler
- 执行信号处理函数
  - 用户态执行 handler
  - 完成后通过 sigreturn() 回到原来的执行点
- 这和硬件中断流程几乎完全一致
#figure(
  image("pic/2025-11-22-12-09-30.png", width: 80%),
  numbering: none,
)
- 内核态：
  ```
  do_signal()
      ↓
  handle_signal()
      ↓
  setup_frame()    // 将返回地址、寄存器压入用户栈
  ```
- 然后：
  ```
  return to user mode  →  执行 signal handler
  ```
- handler 执行完毕后：
  ```
  system_call()       // sigreturn() 进入内核
      ↓
  sys_sigreturn()
      ↓
  restore_sigcontext()  // 恢复现场
  ```
- 最终：返回用户态原来的执行点
- 信号实现机制
  - 注册用户态信号处理函数sig_handler
  - 内核在返回用户态前，发现有信号要处理
  - 内核在用户栈压入sig_handler函数栈信息
    - 模拟用户代码调用sig_handler函数
  - 内核在陷入上下文中修改用户态返回地址
  - 内核返回用户态，直接跳到sig_handler
  - 执行sig_handler函数结束后，自动通过系统调用sigreturn陷入内核态
  - sigreturn恢复进程正常执行的上下文，返回用户态继续执行
#figure(
  image("pic/2025-11-22-12-33-27.png", width: 60%),
  numbering: none,
)

*为什么要用 sigreturn？*
- 因为只有内核有权限恢复寄存器、PC 值、堆栈指针、标志位等硬件上下文
- 这非常关键：
  - 如果用户态可以随便恢复上下文，那就能伪造返回地址
  - 会导致严重的安全漏洞（攻击者可跳转到任意指令）
- 所以：
  - setup_frame() 和 restore_sigcontext() 必须由内核执行，不能由用户态处理
- 权限需求：只有内核能安全操作硬件上下文。
- 安全校验：防止用户态篡改攻击。

== 实践：支持IPC的OS IPC OS (IOS)

https://rcore-os.cn/rCore-Tutorial-Book-v3/chapter7/index.html

=== 实验安排

==== 实验目标

*以往实验目标*
- 提高性能、简化开发、加强安全、支持数据持久保存
- Filesystem OS：支持数据持久保存
- Process OS: 增强进程管理和资源管理
- Address Space OS: 隔离APP访问的内存地址空间
- multiprog & time-sharing OS: 让APP共享CPU资源
- BatchOS: 让APP与OS隔离，加强系统安全，提高执行效率
- LibOS: 让APP与HW隔离，简化应用访问硬件的难度和复杂性

*实验目标*
- 支持应用的灵活性，支持进程间交互
#figure(
  image("pic/2025-11-22-12-30-30.png", width: 80%),
  numbering: none,
)
- 扩展文件抽象：Pipe, Stdout, Stdin
- 以文件形式进行进程间数据交换
- 以文件形式进行串口输入输出
- 信号实现进程间异步通知机制
- 系统调用数量：11个 $->$ 17个
  - 管道：2 个、用于传数据
  - 信号：4 个、用于发通知

*实验要求*
- 理解文件抽象
- 理解IPC机制的设计与实现
  - pipe
  - signal
- 会写支持IPC的OS

==== 总体思路

*理解管道*
- *管道是内核中的一块内存*
  - 顺序写入/读出字节流
- *管道可抽象为文件*
  - 进程中包含管道文件描述符
    - 管道的FileTrait的接口
    - read/write
  - 应用创建管道的系统调用
    - sys_pipe
- 管道示例程序 (用户态)
  ```rs
  ...// usr/src/bin/pipetest.rs
  static STR: &str = "Hello, world!"  //字符串全局变量
  pub fn main() -> i32 {
      let mut pipe_fd = [0usize; 2]; //包含两个元素的fd数组
      pipe(&mut pipe_fd); // create pipe
      if fork() == 0 { // child process, read from parent
          close(pipe_fd[1]); // close write_end
          let mut buffer = [0u8; 32]; //包含32个字节的字节数组
          let len_read = read(pipe_fd[0], &mut buffer) as usize; //读pipe
      } else { // parent process, write to child
          close(pipe_fd[0]); // close read end
          write(pipe_fd[1], STR.as_bytes()); //写pipe
          let mut child_exit_code: i32 = 0;
          wait(&mut child_exit_code); //父进程等子进程结束
      }
  ...
  ```
- *管道与进程的关系*
  - pipe是进程控制块的资源之一
    #figure(
      image("pic/2025-11-22-12-36-58.png", width: 80%),
      numbering: none,
    )

*理解信号*
- signal是内核通知应用的软件中断
- 准备阶段
  - 设定signal的整数编号值
  - 建立应对某signal编号值的例程signal_handler
- 执行阶段
  - 向某进程发出signal，打断进程的当前执行，转到signal_handler执行
- 信号示例程序（用户态）
  ```rs
  ...// usr/src/bin/sig_simple.rs
  fn func() { //signal_handler
      println!("user_sig_test succsess");
      sigreturn(); //回到信号处理前的位置继续执行
  }
  pub fn main() -> i32 {
      let mut new = SignalAction::default();  //新信号配置
      let old = SignalAction::default();      //老信号配置
      new.handler = func as usize;            //设置新的信号处理例程
      if sigaction(SIGUSR1, &new, &old) < 0 { //setup signal_handler
          panic!("Sigaction failed!");
      }
      if kill(getpid() as usize, SIGUSR1) <0{ //send SIGUSR1 to itself
        ...
      }
  ...
  ```
- 信号与进程的关系
  - signal是进程控制块的资源之一

==== 历史背景

管道：Unix 中最引人注目的发明
- 管道的概念来自贝尔实验室的Douglas McIlroy，他在1964年写的一份内部文件中，提出了把多个程序“像花园水管一样”串连并拧在一起的想法，让数据在不同程序中流动
- 大约在1972年下半年，Ken Thompson在听了Douglas McIlroy关于管道的唠叨后，灵机一动，迅速把管道机制实现在UNIX中。
信号：Unix 中容易出错的软件中断
- 信号从Unix的第一个版本就已存在，只是与我们今天所知道的有点不同，需要通过不同的系统调用来捕获不同类型的信号。在版本4之后，改进为通过一个系统调用来捕获所有信号

==== 实践步骤

*实践步骤*
```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch7
cd os
make run
```
#newpara()
*参考输出*
```
[RustSBI output]
...
filetest_simple
fantastic_text
**************/
Rust user shell
>>
```
操作系统启动shell后，用户可以在shell中通过敲入应用名字来执行应用

*测例 pipetest*
在这里我们运行一下本章的测例 pipetest ：
```
>> pipetest
Read OK, child process exited!
pipetest passed!
>>
```
此应用的父子进程通过pipe完成字符串"Hello, world!"的传递

*测例 sig_simple*

在这里我们运行一下本章的测例 sig_simple ：
```
>> sig_simple
signal_simple: sigaction
signal_simple: kill
user_sig_test succsess
signal_simple: Done
>>
```
此应用建立了针对SIGUSR1信号的信号处理例程func，然后再通过kill给自己发信号SIGUSR1，最终func会被调用

=== 代码结构

*用户代码结构*
```
└── user
    └── src
        ├── bin
        │   ├── pipe_large_test.rs(新增：大数据量管道传输)
        │   ├── pipetest.rs(新增：父子进程管道传输)
        │   ├── run_pipe_test.rs(新增：管道测试)
        │   ├── sig_tests.rs(新增：多方位测试信号机制)
        │   ├── sig_simple.rs(新增：给自己发信号)
        │   ├── sig_simple2.rs(新增：父进程给子进程发信号)
        ├── lib.rs(新增两个系统调用：sys_close/sys_pipe/sys_sigaction/sys_kill...)
        └── syscall.rs(新增两个系统调用：sys_close/sys_pipe/sys_sigaction/sys_kill...)
```
#newpara()
*内核代码结构*
```
├── fs(新增：文件系统子模块 fs)
│   ├── mod.rs(包含已经打开且可以被进程读写的文件的抽象 File Trait)
│   ├── pipe.rs(实现了 File Trait 的第一个分支——可用来进程间通信的管道)
│   └── stdio.rs(实现了 File Trait 的第二个分支——标准输入/输出)
├── mm
│   └── page_table.rs(新增：应用地址空间的缓冲区抽象 UserBuffer 及其迭代器实现)
├── syscall
│   ├── fs.rs(修改：调整 sys_read/write 的实现，新增 sys_close/pipe)
│   ├── mod.rs(修改：调整 syscall 分发)
├── task
│   ├── action.rs(信号处理SignalAction的定义与缺省行为)
│   ├── mod.rs（信号处理相关函数）
│   ├── signal.rs（信号处理的信号值定义等）
│   └── task.rs(修改：在任务控制块中加入信号相关内容)
└── trap
    ├── mod.rs（进入/退出内核时的信号处理）
```

=== 管道的设计实现

*管道的设计实现*
- 基于文件抽象，支持I/O重定向
  - [K] 实现基于文件的标准输入/输出
  - [K] 实现基于文件的实现管道
  - [U] 支持命令行参数
  - [U] 支持 “|" 符号

#figure(
  image("pic/2025-11-22-12-45-25.png", width: 80%),
  numbering: none,
)

*标准输入/输出文件*
- 实现基于文件的标准输入/输出
  - FD：0 -- Stdin ; 1/2 -- Stdout
  - 实现File 接口
    - `read -> call(SBI_CONSOLE_GETCHAR)`
    - `write -> call(SBI_CONSOLE_PUTCHAR)`
- 创建TCB时初始化`fd_table`
  ```rs
  TaskControlBlock::fork(...)->... {
    ...
    let task_control_block = Self {
        ...
            fd_table: vec![
                // 0 -> stdin
                Some(Arc::new(Stdin)),
                // 1 -> stdout
                Some(Arc::new(Stdout)),
                // 2 -> stderr
                Some(Arc::new(Stdout)),
            ],
  ...
  ```
- `fork`时复制`fd_table`
  ```rs
  TaskControlBlock::new(elf_data: &[u8]) -> Self{
    ...
      // copy fd table
      let mut new_fd_table = Vec::new();
      for fd in parent_inner.fd_table.iter() {
          if let Some(file) = fd {
              new_fd_table.push(Some(file.clone()));
          } else {
              new_fd_table.push(None);
          }
      }
  ```
*管道文件*
- 管道的系统调用
  ```rs
  /// 功能：为当前进程打开一个管道。
  /// 参数：pipe 表示应用地址空间中
  /// 的一个长度为 2 的 usize 数组的
  /// 起始地址，内核需要按顺序将管道读端
  /// 和写端的文件描述符写入到数组中。
  /// 返回值：如果出现了错误则返回 -1，
  /// 否则返回 0 。
  /// 可能的错误原因是：传入的地址不合法。
  /// syscall ID：59
  pub fn sys_pipe(pipe: *mut usize) -> isize;
  ```
- 创建管道中的Buffer
  ```rs
  pub struct PipeRingBuffer {
      arr: [u8; RING_BUFFER_SIZE],
      head: usize,
      tail: usize,
      status: RingBufferStatus,
      write_end: Option<Weak<Pipe>>,
  }

  make_pipe() -> (Arc<Pipe>, Arc<Pipe>) {
      let buffer = PipeRingBuffer::new();
      let read_end = Pipe::read_end_with_buffer();
      let write_end = Pipe::write_end_with_buffer();
      ...
      (read_end, write_end)
  ```
- 实现基于文件的输入/输出
  - 实现File 接口
    ```rs
    fn read(&self, buf: UserBuffer) -> usize {
       *byte_ref = ring_buffer.read_byte();
    }
    fn write(&self, buf: UserBuffer) -> usize {
      ring_buffer.write_byte( *byte_ref );
    }
    ```

*exec系统调用的命令行参数*
- sys_exec 的系统调用接口需要发生变化
  ```rs
  // 增加了args参数
  pub fn sys_exec(path: &str, args: &[*const u8]) -> isize;
  ```
- shell程序的命令行参数分割
  ```rs
  // 从一行字符串中获取参数
  let args: Vec<_> = line.as_str().split(' ').collect();
  // 用应用名和参数地址来执行sys_exec系统调用
  exec(args_copy[0].as_str(), args_addr.as_slice());
  ```
- 将获取到的参数字符串压入到用户栈上
  ```rs
  impl TaskControlBlock {
    pub fn exec(&self, elf_data: &[u8], args: Vec<String>) {
      ...
      // push arguments on user stack
  }
  ```
  - Trap 上下文中的 a0/a1 寄存器，让 a0 表示命令行参数的个数，而 a1 则表示图中 argv_base 即蓝色区域的起始地址
    ```rs
    pub extern "C" fn _start(argc: usize, argv: usize) -> ! {
      //获取应用的命令行个数 argc, 获取应用的命令行参数到v中
      //执行应用的main函数
      exit(main(argc, v.as_slice()));
    }
    ```
    #figure(
      image("pic/2025-11-22-12-52-34.png", width: 40%),
      numbering: none,
    )

*重定向*
- 复制文件描述符系统调用
  ```rs
  /// 功能：将进程中一个已经打开的文件复制
  /// 一份并分配到一个新的文件描述符中。
  /// 参数：fd 表示进程中一个已经打开的文件的文件描述符。
  /// 返回值：如果出现了错误则返回 -1，否则能够访问已打
  /// 开文件的新文件描述符。
  /// 可能的错误原因是：传入的 fd 并不对应一个合法的已打
  /// 开文件。
  /// syscall ID：24
  pub fn sys_dup(fd: usize) -> isize;

  pub fn sys_dup(fd: usize) -> isize {
    ...
    let new_fd = inner.alloc_fd();
    inner.fd_table[new_fd] = inner.fd_table[fd];
    newfd
  }
  ```
- shell重定向 `$ A | B`
  ```rs
  // user/src/bin/user_shell.rs
  {
    let pid = fork();
      if pid == 0 {
          let input_fd = open(input, ...); //输入重定向 -- B 子进程
          close(0);                        //关闭文件描述符0
          dup(input_fd); //文件描述符0与文件描述符input_fd指向同一文件
          close(input_fd); //关闭文件描述符input_fd
          //或者
          let output_fd = open(output, ...);//输出重定向 -- A子进程
          close(1);                         //关闭文件描述符1
          dup(output_fd);//文件描述符1与文件描述符output_fd指向同一文件
          close(output_fd);//关闭文件描述符output_fd
      //I/O重定向后执行新程序
      exec(args_copy[0].as_str(), args_addr.as_slice());
    }...
  ```

=== 信号的设计实现

*与信号处理相关的系统调用*
- sigaction: 设置信号处理例程
- sigprocmask: 设置要阻止的信号
- kill: 将某信号发送给某进程
- sigreturn: 清除堆栈帧，从信号处理例程返回
  #figure(
    image("pic/2025-11-22-12-57-08.png", width: 80%),
    numbering: none,
  )
  ```rs
  // 设置信号处理例程
  // signum：指定信号
  // action：新的信号处理配置
  // old_action：老的的信号处理配置
  sys_sigaction(signum: i32,
    action: *const SignalAction,
    old_action: *const SignalAction)
    -> isize

  pub struct SignalAction {
      // 信号处理例程的地址
      pub handler: usize,
      // 信号掩码
      pub mask: SignalFlags
  }

  // 设置要阻止的信号
  // mask：信号掩码
  sys_sigprocmask(mask: u32) -> isize

  // 清除堆栈帧，从信号处理例程返回
  sys_sigreturn() -> isize

  // 将某信号发送给某进程
  // pid：进程pid
  // signal：信号的整数码
  sys_kill(pid: usize, signal: i32) -> isize
  ```

*信号的核心数据结构*
- 进程控制块中的信号核心数据结构
  ```rs
  pub struct TaskControlBlockInner {
      ...
      pub signals: SignalFlags,     // 要响应的信号
      pub signal_mask: SignalFlags, // 要屏蔽的信号
      pub handling_sig: isize,      // 正在处理的信号
      pub signal_actions: SignalActions,       // 信号处理例程表
      pub killed: bool,             // 任务是否已经被杀死了
      pub frozen: bool,             // 任务是否已经被暂停了
      pub trap_ctx_backup: Option<TrapContext> //被打断的trap上下文
  }
  ```
*建立signal_handler*
- ```rs
  fn sys_sigaction(signum: i32, action: *const SignalAction,
                            old_action: *mut SignalAction) -> isize {
    //保存老的signal_handler地址到old_action中
    let old_kernel_action = inner.signal_actions.table[signum as usize];
    *translated_refmut(token, old_action) = old_kernel_action;
    //设置新的signal_handler地址到TCB的signal_actions中
    let ref_action = translated_ref(token, action);
    inner.signal_actions.table[signum as usize] = *ref_action;
  ```
- 对于需要修改的信号编号signum：
  - 保存老的signal_handler地址到old_action
  - 设置action为新的signal_handler地址
*通过kill发出信号*
- ```rs
  fn sys_kill(pid: usize, signum: i32) -> isize {
        let Some(task) = pid2task(pid);
        // insert the signal if legal
        let mut task_ref = task.inner_exclusive_access();
        task_ref.signals.insert(flag);
       ...
  ```
- 对进程号为pid的进程发送值为signum的信号：
  - 根据pid找到TCB
  - 在TCB中的signals插入signum信号值
*通过kill发出和处理信号的过程*
- 当pid进程进入内核后，直到从内核返回用户态前的执行过程：
  ```
  执行APP --> __alltraps
            --> trap_handler
                --> handle_signals
                    --> check_pending_signals
                        --> call_kernel_signal_handler
                        --> call_user_signal_handler
                          -->  // backup trap Context
                                // modify trap Context
                                trap_ctx.sepc = handler; //设置回到中断处理例程的入口
                                trap_ctx.x[10] = sig;   //把信号值放到Reg[10]
                --> trap_return //找到并跳转到位于跳板页的`__restore`汇编函数
          -->  __restore //恢复被修改过的trap Context，执行sret
    执行APP的signal_handler函数
  ```
*APP恢复正常执行*
- 当进程号为pid的进程执行完signal_handler函数主体后，会发出`sys_sigreturn`系统调用:
  ```rs
  fn sys_sigreturn() -> isize {
    ...
    // 恢复之前备份的trap上下文
    let trap_ctx = inner.get_trap_cx();
    *trap_ctx = inner.trap_ctx_backup.unwrap();
    ...
  ```
  ```
  执行APP --> __alltraps
        --> trap_handler
              --> 处理 sys_sigreturn系统调用
              --> trap_return //找到并跳转到位于跳板页的`__restore`汇编函数
      -->  __restore //恢复被修改过的trap Context，执行sret
  执行APP被打断的地方
  ```
*屏蔽信号*
- 把要屏蔽的信号直接记录到TCB的signal_mask数据中
  ```rs
  fn sys_sigprocmask(mask: u32) -> isize {
      ...
      inner.signal_mask = flag;
      old_mask.bits() as isize
      ...
  ```
