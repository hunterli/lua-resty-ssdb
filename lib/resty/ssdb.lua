local tcp = ngx.socket.tcp
local null = ngx.null
local type = type
local pairs = pairs
local unpack = unpack
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local rawget = rawget
local remove = table.remove
--local error = error


local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end


local _M = new_tab(0, 104)

_M._VERSION = '0.26'


local ssdb_cmds = {
    --Server
    "auth", "dbsize", --[[ "flushdb",]]
    "info",
    --IP Filter
    "list_allow_ip", "add_allow_ip", "del_allow_ip",
    "list_deny_ip", "add_deny_ip", "del_deny_ip",
    --Key Value
    "set", "setx", "setnx",
    "expire", "ttl", "get",
    "getset", "del", "incr",
    "exists", "getbit", "setbit",
    "bitcount", "countbit", "substr",
    "strlen", "keys", "rkeys",
    "scan", "rscan", --[["multi_set",]]
    "multi_get", "multi_del",
    --Hashmap
    "hset", "hget", "hdel",
    "hincr", "hexists", "hsize",
    "hlist", "hrlist", "hkeys",
    "hgetall", "hscan", "hrscan",
    "hclear", --[["multi_hset",]] "multi_hget",
    "multi_hdel",
    --Sorted Set
    "zset", "zget", "zdel",
    "zincr", "zexists", "zsize",
    "zlist", "zrlist", "zkeys",
    "zscan", "zrscan", "zrank",
    "zrrank", "zrange", "zrrange",
    "zclear", "zcount", "zsum",
    "zavg", "zremrangebyrank", "zremrangebyscore",
    "zpop_front", "zpop_back", --[["multi_zset",]]
    "multi_zget", "multi_zdel",
    --List
    "qpush_front", "qpush_back", "qpop_front",
    "qpop_back", "qpush", "qpop",
    "qfront", "qback", "qsize",
    "qclear", "qget", "qset",
    "qrange", "qslice", "qtrim_front",
    "qtrim_back", "qlist", "qrlist"
}


local mt = { __index = _M }


function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ _sock = sock }, mt)
end


function _M.set_timeout(self, timeout)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end


function _M.connect(self, ...)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:connect(...)
end


function _M.set_keepalive(self, ...)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end


function _M.get_reused_times(self)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:getreusedtimes()
end


local function close(self)
    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    return sock:close()
end
_M.close = close


local function _read_reply(self, sock)
    local ret = {}
    local idx = 1

    while true do
        local line, err = sock:receive()
        if not line then
            if err == "timeout" then
                sock:close()
            end
            return nil, err
        end
        if line == '' then
            --print("_read_reply empty line, packet over")
            break
        end

        local size = tonumber(line)
        --print("_read_replay size: ", size)
        if not size or size < 0 then
                return null
        end
    
        local data, err = sock:receive(size)
        if not data then
            if err == "timeout" then
                sock:close()
            end
            return nil, err
        end
        --print("_read_replay data: ", data)
        ret[idx] = data
        idx = idx + 1

        local dummy, err = sock:receive()
        if not dummy then
            if err == "timeout" then
                 sock:close()
            end
            return nil, err
        end
    end

    local status = ret[1]
    remove(ret, 1)

    local n = #ret
    if status == 'ok' then
        if n == 1 then
            return ret[1], nil
        elseif n ~= 0 then
            return ret, nil
        else
            return null, nil
        end
    elseif status == 'not_found' then
        return null, nil
    else
        return nil, ret
    end
end


local function _gen_req(args)
    local nargs = #args

    local req = new_tab(nargs * 4 + 1, 0)
    local nbits = 1

    for i = 1, nargs do
        local arg = args[i]
        if type(arg) ~= "string" then
            arg = tostring(arg)
        end

        req[nbits] = #arg
        req[nbits + 1] = "\n"
        req[nbits + 2] = arg
        req[nbits + 3] = "\n"

        nbits = nbits + 4
    end

    req[#req + 1] = "\n"

    -- it is much faster to do string concatenation on the C land
    -- in real world (large number of strings in the Lua VM)
    return req
end


local function _do_cmd(self, ...)
    local args = {...}

    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    local req = _gen_req(args)

    local reqs = rawget(self, "_reqs")
    if reqs then
        reqs[#reqs + 1] = req
        return
    end

    --print("request: ", table.concat(req))

    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end

    return _read_reply(self, sock)
end


for i = 1, #ssdb_cmds do
    local cmd = ssdb_cmds[i]

    _M[cmd] =
        function (self, ...)
            return _do_cmd(self, cmd, ...)
        end
end


local function _table_to_array(self, t)
    local n = 0
    for k, v in pairs(t) do
        n = n + 2
    end
    
    local array = new_tab(n, 0)
    
    local i = 0
    for k, v in pairs(t) do
        array[i + 1] = k
        array[i + 2] = v
        i = i + 2
    end
    
    return array
end


function _M.multi_set(self, ...)
    if select('#', ...) == 1 then
        local t = select(1, ...)

        local array = _table_to_array(self, t)

        return _do_cmd(self, "multi_set", unpack(array))
    end

    -- backwards compatibility
    return _do_cmd(self, "multi_set", ...)
end


function _M.multi_hset(self, hashname, ...)
    if select('#', ...) == 1 then
        local t = select(1, ...)

        local array = _table_to_array(self, t)

        return _do_cmd(self, "multi_hset", hashname, unpack(array))
    end

    -- backwards compatibility
    return _do_cmd(self, "multi_hset", hashname, ...)
end


function _M.multi_zset(self, hashname, ...)
    if select('#', ...) == 1 then
        local t = select(1, ...)
    
        local array = _table_to_array(self, t)

        return _do_cmd(self, "multi_zset", hashname, unpack(array))
    end
    
    -- backwards compatibility
    return _do_cmd(self, "multi_zset", hashname, ...)
end


function _M.init_pipeline(self, n)
    self._reqs = new_tab(n or 4, 0)
end


function _M.cancel_pipeline(self)
    self._reqs = nil
end


function _M.commit_pipeline(self)
    local reqs = rawget(self, "_reqs")
    if not reqs then
        return nil, "no pipeline"
    end

    self._reqs = nil

    local sock = rawget(self, "_sock")
    if not sock then
        return nil, "not initialized"
    end

    local bytes, err = sock:send(reqs)
    if not bytes then
        return nil, err
    end

    local nvals = 0
    local nreqs = #reqs
    local vals = new_tab(nreqs, 0)
    for i = 1, nreqs do
        local res, err = _read_reply(self, sock)
        if res then
            nvals = nvals + 1
            vals[nvals] = res

        else
            if err == "timeout" then
                close(self)
                return nil, err
            end
            -- be a valid ssdb error value
            nvals = nvals + 1
            vals[nvals] = {nil, err}
        end
    end

    return vals
end


function _M.array_to_hash(self, t)
    local n = #t
    local h = new_tab(0, n / 2)
    for i = 1, n, 2 do
        h[t[i]] = t[i + 1]
    end
    return h
end


setmetatable(_M, {__index = function(self, cmd)
    local method =
        function (self, ...)
            return _do_cmd(self, cmd, ...)
        end

    -- cache the lazily generated method in our
    -- module table
    _M[cmd] = method
    return method
end})


return _M
