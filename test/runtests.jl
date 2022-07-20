using StructWalk
using StructWalk: WalkStyle
using Test

struct FunctorStyle <: WalkStyle end
StructWalk.children(::FunctorStyle, x::AbstractArray) = ()

struct Foo{X, Y}
    x::X
    y::Y
end

struct Baz
    x
    y
end
StructWalk.constructor(::FunctorStyle, b::Baz) = Base.Fix2(Baz, b.y)
StructWalk.children(::FunctorStyle, b::Baz) = (b.x,)

Base.:(==)(a::T, b::T) where {T<:Foo} = a.x == b.x && a.y == b.y
Base.:(==)(a::Baz, b::Baz) = a.x == b.x && a.y == b.y


@testset "StructWalk.jl" begin
    @testset "walkstyle" begin
        @test postwalk(x->x isa Expr ? eval(x) : x, :(2*3+5)) == 2*3+5
        @test postwalk(x->x isa Expr ? eval(x) : x==:+ ? :* : x==:* ? :+ : x, :(2*3+5)) == (2+3)*5
        @test postwalk(x-> x isa Int ? Float32(x) : x, Dict(:a=>3, :b=>5)) == Dict(:a=>3f0, :b=>5f0)

        struct C
            x::Int
            y::Int
            z::Int
        end
        x = (a=3, b=5, c=(x=4, y=4, z=6), d=((((5,),),),))
        @test postwalk(x) do x
            x isa NamedTuple{(:x, :y, :z)} && return C(x...)
            x isa Tuple && return first(x)
            x isa Integer && return float(x)
            return x
        end == (a=3.0, b=5.0, c=C(4., 4., 6.), d=5.)

        f(x) = x isa Integer ? StructWalk.LeafNode(x // 2) : x isa Tuple ? =>(x .+ 1...) : x
        @test prewalk(f, (3, 5)) == (2//1 => 3//1)

        foo = Foo(1, [1,2,3])
        @test postwalk(x-> x isa Integer ? float(x) : x, FunctorStyle(), foo) == Foo(1.0, [1,2,3])
        @test mapleaves(float, FunctorStyle(), foo) == Foo(1.0, [1.0, 2.0, 3.0])
        baz = Baz(1, 2)
        @test mapleaves(float, FunctorStyle(), baz) == Baz(1.0, 2)
    end

    @testset "alignedstyle" begin
        a = (x = 1, y = (w = 2, b = 3))
        b = (0.5, (0.3, 0.5))
        c = (d = 4, z = (w = 0.5, b = 0.25))

        @test postwalk(identity, a, b) == ((1, 0.5), ((2, 0.3), (3, 0.5)))
        @test mapleaves(Base.splat(+), a, b) == (1.5, (2.3, 3.5))
        @test mapleaves(Base.splat(+), a, c) == (5, (w = 2.5, b = 3.25))

        foo = Foo(2, [1,2,3])
        @test mapleaves(Base.splat(*), FunctorStyle(), foo, (3, 5)) == [6, [5, 10, 15]]
    end

    @testset "scan" begin
        collector()= let c = []; return c, x->push!(c, x); end
        fcollect(xs...) = ((C, f) = collector(); StructWalk.scan(f, xs...); C)
        a = (x = 1, y = (w = 2, b = 3))
        b = (0.5, (0.3, 0.5))
        c = (d = 4, z = (w = 0.5, b = 0.25))

        @test fcollect(a) == [a, a[1], a[2], a[2][1], a[2][2]]
        @test fcollect(a, b) == [(a, b), (a[1], b[1]), (a[2], b[2]), (a[2][1], b[2][1]), (a[2][2], b[2][2])]

        foo = Foo(2, [1,2,3])
        @test fcollect(foo) == [foo, foo.x, foo.y, 1, 2, 3]
        @test fcollect(FunctorStyle(), foo) == [foo, foo.x, foo.y]
    end
end
