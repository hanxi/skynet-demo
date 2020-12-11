all : help

help:
	@echo "支持下面命令:"
	@echo "make build       # 编译 skynet"
	@echo "make clean       # 清理"
	@echo "make cleanall    # 清理所有"

LUA_CLIB_PATH ?= luaclib
LUA_INC ?= skynet/3rd/lua
CFLAGS = -g -O0 -Wall -I$(LUA_INC)
SHARED := -fPIC --shared

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/skiplist.so : 3rd/lua-zset/skiplist.h 3rd/lua-zset/skiplist.c 3rd/lua-zset/lua-skiplist.c
	$(CC)  $(CFLAGS)  -I$(LUA_INC) $(SHARED)  $^ -o $@
	cp 3rd/lua-zset/zset.lua lualib/zset.lua

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet/skynet-src $^ -o $@

LUA_CLIB = skiplist bson

build: \
  $(LUA_CLIB_PATH) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	cd skynet && $(MAKE) linux TLS_MODULE=ltls

clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall

