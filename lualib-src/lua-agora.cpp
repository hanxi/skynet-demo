#include <lua.hpp>
#include "cpp/src/RtcTokenBuilder.h"

using namespace agora::tools;

static int
lbuild_token_with_uid(lua_State *L) {
	const char * app_id = luaL_checkstring(L, 1);
	const char * app_certificate = luaL_checkstring(L, 2);
	const char * channel_name = luaL_checkstring(L, 3);
	uint32_t uid = (uint32_t)luaL_checkinteger(L, 4);
	uint32_t expired_ts = (uint32_t)luaL_checkinteger(L, 5);

    std::string app_id_str(app_id);
    std::string app_certificate_str(app_certificate);
    std::string channel_name_str(channel_name);

    std::string result = RtcTokenBuilder::buildTokenWithUid(
            app_id_str,
            app_certificate_str,
            channel_name_str,
            uid,
            UserRole::Role_Publisher,
            expired_ts);

    lua_pushstring(L, result.c_str());
    return 1;
}

static int
lbuild_token_with_user_account(lua_State *L) {
	const char * app_id = luaL_checkstring(L, 1);
	const char * app_certificate = luaL_checkstring(L, 2);
	const char * channel_name = luaL_checkstring(L, 3);
	const char * user_account = luaL_checkstring(L, 4);
	uint32_t expired_ts = (uint32_t)luaL_checkinteger(L, 5);

    std::string app_id_str(app_id);
    std::string app_certificate_str(app_certificate);
    std::string channel_name_str(channel_name);
    std::string user_account_str(user_account);

    std::string result = RtcTokenBuilder::buildTokenWithUserAccount(
            app_id_str,
            app_certificate_str,
            channel_name_str,
            user_account_str,
            UserRole::Role_Publisher,
            expired_ts);

    lua_pushstring(L, result.c_str());
    return 1;
}

extern "C" {
LUAMOD_API int
luaopen_agora(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "build_token_with_uid", lbuild_token_with_uid },
        { "build_token_with_user_account", lbuild_token_with_user_account },
        { NULL,  NULL },
    };

    luaL_newlib(L,l);
    return 1;
}
}
