local _, ns = ...
local Origins = {}
ns.Origins = Origins
function Origins.Build(profile)
    profile = profile or {}
    local race = profile.race == "Undead" and "Scourge" or profile.race
    local culture = race
    if race == "Skyborne" then culture = race .. ":" .. (profile.faction == "Horde" and "Horde" or "Alliance") end
    local body = culture and ns.OriginStories[ns.Locale.Get()][culture .. ":" .. (profile.class or "")] or nil
    if not body then
        return {key="origins:unknown",kind="missing",title=ns.L("Tu lugar en Azeroth"),source="",
            body=ns.L("Todavía no se pudo leer tu raza y tu clase. El contexto aparecerá cuando tu personaje termine de cargar.")}
    end
    return {key="origins:"..race..":"..profile.class..":"..(profile.faction or ""),
        title=ns.L("Tu lugar en Azeroth"),body=body,source="",kind="origins",language=ns.Locale.Get()}
end
