if not helms then return end
if helms.version < 1 then return end


helms_tests = {}

helms_tests.log_i = helms.logger.new("helms_tests","info")
helms_tests.log_e = helms.logger.new("helms_tests","error")

local helms_test_error_handler = function(err)
	helms_tests.log_e.log(err)
end 
---------------------------------------------------------------------
helms_tests.safe_call = function()
    local pass =false
    local f=function(foo)
        pass = foo
    end
    helms.util.safeCall(f,{true},helms_test_error_handler)
    return pass
end

helms_tests.obj2str = function()
    local pass =
    helms.util.obj2str({foo = "1", bar = 2, doo = {haha = "ok"}})
    =='{doo:{haha:"ok", }, bar:2, foo:"1", }'
    --helms_tests.log_i.log(helms.util.obj2str({foo = "1", bar = 2, doo = {haha = "ok"}}))
    return pass
end

helms_tests.deep_copy = function()
    local instance = {foo = "1", bar = 2, doo = {haha = "ok"}}
    local copy = helms.util.deep_copy(instance)

    local pass = copy.foo == "1" and copy.doo.haha == "ok"
    instance.doo.haha = "Nope"
    pass= pass and copy.doo.haha == "ok"
    return pass
end

helms_tests.getTrueNorthTheta = function()
    local p={x=1,y=0,z=1}
    return helms.maths.getTrueNorthTheta(p) == mist.getNorthCorrection(p)
end


---------------------------------------------------------------------
for k,v in pairs(helms_tests) do
    if type(v) == 'function' then
        if v() then
            helms_tests.log_i.log("Test "..k..": PASS")
        else
            helms_tests.log_i.log("Test "..k..": FAIL")
        end
    end
end

helms_tests.log_i.log(helms.util.obj2str(helms.mission._GroupLookup))