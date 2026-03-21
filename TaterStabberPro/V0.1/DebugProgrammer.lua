-- DebugProgrammer.lua
-- A simple debug plugin that dumps all programmer data to the console.
--
-- Author: Tater
-- Version: 7.0
-- Date: February 11, 2026

return function()
    Printf("=============== PROGRAMMER DUMP ===============")

    local prog = Programmer()

    -- Dump the programmer object itself
    Printf("--- Programmer Object ---")
    prog:Dump()
    Printf("")

    -- Dump each part and its lines
    Printf("--- Programmer Parts: %d ---", #prog)
    for i = 1, #prog do
        local part = prog[i]
        Printf("Part %d (%d lines):", i, #part)
        part:Dump()
        Printf("")
        for j = 1, #part do
            local line = part[j]
            if line then
                Printf("  Part %d Line %d:", i, j)
                line:Dump()
                Printf("")
            end
        end
    end

    -- Dump programmer children
    local children = prog:Children()
    if children then
        Printf("--- Programmer Children: %d ---", #children)
        for i = 1, #children do
            local child = children[i]
            if child then
                Printf("Child %d:", i)
                child:Dump()
                Printf("")
            end
        end
    end

    Printf("================ END DUMP ================")
end
end
end