# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

const UnsafeArray{T,N} = Union{DenseUnsafeArray{T,N}}

export UnsafeArray


@doc doc"""
    uview(A::AbstractArray, I...)

Unsafe equivalent of `view`. May return an `UnsafeArray`, a standard
`SubArray` or `A` itself, depending on `I...` and the type of `A`.

As `uview` may return an `UnsafeArray`, `A` itself and it's contents *must* be
protected from garbage collection (e.g. via `GC.@preserve` on Julia > v0.6)
and memory reallocation while the view is in use.

Use `uviews(f::Function, As::AbstractArray...)` to use `uview`s of one or
multiple arrays with automatically GC protection.

```
uview(A, B, ...) do (A_u, B_u, ...)
    # Do something with the unsafe views A_u, B_u, ...
    # Code here must not resize/append/etc. A, B, ...
end
```

To provide support for `uview` for custom array types, add methods to
function `UnsafeArrays.unsafe_uview`.
"""
function uview end
export uview

Base.@propagate_inbounds uview(A::AbstractArray) = unsafe_uview(A)

Base.@propagate_inbounds function uview(A::AbstractArray, idx, I...)
    J = Base.to_indices(A, (idx, I...))
    @boundscheck checkbounds(A, J...)
    unsafe_uview(A, J...)
end


Base.@propagate_inbounds uview(A::UnsafeArray) = A


@doc doc"""
    uviews(f::Function, As::AbstractArray...)

Equivalent to `f(map(uview, As)...)`. Automatically protects the array(s)
`As` from garbage collection during execution of `f`.

Example:

```
uviews(A, B, ...) do (A_u, B_u, ...)
    # Do something with the unsafe views A_u, B_u, ...
    # Code here must not resize/append/etc. A, B, ...
end
```
"""
function uviews end
export uviews

@inline function uviews(f::Function, As::AbstractArray...)
    @static if VERSION >= v"0.7.0-DEV.3465"
        GC.@preserve(As, f(map(uview, As)...))
    else
        try
            f(map(uview, As)...)
        finally
            _noinline_nop(As)
        end
    end
end


@doc doc"""
    UnsafeArray.unsafe_uview(A::AbstractArray, I::Vararg{Base.ViewIndex,N})
    UnsafeArray.unsafe_uview(A::AbstractArray, i::Base.ViewIndex)
    UnsafeArray.unsafe_uview(A::AbstractArray)

To support `uview` for custom array types, add methods to `unsafe_uview`
instead of `uview`. Implementing
`UnsafeArray.unsafe_uview(A::CustomArrayType)` will often be sufficient.
"""
function unsafe_uview end

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, I::Vararg{Base.ViewIndex,N}) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), I...)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}, i) where {T,N} =
    Base.unsafe_view(unsafe_uview(A), i::Base.ViewIndex)

Base.@propagate_inbounds unsafe_uview(A::AbstractArray{T,N}) where {T,N} = A

Base.@propagate_inbounds unsafe_uview(A::UnsafeArray{T,N}) where {T,N} = A


@doc doc"""
    @uview A[inds...]

Unsafe equivalent of `@view`. Uses `uview` instead of `view`.
"""
macro uview(ex)
    # From Julia Base (same implementation, but using uview):

    if Meta.isexpr(ex, :ref)
        ex = Base.replace_ref_end!(ex)
        if Meta.isexpr(ex, :ref)
            ex = Expr(:call, view, DenseUnsafeArray, ex.args...)
        else # ex replaced by let ...; foo[...]; end
            assert(Meta.isexpr(ex, :let) && Meta.isexpr(ex.args[2], :ref))
            ex.args[2] = Expr(:call, uview, ex.args[2].args...)
        end
        Expr(:&&, true, esc(ex))
    else
        throw(ArgumentError("Invalid use of @view macro: argument must be a reference expression A[...]."))
    end
end

export @uview
