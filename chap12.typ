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

=== 管程实现方式
=== 条件变量的实现
=== 生产者-消费者问题的管程实现
