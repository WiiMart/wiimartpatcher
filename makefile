CC := gcc
CXX := g++

TARGET := WiiMartPatcher

# targets
TARGET_64 := $(TARGET)_x64
TARGET_32 := $(TARGET)_x86
TARGET_STATIC_64 := $(TARGET)-static_x64
TARGET_STATIC_32 := $(TARGET)-static_x86

# flags
CFLAGS := -Wall -g -std=c11
CXXFLAGS := -Wall -g -std=c++17

CFLAGS_64 := $(CFLAGS) -m64
CXXFLAGS_64 := $(CXXFLAGS) -m64
CFLAGS_32 := $(CFLAGS) -m32
CXXFLAGS_32 := $(CXXFLAGS) -m32

LDFLAGS_DYNAMIC :=
LDFLAGS_STATIC := -static
LDFLAGS_CROSS_STATIC := -static -static-libgcc -static-libstdc++

CROSS_CFLAGS_64 := $(CFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CXXFLAGS_64 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0502
CROSS_CFLAGS_32 := $(CFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0501
CROSS_CXXFLAGS_32 := $(CXXFLAGS) -DCURL_STATICLIB -D_WIN32_WINNT=0x0501

LIBS := -lcurl -lssh2 -lpsl -lssl -lcrypto -lgssapi_krb5 -lldap -llber -lbrotlidec -lpthread -lrt -lidn2 -lunistring -lz -lnghttp2 -ldl

# win cross def
CROSS_TRIPLE_64 := x86_64-w64-mingw32
CROSS_CC_64 := $(CROSS_TRIPLE_64)-gcc
CROSS_CXX_64 := $(CROSS_TRIPLE_64)-g++
CROSS_TARGET_64 := $(TARGET)_x64.exe

CROSS_TRIPLE_32 := i686-w64-mingw32
CROSS_CC_32 := $(CROSS_TRIPLE_32)-gcc
CROSS_CXX_32 := $(CROSS_TRIPLE_32)-g++
CROSS_TARGET_32 := $(TARGET)_x86.exe

# dirs
SRC_DIR := src
INC_DIR := ./include
OBJ_DIR_64 := obj_linux64
OBJ_DIR_32 := obj_linux32
CROSS_OBJ_DIR_64 := obj_win64
CROSS_OBJ_DIR_32 := obj_win32

SRCS := $(wildcard $(SRC_DIR)/*.c $(SRC_DIR)/*.cpp)
INCLUDES := -I$(INC_DIR)

# obj
OBJS_64 := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_64)/%.o,$(filter %.c,$(SRCS)))
OBJS_64 += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_64)/%.o,$(filter %.cpp,$(SRCS)))

OBJS_32 := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR_32)/%.o,$(filter %.c,$(SRCS)))
OBJS_32 += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_32)/%.o,$(filter %.cpp,$(SRCS)))

CROSS_OBJS_64 := $(patsubst $(SRC_DIR)/%.c,$(CROSS_OBJ_DIR_64)/%.o,$(filter %.c,$(SRCS)))
CROSS_OBJS_64 += $(patsubst $(SRC_DIR)/%.cpp,$(CROSS_OBJ_DIR_64)/%.o,$(filter %.cpp,$(SRCS)))

CROSS_OBJS_32 := $(patsubst $(SRC_DIR)/%.c,$(CROSS_OBJ_DIR_32)/%.o,$(filter %.c,$(SRCS)))
CROSS_OBJS_32 += $(patsubst $(SRC_DIR)/%.cpp,$(CROSS_OBJ_DIR_32)/%.o,$(filter %.cpp,$(SRCS)))

DOCKER_IMG_64 := wiimartpatcher_alpine_builder_x64
DOCKER_IMG_32 := wiimartpatcher_alpine_builder_x86

.PHONY: all clean dynamic static cross-windows docker-build-64 docker-build-32

all: clean dynamic static cross-windows

# dir make
$(OBJ_DIR_64):
	@mkdir -p $(OBJ_DIR_64)

$(OBJ_DIR_32):
	@mkdir -p $(OBJ_DIR_32)

$(CROSS_OBJ_DIR_64):
	@mkdir -p $(CROSS_OBJ_DIR_64)

$(CROSS_OBJ_DIR_32):
	@mkdir -p $(CROSS_OBJ_DIR_32)

# dyna make
dynamic: dynamic-64 dynamic-32

dynamic-64: $(OBJ_DIR_64) $(TARGET_64)

dynamic-32: $(OBJ_DIR_32) $(TARGET_32)

$(TARGET_64): $(OBJS_64)
	$(CXX) $(CXXFLAGS_64) $(OBJS_64) $(LDFLAGS_DYNAMIC) $(LIBS) -o $@

$(TARGET_32): $(OBJS_32)
	$(CXX) $(CXXFLAGS_32) $(OBJS_32) $(LDFLAGS_DYNAMIC) $(LIBS) -o $@

$(OBJ_DIR_64)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS_64) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_64)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS_64) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_32)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS_32) $(INCLUDES) -c $< -o $@

$(OBJ_DIR_32)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS_32) $(INCLUDES) -c $< -o $@

# static make
static: static-64 static-32

docker-build-64:
	@docker build -t $(DOCKER_IMG_64) -f Dockerfile.x64 .

docker-build-32:
	@docker build -t $(DOCKER_IMG_32) -f Dockerfile.x86 .

static-64: docker-build-64
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_64) make $(TARGET)-intern-64

static-32: docker-build-32
	@docker run --rm -v "$(shell pwd)":/app $(DOCKER_IMG_32) make $(TARGET)-intern-32

.PHONY: $(TARGET)-intern-64 $(TARGET)-intern-32
$(TARGET)-intern-64: $(OBJ_DIR_64) $(OBJS_64)
	$(CXX) $(CXXFLAGS_64) $(OBJS_64) $(LDFLAGS_STATIC) -o $(TARGET_STATIC_64) `pkg-config --static --libs libcurl`

$(TARGET)-intern-32: $(OBJ_DIR_32) $(OBJS_32)
	$(CXX) $(CXXFLAGS_32) $(OBJS_32) $(LDFLAGS_STATIC) -o $(TARGET_STATIC_32) `pkg-config --static --libs libcurl`

# win cross comp
cross-windows: cross-windows-64 cross-windows-32

cross-windows-64: clean-cross-64 $(CROSS_OBJ_DIR_64) $(CROSS_TARGET_64)

cross-windows-32: clean-cross-32 $(CROSS_OBJ_DIR_32) $(CROSS_TARGET_32)

$(CROSS_TARGET_64): $(CROSS_OBJS_64)
	$(CROSS_CXX_64) $(LDFLAGS_CROSS_STATIC) $(CROSS_OBJS_64) `$(CROSS_TRIPLE_64)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` -o $@

$(CROSS_OBJ_DIR_64)/%.o: $(SRC_DIR)/%.c
	$(CROSS_CC_64) $(CROSS_CFLAGS_64) $(INCLUDES) -c $< -o $@

$(CROSS_OBJ_DIR_64)/%.o: $(SRC_DIR)/%.cpp
	$(CROSS_CXX_64) $(CROSS_CXXFLAGS_64) $(INCLUDES) -c $< -o $@

$(CROSS_TARGET_32): $(CROSS_OBJS_32)
	$(CROSS_CXX_32) $(LDFLAGS_CROSS_STATIC) $(CROSS_OBJS_32) `$(CROSS_TRIPLE_32)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` -o $@

$(CROSS_OBJ_DIR_32)/%.o: $(SRC_DIR)/%.c
	$(CROSS_CC_32) $(CROSS_CFLAGS_32) $(INCLUDES) -c $< -o $@

$(CROSS_OBJ_DIR_32)/%.o: $(SRC_DIR)/%.cpp
	$(CROSS_CXX_32) $(CROSS_CXXFLAGS_32) $(INCLUDES) -c $< -o $@

# cleanup
clean: clean-native clean-cross
	@rm -rf $(TARGET_64) $(TARGET_32) $(TARGET_STATIC_64) $(TARGET_STATIC_32)

clean-native:
	@rm -rf $(OBJ_DIR_64) $(OBJ_DIR_32)

clean-cross: clean-cross-64 clean-cross-32

clean-cross-64:
	@rm -rf $(CROSS_OBJ_DIR_64) $(CROSS_TARGET_64)

clean-cross-32:
	@rm -rf $(CROSS_OBJ_DIR_32) $(CROSS_TARGET_32)

all: clean dynamic static cross-windows