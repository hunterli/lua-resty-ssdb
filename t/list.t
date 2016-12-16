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

=== TEST 1: test command: qpush_front
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

            local res, err = db:qpush_front("lht")
            if not res then
                ngx.say("qpush_front error: ", err)
                return
            end
	
            ngx.say("qpush_front result: ", res)
        }
    }
--- request
GET /t
--- response_body
qpush_front error: wrong number of arguments
--- no_error_log
[error]

=== TEST 2: test command: qpush_front
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
           
            local res, err = db:qclear('lht')
            if not res then
                ngx.say("qclear error: ", err)
                return
            end
           
            for i = 1, 2 do
                local res, err = db:qpush_front("lht", "item1")
                if not res then
                    ngx.say("qpush_front error: ", err)
                    return
                end
                ngx.say("qpush_front result: ", res)
            end
           
        }  
    }      
--- request
GET /t     
--- response_body
qpush_front result: 1
qpush_front result: 2
--- no_error_log
[error]


