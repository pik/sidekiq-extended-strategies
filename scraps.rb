def lock_with_debounce
  <<-LUA
    local ret = redis.call('GET', KEYS[1])
    if not ret then
      redis.call('SETEX', KEYS[1], ARGV[1], 1)
      return 1
    else
      ret = math.abs(ret) + 1
      redis.call('SETEX', KEYS[1], ARGV[1], ret)
      return ret
    end
  LUA
end
