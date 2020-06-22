local staticfile = require "staticfile"

return function (r)
    r:get('/hw', function(params)
        return 'someone said hello'
    end)
    r:get('/', function(params)
        return 'index.html'
    end)
    r:get('/static/:fname.:suffix', function(params)
        print("static")
        for k,v in pairs(params) do
            print(type(k),#k,k,v)
        end
        local filename = string.format("%s.%s", params.fname, params.suffix)
        local content = staticfile[filename]
        if content then
            return content
        end
        return "404 Not found", 404
    end)
end

