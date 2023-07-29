# StructWalk.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://chengchingwen.github.io/StructWalk.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://chengchingwen.github.io/StructWalk.jl/dev)
[![Build Status](https://github.com/chengchingwen/StructWalk.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/chengchingwen/StructWalk.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/chengchingwen/StructWalk.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/chengchingwen/StructWalk.jl)

Transform functions for Julia struct. Can be viewed as a general version of `MacroTools`'s `prewalk`/`postwalk` or `Functors`'s `@functor`/`fmap`.

# Examples

## Basic usage
In this first example, we walk over a struct `xs`, applying a function `f` which increments integers.
Using `prewalk`, `f` sees the node first and then the transformed leaves.
Using `postwalk`,  `f` sees the leaves first and then the transformed node:
```julia
xs = (a=2, b=(c=4, d=0))

f(x) = x
f(x::Integer) = x + 1
```

```julia-repl
julia> postwalk(x -> f(@show(x)), xs) # w/o printing: postwalk(f, xs)
x = 2
x = 4
x = 0
x = (c = 5, d = 1)
x = (a = 3, b = (c = 5, d = 1))
(a = 3, b = (c = 5, d = 1))

julia> prewalk(x -> f(@show(x)), xs)
x = (a = 2, b = (c = 4, d = 0))
x = 2
x = (c = 4, d = 0)
x = 4
x = 0
(a = 3, b = (c = 5, d = 1))

```

Since `prewalk` and `postwalk` differ in the order of function application, return values can differ as well: 
```julia
g(x::Integer) = x + 1
g(x::Tuple) = x .* 2
```

```julia-repl
julia> postwalk(x -> g(@show(x)), (3, 5))
x = 3
x = 5
x = (4, 6)
(8, 12)

julia> prewalk(x -> g(@show(x)), (3, 5))
x = (3, 5)
x = 6
x = 10
(7, 11)

```

To avoid infinite recursion using `prewalk`, return values can be wrapped in `StructWalk.LeafNode`.

In the following example, this is required to avoid recursion over the `Integer` fields of the `Rational` number struct:
```julia-repl
julia> postwalk((3, 5)) do x 
           @show(x) 
           if x isa Integer 
               return x // 2 
           elseif x isa Tuple 
               return Pair(x .+ 1...)
           end 
           return x
       end  
x = 3
x = 5
x = (3//2, 5//2)
5//2 => 7//2

julia> prewalk((3, 5)) do x 
           @show(x) 
           if x isa Integer 
               return StructWalk.LeafNode(x // 2)
           elseif x isa Tuple 
               return Pair(x .+ 1...)
           end 
           return x
       end  
x = (3, 5)
x = 4
x = 6
2//1 => 3//1

```

## Structural replace

```julia
julia> xs = (a=3, b=(w=3, b=0))
(a = 3, b = (w = 3, b = 0))

julia> postwalk(xs) do x
           if x isa NamedTuple{(:w, :b)}
               return x[1]=>x[2]
           end
           return x
       end
(a = 3, b = 3 => 0)

```

## More examples

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
