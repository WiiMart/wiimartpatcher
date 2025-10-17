CC := gcc
CXX := g++

TARGET := WiiMartPatcher

# Flags
CFLAGS := -Wall -g -std=c11
CXXFLAGS := -Wall -g -std=c++17

LDFLAGS_DYNAMIC :=
LDFLAGS_STATIC := -static
LDFLAGS_CROSS_STATIC := -static -static-libgcc -static-libstdc++

CROSS_CFLAGS_64 := $(CFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CXXFLAGS_64 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CFLAGS_32 := $(CFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0501
CROSS_CXXFLAGS_32 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0501

LIBS := -lcurl -lssh2 -lpsl -lssl -lcrypto -lgssapi_krb5 -lldap -llber -lbrotlidec -lpthread -lrt -lidn2 -lunistring -lz -lnghttp2 -ldl

# Win Cross Compile Defs
CROSS_TRIPLE_64 := x86_64-w64-mingw32
CROSS_CC_64 := $(CROSS_TRIPLE_64)-gcc
CROSS_CXX_64 := $(CROSS_TRIPLE_64)-g++
CROSS_TARGET_64 := $(TARGET)_x64.exe

CROSS_TRIPLE_32 := i686-w64-mingw32
CROSS_CC_32 := $(CROSS_TRIPLE_32)-gcc
CROSS_CXX_32 := $(CROSS_TRIPLE_32)-g++
CROSS_TARGET_32 := $(TARGET)_x86.exe

# Dir Placements
SRC_DIR := src
INC_DIR := ./include
OBJ_DIR := obj
CROSS_OBJ_DIR_64 := obj_win64
CROSS_OBJ_DIR_32 := obj_win32

SRCS := $(wildcard $(SRC_DIR)/*.c $(SRC_DIR)/*.cpp)

# Native Obj
OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(filter %.c,$(SRCS)))
OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(filter %.cpp,$(SRCS)))

# Windows Obj
CROSS_OBJS_64 := $(patsubst $(SRC_DIR)/%.c,$(CROSS_OBJ_DIR_64)/%.o,$(filter %.c,$(SRCS)))
CROSS_OBJS_64 += $(patsubst $(SRC_DIR)/%.cpp,$(CROSS_OBJ_DIR_64)/%.o,$(filter %.cpp,$(SRCS)))

CROSS_OBJS_32 := $(patsubst $(SRC_DIR)/%.c,$(CROSS_OBJ_DIR_32)/%.o,$(filter %.c,$(SRCS)))
CROSS_OBJS_32 += $(patsubst $(SRC_DIR)/%.cpp,$(CROSS_OBJ_DIR_32)/%.o,$(filter %.cpp,$(SRCS)))

INCLUDES := -I$(INC_DIR)

DOCKER_IMG := wiimartpatcher_alpine_builder

.PHONY: all clean dynamic static cross-windows docker_build_img build_static_dock

all: clean dynamic

# Dir Create
$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

$(CROSS_OBJ_DIR_64):
	@mkdir -p $(CROSS_OBJ_DIR_64)

$(CROSS_OBJ_DIR_32):
	@mkdir -p $(CROSS_OBJ_DIR_32)


# Native building

dynamic: $(OBJ_DIR) $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(OBJS) $(LDFLAGS_DYNAMIC) $(LIBS) -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Static Linux

static: clean docker_build_img build_static_dock

docker_build_img:
	@docker build -t $(DOCKER_IMG) -f Dockerfile .

build_static_dock:
	@docker run --rm \
		-v "$(shell pwd)":/app \
		$(DOCKER_IMG) \
		make $(TARGET)-intern

.PHONY: $(TARGET)-intern
$(TARGET)-intern: $(OBJ_DIR) $(OBJS)
	$(CXX) $(OBJS) $(LDFLAGS_STATIC) -o $(TARGET)-static `pkg-config --static --libs libcurl`

# Windows

cross-windows: cross-windows-64 cross-windows-32

cross-windows-64: clean-cross-64 $(CROSS_OBJ_DIR_64) $(CROSS_TARGET_64)

cross-windows-32: clean-cross-32 $(CROSS_OBJ_DIR_32) $(CROSS_TARGET_32)

$(CROSS_TARGET_64): $(CROSS_OBJS_64)
	$(CROSS_CXX_64) $(LDFLAGS_CROSS_STATIC) $(CROSS_OBJS_64) \
	`$(CROSS_TRIPLE_64)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` \
	-o $@

$(CROSS_OBJ_DIR_64)/%.o: $(SRC_DIR)/%.c
	$(CROSS_CC_64) $(CROSS_CFLAGS_64) $(INCLUDES) -c $< -o $@

$(CROSS_OBJ_DIR_64)/%.o: $(SRC_DIR)/%.cpp
	$(CROSS_CXX_64) $(CROSS_CXXFLAGS_64) $(INCLUDES) -c $< -o $@

$(CROSS_TARGET_32): $(CROSS_OBJS_32)
	$(CROSS_CXX_32) $(LDFLAGS_CROSS_STATIC) $(CROSS_OBJS_32) \
	`$(CROSS_TRIPLE_32)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` \
	-o $@

$(CROSS_OBJ_DIR_32)/%.o: $(SRC_DIR)/%.c
	$(CROSS_CC_32) $(CROSS_CFLAGS_32) $(INCLUDES) -c $< -o $@

$(CROSS_OBJ_DIR_32)/%.o: $(SRC_DIR)/%.cpp
	$(CROSS_CXX_32) $(CROSS_CXXFLAGS_32) $(INCLUDES) -c $< -o $@

# Cleanup

clean: clean-native clean-cross
	@rm -rf $(TARGET) $(TARGET)-static

clean-native:
	@rm -rf $(OBJ_DIR)

clean-cross: clean-cross-64 clean-cross-32

clean-cross-64:
	@rm -rf $(CROSS_OBJ_DIR_64) $(CROSS_TARGET_64)

clean-cross-32:
	@rm -rf $(CROSS_OBJ_DIR_32) $(CROSS_TARGET_32)

doall: clean dynamic static cross-windows