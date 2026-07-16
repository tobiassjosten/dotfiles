-- Shows the number of PRs assigned to you in the menu bar.

-- Provision the PAT (repo scope) once with:
--   security add-generic-password -a tobiassjosten -s github-pr-token -w <token>
local GITHUB_USER  = "tobiassjosten"       -- your GitHub login
local GITHUB_TOKEN = hs.execute(
    "security find-generic-password -a " .. GITHUB_USER .. " -s github-pr-token -w",
    true
):gsub("%s+$", "")
local REFRESH_SECONDS = 120                -- how often to poll

-- What counts as "assigned to you". Pick one (or combine):
--   review-requested:USER  -> PRs where you're a requested reviewer
--   assignee:USER          -> PRs explicitly assigned to you
local QUERY = "is:open is:pr draft:false review-requested:" .. GITHUB_USER

local menubar = hs.menubar.new()

local function setTitle(count)
    if not menubar then return end
    if count and count > 0 then
        menubar:setTitle("#" .. tostring(count))
    else
        menubar:setTitle("")
    end
end

local function fetchCount()
    local url = "https://api.github.com/search/issues?q="
        .. hs.http.encodeForQuery(QUERY) .. "&per_page=1"

    local headers = {
        ["Authorization"]        = "token " .. GITHUB_TOKEN,
        ["Accept"]               = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"]           = "Hammerspoon",
    }

    hs.http.asyncGet(url, headers, function(status, body, _)
        if status ~= 200 or not body then
            setTitle(nil)   -- hide on error
            return
        end
        local ok, data = pcall(hs.json.decode, body)
        if ok and data and data.total_count then
            setTitle(data.total_count)
        else
            setTitle(nil)
        end
    end)
end

-- Click opens the relevant GitHub search page
if menubar then
    menubar:setClickCallback(function()
        hs.urlevent.openURL(
            "https://github.com/pulls?q=" .. hs.http.encodeForQuery(QUERY))
    end)
end

fetchCount()
local timer = hs.timer.doEvery(REFRESH_SECONDS, fetchCount)

return { timer = timer, refresh = fetchCount }
