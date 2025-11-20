#import "@preview/scripst:1.1.1": *

= 文件系统

== 文件和文件系统

#note(subname: [问题])[
  - 作为存储介质，内存与硬盘有什么区别？
    #three-line-table[
      | 对比项 | 内存（RAM）           | 硬盘（HDD/SSD）           |
      | --- | ----------------- | --------------------- |
      | 速度  | 极快（纳秒级）           | 较慢（毫秒级 HDD / 微秒级 SSD） |
      | 持久性 | *断电即失*（易失性）     | *断电也保存*（非易失性）       |
      | 作用  | CPU直接访问，运行程序、数据缓存 | 长期存储文件和系统数据           |
      | 成本  | 单位容量更贵            | 更便宜                   |
      | 容量  | 相对较小              | 大容量                   |
    ]
  - 你了解的文件是什么样的？
    - 通俗地说：文件 = 一段持久保存的数据 + 名字
    - 在操作系统视角，文件具有这些特性
      - 存储在磁盘等长期介质上
      - 有名字、有路径（用来访问）
      - 有长度、权限、时间戳等属性
      - 被视为一个字节流（对应用程序透明）
      - 是操作系统文件系统管理的对象
    - 常见文件类型
      #three-line-table[
        | 类别   | 示例             | 特点         |
        | ---- | -------------- | ---------- |
        | 普通文件 | .txt .jpg .exe | 数据或程序      |
        | 目录   | /home/xx       | 存储文件名和路径关系 |
        | 特殊文件 | /dev/sda       | 设备抽象       |
      ]
  - 持续保存数据如何组织？
    - 为了把数据稳妥地放在磁盘上、还找得到，操作系统做了组织规划：
      - 分配磁盘空间（文件存哪里）
      - 索引定位（如何快速找到）
      - 目录结构（文件怎么组织）
      - 访问权限（谁能操作）
      - 元数据管理（大小时间属性等）
      - 保证可靠性（断电崩溃不丢文件）
    - 典型数据组织方式
      #three-line-table[
        | 组织方式          | 思路        | 说明         |
        | ------------- | --------- | ---------- |
        | 线性连续存储        | 连续磁盘块     | 读写快但容易碎片化  |
        | 链式存储          | 每块指向下一块   | 查找可能慢      |
        | 索引存储（如 inode） | 独立索引指向数据块 | 现代文件系统主流方式 |
      ]
      实际文件系统常用 inode + 数据块，比如 EXT4、XFS、Unix FS
]

=== 文件

==== 文件的概念

*什么是文件系统？*
- 文件系统是存储设备上组织文件的*方法和数据结构*
  #figure(
    image("pic/2025-11-05-22-43-48.png", width: 80%),
    numbering: none,
  )
- 文件系统是操作系统中负责文件命名、存储和检索的*子系统*
  #figure(
    image("pic/2025-11-05-22-46-17.png", width: 80%),
    numbering: none,
  )

*什么是文件？*
- 文件是具有符号名，由字节序列构成的*数据项集合*
  - 文件是文件系统的基本*数据单位*
- *文件名*是文件的标识符号
- *文件头*：文件系统元数据中的文件信息
  - 文件属性：名称、类型、位置、创建时间、…
  - 文件存储位置和顺序
  #three-line-table[
    | 项           | 解释                         |
    | ----------- | -------------------------- |
    | 文件本质        | 字节序列（OS不关心内容格式）            |
    | 文件名         | 标识符（给人看的，不一定对应物理位置）        |
    | 文件头（inode等） | 文件元数据：记录大小、位置、权限等          |
    | 文件属性        | 名称、类型、长度、位置、创建/访问/修改时间、权限… |
  ]

*一切都是文件*
- UNIX类操作系统的设计哲学：*一切皆文件*
  - 普通文件，目录文件
  - 字符设备文件（如键盘，鼠标...）
  - 块设备文件（如硬盘，光驱...）
  - 网络文件（socket ...）等等
  #three-line-table[
    | 类型      | 示例                |
    | ------- | ----------------- |
    | 普通文件    | \*.txt, \*.c, \*.bin |
    | 目录文件    | `/home/user/`     |
    | 字符设备文件  | 键盘、鼠标 `/dev/tty`  |
    | 块设备文件   | 磁盘 `/dev/sda`     |
    | 网络文件    | socket            |
    | 管道、FIFO | 进程间通信             |
  ]
- 所有一切均抽象成文件，提供了*统一的接口*，方便应用程序调用
  - `read() / write() / open() / close()`

*文件视图*
- *用户的文件视图*
  - 持久存储的数据结构
  - 系统调用接口：*字节序列*的集合(UNIX)
- *操作系统的文件视图*
  - *数据块*的集合
  - 数据块是逻辑存储单元，而*扇区*是物理存储单元
*文件中数据的内部结构*
- 与应用相关
  - 无结构：文本文件
  - 简单结构：CSV、JSON等格式化文件
  - 复杂结构：Word文件、ELF可执行文件

==== 文件操作

*文件的基本操作*
- 进程*读文件*
  - 获取文件所在的数据块
  - 返回数据块内对应部分
- 进程*写文件*
  - 获取数据块
  - 修改数据块中对应部分
  - 写回数据块
  #figure(
    image("pic/2025-11-05-22-59-33.png", width: 80%),
    numbering: none,
  )
  - CPU 并不会直接对磁盘读写，磁盘→内存缓冲区→用户进程 是标准路径
  - 即使程序只写 1 byte，文件系统一般也要操作 4KB 的块；所以 `getc()/putc()` 虽看起来是字节操作，本质是块级操作 + 缓冲优化

*文件的基本操作单位*
- 文件系统中的基本操作单位是*数据块*
  - 例如，`getc()`和`putc()`即使每次只访问1字节的数据，也需要缓存目标数据4096字节
  #three-line-table[
    | 名称        | 含义         | 示例          |
    | --------- | ---------- | ----------- |
    | 扇区 Sector | 磁盘物理最小单位   | 512B or 4KB |
    | 块 Block   | 文件系统逻辑最小单位 | 通常 4KB      |
    | 字节 Byte   | 应用层最小单位    | 1B          |
  ]
  内核通过页面缓存 Page Cache来减少磁盘访问

*文件的访问模式*
- 顺序访问: 按字节依次读取
  - 把一维数据映射到文件中
- 随机访问: 从任意位置读写
  - 把一个复杂结构(矩阵)映射到文件中
- 索引访问: 依据数据特征索引
  - 数据库访问是一种基于索引的访问

*文件访问控制*
- 多用户操作系统中的*文件共享*是很必要的
- 访问控制
  - 用户对文件的访问权限
  - 读、写、执行、删除
- 文件访问控制列表(ACL-Access Control List)
  - `<文件实体, 权限>`更精细，现代系统如 NTFS 支持
- UNIX模式
  - `<用户|组|所有人, 读|写|可执行>`
  - 用户标识ID
  - 组标识ID

*多进程如何访问共享文件？*
- 文件是一类共享资源
  - 需要互斥访问
  - 采用类似的同步互斥技术
    - 读写锁
  #three-line-table[
    | 类型         | 解释          |
    | ---------- | ----------- |
    | 互斥锁        | 防止并发修改      |
    | 读写锁 RWLock | 多读单写        |
    | 文件锁 flock  | POSIX 文件锁接口 |
  ]

==== 文件描述符

*应用程序如何访问文件？*
- 应用访问文件数据前必须先“打开”文件，获得*文件描述符*
- 再进一步通过文件描述符（File Descriptor，fd）读写文件
  ```
  fd = open(name, flag);
  read(fd, …);
  close(fd);
  ```

*文件描述符* 当应用程序请求内核打开/新建一个文件时，内核返回一个文件描述符用于*对应这个打开/新建的文件*。
- 形式上，文件描述符是一个*非负整数*
- 实际上，文件描述符是一个*索引值*，指向内核为每一个进程所维护的该进程打开文件的记录表
  #figure(
    image("pic/2025-11-05-23-09-53.png", width: 80%),
    numbering: none,
  )

*打开文件表*
- 内核*跟踪*进程打开的所有文件
  - 操作系统为*每个进程*维护一个打开的文件描述符表
  - 一个*系统级*的打开文件表
  - *i-node*表指中向具体的文件内容
  #three-line-table[
    | 层级          | 内容             | 说明            |
    | ----------- | -------------- | ------------- |
    | *进程打开文件表* | 文件描述符 & 文件指针   | 每个进程自己维护，fd索引 |
    | *系统打开文件表* | 文件状态、访问模式、打开计数 | 所有进程共享        |
    | *inode 表* | 文件元数据与磁盘地址     | 指向真实文件数据块     |
  ]
- 内核在*打开文件表*中*维护打开文件状态和信息*
  - 文件指针
    - 最近一次读写位置
    - 每个进程分别维护自己的打开文件指针
  - 文件打开计数
    - 当前打开文件的次数
    - 最后一个进程关闭文件时，将其从打开文件表中移除
  - 文件的磁盘位置
    - 缓存数据访问信息
  - 访问权限
    - 每个进程的文件访问模式信息
  #three-line-table[
    | 信息            | 存储位置  | 作用             |
    | ------------- | ----- | -------------- |
    | 文件指针 (offset) | 进程级   | 记录读写位置         |
    | 访问模式 (R/W/X)  | 系统级   | 管权限            |
    | 打开计数          | 系统级   | 引用计数，最后一个关闭才释放 |
    | 缓存/磁盘位置       | inode | 文件数据在哪         |
  ]
*默认文件描述符*
- UNIX 系统启动时自动打开三个文件：
  #three-line-table[
    | fd | 名称     | 含义       |
    | -- | ------ | -------- |
    | 0  | stdin  | 标准输入（键盘） |
    | 1  | stdout | 标准输出（屏幕） |
    | 2  | stderr | 错误输出（屏幕） |
  ]

=== 文件系统和文件组织

==== 文件系统的功能

*文件系统类型*
- #three-line-table[
    | 类别         | 示例                                      | 特点               |
    | ---------- | --------------------------------------- | ---------------- |
    | 磁盘文件系统     | FAT32, NTFS, ext2/ext3/ext4, ISO9660    | 本地磁盘/光盘文件存储      |
    | 网络/分布式文件系统 | NFS, SMB, AFS, GFS, Ceph                | 多机器共享文件          |
    | 特殊文件系统     | procfs (`/proc`), sysfs (`/sys`), tmpfs | 不存真实文件，内核接口或内存文件 |
  ]
  - `procfs` 就像内核数据的“假文件书架”
  - `sysfs` 是系统设备和驱动的窗口
  - `tmpfs` 放在内存里，速度快
*虚拟文件系统 (VFS)*
- VFS 是一个抽象层，用来统一不同文件系统接口
- 它屏蔽底层差异，使 Linux 能同时访问 ext4、NFS、FAT、devfs 等
  #figure(
    image("pic/2025-11-05-23-17-53.png", width: 80%),
    numbering: none,
  )

*文件系统功能*
- 文件系统是操作系统中*管理持久性数据的子系统*，提供数据文件*命名、存储和检索*功能
  - 组织、检索、读写访问数据
  - 大多数计算机系统都有文件系统
- 分配文件磁盘空间
  - 管理文件块（位置和顺序）
  - 管理空闲空间(位置)
  - 分配算法 (策略)
- 管理文件集合
  - 组织：组织文件的控制结构和数据结构
  - 命名：给文件取名字
  - 定位：通过名字找到文件文件及其内容
- 数据可靠和安全
  - 安全：多层次保护数据安全
  - 可靠
    - 持久保存文件
    - 避免系统崩溃、数据丢失等

*文件系统组织结构*
- 分层/树状目录结构
  - 文件以目录的方式组织起来
  - *目录*是一类特殊的文件
  - 目录的内容是文件索引表`<文件名, 指向文件的指针>`
  ```
  /
  ├── bin
  ├── home
  │   └── user
  └── etc
      ├── config.cfg
      └── hosts
  ```

==== 目录

*目录操作*
- 应用程序通过系统调用对目录进行操作
  - 搜索文件
  - 创建文件
  - 删除文件
  - 列目录
  - 重命名文件
- 目录就是*文件名 → 文件位置（inode）*的映射表，本质上是个「索引簿」
  #three-line-table[
    | 操作   | 示例                   |
    | ---- | -------------------- |
    | 搜索文件 | `open("a.txt")` 会查目录 |
    | 创建文件 | `creat()`            |
    | 删除文件 | `unlink()`           |
    | 列目录  | `ls`                 |
    | 重命名  | `mv old new`         |
  ]
*目录实现方式*
- 文件名的*线性列表*，包涵了指向数据块的指针
  - 编程简单、执行耗时
- 哈希表 – 哈希数据结构的线性表
  - 减少目录搜索时间
  - 可能有冲突 - 两个文件名的哈希值相同
- ext2/3 传统用线性扫描，ext4 和 XFS 支持哈希索引提升性能
  ```
  目录文件内容（简化）
  [name1 → inode#12]
  [name2 → inode#8]
  [name3 → inode#109]
  ```

*路径解析（遍历目录）*
- 解析 `./fs/inode.rs`
  - 读取 `.` 当前目录
  - 找到 `fs` 项 → 得到 `fs` 的 inode
  - 读取 `fs` 目录内容
  - 找到 `inode.rs` → 得到目标文件 `inode`
  - 进入 `inode` → 获取数据
- 所以访问文件不是跳一次，是逐级查目录。
  - Linux 内核有目录项缓存（dentry cache）避免重复解析

*文件别名（多个名字指同一文件）*
- 多个文件名关联同一个文件
- 硬链接(hard link)
  - 多个文件项指向一个文件
- 软链接(soft link, symbolic link)
  - 新建文件，以存储文件名称的方式来指向其他文件
- inode：管理文件数据的结构
  #three-line-table[
    | 类型             | 指向          | 是否跨文件系统 | 链到目录 | 删除原文件后的结果   |
    | -------------- | ----------- | ------- | ---- | ----------- |
    | 硬链接 hard link  | 指向同一个 inode | ❌       | ❌    | 文件仍存在       |
    | 符号链接 soft link | 指向路径字符串     | ✅       | ✅    | 链断掉，变“悬空链接” |
  ]
  ```
  ln a.txt b.txt      # 硬链接
  ln -s a.txt link    # 软链接
  ```
  #figure(
    image("pic/2025-11-05-23-25-36.png", width: 80%),
    numbering: none,
  )
- 硬链接是对一个文件的引用，而软链接则是一个指向文件路径的指针
- *硬链接不能跨文件系统*，也不能链接到目录
  - 避免目录循环，所以不能链接到目录
- *软链接可以跨文件系统*，也可以链接到目录
- 如何避免目录中没有形成循环？
  - 只允许对文件的链接，不允许对子目录的链接
  - 增加链接时，用循环检测算法确定是否合理
  - 限制遍历文件目录的路径数量

*文件系统挂载*
- 文件系统需要先挂载才能被访问
  - 挂载(mount)是将一个文件系统连接到现有目录树的过程
  ```
  mount /dev/sdb1 /mnt/data
  ```

== 文件系统的设计与实现

#note(subname: [问题])[
  - 如何高效地管理和访问磁盘上存储的文件？
    - 文件系统要解决：
      #three-line-table[
        | 目标   | 说明              |
        | ---- | --------------- |
        | 定位文件 | 目录结构、inode、路径解析 |
        | 快速访问 | 数据结构、缓存、预读、写回   |
        | 节省空间 | 空闲空间管理、分配策略     |
        | 可靠性  | 崩溃恢复、写日志、元数据保护  |
        | 安全性  | 权限、ACL、隔离       |
        | 一致性  | 保证元数据和文件系统结构不乱  |
      ]
    - 实现方式包括：
      - 目录管理（哈希树、B+树、dentry cache）
      - 块管理（位图、链式、索引）
      - 磁盘数据布局（inode table、superblock）
      - 缓存机制（page cache、buffer cache）
      - 写策略（异步写、写回、日志 journaling）
      - VFS 抽象层
  - 内存管理方法可以借用来管理文件吗？
    - 能借，但不能直接照搬
      #three-line-table[
        | 内存概念          | 文件概念                     | 借鉴点           |
        | ------------- | ------------------------ | ------------- |
        | 页 Page        | 块 Block                  | 固定大小管理，提高定位效率 |
        | 页表 Page Table | inode 索引                 | 多级索引结构        |
        | TLB           | dentry cache/inode cache | 加缓存加速查找       |
        | 段 Segment     | 文件                       | 分模块组织、权限控制    |
      ]
]

=== 概述

*文件系统的分层结构*
#figure(
  image("pic/2025-11-05-23-33-20.png", width: 80%),
  numbering: none,
)
- VFS 是“翻译官”，上接统一接口，下接各种真实文件系统
*文件系统在计算机系统中的分层结构*
#figure(
  image("pic/2025-11-05-23-33-52.png", width: 70%),
  numbering: none,
)
*文件系统的用户视图与内核视图*
#figure(
  image("pic/2025-11-05-23-34-08.png", width: 80%),
  numbering: none,
)
#figure(
  image("pic/2025-11-05-23-34-34.png", width: 80%),
  numbering: none,
)
- inode 结构包含：
  - 文件元信息（权限、时间戳、大小）
  - 数据块指针（直接/间接）
- 数据真正放在数据块区

*虚拟文件系统* VFS, Virtual File System

- 一组所有文件系统都支持的数据结构和标准接口
- 磁盘的文件系统：直接把数据存储在磁盘中
  - 比如 Ext 2/3/4、XFS
- 内存的文件系统：内存辅助数据结构
  - 例如目录项
  #three-line-table[
    | 功能       | 解释                                |
    | -------- | --------------------------------- |
    | 统一接口     | 对用户永远是 open/read/write            |
    | 统一抽象     | inode、dentry、file 对象              |
    | 文件系统插件框架 | ext4, FAT, NFS 像插件一样挂进去           |
    | 高速缓存     | inode cache + dentry cache 提升查找速度 |
  ]
- 虚拟文件系统的功能
  - 目的：对所有不同文件系统的抽象
  - 功能
    - 提供相同的文件和文件系统*接口*
    - 管理所有文件和文件系统关联的*数据结构*
    - 高效*查询*例程：遍历文件系统
    - 与特定文件系统模块的交互

=== 文件系统的基本数据结构

*文件系统的存储视图*
- 文件卷控制块 (`superblock`)
- 文件控制块(`inode/vnode`)
- 目录项 (`dir_entry`)
- 数据块（`data block`）
  #figure(
    image("pic/2025-11-05-23-38-21.png", width: 80%),
    numbering: none,
  )

#three-line-table[
  | 名称               | 作用              | 类比          |
  | ---------------- | --------------- | ----------- |
  | Superblock（卷控制块） | 整个文件系统的元信息      | 图书馆“总目录”    |
  | Inode（文件控制块）     | 具体文件的元信息        | 书籍的“目录卡”    |
  | Dir entry（目录项）   | 文件名 → inode 的映射 | 架位标签“书名→卡号” |
  | Data block（数据块）  | 真正的数据内容         | 书架上的书页      |
]
```
vol → root dir → 子目录 → 文件 → 数据块
```
#figure(
  image("pic/2025-11-18-17-03-21.png", width: 80%),
  numbering: none,
)
ext 系列的典型布局：
```
Superblock
Inode Bitmap   # 哪些 inode 被占用
Data Bitmap    # 哪些 block 被占用
Inode Table    # 文件元信息 index node
Data Blocks    # 真实文件数据
```
目录项不会单独有表，它存放在 Data Block 里（目录也是文件）

#figure(
  image("pic/2025-11-18-17-14-25.png", width: 80%),
  numbering: none,
)

*文件卷控制块`superblock`*
- 每个文件系统一个文件卷控制块
  - 块大小、空余块数量等
  - block与inode 的总量，未使用与已使用的数量
  - filesystem的挂载时间、最近一次写入时间、最近一次检验磁盘(fsck) 时间
- ```rust
  pub struct Superblock {
    magic: u32,               // 文件系统类型标识
    pub total_blocks: u32,    // 总块数
    pub inode_bitmap_blocks: u32, // inode 位图占用块数
    pub inode area_blocks: u32,   // inode 区块数
    pub data_bitmap_blocks: u32,  // 数据位图占用块数
    pub data_area_blocks: u32,    // 数据区块数
  }
  ```
*文件控制块`inode`*
- 每个文件有一个文件控制块 inode (`inode`/`vnode`)
  - 大小、数据块位置（指向一个或多个datablock）
  - 访问模式(read/write/excute)
  - 拥有者与群组(owner/group)
  - 时间信息：建立或状态改变的时间、最近读取时间/修改的时间
  - *文件名存放在目录的datablock*
  - 文件的字节数
  - 文件拥有者的 User ID
  - 文件的 Group ID
  - 链接数：有多少文件名指向这个 inode
  - 文件数据 block 的位置（直接、间接）
- ```rust
  pub struct DiskInode {
    pub size: u32,               // 文件大小（字节）
    pub direct: [u32; INODE_DIRECT_COUNT], // 直接数据块指针
    pub indirect1: u32,         // 一级间接块指针
    pub indirect2: u32,         // 二级间接块指针
    type: DiskInodeType,        // 文件类型
  }
  ```
*bitmap块 `bitmap inode/dnode`*
- inode使用或者未使用标志位
- dnode使用或者未使用标志位
- 用于空间分配
*数据块dnode(`data node`)*
- 目录和文件的数据块
  - 放置目录和文件内容
  - 格式化时确定data block的固定大小
  - 每个block都有编号，以方便inode记录
  - inode一般为128B
  - data block一般为4KB
- 目录的数据块存：
  #three-line-table[
    | Inode 号 | 类型   | 文件名       |
    | ------- | ---- | --------- |
    | 2       | 目录   | .         |
    | 1       | 目录   | ..        |
    | 18      | 文件   | hello.txt |
    | 19      | 插图文件 | a.png     |
  ]
  这其实是一张表文件 inside 文件
  #figure(
    image("pic/2025-11-18-17-38-31.png", width: 80%),
    numbering: none,
  )
*目录项(`dir_entry`)*
- 一个目录（文件夹）包含多个目录项
  - 每个目录项一个(目录和文件)
  - 将目录项数据结构及树型布局编码成树型数据结构
  - 指向文件控制块、父目录、子目录等
- OS会缓存一个读过目录项来提升效率
- ```rust
  pub struct DirEntry {
    name: [u8, NAME_LENGTH_LIMIT + 1], // 文件名
    inode_number: u32,               // 指向的 inode 号
  }
  ```

=== 文件缓存

*多种磁盘缓存位置*
#figure(
  image("pic/2025-11-18-17-44-51.png", width: 80%),
  numbering: none,
)
```
磁盘
  ↓
磁盘控制器：扇区缓存（硬件级别）
  ↓
内存：
   - 数据块缓存 buffer cache
   - 页缓存 page cache
   - 打开文件表
   - 内存虚拟磁盘（RAMFS、tmpfs）
```
#newpara()
*数据块缓存（Block Cache / Buffer Cache）*
- 数据块*按需读入*内存
  - 提供`read()`操作
  - 预读: 预先读取后面的数据块
- 数据块使用后被*缓存*
  - 假设数据将会再次用到
  - 写操作可能被缓存和延迟写入
  #figure(
    image("pic/2025-11-18-17-54-18.png", width: 80%),
    numbering: none,
  )
这是文件系统使用的“传统缓存方式”。
- 作用
  - 按需把文件的数据块读到内存（read）
  - 可能预读（read-ahead）
  - 使用后会暂存，以便下次快速访问
  - 写操作可能延迟写入（write-back）
- 方式如下：
  - 按需读取（On-demand read）
    - 当进程调用 `read(fd, ...)`：
    - 内核检查缓存里是否有对应的数据块
    - 如果没有，就从磁盘读入内存
    - 返回给用户
  - 预读机制（Readahead）
    - 如果用户读取第 1 块，内核很可能自动把第 2 块、3 块也读入。
    - 因为大多数程序都以顺序访问为主。
  - 写操作延迟写（Delayed write）
    - `write()` 的数据通常不立刻写到磁盘，而是写到缓存里，并标记为 dirty（脏块），稍后再统一写回。
    - 好处：
      - 减少磁盘写次数（合并一堆写成一次）
      - 程序运行更快
    - 代价：
      - 系统崩溃可能导致数据丢失，因此有 journal/log 机制加持（ext4、XFS）

*页缓存（Page Cache）*
- 页缓存: 统一缓存数据块和内存页
- 在虚拟地址空间中虚拟页面可映射到本地外存文件中
  #figure(
    image("pic/2025-11-18-17-58-27.png", width: 80%),
    numbering: none,
  )
- 文件数据块的页缓存
  - 在虚拟内存中文件数据块被映射成页
  - 文件的读/写操作被转换成对内存的访问
  - 可能导致缺页和/或设置为脏页
- 问题: 页置换算法需要协调虚拟存储和页缓存间的页面数

*文件描述符（File Descriptor）*
- 每一个被打开的文件，都需要：
  - 一个文件描述符（用户态编号）
  - 一个进程打开文件表 entry
  - 一个系统文件表 entry（跨进程共享）
  - 一个 inode
- 每个被打开的文件都有一个文件描述符作为index，指向对应文件状态信息
- 打开文件表
  - 每个进程1个进程打开文件表
  - 一个系统打开文件表
  ```
  进程打开文件表（用户级 FD）
        ↓
  系统打开文件表（open file）
        ↓
  inode（文件元数据）
        ↓
  数据块数据
  ```
  #figure(
    image("pic/2025-11-18-18-21-09.png", width: 80%),
    numbering: none,
  )

*文件锁*
- 一些文件系统提供文件锁，用于协调多进程的文件访问
  - 强制：根据锁保持情况和访问需求确定是否拒绝访问
  - 劝告：进程可以查找锁的状态来决定怎么做

=== 文件分配

*文件大小*
- 大多数文件都很小
  - 需要支持小文件
  - 数据块空间不能太大
- 一些文件非常大
  - 能支持大文件
  - 可高效读写

*文件分配*
- 分配文件数据块
- 分配方式
  - 连续分配
  - 链式分配
  - 索引分配
- 评价指标
  - 存储效率：外部碎片等
  - 读写性能：访问速度

==== 连续分配（Contiguous Allocation）

文件占用磁盘上一段连续的物理块：
#figure(
  image("pic/2025-11-18-18-31-14.png", width: 80%),
  numbering: none,
)
```
文件头：
  起始块号 + 长度（占用多少个连续块）
```
- 分配策略: 最先匹配, 最佳匹配, ...
- 优点：高效的顺序和随机读访问
- 缺点：频繁分配会带来碎片；增加文件内容开销大

==== 链式分配（Linked Allocation）

每个数据块都有指向“下一个数据块”的指针：
#figure(
  image("pic/2025-11-18-18-31-50.png", width: 80%),
  numbering: none,
)
```
块2 → 块7 → 块3 → 块9 → 块14 → ...
```
- 优点: 创建、增大、缩小很容易；几乎没有碎片
- 缺点：
  - 随机访问效率低；可靠性差；
  - 破坏一个链，后面的数据块就丢了

*显式链式（FAT）*
- 所有的链表关系放在一张表 FAT 中：
  ```
  FAT[2] = 7
  FAT[7] = 3
  FAT[3] = 9
  ...
  ```
  目录项只需要知道开始块号。
  #figure(
    image("pic/2025-11-18-18-33-31.png", width: 80%),
    numbering: none,
  )

*隐式链式（链在每个数据块里）*
- 每个块保存了指向下一块的指针
  ```
  数据 | next-block-number
  ```

==== 索引分配（Indexed Allocation）

- 文件头包含了*索引数据块指针*
- 索引数据块中的索引是文件数据块的指针
#figure(
  image("pic/2025-11-18-18-34-25.png", width: 80%),
  numbering: none,
)
```
索引块：
  [5, 7, 9, 14, ...]
```
- 优点
  - 创建、增大、缩小很容易；几乎没有碎片；支持直接访问
- 缺点
  - 当文件很小时，存储索引的开销相对大

索引分配
- 链式索引块(IB+IB+…)
  #figure(
    image("pic/2025-11-18-18-35-23.png", width: 80%),
    numbering: none,
  )
- 多级索引块(IB\*IB\*…)
  #figure(
    image("pic/2025-11-18-18-35-32.png", width: 80%),
    numbering: none,
  )

#figure(
  image("pic/2025-11-18-18-35-42.png", width: 80%),
  numbering: none,
)

*多级索引（UNIX inode）*
- UNIX（ext2/3/4）文件系统采用：
  - 10 个直接块指针（存小文件）
  - 1 个一级间接块指针
  - 1 个二级间接块指针
  - 1 个三级间接块指针
#figure(
  image("pic/2025-11-18-18-36-21.png", width: 80%),
  numbering: none,
)

可以支持非常大的文件
- 例如：块大小 4KB；每个指针 4B，则一个索引块能存：
  ```
  4KB / 4B = 1024 个指针
  ```
- 一级间接块可寻址：
  - $1024$ 个数据块 = 4MB
- 二级间接块：
  - $1024 × 1024$ = 1M 个数据块 = 4GB
- 三级间接块：
  - $1024^3$ ≈ $10^9$ 块 = 4TB

#three-line-table[
  | 方式                   | 优点          | 缺点              |
  | -------------------- | ----------- | --------------- |
  | *连续分配*             | 顺序 & 随机访问最快 | 外部碎片，文件增长困难     |
  | *链式分配（隐式/显式 FAT）*  | 扩展容易，无碎片    | 随机访问很慢；可靠性差（链断） |
  | *索引分配（inode 多级索引）* | 支持随机访问，易扩展  | 索引块需要空间；多级寻址稍慢  |
]

==== 空闲空间管理（Free Space Management）

跟踪记录文件卷中未分配的数据块

*位图（bitmap）*
- ```
  111110001011011 ...
  1=已占用
  0=空闲
  ```
- 160GB磁盘 --> 40M数据块 --> 5MB位图
- 假定空闲空间在磁盘中均匀分布，
  - 找到“0”之前要扫描$n/r$
    - $n$磁盘上数据块的总数
    - $r$空闲数据块的比例
*链表*
#figure(
  image("pic/2025-11-18-18-39-57.png", width: 80%),
  numbering: none,
)
*索引*
#figure(
  image("pic/2025-11-18-18-40-03.png", width: 80%),
  numbering: none,
)

=== 文件访问过程示例

*文件系统组织示例*
#figure(
  image("pic/2025-11-18-18-41-14.png", width: 80%),
  numbering: none,
)
- inode 位图（inode bitmap）
  - 每一位对应一个 inode 是否被使用
  - 找空闲 inode 就是在找“0”位
- 数据块位图（data bitmap）
  - 每一位对应一个数据块是否被使用
  - 找空闲数据块也是找“0”
- inode 区（inodes）
  - 每个 inode 保存：
    - 文件大小
    - 文件类型（文件/目录/链接）
    - 数据块指针（direct, indirect）
    - 权限属性等
- 数据块区（data blocks）
  - 存放文件内容
  - 或目录项（文件名 + inode 号）
  - 或间接索引块
- 根目录 inode -> 目录数据块 -> 子目录 inode …
  - 文件系统层级通过目录数据块里的“文件名 → inode号”来链接。
*文件读操作过程*
#figure(
  image("pic/2025-11-18-18-42-41.png", width: 80%),
  numbering: none,
)
```
路径解析 → 找到 inode → 查看 inode 的数据块指针 → 查找缓存 →
  命中 → 直接返回
  未命中 → 读磁盘 → 放入缓存 → 返回数据
```
#newpara()
*文件写操作过程*
#figure(
  image("pic/2025-11-18-18-45-58.png", width: 80%),
  numbering: none,
)
```
路径解析 → 找到/创建 inode → 分配数据块 → 写入缓存 →
  标记脏页 → 延迟写回磁盘
```
#newpara()
*文件系统分区*
- 多数磁盘划分为一个或多个分区，每个分区有一个独立的文件系统
  #figure(
    image("pic/2025-11-18-18-46-25.png", width: 80%),
    numbering: none,
  )
磁盘被分为多个分区 (partition)
- 每个分区包含一个完整的文件系统，结构如下：
- 引导块（boot block）
  - 仅第一个分区用来装引导程序（如 GRUB）
- 超级块（superblock）
  - 整个文件系统的元数据
  - 总 inode 数
  - 总数据块数
  - 块大小
  - 空闲块统计
  - 空闲 inode 统计
  非常关键，损坏会导致文件系统不可用
- 块组描述符（Block Group Descriptor）
  - 记录每个块组的 bitmap、inode 区等偏移
- 位图（inode bitmap & data bitmap）
  - 管理空闲 inode / 数据块
- inode 列表
  - 每个 inode 是一个结构体
- 数据块区
  - 存放实际文件内容、目录内容等

== 支持崩溃一致性的文件系统

#note(subname: [问题])[
  如何减少文件系统中的数据丢失和出错机率？

  *为什么会发生文件系统损坏？*
  - 文件系统进行写操作时，必须修改多个不同的数据结构。例如写入一个新文件需要：
    - 修改数据块内容（data block）
    - 更新 inode（文件元数据：大小、时间戳、指向的数据块等）
    - 更新数据位图（标记数据块已被占用）
    - 更新 inode 位图（新 inode 被分配）
    - 更新目录项（目录文件添加新条目）
  - 这些写入顺序必须严格遵守，否则就会产生不一致（inconsistency）。

  *崩溃时可能产生的错误*
  - 设想在写文件过程中断电或 OS 崩溃，会出现以下问题：
    - 数据丢失 Data Loss
      - 例如还没把缓存中的脏页刷到磁盘 → 文件内容丢失
    - 元数据不一致 Metadata Inconsistency

  *文件系统崩溃后如何恢复？*
  - FSCK（文件系统检查）
    - 早期 UNIX/ext2 的恢复方法。
  - 日志文件系统（Journaling File System）
    - 典型：ext3/ext4，NTFS，XFS，ReiserFS
  - 写时复制（Copy-on-Write, COW）
    - 典型：Btrfs，ZFS，APFS（苹果的文件系统）
]

=== 崩溃一致性问题

==== 崩溃一致性

*文件系统的持久数据更新挑战*
- 如何在出现断电（power loss）或系统崩溃（system crash）的情况下，更新持久数据结构？
- 崩溃可能导致磁盘文件系统映像中的文件系统数据结构出现*不一致*性。如，有空间泄露、将垃圾数据返回给用户等.

*崩溃一致性问题*
- *崩溃一致性问题*（crash-consistency problem）也称一致性更新问题（consistent-update problem）
- 特定操作需要更新磁盘上的两个结构A和B。
- 磁盘一次只为一个请求提供服务，因此其中一个请求将首先到达磁盘（A或B），而另一个没写到磁盘。
- 如果在一次写入完成后系统崩溃或断电，则磁盘上的结构将处于不一致（inconsistent）的状态。

*崩溃一致性的需求*
- 目标
  - 将文件系统从一个一致状态（在文件被追加之前），原子地（atomically）*变迁*到另一个一致状态（在inode、位图和新数据块被写入磁盘之后）。
- 困难
  - 磁盘一次只提交一次写入，更新之间可能会发生崩溃或断电。

*文件更新过程示例*
- 考虑一个应用以某种方式更新磁盘结构：将单个数据块附加到原有文件。
  - 通过打开文件，调用`lseek()`将文件偏移量移动到文件末尾，然后在关闭文件之前，向文件发出单个4KB写入来完成追加。
  - lseek + write 并非原子操作。多个进程可能在 lseek 和 write 之间修改文件，导致偏移量失效。

*文件系统数据结构*
- inode位图（inode bitmap，只有8位，每个inode一个）
- 数据位图（data bitmap，也是8位，每个数据块一个）
- inode（总共8个，编号为0到7，分布在4个块上）
- 数据块（总共8个，编号为0～7）。
#figure(
  image("pic/2025-11-18-18-59-27.png", width: 80%),
  numbering: none,
)

*文件更新中的磁盘操作*
- 考虑一个应用以某种方式更新磁盘结构：将单个数据块附加到原有文件
  - 必须对磁盘执行*3次单独写入*
    - inode（I[v2]）、位图（B[v2]）和数据块（Db）
  - 发出`write()`系统调用时，这些写操作通常不会立即发生。
    - 脏的inode、位图和新数据先在*内存*（页面缓存page cache，或缓冲区缓存buffer cache）中存在一段时间。
  - 当文件系统最终决定将它们写入磁盘时（比如说5s或30s），文件系统将向磁盘发出必要的*写入请求*。

==== 崩溃场景

*文件操作中的崩溃*
- 在文件操作过程中可能会发生崩溃，从而干扰磁盘的这些更新。
- 如果写入操作中的一个或两个完成后发生崩溃，而不是全部3个，则文件系统可能处于有趣（不一致）的状态。

#figure(
  image("pic/2025-11-18-19-01-58.png", width: 80%),
  numbering: none,
)

*崩溃场景一*：只将数据块（Db）写入磁盘
- 数据在磁盘上，但没有指向它的inode，也没有表示块已分配的位图
- 好像写入从未发生过一样
- 这是空间泄露（leak），未来永远无法回收
*崩溃场景二*：只有更新的inode（I[v2]）写入了磁盘
- inode指向磁盘块5，其中Db即将写入，但Db尚未写入
- 从磁盘读取垃圾数据（磁盘块5的旧内容）
- 这是数据损坏（stale / garbage data）
*崩溃场景三*：只有更新后的位图（B[v2]）写入了磁盘
- 位图指示已分配块5，但没有指向它的inode
- 这种写入将导致空间泄露（space leak），文件系统永远不会使用块5
- 结果：空间泄露（leak）
*崩溃场景四*：inode（I[v2]）和位图（B[v2]）写入了磁盘，但没有写入数据（Db）
- inode有一个指向块5的指针，位图指示5正在使用
- 因此从文件系统的元数据的角度来看，一切看起来很正常
- 但磁盘块5中又是垃圾数据
*崩溃场景五*：写入了inode（I[v2]）和数据块（Db），但没有写入位图（B[v2]）
- inode指向了磁盘上的正确数据
- 在inode和位图（B1）的旧版本之间存在*不一致*
- 触发双重使用（double allocation），文件系统可能互相覆盖
*崩溃场景六*：写入了位图（B[v2]）和数据块（Db），但没有写入inode（I[v2]）
- inode和数据位图之间再次存在不一致
- 不知道它属于哪个文件，因为没有inode指向该块

#three-line-table[
  | 场景 | 写入情况           | 错误类型       |
  | -- | -------------- | ---------- |
  | 1  | 仅 data block   | 空间泄露       |
  | 2  | 仅 inode        | 用户读到垃圾     |
  | 3  | 仅 data bitmap  | 空间泄露       |
  | 4  | inode + bitmap | 用户读到垃圾     |
  | 5  | inode + data   | 双重分配（严重错误） |
  | 6  | bitmap + data  | 空间泄露       |
]

=== 文件系统检查程序 fsck

*崩溃解决方案*
- 文件系统检查程序 fsck
- 基于预写日志（write ahead log）的文件系统

*文件系统检查程序 fsck*
- 早期的文件系统采用了一种简单的方法来处理崩溃一致性
- 让不一致的事情发生，然后再修复它们（重启时）
- 目标：确保文件系统元数据内部一致

*超级块检查*
- 检查超级块检查是否合理，主要是进行健全性检查
  - 确保文件系统大小大于分配的块数
  - 找到超级块的*内容不合理（冲突）*，系统（或管理员）可以决定使用超级块的*备用副本*
- 注：可靠性高的文件系统，会有多处放置超级块备份的磁盘扇区
  #figure(
    image("pic/2025-11-18-19-08-49.png", width: 80%),
    numbering: none,
  )
*位图与inode间的一致性检查*
- 扫描inode、间接块、双重间接块等，以了解当前在文件系统中分配的块，生成正确版本的分配位图
- 如果位图和inode之间存在任何不一致，则通过*信任inode内的信息*来解决它
- 对所有inode执行相同类型的检查，确保所有看起来像在使用的inode，都在inode位图中有标记
inode状态检查
*inode状态检查*
- 检查每个inode是否存在损坏或其他问题
- 每个分配的inode具有有效的类型字段（即常规文件、目录、符号链接等）
- 如果inode字段存在问题，不易修复，则inode被认为是可疑的，并被fsck清除，inode位图相应地更新。
*链接计数检查*
- inode链接计数表示包含此特定文件的引用（即链接）的不同目录的数量。
- 从根目录开始扫描整个目录树，并为文件系统中的每个文件和目录构建自己的链接计数
- 如果*新计算的计数*与inode中找到的计数不匹配，则通常是修复inode中的计数
- 如果发现已分配的inode但*没有目录引用*它，则会将其移动到lost + found目录。
*重复指针检查*
- 两个不同的inode引用同一个块的情况
- 如果一个inode明显错误，可能会被清除或复制指向的块，从而为每个inode提供其自己的文件数据
- inode有很多错误可能性，比如其inode内的元数据不一致
  - inode有文件的长度记录，但其实际指向的数据块大小小于其文件长度
*坏块检查*
- 在扫描所有指针列表时，检查坏块指针。如果指针显然指向超出其有效范围的某个指针，则该指针被认为是“坏的”。
  - 地址指向大于分区大小的块
  - 从inode或间接块中删除（清除）该指针
*目录检查*
- fsck不了解用户文件的内容，但目录包含由文件系统本身创建的特定格式的信息。对每个目录的内容执行额外的完整性检查。
  - 确保“.”和“..”是前面的条目，目录条目中引用的每个inode都已分配
  - 确保整个层次结构中没有目录的引用超过一次
*文件系统检查程序 fsck 的不足*
- 对于非常大的磁盘卷，扫描整个磁盘，以查找所有已分配的块并读取整个目录树，可能需要几分钟或几小时。
- 可能丢数据！

=== 日志文件系统

崩溃一致性的问题在前面已经看到 —— 追加一个数据块需要更新：
- inode
- data bitmap
- data block
三者必须“一起出现”或“不出现”，否则就会有：
- 指针指向垃圾数据
- 位图和 inode 不一致
- 块泄露
- 文件读取时读到旧内容或损坏数据
日志（Journal）机制就是为解决这个问题而设计的。

==== 日志

*日志（或预写日志）*
- 预写日志（write-ahead logging）
- 借鉴数据库管理系统的想法
- 在文件系统中，出于历史原因，通常将预写日志称为日志（journaling）
- 第一个实现它的文件系统是Cedar（1988年）
- 许多现代文件系统都使用这个想法，包括Linux ext3和ext4、reiserfs、IBM的JFS、SGI的XFS和Windows NTFS。

*预写日志的思路*
- 更新磁盘时，在覆写结构之前，首先写下一点小注记（在磁盘上的其他地方，在一个众所周知的位置），描述你将要做的事情
- 写下这个注记就是“预写”部分，把它写入一个结构，并组织成“日志”
  - 日志是连续追加写

*预写日志的崩溃恢复*
- 通过将注记写入磁盘，可以保证在更新（覆写）正在更新的结构期间发生崩溃时，能够返回并查看你所做的注记，然后重试
- 在崩溃后准确知道要修复的内容（以及如何修复它），而不必扫描整个磁盘
- 日志功能通过在更新期间增加了一些工作量，大大减少了恢复期间所需的工作量

写操作流程：
- 写日志：我打算修改 inode（I[v2]）、位图（B[v2]）、数据（Db）
- 提交日志：告诉系统这批日志有效（TxE）
- 将真实数据写入文件系统（checkpoint）
- 回收日志空间
这样能保证：
- 崩溃后，只需查看日志，不用扫描整个磁盘
- 如果日志已提交但实际写入未完成 → 重做日志（redo）
- 如果日志未提交 → 直接丢弃（这批操作根本不算发生过）

==== 数据日志（data journaling）

*数据日志（data journaling）*
```
TxB       I[v2]       B[v2]       Db      TxE
^                                         ^
事务开始块                                 事务结束块
```
这是一个事务 (transaction)，包含：
- TxB：事务开始（Transaction Begin）
- 一组需要写入的块（inode、bitmap、data）
- TxE：事务结束（Transaction End）
- 数据日志写到磁盘上（写日志）
- 更新磁盘，覆盖相关结构（写真实数据） (checkpoint)
  - I[V2] B[v2] Db

*写入日志期间发生崩溃*
- 磁盘内部可以（1）写入TxB、I[v2]、B[v2]和TxE，然后（2）才写入Db。
- 如果磁盘在（1）和（2）之间断电，那么磁盘上会变成：
  ```
  TxB       I[v2]       B[v2]       ??      TxE
  ```
*数据日志的两步事务写入*
- 为避免该问题，文件系统分两步发出事务写入。
  - 将除TxE块之外的所有块写入日志，同时发出这些写入操作
  - 当这些写入完成时，日志将看起来像这样（假设又是文件追加的工作负载）：
  ```
  TxB       I[v2]       B[v2]       Db      ??
  ```
  当这些写入完成时，文件系统会发出TxE块的写入，从而使日志处于最终的安全状态：
  ```
  TxB       I[v2]       B[v2]       Db      TxE
  ```

*数据日志的更新流程*
- 日志写入 Journal write：
  - 将事务的内容（包括TxB、元数据和数据）写入日志，等待这些写入完成。
- 日志提交 Journal Commit：
  - 将事务提交块（包括TxE）写入日志，等待写完成，事务被认为已提交（committed）。
- 加检查点 Checkpoint
  - 将更新内容（元数据和数据）写入其最终的磁盘位置。

*数据日志恢复流程（Crash Recovery）*
- 情形1：崩溃发生在 TxE 写入之前（journal commit 前）
  - 日志状态：不完整（没有 TxE）→ 整个事务丢弃→ 原文件系统未发生任何改变 → 一致
  - 文件系统可以丢掉之前写入的log。由于磁盘具体位置的bitmap，inodes，data blocks都没变，所以可以确保文件系统一致性。
- 情形2：崩溃发生在 TxE 之后 checkpoint 之前
  - 日志状态：完整（有 TxB + TxE）→ 文件系统启动时：
    - 扫描日志
    - 发现已提交事务
    - 但真实文件系统没有 checkpoint
    - 重放（redo）日志：将 I[v2]、B[v2]、Db 再次写入真实位置
  - 文件系统在启动时候，可以扫描所有已经commited的log，然后针对每一个log记录操作进行replay，即recovery的过程中执行Checkpoint，将log的信息回写到磁盘对应的位置。这种操作也成为redo logging。
- 情形3：崩溃发生在 checkpoint 之后
  - 真实文件已经更新成功，日志是否写完无所谓。
  - 都已经成功回写到磁盘了，文件系统的bitmap、inodes、data blocks也能确保一致性。
- 在此更新序列期间的任何时间都可能发生崩溃。
  - 如果崩溃发生在将事务安全地写入日志之前
  - 如果崩溃是在事务提交到日志之后，但在检查点完成之前发生

==== 日志文件系统的性能优化

*日志超级块 journal superblock*
- 单独区域存储
- 批处理日志更新
- 循环日志回收与复用
  ```
  Journal Super Tx1 Tx2 Tx3 ... TxN
  ```
- *日志超级块的更新过程*
  - Journal write：将TxB以及对应的文件操作写入到事务中
  - Journal commit：写入TxE，并等待完成。完成后，这个事务是committed。
  - Checkpoint：将事务中的数据，分别各自回写到各自的磁盘位置中。
  - Free: 一段时间后，通过更新日志记录，超级块将交易记录标记为空闲（释放掉）

*元数据日志 Metadata Journaling*
- 什么时候应该将数据块 Db 写入磁盘？
  - 数据写入的顺序对于仅元数据的日志记录很重要
  - 如果在事务（包含 I [v2] 和 B [v2]）完成后将 Db 写入磁盘，这样有问题吗？
- *元数据日志的更新过程*
  - Data write：写入数据到磁盘的对应位置
  - Journal metadata write：将TxB以及对应的文件metadata操作写入到事务中
  - Journal commit：写入TxE，并等待完成。完成后，这个事务是committed。
  - Checkpoint metadata：将事务中的metadata的操作相关数据，分别各自回写到各自的磁盘位置中。
  - Free：释放journal区域的log记录
  - 通过强制首先写入数据，文件系统可保证指针永远不会指向垃圾数据
- Data Journaling时间线 v.s. Metadata Journaling时间线
  #figure(
    image("pic/2025-11-20-13-46-20.png", width: 80%),
    numbering: none,
  )

*不同日志模式*
- Journal Mode: 操作的metadata和file data都会写入到日志中然后提交，这是最慢的。
- Ordered Mode: 只有metadata操作会写入到日志中，但是确保数据在日志提交前写入到磁盘中，速度较快
- Writeback Mode: 只有metadata操作会写入到日志中，且不确保数据在日志提交前写入(数据可能丢失)，速度最快

== 实践：支持文件的操作系统 Filesystem OS(FOS)

https://rcore-os.cn/rCore-Tutorial-Book-v3/chapter6/index.html

=== 实验目标和步骤

==== 实验目标

*以往实验目标*
- Process OS: 增强进程管理和资源管理
- Address Space OS: APP不用考虑其运行时的起始执行地址，隔离APP访问的内存地址空间
- multiprog & time-sharing OS: 让APP有效共享CPU，提高系统总体性能和效率
- BatchOS: 让APP与OS隔离，加强系统安全，提高执行效率
- LibOS: 让APP与HW隔离，简化应用访问硬件的难度和复杂性

*实验目标*：支持数据持久保存
- 以文件形式保存持久数据，并能进行文件数据读写
- 进程成为文件资源的使用者
- 能够在应用层面发出如下系统调用请求：
  - open/read/write/close
  #figure(
    image("pic/2025-11-20-13-54-27.png", width: 80%),
    numbering: none,
  )

*Filesystem OS (FOS)*
#figure(
  image("pic/2025-11-20-13-53-29.png", width: 80%),
  numbering: none,
)

*历史：UNIX文件系统*
- 1965：描述未来的 MULTICS 操作系统
  - 指明方向的舵手
    - 文件数据看成是一个无格式的字节流
    - 第一次引入了层次文件系统的概念
  - 启发和造就了UNIX文件系统
    - 一切皆文件

*实验要求*
- 理解文件系统/文件概念
- 理解文件系统的设计与实现
- 理解应用$<->$库$<->$...$<->$设备驱动的整个文件访问过程
- 会写支持文件系统的OS

*实验中的文件类型*
- 当前
  - Regular file 常规文件
  - Directory 目录文件
- 未来
  - Link file 链接文件
  - Device 设备文件
  - Pipe 管道文件

*总体思路*

#figure(
  image("pic/2025-11-20-13-59-36.png", width: 80%),
  numbering: none,
)

==== 文件系统接口和数据结构

*文件访问流程*
#figure(
  image("pic/2025-11-20-14-00-11.png", width: 80%),
  numbering: none,
)

*文件系统访问接口*
#figure(
  image("pic/2025-11-20-14-01-17.png", width: 80%),
  numbering: none,
)

*文件系统的数据结构*
#figure(
  image("pic/2025-11-20-14-02-48.png", width: 80%),
  numbering: none,
)

#figure(
  image("pic/2025-11-20-14-05-02.png", width: 80%),
  numbering: none,
)

==== 实践步骤

*实验步骤*
- 编译：内核独立编译，单独的内核镜像
- 编译：应用程序编译后，组织形成文件系统镜像
- 构造：进程的管理与初始化，建立基于页表机制的虚存空间
- 构造：构建文件系统
- 运行：特权级切换，进程与OS相互切换
- 运行：切换地址空间，跨地址空间访问数据
- 运行：从文件系统加载应用，形成进程
- 运行：数据访问：内存--磁盘，基于文件的读写

*实践步骤*
```bash
git clone https://github.com/rcore-os/rCore-Tutorial-v3.git
cd rCore-Tutorial-v3
git checkout ch6
cd os
make run
```
```bash
[RustSBI output]
...
filetest_simple
fantastic_text
**************/
Rust user shell
>>
```
操作系统启动shell后，用户可以在shell中通过敲入应用名字来执行应用。从用户界面上，没看出文件系统的影子。在这里我们运行一下本章的测例 filetest_simple ：
```
>> filetest_simple
file_test passed!
Shell: Process 2 exited with code 0
>>
```
它会将 Hello, world! 输出到另一个文件 filea，并读取里面的内容确认输出正确。我们也可以通过命令行工具 cat_filea 来更直观的查看 filea 中的内容：
```
>> cat_filea
Hello, world!
Shell: Process 2 exited with code 0
>>
```

=== 代码结构

*软件架构*
- 文件操作：open, read, write, close
*代码结构*
- 添加easy-fs
  ```
  ├── easy-fs(新增：从内核中独立出来的一个简单的文件系统 EasyFileSystem 的实现)
  │   ├── Cargo.toml
  │   └── src
  │       ├── bitmap.rs(位图抽象)
  │       ├── block_cache.rs(块缓存层，将块设备中的部分块缓存在内存中)
  │       ├── block_dev.rs(声明块设备抽象接口 BlockDevice，需要库的使用者提供其实现)
  │       ├── efs.rs(实现整个 EasyFileSystem 的磁盘布局)
  │       ├── layout.rs(一些保存在磁盘上的数据结构的内存布局)
  │       ├── lib.rs（定义的必要信息）
  │       └── vfs.rs(提供虚拟文件系统的核心抽象，即索引节点 Inode)
  ├── easy-fs-fuse(新增：将当前 OS 上的应用可执行文件按照 easy-fs 的格式进行打包)
  │   ├── Cargo.toml
  │   └── src
  │       └── main.rs
  ├── os
  │   ├── build.rs
  │   ├── Cargo.toml(修改：新增 Qemu 和 K210 两个平台的块设备驱动依赖 crate)
  │   ├── Makefile(修改：新增文件系统的构建流程)
  │   └── src
  │       ├── config.rs(修改：新增访问块设备所需的一些 MMIO 配置)
  │       ├── console.rs
  │       ├── drivers(修改：新增 Qemu 和 K210 两个平台的块设备驱动)
  │       │   ├── block
  │       │   │   ├── mod.rs(将不同平台上的块设备全局实例化为 BLOCK_DEVICE 提供给其他模块使用)
  │       │   │   ├── sdcard.rs(K210 平台上的 microSD 块设备, Qemu不会用)
  │       │   │   └── virtio_blk.rs(Qemu 平台的 virtio-blk 块设备)
  │       │   └── mod.rs
  ```

=== 应用程序设计

==== 文件和目录

*理解文件*
- 对持久存储（persistent storage）的虚拟化和抽象
  - Tape，Disk，SSD...
  - 用户用它们保存真正关心的数据
*从应用角度理解文件*
- 文件是一个特殊的线性字节数组，每个字节都可以读取或写入。
- 每个文件都有一个给用户可理解的字符串名字
- 每个文件都有一个应用程序员可理解的某种低级名称-文件描述符 (file descriptor)
- 显示文件的线性字节内容
  ```bash
  hexedit os/src/main.rs
  ```
*从内核角度理解文件*
- 文件是存储设备上的数据，需要通过文件系统进行管理
- 管理文件的结构称为inode，inode描述了文件的各种属性和数据位置
- 显示文件的线性字节内容
  ```bash
  cd os ; stat src/main.rs
  ```
*从应用角度理解目录*
- 目录是一个特殊的文件，它的内容包含一个位于该目录下的文件名列表
- 显示目录内容
  ```bash
  cd os; ls -la
  ```
*从内核角度理解目录*
- 目录是一个特殊的文件，它的内容包含一个（用户可读文件名字，inode）对的数组
- `DirEntry`数组
  ```rust
  pub struct DirEntry {
      name: [u8; NAME_LENGTH_LIMIT + 1],
      inode_number: u32,
  }
  ```

==== 文件访问系统调用

- `open()`系统调用
  ```rust
  /// 功能：打开一个常规文件，并返回可以访问它的文件描述符。
  /// 参数：path 描述要打开的文件的文件名
  /// （简单起见，文件系统不需要支持目录，所有的文件都放在根目录 / 下），
  /// flags 描述打开文件的标志，具体含义下面给出。
  /// 返回值：如果出现了错误则返回 -1，否则返回打开常规文件的文件描述符。
  /// 可能的错误原因是：文件不存在。
  /// syscall ID：56
  fn sys_open(path: &str, flags: u32) -> isize
  ```
- `close()`系统调用
  ```rust
  /// 功能：当前进程关闭一个文件。
  /// 参数：fd 表示要关闭的文件的文件描述符。
  /// 返回值：如果成功关闭则返回 0 ，否则返回 -1 。
  /// 可能的出错原因：传入的文件描述符并不对应一个打开的文件。

  /// syscall ID：57
  fn sys_close(fd: usize) -> isize
  ```
- `read()`系统调用
  ```rust
  /// 功能：当前进程读取文件。
  /// 参数：fd 表示要读取文件的文件描述符。
  /// 返回值：如果成功读入buf，则返回 读取的字节数，否则返回 -1 。
  /// 可能的出错原因：传入的文件描述符并不对应一个打开的文件。

  /// syscall ID：63
  sys_read(fd: usize, buf: *const u8, len: usize) -> isize
  ```
- `write()`系统调用
  ```rust
  /// 功能：当前进程写入一个文件。
  /// 参数：fd 表示要写入文件的文件描述符。
  /// 返回值：如果成功把buf写入，则返回写入字节数 ，否则返回 -1 。
  /// 可能的出错原因：传入的文件描述符并不对应一个打开的文件。

  /// syscall ID：64
  fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize
  ```
- 应用程序示例
  ```rust
  // user/src/bin/filetest_simple.rs
  pub fn main() -> i32 {
      let test_str = "Hello, world!";
      let filea = "filea\0";
      // 创建文件filea，返回文件描述符fd(有符号整数)
      let fd = open(filea, OpenFlags::CREATE | OpenFlags::WRONLY);
      write(fd, test_str.as_bytes());               // 把test_str写入文件中
      close(fd);                                    // 关闭文件
      let fd = open(filea, OpenFlags::RDONLY);      // 只读方式打开文件
      let mut buffer = [0u8; 100];                  // 100字节的数组缓冲区
      let read_len = read(fd, &mut buffer) as usize;// 读取文件内容到buffer中
      close(fd);                                    // 关闭文件
  }
  ```

=== 内核程序设计

==== 核心数据结构

*核心数据结构*
- 进程管理文件
  - 目录、文件
  - inode
  - 文件描述符
  - 文件描述符表
- 文件位于根目录`ROOT_INODE`中
- 目录的内容是`DirEntry`组成的数组
- 文件/目录用`inode`表示
  ```rust
  pub struct DirEntry {
      name: [u8; NAME_LENGTH_LIMIT + 1],
      inode_number: u32,
  }
  ...
  let fd = open(filea, OpenFlags::RDONLY);
  ```
- 打开的文件在进程中`fd_table`中
- `fd_table`是`OSInode`组成的数组
  ```rust
  pub struct TaskControlBlockInner {
      pub fd_table: ... //文件描述符表

  pub struct OSInode {//进程管理的inode
      readable: bool,  writable: bool,
      inner: UPSafeCell<OSInodeInner>,//多线程并发安全
  }

  pub struct OSInodeInner {
      offset: usize, //文件读写的偏移位置
      inode: Arc<Inode>,//存储设备inode，线程安全的引用计数指针
  }
  ```
- 超级块
  - 超级块(SuperBlock)描述文件系统全局信息
    ```rust
    pub struct SuperBlock {
        magic: u32,
        pub total_blocks: u32,
        pub inode_bitmap_blocks: u32,
        pub inode_area_blocks: u32,
        pub data_bitmap_blocks: u32,
        pub data_area_blocks: u32,
    }
    ```
- inode/data位图
  - 位图(bitmap)描述文件系统全局信息
  - 在 easy-fs 布局中存在两类位图
    - 索引节点位图
    - 数据块位图
    ```rust
    pub struct Bitmap {
        start_block_id: usize,
        blocks: usize,
    }
    ```
- disk_inode
  - `read_at`和`write_at`把文件偏移量和buf长度转换为一系列的数据块编号，并进行通过`get_block_cache`数据块的读写
  - `get_block_id`方法体现了 DiskInode 最重要的数据块索引功能，它可以从索引中查到它自身用于保存文件内容的第 block_id 个数据块的块编号，这样后续才能对这个数据块进行访问
  - 磁盘索引节点(DiskInode)描述文件信息和数据
    ```rust
    pub struct DiskInode {
        pub size: u32,
        pub direct: [u32; INODE_DIRECT_COUNT],
        pub indirect1: u32,
        pub indirect2: u32,
        type_: DiskInodeType,
    }
    ```
- disk_data
  - 数据块与目录项
    ```rust
    type DataBlock = [u8; BLOCK_SZ];

    pub struct DirEntry {
        name: [u8; NAME_LENGTH_LIMIT + 1],
        inode_number: u32,
    }
    ```
- blk_cache
  - pub const BLOCK_SZ: usize = 512;
    ```rust
    pub struct BlockCache {
        cache: [u8; BLOCK_SZ], //512 字节数组
        block_id: usize, //对应的块编号
        //底层块设备的引用，可通过它进行块读写
        block_device: Arc<dyn BlockDevice>,
        modified: bool, //它有没有被修改过
    }
    ```
    `get_block_cache` ：取一个编号为 `block_id` 的块缓存

==== 文件管理机制

*文件管理机制概述*
- 文件系统初始化
- 打开与关闭文件
- 基于文件加载应用
- 读写文件

*文件系统初始化*
- 打开块设备 BLOCK_DEVICE ；
- 从块设备 BLOCK_DEVICE 上打开文件系统；
- 从文件系统中获取根目录的 inode 。
  ```rust
  lazy_static! {//宏定义静态变量
      pub static ref BLOCK_DEVICE = Arc::new(BlockDeviceImpl::new());
  ......
  lazy_static! {
      pub static ref ROOT_INODE: Arc<Inode> = {
          let efs = EasyFileSystem::open(BLOCK_DEVICE.clone());
          Arc::new(EasyFileSystem::root_inode(&efs))
  ```

*打开(创建)文件*
```rust
pub fn sys_open(path: *const u8, flags: u32) -> isize {
    //调用open_file函数获得一个OSInode结构的inode
    if let Some(inode) = open_file(path.as_str(),
                           OpenFlags::from_bits(flags).unwrap()) {
        let mut inner = task.inner_exclusive_access();
        let fd = inner.alloc_fd();  //得到一个空闲的fd_table项的idx，即fd
        inner.fd_table[fd] = Some(inode); //把inode填入fd_table[fd]中
        fd as isize  //返回fd
    ...
```
如果失败，会返回 -1
```rust
fn open_file(name: &str, flags: OpenFlags) -> Option<Arc<OSInode>> {
  ......
 ROOT_INODE.create(name) //在根目录中创建一个DireEntry<name，inode>
                .map(|inode| {//创建进程中fd_table[OSInode]
                    Arc::new(OSInode::new(
                        readable,
                        writable,
                        inode,  ))
                })
```
在根目录`ROOT_INODE`中创建一个文件，返回`OSInode`

*打开(查找)文件*
```rust
fn open_file(name: &str, flags: OpenFlags) -> Option<Arc<OSInode>> {
  ......
 ROOT_INODE.find(name) //在根目录中查找DireEntry<name，inode>
            .map(|inode| { //创建进程中fd_table[OSInode]
                Arc::new(OSInode::new(
                    readable,
                    writable,
                    inode ))
            })
```
在根目录`ROOT_INODE`中找到一个文件，返回`OSInode`

*关闭文件*
```rust
pub fn sys_close(fd: usize) -> isize {
    let task = current_task().unwrap();
    let mut inner = task.inner_exclusive_access();
    ......
    inner.fd_table[fd].take();
    0
}
```
`sys_close`：将进程控制块中的文件描述符表对应的一项改为 None 代表它已经空闲即可，同时这也会导致文件的引用计数减一，当引用计数减少到 0 之后文件所占用的资源就会被自动回收。

*基于文件加载应用*（ELF可执行文件格式）
```rust
pub fn sys_exec(path: *const u8) -> isize {
    if let Some(app_inode) = open_file(path.as_str(), ...) {
        let all_data = app_inode.read_all();
        let task = current_task().unwrap();
        task.exec(all_data.as_slice()); 0
} else { -1 }
```
当获取应用的 ELF 文件数据时，首先调用 `open_file` 函数，以只读方式打开应用文件并获取它对应的 `OSInode` 。接下来可以通过 `OSInode::read_all` 将该文件的数据全部读到一个向量 `all_data` 中

*读写文件*
- 基于文件抽象接口和文件描述符表
- 可以按照无结构的字节流在处理基本的文件读写
  ```rust
  pub fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize {
        if let Some(file) = &inner.fd_table[fd] {
            file.write(
                UserBuffer::new(translated_byte_buffer(token, buf, len))
            ) as isize

  pub fn sys_read(fd: usize, buf: *const u8, len: usize) -> isize {
        if let Some(file) = &inner.fd_table[fd] {
            file.read(
                UserBuffer::new(translated_byte_buffer(token, buf, len))
            ) as isize
  ```
  操作系统都是通过文件描述符在当前进程的文件描述符表中找到某个文件，无需关心文件具体的类型。

#note(subname: [easy-fs总结])[
  *ch6 新增数据结构与关系总览（Easy-FS + OS 文件系统层）*

  从 ch6 开始，本实验加入了一个完整的 *块设备 + 文件系统 + VFS 抽象 + OS 文件接口 + 文件描述符表*。

  整个结构分 4 层：

  ```
  用户进程（系统调用 open/read/write/...）
          ↓
  OS 文件层（File trait, OSInode, FD table）
          ↓
  VFS 层（easy-fs::Inode）
          ↓
  Easy-FS 文件系统层（磁盘 inode / 数据块 / bitmap）
          ↓
  块设备（QEMU virtio-blk）
  ```

  下文将按模块依次总结所有新增结构。

  1. 块设备层（Block Device Layer）
    - ✦ BlockDevice trait
      - 路径：`easy-fs/src/block_dev.rs`
      ```rust
      pub trait BlockDevice: Send + Sync + Any {
          fn read_block(&self, block_id: usize, buf: &mut [u8]);
          fn write_block(&self, block_id: usize, buf: &[u8]);
      }
      ```
      *含义*：定义一个通用的“块设备”接口。底层可以是 QEMU 的 virtio-blk，也可以是文件系统打包工具 easy-fs-fuse 的 BlockFile。所有文件系统操作最终都会通过 BlockDevice 读写磁盘块。
  2. 块缓存层（Block Cache Layer）
    - ✦ BlockCache
      - 路径：`easy-fs/src/block_cache.rs`
      - 缓存单个磁盘块，提供：
        - read / modify 块内数据
        - 自动回写（Drop 时 sync）
        - Arc + Mutex 管理共享缓存
    - ✦ BlockCacheManager + 全局 BLOCK_CACHE_MANAGER
      - 维持固定数量（16）的块缓存
        - LRU 替换
        - 自动 sync 全部缓存
    - 关系：
    ```
    EasyFileSystem
        ↓
    get_block_cache
        ↓
    BlockCacheManager
        ↓
    BlockCache（单个块）
    ```
  3. 磁盘布局层（Disk Layout Layer）
    - 路径：`easy-fs/src/layout.rs`
    - 定义磁盘中 *真正存储的结构体*：
    - ✦ SuperBlock
      - 描述整个文件系统布局：
        - 总块数
        - inode 位图大小
        - data 位图大小
        - inode 区域大小
        - 数据区大小
        - magic number
    - ✦ DiskInode
      - 磁盘中的 inode 实际存储结构：
      - 字段：
        - size（字节）
        - type（文件或目录）
        - direct[28]
        - indirect1
        - indirect2
      - 包含方法：
        - read_at / write_at
        - increase_size
        - clear_size
        - get_block_id（根据逻辑块号找到真正的数据块）
    - 关系：
    ```
    DiskInode -> 数据块
              -> 完整管理直接块 / 一级间接块 / 二级间接块
    ```
    - ✦ DirEntry
      - 目录项：
      ```rust
      pub struct DirEntry {
          name: [u8; 28],
          inode_id: u32,
      }
      ```
  4. EasyFileSystem 层（easy-fs/src/efs.rs）
    - 文件系统的核心抽象：
    - ✦ EasyFileSystem
      - 字段：
      #three-line-table[
        | 字段                     | 含义          |
        | ---------------------- | ----------- |
        | block_device           | 底层块设备       |
        | inode_bitmap           | inode 位图分配器 |
        | data_bitmap            | 数据块位图分配器    |
        | inode_area_start_block | inode 区起始块  |
        | data_area_start_block  | 数据块区起始块     |
      ]
      - 方法：
        - create（格式化一个 EFS）
        - open（打开一个已有的 EFS）
        - root_inode
        - alloc_inode / alloc_data
        - dealloc_data
        - get_disk_inode_pos
      - 关系：
      ```
      EasyFS -> inode_bitmap / data_bitmap
            -> 块缓存层读写 DiskInode
            -> 提供真正的 root Inode
      ```
  5. VFS 层（Virtual FS Layer）
    - 路径：`easy-fs/src/vfs.rs`
    - 把磁盘结构包装成“可操作”的 inode
    - ✦ easy_fs::Inode
      - 字段：
        - block_id
        - block_offset
        - fs: Arc\<Mutex\<EasyFileSystem\>\>
        - block_device
      - 方法：
        - find(name)
        - create(name)
        - ls()
        - read_at / write_at
        - clear()
        - metadata()
    - 关系：
    ```
    OSInode(内核) → Inode(VFS) → DiskInode(磁盘) → 数据块
    ```
  6. OS 文件层（OS FS Layer）
    - 路径：`os/src/fs/inode.rs`
    - 负责给 OS 提供统一的文件抽象。
    - ✦ OSInode
      - 包装 easy-fs 的 Inode，使之实现 File trait。
      - 字段：
        #three-line-table[
          | 字段                              | 功能           |
          | ------------------------------- | ------------ |
          | readable                        | 是否可读         |
          | writable                        | 是否可写         |
          | inner: UPSafeCell\<OSInodeInner\> | 带 offset 的结构 |
        ]
    - ✦ OSInodeInner
      ```rust
      pub struct OSInodeInner {
          offset: usize,
          inode: Arc<Inode>,
      }
      ```
      - 包含文件偏移（为每个 open 独立）
      - 指向 easy_fs::Inode
    - ✦ File trait（统一 IO 抽象）
      - 路径：`os/src/fs/mod.rs`
      ```rust
      pub trait File {
          fn read(&self, buf: UserBuffer) -> usize;
          fn write(&self, buf: UserBuffer) -> usize;
          fn get_stat(&self, stat: &mut Stat) -> isize { -1 }
      }
      ```
      - 所有文件类型都实现 File：
        - OSInode（普通文件）
        - Stdin
        - Stdout
        - PipeRead / PipeWrite（ch7）
    - ✦ ROOT_INODE
      - easy-fs 的根目录挂载点
      ```rust
      lazy_static! {
          pub static ref ROOT_INODE: Arc<Inode>
      }
      ```
  7. OS 层的文件描述符表（FD table）
    - 路径：`os/task/task.rs`
    - 在 TaskControlBlockInner 中新增字段：
    ```rust
    pub fd_table: Vec<Option<Arc<dyn File>>>
    ```
    每打开一个文件：
    - 生成一个 OSInode
    - 插入 fd_table
  8. easy-fs-fuse 打包工具
    - 作为辅助模块用于生成 `fs.img`：
      - BlockFile 实现 BlockDevice
      - 将 host 文件读入 easy-fs 根目录中
    - 与 OS 运行无直接关系，但用于构建 `fs.img`。

  *总图（关键结构关系）*
  ```
  用户态
   └── sys_open / read / write / close / unlink / fstat
         ↓
  Task.fd_table : Vec<Option<Arc<dyn File>>>
         ↓
  OSInode --------------→ easy_fs::Inode
         |                         ↓
         |                 DiskInode + DirEntry
         ↓                         ↓
  File trait                  数据块（BlockCache）
         ↓                         ↓
  UserBuffer                 BlockDevice
  ```
  *关键数据结构总结表*
  #three-line-table[
    | 层级     | 结构                             | 功能                |
    | ------ | ------------------------------ | ----------------- |
    | 块设备层   | BlockDevice                    | 读写磁盘块             |
    | 缓存层    | BlockCache / BlockCacheManager | 缓存磁盘数据块           |
    | 文件系统层  | SuperBlock                     | 描述文件系统布局          |
    | 文件系统层  | Bitmap                         | inode/data 位图管理   |
    | 文件系统层  | DiskInode                      | 磁盘上真实 inode       |
    | 文件系统层  | DirEntry                       | 目录项               |
    | 文件系统层  | EasyFileSystem                 | 文件系统核心管理          |
    | VFS 层  | Inode                          | 对 DiskInode 的抽象封装 |
    | OS 文件层 | OSInode                        | 内核中的文件对象          |
    | OS 文件层 | File trait                     | 统一文件访问接口          |
    | OS 文件层 | Stdin / Stdout                 | 控制台 I/O           |
    | 进程层    | fd_table                       | 每个进程的文件描述符表       |
  ]

]
