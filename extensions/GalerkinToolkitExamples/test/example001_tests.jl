module Example001Tests

import GalerkinToolkit as gk
using GalerkinToolkitExamples: Example001
using Test

tol = 1.0e-10
params = Dict{Symbol,Any}()
params[:mesh] = gk.cartesian_mesh((0,3,0,2),(10,5),complexify=false)
params[:dirichlet_tags] = ["1-face-1","1-face-3","1-face-4"]
params[:neumann_tags] = ["1-face-2"]
params[:u] = (x) -> sum(x)
params[:f] = (x) -> 0.0
params[:g] = (x) -> 1.0
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol
@test results[:ncells] == 10*5

params = Dict{Symbol,Any}()
params[:mesh] = gk.cartesian_mesh((0,3,0,2,0,1),(5,5,5))
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol
@test results[:ncells] == 5*5*5

params = Dict{Symbol,Any}()
params[:mesh] = gk.cartesian_mesh((0,3,0,2),(5,5),simplexify=true)
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol

params = Dict{Symbol,Any}()
params[:mesh] = gk.cartesian_mesh((0,3,0,2,0,1),(5,5,5),simplexify=true)
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol

params = Dict{Symbol,Any}()
params[:hi] = 1
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol

domain = (0,1,0,1)
cells = (10,10)
fine_mesh = gk.cartesian_mesh(domain,cells)
domain = (0,30,0,10)
cells = (2,2)
coarse_mesh = gk.cartesian_mesh(domain,cells)
mesh, = gk.two_level_mesh(coarse_mesh,fine_mesh)

params = Dict{Symbol,Any}()
params[:mesh] = mesh
results = Example001.main(params)
@test results[:eh1] < tol
@test results[:el2] < tol


end # module