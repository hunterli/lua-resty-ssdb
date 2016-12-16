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

=== TEST 1: module size of resty.ssdb
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua '
            local ssdb = require "resty.ssdb"
            n = 0
            for k, _ in pairs(ssdb) do
                n = n + 1
            end
            ngx.say("size: ", n)
        ';
    }
--- request
GET /t
--- response_body
size: 103
--- no_error_log
[error]

