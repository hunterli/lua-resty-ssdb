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

=== TEST 1: continue using the obj when read timeout happens
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            local ok, err = db:connect("127.0.0.1", 1921);
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            db:set_timeout(100) -- 0.1 sec

            for i = 1, 2 do
                local data, err = db:get("foo")
                if not data then
                    ngx.say("failed to get: ", err)
                else
                    ngx.say("get: ", data);
                end
                ngx.sleep(0.1)
            end

            db:close()
        ';
    }
--- request
GET /t
--- tcp_listen: 1921
--- tcp_query eval
"3
get
3
foo

"
--- tcp_reply eval
"2
ok
5
hello

"
--- tcp_reply_delay: 150ms
--- response_body
failed to get: timeout
failed to get: closed

=== TEST 2: continue using the obj when read timeout happens
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            local db = ssdb:new()

            local ok, err = db:connect("127.0.0.1", 1921);
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

                local data, err = db:get("foo")
                if not data then
                    ngx.say("failed to get: ", err)
                else
                    ngx.say("get: ", data);
                end

            db:close()
        ';
    }
--- request
GET /t
--- tcp_listen: 1921
--- tcp_query eval
"3
get
3
foo

"
--- tcp_reply eval
"2
ok
6
hello1

"
--- response_body
get: hello1
--- error_log

