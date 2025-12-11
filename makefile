# =========================
#  Host detection
# =========================
HOST_OS   := $(shell uname -s)
HOST_ARCH := $(shell uname -m)

# =========================
#  Compilers
# =========================
# Use Apple clang on macOS, gcc/g++ elsewhere
ifeq ($(HOST_OS),Darwin)
  CC  := clang
  CXX := clang++
else
  CC  := gcc
  CXX := g++
endif

# =========================
#  Common settings
# =========================
TARGET  := WiiMartPatcher
SRC_DIR := src
INC_DIR := include

SRCS     := $(wildcard $(SRC_DIR)/*.c $(SRC_DIR)/*.cpp)
INCLUDES := -I$(INC_DIR)

CFLAGS   := -Wall -g -std=c11
CXXFLAGS := -Wall -g -std=c++17

# =========================
#  macOS native build
# =========================

# Decide Homebrew prefix and binary name
ifeq ($(HOST_OS),Darwin)
  ifeq ($(HOST_ARCH),arm64)
    BREW_PREFIX ?= /opt/homebrew
    MAC_BIN     := $(TARGET)_mac_arm64
  else ifeq ($(HOST_ARCH),x86_64)
    BREW_PREFIX ?= /usr/local
    MAC_BIN     := $(TARGET)_mac_x86_64
  else
    MAC_BIN     := $(TARGET)_mac_unknown
  endif

  CFLAGS   += -I$(BREW_PREFIX)/include
  CXXFLAGS += -I$(BREW_PREFIX)/include

  MAC_LDFLAGS := -L$(BREW_PREFIX)/lib
  MAC_LIBS    := -lcurl -lssh2

  OBJ_DIR_MAC := obj_mac
  MAC_OBJS    := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_MAC)/%.o,$(filter %.c,$(SRCS)))
  MAC_OBJS    += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_MAC)/%.o,$(filter %.cpp,$(SRCS)))

endif

# =========================
#  Linux static builds via Docker
#  (build Linux binaries even from macOS)
# =========================

DOCKER_IMG_64        := wiimartpatcher_alpine_builder_x64
DOCKER_IMG_32        := wiimartpatcher_alpine_builder_x86
LINUX_STATIC_BIN_64  := $(TARGET)_linux_static_x64
LINUX_STATIC_BIN_32  := $(TARGET)_linux_static_x86
OBJ_DIR_LINUX64      := obj_linux64
OBJ_DIR_LINUX32      := obj_linux32

LINUX64_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUX64)/%.o,$(filter %.c,$(SRCS)))
LINUX64_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUX64)/%.o,$(filter %.cpp,$(SRCS)))

LINUX32_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUX32)/%.o,$(filter %.c,$(SRCS)))
LINUX32_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUX32)/%.o,$(filter %.cpp,$(SRCS)))

# =========================
#  Windows (MinGW) cross builds
# =========================

CROSS_TRIPLE_64 := x86_64-w64-mingw32
CROSS_CC_64     := $(CROSS_TRIPLE_64)-gcc
CROSS_CXX_64    := $(CROSS_TRIPLE_64)-g++
WIN_BIN_64      := $(TARGET)_win_x64.exe

CROSS_TRIPLE_32 := i686-w64-mingw32
CROSS_CC_32     := $(CROSS_TRIPLE_32)-gcc
CROSS_CXX_32    := $(CROSS_TRIPLE_32)-g++
WIN_BIN_32      := $(TARGET)_win_x86.exe

CROSS_CFLAGS_64   := $(CFLAGS)   -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CXXFLAGS_64 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CFLAGS_32   := $(CFLAGS)   -DCURL_STATICLIB -D_WIN32_WINNT=0x0501
CROSS_CXXFLAGS_32 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0501

OBJ_DIR_WIN64 := obj_win64
OBJ_DIR_WIN32 := obj_win32

WIN64_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_WIN64)/%.o,$(filter %.c,$(SRCS)))
WIN64_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_WIN64)/%.o,$(filter %.cpp,$(SRCS)))

WIN32_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_WIN32)/%.o,$(filter %.c,$(SRCS)))
WIN32_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_WIN32)/%.o,$(filter %.cpp,$(SRCS)))

LDFLAGS_CROSS_STATIC := -static -static-libgcc -static-libstdc++

# =========================
#  Phony high-level targets
# =========================
.PHONY: all mac linux windows clean clean-mac clean-linux clean-windows \
        linux-static linux-static-internal-64 linux-static-internal-32

# Build everything we reasonably can from this host
all: mac linux windows

# =========================
#  macOS section
# =========================
ifeq ($(HOST_OS),Darwin)

mac: $(MAC_BIN)

$(OBJ_DIR_MAC):
	@mkdir -p $(OBJ_DIR_MAC)

$(OBJ_DIR_MAC)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_MAC)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_MAC)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_MAC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(MAC_BIN): $(MAC_OBJS)
	$(CXX) $(CXXFLAGS) $(MAC_OBJS) $(MAC_LDFLAGS) $(MAC_LIBS) -o $@

else

# On non-macOS, mac target is a stub
mac:
	@echo "mac target only supported on macOS (Darwin). Skipping."

endif

# =========================
#  Linux static via Docker
# =========================

linux: linux-static

linux-static: $(LINUX_STATIC_BIN_64) $(LINUX_STATIC_BIN_32)

docker-build-64:
	@docker build -t $(DOCKER_IMG_64) -f Dockerfile.x64 .

docker-build-32:
	@docker build -t $(DOCKER_IMG_32) -f Dockerfile.x86 .

# These run *inside* the containers, from the same Makefile
$(LINUX_STATIC_BIN_64): docker-build-64
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_64) \
		sh -c "cd /app && make linux-static-internal-64"

$(LINUX_STATIC_BIN_32): docker-build-32
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_32) \
		sh -c "cd /app && make linux-static-internal-32"

linux-static-internal-64: $(OBJ_DIR_LINUX64) $(LINUX64_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUX64_OBJS) -static -o $(LINUX_STATIC_BIN_64) `pkg-config --static --libs libcurl`

linux-static-internal-32: $(OBJ_DIR_LINUX32) $(LINUX32_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUX32_OBJS) -static -o $(LINUX_STATIC_BIN_32) `pkg-config --static --libs libcurl`

$(OBJ_DIR_LINUX64):
	@mkdir -p $(OBJ_DIR_LINUX64)

$(OBJ_DIR_LINUX32):
	@mkdir -p $(OBJ_DIR_LINUX32)

$(OBJ_DIR_LINUX64)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUX64)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX64)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUX64)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX32)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUX32)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX32)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUX32)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# =========================
#  Windows cross builds
# =========================

windows: $(WIN_BIN_64) $(WIN_BIN_32)

$(OBJ_DIR_WIN64):
	@mkdir -p $(OBJ_DIR_WIN64)

$(OBJ_DIR_WIN32):
	@mkdir -p $(OBJ_DIR_WIN32)

$(OBJ_DIR_WIN64)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_WIN64)
	$(CROSS_CC_64) $(CROSS_CFLAGS_64) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_WIN64)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_WIN64)
	$(CROSS_CXX_64) $(CROSS_CXXFLAGS_64) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_WIN32)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_WIN32)
	$(CROSS_CC_32) $(CROSS_CFLAGS_32) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_WIN32)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_WIN32)
	$(CROSS_CXX_32) $(CROSS_CXXFLAGS_32) $(INCLUDES) -c $< -o $@

$(WIN_BIN_64): $(OBJ_DIR_WIN64) $(WIN64_OBJS)
	$(CROSS_CXX_64) $(LDFLAGS_CROSS_STATIC) $(WIN64_OBJS) \
		`$(CROSS_TRIPLE_64)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` \
		-o $@

$(WIN_BIN_32): $(OBJ_DIR_WIN32) $(WIN32_OBJS)
	$(CROSS_CXX_32) $(LDFLAGS_CROSS_STATIC) $(WIN32_OBJS) \
		`$(CROSS_TRIPLE_32)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` \
		-o $@

# =========================
#  Cleaning
# =========================

.PHONY: clean clean-mac clean-linux clean-windows

clean: clean-mac clean-linux clean-windows
	@rm -f $(MAC_BIN) $(LINUX_STATIC_BIN_64) $(LINUX_STATIC_BIN_32) \
		$(WIN_BIN_64) $(WIN_BIN_32)

clean-mac:
	@rm -rf obj_mac

clean-linux:
	@rm -rf $(OBJ_DIR_LINUX64) $(OBJ_DIR_LINUX32)

clean-windows:
	@rm -rf $(OBJ_DIR_WIN64) $(OBJ_DIR_WIN32)

