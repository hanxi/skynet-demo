local staticfile = require "staticfile"

return function (r)
    r:get('/hw', function(params)
        return 'someone said hello'
    end)
    r:get('/', function(params)
        local content = staticfile["index.html"]
        if content then
            return content
        end
        return "404 Not found", 404
    end)
    r:get('/static/:filename', function(params)
        print("static")
        for k,v in pairs(params) do
            print(type(k),#k,k,v)
        end
        local content = staticfile[params.filename]
        if content then
            return content
        end
        return "404 Not found", 404
    end)
end

