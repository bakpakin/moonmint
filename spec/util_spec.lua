local util = require "../src/util"

local function testEncodeGen(name, encode, decode)
    return function(data, encoded_form)
        local encoded_data = encode(data)
        if encoded_form then
            assert.are.equal(encoded_data, encoded_form)
        end
        assert.are.same(data, decode(encoded_data))
    end
end

local testQuery = testEncodeGen("Test Query", util.queryEncode, util.queryDecode)
local testURL = testEncodeGen("Test URL", util.urlEncode, util.urlDecode)
local testJSON = testEncodeGen("Test JSON", util.jsonEncode, util.jsonDecode)
local testCookie = testEncodeGen("Test Cookie", util.cookieEncode, util.cookieDecode)

describe("util", function()

    describe("Url encoding/decoding", function()

        it("Does basic encoding/decoding of simple strings", function()
            testURL("abcdefg")
            testURL("1233456")
        end)

        it("Encodes/decodes url special characters", function()
            testURL("!@#$%^&*()_+.,?:;\\")
        end)

        it("Encodes/decodes those darned plus signs", function()
            testURL("+ + +", "%2B+%2B+%2B")
        end)

        it("Encodes/decodes all possible bytes", function()
            for i = 0, 255 do
                testURL(string.char(i))
            end
        end)

        it ("Encodes/decodes strings of all possible bytes", function()
            for i = 0, 250 do
                testURL(string.char(i, i + 1, i + 2, i + 3, i + 4, i + 5))
            end
        end)

    end)

    describe("Query encoding/decoding", function()

        it("Encodes and decodes strings", function()
            testQuery({
                hello = "kitty",
                cat = "yum"
            }, "hello=kitty&cat=yum")
        end)

        it("Encodes and decodes numbers and strings", function()
            testQuery({
                [0] = "go",
                jump = "How high?++++",
                anumber = 145.2
            })
        end)

    end)

end)
