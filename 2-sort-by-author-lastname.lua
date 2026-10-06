local BookList = require("ui/widget/booklist")
local ffiUtil = require("ffi/util")
local _ = require("gettext")

local LAST = "\u{FFFF}"

local function toSet(words)
    local set = {}
    for __, word in ipairs(words) do
        set[word] = true
        set[word .. "."] = true
    end
    return set
end

local PREFIXES = toSet{ "mr", "mrs", "ms", "dr", "prof", "sir", "dame", "rev" }
local SUFFIXES = toSet{ "jr", "sr", "junior", "senior", "i", "ii", "iii", "iv", "phd", "ph.d", "md", "m.d", "esq" }
local COPYWORDS = toSet{ "agency", "corporation", "company", "co", "council", "committee", "inc", "institute", "national", "society", "club", "team", "software", "games", "entertainment", "media", "studios", "press", "publishing", "staff", "anonymous", "various" }
local PARTICLES = toSet{ "da", "das", "de", "del", "della", "den", "der", "di", "do", "dos", "du", "la", "le", "st", "ten", "ter", "van", "von", "bin", "ibn" }

local function authorSortKey(author)
    local name = author:gsub("%b()", ""):gsub("%b[]", ""):match("^%s*(.-)%s*$")
    if name:find(",") then
        local head, tail = name:match("^(.*),%s*(%S+)$")
        if not (tail and SUFFIXES[tail:lower()]) then return name end
        if head:find(",") then return head .. " " .. tail end
        name = head .. " " .. tail
    end
    local tokens, lower = {}, {}
    for word in name:gmatch("%S+") do
        tokens[#tokens + 1] = word
        lower[#tokens] = word:lower()
        if COPYWORDS[lower[#tokens]] then return name end
    end
    if #tokens < 2 then return tokens[1] or LAST end
    local first, last = 1, #tokens
    while first < last and PREFIXES[lower[first]] do first = first + 1 end
    while last > first and SUFFIXES[lower[last]] do last = last - 1 end
    local start = last
    while start - 1 > first and PARTICLES[lower[start - 1]] do start = start - 1 end
    local key = table.concat(tokens, " ", start, last)
    if start > first then key = key .. ", " .. table.concat(tokens, " ", first, start - 1) end
    if last < #tokens then key = key .. " " .. table.concat(tokens, " ", last + 1) end
    return key
end

BookList.collates.author_last_name = {
    text = _("Author (last name)"),
    menu_order = 115,
    can_collate_mixed = false,
    item_func = function(item, ui)
        local ok, props = pcall(function() return ui.bookinfo:getDocProps(item.path or item.file) end)
        props = ok and props or {}
        local author = (props.authors or ""):match("[^\n&;]*[^\n&;%s][^\n&;]*")
        item.author_key = author and authorSortKey(author) or LAST
        item.title_key = props.display_title or item.text
    end,
    init_sort_func = function()
        return function(a, b)
            if a.author_key ~= b.author_key then
                return ffiUtil.strcoll(a.author_key, b.author_key)
            end
            return ffiUtil.strcoll(a.title_key, b.title_key)
        end
    end,
    mandatory_func = function(item)
        return item.author_key ~= LAST and item.author_key or ""
    end,
}