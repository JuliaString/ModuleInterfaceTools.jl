# Copyright 2018 Gandalf Software, Inc., Scott P. Jones
# Licensed under MIT License, see LICENSE.md

using ModuleInterfaceTools

@api test

@api extend StrAPI

@api list StrAPI

@api def testcase begin
    myname = "Scott Paul Jones"
end

@testset "@api def <name> <expr>" begin
    @testcase
    @test myname == "Scott Paul Jones"
end

codepoints(x::Integer) = 1
codepoints(x::Float64) = 2

@testset "Function extension" begin
    @test typeof(codepoints("foo")) === CodePoints{String}
    @test codepoints(1) == 1
    @test codepoints(2.0) == 2
end

@testset "API lists" begin
    @test StrAPI.__api__.mod == StrAPI
    @test :split in Set(StrAPI.__api__.base)
    @test :encoding in Set(StrAPI.__api__.public!)
    @test :Direction in Set(StrAPI.__api__.public)
end
