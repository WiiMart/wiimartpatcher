CC := gcc
CXX := g++

TARGET := WiiMartPatcher

# Flags
CFLAGS := -Wall -g -std=c11
CXXFLAGS := -Wall -g -std=c++17

LDFLAGS_DYNAMIC :=
LDFLAGS_STATIC := -static
LDFLAGS_CROSS_STATIC := -static -static-libgcc -static-libstdc++

CROSS_CFLAGS := $(CFLAGS) -DCURL_STATICLIB
CROSS_CXXFLAGS := $(CXXFLAGS) -DCURL_STATICLIB

LIBS := -lcurl -lssh2 -lpsl -lssl -lcrypto -lgssapi_krb5 -lldap -llber -lbrotlidec -lpthread -lrt -lidn2 -lunistring -lz -lnghttp2 -ldl

# Win Cross Compile Defs
CROSS_TRIPLE := x86_64-w64-mingw32
CROSS_CC := $(CROSS_TRIPLE)-gcc
CROSS_CXX := $(CROSS_TRIPLE)-g++
CROSS_TARGET := $(TARGET).exe

# Dir Placements
SRC_DIR := src
INC_DIR := ./include
OBJ_DIR := obj
CROSS_OBJ_DIR := obj_win

SRCS := $(wildcard $(SRC_DIR)/*.c $(SRC_DIR)/*.cpp)

# Native Obj
OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(filter %.c,$(SRCS)))
OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(filter %.cpp,$(SRCS)))

# Windows Obj
CROSS_OBJS := $(patsubst $(SRC_DIR)/%.c,$(CROSS_OBJ_DIR)/%.o,$(filter %.c,$(SRCS)))
CROSS_OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(CROSS_OBJ_DIR)/%.o,$(filter %.cpp,$(SRCS)))

INCLUDES := -I$(INC_DIR)

DOCKER_IMG := wiimartpatcher_alpine_builder

.PHONY: all clean dynamic static cross-windows docker_build_img build_static_dock

all: clean dynamic

# Dir Create
$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

$(CROSS_OBJ_DIR):
	@mkdir -p $(CROSS_OBJ_DIR)


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

cross-windows: clean-cross $(CROSS_OBJ_DIR) $(CROSS_TARGET)

 $(CROSS_TARGET): $(CROSS_OBJS)
	$(CROSS_CXX) $(LDFLAGS_CROSS_STATIC) $(CROSS_OBJS) `$(CROSS_TRIPLE)-pkg-config --static --libs libcurl | sed 's/-R[^ ]*//g'` -o $@

$(CROSS_OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CROSS_CC) $(CROSS_CFLAGS) $(INCLUDES) -c $< -o $@

$(CROSS_OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CROSS_CXX) $(CROSS_CXXFLAGS) $(INCLUDES) -c $< -o $@


# Cleanup

clean: clean-native clean-cross
	@rm -rf $(TARGET) $(TARGET)-static

clean-native:
	@rm -rf $(OBJ_DIR)

clean-cross:
	@rm -rf $(CROSS_OBJ_DIR) $(CROSS_TARGET)

doall: clean dynamic static cross-windows
