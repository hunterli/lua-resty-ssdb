local ssdb = require("resty.ssdb")

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
	new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 104)

_M._VERSION = '0.1'

local mt = { __index = _M }


function _M.new(self, option)
	local client, err = ssdb:new()
	if not client then
		return nil, err
	end
	if not option then
		option = {}
	end
	local opt = {}
	opt.host = option.host or "127.0.0.1"
	opt.port = option.port or 8888
	opt.timeout = option.timeout or 2000
        opt.keep_alive = option.keep_alive or 10000
	opt.pool_size = option.pool_size or 10

	return setmetatable({_client=client, _option=opt}, mt)
end


local function _init(self, client)
        local option = rawget(self, "_option")

        client:set_timeout(option.timeout)

        local res, err = client:connect(option.host, option.port)
	if not res then
		return nil, err
	end
	--print("socket client:get_reused_times: ", client:get_reused_times())
	return res, nil
end


local function _deinit(self, client)
        local option = rawget(self, "_option")

        client:set_keepalive(option.keep_alive, option.pool_size)
end


function _M.init_pipeline(self, ...)
        local client = rawget(self, "_client")
        if not client then
                return nil, "not initialized"
        end

        self.is_pipeline = true

        return client:init_pipeline(...)
end


function _M.commit_pipeline(self, ...)
	local client = rawget(self, "_client")
	if not client then
		return nil, "not initialized"
	end

	self.is_pipeline = false

	local res, err = _init(self, client)
	if not res then
		return nil, err
	end

	local res, err = client:commit_pipeline(...)
	if not res then
		if err == "timeout" then
			client:close()
		end
		return nil, err
	end

	_deinit(self, client)

	return res, err
end


function _M.cancel_pipeline(self, ...)
	local client = rawget(self, "_client")
	if not client then
		return nil, "not initialized"
	end

	self.is_pipeline = false

	return client:cancel_pipeline(...)
end


local function wrap_cmd(self, cmd, ...)
	local client = rawget(self, "_client")
	if not client then
		return nil, "not initialized"
	end

	local method = client[cmd]
	if not method then
		return nil, "unknown cmd: "..cmd
	end

	if self.is_pipeline == true then
		return method(client, ...)
	end

	local res, err = _init(self, client)
	if not res then
		return nil, err
	end
	
	local res, err = method(client, ...)
	if not res then
		if err == "timeout" then
			client:close()
		end
		return nil, err
	end

	_deinit(self, client)

	return res, err
end

setmetatable(_M, {__index = function(self, cmd)
	local method = function (self, ...)
		return wrap_cmd(self, cmd, ...)
	end

	-- cache the lazily generated method in our
	-- module table
	_M[cmd] = method
	return method
end})


return _M
