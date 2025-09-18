#import "@preview/scripst:1.1.1": *

#show: scripst.with(
  title: [操作系统第2次作业],
  author: "刘骥安 2022013054",
  time: "2025/9/18",
  contents: true,
)

= 第一题

#exercise[
  熟练使用开发环境是顺利和高效完成操作系统课实验的必要条件。请从互联网搜索你需要的信息，以逐渐熟练使用qemu、shell、vim（也可以是其他你喜欢的代码编辑工具）和git等工具。然后回答如下问题。
  1. 简要介绍一个模拟器工具，并查找相关的配置使用帮助；
  2. 简要介绍一个命令行工具，并查找相关的配置使用帮助；
  3. 简要介绍一个代码编辑工具，并查找相关的配置使用帮助；
  4. 简要介绍一个代码版本维护工具，并查找相关的配置使用帮助；
]

#solution[
  1. QEMU(Quick EMUlator)是一个开源的虚拟机模拟器，支持x86、ARM、RISC-V等架构，可以模拟完整的计算机系统。在实验中我们要用的是`qemu-system-riscv64`。QEMU的官方网站是 https://www.qemu.org/documentation/ ，提供了详细的文档和使用指南；archlinux的wiki https://wiki.archlinuxcn.org/wiki/QEMU 提供了安装、配置和使用方式的详细说明；以及详细的中文介绍 https://zhuanlan.zhihu.com/p/580681197 。
  2. Bash(Bourne Again SHell)是Linux和Unix系统中常用的命令行解释器，提供了强大的脚本编写和命令执行功能。Bash的官方网站是 https://www.gnu.org/software/bash/ ，提供了完整的文档和手册；archlinux的wiki https://wiki.archlinuxcn.org/wiki/Bash 提供了安装、配置和使用方式的详细说明。 zsh(Z Shell)是另一个功能强大的命令行解释器，具有更丰富的功能和插件支持。zsh的官方网站是 https://www.zsh.org/ ，提供了详细的文档和使用指南；archlinux的wiki https://wiki.archlinuxcn.org/wiki/Zsh 提供了安装、配置和使用方式的详细说明。
  3. VSCode(Visual Studio Code)是一个由微软开发的开源代码编辑器，支持多种编程语言和扩展插件，对各种编程任务提供了强大的支持。VSCode的官方网站是 https://code.visualstudio.com/ 。
  4. Git是一个分布式版本控制系统，用于跟踪文件的更改和协作开发。Git的官方网站是 https://git-scm.com/ ，提供了完整的文档和手册；Pro Git电子书 https://git-scm.com/book/zh/v2 提供了详细的中文介绍和使用指南。
]

= 第二题

#exercise[
  下面是一组使用系统调用服务的应用程序。请尝试运行和分析其中的一个你有兴趣小例子的执行过程，利用Linux系统中的#link("https://zhuanlan.zhihu.com/p/69527356")[strace]工具来确定该应用程序在执行时调用了哪些系统调用。

  #link("https://pdos.csail.mit.edu/6.828/2021/lec/l-overview/")[使用操作系统的系统调用服务的应用程序示例列表]（出处：MIT的操作系统课）
]
