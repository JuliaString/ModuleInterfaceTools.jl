# Copyright 2018 Gandalf Software, Inc., Scott P. Jones
# Licensed under MIT License, see LICENSE.md

using APITools

@static V6_COMPAT ? (using Base.Test) : (using Test)

@def testcase begin
    myname = "Scott Paul Jones"
end

@testset "@def macro" begin
    @testcase
    @test myname == "Scott Paul Jones"
end

# Pick up APITest from the test directory
push!(LOAD_PATH, @__DIR__)

@api init

import APITest: myfunc

macroexpand( :( @api extend APITest ) )

@api list

@api list APITest

myfunc(::AbstractFloat) = 3

@testset "@api macro" begin
    @test myfunc(1) == 1
    @test myfunc("foo") == 2
    @test myfunc(2.0) == 3
    @test APITest.__api__.mod == APITest
    @test APITest.__api__.base == (:nextind, :getindex, :setindex!)
    @test APITest.__api__.public  == (:myfunc,)
    @test APITest.__api__.define_public == (:Foo,)
end
