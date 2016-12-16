# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_SSDB_HOST} ||= "127.0.0.1";
$ENV{TEST_NGINX_SSDB_PORT} ||= 8888;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: set and get
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:set("dog", "an animal")
            if not res then
                ngx.say("failed to set dog: ", err)
                return
            end

            ngx.say("set dog: ", res)

            for i = 1, 2 do
                local res, err = db:get("dog")
                if not res then
                    ngx.say("failed to get dog: ", err)
                    return
                end

                if res == ngx.null then
                    ngx.say("dog not found.")
                    return
                end

                ngx.say("dog: ", res)
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
set dog: 1
dog: an animal
dog: an animal
--- no_error_log
[error]



=== TEST 2: flushall
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:flushall()
            if not res then
                ngx.say("failed to flushall: ", err)
                return
            end
            ngx.say("flushall: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
failed to flushall: Unknown Command: flushall
--- no_error_log
[error]



=== TEST 3: get nil bulk value
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            for i = 1, 2 do
                res, err = db:get("not_found")
                if not res then
                    ngx.say("failed to get: ", err)
                    return
                end

                if res == ngx.null then
                    ngx.say("not_found not found.")
                    return
                end

                ngx.say("get not_found: ", res)
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
not_found not found.
--- no_error_log
[error]



=== TEST 5: incr and decr
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:set("connections", 10)
            if not res then
                ngx.say("failed to set connections: ", err)
                return
            end

            ngx.say("set connections: ", res)

            res, err = db:incr("connections")
            if not res then
                ngx.say("failed to set connections: ", err)
                return
            end

            ngx.say("incr connections: ", res)

            local res, err = db:get("connections")
            if not res then
                ngx.say("failed to get connections: ", err)
                return
            end

            res, err = db:incr("connections")
            if not res then
                ngx.say("failed to incr connections: ", err)
                return
            end

            ngx.say("incr connections: ", res)

            res, err = db:decr("connections")
            if not res then
                ngx.say("failed to decr connections: ", err)
                return
            end

            ngx.say("decr connections: ", res)

            res, err = db:get("connections")
            if not res then
                ngx.say("connections not found.")
                return
            end

            ngx.say("connections: ", res)

            res, err = db:del("connections")
            if not res then
                ngx.say("failed to del connections: ", err)
                return
            end

            ngx.say("del connections: ", res)

            res, err = db:incr("connections")
            if not res then
                ngx.say("failed to set connections: ", err)
                return
            end

            ngx.say("incr connections: ", res)

            res, err = db:get("connections")
            if not res then
                ngx.say("connections not found.")
                return
            end

            ngx.say("connections: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
set connections: 1
incr connections: 11
incr connections: 12
decr connections: 11
connections: 11
del connections: 1
incr connections: 1
connections: 1
--- no_error_log
[error]



=== TEST 6: incr with param
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

	    local res, err = db:del("connections")
	    if not res then
	        ngx.say("delete connections error: ", err)
		return
	    end

            local res, err = db:incr("connections", 12)
            if not res then
                ngx.say("failed to set connections: ", res, ": ", err)
                return
            end

            ngx.say("incr connections: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
incr connections: 12
--- no_error_log
[error]



=== TEST 10: set keepalive and get reused times
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local times = db:get_reused_times()
            ngx.say("reused times: ", times)

            local ok, err = db:set_keepalive()
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end

            ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            times = db:get_reused_times()
            ngx.say("reused times: ", times)

            local ok, err = db:set_keepalive()
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end

            ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            times = db:get_reused_times()
            ngx.say("reused times: ", times)

	    db:close()

            ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            times = db:get_reused_times()
            ngx.say("reused times: ", times)

	    db:close()

	    local ok, err = db:set_keepalive()
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end

            ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            times = db:get_reused_times()
            ngx.say("reused times: ", times)
        ';
    }
--- request
GET /t
--- response_body
reused times: 0
reused times: 1
reused times: 2
reused times: 0
failed to set keepalive: closed
--- no_error_log
[error]


=== TEST 11: mget
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:multi_del("dog", "cat")
            if not res then
                ngx.say("failed to del dog cat: ", err)
                return
            end

            local res, err = db:set("dog", "an animal")
            if not res then
                ngx.say("failed to set dog: ", err)
                return
            end

            ngx.say("set dog: ", res)

            for i = 1, 2 do
                local res, err = db:multi_get("dog", "cat", "dog")
                if not res then
                    ngx.say("failed to get dog: ", err)
                    return
                end

                if res == ngx.null then
                    ngx.say("dog not found.")
                    return
                end

                local cjson = require "cjson"
                ngx.say("res: ", cjson.encode(res))
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
set dog: 1
res: ["dog","an animal","dog","an animal"]
res: ["dog","an animal","dog","an animal"]
--- no_error_log
[error]



=== TEST 12: multi_hget array_to_hash
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ok, err = db:multi_hdel("animals", "dog", "cat", "cow")
            if not ok then
                ngx.say("failed to flush all: ", err)
                return
            end

            local res, err = db:multi_hset("animals", { dog = "bark", cat = "meow", cow = "moo" })
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end

            ngx.say("multi_hset animals: ", res)

            local res, err = db:multi_hget("animals", "dog", "cat", "cow")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_hget animals: ", res)

            local res, err = db:hgetall("animals")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            if not res then
                ngx.say("animals not found.")
                return
            end

            local h = db:array_to_hash(res)

            ngx.say("dog: ", h.dog)
            ngx.say("cat: ", h.cat)
            ngx.say("cow: ", h.cow)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
multi_hset animals: 3
multi_hget animals: dogbarkcatmeowcowmoo
dog: bark
cat: meow
cow: moo
--- no_error_log
[error]



=== TEST 13: boolean args
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ok, err = db:set("foo", true)
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            local res, err = db:get("foo")
            if not res then
                ngx.say("failed to get: ", err)
                return
            end

            ngx.say("foo: ", res, ", type: ", type(res))

            ok, err = db:set("foo", false)
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            local res, err = db:get("foo")
            if not res then
                ngx.say("failed to get: ", err)
                return
            end

            ngx.say("foo: ", res, ", type: ", type(res))

            ok, err = db:set("foo", nil)
            if not ok then
                ngx.say("failed to set: ", err)
            end

            local res, err = db:get("foo")
            if not res then
                ngx.say("failed to get: ", err)
                return
            end

            ngx.say("foo: ", res, ", type: ", type(res))

            local ok, err = db:set_keepalive(10, 10)
            if not ok then
                ngx.say("failed to set_keepalive: ", err)
            end
        ';
    }
--- request
GET /t
--- response_body
foo: true, type: string
foo: false, type: string
failed to set: wrong number of arguments
foo: false, type: string
--- no_error_log
[error]



=== TEST 14: set and get (key with underscores)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:set("a_dog", "an animal")
            if not res then
                ngx.say("failed to set a_dog: ", err)
                return
            end

            ngx.say("set a_dog: ", res)

            for i = 1, 2 do
                local res, err = db:get("a_dog")
                if not res then
                    ngx.say("failed to get a_dog: ", err)
                    return
                end

                if not res then
                    ngx.say("a_dog not found.")
                    return
                end

                ngx.say("a_dog: ", res)
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
set a_dog: 1
a_dog: an animal
a_dog: an animal
--- no_error_log
[error]
