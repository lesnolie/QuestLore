local _, ns = ...
local Locale = {}
ns.Locale = Locale
local english = {
 ["Ver historial"]="View history",
 ["Historial de relatos"]="Story history",
 ["Selecciona un relato de la lista. El historial se guarda para este personaje."]="Select a story from the list. History is saved for this character.",
 ["Aún no hay relatos guardados."]="No stories have been saved yet.",
 ["Adjuntar al final del rastreador de misiones"]="Attach below the quest tracker",
 ["Requiere ForeverCore para adjuntar el relato al rastreador."]="ForeverCore is required to attach the story to the quest tracker.",
 ["El cambio se aplicará al salir de combate."]="The change will apply after combat ends.",
 ["Desactiva esta opción para mover y redimensionar la ventana libremente."]="Turn this off to move and resize the window freely.",
 ["Tu lugar en Azeroth"]="Your place in Azeroth",
 ["Selecciona una misión"]="Select a quest",
 ["Abre el diario y selecciona una misión, o sigue una para leer por qué estás haciéndola."]="Select a quest in your journal or track one to read why you are doing it.",
 ["Cargando el relato de la misión…"]="Loading the quest story…",
 ["Todavía no hay relato disponible para esta misión. Prueba a abrir sus detalles en el diario."]="This quest's story is not available yet. Try opening its details in the quest journal.",
 ["Tu aventura"]="Your adventure",
 ["Preparando el relato de tu personaje…"]="Preparing your character's story…",
 ["Sin misiones activas"]="No active quests",
 ["Has comenzado tu aventura. Selecciona una misión para leer su contexto. Puedes consultar tus relatos anteriores en las opciones de QuestLore."]="Your adventure has begun. Select a quest to read its context. You can find previous stories in the QuestLore options.",
 ["Minimizar ventana"]="Minimize window", ["Restaurar ventana"]="Restore window",
 ["Relato anterior"]="Previous story", ["Relato siguiente"]="Next story",
 ["Volver al contexto actual de tu personaje"]="Return to your character's current context",
 ["Arrastra para cambiar el tamaño"]="Drag to resize", ["Actual"]="Current",
 ["Actual · nuevo"]="Current · new", ["Historial"]="History",
 ["Tamaño del texto: "]="Text size: ", ["Restablecer texto"]="Reset text size",
 ["Idioma del relato"]="Story language", ["Automático (idioma del juego)"]="Automatic (game language)",
 ["Español"]="Español", ["English"]="English",
 ["El contexto de tus misiones. Las preferencias se guardan para este personaje."]="The context behind your quests. Settings are saved for this character.",
 ["Has recuperado tu voluntad. Ahora debes encontrar tu lugar entre los Renegados y ayudar a proteger Tirisfal."]="You have regained your free will. Now you must find your place among the Forsaken and help protect Tirisfal.",
 ["Todavía no se pudo leer tu raza y tu clase. El contexto aparecerá cuando tu personaje termine de cargar."]="Your race and class are not available yet. Your story will appear when your character finishes loading.",
 ["Este relato todavía no tiene una traducción al idioma elegido."]="This story has not been translated into the selected language yet.",
 ["Misión "]="Quest ", ["Resumen narrativo · sin adelantar la historia"]="Narrative summary · no story spoilers",
 ["Extracto del relato de la misión"]="Quest story excerpt", ["Descripción de la misión"]="Quest description",
}
-- Explicit branch avoids Lua's boolean result for the short language code.
function Locale.Resolve(value)
    if value == "es" or (type(value)=="string" and value:sub(1,2)=="es") then return "es" end
    return "en"
end
function Locale.Get()
    local choice = ns.db and ns.db.language
    if choice == "es" or choice == "en" then return choice end
    return Locale.Resolve(ns.locale or (GetLocale and GetLocale()) or "esMX")
end
function ns.L(key, language)
    return (language or Locale.Get())=="en" and (english[key] or key) or key
end
function Locale.Set(choice)
    if choice ~= "auto" and choice ~= "es" and choice ~= "en" then return end
    ns.db.language = choice
    if ns.ready then ns.history:Relocalize() end
    if ns.Options then ns.Options:Sync() end
    if ns.ready then
        if ns.Window.Localize then ns.Window:Localize() end
        ns.QueueRefresh()
    end
end
