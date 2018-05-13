# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

#no_diff();
#no_long_string();

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/lib/?.lua;$pwd/../lua-resty-core/lib/?.lua;;";
    #init_by_lua '
    #local v = require "jit.v"
    #v.on("$Test::Nginx::Util::ErrLogFile")
    #require "resty.core"
    #';

_EOC_

no_long_string();
run_tests();

__DATA__

=== TEST 1: no user flags by default
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(2)

            c:set("dog", 32)
            c:set("cat", 56)
            ngx.say("dog: ", c:get("dog"))
            ngx.say("cat: ", c:get("cat"))
        }
    }
--- request
    GET /t
--- response_body
dog: 32
cat: 56
--- no_error_log
[error]



=== TEST 2: stores user flags if specified
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(2)

            c:set("dog", 32, nil, 0x01)
            c:set("cat", 56, nil, 0x02)
            ngx.say("dog: ", c:get("dog"))
            ngx.say("cat: ", c:get("cat"))
        }
    }
--- request
    GET /t
--- response_body
dog: 32nil1
cat: 56nil2
--- no_error_log
[error]



=== TEST 3: user flags are uint32_t
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(3)

            c:set("dog", 32, nil, 4294967295)
            c:set("cat", 56, nil, 4294967296)
            c:set("bird", 78, nil, -1)
            ngx.say("dog: ", c:get("dog"))
            ngx.say("cat: ", c:get("cat"))
            ngx.say("bird: ", c:get("bird"))
        }
    }
--- request
    GET /t
--- response_body
dog: 32nil4294967295
cat: 56nil0
bird: 78nil4294967295
--- no_error_log
[error]



=== TEST 4: user flags not number is ignored
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(2)

            c:set("dog", 32, nil, "")
            ngx.say(c:get("dog"))
        }
    }
--- request
    GET /t
--- response_body
32
--- no_error_log
[error]



=== TEST 5: all nodes from double-ended queue have flags
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local len = 10

            local lrucache = require "resty.lrucache"
            local c = lrucache.new(len)

            for i = 1, len do
                c:set(i, 32, nil, 1)
            end

            for i = 1, len do
                local v, _, flags = c:get(i)
                if not flags then
                    ngx.say("item ", i, " does not have flags")
                    return
                end
            end

            ngx.say("ok")
        }
    }
--- request
    GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 6: user flags are preserved when item is stale
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(1)

            c:set("dogs", 32, 0.2, 3)
            ngx.sleep(0.21)

            ngx.say(c:get("dogs"))
        }
    }
--- request
    GET /t
--- response_body
nil323
--- no_error_log
[error]



=== TEST 7: user flags are not preserved upon eviction
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local lrucache = require "resty.lrucache"
            local c = lrucache.new(1)

            for i = 1, 10 do
                local flags = i % 2 == 0 and i
                c:set(i, true, nil, flags)
                ngx.say(c:get(i))
            end
        }
    }
--- request
    GET /t
--- response_body
true
truenil2
true
truenil4
true
truenil6
true
truenil8
true
truenil10
--- no_error_log
[error]
