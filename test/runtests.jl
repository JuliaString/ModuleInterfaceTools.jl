# Copyright 2018 Gandalf Software, Inc., Scott P. Jones
# Licensed under MIT License, see LICENSE.md

using APITools

@static V6_COMPAT ? (using Base.Test) : (using Test)

# Pick up APITest from the test directory
push!(LOAD_PATH, @__DIR__)

@api extend APITest

@api list APITest

@api def testcase begin
    myname = "Scott Paul Jones"
end

@testset "@api def <name> <expr>" begin
    @testcase
    @test myname == "Scott Paul Jones"
end

myfunc(::AbstractFloat) = 3

@testset "Function extension" begin
    @test myfunc(1) == 1
    @test myfunc("foo") == 2
    @test myfunc(2.0) == 3
end

@testset "API lists" begin
    @test APITest.__api__.mod == APITest
    @test Set(APITest.__api__.base) == Set([:nextind, :getindex, :setindex!])
    @test Set(APITest.__api__.public) == Set([:Foo])
    @test Set(APITest.__api__.public!) == Set([:myfunc])
end
