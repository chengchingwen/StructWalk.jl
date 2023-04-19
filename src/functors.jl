# Replacement for Functors.jl

const NoChildren = Tuple{}
# isleaf(x) = isempty(x)

struct FunctorStyle <: WalkStyle end

isleaf(@nospecialize(x)) = children(FunctorStyle(), x) === NoChildren()

children(::FunctorStyle, x::AbstractArray{<:Number}) = ()
constructor(::FunctorStyle, x::AbstractArray{<:Number}) = _ -> x
iscontainer(::FunctorStyle, x::AbstractArray{<:Number}) = false

constructor(::FunctorStyle, x::AbstractArray) = identity
constructor(::FunctorStyle, x::Tuple) = identity
constructor(::FunctorStyle, x::NamedTuple) = identity
constructor(::FunctorStyle, x::Dict) = identity

children(::FunctorStyle, x::AbstractArray) = x
children(::FunctorStyle, x::Tuple) = x
children(::FunctorStyle, x::NamedTuple) = x
children(::FunctorStyle, x::Dict) = x

function constructor(::FunctorStyle, x::T) where T
    if iszero(fieldcount(T))
        return identity
    else
        ch -> ConstructionBase.constructorof(T)(ch...)
    end
end

# mimicks Functors.fmap
fmap(f, x) = functor_mapleaves(f, FunctorStyle(), x)

# mimicks Functors.fmapstructure
struct FunctorStructureStyle <: WalkStyle end
children(::FunctorStructureStyle, x) = children(FunctorStyle(), x)
iscontainer(::FunctorStructureStyle, x) = iscontainer(FunctorStyle(), x)
constructor(::FunctorStructureStyle, x) = to_standard_container

to_standard_container(x::Union{Tuple, NamedTuple, AbstractArray, AbstractDict}) = x
to_standard_container(x::T) where T = (; (f => getfield(x, f) for f in fieldnames(T))...)

"""
    fmapstructure(f, x; exclude = isleaf)

Like fmap, but doesn't preserve the type of custom structs. Instead, it returns a NamedTuple (or a Tuple, or an array),
or a nested set of these.

Useful for when the output must not contain custom structs.

# Examples
```
julia> struct Foo; x; y; end

julia> @functor Foo

julia> m = Foo([1,2,3], [4, (5, 6), Foo(7, 8)]);

julia> fmapstructure(x -> 2x, m)
(x = [2, 4, 6], y = Any[8, (10, 12), (x = 14, y = 16)])

julia> fmapstructure(println, m)
[1, 2, 3]
4
5
6
7
8
(x = nothing, y = Any[nothing, (nothing, nothing), (x = nothing, y = nothing)])
```
"""
fmapstructure(f, x) = functor_mapleaves(f, FunctorStructureStyle(), x)


functor_mapleaves(f, style::WALKSTYLE, x) = functor_walk(f, identity, style, x -> functor_mapleaves(f, style, x), x)

### Same as walk but doesn't splat the constructor. 
### We could replace `walk` with this in the next breaking release.
function functor_walk(f, g, style::WALKSTYLE, inner_walk, x)
    T, fields, iscontainer = walkstyle(style, x)
    isleaf = isempty(fields)
    if isleaf
        return f(x)
    else
        v = mapvalues(inner_walk, fields)
        return g(T(v))
    end
end

mapvalues(f, x) = map(f, x)
mapvalues(f, x::Dict) = Dict(k => f(v) for (k, v) in pairs(x))

# functor(::Type{<:Adjoint}, x) = (parent = _adjoint(x),), y -> adjoint(only(y))

# _adjoint(x) = adjoint(x)  # _adjoint is the inverse, and also understands more types:
# _adjoint(x::NamedTuple{(:parent,)}) = x.parent  # "structural" gradient, and lazy broadcast used by Optimisers:
# _adjoint(bc::Broadcast.Broadcasted{S}) where S = Broadcast.Broadcasted{S}(_conjugate(bc.f, adjoint), _adjoint.(bc.args))

# functor(::Type{<:Transpose}, x) = (parent = _transpose(x),), y -> transpose(only(y))

# _transpose(x) = transpose(x)
# _transpose(x::NamedTuple{(:parent,)}) = x.parent
# _transpose(bc::Broadcast.Broadcasted{S}) where S = Broadcast.Broadcasted{S}(_conjugate(bc.f, transpose), _transpose.(bc.args))

# _conjugate(f::F, ::typeof(identity)) where F = f
# _conjugate(f::F, op::Union{typeof(transpose), typeof(adjoint)}) where F = (xs...,) -> op(f(op.(xs)...))

# function functor(::Type{<:PermutedDimsArray{T,N,perm,iperm}}, x) where {T,N,perm,iperm}
#   (parent = _PermutedDimsArray(x, iperm),), y -> PermutedDimsArray(only(y), perm)
# end
# function functor(::Type{<:PermutedDimsArray{T,N,perm,iperm}}, x::PermutedDimsArray{Tx,N,perm,iperm}) where {T,Tx,N,perm,iperm}
#   (parent = parent(x),), y -> PermutedDimsArray(only(y), perm)  # most common case, avoid wrapping wrice.
# end

# _PermutedDimsArray(x, iperm) = PermutedDimsArray(x, iperm)
# _PermutedDimsArray(x::NamedTuple{(:parent,)}, iperm) = x.parent
# _PermutedDimsArray(bc::Broadcast.Broadcasted, iperm) = _Pe