
function domain_dim end
function ambient_dim end
function face_ref_id end
function ref_faces end
function face_incidence end
function face_nodes end
function face_own_nodes end
function node_coordinates end
function periodic_nodes end
function hanging_nodes end
function is_hanging end
function is_periodic end
function num_faces end
function num_nodes end
function is_simplex end
function is_hypercube end
function vertex_node end
function node_vertex end
function group_faces end
function group_name end
function group_names end
function group_id end
function group_ids end
function add_group! end
function group_faces! end

function ref_face_incidence(mesh,rank,m,n)
  refid_to_refface = ref_faces(mesh,ranl)
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

default_is_simplex(geo) = false
default_is_hypercube(geo) = false
default_is_hanging(geo) =  length(first(hanging_nodes(geo)))>0
default_hanging_nodes(geo) = (Int32[],JaggedArray(Vector{Int32}[]))
default_is_periodic(geo) = length(first(periodic_nodes(geo)))>0
default_periodic_nodes(geo) = (Int32[],Int32[])
default_num_faces(geo,rank) = length(face_ref_id(geo,rank))
default_num_nodes(geo) = length(node_coordinates(geo))
default_ambient_dim(geo) = length(eltype(node_coordinates(geo)))

is_simplex(geo) = default_is_simplex(geo)
is_hypercube(geo) = default_is_hypercube(geo)
is_hanging(geo) = default_is_hanging(geo)
hanging_nodes(geo) = default_hanging_nodes(geo)
is_periodic(geo) = default_is_periodic(geo)
periodic_nodes(geo) = default_periodic_nodes(geo)
num_faces(geo,rank) = default_num_faces(geo,rank)
num_nodes(geo) = default_num_nodes(geo)
ambient_dim(geo) = default_ambient_dim(geo)

struct GroupCollection
  domain_dim::Int
  group_names::Dict{Int,String}
  group_ids::Dict{String,Int}
  group_faces::Dict{Int,Vector{Vector{Int32}}}
end

struct EmptyInitializer end

const void = EmptyInitializer()

function GroupCollection(::EmptyInitializer,rank::Int)
  GroupCollection(
    rank,
    Dict{Int,String}(),
    Dict{String,Int}(),
    Dict{Int,Vector{Vector{Int32}}}())
end

function add_group!(g::GroupCollection,name,id)
  haskey(g.group_names,id) && error("id $id already present in GroupCollection")
  haskey(g.group_ids,name) && error("Name $name alreade present in GroupCollection")
  g.group_names[id] = name
  g.group_ids[name] = id
  g.group_faces[id] = fill(Int32[],g.domain_dim+1)
end

function add_group!(g::GroupCollection,name)
  if length(g.group_ids) == 0
    id = 1
  else
    id = maximum(g.group_ids) + 1
  end
  add_group!(g,name,id)
end

domain_dim(g::GroupCollection) = g.domain_dim
group_id(g::GroupCollection,name::String) = g.group_ids[name]
group_id(g::GroupCollection,id::Int) = id
group_name(g::GroupCollection,name::String) = name
group_name(g::GroupCollection,id::Int) = g.group_names[id]
group_names(g::GroupCollection) = sort(collect(values(g.group_names)))
group_ids(g::GroupCollection) = sort(collect(values(g.group_ids)))

function group_faces(g::GroupCollection,name,rank)
  id = group_id(g,name)
  g.group_faces[id][rank+1]
end

function group_faces!(g::GroupCollection,faces,name,rank)
  id = group_id(g,name)
  g.group_faces[id][rank+1] = faces
  faces
end

mutable struct SimpleFEMesh{T}
  domain_dim::Int
  node_coordinates::Vector{T}
  face_nodes::Vector{JArray{Int32}}
  face_ref_id::Vector{Vector{Int8}}
  ref_faces::Vector{Vector{Any}}
  periodic_nodes::Tuple{Vector{Int32},Vector{Int32}}
  hanging_nodes::Tuple{Vector{Int32},JArray{Int32}}
  physical_groups::GroupCollection
end

function SimpleFEMesh{T}(::EmptyInitializer,rank) where T
  SimpleFEMesh(
    rank,
    zeros(T,0),
    [ JaggedArray(Vector{Int32}[]) for i in 1:(rank+1)],
    [ Int8[] for i in 1:(rank+1)],
    [ Any[] for i in 1:(rank+1)],
    (Int32[],Int32[]),
    (Int32[],JaggedArray(Vector{Int32}[])),
    GroupCollection(void,rank))
end

domain_dim(m::SimpleFEMesh) = m.domain_dim
node_coordinates(m::SimpleFEMesh) = m.node_coordinates
face_nodes(m::SimpleFEMesh,rank) = m.face_nodes[rank+1]
face_ref_id(m::SimpleFEMesh,rank) = m.face_ref_id[rank+1]
ref_faces(m::SimpleFEMesh,rank) = m.ref_faces[rank+1]
periodic_nodes(m::SimpleFEMesh) = m.periodic_nodes
hanging_nodes(m::SimpleFEMesh) = m.periodic_nodes
physical_groups(m::SimpleFEMesh) = m.physical_groups

node_coordinates!(m::SimpleFEMesh,v) = (m.node_coordinates = v)
face_nodes!(m::SimpleFEMesh,v,rank) = (m.face_nodes[rank+1] = v)
face_ref_id!(m::SimpleFEMesh,v,rank) = (m.face_ref_id[rank+1] = v)
ref_faces!(m::SimpleFEMesh,v,rank) = (m.ref_faces[rank+1] = v)
periodic_nodes!(m::SimpleFEMesh,v) = (m.periodic_nodes = v)
hanging_nodes!(m::SimpleFEMesh,v) = (m.periodic_nodes = v)
physical_groups!(m::SimpleFEMesh,v) = (m.physical_groups = v)






function fe_mesh end


