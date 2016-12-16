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

=== TEST 1: multi_hset key-pairs
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

            local res, err = db:multi_hdel("animals", "dog", "cat", "cow")
            if not res then
                ngx.say("failed to zdel animals: ", err)
                return
            end

            local res, err = db:multi_hset("animals", "dog", "bark", "cat", "meow")
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end
            ngx.say("multi_hset animals: ", res)

            local res, err = db:multi_hget("animals", "dog", "cat")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_hget animals: ", res)
	    res = db:array_to_hash(res)
	    ngx.say("multi_hget dog: ", res.dog)

            db:close()
        ';
    }
--- request
GET /t
--- response_body
multi_hset animals: 2
multi_hget animals: dogbarkcatmeow
multi_hget dog: bark
--- no_error_log
[error]


=== TEST 2: multi_hset lua tables
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

            local res, err = db:multi_hdel("animals", "dog", "cat", "cow")
            if not res then
                ngx.say("failed to zdel animals: ", err)
                return
            end

            local t = { dog = "bark", cat = "meow", cow = "moo" }
            local res, err = db:multi_hset("animals", t)
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

            db:close()
        ';
    }
--- request
GET /t
--- response_body
multi_hset animals: 3
multi_hget animals: dogbarkcatmeowcowmoo
--- no_error_log
[error]



=== TEST 3: multi_hset a single scalar
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

            local res, err = db:multi_hdel("animals", "dog", "cat", "cow")
            if not res then
                ngx.say("failed to zdel animals: ", err)
                return
            end

            local res, err = db:multi_hset("animals", "cat")
            if not res then
                ngx.say("failed to set animals: ", err)
                return
            end
            ngx.say("multi_hset animals: ", res)

            local res, err = db:multi_hget("animals", "cat")
            if not res then
                ngx.say("failed to get animals: ", err)
                return
            end

            ngx.say("multi_hget animals: ", res)

            db:close()
        ';
    }
--- request
GET /t
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- error_log
table expected, got string

