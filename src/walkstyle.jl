expr_constructor(head, args) = Expr(head, args...)

constructor(::Type{WalkStyle}, x::Tuple) = Tuple
constructor(::Type{WalkStyle}, x::NamedTuple) = let name = keys(x); x->NamedTuple{name}(x); end
constructor(::Type{WalkStyle}, x::Expr) = expr_constructor

children(::Type{WalkStyle}, x::AbstractArray) = (x,)
children(::Type{WalkStyle}, x::Tuple) = (x,)
children(::Type{WalkStyle}, x::NamedTuple) = (x,)
children(::Type{WalkStyle}, x::AbstractDict) = ((p for p in x),)

for type in :(
    AbstractArray,
    AbstractDict,
    Tuple,
    NamedTuple,
).args
    @eval iscontainer(::Type{WalkStyle}, x::$type) = true
end
