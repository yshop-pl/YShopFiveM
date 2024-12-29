DBLoaded = false
local emotes = {"🐸", "🐌", "👾","🐉","🐘","🦡","🦔","🪼","🐚","🦐","🐠","🦩","🪽","🦉","🦢"}
MySQL.ready(function()
    DBLoaded = true
end)

function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function printDebug(text)
    if Config.Debug then
        print("[^5DEBUG^7] "..text)
    end
end

local function SendAPIRequest(path, cb, body)
    url = Config.ApiUrl.."/public/license/server/"..Config.ServerId.."/"..path
    method = not body and "GET" or "POST"
    headers = {}
    headers["User-Agent"] = "YShopFiveM/"..GetResourceMetadata(GetCurrentResourceName(), "version")
    headers["x-api-key"] = Config.ApiKey
    headers["x-app-platform"] = "platform/minecraft-java"
    headers["x-app-platform-version"] = ""..GetGameBuildNumber()
    headers["x-app-platform-engine"] = GetConvar("sv_hostname", "FiveM Server")
    printDebug("Sending "..method.." to url: "..url)
    printDebug("With API Key: "..Config.ApiKey)
    PerformHttpRequest(url, function (statusCode, resultData, resultHeaders, ErrorData)
        if statusCode >= 400 then
            print("[^1ERROR^7] [^4"..statusCode.."^7] Sprawdź poprawność pliku konfiguracyjnego!")
            printDebug("[^1ERROR^7] [^2"..statusCode.."^7] "..ErrorData)
            return
        end
        cb(statusCode, resultData, resultHeaders)
    end, method, body, headers)
end

local function ExecuteOrders()
    SendAPIRequest("commands", function(status, data)
        orders = json.decode(data)

        for k, v in pairs(orders) do
            local fivemid = string.format("fivem:%s", mysplit(v['nickname'], ":")[1])
            if v["require_online"] then
                local isOnline = MySQL.Sync.fetchScalar("SELECT online FROM shop_identifiers WHERE fivemid = @fivemid", {
                    ['@fivemid'] = fivemid
                })
                if not isOnline then
                    goto continue
                end
            end
            local result = exports.oxmysql.query_async(nil, "SELECT name, identifier FROM shop_identifiers WHERE fivemid = @fivemid", {
                ['@fivemid'] = fivemid
            })
            if result then
                printDebug("Executing Order: "..v.id)
                for k, command in pairs(mysplit(dec(v.commands), "||")) do 
                    command = string.gsub(command, "{identifier}", result[1].identifier)
                    command = string.gsub(command, "{fivemname}", result[1].name)
                    printDebug("Executing Command: "..command)
                    ExecuteCommand(command)
                end 
                SendAPIRequest("commands/"..v.id, function(status, data)
                    printDebug("Executed Order: "..v.id)
                end, json.encode({["post"] = true}))
            end
            ::continue::
        end
    end)
end

Citizen.CreateThread(function ()    
    while true do
        ExecuteOrders()
        printDebug("Executing Orders")
        Wait(30000)
    end
end)


AddEventHandler('playerConnecting', function(PlayerId, setCallback, deferrals)
    deferrals.defer()
    Citizen.Wait(100)

    while not DBLoaded do
        deferrals.update("Oczekiwanie na połączenie z bazą danych ".. emotes[math.random(1, #emotes)])
        Citizen.Wait(100)
    end
    local name = GetPlayerName(PlayerId)
    local FivemId = nil
    local identifier = nil

    for k, v in pairs(GetPlayerIdentifiers(PlayerId)) do
        if (string.match(string.lower(v), 'fivem:')) then
            FivemId = v
        end
        if (string.match(string.lower(v), Config.MainIdentifier..':')) then
            identifier = v
        end
    end

    if FivemId == nil then
        deferrals.done()
        return
    end

    exports.oxmysql.query(nil,'SELECT COUNT(*) AS `count` FROM `shop_identifiers` WHERE `fivemid` = @fivemid', {
        ["fivemid"] = FivemId
    }, function(results)
        if (results ~= nil and #results > 0) then
            if tonumber(results[1].count) < 1 then
                exports.oxmysql.query(nil, "INSERT INTO `shop_identifiers` (`id`, `fivemid`, `name`, `identifier`, `date`, `online`) VALUES (NULL, @fivemid, @name, @identifier, CURRENT_TIMESTAMP, 1)", {
                    ['@fivemid'] = FivemId,
                    ['@name'] = name,
                    ['@identifier'] = identifier,
                })     
            else
                exports.oxmysql.query(nil, "UPDATE `shop_identifiers` SET `name` = @name, `date` = CURRENT_TIMESTAMP, `online` = 1 WHERE `fivemid` = @fivemid AND `identifier` = @identifier", {
                    ['@fivemid'] = FivemId,
                    ['@name'] = name,
                    ['@identifier'] = identifier,
                })
            end
        end
    end)
end)

AddEventHandler('playerDropped', function (reason)
    local FivemId = nil
    local identifier = nil
    for k, v in pairs(GetPlayerIdentifiers(source)) do
        if (string.match(string.lower(v), 'fivem:')) then
            FivemId = v
        end
        if (string.match(string.lower(v), Config.MainIdentifier..':')) then
            identifier = v
        end
    end
    exports.oxmysql.query(nil,"UPDATE `shop_identifiers` SET `online` = 0 WHERE `fivemid` = @fivemid AND `identifier` = @identifier", {
        ['@fivemid'] = FivemId,
        ['@identifier'] = identifier,
    })
end)

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding

-- decoding
function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end
