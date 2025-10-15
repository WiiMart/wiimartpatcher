CC := gcc
CXX := g++

TARGET := WiiMartPatcher

CFLAGS := -Wall -g -std=c11
CXXFLAGS := -Wall -g -std=c++17

LDFLAGS_DYNAMIC :=
LDFLAGS_STATIC := -static

LIBS := -lcurl -lssh2 -lpsl -lssl -lcrypto -lgssapi_krb5 -lldap -llber -lbrotlidec -lpthread -lrt -lidn2 -lunistring -lz -lnghttp2 -ldl

SRC_DIR := src
INC_DIR := ./include
OBJ_DIR := obj

SRCS := $(wildcard $(SRC_DIR)/*.c $(SRC_DIR)/*.cpp)

OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(filter %.c,$(SRCS)))
OBJS += $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(filter %.cpp,$(SRCS)))

INCLUDES := -I$(INC_DIR)

DOCKER_IMG := wiimartpatcher_alpine_builder

.PHONY: all clean dynamic static docker_build_img build_static_dock

all: clean dynamic

$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

dynamic: $(OBJ_DIR) $(TARGET)

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

$(TARGET): $(OBJS)
	$(CXX) $(OBJS) $(LDFLAGS_DYNAMIC) $(LIBS) -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	@rm -rf $(OBJ_DIR) $(TARGET) $(TARGET)-static
doall: clean dynamic static