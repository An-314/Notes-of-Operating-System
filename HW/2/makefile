# 编译所有源文件并生成可执行文件
TARGET_DIR:=bin
SRC_DIR:=src
CC:=gcc
SRCS:=$(wildcard $(SRC_DIR)/*.c)
TARGETS:=$(patsubst $(SRC_DIR)/%.c,$(TARGET_DIR)/%,$(SRCS))

# 利用 strace.sh 脚本对所有可执行文件进行系统调用跟踪
LOG_DIR:=log
STRACE_SH:=strace.sh

# 对作业报告进行编译
MAIN:=main.pdf

all: $(TARGETS) STRACE $(MAIN)

$(TARGET_DIR)/%: $(SRC_DIR)/%.c
	mkdir -p $(TARGET_DIR)
	$(CC) -o $@ $<
	chmod +x $@
	echo "Built $@"

STRACE: $(STRACE_SH)
	mkdir -p $(LOG_DIR)
	bash $(STRACE_SH)

$(MAIN): main.typ
	typst compile $< $@

clean:
	rm -rf $(TARGET_DIR) $(LOG_DIR) output.txt $(MAIN)

.PHONY: all clean