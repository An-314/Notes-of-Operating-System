#import "@preview/scripst:1.1.1": *

#show: scripst.with(
  title: [操作系统第3次作业],
  author: "Anzreww",
  time: "2025/9/18",
  contents: true,
)

= 第一题

#exercise[
  依据操作系统课实验的选择，搭建所需要的实验环境。然后描述自己在搭建实验环境过程中问题和解决方法。
  - #link("https://learningos.cn/rCore-Tutorial-Guide-2022A/0setup-devel-env.html")[rcore]
]

#solution[
  选择rCore实验环境
  - 参考官方文档：https://learningos.cn/rCore-Tutorial-Guide-2022A/0setup-devel-env.html
  - 手动方式进行本地OS开发环境配置，本机环境为
    - OS: Arch Linux
    - CPU: 12th Gen Intel i7-12700H (20) \@ 4.600GHz
    - Arch: x86_64
  - 主要步骤
    - Rust 开发环境配置
      ```bash
      sudo pacman -S rustup
      rustup default stable
      rustup update
      ```
      确认 Rust 版本
      ```bash
      rustc --version
      ```
      结果为
      ```
      rustc 1.90.0 (1159e78c4 2025-09-14)
      ```
    - Qemu 模拟器安装
      从#link("https://wiki.archlinux.org/title/QEMU")[archlinux wiki]可以看到 qemu 在 archlinux 下的安装方式和使用方法
      ```bash
      sudo pacman -S qemu-full
      ```
      确认 qemu 版本
      ```bash
      qemu-system-riscv64 --version
      ```
      ```bash
      qemu-riscv64 --version
      ```
      结果为
      ```
      QEMU emulator version 10.1.0
      Copyright (c) 2003-2025 Fabrice Bellard and the QEMU Project developers
      ```
      ```
      qemu-riscv64 version 10.1.0
      Copyright (c) 2003-2025 Fabrice Bellard and the QEMU Project developers
      ```
    - 试运行 rCore-Tutorial
      ```bash
      git clone git@github.com:rcore-os/rCore-Tutorial-v3.git
      cd rCore-Tutorial-v3
      git checkout ch1
      cd os
      make run
      ```
      在运行时遇到错误
      ```
      (rustup target list | grep "riscv64gc-unknown-none-elf (installed)") || rustup target add riscv64gc-unknown-none-elf
      riscv64gc-unknown-none-elf (installed)
      cargo install cargo-binutils
          Updating crates.io index
          Ignored package `cargo-binutils v0.4.0` is already installed, use --force to override
      rustup component add rust-src
      info: component 'rust-src' is up to date
      rustup component add llvm-tools-preview
      info: component 'llvm-tools' for target 'x86_64-unknown-linux-gnu' is up to date
      Platform: qemu
          Finished `release` profile [optimized + debuginfo] target(s) in 0.00s
      make: rust-objcopy: 没有那个文件或目录
      make: *** [Makefile:37：target/riscv64gc-unknown-none-elf/release/os.bin] 错误 127
      ```
      通过引入环境变量
      ```bash
      export PATH="$HOME/.cargo/bin:$PATH"
      ```
      将`cargo-binutils`加入PATH后，`rust-objcopy`就会调用 当前 toolchain 自带的`llvm-objcopy`，从而解决问题。
  ```log
  ❯ LOG=DEBUG make run
  \033[0;32mQEMU version is 10.1.0(>=7), OK!\033[0m
  (rustup target list | grep "riscv64gc-unknown-none-elf (installed)") || rustup target add riscv64gc-unknown-none-elf
  riscv64gc-unknown-none-elf (installed)
  cargo install cargo-binutils
      Updating crates.io index
       Ignored package `cargo-binutils v0.4.0` is already installed, use --force to override
  rustup component add rust-src
  info: component 'rust-src' is up to date
  rustup component add llvm-tools-preview
  info: component 'llvm-tools' for target 'x86_64-unknown-linux-gnu' is up to date
  Platform: qemu
     Compiling os v0.1.0 (/home/A/Documents/Notes/6_Hacking/8_OS/LAB/rCore-Tutorial-v3/os)
      Finished `release` profile [optimized + debuginfo] target(s) in 0.10s
  [rustsbi] RustSBI version 0.3.1, adapting to RISC-V SBI v1.0.0
  .______       __    __      _______.___________.  _______..______   __
  |   _  \     |  |  |  |    /       |           | /       ||   _  \ |  |
  |  |_)  |    |  |  |  |   |   (----`---|  |----`|   (----`|  |_)  ||  |
  |      /     |  |  |  |    \   \       |  |      \   \    |   _  < |  |
  |  |\  \----.|  `--'  |.----)   |      |  |  .----)   |   |  |_)  ||  |
  | _| `._____| \______/ |_______/       |__|  |_______/    |______/ |__|
  [rustsbi] Implementation     : RustSBI-QEMU Version 0.2.0-alpha.2
  [rustsbi] Platform Name      : riscv-virtio,qemu
  [rustsbi] Platform SMP       : 1
  [rustsbi] Platform Memory    : 0x80000000..0x88000000
  [rustsbi] Boot HART          : 0
  [rustsbi] Device Tree Region : 0x87e00000..0x87e013a4
  [rustsbi] Firmware Address   : 0x80000000
  [rustsbi] Supervisor Address : 0x80200000
  [rustsbi] pmp01: 0x00000000..0x80000000 (-wr)
  [rustsbi] pmp02: 0x80000000..0x80200000 (---)
  [rustsbi] pmp03: 0x80200000..0x88000000 (xwr)
  [rustsbi] pmp04: 0x88000000..0x00000000 (-wr)
  [kernel] Hello, world!
  [DEBUG] [kernel] .rodata [0x80202000, 0x80203000)
  [ INFO] [kernel] .data [0x80203000, 0x80204000)
  [ WARN] [kernel] boot_stack top=bottom=0x80214000, lower_bound=0x80204000
  [ERROR] [kernel] .bss [0x80214000, 0x80215000)
  [rustsbi-panic] hart 0 %
  ```
  但该方法在实验仓库`rCore-Tutorial-Code.git`中无法使用，原因是`QEMU`版本过高(10.1.0)，而实验要求`QEMU`版本要求在`7.0.0`到`8.0.0`之间。
  - 由于Arch Linux的滚动更新机制，`pacman`无法安装指定版本的`QEMU`，只能安装最新版；在安装旧版本的时候会有一系列依赖冲突问题
    - 通过`downgrade`命令将`QEMU`版本降级，发现依赖关系过于复杂，会和系统中的一些库冲突，考虑编译安装
    - 在编译过程中发现`QEMU`的 eBPF 模块和系统里的 libbpf API 版本不兼容，导致编译失败
    - 最终选择用`Docker`容器来编译安装`QEMU 7.0.0`
  ```log
  A-Terminal# make run
  (rustup target list | grep "riscv64gc-unknown-none-elf (installed)") || rustup target add riscv64gc-unknown-none-elf
  info: syncing channel updates for 'nightly-2024-05-02-x86_64-unknown-linux-gnu'
  info: latest update on 2024-05-02, rust version 1.80.0-nightly (c987ad527 2024-05-01)
  info: downloading component 'cargo'
  info: downloading component 'clippy'
  info: downloading component 'llvm-tools'
  info: downloading component 'rust-src'
  info: downloading component 'rust-std'
  info: downloading component 'rustc'
  info: downloading component 'rustfmt'
  info: installing component 'cargo'
  info: installing component 'clippy'
  info: installing component 'llvm-tools'
  info: installing component 'rust-src'
  info: installing component 'rust-std'
  info: installing component 'rustc'
  info: installing component 'rustfmt'
  info: downloading component 'rust-std' for 'riscv64gc-unknown-none-elf'
  info: installing component 'rust-std' for 'riscv64gc-unknown-none-elf'
  cargo install cargo-binutils
      Updating crates.io index
    Downloaded cargo-binutils v0.4.0
    Downloaded 1 crate (28.2 KB) in 0.67s
      Ignored package `cargo-binutils v0.4.0` is already installed, use --force to override
  rustup component add rust-src
  info: component 'rust-src' is up to date
  rustup component add llvm-tools-preview
  info: component 'llvm-tools' for target 'x86_64-unknown-linux-gnu' is up to date
  Platform: qemu
      Updating crates.io index
    Downloaded log v0.4.28
    Downloaded 1 crate (51.1 KB) in 0.71s
    Compiling log v0.4.28
    Compiling os v0.1.0 (/mnt/os)
      Finished `release` profile [optimized + debuginfo] target(s) in 1.13s
  [rustsbi] RustSBI version 0.3.0-alpha.4, adapting to RISC-V SBI v1.0.0
  .______       __    __      _______.___________.  _______..______   __
  |   _  \     |  |  |  |    /       |           | /       ||   _  \ |  |
  |  |_)  |    |  |  |  |   |   (----`---|  |----`|   (----`|  |_)  ||  |
  |      /     |  |  |  |    \   \       |  |      \   \    |   _  < |  |
  |  |\  \----.|  `--'  |.----)   |      |  |  .----)   |   |  |_)  ||  |
  | _| `._____| \______/ |_______/       |__|  |_______/    |______/ |__|
  [rustsbi] Implementation     : RustSBI-QEMU Version 0.2.0-alpha.2
  [rustsbi] Platform Name      : riscv-virtio,qemu
  [rustsbi] Platform SMP       : 1
  [rustsbi] Platform Memory    : 0x80000000..0x88000000
  [rustsbi] Boot HART          : 0
  [rustsbi] Device Tree Region : 0x87000000..0x87000ef2
  [rustsbi] Firmware Address   : 0x80000000
  [rustsbi] Supervisor Address : 0x80200000
  [rustsbi] pmp01: 0x00000000..0x80000000 (-wr)
  [rustsbi] pmp02: 0x80000000..0x80200000 (---)
  [rustsbi] pmp03: 0x80200000..0x88000000 (xwr)
  [rustsbi] pmp04: 0x88000000..0x00000000 (-wr)
  [kernel] Hello, world!
  ```
]

= 第二题

#exercise[
  在你选择的开发和运行环境下，写一个函数`print_stackframe()`，用于获取当前位置的函数调用栈信息。实现如下一种或多种功能：函数入口地址、函数名信息、参数调用参数信息、返回值信息。
  可能的环境选择：
  - 操作系统环境：Linux、uCore、rCore、MacOS、Windows...
  - 特权级：用户态、内核态
  - 编程语言：Rust、C...
]
