walkstyle(::Type{WalkStyle}, x::T) where {T <: AbstractArray} = t->convert(AbstractArray, t), (x,), true
walkstyle(::Type{WalkStyle}, x::T) where {T <: Tuple} = Tuple, (x,), true
walkstyle(::Type{WalkStyle}, x::T) where {T <: NamedTuple} = let name=keys(x); x->NamedTuple{name}(x); end, (x,), true
walkstyle(::Type{WalkStyle}, x::Expr) = (head, args)->Expr(head, args...), (x.head, x.args)
walkstyle(::Type{WalkStyle}, x::T) where {T <: AbstractDict} = Dict, ((p for p in x),), true
