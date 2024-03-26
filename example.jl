"""
TODO:
3D cartesian and naming and gmsh

geometry.jl
geometry_test.jl # clean up example.jl
descriptive names for assets and geo files
2D square_<square, triangl>_4x4
3D  

# example naming convention, only include refcell info in the mesh fname, not the geo fname
[unit_cell_mesh, two_level_mesh]_<dimension>_[periodic,nonperiodic]_[gmsh,glk]\
    _<shape, e.g., puzzlepiece, square>_shape_[quad, triangle]\
    _[mesh dims]_refcell.[geo, msh, vtu]

for testing correctness of outputs:
   given a julia object, store the integer for correct object contents (find this func, not ash)   
    take some example node ids and corresponding coordinates of interface nodes against
        the hardcoded physical coordinates that would be expected for those points

can use PartitionedArraysBenchmarks/benchmarks.jl as reference

mesh generation should be of order of multigrid solver example02

loading of sequential total mesh 

parallel mesh support in gmsh?

Go through assets/ and remove unneeded geos/meshes 

Test using puzzle piece mesh??

Make 3D periodic cube
"""
module TMP

import GalerkinToolkit as gk
using WriteVTK
using Test

function test_two_level_mesh_with_nonperiodic_square_unit_cell()
    # corresponds to 2D cell in glk mesh
    cell_dim = 2

    # initialize 1x1 coarse mesh
    coarse_domain = (0,10,0,10)
    coarse_mesh_dims = (1,1)
    coarse_mesh = gk.cartesian_mesh(coarse_domain,coarse_mesh_dims)
    coarse_cell_vtk_fname_1x1 = "coarse_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_1x1_refcell"

    # initialize 4x4 glk unit cell mesh  
    unit_cell_domain = (0,1,0,1)
    unit_cell_dims = (4,4)
    unit_cell_mesh = gk.cartesian_mesh(unit_cell_domain, unit_cell_dims) 

    # visualize the glk unit cell 
    unit_cell_vtk_fname = "unit_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_4x4_refcell"
    visualize_unit_cell_mesh(unit_cell_mesh, joinpath("output", unit_cell_vtk_fname))

    # construct the final mesh with 1x1 coarse mesh 
    final_mesh, _ = gk.two_level_mesh(coarse_mesh, unit_cell_mesh)

    # visualize final mesh with 1x1 coarse mesh
    vtk_grid(joinpath(
        "output",
        "two_level_mesh_$(unit_cell_vtk_fname)_$(coarse_cell_vtk_fname_1x1)"),
        gk.vtk_args(final_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,final_mesh)
            gk.vtk_physical_nodes!(vtk,final_mesh)
    end

    # Coordinate check for unit cell in 1x1 coarse mesh
    final_cell_to_inspect = 12 # arbitrary 
    final_cell_to_inspect_coordinates = [
        [7.5, 5.0],
        [10.0, 5.0],
        [7.5, 7.5],
        [10.0, 7.5]
    ]
    example_coordinates = coordinates(final_mesh, final_cell_to_inspect, cell_dim)
    @test example_coordinates == final_cell_to_inspect_coordinates

    # initialize 4x4 coarse mesh 
    coarse_domain = (0,10,0,10)
    coarse_mesh_dims = (4,4)
    coarse_mesh = gk.cartesian_mesh(coarse_domain,coarse_mesh_dims)
    coarse_cell_vtk_fname_4x4 = "coarse_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_4x4_refcell"

    # construct the final mesh with a 4x4 coarse mesh     
    final_mesh, _ = gk.two_level_mesh(coarse_mesh, unit_cell_mesh)

    # visualize final mesh with 4x4 coarse mesh
    vtk_grid(joinpath(
        "output",
        "two_level_mesh_$(unit_cell_vtk_fname)_$(coarse_cell_vtk_fname_4x4)"),
        gk.vtk_args(final_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,final_mesh)
            gk.vtk_physical_nodes!(vtk,final_mesh)
    end

    # Coordinate check for unit cell in 4x4 coarse mesh 
    final_cell_to_inspect = 114 # arbitrary 
    final_cell_to_inspect_coordinates = [
        [8.125, 2.5],
        [8.75, 2.5],
        [8.125, 3.125],
        [8.75, 3.125]       
    ]
    example_coordinates = coordinates(final_mesh, final_cell_to_inspect, cell_dim)
    @test example_coordinates == final_cell_to_inspect_coordinates
end 

function test_two_level_mesh_with_periodic_square_unit_cell()

    # Initialize coarse 1x1 mesh 
    coarse_domain = (0,10,0,10)
    coarse_mesh_dims = (1,1)
    coarse_mesh_1x1 = gk.cartesian_mesh(coarse_domain,coarse_mesh_dims)
    coarse_cell_vtk_fname_1x1 = "coarse_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_1x1_refcell"

    # Load periodic fine (unit cell) mesh with triangular refcells 
     unit_cell_mesh_fpath = joinpath(
        @__DIR__, 
        "assets", 
        "unit_cell_2D_periodic_square_geometry_triangular_refcell.msh")
    unit_cell_mesh = gk.mesh_from_gmsh(unit_cell_mesh_fpath)

    # visualize the periodic gmsh unit cell with triangular refcells 
    unit_cell_vtk_fname = "unit_cell_mesh_2D_periodic_gmsh_square_geometry_triangular_refcell"
    visualize_unit_cell_mesh(unit_cell_mesh, joinpath("output", unit_cell_vtk_fname))

    # visualize final mesh with 1x1 coarse mesh and periodic unit cell 
    periodic_final_mesh, _ = gk.two_level_mesh(coarse_mesh_1x1, unit_cell_mesh)

    n_nodes = gk.num_nodes(periodic_final_mesh)

    vtk_grid(
        joinpath("output",
        "two_level_mesh_$(unit_cell_vtk_fname)_$(coarse_cell_vtk_fname_1x1)"),
        gk.vtk_args(periodic_final_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,periodic_final_mesh)
            gk.vtk_physical_nodes!(vtk,periodic_final_mesh)
            vtk["node_ids"] = collect(1:n_nodes)
    end
   
    # TODO: hardcoded coordinate check

    # Initialize coarse 4x4 mesh 
    coarse_domain = (0,10,0,10)
    coarse_mesh_dims = (4,4)
    coarse_mesh_4x4 = gk.cartesian_mesh(coarse_domain,coarse_mesh_dims)
    coarse_cell_vtk_fname_4x4 = "coarse_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_4x4_refcell"

    # visualize final mesh with 4x4 coarse mesh and periodic unit cell 
    periodic_final_mesh, _ = gk.two_level_mesh(coarse_mesh_4x4, unit_cell_mesh)

    n_nodes = gk.num_nodes(periodic_final_mesh)

    vtk_grid(
        joinpath("output",
        "two_level_mesh_$(unit_cell_vtk_fname)_$(coarse_cell_vtk_fname_4x4)"),
        gk.vtk_args(periodic_final_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,periodic_final_mesh)
            gk.vtk_physical_nodes!(vtk,periodic_final_mesh)
            vtk["node_ids"] = collect(1:n_nodes)
    end

    # TODO: Check hardcoded coordinates 


end

# TODO: fails currently... check physical group naming conventions 
function test_two_level_mesh_with_periodic_puzzle_piece_unit_cell()

     # Initialize coarse mesh 
     coarse_domain = (0,10,0,10)
     coarse_mesh_dims = (4,4)
     coarse_mesh = gk.cartesian_mesh(coarse_domain,coarse_mesh_dims)
     coarse_cell_vtk_fname_4x4 = "coarse_cell_mesh_2D_nonperiodic_glk_square_geometry_quad_4x4_refcell"

    # Load periodic fine (unit cell) mesh
    unit_cell_mesh_fpath = joinpath(
        @__DIR__, 
        "assets", 
        "unit_cell_2D_periodic_puzzlepiece_geometry_triangular_refcell.msh")
    unit_cell_mesh = gk.mesh_from_gmsh(unit_cell_mesh_fpath)

    # visualize the periodic gmsh unit cell 
    unit_cell_vtk_fname = "unit_cell_mesh_2D_periodic_gmsh_puzzlepiece_geometry_triangular_refcell"
    visualize_unit_cell_mesh(unit_cell_mesh, joinpath("output", unit_cell_vtk_fname))

    # visualize final mesh with 4x4 coarse mesh and puzzle piece unit cell
    periodic_final_mesh, _ = gk.two_level_mesh(coarse_mesh, unit_cell_mesh)

    n_nodes = gk.num_nodes(periodic_final_mesh)

    vtk_grid(
        joinpath(
        "output",
        "two_level_mesh_$(unit_cell_vtk_fname)_$(coarse_cell_vtk_fname_4x4)"),
        gk.vtk_args(periodic_final_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,periodic_final_mesh)
            gk.vtk_physical_nodes!(vtk,periodic_final_mesh)
            vtk["node_ids"] = collect(1:n_nodes)
    end

    # TODO: check hardcode coordinates 
end

function visualize_unit_cell_mesh(unit_cell_mesh, outpath)

    # Get periodic node info about unit cell
    periodic_nodes = gk.periodic_nodes(unit_cell_mesh)
    fine_pnode_to_fine_node = periodic_nodes.first 
    fine_pnode_to_master_fine_node = periodic_nodes.second 
    
    # Labeling periodic nodes 
    node_ids = collect(1:gk.num_nodes(unit_cell_mesh))
    fine_node_to_master_fine_node = copy(node_ids)
    fine_node_to_master_fine_node[
        fine_pnode_to_fine_node] = fine_pnode_to_master_fine_node

    # Handles periodic vertices whose master node is the master of another periodic 
    # vertex assuming one level of indirection for periodicity 
    # (e.g., vertex -> master -> master)
    n_fine_nodes = length(node_ids)
    for fine_node in 1:n_fine_nodes
        master_fine_node = fine_node_to_master_fine_node[fine_node]
        if fine_node == master_fine_node
            continue  
        end

        master_master_fine_node = fine_node_to_master_fine_node[master_fine_node]
        fine_node_to_master_fine_node[fine_node] = master_master_fine_node 
    end 

    # Visualize in paraview
    vtk_grid(
        outpath,
        gk.vtk_args(unit_cell_mesh)...) do vtk
            gk.vtk_physical_faces!(vtk,unit_cell_mesh)
            gk.vtk_physical_nodes!(vtk,unit_cell_mesh)
            vtk["periodic_master_id"] = fine_node_to_master_fine_node
            vtk["node_id"] = node_ids
    end

    # TODO: Check hardcoded coordinates 
end 

"""
    coordinates(mesh, face_id, d)

Return node coordinates corresponding to the `d`-dimensional face with `face_id`

Variables matching the pattern `mesh_node*` correspond to the granularity of the supplied 
`mesh`. For example, if `mesh` is a `final_mesh`, then `mesh_node_to_coordinates`
is understood as `final_mesh_node_to_coordinates`.
"""
function coordinates(mesh, face, d)
    n_dfaces = gk.num_faces(mesh, d)
    dface_to_local_node_to_mesh_node = gk.face_nodes(mesh, d)
    mesh_node_to_coordinates = gk.node_coordinates(mesh)
    @assert face <= n_dfaces "face id is in [1...n_faces]"
    local_node_to_mesh_node = dface_to_local_node_to_mesh_node[face]
    coordinates = mesh_node_to_coordinates[local_node_to_mesh_node]
    return coordinates
end 

TMP.test_two_level_mesh_with_nonperiodic_square_unit_cell()
TMP.test_two_level_mesh_with_periodic_square_unit_cell()
# TMP.test_two_level_mesh_with_periodic_puzzle_piece_unit_cell()

end # module TMP
