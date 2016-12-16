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

=== TEST 1: multi_set key-pairs
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

            local res, err = db:multi_del("dog", "cat", "cow")
            if not res then
                ngx.say("failed to del animals: ", err)
                return
            end

            local res, err = db:multi_set("dog", "bark", "cat", "meow")
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end
            ngx.say("multi_set: ", res)

            local res, err = db:multi_get("dog", "cat")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_get: ", res)
	    res = db:array_to_hash(res)
	    ngx.say("multi_get dog: ", res.dog)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
multi_set: 2
multi_get: dogbarkcatmeow
multi_get dog: bark
--- no_error_log
[error]


=== TEST 2: multi_set lua tables
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

            local res, err = db:multi_del("dog", "cat", "cow")
            if not res then
                ngx.say("failed to del animals: ", err)
                return
            end

            local t = { dog = "bark", cat = "meow", cow = "moo" }
            local res, err = db:multi_set(t)
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end
            ngx.say("multi_set: ", res)

            local res, err = db:multi_get("dog", "cat", "cow")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_get: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
multi_set: 3
multi_get: dogbarkcatmeowcowmoo
--- no_error_log
[error]


=== TEST 3: multi_set a single scalar
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

            local res, err = db:multi_del("dog", "cat", "cow")
            if not res then
                ngx.say("failed to del animals: ", err)
                return
            end

            local res, err = db:multi_set("cat")
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end
            ngx.say("multi_set: ", res)

            local res, err = db:multi_get("cat")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_get: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- error_log
table expected, got string

