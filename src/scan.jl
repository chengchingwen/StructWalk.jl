function walkby(f, g, h, style::WALKSTYLE, inner_scan, x)
    _, fields, iscontainer = walkstyle(style, x)
    isleaf = isempty(fields)
    if isleaf
        f(x)
    else
        g(x)
        _h = iscontainer ? Base.Fix1(map, inner_scan) : inner_scan
        foreach(_h, fields)
        h(x)
    end
    return nothing
end

function walkby(f, g, h, style::ALIGNED, inner_scan, x, y, z...)
    _, C = alignedstyle(style, x, y, z...)
    isleaf = isempty(C)
    X = (x, y, z...)
    if isleaf
        f(X)
    else
        g(X)
        foreach(inner_scan, C)
        h(X)
    end
    return nothing
end


"""
    scan(f, [g = f, style = WalkStyle], x)    

Walk through `x` without constructing anything and applying `f` to leaf nodes and
`g` to every other node.
"""
scan(f, x) = scan(f, WalkStyle, x)
scan(f, style::WALKSTYLE, x) = scan(f, f, style, x)
scan(f, g, style::WALKSTYLE, x) = scan(f, g, identity, style, x)
scan(f, g, h, style::WALKSTYLE, x) = walkby(f, g, h, style, x -> scan(f, g, h, style, x), x)

scan(f, x, y, z...) = scan(f, AlignedStyle, x, y, z...)
scan(f, style::WalkStyle, x, y, z...) = scan(f, DefaultAlignedStyle(style), x, y, z...)
scan(f, g, style::WalkStyle, x, y, z...) = scan(f, g, DefaultAlignedStyle(style), x, y, z...)
scan(f, g, h, style::WalkStyle, x, y, z...) = scan(f, g, h, DefaultAlignedStyle(style), x, y, z...)
scan(f, style::ALIGNED, x, y, z...) = scan(f, f, style, x, y, z...)
scan(f, g, style::ALIGNED, x, y, z...) = scan(f, g, identity, style, x, y, z...)
scan(f, g, h, style::ALIGNED, x, y, z...) = walkby(f, g, h, style, x -> scan(f, g, h, style, x...), x, y, z...)
