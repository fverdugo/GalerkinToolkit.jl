module GalerkinToolkitTests

using Test
import GalerkinToolkit as gt

spx0 = gt.unit_simplex(0)
spx1 = gt.unit_simplex(1)
spx2 = gt.unit_simplex(2)
spx3 = gt.unit_simplex(3)
display(spx3)

cube0 = gt.unit_n_cube(0)
cube1 = gt.unit_n_cube(1)
cube2 = gt.unit_n_cube(2)
cube3 = gt.unit_n_cube(3)
display(cube3)

@show typeof(spx0)
@show typeof(cube0)
@show typeof(spx1)
@show typeof(cube1)

degree = 4
quad = gt.default_quadrature(spx0,degree)
quad = gt.default_quadrature(spx1,degree)
quad = gt.default_quadrature(spx2,degree)
quad = gt.default_quadrature(spx3,degree)

quad = gt.default_quadrature(cube0,degree)
quad = gt.default_quadrature(cube1,degree)
quad = gt.default_quadrature(cube2,degree)
quad = gt.default_quadrature(cube3,degree)


order = 1
fe = gt.lagrangian_fe(spx0,order)
fe = gt.lagrangian_fe(spx1,order)
fe = gt.lagrangian_fe(spx2,order)
fe = gt.lagrangian_fe(spx3,order)
display(fe)

fe = gt.lagrangian_fe(cube0,order)
fe = gt.lagrangian_fe(cube1,order)
fe = gt.lagrangian_fe(cube2,order)
fe = gt.lagrangian_fe(cube3,order)
display(fe)

fe = gt.lagrangian_fe(cube0,order)
fe = gt.lagrangian_fe(cube2,order)
@show gt.node_coordinates(fe)

spx2 = gt.unit_simplex(2)
quad = gt.default_quadrature(spx2,degree)
fe = gt.lagrangian_fe(spx2,order)
funs = gt.shape_functions(fe)
x = gt.coordinates(quad)
B = broadcast(gt.value,permutedims(funs),x)
display(B)
tabulator = gt.tabulator(fe)
A = tabulator(gt.value,x)
@test A≈B
x = gt.node_coordinates(fe)
A = tabulator(gt.value,x)
@show A

fe = gt.lagrangian_fe(spx2,order;shape=(3,))
funs = gt.shape_functions(fe)
x = gt.coordinates(quad)
B = broadcast(gt.value,permutedims(funs),x)
display(B)
tabulator = gt.tabulator(fe)
A = tabulator(gt.value,x)
@test A≈B
x = gt.node_coordinates(fe)
A = tabulator(gt.value,x)
@show A


#∂spx0 = gt.boundary(spx0)
#∂spx0 = gt.boundary(spx1)
#∂cube0 = gt.boundary(cube0)



end # module
