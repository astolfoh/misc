for _, instance in ipairs(game:GetDescendants()) do

    if instance:IsA("LocalScript") or instance:IsA("ModuleScript") then

        local bytecode = getscriptbytecode(instance)
        local convertreadable = tostring(bytecode)

        for line in convertreadable:gmatch("%w+") do
            if line:match("UpdateMousePos") then
                print(line)
            end
        end

    end

end
