# skynet-demo

### websocket watchdog gate agent

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

算法类似美团的 Leaf-segment 的数据库方案

测试命令：

```
./skynet/skynet etc/config.test
```

