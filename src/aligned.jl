abstract type AlignedStyle{W<:WalkStyle} end

struct DefaultAlignedStyle{W} <: AlignedStyle{W}
    walkstyle::W
end

const ALIGNED = Union{AlignedStyle, Type{<:AlignedStyle}, DefaultAlignedStyle}

WalkStyle(style::DefaultAlignedStyle) = style.walkstyle
WalkStyle(::AlignedStyle{W}) where W = W()
WalkStyle(::Type{AlignedStyle}) = WalkStyle
WalkStyle(::Type{<:AlignedStyle{W}}) where W = W()

constructor(s::ALIGNED, x::T, y::T, z::T...) where T = T
constructor(s::ALIGNED, x::NamedTuple{name}, y::NamedTuple{name}, z::NamedTuple{name}...) where name = NamedTuple{name}
constructor(s::ALIGNED, x::Union{NamedTuple, Tuple}, y::Union{NamedTuple, Tuple}, z::Union{NamedTuple, Tuple}...) = Tuple
constructor(s::ALIGNED, x, y, z...) = identity

function children(style::ALIGNED, x)
    wstyle = WalkStyle(style)
    xc = children(wstyle, x)
    x_is_c = iscontainer(wstyle, x)
    return x_is_c ? length(xc) == 1 ? xc[1] : Iterators.flatten(xc) : xc
end
children(style::ALIGNED, x, y) = (children(style, x), children(style, y))
children(style::ALIGNED, x, y, z, w...) = (children(style, x), children(style, y, z, w...)...)

alignedstyle(x, y, z...) = alignedstyle(AlignedStyle, x, y, z...)
function alignedstyle(style::ALIGNED, x, y, z...)
    T = constructor(style, x, y, z...)
    C = children(style, x, y, z...)
    return T, zip(C...)
end

walk(f, style::ALIGNED, inner_walk, x, y, z...) = walk(f, f, style, inner_walk, x, y, z...)
function walk(f, g, style::ALIGNED, inner_walk, x, y, z...)
    T, C = alignedstyle(style, x, y, z...)
    isleaf = isempty(C)
    if isleaf
        return f((x, y, z...))
    else
        return g(T(map(inner_walk, C)))
    end
end

postwalk(f, x, y, z...) = postwalk(f, AlignedStyle, x, y, z...)
postwalk(f, style::WalkStyle, x, y, z...) = postwalk(f, DefaultAlignedStyle(style), x, y, z...)
postwalk(f, style::ALIGNED, x, y, z...) = walk(f, style, x -> postwalk(f, style, x...), x, y, z...)

prewalk(f, x, y, z...) = prewalk(f, AlignedStyle, x, y, z...)
prewalk(f, style::WalkStyle, x, y, z...) = prewalk(f, DefaultAlignedStyle(style), x, y, z...)
prewalk(f, style::ALIGNED, x) = walk(identity, style, x -> prewalk(f, style, x...), f(x), f(y), map(f, z)...)

mapleaves(f, x, y, z...) = mapleaves(f, AlignedStyle, x, y, z...)
mapleaves(f, style::WalkStyle, x, y, z...) = mapleaves(f, DefaultAlignedStyle(style), x, y, z...)
mapleaves(f, style::ALIGNED, x, y, z...) = walk(f, identity, style, x -> mapleaves(f, style, x...), x, y, z...)

mapnonleaves(f, x, y, z...) = mapnonleaves(f, AlignedStyle, x, y, z...)
mapnonleaves(f, style::WalkStyle, x, y, z...) = mapnonleaves(f, DefaultAlignedStyle(style), x, y, z...)
mapnonleaves(f, style::ALIGNED, x, y, z...) = walk(identity, f, style, x -> mapnonleaves(f, style, x...), x, y, z...)
