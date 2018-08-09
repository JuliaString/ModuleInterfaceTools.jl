# Copyright 2018 Gandalf Software, Inc., Scott P. Jones
# Licensed under MIT License, see LICENSE.md

using ModuleInterfaceTools

@api test

@api extend InternedStrings

@api list InternedStrings

@api def testcase begin
    myname = "Scott Paul Jones"
end

@testset "@api def <name> <expr>" begin
    @testcase
    @test myname == "Scott Paul Jones"
end

intern(x::Integer) = 1
intern(x::Float64) = 2

@testset "Function extension" begin
    @test typeof(intern("foo")) == String
    @test intern(1) == 1
    @test intern(2.0) == 2
    @test intern("th") == "th"
end
