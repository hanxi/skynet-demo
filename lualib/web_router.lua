return function (r)
    r:get('/hw', function(params)
        return 'someone said hello'
    end)
    r:get('/', function(params)
        return 'index.html'
    end)
end

