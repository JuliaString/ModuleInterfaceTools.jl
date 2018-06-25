# Copyright 2018 Gandalf Software, Inc., Scott P. Jones
# Licensed under MIT License, see LICENSE.md

using ModuleInterfaceTools

@api test

@api extend StrTables

@api list StrTables

@api def testcase begin
    myname = "Scott Paul Jones"
end

@testset "@api def <name> <expr>" begin
    @testcase
    @test myname == "Scott Paul Jones"
end

cvt_char(x::Integer) = 1
cvt_char(x::Float64) = 2

@testset "Function extension" begin
    @test typeof(cvt_char("foo")) == Vector{Char}
    @test cvt_char(1) == 1
    @test cvt_char(2.0) == 2
    @test cvt_char("th") == Char['t', 'h']
end
