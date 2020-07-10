#include <lua.hpp>
#include <src/tls_sig_api_v2.h>

static int
lgen_sig(lua_State *L) {
	uint32_t sdkappid = (uint32_t)luaL_checkinteger(L, 1);
	const char * identifier = luaL_checkstring(L, 2);
	const char * key = luaL_checkstring(L, 3);
	uint32_t expire = (uint32_t)luaL_checkinteger(L, 4);

    std::string identifier_str(identifier);
    std::string key_str(key);

    std::string sig;
    std::string errmsg;

    int ret = gen_sig(sdkappid, identifier_str, key_str, expire, sig, errmsg);

    lua_pushnumber(L, ret);
    lua_pushstring(L, sig.c_str());
    lua_pushstring(L, errmsg.c_str());
    return 3;
}

static int
lgen_sig_with_userbuf(lua_State *L) {
	uint32_t sdkappid = (uint32_t)luaL_checkinteger(L, 1);
	const char * identifier = luaL_checkstring(L, 2);
	const char * key = luaL_checkstring(L, 3);
	uint32_t expire = (uint32_t)luaL_checkinteger(L, 4);
	const char * userbuf = luaL_checkstring(L, 5);

    std::string identifier_str(identifier);
    std::string key_str(key);
    std::string userbuf_str(userbuf);

    std::string sig;
    std::string errmsg;

    int ret = gen_sig_with_userbuf(sdkappid, identifier_str, key_str, expire, userbuf, sig, errmsg);

    lua_pushnumber(L, ret);
    lua_pushstring(L, sig.c_str());
    lua_pushstring(L, errmsg.c_str());
    return 3;
}

extern "C" {
LUAMOD_API int
luaopen_tencentyun(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "gen_sig", lgen_sig },
        { "gen_sig_with_userbuf", lgen_sig_with_userbuf },
        { NULL,  NULL },
    };

    luaL_newlib(L,l);
    return 1;
}
}
