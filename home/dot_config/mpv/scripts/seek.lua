local timer = mp.add_timeout(1, function() mp.command('script-message osc-visibility auto ""') end, true)
mp.register_event('seek',
    function()
        mp.command('script-message osc-visibility always ""')
        timer:kill()
        timer:resume()
    end)
