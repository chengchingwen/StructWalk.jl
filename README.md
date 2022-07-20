# StructWalk.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://chengchingwen.github.io/StructWalk.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://chengchingwen.github.io/StructWalk.jl/dev)
[![Build Status](https://github.com/chengchingwen/StructWalk.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/chengchingwen/StructWalk.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/chengchingwen/StructWalk.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/chengchingwen/StructWalk.jl)

Transform functions for Julia struct. Can be viewed as a general version of `MacroTools`'s `prewalk`/`postwalk` or `Functors`'s `@functor`/`fmap`.

# Examples

## Basic usage

```julia
julia> postwalk(x -> @show(x) isa Integer ? x + 1 : x, (a=2, b=(c=4, d=0)))
x = 2
x = 4
x = 0
x = (c = 5, d = 1)
x = (a = 3, b = (c = 5, d = 1))
(a = 3, b = (c = 5, d = 1))

julia> postwalk(x -> @show(x) isa Integer ? x + 1 : x .+ 1, (3, 5))
x = 3
x = 5
x = (4, 6)
(5, 7)

julia> postwalk(x -> @show(x) isa Integer ? x // 2 : x isa Tuple ? =>(x .+ 1...) : x, (3, 5))
x = 3
x = 5
x = (3//2, 5//2)
5//2 => 7//2

julia> prewalk(x -> @show(x) isa Integer ? x + 1 : x, (a=2, b=(c=4, d=0)))
x = (a = 2, b = (c = 4, d = 0))
x = 2
x = (c = 4, d = 0)
x = 4
x = 0
(a = 3, b = (c = 5, d = 1))

julia> prewalk(x -> @show(x) isa Integer ? x + 1 : x .+ 1, (3, 5))
x = (3, 5)
x = 4
x = 6
(5, 7)

julia> prewalk(x -> @show(x) isa Integer ? StructWalk.LeafNode(x // 2) : x isa Tuple ? =>(x .+ 1...) : x, (3, 5))
x = (3, 5)
x = 4
x = 6
2//1 => 3//1

```


## Structural replace

```julia
julia> x = (a=3, b=(w=3, b=0))
(a = 3, b = (w = 3, b = 0))

julia> postwalk(x) do x
           if x isa NamedTuple{(:w, :b)}
               return x[1]=>x[2]
           end
           return x
       end
(a = 3, b = 3 => 0)

```


## More example

```julia
using StructWalk
import StructWalk: WalkStyle, walkstyle

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

myfmap(f, x) = mapleaves(f, FunctorStyle(), x)

julia> foo = Foo(1, [1, 2, 3])
Foo{Int64, Vector{Int64}}(1, [1, 2, 3])

julia> postwalk(x-> x isa Integer ? float(x) : x, FunctorStyle(), foo)
Foo{Float64, Vector{Int64}}(1.0, [1, 2, 3])

julia> myfmap(float, foo)
Foo{Float64, Vector{Float64}}(1.0, [1.0, 2.0, 3.0])

julia> baz = Baz(1, 2)
Baz(1, 2)

julia> myfmap(float, baz)
Baz(1.0, 2)

julia> using CUDA; myfmap(CUDA.cu, foo)
Foo{Int64, CuArray{Int64, 1, CUDA.Mem.DeviceBuffer}}(1, [1, 2, 3])

```
