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

$(LUA_CLIB_PATH)/skiplist.so : 3rd/lua-zset/skiplist.h 3rd/lua-zset/skiplist.c 3rd/lua-zset/lua-skiplist.c | $(LUA_CLIB_PATH)
	$(CC)  $(CFLAGS)  -I$(LUA_INC) $(SHARED)  $^ -o $@
	cp 3rd/lua-zset/zset.lua lualib/zset.lua

$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@

$(LUA_CLIB_PATH)/agora.so : lualib-src/lua-agora.cpp | $(LUA_CLIB_PATH)
	g++ -std=c++0x $(CFLAGS) $(SHARED) -I3rd/agora/DynamicKey/AgoraDynamicKey $^ -o $@ -lz -lcrypto

TENCENTYUN_FLAG = -DFMT_HEADER_ONLY -DRAPIDJSON_HAS_STDSTRING=1 -DUSE_OPENSSL
$(LUA_CLIB_PATH)/tencentyun.so : lualib-src/lua-tencentyun.cpp 3rd/tls-sig-api-v2/src/tls_sig_api_v2.cpp | $(LUA_CLIB_PATH)
	g++ -std=c++0x $(CFLAGS) $(SHARED) $(TENCENTYUN_FLAG) -I3rd/tls-sig-api-v2 -I3rd/tls-sig-api-v2/src -I3rd/tls-sig-api-v2/third/fmt/include -I3rd/tls-sig-api-v2/third/rapidjson/include $^ -o $@ -lz -lcrypto

$(LUA_CLIB_PATH)/snapshot.so : 3rd/lua-snapshot/snapshot.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@
	cp 3rd/lua-snapshot/snapshot_utils.lua lualib/snapshot_utils.lua

LUA_CLIB = skiplist cjson agora tencentyun snapshot

build: \
  $(LUA_CLIB_PATH) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	cd skynet && $(MAKE) linux TLS_MODULE=ltls

schema:
	cd 3rd/lua-dirty-mongo/tools && make LUA_INC=$(LUA_INC)
	./skynet/3rd/lua/lua 3rd/lua-dirty-mongo/tools/gen_schema.lua proto/db.proto lualib/schema.lua

clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall

