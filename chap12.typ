#import "@preview/scripst:1.1.1": *

= 同步与互斥

== 概述

=== 北京

*背景*
- 独立进/线程
  - 不和其他进/线程共享资源或状态
  - 确定性 $=>$ 输入状态决定结果
  - 可重现 $=>$ 能够重现起始条件
  - 调度顺序不重要
  #figure(
    image("pic/2025-12-09-20-06-31.png", width: 30%),
    numbering: none,
  )
  即使是最简单的一条语句`new_pid = next_pid++`在汇编层面也不是原子的
- 进/线程如果有资源共享
  - 存在不确定性
  - 存在不可重现
  - 可能出现难以重现的错误
- 有资源共享的进/线程执行fork时的可能错误
  #figure(
    image("pic/2025-12-09-20-05-22.png", width: 80%),
    numbering: none,
  )

*原子操作（Atomic Operation）*
- 原子操作是指*一次不存在任何中断或失败的操作*
  - 要么操作成功完成
  - 或者操作没有执行
  - 不会出现部分执行的状态
- 操作系统需要利用同步机制在并发执行的同时，保证一些操作是原子操作
  #figure(
    image("pic/2025-12-09-20-06-00.png", width: 80%),
    numbering: none,
  )

*同步与互斥*
- 同步与互斥提供：
  #three-line-table[
    | 问题                   | 解决方式           |
    | -------------------- | -------------- |
    | 防止 interleaving 导致错误 | 原子操作（atomic）   |
    | 多线程修改共享资源            | 互斥锁（mutex）     |
    | 控制多个线程按顺序执行          | 信号量（semaphore） |
    | 在条件满足前阻塞某线程          | 条件变量（condvar）  |
    | 消费者—生产者模型            | 管程（monitor）    |
  ]
- 同步与互斥的本质问题：
  - CPU 调度让指令随机交错运行，而大多数语句在机器级别不是原子的
  - 因此只要存在 共享变量，就必须保证：
    - 要么序列化访问（mutex）
    - 要么使用不可分割的硬件原子指令（atomic）
    - 要么用更高级语言/OS 提供的同步机制（信号量、管程等）

=== 现实生活中的同步互斥

*同步与互斥*
- *互斥（Mutual Exclusion）*：某段关键代码（临界区）在任意时刻只能被一个线程执行。
  - 修改共享变量 `next_pid`
  - 修改文件元数据
  - 分配内存
  - 更新页表
- *同步（Synchronization）*：线程之间需要按某种顺序进行协作。
  - 子线程必须在父线程之后完成某个阶段
  - 线程必须等待某条件达成（信号量、条件变量）

*现实生活中的同步互斥*
- 例如: 家庭采购协调 (利用现实生活问题帮助理解操作系统同步问题)
  - 注意，计算机与人的差异
    #figure(
      image("pic/2025-12-09-20-08-29.png", width: 80%),
      numbering: none,
    )
- 如何保证家庭采购协调的成功和高效
  - 需要采购时，有人去买面包
  - 最多只有一个人去买面包
- 可能的解决方法
  - 在冰箱上设置一个锁和钥匙（ lock&key）
  - 去买面包之前锁住冰箱并且拿走钥匙
- 加锁导致的新问题
  - 冰箱中还有其他食品时，别人无法取到
- *方案一：先检查，后留便签*
  - 使用便签来避免购买太多面包
    - 购买之前留下一张便签
    - 买完后移除该便签
    - 别人看到便签时，就不去购买面包
  ```c
  if (nobread) {
      if (noNote) {
          leave Note;
          buy bread;
          remove Note;
      }
  }
  ```
  - 方案一的分析
    - 偶尔会购买太多面包 - 重复
      - 检查面包和便签后帖便签前，有其他人检查面包和便签
    - 解决方案只是间歇性地失败
      - 问题难以调试
      - 必须考虑调度器所做事情
  #figure(
    image("pic/2025-12-09-20-11-45.png", width: 80%),
    numbering: none,
  )
- *方案二：先留便签，后检查*
  - 先留便签，后查面包和便签
  ```c
  leave Note;
  if (nobread) {
    if (noNote) {
        buy bread;
      }
  }
  remove note;
  ```
  - 会发生什么？不会有人买面包
  #figure(
    image("pic/2025-12-09-20-13-16.png", width: 80%),
    numbering: none,
  )
- *方案三：先留不同便签，后检查*
  - 为便签增加标记，以区别不同人的便签
  - 现在可在检查之前留便签
  ```c
  // 进程A
  leave note_2;
  if (no note_1) {
    if (no bread) {
      buy bread;
    }
  }
  remove note_2;
  // 进程B
  leave note_1;
  if (no note_2) {
    if (no bread) {
      buy bread;
    }
  }
  remove note_1;
  ```
  #figure(
    image("pic/2025-12-09-20-14-34.png", width: 80%),
    numbering: none,
  )
  - 会发生什么？
    - 可能导致没有人去买面包
    - 每个人都认为另外一个去买面包
- *方案四：采用不同流程* Peterson 算法
  - 两个人采用不同的处理流程
  #figure(
    image("pic/2025-12-09-20-15-14.png", width: 80%),
    numbering: none,
  )
  - 两个人采用不同的处理流程
    - 现在有效吗？
      - 它有效，但太复杂
    - A和B的代码不同
      - 如果线程更多，怎么办？
    - 当A等待时，不能做其他事
      - 忙等待（busy-waiting）
- *方案五：采用原子操作*
  - 利用两个原子操作实现一个锁(lock)
  - `Lock.Acquire()`
    - 在锁被释放前一直等待，然后获得锁
    - 如果两个线程都在等待同一个锁，并且同时发现锁被释放了，那么只有一个能够获得锁
  - `Lock.Release()`
    - 解锁并唤醒任何等待中的线程
  #figure(
    image("pic/2025-12-09-20-21-08.png", width: 50%),
    numbering: none,
  )
  - Acquire = 一个硬件原子操作
    - “检查锁是否空闲 + 抢占锁” 在硬件层面是一条不可中断的操作
    - 这是现代操作系统锁的唯一可靠基础

=== 临界区

在每个并发程序中，都存在一段代码，它会访问“共享资源”，并且这个资源不能被多个线程同时操作 —— 这段代码就叫：*临界区(Critical Section)*

典型的共享资源包括：
- 共享变量（如 next_pid）
- 链表、哈希表
- 文件系统元数据
- 进程管理表
- 页表 FrameAllocator
- 标准输出缓冲区

*临界区(Critical Section)的结构*
```
entry section
  critical section
exit section
  remainder section
```
- 进入区(entry section)
  - 检查可否进入临界区的一段代码
  - 如可进入，设置相应"正在访问临界区"标志
- 临界区(critical section)
  - 线程中访问临界资源的一段需要互斥执行的代码
- 退出区(exit section)
  - 清除“正在访问临界区”标志
- 剩余区(remainder section)
  - 代码中的其余部分
- 可以对应 OS 中类似操作：
  - entry：`mutex.lock()`、`spin_lock()`
  - exit：`mutex.unlock()`
  - remainder：普通用户逻辑
*临界区访问规则*
- *空闲则入*：没有线程在临界区时，任何线程可进入
- *忙则等待*：有线程在临界区时，其他线程均不能进入临界区
- *有限等待*：等待进入临界区的线程不能无限期等待
- *让权等待*（可选）：不能进入临界区的线程，应释放CPU（如转换到阻塞状态）

=== 同步互斥的方法

==== 禁用硬件中断

*禁用硬件中断*
- 没有中断，没有上下文切换，因此没有并发
  - 硬件将中断处理延迟到中断被启用之后
  - 现代计算机体系结构都提供指令来实现禁用中断
  ```
  local_irq_save(unsigned long flags);
      critical section
  local_irq_restore(unsigned long flags);
  ```
- 进入临界区：禁止所有中断，并保存标志
- 离开临界区：使能所有中断，并恢复标志
- 缺点
  - 禁用中断后，线程无法被停止
    - 整个系统都会为此停下来
    - 可能导致其他线程处于饥饿状态
  - 临界区可能很长
    - 无法确定响应中断所需的时间（可能存在硬件影响）
  - 不适合多核
- 要小心使用

==== 基于软件的解决方法

*基于软件的解决方法*
#figure(
  image("pic/2025-12-09-21-06-33.png", width: 50%),
  numbering: none,
)
*尝试一：根据turn值进入临界区*
- 满足“忙则等待”，但是有时不满足“空闲则入”
  ```c
  // 线程 Tj
  do {
    while (turn != j) ;
    critical section
    turn = i;
    remainder section
  } while(1)
  ```
- 强制轮流法
- Ti不在临界区，Tj想要继续运行，但是必须等待Ti进入过临界区后
- turn = 0;
  - T0 不需要访问临界区
  - T1 需要访问，但没有轮到，只能一直等待
  #figure(
    image("pic/2025-12-09-21-11-51.png", width: 50%),
    numbering: none,
  )
*尝试二：根据flag进入临界区*
- 互相依赖（线程忙等）
- 不满足“忙则等待”
  - `flag[i]=flag[j]=0`
  ```c
  // 线程 Tj
  do {
    while (flag[i] == 1) ;
    flag[j] = 1;
    critical section
    flag[j] = 0;
    remainder section
  } while(1)
  ```
  #figure(
    image("pic/2025-12-09-21-19-51.png", width: 50%),
    numbering: none,
  )
  - 同时执行：
    ```
    T0: check flag1 == 0  ----+
    T1: check flag0 == 0       |
                              +-- race condition
    T0: flag0 = 1         <----+
    T1: flag1 = 1
    ```
*尝试三：根据flag进入临界区*
- 满足“忙则等待”，但是不满足“空闲则入”
  - flag[i]=flag[j]=1
  ```c
  // 线程 Tj
  do {
    flag[j] = 1;
    while (flag[i] == 1) ;
    critical section
    flag[j] = 0;
    remainder section
  } while(1)
  ```
  #figure(
    image("pic/2025-12-09-21-20-42.png", width: 50%),
    numbering: none,
  )
*Peterson算法 turn+flag*
- 满足线程Ti和Tj之间互斥的经典的基于软件的解决方法（1981年）
- 孔融让梨
- 主动声明意图（flag变量）
- 礼貌谦让（turn变量）
- 安全检查（循环验证）
- 结合：
  - `flag` 表示：我想进入
  - `turn` 表示：我礼让对方
  #figure(
    image("pic/2025-12-09-21-22-54.png", width: 80%),
    numbering: none,
  )
  ```rust
  // 共享变量
  let mut flag = [false; N]; // 标识进程是否请求进入临界区
  let mut turn = 0; // 记录应该让哪个进程进入临界区
  // 进程P0
  while (true) {
      flag[0] = true;
      turn = 1;
      while (flag[1] == true && turn == 1) ;
      // 进入临界区执行任务
      // 退出临界区
      flag[0] = false;
  }
  // 进程P1
  while (true) {
      flag[1] = true;
      turn = 0;
      while (flag[0] == true && turn == 0) ;
      // 进入临界区执行任务
      // 退出临界区
      flag[1] = false;
  }

  //进程Pi
  flag[i] = True;
  turn = j;
  while(flag[j] && turn == j);
  critical section;
  flag[i] = False;
  remainder section;
  //进程Pj
  flag[j] = True;
  turn = i;
  while(flag[i] && turn == i);
  critical section;
  flag[j] = False;
  remainder section;
  ```
  #figure(
    image("pic/2025-12-09-21-23-33.png", width: 40%),
    numbering: none,
  )
  - Peterson 只在理论和单核强顺序机器模型中正确
  - 现代 CPU 上不能用

*Dekkers算法*
- 声明阶段：举起flag标志牌声明意图
- 竞争阶段：若对方在竞争，根据turn退让
- 释放阶段：使用完资源后切换turn，保公平
  ```c
  do{
    flag[0] = true;// 首先P0举手示意我要访问
    while(flag[1]) {// 看看P1是否也举手了
      if(turn==1){// 如果P1也举手了，那么就看看到底轮到谁
          flag[0]=false;// 如果确实轮到P1，那么P0先把手放下（让P1先）
          while(turn==1);// 只要还是P1的时间，P0就不举手，一直等
          flag[0]=true;// 等到P1用完了（轮到P0了），P0再举手
      }
    }
    critical section;// 访问临界区
    turn = 1;// P0访问完了，把轮次交给P1，让P1可以访问
    flag[0]=false;// P0放下手
    remainder section;
  } while(true);
  ```
  #figure(
    image("pic/2025-12-09-21-24-37.png", width: 40%),
    numbering: none,
  )
  #figure(
    image("pic/2025-12-09-21-24-50.png", width: 80%),
    numbering: none,
  )

*N线程*Eisenberg和McGuire
- 一个共享的turn变量，若干线程排成一个环
- 每个环有个flag标志，想要进入临界区填写flag标志
- 有多个想进入临界区，从前往后走，执行完一个线程，turn改为下一个线程的值。
  #figure(
    image("pic/2025-12-09-21-25-47.png", width: 80%),
    numbering: none,
  )
- 初始化
  ```c
  INITIALIZATION:

  enum states flags[n -1]; //{IDLE, WAITING, ACTIVE}
  int turn;
  for (index=0; index<n; index++) {
    flags[index] = IDLE;
  }
  ```
- 进入临界区
  ```c
  ENTRY PROTOCOL (for Process i ):
  repeat {//从turn到i是否存在请求进程:若存在，则不断循环，直至不存在这样的进程，将当前进程标记为ACTIVE
    flags[i] = WAITING;//表明自己需要资源
    index = turn;//轮到谁了
    while (index != i) {//从turn到i轮流找不idle的线程
        if (flag[index] != IDLE) index = turn;//turn到i有非idle的阻塞
        else index = (index+1) mod n; //否则轮到i，并跳出
    }
    flags[i] = ACTIVE;//Pi active; 其他线程有可能active
    //对所有ACTIVE的进程做进一步的判断，判断除了当前进程以外，是否还存在其他ACTIVE的进程
    index = 0;//看看是否还有其他active的
    while ((index < n) && ((index == i) || (flags[index] != ACTIVE))) {
        index = index+1;
    }//如果后面没有active了，并且轮到Pi或者turn idle, 就轮到i;否则继续循环
  } until ((index >= n) && ((turn == i) || (flags[turn] == IDLE)));
  turn = i;//获得turn并处理
  ```
- 离开临界区
  ```c
  EXIT PROTOCOL (for Process i ):

  index = turn+1 mod n;//找到一个不idle的
  while (flags[index] == IDLE) {
    index = index+1 mod n;
  }
  turn = index;//找到不idle的设置为turn；或者设置为自己
  flag[i] = IDLE;//结束，自己变idle
  ```

==== 更高级的抽象方法

*更高级的抽象方法*
- 基于软件的解决方法
  - 复杂，需要忙等待
- 更高级的抽象方法
  - 硬件提供了一些同步原语
    - 中断禁用，原子操作指令等
  - 操作系统提供更高级的编程抽象来简化线程同步
    - 例如：锁、信号量
    - 用硬件原语来构建

*锁(lock)*
- 锁是一个抽象的数据结构
  - 一个二进制变量（锁定/解锁）
  - 使用锁来控制临界区访问
  - `Lock::Acquire()`
    - 锁被释放前一直等待，后得到锁
  - `Lock::Release()`
    - 释放锁，唤醒任何等待的线程
  ```c
  lock next pid->Acquire();
    new pid = next pid++;
  lock next pid->Release();
  ```
- 现代CPU提供一些特殊的原子操作指令
  - *测试和置位（Test-and-Set）指令*
    - 从内存单元中读取值
    - 测试该值是否为1(然后返回真或假)
    - 内存单元值设置为1
      - 输入0，改成1，返回0；
      - 输入1，保持1，返回1；
  ```c
  bool TestAndset(bool *target){
    bool rv= *target;
    *target = true;
    return rv;
  }
  ```
  ```c
  do {
    while(TestAndSet(&lock)） ;
    critical section;
    lock = false;
    remainder section;
  } while (true)
  ```
  ```c
  lock(): while(TestAndSet(&lock));
  critical section;
  unlock(): lock=false;
  ```
- 原子操作：交换指令CaS（Compare and Swap）
  ```c
  bool compare_and_swap(int *value, int old, int new) {
    if(*value==old) {
        *value = new;
        return true; }
    return false;
  }
  ```
  ```c
  int lock = 0;                           // 初始时锁空闲
  while(!compare_and_swap(&lock,0,1));    // lock 加锁
  critical section;
  lock=0;                                 // unlock 解锁
  remainder section;
  ```
  - CAS（Compare-And-Swap）指令看似非常强大，但它有一个经典漏洞：ABA 问题
    - value= 100；
    - Thread1: value - 50; `//成功 value=50`
    - Thread2: value - 50; `//阻塞`
    - Thread3: value + 50; `//成功 value=100`
    - Thread2: 重试成功
  - 解决思路：加上版本号（时间戳）
    - (100,1); (50,2); (100,3)
  - CAS 只比较值是否相等，而不检查该值是否“变化过”。
- 使用TaS指令实现自旋锁(spinlock)
  - 线程在等待的时候消耗CPU时间
  #figure(
    image("pic/2025-12-09-21-55-34.png", width: 80%),
    numbering: none,
  )
  - 自旋锁：线程在等待锁时 不断循环检查 是否可以获得锁，不会主动放弃 CPU
    - 忙等（busy-waiting）、不会引起线程切换，因此非常快、但会浪费 CPU
- 忙等锁 v.s. 等待锁
  #figure(
    image("pic/2025-12-09-21-55-47.png", width: 80%),
    numbering: none,
  )

- 优点
  - 适用于单处理器或者共享主存的多处理器中任意数量的线程同步
  - 简单并且容易证明
  - 支持多临界区
- 缺点
  - 忙等待消耗处理器时间
  - 可能导致饥饿
    - 线程离开临界区时有多个等待线程的情况
  - 可能死锁：线程间相互等待，无法继续执行

#note(subname: [小结])[
  *常用的三种同步实现方法*
  - 禁用中断（仅限于单处理器）
  - 软件方法（复杂）
  - 锁是一种高级的同步抽象方法
    - 硬件原子操作指令（单处理器或多处理器均可）
    - 互斥可以使用锁来实现
]

== 信号量

*信号量(semaphore)*
- 信号量是操作系统提供的一种协调共享资源访问的方法
- Dijkstra在20世纪60年代提出
- 早期的操作系统的主要同步机制
  #figure(
    image("pic/2025-12-09-22-11-03.png", width: 80%),
    numbering: none,
  )
- 信号量是一种抽象数据类型，由一个整型(sem)变量和两个原子操作组成
  - P()：Prolaag 荷兰语：尝试减少
    - `sem = sem - 1`
    - `sem<0`进入等待, 否则继续
  - V()：Verhogen 荷兰语：尝试增加
    - `sem = sem + 1`
    - `sem<=0`唤醒等待线程
  #figure(
    image("pic/2025-12-09-22-12-31.png", width: 80%),
    numbering: none,
  )
- 信号量是被保护的整数变量
  - 初始化完成后，只能通过P()和V()操作修改
  - 由操作系统保证，PV操作是原子操作
- P()可能阻塞，V()不会阻塞
- 通常假定信号量是“公平的”
  - 线程不会被无限期阻塞在P()操作
  - 假定信号量等待按先进先出排队
- 问题：自旋锁能否实现先进先出?

*信号量在概念上的实现*
```c
Class Semaphore {
  int sem;
  WaitQueue q;
}
```
```c
Semaphore::P() {
    sem--；
    if (sem < 0) {
      Add this thread t to q;
      block(t)
    }
}
Semaphore::V() {
    sem++；
    if (sem <= 0) {
      Remove a thread t from q;
      wakeup(t)
    }
}
```
以及
```
Semaphore::P() {
    while (sem <= 0) {
      Add this thread t to q;
      block(t)
    }
    sem--；
}
```
问题：这个实现与上一个有什么不同？

- 问题
  - 存在设计缺陷，无法正常工作
  - 信号量始终非负（sem<=0不成立），不会唤醒阻塞线程。因此无法在信号量为正时唤醒线程，导致永久阻塞
    - 示例：初始 sem = 1。
    - 线程A调用 P()：退出循环，sem = 0。
    - 线程B调用 P()：发现 sem = 0，进入循环并阻塞。
    - 线程A调用 V()：sem = 1，但 sem <= 0 不成立，不唤醒线程B。
    - 结果：线程B永久阻塞，系统死锁。
    - 检查和减操作必须是原子的，而 while 方案破坏了这个顺序

*信号量的分类和使用*
- 信号量的分类
  - 二进制信号量：资源数目为0或1
  - 计数信号量:资源数目为任何非负值
- 信号量的使用
  - 互斥访问
  - 条件同步

*互斥访问举例*
- 每个临界区设置一个初值为1的信号量
- 成对使用P()操作和V()操作
  - P()操作保证互斥访问资源
  - V()操作在使用后释放资源
  - PV操作次序不能错误、重复或遗漏
  ```c
  mutex = new Semaphore(1); // 初始化信号量
  mutex->P();           // 进入临界区
    critical section;
  mutex->V();           // 离开临界区
  ```
*条件同步举例*
- 每个条件同步设置一个信号量，其初值为0
  #figure(
    image("pic/2025-12-09-22-15-55.png", width: 80%),
    numbering: none,
  )
  比如 A 必须等待 B 做完某件事

*生产者-消费者问题*
- 有界缓冲区的生产者-消费者问题描述
  - 一个或多个生产者在生成数据后放在一个缓冲区里
  - 单个消费者从缓冲区取出数据处理
  - 任何时刻只能有一个生产者或消费者可访问缓冲区
  #figure(
    image("pic/2025-12-09-22-16-22.png", width: 80%),
    numbering: none,
  )
- 问题分析
  - 任何时刻只能有一个线程操作缓冲区（互斥访问）
  - 缓冲区空时，消费者必须等待生产者（条件同步）
  - 缓冲区满时，生产者必须等待消费者（条件同步）
- 用信号量描述每个约束
  - 二进制信号量mutex
  - 计数信号量fullBuffers
  - 计数信号量emptyBuffers
  #figure(
    image("pic/2025-12-09-22-19-43.png", width: 80%),
    numbering: none,
  )
  ```c
  mutex = Semaphore(1);
  emptyBuffers = Semaphore(N);
  fullBuffers = Semaphore(0);

  // 生产者
  emptyBuffers->P(); // 等待空槽
  mutex->P();
  Add item
  mutex->V();
  fullBuffers->V(); // 增加可消费项目

  // 消费者
  fullBuffers->P(); // 等待满槽
  mutex->P();
  Remove item
  mutex->V();
  emptyBuffers->V(); // 增加可生产空槽
  ```
  - P、V操作的顺序有影响吗？
- 读/开发代码比较困难
- 容易出错
  - 使用已被占用的信号量
  - 忘记释放信号量
  - 不能够避免死锁问题
  - 对程序员要求较高

== 管程与条件变量

=== 管程（Monitor）、条件变量（Condition Variable）

*为什么引入管程？*传统PV和锁机制的可读性差
- 程序*可读性差*：要了解对于一组共享变量及信号量的操作是否正确，则必须通读整个系统或者并发程序
- 程序*不利于修改和维护*：程序局部性很差，所以任一组变量或一段代码的修改都可能影响全局
- *正确性*难以保证：操作系统或并发程序通常很大，很难保证一个复杂的系统没有逻辑错误。
- 容易发生*死锁*：如果不使用好P、V操作时，逻辑上发生错误，很有可能会导致死锁。

*管程*
- 管程是一种用于*多线程互斥访问共享资源*的*程序结构*
- 采用*面向对象方法*，简化了线程间的同步控制
- *任一时刻最多只有一个线程执行管程代码*
- 正在管程中的线程可临时放弃管程的互斥访问，等待事件出现时恢复
- 管程提供三个关键特征：
  - 互斥进入（Mutual Exclusion）
    - 任意时刻最多只有一个线程在执行管程内的代码
    - 不需要程序员写 `mutex.lock() / unlock()`
  - 条件同步（Condition Synchronization）
    - 当线程在管程内发现资源不可用时，可以：
      - `wait(c)`：让出管程并进入条件变量 c 的等待队列
      - `signal(c)`：唤醒在条件变量 c 上等待的某个线程
    - 数据封装（Encapsulation）
      - 管程中的共享变量对外不可见
      - 外部只能通过管程提供的方法访问共享数据
      - 就像一个“类 + 自动加锁机制”
  #figure(
    image("pic/2025-12-09-23-48-45.png", width: 80%),
    numbering: none,
  )
- 模块化，一个管程是一个基本程序单位，可以单独编译
- 抽象数据类型，管程是一种特殊的数据类型，其中不仅有数据，而且有对数据进行操作的代码
- 信息隐蔽，管程是半透明的，管程中的过程（函数）实现了某些功能，在其外部则是不可见的
  #figure(
    image("pic/2025-12-09-23-56-30.png", width: 80%),
    numbering: none,
  )
  - 管程内部有 共享变量
  - 每个 条件变量 有一个等待队列
  - 管程入口处有一个 入口队列（entry queue）
  - signal 会让执行权转交（handoff）
  #three-line-table[
    | 组成部分                          | 作用                         |
    | ----------------------------- | -------------------------- |
    | *共享变量*                      | 被多个线程共同使用，由管程管理            |
    | *互斥锁（monitor lock）*         | 保证管程一次只允许一个线程执行            |
    | *条件变量（Condition Variables）* | 用于线程等待和唤醒                  |
    | *入口等待队列*                    | 还没进入管程的线程排队                |
    | *条件等待队列*                    | 因资源不可用而 wait() 的线程         |
    | *紧急等待队列*                    | signal 后被挂起的线程存放处（为了优先权转移） |
  ]

*管程的外部特征*
- 管程中的共享变量在管程外部是不可见的，外部只能通过调用管程中所说明的外部过程(函数)来间接地访问管程中的共享变量
- *互斥*：任一时刻管程中只能有一个活跃进程，通过锁竞争进入管程
- *等待*：进入管程的线程因资源被占用而进入等待状态
  - 每个条件变量表示一种等待原因，对应一个等待队列
  - 入口队列管理未进入管程的线程/进程
- *唤醒*：管程中等待的线程可以在其他线程释放资源时被唤醒
- *管程操作*：进入`enter`, 离开`leave`, 等待`wait`, 唤醒`signal`

*条件变量*（Condition Variable）
- 用来处理“等待某个条件成立”
- 条件变量是多线程编程中的一种*同步机制*，用于线程间通信和协调
  - 它是一个*结构体*，包含了一个*等待队列、等待和唤醒等操作函数*
  - 通过条件变量实现线程的阻塞、唤醒和通讯等功能
- 条件变量与互斥锁（mutex）配合，可实现线程间的同步和互斥
  - 共享资源被占用时，*线程可通过条件变量挂起自己*
  - 其他线程释放该资源后，继续执行

*条件变量的主要操作*
- 初始化：通过`pthread_cond_init()`函数初始化一个条件变量
- 销毁：通过`pthread_cond_destroy()`函数销毁一个条件变量
- 等待：通过`pthread_cond_wait()`函数在条件变量上等待，线程会自动解锁互斥锁并进入等待状态，直到被唤醒
  - 当前线程进入条件变量 c 的等待队列
  - 自动释放 monitor lock
  - 然后阻塞
  - 等 `signal(c)` 来唤醒
- 唤醒：通过`pthread_cond_signal()`或`pthread_cond_broadcast()`函数唤醒一个或多个等待在条件变量上的线程
  - 唤醒一个等待在条件变量 c 上的线程
  - 当前线程必须将管程执行权让给被唤醒的线程（Hoare 语义）
  - 本线程进入紧急等待队列

*条件变量的使用步骤*
- 创建条件变量和互斥锁，并初始化它们
- 线程在持有互斥锁时，可修改或访问共享资源
- 当共享资源被其他线程占用时，当前线程阻塞自己，并让出互斥锁，等待条件变量唤醒
- 线程释放共享资源后，可通过条件变量唤醒等待在条件变量上的线程，让它们重新尝试获取共享资源并执行相应的操作

*管程的组成*
- 一个由过程（函数）、变量及数据结构等组成的一个集合
  - 一个锁：控制管程代码的互斥访问
  - 0或者多个条件变量: 管理共享数据的并发访问，每个条件变量有个等待（紧急）队列
  - 入口等待队列：管程入口处等待队列
  - 条件变量队列：某个条件变量的等待队列（为资源占用而等待）
  - 紧急等待队列：唤醒使用的紧急队列
    - 当T1线程执行唤醒操作而唤醒T2，如果T1把访问权限交给T2，T1被挂起；T1放入紧急等待队列
    - 紧急等待队列优先级高于条件变量等待队列

*管程操作*
- T.enter过程：线程T在进入管程之前要获得互斥访问权(lock)
- T.leave过程：当线程T离开管程时，如果紧急队列不为空，唤醒紧急队列中的线程，并将T所持锁赋予唤醒的线程；如果紧急队列为空，释放lock，唤醒入口等待队列某个线程
- T.wait(c)：
  + 阻塞线程T自己，将T自己挂到条件变量c的等待队列；
  + 释放所持锁；
  + 唤醒入口等待队列的一个或者多个线程；
- T.signal(c)：
  + 把条件变量c的等待队列某个线程唤醒；
  + 把线程T所持lock给被唤醒的线程；
  + 把线程T自己挂在紧急等待队列
  #figure(
    image("pic/2025-12-10-00-20-22.png", width: 80%),
    numbering: none,
  )

=== 管程实现方式

*管程实现方式*
- 如果线程T1因条件A未满足处于阻塞状态，那么当线程T2让条件A满足并执行signal操作唤醒T1后，不允许线程T1和T2同时处于管程中，那么如何确定哪个执行/哪个等待？
- 管程中条件变量的释放处理方式
  - Hoare管程：T1执行/T2等待，直至T1离开管程，然后T2继续执行
  - MESA/Hansen管程：T2执行/T1等待，直至T2离开管程，然后T1可能继续执行（重新竞争/直接执行）
  - 线程 T2 的signal，使线程 T1 等待的条件满足时
    - Hoare：T2 通知完 T1后，T2 阻塞，T1 马上执行；等 T1 执行完，再唤醒 T2 执行
    - Hansen： T2 通知完 T1 后，T2 还会接着执行，T2 执行结束后（规定：最后操作是signal），然后 T1 再执行（将锁直接给T1）
    - MESA：T2 通知完 T1 后，T2 还会接着执行，T1 并不会立即执行，而是重新竞争访问权限
  #figure(
    image("pic/2025-12-10-00-24-15.png", width: 80%),
    numbering: none,
  )
  #figure(
    image("pic/2025-12-10-00-24-31.png", width: 80%),
    numbering: none,
  )
  - 唤醒一个线程的两种选择：直接赋予锁 vs 重新公平竞争锁
    #figure(
      image("pic/2025-12-10-00-24-53.png", width: 80%),
      numbering: none,
    )
*Hoare管程*
```
1. T1 进入管程monitor
2. T1 等待资源 (进入等待队列wait queue)
3. T2 进入管程monitor
4. T2 资源可用 ，通知T1恢复执行，
   并把自己转移到紧急等待队列
5. T1 重新进入管程monitor并执行
6. T1 离开monitor
7. T2 重新进入管程monitor并执行
8. T2 离开管程monitor
9. 其他在entry queue中的线程通过竞争
   进入管程monitor
```
#figure(
  image("pic/2025-12-10-00-27-09.png", width: 50%),
  numbering: none,
)
- #three-line-table[
    | 特性              | 描述                     |
    | --------------- | ---------------------- |
    | *signal 立即让权* | T1 立即执行，不必重新竞争         |
    | *条件语义最强*      | signal 保证 “条件此刻为真”     |
    | *实现复杂*        | 需要紧急等待队列（urgent queue） |
    | *性能较低*        | 上下文切换频繁                |
  ]
- 好处
  - wait 后立即恢复执行，不需重新检查条件
  - 正确性容易推理
- 缺点
  - 运行时开销巨大
  - 现代语言很少使用
*Mesa管程*
```
1. T1 进入管程monitor
2. T1 等待资源
  (进入wait queue，并释放monitor)
3. T2 进入monitor
4. T2 资源可用，通知T1
  (T1被转移到entey queue，重新平等竞争)
5. T2 继续执行
6. T2 离开monitor
7. T1 获得执行机会，从entry queue
   出队列，恢复执行
8. T1 离开monitor
9. 其他在entry queue中的线程通过竞争
   进入monitor
```
#figure(
  image("pic/2025-12-10-00-28-19.png", width: 80%),
  numbering: none,
)
- #three-line-table[
    | 特性                 | 描述            |
    | ------------------ | ------------- |
    | *signal 不让权*     | 只是把等待线程放入入口队列 |
    | *醒来要重新竞争锁*       | 没有强条件保证       |
    | *需要 while(wait)* | 因为条件可能已经被他人改写 |
    | *实现简单、性能高*       | 无需紧急队列        |
  ]
- ```c
  mutex.lock();
  while (!condition)
      cond.wait();
  ... do work ...
  mutex.unlock();
  ```
  不能用 if，因为醒来时条件可能已经被破坏
*Hansen管程*
```
1. T1 进入管程monitor
2. T1 等待资源c
3. T2 进入monitor
4. T2 离开Monitor,并给通知等待
   资源c的线程，资源可用
5. T1 重新进入 monitor
6. T1 离开monitor
7. 其他线程从entry queue中通过竞争
   进入monitor
```
#figure(
  image("pic/2025-12-10-00-28-58.png", width: 80%),
  numbering: none,
)
- #three-line-table[
    | 特性                    | 描述                  |
    | --------------------- | ------------------- |
    | *避免紧急队列*            | 因为 signal 后 T2 立即退出 |
    | *等待线程立即执行*          | 类似 Hoare            |
    | *要求 signal 必须是最后一句* | 破坏了程序写法的自由度         |
    | *现代语言基本不用*          | 理论价值更高              |
  ]

#three-line-table[
  | 特性          | Hoare  | Mesa (Java/pthread) | Hansen     |
  | ----------- | ------ | ------------------- | ---------- |
  | signal 后让权？ | ✔ 立即让权 | ✘ 不让权               | ✔ T2 退出后让权 |
  | 等待线程恢复方式    | 立即执行   | 回到入口队列重新竞争          | 立即获得锁      |
  | 条件是否保证成立？   | ✔ 是    | ✘ 不一定               | ✔ 是        |
  | 是否需要 while？ | ❌ 不需要  | ✔ 必须 while          | ❌ 不需要      |
  | 实现难度        | 最高     | 最容易                 | 中等         |
  | 性能          | 最低     | 最优                  | 中等         |
]

=== 条件变量的实现

*条件变量的实现*
#figure(
  image("pic/2025-12-10-00-50-31.png", width: 80%),
  numbering: none,
)
- 条件变量 Condition 的基本结构
  ```c
  Class Condition {
      int numWaiting = 0;
      WaitQueue q;
  }
  ```
  - numWaiting：当前等待在此条件变量上的线程数
  - WaitQueue q：条件队列，每个条件变量都有自己的等待队列
- Condition::Wait(lock)
  ```c
  Condition::Wait(lock){
      numWaiting++;
      Add this thread t to q;
      release(lock); // 等待条件时必须释放互斥锁，否则其他线程无法改变条件，会造成死锁
      schedule(); // need mutex
      require(lock); // 重新获得互斥锁
  }
  ```
- Condition::Signal()
  ```c
  Condition::Signal(){
      if (numWaiting > 0) {
          Remove a thread t from q;
          numWaiting--;
          wakeup(t);
      }
  }
  ```
- 条件变量 = 等待队列 + 释放锁 + 原子阻塞 + 唤醒后重新竞争锁（Mesa）

=== 生产者-消费者问题的管程实现

*生产者-消费者问题的管程实现*
#figure(
  image("pic/2025-12-10-00-56-55.png", width: 80%),
  numbering: none,
)
- 管程内部的数据与同步原语
  ```c
  class BoundedBuffer {
      …
      Lock lock;                    // 互斥锁：保证对缓冲区的访问互斥
      int count = 0;                // 当前缓冲区里元素个数
      Condition notFull, notEmpty;  // 两个条件变量
  }
  ```
  - lock：管程的“门锁”，谁进来操作缓冲区，谁必须先拿到这把锁。
  - count：共享状态，决定当前是“满 / 空 / 中间”。
  - notFull：表示“缓冲区不满”的条件；生产者在 count == n（满）时就等在这里。
  - notEmpty：表示“缓冲区非空”的条件；消费者在 count == 0（空）时就等在这里。
- 生产者：Deposit(c)
  ```c
  BoundedBuffer::Deposit(c) {
      lock->Acquire();                    // 1. 进管程，拿锁

      while (count == n)                  // 2. 缓冲区满了？
          notFull.Wait(&lock);            //    满了就等待“有空位”

      Add c to the buffer;                // 3. 真正往缓冲区里放数据
      count++;

      notEmpty.Signal();                  // 4. 告诉“等着取数据”的消费者：现在不空了
      lock->Release();                    // 5. 离开管程，释放锁
  }
  ```
  - 先拿锁再访问共享数据：保证每次只有一个线程在改 count 和缓冲区。
  - `while(count == n) + wait` 而不是 if
    - Mesa 模型下，signal 只保证“某个时刻条件成立过”，被唤醒时条件可能又变回不满足。
    - 所以醒来后要再次检查，条件不满足就继续等。
  - wait 内部干了三件事
    - 把当前线程放到 notFull 的等待队列；
    - 原子地释放 lock；
    - 把自己挂起（调度其它线程）。
  - 往缓冲区放完数据后 notEmpty.Signal()
    - 只唤醒一个在 notEmpty 上等待的消费者；
    - 被唤醒的消费者不会立刻执行（Mesa），而是加入 entry queue 重新竞争锁。
- 消费者：Remove(c)
  ```c
  BoundedBuffer::Remove() {
      lock->Acquire();                    // 1. 进管程，拿锁

      while (count == 0)                  // 2. 缓冲区空了？
          notEmpty.Wait(&lock);           //    空了就等待“有数据”

      Remove c from the buffer;           // 3. 真正从缓冲区里取数据
      count--;

      notFull.Signal();                   // 4. 告诉“等着放数据”的生产者：现在不满了
      lock->Release();                    // 5. 离开管程，释放锁

      return c;
  }
  ```
  - 和生产者类似，只是条件和操作相反。

*如何使用管程？*
- Java支持管程；C++支持条件变量
  ```java
  public class CounterMonitor {
      private int count = 0; // 共享资源
      // 增加count的方法，这里用synchronized关键字确保互斥访问
      public synchronized void increment() {
          count++; // 可以添加其他逻辑，比如通知等待的线程等
      }
      // 获取count值的方法，也需要同步
      public synchronized int getCount() {
          return count;
      }
  }
  ```

== 同步互斥实例问题

=== 哲学家就餐问题

*哲学家就餐问题*
- 5个哲学家围绕一张圆桌而坐
- 桌子上放着5支叉子
- 每两个哲学家之间放一支叉子
- 哲学家的动作包括思考和进餐
- 进餐时需同时用左右两边的叉子
- 思考时将两支叉子放回原处
如何保证哲学家们的动作有序进行？
- 如：不出现有人永远拿不到叉子

*方案1*
#figure(
  image("pic/2025-12-10-00-59-26.png", width: 80%),
  numbering: none,
)
- 不正确，可能导致死锁
*方案2*
#figure(
  image("pic/2025-12-10-00-59-47.png", width: 80%),
  numbering: none,
)
- 互斥访问正确，但每次只允许一人进餐
*方案3*
#figure(
  image("pic/2025-12-10-01-00-20.png", width: 80%),
  numbering: none,
)
- 没有死锁，可有多人同时就餐
*方案4*
#figure(
  image("pic/2025-12-10-01-00-42.png", width: 80%),
  numbering: none,
)
- AND型信号量集是指同时需要多个资源且每种占用一个资源时的信号量操作。
- 当一段代码需要同时获取两个或多个临界资源时，就可能出现由于各线程分别获得部分临界资源并等待其余的临界资源的局面。各线程都会“各不相让”，从而出现死锁。
- 解决这个问题的一个基本思路是：在一个原语中申请整段代码需要的多个临界资源，*要么全部分配给它，要么一个都不分配给它*。这就是AND型信号量集的基本思想。
- 原子申请多个资源 → 死锁完全避免
- AND型信号量集
  ```
  P(S1, S2, …, Sn)
  {
      While(TRUE)
      {
          if (S1 >=1 and … and Sn>=1 ){
              for( i=1 ;i<=n; i++) Si--;
          break;
          }
          else{
              Place the thread in the waiting queue associated  with the first Si
              found with Si < 1
          }
      }
  }

  V(S1, S2, …, Sn){
      for (i=1; i<=n; i++) {
              Si++ ;
              Remove all the thread waiting in the queue associated with Si into
              the ready queue
      }
  }
  ```
*方案5*（状态机 + 局部信号量）
#figure(
  image("pic/2025-12-10-01-01-47.png", width: 80%),
  numbering: none,
)
#figure(
  image("pic/2025-12-10-01-01-55.png", width: 80%),
  numbering: none,
)
#figure(
  image("pic/2025-12-10-01-02-06.png", width: 80%),
  numbering: none,
)
- 思想：每个哲学家维护一个状态
  ```c
  #define THINKING 0
  #define HUNGRY   1
  #define EATING   2

  int state[N]; // 哲学家状态数组
  semaphore mutex = 1; // 互斥信号量
  semaphore s[N]; // 每个哲学家的信号量
  ```
- take_forks(i)
  ```c
  P(mutex);
  state[i] = HUNGRY;
  test(i);
  V(mutex);
  P(s[i]);   // 若没成功拿叉子则阻塞
  ```
- put_forks(i)
  ```c
  P(mutex);
  state[i] = THINKING;
  test(LEFT);
  test(RIGHT);
  V(mutex);
  ```
- test(i)
  ```c
  if (state[i] == HUNGRY &&
      state[LEFT] != EATING &&
      state[RIGHT] != EATING) {
      state[i] = EATING;
      V(s[i]);
  }
  ```
- 不会死锁：哲学家只有在左右邻居都不吃饭时才能吃 → 不会出现环形等待链。
- 不会饥饿：因为释放叉子后会主动检查邻居是否可被唤醒。
- 高并行度：允许远离的哲学家同时吃饭（例如 0 号和 2 号）。
- 可扩展到 N 个哲学家：只需要增加数组大小即可。

=== 读者-写者问题

==== 读者-写者问题描述

*读者-写者问题*
- 共享数据的两类使用者
  - 读者：只读不修改数据
  - 写者：读取和修改数据
- 对共享数据的读写
  - 多个：“读－读”-- 允许
  - 单个：“读－写”-- 互斥
  - 单个：“写－写”-- 互斥
  #figure(
    image("pic/2025-12-10-01-23-13.png", width: 80%),
    numbering: none,
  )
- 读者优先策略
  - 只要有读者正在读状态，后来的读者都能直接进入
  - 如读者持续不断进入，则写者就处于饥饿
- 写者优先策略
  - 只要有写者就绪，写者应尽快执行写操作
  - 如写者持续不断就绪，则读者就处于饥饿

==== 读者-写者问题的信号量实现

*读者-写者问题的信号量实现方案*
- 用信号量描述每个约束
  - 信号量WriteMutex：控制读写操作的互斥，初始化为1
  - 读者计数Rcount ：正在进行读操作的读者数目，初始化为0
  - 信号量CountMutex：控制对读者计数的互斥修改，初始化为1
  #figure(
    image("pic/2025-12-10-01-24-15.png", width: 80%),
    numbering: none,
  )
  - 读者 Reader
    ```c
    P(CountMutex);
    if (Rcount == 0)
        P(WriteMutex);   // 第一个读者需要锁住写者
    Rcount++;
    V(CountMutex);

    read;   // 多个读者可并发读

    P(CountMutex);
    Rcount--;
    if (Rcount == 0)
        V(WriteMutex);   // 最后一个读者离开，写者可以写
    V(CountMutex);
    ```
  - 写者 Writer
    ```c
    P(WriteMutex);   // 写者需要独占访问
    write;           // 进行写操作
    V(WriteMutex);   // 写操作完成，释放锁
    ```
  - 此实现中，读者优先
    - 多个读者可同时读
    - 写者必须等待所有读者结束
    - 持续有读者进入时，写者可能会饿死

==== 读者-写者问题的管程实现

*管程的状态变量*
#figure(
  image("pic/2025-12-10-01-24-39.png", width: 80%),
  numbering: none,
)
- ```c
  AR = 0; // Active Readers   正在读的读者数
  AW = 0; // Active Writers   正在写的写者数（0 或 1）
  WR = 0; // Waiting Readers  等待读的读者数
  WW = 0; // Waiting Writers  等待写的写者数

  Lock lock;               // 管程互斥锁
  Condition okToRead;      // 读者条件变量
  Condition okToWrite;     // 写者条件变量
  ```
*读者实现*
#figure(
  image("pic/2025-12-10-01-25-06.png", width: 80%),
  numbering: none,
)
- Public 接口
  ```c
  Public Database::Read() {
      StartRead();
      read database;
      DoneRead();
  }
  ```
- StartRead()
  ```c
  lock.Acquire();
  while ((AW + WW) > 0) {     // 有写者在写 或 有写者在等待
      WR++;                   // 我是一个等待的读者
      okToRead.wait(&lock);   // 阻塞等待
      WR--;                   // 被唤醒后减少等待计数
  }
  AR++;                       // 可以开始读
  lock.Release();
  ```
  - 写者优先策略：如果有写者等待，读者不能直接读
  - 所以能避免写者饥饿
- DoneRead()
  ```c
  lock.Acquire();
  AR--;
  if (AR == 0 && WW > 0)          // 没有读者且有写者等待
      okToWrite.signal();         // 唤醒写者
  lock.Release();
  ```
*写者实现*
#figure(
  image("pic/2025-12-10-01-25-24.png", width: 80%),
  numbering: none,
)
- Public 接口
  ```c
  Public Database::Write() {
      StartWrite();
      write database;
      DoneWrite();
  }
  ```
- StartWrite()
  ```c
  lock.Acquire();
  while (AR + AW > 0) {           // 只要有人读或有人写，就不能写
      WW++;                       // 等待写
      okToWrite.wait(&lock);
      WW--;
  }
  AW++;                           // 可以写
  lock.Release();
  ```
- DoneWrite()
  ```c
  lock.Acquire();
  AW--;
  if (WW > 0)                     // 优先唤醒写者
      okToWrite.signal();
  else if (WR > 0)                // 没有写者 → 唤醒所有读者
      okToRead.broadcast();
  lock.Release();
  ```
  #three-line-table[
    | 特点      | 信号量实现          | 管程实现                       |
    | ------- | -------------- | -------------------------- |
    | 抽象级别    | 低，需要人工保证 PV 匹配 | 高，结构化封装自动保证互斥              |
    | 容易出错    | 容易（易遗漏 P/V）    | 难（交给系统处理）                  |
    | 代码可读性   | 差              | 高                          |
    | 适合教学/证明 | 是              | 是，但略复杂                     |
    | 工程语言支持  | 需要手写同步         | C++ Java Go 已内置 monitor 机制 |
  ]

== 死锁

=== 死锁问题

==== 什么是死锁？

*死锁问题*
- 桥梁只能单向通行
- 桥的每个部分可视为一个资c源
  #figure(
    image("pic/2025-12-10-01-27-23.png", width: 80%),
    numbering: none,
  )
- 可能出现死锁
  - 对向行驶车辆在桥上相遇
  - 解决方法：一个方向的车辆倒退(资源抢占和回退)
- 可能发生饥饿
  - 由于一个方向的持续车流，另一个方向的车辆无法通过桥梁

*死锁问题*
- 由于竞争资源或者通信关系，两个或更多线程在执行中出现，永远相互等待只能由其他进程引发的事件
  ```
  Thread 1:    Thread 2:
  lock(L1);    lock(L2);
  lock(L2);    lock(L1);
  ```
  #figure(
    image("pic/2025-12-10-01-28-35.png", width: 80%),
    numbering: none,
  )

==== 资源分配图

*资源请求与使用关系*
- 资源类型$R_1, R_2, ...,R_m$
  - CPU执行时间、内存空间、I/O设备等
- 每类资源$R_i$有$W_i$个实例
- 线/进程访问资源的流程
  - 请求：申请空闲资源
  - 使用：占用资源
  - 释放：资源状态由占用变成空闲
  #figure(
    image("pic/2025-12-10-01-52-27.png", width: 80%),
    numbering: none,
  )
*资源分类*
- 可重用资源（Reusable Resource）
  - 任何时刻只能有一个线/进程使用资源
  - 资源被释放后，其他线/进程可重用
  - 可重用资源示例
    - 硬件：处理器、内存、设备等
    - 软件：文件、数据库和信号量等
  - 可能出现死锁：每个进程占用一部分资源并请求其它资源
- 可消耗资源(Consumable resource)
  - 资源可被销毁
  - 可消耗资源示例
    - 在I/O缓冲区的中断、信号、消息等
  - 可能出现死锁：进程间相互等待接收对方的消息
*资源分配图*
- 描述资源和进程间的分配和占用关系的有向图
- 顶点：系统中的进程 $P={P_1, P_2, ..., P_n}$
- 顶点：系统中的资源 $R={R_1, R_2, ..., R_m}$
- 边：资源请求
  - 进程$P_i$请求资源$R_j$，用有向边$P_i -> R_j$表示
- 边：资源分配
  - 资源$R_j$分配给进程$P_i$，用有向边$R_j -> P_i$表示
- 资源分配图示例
  #figure(
    image("pic/2025-12-10-01-57-35.png", width: 80%),
    numbering: none,
  )
  - 是否有死锁？
*形成死锁的必要条件*
- 互斥
  - 任何时刻只能有一个进/线程使用一个资源实例
  - 持有并等待
- 进/线程保持至少一个资源，并正在等待获取其他进程持有的资源
  - 非抢占
  - 资源只能在进程使用后自愿释放
- 循环等待
  - 存在等待进程集合${P_0, P_1, ..., P_N}$
  - 进程间形成相互等待资源的环


=== 死锁处理办法

*死锁处理办法*
- 死锁预防(Deadlock Prevention)
  - 确保系统永远不会进入死锁状态
- 死锁避免(Deadlock Avoidance)
  - 在使用前进行判断，只允许不会出现死锁的进程请求资源
- 死锁检测和恢复(Deadlock Detection & Recovery)
  - 在检测到运行系统进入死锁状态后，进行恢复
- 由应用进程处理死锁
  - 通常操作系统忽略死锁
    - 大多数操作系统（包括UNIX）的做法

==== 死锁预防

*死锁预防*
- 预防采用某种策略限制并发进程对资源的请求，或破坏死锁必要条件。
- 破坏“互斥”
  - 把互斥的共享资源封装成可同时访问，例如用SPOOLing技术将打印机改造为共享设备；
  - 缺点：但是很多时候都无法破坏互斥条件。
- 破坏“持有并等待“
  - 只在能够同时获得所有需要资源时，才执行分配操作
  - 缺点：资源利用率低
- 破坏“非抢占”
  - 如进程请求不能立即分配的资源，则释放已占有资源
  - 申请的资源被其他进程占用时，由OS协助剥夺
  - 缺点：反复地申请和释放资源会增加系统开销，降低系统吞吐量。
- 破坏“循环等待“
  - 对资源排序，要求进程按顺序请求资源
  - 缺点：必须按规定次序申请资源，用户编程麻烦
  - 缺点：难以支持资源变化（例如新资源）

==== 死锁避免

*死锁避免*
- 利用额外的先验信息，在分配资源时判断是否会出现死锁，只在不会死锁时分配资源
- 要求进程声明需要资源的最大数目
- 限定提供与分配的资源数量，确保满足进程的最大需求
- 动态检查的资源分配状态，确保不会出现环形等待

*系统安全状态*
- 资源分配中，系统处于安全状态
- 针对所有已占用进程，存在安全执行序列${P_1,P_2, ..., P_N}$
- $P_i$要求的资源 $<=$ 当前可用资源 $+$ 所有$P_j$ 持有资源，其中$j<i$
- 如$P_i$的资源请求不能立即分配，则$P_i$等待所有$P_j (j<i)$完成
- $P_i$完成后，$P_(i+1)$可得到所需资源，执行完并释放所分配的资源
- 最终整个序列的所有$P_i$都能获得所需资源

*安全状态与死锁的关系*
- 系统处于安全状态，一定没有死锁
- 系统处于不安全状态，可能出现死锁
  - 避免死锁就是确保系统不会进入不安全状态

*银行家算法（Banker's Algorithm）*
- 银行家算法是一个避免死锁产生的算法。以银行借贷分配策略为基础，判断并保证系统处于安全状态
- 客户在第一次申请贷款时，声明所需最大资金量，在满足所有贷款要求并完成项目时，及时归还
- 在客户贷款数量不超过银行拥有的最大值时，银行家尽量满足客户需要
  - 银行家 ↔ 操作系统；资金 ↔ 资源；客户 ↔ 线/进程

*银行家算法的算法思路*
+ 对于一个线程T的请求，判断请求的资源是否超过最大可用资源
  - 如果超过，不分配，T阻塞等待
  - 如果不超过，继续2
+ 如果分配给该请求资源，判断是否安全
  - 安全则分配给T资源；否则不分配，T阻塞等待
+ 如何判断是否安全？
  - 判断是否每个线程都可以安全完成
    - 如果每个都可以完成则安全；否则不安全

*银行家算法的数据结构*
#figure(
  image("pic/2025-12-10-02-15-20.png", width: 80%),
  numbering: none,
)
- n = 线程数
- m = 资源种类数
- Max[n][m]（最大需求矩阵）
  - 线程 Ti 最多可能需要 Rj 的多少个实例。
- Allocation[n][m]（已分配矩阵）
  - Ti 当前已获得的资源实例数。
- Need[n][m]（剩余需求矩阵）
  - Ti 未来还需要多少资源：Max - Allocation
- Available[m]（可用资源向量）
  - 系统中每种资源类型当前可用的实例数。
*安全状态的判断*Safety Algorithm
#figure(
  image("pic/2025-12-10-02-15-35.png", width: 80%),
  numbering: none,
)
+ 初始化
  ```
  Work = Available
  Finish[i] = false (所有进程都未完成)
  ```
+ 寻找一个满足条件的线程 Ti
  ```
  Finish[i] = false
  Need[i] ≤ Work （能立即满足 Ti 的需求）
  ```
  若找不到，跳到 Step 4
+ 模拟 Ti 运行完
  ```
  Work = Work + Allocation[i]
  Finish[i] = true
  回到 Step 2
  ```
+ 检查是否所有 Finish[i] = true
  - 是 → 安全
  - 否 → 不安全
*银行家算法的完整描述*
#figure(
  image("pic/2025-12-10-02-15-50.png", width: 80%),
  numbering: none,
)
- 检查是否超过最大需求
  ```
  If Request > Need[i] → Error（非法请求）
  ```
- 检查资源是否够用
  ```
  If Request > Available → Ti 必须等待
  ```
- 试探性分配（Tentative Allocation）
  ```
  Available  = Available - Request
  Allocation = Allocation + Request
  Need       = Need - Request
  ```
- 调用安全性算法
  - 如果安全 → 允许分配
  - 如果不安全 → 撤销试探分配，Ti 必须等待
*银行家算法示例1*
#grid(columns: (1fr, 1fr))[
  #figure(
    image("pic/2025-12-10-02-16-39.png", width: 80%),
    numbering: none,
  )
][
  #figure(
    image("pic/2025-12-10-02-16-52.png", width: 80%),
    numbering: none,
  )
][
  #figure(
    image("pic/2025-12-10-02-17-00.png", width: 80%),
    numbering: none,
  )
][
  #figure(
    image("pic/2025-12-10-02-17-10.png", width: 80%),
    numbering: none,
  )
]
#newpara()
*银行家算法示例2*
#grid(columns: (1fr, 1fr))[
  #figure(
    image("pic/2025-12-10-02-17-36.png", width: 80%),
    numbering: none,
  )
][
  #figure(
    image("pic/2025-12-10-02-17-44.png", width: 80%),
    numbering: none,
  )
]

==== 死锁检测

*死锁检测*
- 允许系统进入死锁状态
- 维护系统的资源分配图
- 定期调用死锁检测算法来搜索图中是否存在死锁
- 出现死锁时，用死锁恢复机制进行恢复
  #figure(
    image("pic/2025-12-10-02-18-38.png", width: 80%),
    numbering: none,
  )
*死锁检测算法数据结构*
- Available:长度为m的向量：每种类型可用资源的数量
- Allocation:一个n×m矩阵：当前分配给各个进程每种类型资源的数量
  - 进程$P_i$拥有资源$R_j$的`Allocation[i][j]`个实例
*死锁检测算法的完整描述*
#figure(
  image("pic/2025-12-10-02-19-56.png", width: 80%),
  numbering: none,
)
+ 初始化
  ```
  Work = Available  // 当前可用资源
  Finish[i] =
      true  如果 Allocation[i] == 0     // 该线程没有占资源，不会导致死锁
      false 如果 Allocation[i] > 0      // 占资源但未完成
  ```
+ 寻找可完成的线程 Ti
  ```
  Finish[i] == false（线程还没完成）
  Request[i] <= Work（它尚需的资源 <= 当前可用资源 Work）
  ```
  - 如果找到满足的 Ti → 进入 Step 3
  - 如果找不到 → 进入 Step 4
+ 模拟该线程完成
  ```
  Work = Work + Allocation[i]   // 释放该线程占有的资源
  Finish[i] = true
  ```
  然后 回到 Step 2 继续找下一个线程
+ 检测死锁
  - 如果存在某个 `Finish[i] == false`，
  - 则系统处于 死锁状态，这些线程无法完成
*死锁检测示例1*
#figure(
  image("pic/2025-12-10-02-20-15.png", width: 80%),
  numbering: none,
)
- 序列$<P_0,P_2,P_1,P_3,P_4>$对于所有的i，都可满足`Finish[i] = true`
*死锁检测示例2*
#figure(
  image("pic/2025-12-10-02-21-07.png", width: 80%),
  numbering: none,
)
- 可通过回收线程$T_0$占用的资源，但资源不足以完成其他线程请求
- 线程$T_1, T_2, T_3, T_4$形成死锁

*使用死锁检测算法*
- 死锁检测的时间和周期选择依据
  - 死锁多久可能会发生
  - 多少进/线程需要被回滚
- 资源图可能有多个循环
  - 难于分辨“造成”死锁的关键进/线程

==== 死锁恢复

*进程终止*
- 终止所有的死锁进程
- 一次只终止一个进程直到死锁消除
- 终止进程的顺序的参考因素：
  - 进程的优先级
  - 进程已运行时间以及还需运行时间
  - 进程已占用资源
  - 进程完成需要的资源
  - 终止进程数目
  - 进程是交互还是批处理

*资源抢占*
- 选择被抢占进程
  - 参考因素：最小成本目标
- 进程回退
  - 返回到一些安全状态, 重启进程到安全状态
- 可能出现饥饿
  - 同一进程可能一直被选作被抢占者
