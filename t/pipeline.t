# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_SSDB_HOST} ||= "127.0.0.1";
$ENV{TEST_NGINX_SSDB_PORT} ||= 8888;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: basic
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
                db:init_pipeline()

                db:set("dog", "an animal")
                db:get("dog")
                db:set("dog", "hello")
                db:get("dog")

                local results = db:commit_pipeline()
                local cjson = require "cjson"
                ngx.say(cjson.encode(results))
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
["1","an animal","1","hello"]
["1","an animal","1","hello"]
--- no_error_log
[error]



=== TEST 2: cancel automatically
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

            db:init_pipeline()

            db:set("dog", "an animal")
            db:get("dog")

            for i = 1, 2 do
                db:init_pipeline()

                db:set("dog", "an animal")
                db:get("dog")
                db:set("dog", "hello")
                db:get("dog")

                local results = db:commit_pipeline()
                local cjson = require "cjson"
                ngx.say(cjson.encode(results))
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
["1","an animal","1","hello"]
["1","an animal","1","hello"]
--- no_error_log
[error]



=== TEST 3: cancel explicitly
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

            db:init_pipeline()

            db:set("dog", "an animal")
            db:get("dog")

            db:cancel_pipeline()

            local res, err = db:del("dog")
            if not res then
                ngx.say("failed to flush all: ", err)
                return
            end

            ngx.say("flushall: ", res)

            for i = 1, 2 do
                db:init_pipeline()

                db:set("dog", "an animal")
                db:get("dog")
                db:set("dog", "hello")
                db:get("dog")

                local results = db:commit_pipeline()
                local cjson = require "cjson"
                ngx.say(cjson.encode(results))
            end

            db:close()
        ';
    }
--- request
GET /t
--- response_body
flushall: 1
["1","an animal","1","hello"]
["1","an animal","1","hello"]
--- no_error_log
[error]


=== TEST 4: mixed
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", 8888)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            res, err = db:set("dog", "an aniaml")
            if not res then
                ngx.say("failed to set dog: ", err)
                return
            end

            ngx.say("set result: ", res)

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

            db:init_pipeline()
            db:set("cat", "Marry")
            db:set("horse", "Bob")
            db:get("cat")
            db:get("horse")
            local results, err = db:commit_pipeline()
            if not results then
                ngx.say("failed to commit the pipelined requests: ", err)
                return
            end

            for i, res in ipairs(results) do
                if type(res) == "table" then
                    if res[1] == false then
                        ngx.say("failed to run command ", i, ": ", res[2])
                    else
                        ngx.say("cmd ", i, ": ", res)
                    end
                else
                    -- process the scalar value
                    ngx.say("cmd ", i, ": ", res)
                end
            end

            -- put it into the connection pool of size 100,
            -- with 0 idle timeout
            local ok, err = db:set_keepalive(0, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end

            -- or just close the connection right away:
            -- local ok, err = db:close()
            -- if not ok then
            --     ngx.say("failed to close: ", err)
            --     return
            -- end
        ';
    }
--- request
    GET /test
--- response_body
set result: 1
dog: an aniaml
cmd 1: 1
cmd 2: 1
cmd 3: Marry
cmd 4: Bob
--- no_error_log
[error]



=== TEST 5: ssdb return error in pipeline
--- http_config eval: $::HttpConfig
--- config
    location /test {
        content_by_lua_block {
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            db:set_timeout(1000) -- 1 sec

            local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", 8888)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:del("dog")
            if not res then
                ngx.say("failed to del dog: ", err)
                return
            end

            db:init_pipeline()
            db:hkeys("dog","","",10)
            db:set("dog", "an animal")
            db:hkeys("dog")
            db:get("dog")
            local results, err = db:commit_pipeline()
            if not results then
                ngx.say("failed to commit the pipelined requests: ", err)
                return
            end

            for i, res in ipairs(results) do
                if type(res) == "table" then
                    if not res[1] then
                        ngx.say("failed to run command ", i, ": ", res[2])
                    else
                        ngx.say("cmd ", i, ": ", res)
                    end
                else
                    -- process the scalar value
                    ngx.say("cmd ", i, ": ", res)
                end
            end

            -- put it into the connection pool of size 100,
            -- with 0 idle timeout
            local ok, err = db:set_keepalive(0, 100)
            if not ok then
                ngx.say("failed to set keepalive: ", err)
                return
            end
	}
    }
--- request
    GET /test
--- response_body
cmd 1: null
cmd 2: 1
failed to run command 3: wrong number of arguments
cmd 4: an animal
--- no_error_log
[error]


