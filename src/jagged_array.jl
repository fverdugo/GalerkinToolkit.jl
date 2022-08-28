
"""
    prefix!(a)

Sets `a[1]=1` and then `a[i+1]=a[i]` for `i in 1:length(a)`.
"""
function prefix!(a)
  a[1] = one(eltype(a))
  n = length(a)
  @inbounds for i in 1:(n-1)
    a[i+1] += a[i]
  end
  a
end

"""
    rewind!(a)

Sets `a[i+1]=a[i]` for `i in (length(a)-1):-1:1` and finally `a[1]=1`.
"""
function rewind!(a)
  n = length(a)
  @inbounds for i in (n-1):-1:1
    a[i+1] = a[i]
  end
  a[1] = one(eltype(a))
  a
end

"""
    struct GenericJaggedArray{V,A,B}

Generalization of `JaggedArray`, where the fields `data` and `ptrs` are allowed to be any array-like
object.

# Properties
    data::A
    ptrs::B

# Supertype hierarchy

    GenericJaggedArray{V,A,B} <: AbstractVector{V}

Given `a::GenericJaggedArray`, `V` is `typeof(view(a.data,a.ptrs[i]:(a.ptrs[i+1]-1)))`.
"""
struct GenericJaggedArray{T,A,B} <: AbstractVector{T}
  data::A
  ptrs::B
  @doc """
      GenericJaggedArray(data,ptrs)

  Create a `GenericJaggedArray` from the given `data` and `ptrs` fields.
  The resulting object stores references to the given vectors.
  """
  function GenericJaggedArray(data,ptrs)
    Tp = eltype(ptrs)
    T = typeof(view(data,Tp(1):Tp(0)))
    A = typeof(data)
    B = typeof(ptrs)
    new{T,A,B}(data,ptrs)
  end
  function GenericJaggedArray{T,A,B}(data::A,ptrs::B) where {T,A,B}
    new{T,A,B}(data,ptrs)
  end
end

"""
    struct JaggedArray{T,Ti}

Efficient implementation of a vector of vectors. The inner vectors are stored one after the other
in consecutive memory locations using an auxiliary vector `data`. The range of indices corresponding
to each inner vector are encoded using a vector of integers `ptrs`.

# Properties
    data::Vector{T}
    ptrs::Vector{Ti}

Given `a::JaggedArray`, `a.data` contains the inner vectors. The `i`-th inner vector is stored in the
range `a.ptrs[i]:(a.ptrs[i+1]-1)`. The number of inner vectors (i.e. `length(a)`) is `length(a.ptrs)-1`.
`a[i]` returns a view of `a.data` restricted to the range `a.ptrs[i]:(a.ptrs[i+1]-1)`.

# Supertype hierarchy

    JaggedArray{T,Ti} <: AbstractVector{V}

Given `a::JaggedArray`, `V` is `typeof(view(a.data,a.ptrs[i]:(a.ptrs[i+1]-1)))`.

"""
struct JaggedArray{T,Ti} <: AbstractVector{SubArray{T,1,Vector{T},Tuple{UnitRange{Ti}},true}}
  data::Vector{T}
  ptrs::Vector{Ti}
  @doc """
      JaggedArray(data::Vector,ptrs::Vector)

  Create a `JaggedArray` from the given `data` and `ptrs` fields.
  The resulting object stores references to the given vectors.
  """
  function JaggedArray(data::Vector{T},ptrs::Vector{Ti}) where {T,Ti}
    new{T,Ti}(data,ptrs)
  end
  function JaggedArray{T,Ti}(data::Vector{T},ptrs::Vector{Ti}) where {T,Ti}
    new{T,Ti}(data,ptrs)
  end
end

"""
    JaggedArray(a)

Create a `JaggedArray` object from the vector of vectors `a`. If `a::JaggedArray`, then `a` is returned.
Otherwise, the contents of `a` are copied.
"""
JaggedArray(a::AbstractArray{<:AbstractArray{T}}) where T = JaggedArray{T,Int32}(a)
JaggedArray(a::JaggedArray) = a

JaggedArray{T,Ti}(a::JaggedArray{T,Ti}) where {T,Ti} = a
function JaggedArray{T,Ti}(a::AbstractArray{<:AbstractArray}) where {T,Ti}
  n = length(a)
  ptrs = Vector{Ti}(undef,n+1)
  u = one(eltype(ptrs))
  @inbounds for i in 1:n
    ai = a[i]
    ptrs[i+1] = length(ai)
  end
  prefix!(ptrs)
  ndata = ptrs[end]-u
  data = Vector{T}(undef,ndata)
  p = 1
  @inbounds for i in 1:n
    ai = a[i]
    for j in 1:length(ai)
      aij = ai[j]
      data[p] = aij
      p += 1
    end
  end
  JaggedArray(data,ptrs)
end


Base.size(a::Union{JaggedArray,GenericJaggedArray}) = (length(a.ptrs)-1,)
function Base.getindex(a::Union{JaggedArray,GenericJaggedArray},i::Integer)
  u = one(eltype(a.ptrs))
  pini = a.ptrs[i]
  pend = a.ptrs[i+1]-u
  view(a.data,pini:pend)
end
function Base.convert(::Type{J},vv) where J<:GenericJaggedArray
  a = JaggedArray(vv)
  J(a.data,a.ptrs)
end
function Base.convert(::Type{J},vv) where J<:JaggedArray
  J(vv)
end
function Base.convert(::Type{J},vv::J) where J<:GenericJaggedArray
  vv
end
function Base.convert(::Type{J},vv::J) where J<:JaggedArray
  vv
end

"""
    jagged_array(data,ptrs)

Create a `JaggedArray` or a `GenericJaggedArray` object depending on the type of `data` and `ptrs`.
The returned object stores references to the given inputs.
"""
jagged_array(data,ptrs) = GenericJaggedArray(data,ptrs)
jagged_array(data::Vector,ptrs::Vector) = JaggedArray(data,ptrs)


