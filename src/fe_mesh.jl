
"""
   const INVALID_ID::Int

Stores an invalid linear index for 1-based indexed objects.
`INVALID_ID` is some number less than `1`. The user should not rely on the
specific value.
"""
const INVALID_ID = -1

"""
    domain_dim(geo)
Return the number of space dimensions of the geometrical object `geo`.
"""
function domain_dim end

"""
    ambient_dim(geo)
Return the number of dimensions of the ambient space,
where the geometrical object `geo` is embedded.
"""
function ambient_dim end

"""
    ref_faces(geo,rank)

Return a vector with the reference faces of rank `rank`
associated with the geometrical object `geo`.
"""
function ref_faces end

"""
    face_ref_id(geo,rank)
Return a vector of integer ids, indicating which is the reference face
for each face of rank `rank` in the geometrical object `geo`. I.e.,

    id_to_ref_face = ref_faces(geo,rank)
    face_to_id = face_ref_id(geo,rank)
    ref_face = id_to_ref_face[face_to_id[face]]

`ref_face` is the reference face associated with face number `face` of rank `rank` in `geo`.
"""
function face_ref_id end

"""
    face_nodes(geo,rank)
Return the face connectivities for faces of rank `rank` in `geo`. The result is a vector of vectors
that can be indexed with a face id, returning the node ids of the nodes on the *closure* of this face.
"""
function face_nodes end

"""
    face_own_nodes(geo,rank)
Like `face_nodes(geo,rank)`, but it returns node ids in the *interior* of the faces in `geo`.
"""
function face_own_nodes end

"""
    node_coordinates(geo)
Return a vector with the nodal coordinates of the nodes in `geo`.
"""
function node_coordinates end

"""
    info = periodic_nodes(geo)
Returns information about periodic nodes in `geo`.
- `info.periodic` is a vector with the node ids of periodic nodes.
- `info.master` is a vector containing the corresponding master ids.
- `info.coff` is a vector containing the scaling between a master node and is periodic node (usually a vector of `1.0`).
"""
function periodic_nodes end


function hanging_nodes end
function is_hanging end
function is_periodic end
function num_faces end
function num_nodes end
function is_simplex end
function is_hypercube end
function physical_group_faces end
function physical_group_name end
function physical_group_dim end
function physical_group_dims end
function physical_group_names end
function physical_group_id end
function physical_group_ids end
function new_physical_group! end
function physical_group_faces! end
function face_incidence end
function face_vertices end

function ref_face_incidence(mesh,rank,m,n)
  refid_to_refface = ref_faces(mesh,rank)
  map(rf->face_incidence(rf,m,n),refid_to_refface)
end
function ref_face_nodes(mesh,rank,m)
  refid_to_refface = ref_faces(mesh,rank)
  map(rf->face_nodes(rf,m),refid_to_refface)
end
function ref_face_own_nodes(mesh,rank,m)
  refid_to_refface = ref_faces(mesh,rank)
  map(rf->face_own_nodes(rf,m),refid_to_refface)
end

struct PeriodicNodeCollection{Ti,T}
  periodic::Vector{Ti}
  master::Vector{Ti}
  coeff::Vector{T}
end

function PeriodicNodeCollection{Ti,T}() where {Ti,T}
  PeriodicNodeCollection(Ti[],Ti[],T[])
end

struct HangingNodeCollection{Ti,T}
  hanging::Vector{Ti}
  masters::JaggedArray{Ti,Int32}
  coeffs::JaggedArray{Ti,Int32}
end

function HangingNodeCollection{Ti,T}() where {Ti,T}
  HangingNodeCollection(
    Ti[],
    JaggedArray([Ti[]]),
    JaggedArray([T[]]))
end

default_is_simplex(geo) = false
default_is_hypercube(geo) = false
default_is_hanging(geo) =  length(first(hanging_nodes(geo)))>0
default_hanging_nodes(geo) = HangingNodeCollection{Int32,Float64}()
default_is_periodic(geo) = length(first(periodic_nodes(geo)))>0
default_periodic_nodes(geo) = PeriodicNodeCollection{Int32,Float64}()
default_num_faces(geo,rank) = length(face_ref_id(geo,rank))
default_num_nodes(geo) = length(node_coordinates(geo))
default_ambient_dim(geo) = length(eltype(node_coordinates(geo)))
default_physical_groups(geo) = PhysicalGroupCollection(domain_dim(geo))

is_simplex(geo) = default_is_simplex(geo)
is_hypercube(geo) = default_is_hypercube(geo)
is_hanging(geo) = default_is_hanging(geo)
hanging_nodes(geo) = default_hanging_nodes(geo)
is_periodic(geo) = default_is_periodic(geo)
periodic_nodes(geo) = default_periodic_nodes(geo)
num_faces(geo,rank) = default_num_faces(geo,rank)
num_nodes(geo) = default_num_nodes(geo)
ambient_dim(geo) = default_ambient_dim(geo)

struct PhysicalGroupCollection{Ti}
  physical_group_name::Vector{Dict{Int,String}}
  physical_group_id::Vector{Dict{String,Int}}
  physical_group_faces::Vector{Dict{Int,Vector{Ti}}}
end
physical_groups(a::PhysicalGroupCollection) = a
domain_dim(a::PhysicalGroupCollection) = length(a.physical_group_id)-1

function PhysicalGroupCollection(dim::Integer)
  PhysicalGroupCollection{Int32}(dim)
end

function PhysicalGroupCollection{Ti}(dim::Integer) where Ti
  PhysicalGroupCollection(
    [Dict{Int,String}() for d in 0:dim],
    [Dict{String,Int}() for d in 0:dim],
    [Dict{Int,Vector{Ti}}() for d in 0:dim])
end

physical_group_faces(g::PhysicalGroupCollection,d,name) = g.physical_group_faces[d+1][physical_group_id(g,d,name)]
physical_group_faces!(g::PhysicalGroupCollection,faces,d,name) = (g.physical_group_faces[d+1][physical_group_id(g,d,name)] = faces)
physical_group_id(g::PhysicalGroupCollection,d,name::AbstractString) = g.physical_group_id[d+1][String(name)]
physical_group_name(g::PhysicalGroupCollection,d,id::Integer) = g.physical_group_name[d+1][Int(id)]
has_physical_group(g,d,name::String) = haskey(g.physical_group_id[d+1],name)
has_physical_group(g,d,id::Int) = haskey(g.physical_group_name[d+1],id)
function physical_group_id(g::PhysicalGroupCollection,d,id::Integer)
  @assert haskey(g.physical_group_name[d+1],Int(id))
  id
end
function physical_group_name(g::PhysicalGroupCollection,d,name::AbstractString)
  @assert haskey(g.physical_group_id[d+1],String(name))
  name
end
function physical_group_names(g::PhysicalGroupCollection,d)
  ids = physical_group_ids(g,d)
  [ g.physical_group_name[d+1][i] for i in ids]
end
function physical_group_ids(g::PhysicalGroupCollection,d)
  sort(collect(keys(g.physical_group_name[d+1])))
end

function new_physical_group_id(g::PhysicalGroupCollection)
  function maxid(dict)
    if length(dict) == 0
      id = 0
    else
      id = maximum(values(dict))
    end
  end
  id = maximum(map(maxid,g.physical_group_id))+1
  id
end

function new_physical_group!(g::PhysicalGroupCollection,d,name,id=new_physical_group_id(g))
  haskey(g.physical_group_name[d+1],id) && error("id $id already present in PhysicalGroupCollection for dimension $d")
  haskey(g.physical_group_id[d+1],name) && error("Name $name already present in PhysicalGroupCollection for dimension $d")
  g.physical_group_name[d+1][id] = name
  g.physical_group_id[d+1][name] = id
  g.physical_group_faces[d+1][id] = Int32[]
end

function classify_nodes(mesh,ids;boundary=fill(true,length(ids)))
  D = domain_dim(mesh)
  groups = physical_groups(mesh)
  i_to_id = ids
  ni = length(i_to_id)
  nnodes = num_nodes(mesh)
  node_to_i = fill(Int32(INVALID_ID),nnodes)
  for d = D:-1:0
    for i in 1:ni
      id = i_to_id[i]
      if !has_physical_group(groups,d,id)
        continue
      end
      nodes = physical_group_nodes(mesh,d,id;boundary=boundary[i])
      node_to_i[nodes] .= i
    end
  end
  node_to_i
end

function physical_group_nodes(mesh,d,id;boundary=true)
  if boundary
    physical_group_nodes_with_boundary(mesh,d,id)
  else
    physical_group_nodes_without_boundary(mesh,d,id)
  end
end

function physical_group_nodes_with_boundary(mesh,d,id)
  function _barrier(nnodes,face_to_nodes,faces_in_physical_group)
    node_to_mask = fill(false,nnodes)
    for face in faces_in_physical_group
      nodes = face_to_nodes[face]
      for node in nodes
        node_to_mask[node] = true
      end
    end
    collect(Int32,findall(node_to_mask))
  end
  groups = physical_groups(mesh)
  faces_in_physical_group = physical_group_faces(groups,d,id)
  face_to_nodes = face_nodes(mesh,d)
  nnodes = num_nodes(mesh)
  _barrier(nnodes,face_to_nodes,faces_in_physical_group)
end

function physical_group_nodes_without_boundary(mesh,d,id)
  error("Not implemented.")
  # 1. Compute nodes with boundary
  # 2. Identify d-1 faces on the boundary of the group
  # 3. Collect nodes from faces computed in 2.
  # 4. Subtract from nodes computed in 1.
  # Setp 2. would require to compute the polytopal complex
  #polycom = polytopal_complex(mesh)
end

function fe_mesh end

# We can add this one if we need generic
# fields
#mutable struct GenericFEMesh{}
#end

mutable struct FEMesh{T,Ti,Tf}
  domain_dim::Int
  node_coordinates::Vector{T}
  face_nodes::Vector{JaggedArray{Ti}}
  face_ref_id::Vector{Vector{Int8}}
  ref_faces::Vector{Vector{Any}}
  periodic_nodes::Tuple{Vector{Ti},Vector{Ti},Vector{Tf}}
  hanging_nodes::Tuple{Vector{Ti},JaggedArray{Ti},JaggedArray{Tf}}
  physical_groups::PhysicalGroupCollection
  buffer::Dict{Symbol,Any}
end
fe_mesh(a::FEMesh) = a

function FEMesh{T}(rank) where T
  FEMesh{T,Int32,Float64}(rank)
end

function FEMesh{T,Ti,Tf}(rank) where {T,Ti,Tf}
  FEMesh(
    rank,
    zeros(T,0),
    [ GenericJaggedArray(Vector{Ti}[]) for i in 1:(rank+1)],
    [ Int8[] for i in 1:(rank+1)],
    [ Any[] for i in 1:(rank+1)],
    (Ti[],Ti[],Tf[]),
    (Ti[],GenericJaggedArray(Vector{Ti}[]),GenericJaggedArray(Vector{Tf}[])),
    PhysicalGroupCollection(rank),
    Dict{Symbol,Any}()
   )
end

domain_dim(m::FEMesh) = m.domain_dim
node_coordinates(m::FEMesh) = m.node_coordinates
face_nodes(m::FEMesh,rank) = m.face_nodes[rank+1]
face_ref_id(m::FEMesh,rank) = m.face_ref_id[rank+1]
ref_faces(m::FEMesh,rank) = m.ref_faces[rank+1]
periodic_nodes(m::FEMesh) = m.periodic_nodes
hanging_nodes(m::FEMesh) = m.hanging_nodes
physical_groups(m::FEMesh) = m.physical_groups

node_coordinates!(m::FEMesh,v) = (m.node_coordinates = v)
face_nodes!(m::FEMesh,v,rank) = (m.face_nodes[rank+1] = v)
face_ref_id!(m::FEMesh,v,rank) = (m.face_ref_id[rank+1] = v)
ref_faces!(m::FEMesh,v,rank) = (m.ref_faces[rank+1] = v)
periodic_nodes!(m::FEMesh,v) = (m.periodic_nodes = v)
hanging_nodes!(m::FEMesh,v) = (m.hanging_nodes = v)
physical_groups!(m::FEMesh,v) = (m.physical_groups = v)

function polytopal_complex(m::FEMesh)
  if !haskey(m.buffer,:polytopal_complex)
    polycomplex = PolyComplexFromFEMesh(m)
    m.buffer[:polytopal_complex] = polycomplex
  end
  m.buffer[:polytopal_complex]
end
