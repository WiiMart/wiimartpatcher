# =========================
#  Host detection
# =========================
HOST_UNAME := $(shell uname -s 2>/dev/null || echo Unknown)

ifeq ($(HOST_UNAME),Darwin)
  HOST_OS   := Darwin
else ifeq ($(HOST_UNAME),Linux)
  HOST_OS   := Linux
else
  # Covers MSYS/MinGW etc. on Windows
  HOST_OS   := Windows
endif

HOST_ARCH := $(shell uname -m 2>/dev/null || echo unknown)

# =========================
#  Compilers (native)
# =========================
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
#  "native" vs "all" behavior
# =========================

# NATIVE_TARGET: what plain "make" builds on this host
# ALL_TARGETS:   what "make all" will try to build
ifeq ($(HOST_OS),Darwin)
  NATIVE_TARGET := mac
  ALL_TARGETS   := mac windows linux-docker
else ifeq ($(HOST_OS),Linux)
  NATIVE_TARGET := linux
  ALL_TARGETS   := linux windows
else
  # Windows host
  NATIVE_TARGET := windows
  ALL_TARGETS   := windows
endif

.PHONY: native all mac linux linux-docker windows \
        clean clean-mac clean-linux clean-linux-docker clean-windows

# Default goal when you just run "make"
.DEFAULT_GOAL := native

native: $(NATIVE_TARGET)

all: $(ALL_TARGETS)

# =========================
#  macOS native build
# =========================
ifeq ($(HOST_OS),Darwin)

# Decide Homebrew prefix + binary name
ifeq ($(HOST_ARCH),arm64)
  BREW_PREFIX       ?= /opt/homebrew
  MAC_BIN           := $(TARGET)_mac_arm64
else ifeq ($(HOST_ARCH),x86_64)
  BREW_PREFIX       ?= /usr/local
  MAC_BIN           := $(TARGET)_mac_x86_64
else
  BREW_PREFIX       ?= /usr/local
  MAC_BIN           := $(TARGET)_mac_unknown
endif

# Homebrew includes/libs for macOS build
CFLAGS   += -I$(BREW_PREFIX)/include
CXXFLAGS += -I$(BREW_PREFIX)/include

MAC_LDFLAGS := -L$(BREW_PREFIX)/lib
MAC_LIBS    := -lcurl -lssh2

OBJ_DIR_MAC := obj_mac
MAC_OBJS    := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_MAC)/%.o,$(filter %.c,$(SRCS)))
MAC_OBJS    += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_MAC)/%.o,$(filter %.cpp,$(SRCS)))

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

# Non-macOS: stub mac target
mac:
	@echo "To build Mac builds, build on a Mac please."

endif

# =========================
#  Native Linux build (dynamic)
# =========================
LINUX_BIN     := $(TARGET)_linux_x64
OBJ_DIR_LINUX := obj_linux

LINUX_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUX)/%.o,$(filter %.c,$(SRCS)))
LINUX_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUX)/%.o,$(filter %.cpp,$(SRCS)))

# minimal libs; adjust if you need more
LINUX_LIBS := -lcurl -lssh2

ifeq ($(HOST_OS),Linux)

linux: $(LINUX_BIN)

$(OBJ_DIR_LINUX):
	@mkdir -p $(OBJ_DIR_LINUX)

$(OBJ_DIR_LINUX)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUX)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUX)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(LINUX_BIN): $(LINUX_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUX_OBJS) $(LINUX_LIBS) -o $@

else

# Non-Linux: stub
linux:
	@echo "linux target is only native on Linux. Use 'make linux-docker' to build via Docker."

endif

# =========================
#  Linux static builds via Docker (only when explicitly requested)
# =========================
DOCKER_IMG_64        := wiimartpatcher_alpine_builder_x64
DOCKER_IMG_32        := wiimartpatcher_alpine_builder_x86
DOCKER_IMG_ARM       := wiimartpatcher_alpine_builder_arm

LINUX_STATIC_BIN_64  := $(TARGET)_linux_static_x64
LINUX_STATIC_BIN_32  := $(TARGET)_linux_static_x86
LINUX_STATIC_BIN_ARM := $(TARGET)_linux_static_arm64

OBJ_DIR_LINUX64      := obj_linux64
OBJ_DIR_LINUX32      := obj_linux32
OBJ_DIR_LINUXARM     := obj_linuxarm

LINUX64_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUX64)/%.o,$(filter %.c,$(SRCS)))
LINUX64_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUX64)/%.o,$(filter %.cpp,$(SRCS)))

LINUX32_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUX32)/%.o,$(filter %.c,$(SRCS)))
LINUX32_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUX32)/%.o,$(filter %.cpp,$(SRCS)))

LINUXARM_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_LINUXARM)/%.o,$(filter %.c,$(SRCS)))
LINUXARM_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_LINUXARM)/%.o,$(filter %.cpp,$(SRCS)))

linux-docker: $(LINUX_STATIC_BIN_64) $(LINUX_STATIC_BIN_32) $(LINUX_STATIC_BIN_ARM)

docker-build-64:
	@docker build --platform=linux/amd64 -t $(DOCKER_IMG_64) -f Dockerfile.x64 .

docker-build-32:
	@docker build --platform=linux/386 -t $(DOCKER_IMG_32) -f Dockerfile.x86 .

docker-build-arm:
	@docker build --platform=linux/arm64 -t $(DOCKER_IMG_ARM) -f Dockerfile.arm .

$(LINUX_STATIC_BIN_64): docker-build-64
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_64) \
		sh -c "cd /app && make linux-static-internal-64"

$(LINUX_STATIC_BIN_32): docker-build-32
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_32) \
		sh -c "cd /app && make linux-static-internal-32"

$(LINUX_STATIC_BIN_ARM): docker-build-arm
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_ARM) \
		sh -c "cd /app && make linux-static-internal-arm"

linux-static-internal-64: $(OBJ_DIR_LINUX64) $(LINUX64_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUX64_OBJS) -static -o $(LINUX_STATIC_BIN_64) `pkg-config --static --libs libcurl`

linux-static-internal-32: $(OBJ_DIR_LINUX32) $(LINUX32_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUX32_OBJS) -static -o $(LINUX_STATIC_BIN_32) `pkg-config --static --libs libcurl`

linux-static-internal-arm: $(OBJ_DIR_LINUXARM) $(LINUXARM_OBJS)
	$(CXX) $(CXXFLAGS) $(LINUXARM_OBJS) -static -o $(LINUX_STATIC_BIN_ARM) `pkg-config --static --libs libcurl`

$(OBJ_DIR_LINUX64):
	@mkdir -p $(OBJ_DIR_LINUX64)

$(OBJ_DIR_LINUX32):
	@mkdir -p $(OBJ_DIR_LINUX32)

$(OBJ_DIR_LINUXARM):
	@mkdir -p $(OBJ_DIR_LINUXARM)

$(OBJ_DIR_LINUX64)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUX64)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX64)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUX64)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX32)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUX32)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUX32)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUX32)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUXARM)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR_LINUXARM)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_LINUXARM)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR_LINUXARM)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# =========================
#  Windows cross builds (MinGW)
# =========================

# Triples
CROSS_TRIPLE_64 := x86_64-w64-mingw32
CROSS_CC_64     := $(CROSS_TRIPLE_64)-gcc
CROSS_CXX_64    := $(CROSS_TRIPLE_64)-g++
WIN_BIN_64      := $(TARGET)_win_x64.exe

CROSS_TRIPLE_32 := i686-w64-mingw32
CROSS_CC_32     := $(CROSS_TRIPLE_32)-gcc
CROSS_CXX_32    := $(CROSS_TRIPLE_32)-g++
WIN_BIN_32      := $(TARGET)_win_x86.exe

# Where your static libcurl builds live for MinGW.
# Override if needed:
#   MINGW_WIN64_PREFIX=/opt/mingw64 MINGW_WIN32_PREFIX=/opt/mingw32
MINGW_WIN64_PREFIX ?= $(HOME)/mingw-win64-root
MINGW_WIN32_PREFIX ?= $(HOME)/mingw-win32-root

# Cross CFLAGS with curl headers
CROSS_CFLAGS_64   ?= $(CFLAGS)   -I$(MINGW_WIN64_PREFIX)/include -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CXXFLAGS_64 ?= $(CXXFLAGS) -I$(MINGW_WIN64_PREFIX)/include -DCURL_STATICLIB -D_WIN32_WINNT=0x0502

CROSS_CFLAGS_32   ?= $(CFLAGS)   -I$(MINGW_WIN32_PREFIX)/include -DCURL_STATICLIB -D_WIN32_WINNT=0x0501
CROSS_CXXFLAGS_32 ?= $(CXXFLAGS) -I$(MINGW_WIN32_PREFIX)/include -DCURL_STATICLIB -D_WIN32_WINNT=0x0501

# Static link flags with curl libs
LDFLAGS_CROSS_STATIC_64 ?= -static -static-libgcc -static-libstdc++ -L$(MINGW_WIN64_PREFIX)/lib
LDFLAGS_CROSS_STATIC_32 ?= -static -static-libgcc -static-libstdc++ -L$(MINGW_WIN32_PREFIX)/lib

# Extra Windows system libs curl wants on MinGW (64 and 32)
WIN_EXTRA_LIBS := -lws2_32 -lbcrypt -lcrypt32 -lwldap32 -lsecur32 -liphlpapi -lnormaliz

OBJ_DIR_WIN64 := obj_win64
OBJ_DIR_WIN32 := obj_win32

WIN64_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_WIN64)/%.o,$(filter %.c,$(SRCS)))
WIN64_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_WIN64)/%.o,$(filter %.cpp,$(SRCS)))

WIN32_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_WIN32)/%.o,$(filter %.c,$(SRCS)))
WIN32_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_WIN32)/%.o,$(filter %.cpp,$(SRCS)))

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
	$(CROSS_CXX_64) $(LDFLAGS_CROSS_STATIC_64) $(WIN64_OBJS) -lcurl $(WIN_EXTRA_LIBS) -o $@

$(WIN_BIN_32): $(OBJ_DIR_WIN32) $(WIN32_OBJS)
	$(CROSS_CXX_32) $(LDFLAGS_CROSS_STATIC_32) $(WIN32_OBJS) -lcurl $(WIN_EXTRA_LIBS) -o $@

# =========================
#  Cleaning
# =========================
clean: clean-mac clean-linux clean-linux-docker clean-windows
	@rm -f $(MAC_BIN) $(LINUX_BIN) \
		$(LINUX_STATIC_BIN_64) $(LINUX_STATIC_BIN_32) $(LINUX_STATIC_BIN_ARM) \
		$(WIN_BIN_64) $(WIN_BIN_32)

clean-mac:
	@rm -rf obj_mac

clean-linux:
	@rm -rf obj_linux

clean-linux-docker:
	@rm -rf obj_linux64 obj_linux32 obj_linuxarm

clean-windows:
	@rm -rf obj_win64 obj_win32

