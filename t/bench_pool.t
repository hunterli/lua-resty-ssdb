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
        content_by_lua_block {
            local ssdb = require "resty.ssdbcp"
            local db = ssdb:new({host="$TEST_NGINX_SSDB_HOST", port=$TEST_NGINX_SSDB_PORT, timeout=1000, keep_alive=10000, pool_size=100})

            db:set("dog", "an animal")
            local d1 = db:get("dog")
            db:set("dog", "hello")
            local d2 = db:get("dog")

            ngx.say("d1: ", d1)
            ngx.say("d2: ", d2)

        }
    }
--- request
GET /t
--- response_body
d1: an animal
d2: hello
--- no_error_log
[error]

