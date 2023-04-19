module StructWalk

import ConstructionBase
using ConstructionBase: constructorof

export prewalk, postwalk, mapleaves

"""
    abstract type WalkStyle and

Subtype `WalkStyle` and overload [`walkstyle`](@ref) to define custom walking behaviors (constructor / children /...).
"""
abstract type WalkStyle end

"""
    walkstyle(::CustomWalkStyle, x::T) where {CumstomWalkStyle <: WalkStyle}

Should return a tuple of length 3 with:

    1. [constructor](@ref): A proper constuctor for `T`, can be `identity` if `x` isa leaf.
    2. [children](@ref): Children of `x` in a tuple, or empty tuple `()` if `x` is a leaf. 
        Named tuples are also allowed as alternatives to tuples. 
    3. [iscontainer](@ref): A bool indicate whether element of 2. is the actual list of children.
        For example, since `Array` has 0 `fieldcount`, we doesn't split the value into a tuple as children.
        Instead, we return `(x,)` as children and the extra boolean `true`, so it will `walk`/`map` through `x`
        accordingly. Default `false`.
"""
function walkstyle end

"""
    walkstyle(x)
    walkstyle(::Type{WalkStyle}, x::T) where T

Return `T` and a tuple all field values of `x`. The default behavior use
 `ConstructionBase.constructorof` for the constructor and
 `ConstructionBase.getfields` for the children.
"""
walkstyle(x) = walkstyle(WalkStyle, x)
walkstyle(s::WalkStyle, x) = _walkstyle(s, x)
walkstyle(::Type{WalkStyle}, x) = _walkstyle(WalkStyle, x)
@inline _walkstyle(s, x) = constructor(s, x), children(s, x), iscontainer(s, x)

"""
    constructor(s::WalkStyle, x)

Return the constructor for `x`, which would be applied to `children(s, x)`.

See also: [children](@ref), [iscontainer](@ref)
"""
constructor(x) = constructor(WalkStyle, x)
constructor(s::WalkStyle, x) = constructor(WalkStyle, x)
constructor(::Type{WalkStyle}, x) = iszero(fieldcount(typeof(x))) ? identity : ConstructionBase.constructorof(typeof(x))

"""
    children(s::WalkStyle, x)

Return the children of `x`, which would be feeded to `constructor(s, x)`. If `x` is an container type like `Array`,
 it can return a tuple of itself and set `iscontainer(s, x)` to `true`.

See also: [constructor](@ref), [iscontainer](@ref)
"""
children(x) = children(WalkStyle, x)
children(s::WalkStyle, x) = children(WalkStyle, x)
children(::Type{WalkStyle}, x) = iszero(fieldcount(typeof(x))) ? () : ConstructionBase.getfields(x)

"""
    iscontainer(s::WalkStyle, x)

Return a `Bool` indicating whether `children(x)` return a tuple of itself or not.

See also: [constructor](@ref), [children](@ref)
"""
iscontainer(x) = iscontainer(WalkStyle, x)
iscontainer(s::WalkStyle, x) = iscontainer(WalkStyle, x)
iscontainer(::Type{WalkStyle}, x) = false

const WALKSTYLE = Union{WalkStyle, Type{<:WalkStyle}}

# default walkstyle for some types
include("walkstyle.jl")

"""
    LeafNode(x)

special type for marking non-leaf value as leaf. Use with `prewalk`.

See also: [`prewalk`](@ref)
"""
struct LeafNode{T}
    x::T
end

@nospecialize

walk(_, _, ::WALKSTYLE, _, x::LeafNode) = x.x

walk(f, style::WALKSTYLE, inner_walk, x) = walk(f, f, style, inner_walk, x)
function walk(f, g, style::WALKSTYLE, inner_walk, x)
    T, fields, iscontainer = walkstyle(style, x)
    isleaf = isempty(fields)
    if isleaf
        return f(x)
    else
        h = iscontainer ? Base.Fix1(map, inner_walk) : inner_walk
        v = map(h, fields)
        return g(T(v...))
    end
end


"""
    postwalk(f, [style = WalkStyle], x)

Apply `f` to each node in `x` and return the result.
 `f` sees the leaves first and then the transformed node.

# Example

```julia-repl
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

```

See also: [`prewalk`](@ref)
"""
postwalk(f, x) = postwalk(f, WalkStyle, x)
postwalk(f, style::WALKSTYLE, x) = walk(f, style, x -> postwalk(f, style, x), x)

"""
    prewalk(f, [style = WalkStyle], x)

Apply `f` to each node in `x` and return the result.
 `f` sees the node first and then the transformed leaves.

*Notice* that it is possible it walk infinitely if you transform a node into non-leaf value.
 Wrapping the non-leaf value with `LeafNode(y)` in `f` to prevent infinite walk.

# Example

```julia-repl
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

See also: [`postwalk`](@ref), [`LeafNode`](@ref)
"""
prewalk(f, x) = prewalk(f, WalkStyle, x)
prewalk(f, style::WALKSTYLE, x) = walk(identity, style, x -> prewalk(f, style, x), f(x))

"""
    mapleaves(f, [style = WalkStyle], x)

Apply `f` to each leaf nodes in `x` and return the result.
 `f` only see leaf nodes.

# Example

```julia-repl
julia> mapleaves(x -> @show(x) isa Integer ? x + 1 : x, (a=2, b=(c=4, d=0)))
x = 2
x = 4
x = 0
(a = 3, b = (c = 5, d = 1))

```
"""
mapleaves(f, x) = mapleaves(f, WalkStyle, x)
mapleaves(f, style::WALKSTYLE, x) = walk(f, identity, style, x -> mapleaves(f, style, x), x)

"""
    mapnonleaves(f, [style = WalkStyle], x)

Apply `f` to each non-leaf in `x` and return the result.
 `f` only see non-leaf nodes.

# Example

```julia-repl
julia> StructWalk.mapnonleaves(x -> @show(x) isa Integer ? x + 1 : x, (a=2, b=(c=4, d=0)))
x = (c = 4, d = 0)
x = (a = 2, b = (c = 4, d = 0))
(a = 2, b = (c = 4, d = 0))

```
"""
mapnonleaves(f, x) = mapnonleaves(f, WalkStyle, x)
mapnonleaves(f, style::WALKSTYLE, x) = walk(identity, f, style, x -> mapnonleaves(f, style, x), x)

include("aligned.jl")
include("scan.jl")
include("functors.jl")

@specialize

end
