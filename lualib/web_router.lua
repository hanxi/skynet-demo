return function (r)
    r:get('/hw', function(params)
        return 'someone said hello'
    end)
    r:get('/', function(params)
        return 'index.html'
    end)
    r:get('/static/:filename', function(params)
        local content = staticfile[filename]
        if content then
            return content
        end
        return "404 Not found", 404
    end)
end

