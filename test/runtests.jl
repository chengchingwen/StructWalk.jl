using StructWalk
using Test

@testset "StructWalk.jl" begin
    @test postwalk(x->x isa Expr ? eval(x) : x, :(2*3+5)) == 2*3+5
    @test postwalk(x->x isa Expr ? eval(x) : x==:+ ? :* : x==:* ? :+ : x, :(2*3+5)) == (2+3)*5

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

end
