TARGET_DIR:=bin
SRC_DIR:=src
CC:=gcc

SRCS:=$(wildcard $(SRC_DIR)/*.c)
TARGETS:=$(patsubst $(SRC_DIR)/%.c,$(TARGET_DIR)/%,$(SRCS))

LOG_DIR:=log
STRACE_SH:=strace.sh

all: $(TARGETS) STRACE

$(TARGET_DIR)/%: $(SRC_DIR)/%.c
	mkdir -p $(TARGET_DIR)
	$(CC) -o $@ $<
	chmod +x $@
	echo "Built $@"

STRACE: $(STRACE_SH)
	mkdir -p $(LOG_DIR)
	bash $(STRACE_SH)

clean:
	rm -rf $(TARGET_DIR) $(LOG_DIR) output.txt

.PHONY: all clean