module Example003

import GalerkinToolkit as gk
import ForwardDiff
using StaticArrays
using LinearAlgebra
using SparseArrays
using WriteVTK

# This one implements a vanilla sequential iso-parametric Poisson solver
# with FE assembly on GPUs

function main(params_in)

    # Process params
    params_default = default_params()
    params = add_default_params(params_in,params_default)
    results = Dict{Symbol,Any}()

    # Setup main data structures
    state = setup(params)
    add_basic_info(results,params,state)

    # Assemble system and solve it
    A,b = assemble_system(state)
    x = solve_system(A,b,params)

    # Post process
    uh = setup_uh(x,state)
    integrate_error_norms(results,uh,state)
    export_results(uh,params,state)

    results
end

function add_default_params(params_in,params_default)
    UmD = setdiff(keys(params_in),keys(params_default))
    for k in UmD
        @warn "Parameter with key :$k is unused"
    end
    UiD = intersect(keys(params_default),keys(params_in))
    DmU = setdiff(keys(params_default),keys(params_in))
    a = [ k=>params_in[k] for k in UiD]
    b = [ k=>params_default[k] for k in DmU]
    Dict(vcat(a,b))
end

function default_params()
    outdir = mkpath(joinpath(@__DIR__,"..","output"))
    params = Dict{Symbol,Any}()
    params[:mesh] = gk.cartesian_mesh((0,1,0,1),(10,10))
    params[:u] = (x) -> sum(x)
    params[:f] = (x) -> 0.0
    params[:g] = (x) -> 0.0
    params[:dirichlet_tags] = ["boundary"]
    params[:neumann_tags] = String[]
    params[:integration_degree] = 2
    params[:solver] = lu_solver()
    params[:example_path] = joinpath(outdir,"example003")
    params
end

function lu_solver()
    setup(x,A,b) = lu(A)
    setup! = lu!
    solve! = ldiv!
    finalize!(S) = nothing
    (;setup,setup!,solve!,finalize!)
end

function setup_dirichlet_bcs(params)
    mesh = params[:mesh]
    u = params[:u]
    dirichlet_tags = params[:dirichlet_tags]
    node_to_tag = zeros(gk.num_nodes(mesh))
    tag_to_name = dirichlet_tags
    gk.classify_mesh_nodes!(node_to_tag,mesh,tag_to_name)
    free_and_dirichlet_nodes = gk.partition_from_mask(i->i==0,node_to_tag)
    node_to_x = gk.node_coordinates(mesh)
    dirichlet_nodes = last(free_and_dirichlet_nodes)
    x_dirichlet = view(node_to_x,dirichlet_nodes)
    u_dirichlet = u.(x_dirichlet)
    dirichlet_bcs = (;free_and_dirichlet_nodes,u_dirichlet,node_to_tag)
end

function setup_integration(params,objects)
    mesh = params[:mesh]
    degree = params[:integration_degree]
    D = gk.num_dims(mesh)
    if objects === :cells
        d = D
    elseif objects === :faces
        d = D-1
    else
        error("")
    end
    # Integration
    ref_cells = gk.reference_faces(mesh,d)
    face_to_rid = gk.face_reference_id(mesh,d)
    integration_rules = map(ref_cells) do ref_cell
        gk.default_quadrature(gk.geometry(ref_cell),degree)
    end
    rid_to_weights = map(gk.weights,integration_rules)
    rid_to_coords = map(gk.coordinates,integration_rules)
    integration = (;rid_to_weights,rid_to_coords,face_to_rid,d)
end

function setup_isomap(params,integration)
    rid_to_coords = integration.rid_to_coords
    face_to_rid = integration.face_to_rid
    d = integration.d
    mesh = params[:mesh]
    ref_cells = gk.reference_faces(mesh,d)
    shape_funs = map(rid_to_coords,ref_cells) do q,ref_cell
        shape_vals = gk.tabulator(ref_cell)(gk.value,q)
        shape_grads = gk.tabulator(ref_cell)(ForwardDiff.gradient,q)
        shape_vals, shape_grads
    end
    rid_to_shape_vals = map(first,shape_funs)
    rid_to_shape_grads = map(last,shape_funs)
    face_to_nodes = gk.face_nodes(mesh,d)
    node_to_coords = gk.node_coordinates(mesh)
    isomap = (;face_to_nodes,node_to_coords,face_to_rid,rid_to_shape_vals,rid_to_shape_grads,d)
end

function setup_neumann_bcs(params)
    mesh = params[:mesh]
    neumann_tags = params[:neumann_tags]
    neum_face_to_face = Int[]
    if length(neumann_tags) != 0
        D = gk.num_dims(mesh)
        tag_to_groups = gk.physical_faces(mesh,D-1)
        neum_face_to_face = reduce(union,map(tag->tag_to_groups[tag],neumann_tags))
    end
    (;neum_face_to_face)
end

function setup_user_funs(params)
    u = params[:u]
    f = params[:f]
    g = params[:g]
    user_funs = (;u,f,g)
end

function setup(params)
    dirichlet_bcs = setup_dirichlet_bcs(params)
    neumann_bcs = setup_neumann_bcs(params)
    cell_integration = setup_integration(params,:cells)
    face_integration = setup_integration(params,:faces)
    cell_isomap = setup_isomap(params,cell_integration)
    face_isomap = setup_isomap(params,face_integration)
    user_funs = setup_user_funs(params)
    solver = params[:solver]
    state = (;solver,dirichlet_bcs,neumann_bcs,cell_integration,cell_isomap,face_integration,face_isomap,user_funs)
end

function add_basic_info(results,params,state)
    node_to_x = state.cell_isomap.node_to_coords
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    cell_to_rid = state.cell_isomap.face_to_rid
    nfree = length(first(free_and_dirichlet_nodes))
    nnodes = length(node_to_x)
    ncells = length(cell_to_rid)
    results[:nnodes] = nnodes
    results[:nfree] = nfree
    results[:ncells] = ncells
    results
end

function integrate_matrix(state)

    # We assume a single cell type
    @assert length(state.cell_isomap.rid_to_shape_grads) == 1

    cell_to_nodes = state.cell_isomap.face_to_nodes
    node_to_x = state.cell_isomap.node_to_coords
    ∇se = state.cell_isomap.rid_to_shape_grads[1]
    se = state.cell_isomap.rid_to_shape_vals[1]
    we = state.cell_integration.rid_to_weights[1]
    d = state.cell_integration.d
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    node_to_free_node = gk.permutation(free_and_dirichlet_nodes)
    nfree = length(first(free_and_dirichlet_nodes))

    cell

    n_local_nodes = size(∇se,2)
    n_int_points = size(∇se,1)
    n_cells = length(cell_to_nodes)
    n_coo = n_cells*n_local_nodes

    Tx = SVector{d,Float64}
    TJ = typeof(zero(Tx)*zero(Tx)')

    # Assemble
    # This one should be good enough on the CPU
    Ie = zeros(Float64,n_local_nodes*n_cells)
    Je = zeros(Float64,n_local_nodes*n_cells)
    for cell in 1:n_cells
        nodes = cell_to_nodes[cell]
        for i in 1:n_local_nodes
            for j in 1:n_local_nodes
                p_ij = (cell-1)*n_local_nodes*n_local_nodes + (j-1)*n_local_nodes + i
                Ie[p_ij] = 
                Je[p_ij] = nodes[J]
            end
        end
    end

    # Convert data to a format more suitable for gpus
    # Perhaps more date is needed, and with appropriate reordering
    nodese = JaggedArray(cell_to_nodes).data
    cell_to_is_dirichlet = fill(false,n_cells)
    for cell in 1:n_cells
        nodes = cell_to_nodes[cell]
        if any(node-> node_to_free_node[node]>nfree,nodes)
            cell_to_is_dirichlet[cell] = true
        end
    end

    # TODO move to the GPU
    # The code below runs on the CPU
    # but it is implemented in a way close of what
    # one will implement on the GPU
    Ae = zeros(Float64,n_local_nodes*n_local_nodes*n_cells)
    fe = zeros(Float64,n_local_nodes*n_cells)

    # Auxiliary memory
    # can we get rid of this?
    ∇xe = zeros(Tx,n_local_nodes*n_cells)
    for cell in 1:n_cells
        for iq in 1:n_int_points
            Jt = zero(TJ) 
            xint = zero(Tx)
            for k in 1:n_local_nodes
                p_k = (cell-1)*n_local_nodes + k
                node = nodese[p_k]
                x = node_to_x[nodes[k]]
                ∇sqx = ∇se[iq,k]
                sqx = se[iq,k]
                Jt += ∇sqx*x'
                xint += sqx*x
            end
            detJt = det(Jt)
            invJt = inv(Jt)
            dV = abs(detJt)*we[iq]
            for k in 1:n_local_nodes
                p_k = (cell-1)*n_local_nodes + k
                ∇xe[p_k] = invJt*∇se[iq,k]
            end
            # Matrix
            for j in 1:n_local_nodes
                p_j = (cell-1)*n_local_nodes + j
                for i in 1:n_local_nodes
                    p_ij = (cell-1)*n_local_nodes*n_local_nodes + (j-1)*n_local_nodes + i
                    p_i = (cell-1)*n_local_nodes + i
                    V_coo[p_ij] += ∇xe[p_i]⋅∇xe[p_j]*dV
                end
            end
            # Vector
            fx = f(xint)
            for k in 1:n_local_nodes
                p_k = (cell-1)*n_local_nodes + k
                b_coo[p_k] +=  fx*se[iq,k]*dV
            end
        end
    end

    # Add boundary conditions to fe
    # We provably don't want to merge this and the previous one
    # since this will lead to branching but it will be shorter
    for cell in 1:n_cells
        if !cell_to_is_dirichlet[cell]
            continue
        end
        for i in 1:n_local_nodes
            p_i = (cell-1)*n_local_nodes + i
            ni = nodese[p_i]
            gi = node_to_free_node[ni]
            if gi > nfree # Not really needed
                continue
            end
            for j in 1:n_local_nodes
                p_j = (cell-1)*n_local_nodes + j
                nj = nodese[p_j]
                gj = node_to_free_node[nj]
                if gj <= nfree
                    continue
                end
                p_ij = (cell-1)*n_local_nodes*n_local_nodes + (j-1)*n_local_nodes + i
                Aij = Ae[p_ij]
                uj = u_dirichlet[gj-nfree]
                be[p_i] -= Aij*uj
            end
        end
    end





   




end

function assemble_system_loop(state)

    cell_to_nodes = state.cell_isomap.face_to_nodes
    cell_to_rid = state.cell_isomap.face_to_rid
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    node_to_x = state.cell_isomap.node_to_coords
    ∇s = state.cell_isomap.rid_to_shape_grads
    s = state.cell_isomap.rid_to_shape_vals
    u_dirichlet = state.dirichlet_bcs.u_dirichlet
    f = state.user_funs.f
    w = state.cell_integration.rid_to_weights
    d = state.cell_integration.d

    # Count coo entries
    n_coo = 0
    ncells = length(cell_to_nodes)
    node_to_free_node = gk.permutation(free_and_dirichlet_nodes)
    nfree = length(first(free_and_dirichlet_nodes))
    for cell in 1:ncells
        nodes = cell_to_nodes[cell]
        for nj in nodes
            if node_to_free_node[nj] > nfree
                continue
            end
            for ni in nodes
                if node_to_free_node[ni] > nfree
                    continue
                end
                n_coo += 1
            end
        end
    end

    # Allocate coo values
    I_coo = zeros(Int32,n_coo)
    J_coo = zeros(Int32,n_coo)
    V_coo = zeros(Float64,n_coo)
    b = zeros(nfree)

    # Allocate auxiliary buffers
    ∇x = map(i->similar(i,size(i,2)),∇s)
    Aes = map(i->zeros(size(i,2),size(i,2)),∇s)
    fes = map(i->zeros(size(i,2)),∇s)
    ues = map(i->zeros(size(i,2)),∇s)

    Tx = SVector{d,Float64}
    TJ = typeof(zero(Tx)*zero(Tx)')

    # Fill coo values
    i_coo = 0
    for cell in 1:ncells
        rid = cell_to_rid[cell]
        nodes = cell_to_nodes[cell]
        Ae = Aes[rid]
        ue = ues[rid]
        fe = fes[rid]
        nl = length(nodes)
        ∇se = ∇s[rid]
        ∇xe = ∇x[rid]
        se = s[rid]
        we = w[rid]
        nq = length(we)
        fill!(Ae,zero(eltype(Ae)))
        fill!(fe,zero(eltype(Ae)))
        fill!(ue,zero(eltype(Ae)))
        for k in 1:nl
            nk = nodes[k]
            gk = node_to_free_node[nk]
            if  gk <= nfree
                continue
            end
            ue[k] = u_dirichlet[gk-nfree]
        end
        for iq in 1:nq
            Jt = zero(TJ) 
            xint = zero(Tx)
            for k in 1:nl
                x = node_to_x[nodes[k]]
                ∇sqx = ∇se[iq,k]
                sqx = se[iq,k]
                Jt += ∇sqx*x'
                xint += sqx*x
            end
            detJt = det(Jt)
            invJt = inv(Jt)
            dV = abs(detJt)*we[iq]
            for k in 1:nl
                ∇xe[k] = invJt*∇se[iq,k]
            end
            for j in 1:nl
                for i in 1:nl
                    Ae[i,j] += ∇xe[i]⋅∇xe[j]*dV
                end
            end
            fx = f(xint)
            for k in 1:nl
                fe[k] +=  fx*se[iq,k]*dV
            end
        end
        for i in 1:nl
            for j in 1:nl
                fe[i] -= Ae[i,j]*ue[j]
            end
        end
        for i in 1:nl
            ni = nodes[i]
            gi = node_to_free_node[ni]
            if gi > nfree
                continue
            end
            b[gi] += fe[i]
        end
        for j in 1:nl
            nj = nodes[j]
            gj = node_to_free_node[nj]
            if  gj > nfree
                continue
            end
            for i in 1:nl
                ni = nodes[i]
                gi = node_to_free_node[ni]
                if gi > nfree
                    continue
                end
                i_coo += 1
                I_coo[i_coo] = gi
                J_coo[i_coo] = gj
                V_coo[i_coo] = Ae[i,j]
            end
        end
    end
    add_neumann_bcs!(b,state)
    I_coo,J_coo,V_coo,b
end

function add_neumann_bcs!(b,state)

    neum_face_to_face = state.neumann_bcs.neum_face_to_face
    if length(neum_face_to_face) == 0
        return nothing
    end
    face_to_rid = state.face_isomap.face_to_rid
    face_to_nodes = state.face_isomap.face_to_nodes
    ∇s_f = state.face_isomap.rid_to_shape_grads
    s_f = state.face_isomap.rid_to_shape_vals
    node_to_x = state.face_isomap.node_to_coords
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    g = state.user_funs.g
    w_f = state.face_integration.rid_to_weights
    d = state.cell_integration.d

    fes = map(i->zeros(size(i,2)),s_f)
    Tx = SVector{d,Float64}
    Ts = typeof(zero(SVector{d-1,Float64})*zero(Tx)')
    node_to_free_node = gk.permutation(free_and_dirichlet_nodes)
    nfree = length(first(free_and_dirichlet_nodes))

    for face in neum_face_to_face
        rid = face_to_rid[face]
        nodes = face_to_nodes[face]
        ∇se = ∇s_f[rid]
        se = s_f[rid]
        we = w_f[rid]
        nq = length(we)
        fe = fes[rid]
        fill!(fe,zero(eltype(fe)))
        nl = length(nodes)
        for iq in 1:nq
            Jt = zero(Ts) 
            xint = zero(Tx)
            for k in 1:nl
                x = node_to_x[nodes[k]]
                ∇sqx = ∇se[iq,k]
                sqx = se[iq,k]
                Jt += ∇sqx*x'
                xint += sqx*x
            end
            J = transpose(Jt)
            dS = sqrt(det(Jt*J))*we[iq]
            gx = g(xint)
            for k in 1:nl
                fe[k] +=  gx*se[iq,k]*dS
            end
        end
        for i in 1:nl
            ni = nodes[i]
            gi = node_to_free_node[ni]
            if gi > nfree
                continue
            end
            b[gi] += fe[i]
        end
    end

    nothing
end

function assemble_system(state)
    I,J,V,b = assemble_system_loop(state)
    nfree = length(b)
    A = sparse(I,J,V,nfree,nfree)
    A,b
end

function solve_system(A,b,params)
    solver = params[:solver]
    x = similar(b,axes(A,2))
    setup = solver.setup(x,A,b)
    solver.solve!(x,setup,b)
    solver.finalize!(setup)
    x
end

function setup_uh(x,state)
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    node_to_x = state.cell_isomap.node_to_coords
    u_free = x
    u_dirichlet = state.dirichlet_bcs.u_dirichlet
    nnodes = length(node_to_x)
    uh = zeros(nnodes)
    uh[first(free_and_dirichlet_nodes)] = u_free
    uh[last(free_and_dirichlet_nodes)] = u_dirichlet
    uh
end

function integrate_error_norms_loop(uh,state)

    cell_to_nodes = state.cell_isomap.face_to_nodes
    cell_to_rid = state.cell_isomap.face_to_rid
    free_and_dirichlet_nodes = state.dirichlet_bcs.free_and_dirichlet_nodes
    node_to_x = state.cell_isomap.node_to_coords
    ∇s = state.cell_isomap.rid_to_shape_grads
    s = state.cell_isomap.rid_to_shape_vals
    u_dirichlet = state.dirichlet_bcs.u_dirichlet
    u = state.user_funs.u
    w = state.cell_integration.rid_to_weights
    d = state.cell_integration.d

    eh1 = 0.0
    el2 = 0.0
    ncells = length(cell_to_rid)
    ues = map(i->zeros(size(i,2)),∇s)
    ∇x = map(i->similar(i,size(i,2)),∇s)
    Tx = SVector{d,Float64}
    TJ = typeof(zero(Tx)*zero(Tx)')
    for cell in 1:ncells
        rid = cell_to_rid[cell]
        nodes = cell_to_nodes[cell]
        ue = ues[rid]
        nl = length(nodes)
        ∇se = ∇s[rid]
        ∇xe = ∇x[rid]
        se = s[rid]
        we = w[rid]
        nq = length(we)
        for k in 1:nl
            nk = nodes[k]
            ue[k] = uh[nk]
        end
        for iq in 1:nq
            Jt = zero(TJ) 
            xint = zero(Tx)
            for k in 1:nl
                x = node_to_x[nodes[k]]
                ∇sqx = ∇se[iq,k]
                sqx = se[iq,k]
                Jt += ∇sqx*x'
                xint += sqx*x
            end
            detJt = det(Jt)
            invJt = inv(Jt)
            dV = abs(detJt)*we[iq]
            for k in 1:nl
                ∇xe[k] = invJt*∇se[iq,k]
            end
            ux = u(xint)
            ∇ux = ForwardDiff.gradient(u,xint)
            ∇uhx = zero(∇ux)
            uhx = zero(ux)
            for k in 1:nl
                uek = ue[k]
                ∇uhx += uek*∇xe[k]
                uhx += uek*se[iq,k]
            end
            ∇ex = ∇ux - ∇uhx
            ex =  ux - uhx
            eh1 += (∇ex⋅∇ex + ex*ex)*dV
            el2 += ex*ex*dV
        end
    end
    eh1, el2
end

function integrate_error_norms(results,uh,state)
    eh1², el2² = integrate_error_norms_loop(uh,state)
    eh1 = sqrt(eh1²)
    el2 = sqrt(el2²)
    results[:eh1] = eh1
    results[:el2] = el2
    results
end

function export_results(uh,params,state)
    mesh = params[:mesh]
    example_path = params[:example_path]
    node_to_tag = state.dirichlet_bcs.node_to_tag
    vtk_grid(example_path,gk.vtk_args(mesh)...) do vtk
        gk.vtk_physical_faces!(vtk,mesh)
        vtk["tag"] = node_to_tag
        vtk["uh"] = uh
        vtk["dim"] = gk.face_dim(mesh)
    end
end

end # module