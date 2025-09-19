# 基本变量
BUILD_DIR := builds

MAIN_SRC := main.typ
MAIN_PDF := $(BUILD_DIR)/main.pdf

CHAPS := $(wildcard chap*.typ)

# HW 部分
HW_SRC := $(wildcard HW/*/main.typ)
HW_PDF := $(patsubst HW/%/main.typ,$(BUILD_DIR)/HW/%.pdf,$(HW_SRC))

.PHONY: all clean

all: $(MAIN_PDF) $(HW_PDF)

# 编译主文档
$(MAIN_PDF): $(MAIN_SRC) $(CHAPS)
	mkdir -p $(dir $@)
	typst compile $< $@

# 编译每个 HW
$(BUILD_DIR)/HW/%.pdf: HW/%/main.typ
	mkdir -p $(dir $@)
	typst compile $< $@

clean:
	rm -f $(MAIN_PDF) $(HW_PDF)

