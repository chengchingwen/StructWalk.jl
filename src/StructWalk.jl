module StructWalk

export prewalk, postwalk

"""
Abstract type `WalkStyle`

Subtype `WalkStyle` and overload [`walkstyle`](@ref) to define custom walking behaviors (constructor / children /...).
"""
abstract type WalkStyle end

"""
    walkstyle(::CustomWalkStyle, x::T) where {CumstomWalkStyle <: WalkStyle}

Should return a tuple of length 2-3 with:

    1. A proper constuctor for `T`, can be `identity` if `x` isa leaf.
    2. Children of `x` in a tuple, or empty tuple `()` if `x` is a leaf.
    3. [optional] a bool indicate whether element of 2. is the actual list of children. default to `false`.

For example, since `Array` has 0 `fieldcount`, we doesn't split the value into a tuple as children.
 Instead, we return `(x,)` as children and the extra boolean `true`, so it will `walk`/`map` through `x`
 accordingly.
"""
function walkstyle end

"""
    walkstyle(x)
    walkstyle(::Type{WalkStyle}, x::T) where T

return `T` and a tuple all field values of `x`.
"""
walkstyle(x) = walkstyle(WalkStyle, x)
walkstyle(s::WalkStyle, x) = walkstyle(WalkStyle, x)
function walkstyle(::Type{WalkStyle}, x::T) where T
    n = fieldcount(T)
    isleaf = iszero(n)
    return T.name.wrapper, isleaf ? () : ntuple(i->getfield(x, i), n)
end
walkstyle(::Type{WalkStyle}, x::T) where {T <: Array} = t->convert(AbstractArray, t), (x,), true
walkstyle(::Type{WalkStyle}, x::T) where {T <: Tuple} = Tuple, (x,), true
walkstyle(::Type{WalkStyle}, x::T) where {T <: NamedTuple} = let name=keys(x); x->NamedTuple{name}(x); end, (x,), true
walkstyle(::Type{WalkStyle}, x::Expr) = (head, args)->Expr(head, args...), (x.head, x.args)

"""
    LeafNode(x)

special type for marking non-leaf value as leaf. Use with `prewalk`.

See also: [`prewalk`](@ref)
"""
struct LeafNode{T}
    x::T
end

@nospecialize

walk(_, _, _, x::LeafNode, _) = x.x

walk(f, style, x, inner_walk) = walk(f, f, style, x, inner_walk)
function walk(f, g, style, x, inner_walk)
    S = walkstyle(style, x)
    T, fields = S
    isleaf = isempty(fields)
    isnontuple = length(S) <= 2 ? false : S[3]
    if isleaf
        return f(x)
    else
        h = isnontuple ? v->map(inner_walk, v) : inner_walk
        return g(T(map(h, fields)...))
    end
end

"""
    postwalk(f, [style = WalkStyle], x)

Applies `f` to each node in `x` and return the result.
`f` sees the leaves first and then the transformed node.

# Example

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

```

See also: [`prewalk`](@ref)
"""
postwalk(f, x) = postwalk(f, WalkStyle, x)
postwalk(f, style, x) = walk(f, style, x, x -> postwalk(f, style, x))


"""
    prewalk(f, [style = WalkStyle], x)

Applies `f` to each node in `x` and return the result.
`f` sees the node first and then the transformed leaves.

*Notice* that it is possible it walk infinitely if you transform a node into non-leaf value.
 Wrapping the non-leaf value with `LeafNode(y)` in `f` to prevent infinite walk.

# Example

```julia
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
prewalk(f, style, x) = walk(identity, style, f(x), x -> prewalk(f, style, x))


@specialize


end
