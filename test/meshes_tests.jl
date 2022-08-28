module MeshesTests

using GalerkinToolkit
using Meshes
using Test

grid = CartesianGrid(3,3)

mesh = fe_mesh(grid)

groups = physical_groups(mesh)
@test physical_group_faces(groups,0,3) == [4]
@test physical_group_faces(groups,1,5) == [1,3,4]
@test face_nodes(mesh,0) == [[1],[4],[13],[16]]
@test face_nodes(mesh,1) == [[1,2],[5,1],[2,3],[3,4],[4,8],[9,5],[8,12],[14,13],[13,9],[15,14],[12,16],[16,15]]
@test face_nodes(mesh,2) == [[1,2,6,5],[2,3,7,6],[3,4,8,7],[5,6,10,9],[6,7,11,10],[7,8,12,11],[9,10,14,13],[10,11,15,14],[11,12,16,15]]
ref_faces(mesh,0)
ref_faces(mesh,1)
ref_faces(mesh,2)
face_ref_id(mesh,0)
face_ref_id(mesh,1)
face_ref_id(mesh,2)
@test has_periodic_nodes(mesh) == false
@test has_hanging_nodes(mesh) == false

mesh = fe_mesh(grid,is_periodic=(true,false))
@test has_periodic_nodes(mesh) == true
info = periodic_nodes(mesh)
@test info.periodic == [4,8,12,16]
@test info.master == [1,5,9,13]
@test info.coeff == [1,1,1,1]

mesh = fe_mesh(grid,is_periodic=(false,true))
@test has_periodic_nodes(mesh) == true
info = periodic_nodes(mesh)
@test info.periodic == [13,14,15,16]
@test info.master == [1,2,3,4]
@test info.coeff == [1,1,1,1]

mesh = fe_mesh(grid,is_periodic=(true,true))
@test has_periodic_nodes(mesh) == true
info = periodic_nodes(mesh)
@test info.periodic == [4,8,12,16,14,15]
@test info.master == [1,5,9,13,2,3]
@test info.coeff == [1,1,1,1,1,1]

#i_to_physical_groupid = [9,3,5,1]
#node_to_i = classify_nodes(mesh,i_to_physical_groupid)
#@test i_to_physical_groupid[node_to_i] == [1,5,5,5,9,9,9,9,9,9,9,9,9,9,9,3]


end # module
