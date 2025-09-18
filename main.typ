#import "@preview/scripst:1.1.1": *

#let preface = [
  OS原理与设计思想
  - 操作系统结构
  - 中断及系统调用
  - 内存管理
  - 进程管理
  - 处理机调度
  - 同步互斥
  - 文件系统
  - I/O 子系统
]

#show: scripst.with(
  template: "book",
  title: [操作系统],
  author: ("Anzreww",),
  time: "乙巳秋冬于清华园",
  contents: true,
  content-depth: 3,
  matheq-depth: 3,
  lang: "zh",
  preface: preface,
)


#include "chap1.typ"
