# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/lib/?.lua;$pwd/../lua-resty-core/lib/?.lua;;";
    #init_by_lua_block {
    #local v = require "jit.v"
    #v.on("$Test::Nginx::Util::ErrLogFile")
    #require "resty.core"
    #};

_EOC_

no_long_string();
run_tests();

__DATA__

=== TEST 1: flush_all() deletes all keys
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(100)

            local N = 3

            for i = 1, N do
                c:set("key " .. i, true)
            end

            c:flush_all()

            for i = 1, N do
                local key = "key " .. i
                local v = c:get(key)
                ngx.say(key, ": ", v)
            end
        }
    }
--- request
    GET /t
--- response_body
key 1: nil
key 2: nil
key 3: nil

--- no_error_log
[error]



=== TEST 2: flush_all() deletes all keys [pureffi]
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache.pureffi"
            local c = lrucache.new(100)

            local N = 3

            for i = 1, N do
                c:set("key " .. i, true)
            end

            c:flush_all()

            for i = 1, N do
                local key = "key " .. i
                local v = c:get(key)
                ngx.say(key, ": ", v)
            end
        }
    }
--- request
    GET /t
--- response_body
key 1: nil
key 2: nil
key 3: nil

--- no_error_log
[error]
