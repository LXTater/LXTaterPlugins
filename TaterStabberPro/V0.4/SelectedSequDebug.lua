return function ()
    -- Get the selected sequence
    local selectedSeq = SelectedSequence()
    
    if not selectedSeq then
        Printf("No sequence selected")
        return
    end
    
    -- Print sequence number and name
    local seqNum = selectedSeq.no or "Unknown"
    local seqName = selectedSeq.name or "Unnamed"
    
    Printf("=============== SELECTED SEQUENCE INFO ===============")
    Printf("Sequence Number: " .. tostring(seqNum))
    Printf("Sequence Name: " .. tostring(seqName))
    Printf("======================================================")
    
    -- Optional: Full dump for additional details
   -- Printf("")
   -- Printf("=============== START OF FULL DUMP ===============")
   -- selectedSeq:Dump()
   -- Printf("================ END OF FULL DUMP ================")
end