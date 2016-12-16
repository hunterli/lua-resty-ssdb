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

=== TEST 1: test command: list_allow_ip
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local ssdb = require "resty.ssdb"
	    local db = ssdb:new()
	    
	    db:set_timeout(1000)

	    local ok, err = db:connect("$TEST_NGINX_SSDB_HOST", $TEST_NGINX_SSDB_PORT)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = db:list_allow_ip()
            if not res then
                ngx.say("list allow ip error: ", err)
                return
            end
	
            ngx.say("list allow ip result: ", res)
        }
    }
--- request
GET /t
--- response_body
list allow ip error: Unknown Command: list_allow_ip
--- no_error_log
[error]

