# skynet-demo

## 编译

```
sudo apt-get install -y autoconf libssl-dev
git submodule update --init --recursive
make build
```

## websocket watchdog gate agent

fork from https://github.com/xzhovo/skynet-websocket-gate

编译 skynet:

```
git submodule update --init
cd skynet
make linux
```

启动命令：

```
./skynet/skynet etc/config.cfg
```

默认是 `ws` 协议，如果要改成 `wss` 协议，采用下面指令编译

```
make linux TLS_MODULE=tls
```

生成 `wss` 所需的密钥

```lua
-- gen cert and key
-- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
```

修改 `service/main.lua` 里的 `protocol`

```lua
local protocol = "wss"
```


方案跟 [xzhovo/skynet-websocket-gate](https://github.com/xzhovo/skynet-websocket-gate) 有点不同，为了支持 `wss`, 采用了转发的模式推送数据给客户端

往 `gate` 发送 `response` 数据后， `gate` 会转发给客户端。

```lua
skynet.send(gate, "lua", "response", fd, msg)
```

[xzhovo/skynet-websocket-gate](https://github.com/xzhovo/skynet-websocket-gate) 的方案有个隐患， `agent` 引用了 `websocket.lua`, 需要维护好 `ws_pool` 。


根据 [mikewu86](https://github.com/mikewu86) 的提议 [issues#1](https://github.com/hanxi/skynet-demo/issues/1) ，已经将 ws_gate 扩展为 master/slave 模式。

## guid 模块

~~算法类似美团的 Leaf-segment 的数据库方案~~

已删除，请采用下面的雪花算法。

## bson 支持整数 key， MongoDB 支持保存整数 key

已删除。

## 集成 zset 模块

`lualib/zset.lua`


## 集成声网 SDK

- 声网 SDK 代码 `3rd/agora` : <https://github.com/AgoraIO/Tools>
- lua 库代码 `lualib-src/lua-agora.cpp`

## 集成腾讯云 SDK

- 腾讯云 SDK 代码 `3rd/tls-sig-api-v2` : <https://github.com/tencentyun/tls-sig-api-v2-cpp>
- lua 库代码 `lualib-src/lua-tencentyun.cpp`
- 如果编译报错找不到 fmt 库，可以使用 `git submodule update --init --recursive` 命令更新相关库

测试 SDK 使用下面的指令启动 skynet:

```bash
./skynet/skynet etc/config.test-sdk
```

## 集成 lua-cjson

使用 lua 测试：

```bash
./skynet/3rd/lua/lua test/test-cjson.lua
```

skynet 中直接用这个测试服务就行：

```bash
./skynet/skynet etc/config.test
```

## 雪花算法生成唯一 ID

测试命令

```bash
./skynet/skynet etc/config.test-snowflake
```

- 4096 个服务
- 单个服务 10 毫秒内可以生成 4096 个 ID
- 支持时间跨服 174 年
- 时间回拨检查

## QQ api 接口

主要测试 http 的 get 和 post 如何使用，代码位置： `lualib/qqapi.lua`

目前就接了屏蔽字的接口： <https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/sec-check/security.msgSecCheck.html>

测试命令：

```bash
./skynet/skynet etc/config.test-qqapi
```

如果是 https 接口，需要在配置中开启 ssl:

```lua
enablessl = true
```

当然，编译 skynet 时也需要把 tls 编译进去：

```
cd skynet && make linux TLS_MODULE=ltls
```

## 策划导表配置热更

- 使用 [ShareTable](https://github.com/cloudwu/skynet/wiki/ShareData#sharetable) 实现
- 参考这个讨论 [discussions/1429](https://github.com/cloudwu/skynet/discussions/1429)
- 代码位置: `lualib/staticdata.lua`

测试命令：

```bash
./skynet/skynet etc/config.teststaticdata
```

然后在 30 秒内修改 `data/test/data1.lua` 和 `data/test/data2.lua` 文件内容。

方案采用的是只使用 `sharetable.query` 接口更新本地引用，所以使用配置的地方都不能缓存配置数据，使用数据都需要从 root 取。

目前的方案只实现了手动调用 `staticdata.update(arrlist)` 接口实现热更配置。 可以优化成自动定时检测某个文件的时间，文件内容就是待热更的配置文件列表，以后有空再补上吧。

## QQ 群

群号 677839887
