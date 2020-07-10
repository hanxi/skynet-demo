local skynet = require "skynet"
local agora = require "agora"
local tencentyun = require "tencentyun"

skynet.start(function()

    -- 腾讯IM配置
    local im_sdkappid = 1400427955
    local im_key = "4e1876a738a586914ba9302ef8460bad24c898533c6f558e31cade0f60ec08c4"
    local im_expire = 180*86400
    local uid = "123456"
    local ok,imsig,errmsg = tencentyun.gen_sig(im_sdkappid, uid, im_key, im_expire)
    if not ok then
        skynet.error("imsig failed. uid:", uid, ",errmsg:", errmsg)
    end
    skynet.error("test tencentyun ok. imsig:", imsig)

    local now = math.floor(skynet.time())

    -- 声网配置
    local agora_app_id = "c079635118154c9aad3a5e696423b5ca"
    local agora_app_certificate = "9333a1e121c840fea4bee2d433d10066"
    local rtcchannel = "channel"
    uid = 123456
    local rtctoken = agora.build_token_with_uid(agora_app_id, agora_app_certificate, rtcchannel, uid, now + 86400)
    skynet.error("test agora ok. rtctoken:", rtctoken)
end)
