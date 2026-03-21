return function ()
    -- Dumps information about the current programmer part object.
    Printf("=============== START OF DUMP ===============")
    DataPool().Universes[1]:Dump()
    Printf("================ END OF DUMP ================")
end