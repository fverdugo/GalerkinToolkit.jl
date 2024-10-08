module AssemblyTests

import GalerkinToolkit as GT
using GalerkinToolkit: ∫, ×
using Test
import ForwardDiff
using LinearAlgebra

outdir = mkpath(joinpath(@__DIR__,"..","output"))

domain = (0,1,0,1)
cells = (4,4)
mesh = GT.cartesian_mesh(domain,cells)
GT.label_interior_faces!(mesh;physical_name="interior_faces")
GT.label_boundary_faces!(mesh;physical_name="boundary_faces")

Ω = GT.interior(mesh)
Ωref = GT.interior(mesh;is_reference_domain=true)
ϕ = GT.domain_map(Ωref,Ω)

D = GT.num_dims(mesh)
Γdiri = GT.boundary(mesh;physical_names=["1-face-1","1-face-3"])

Γref = GT.boundary(mesh;
                 is_reference_domain=true,
                 physical_names=["1-face-2","1-face-4"])

Γ = GT.physical_domain(Γref)

V = GT.iso_parametric_space(Ωref;dirichlet_boundary=Γdiri)

degree = 2
dΩref = GT.measure(Ωref,degree)
ϕ = GT.domain_map(Ωref,Ω)

dΓref = GT.measure(Γref,degree)
α = GT.domain_map(Γref,Γ)
β = GT.domain_map(Γref,Ωref)

Λref = GT.skeleton(mesh;
                 is_reference_domain=true,
                 physical_names=["interior_faces"])

Λ = GT.physical_domain(Λref)
dΛref = GT.measure(Λref,degree)
ϕ_Λref_Λ = GT.domain_map(Λref,Λ)
ϕ_Λref_Ωref = GT.domain_map(Λref,Ωref)

function dV(J)
    abs(det(J))
end

function dS(J)
    Jt = transpose(J)
    sqrt(det(Jt*J))
end

jump(u,ϕ,q) = u(ϕ[+](q))[+]-u(ϕ[-](q))[-]

function l(v)
    ∫(dΩref) do q
        J = ForwardDiff.jacobian(ϕ,q)
        v(q)*dV(J)
    end +
    ∫(dΓref) do p
        q = β(p)
        J = ForwardDiff.jacobian(α,p)
        v(q)*dS(J)
    end +
    ∫(dΛref) do p
        J = ForwardDiff.jacobian(ϕ_Λref_Λ,p)
        jump(v,ϕ_Λref_Ωref,p)*dS(J)
    end
end

b = GT.assemble_vector(l,V,Float64)

function l(v)
    ∫(dΛref) do p
        J = ForwardDiff.jacobian(ϕ_Λref_Λ,p)
        jump(v,ϕ_Λref_Ωref,p)*dS(J)
    end
end

b = GT.assemble_vector(l,V,Float64)
@test sum(b)+1 ≈ 1

V² = V × V

function l((v1,v2))
    ∫(dΩref) do q
        J = ForwardDiff.jacobian(ϕ,q)
        v1(q)*v2(q)*dV(J)
    end +
    ∫(dΛref) do p
        J = ForwardDiff.jacobian(ϕ_Λref_Λ,p)
        jump(v1,ϕ_Λref_Ωref,p)*jump(v2,ϕ_Λref_Ωref,p)*dS(J)
    end
end

b = GT.assemble_vector(l,V²,Float64)

function a(u,v)
    ∫(dΩref) do q
        J = ForwardDiff.jacobian(ϕ,q)
        u(q)*v(q)*dV(J)
    end +
    ∫(dΓref) do p
        q = β(p)
        J = ForwardDiff.jacobian(α,p)
        u(q)*v(q)*dS(J)
    end +
    ∫(dΛref) do p
        J = ForwardDiff.jacobian(ϕ_Λref_Λ,p)
        jump(v,ϕ_Λref_Ωref,p)*jump(u,ϕ_Λref_Ωref,p)*dS(J)
    end
end

A = GT.assemble_matrix(a,V,V,Float64)

function a((u1,u2),(v1,v2))
    ∫(dΩref) do q
        J = ForwardDiff.jacobian(ϕ,q)
        v1(q)*v2(q)*u1(q)*u2(q)*dV(J)
    end +
    ∫(dΛref) do p
        J = ForwardDiff.jacobian(ϕ_Λref_Λ,p)
        jump(v1,ϕ_Λref_Ωref,p)*jump(v2,ϕ_Λref_Ωref,p)*jump(u1,ϕ_Λref_Ωref,p)*jump(u2,ϕ_Λref_Ωref,p)*dS(J)
    end
end

A = GT.assemble_matrix(a,V²,V²,Float64)

x = similar(b,axes(A,2))
fill!(x,0)
uh = GT.solution_field(V²,x)
uh1,uh2 = uh
fill!(GT.free_values(uh2),1)
@test x[end] == 1

function dV(ϕ,q)
    J = ForwardDiff.jacobian(ϕ,q)
    abs(det(J))
end

a(u,v) = ∫( q->u(q)*v(q)*dV(ϕ,q), dΩref)

f = GT.analytical_field(sum,Ω)

l(v) = ∫( q->f(ϕ(q))*v(q)*dV(ϕ,q), dΩref)

V = GT.iso_parametric_space(Ωref)

x,A,b = GT.linear_problem(Float64,V,a,l)
x .= A\b
uh = GT.solution_field(V,x)

function ∇(u,phi,q)
   J = ForwardDiff.jacobian(phi,q)
   g = ForwardDiff.gradient(u,q)
   J\g
end

a(u,v) = ∫( q->∇(u,ϕ,q)⋅∇(v,ϕ,q)*dV(ϕ,q), dΩref)
l(v) = 0

x,A,b = GT.linear_problem(uh,a,l)
display(A)
x .= A\b

# Poisson solve (reference domain)

domain = (0,1,0,1)
cells = (4,4)
mesh = GT.cartesian_mesh(domain,cells)
GT.label_boundary_faces!(mesh;physical_name="boundary_faces")

Ω = GT.interior(mesh)
Ωref = GT.reference_domain(Ω)
ϕ = GT.domain_map(Ωref,Ω)

D = GT.num_dims(mesh)
Γdiri = GT.boundary(mesh;physical_names=["boundary_faces"])

#V = GT.iso_parametric_space(Ωref;dirichlet_boundary=Γdiri)

order = 3
V = GT.lagrange_space(Ωref,order;dirichlet_boundary=Γdiri)

u = GT.analytical_field(sum,Ω)
uhd = GT.dirichlet_field(Float64,V)
# TODO
#GT.interpolate_dirichlet!(q->u(ϕ(q)),uh)
GT.interpolate_dirichlet!(u∘ϕ,uhd)

function ∇(u,q)
   J = ForwardDiff.jacobian(ϕ,q)
   g = ForwardDiff.gradient(u,q)
   J\g
end

function dV(q)
    J = ForwardDiff.jacobian(ϕ,q)
    abs(det(J))
end

degree = 2*order
dΩref = GT.measure(Ωref,degree)

a(u,v) = ∫( q->∇(u,q)⋅∇(v,q)*dV(q), dΩref)
l(v) = 0

x,A,b = GT.linear_problem(uhd,a,l)
x .= A\b
uh = GT.solution_field(uhd,x)

# TODO
# Functions like this ones should
# work as AbstractQuantities?
eh(q) = u(ϕ(q)) - uh(q)
∇eh(q) = ForwardDiff.gradient(u,ϕ(q)) - ∇(uh,q)

tol = 1.e-12
el2 = ∫( q->abs2(eh(q))*dV(q), dΩref) |> sum |> sqrt
@test el2 < tol

eh1 = ∫( q->∇eh(q)⋅∇eh(q)*dV(q), dΩref) |> sum |> sqrt
@test el2 < tol

# Poisson solve (API in physical domain)

V = GT.lagrange_space(Ω,order;dirichlet_boundary=Γdiri)

uhd = GT.dirichlet_field(Float64,V)
GT.interpolate_dirichlet!(u,uhd)

dΩ = GT.measure(Ω,degree)

∇(u,q) = ForwardDiff.gradient(u,q)

a(u,v) = ∫( q->∇(u,q)⋅∇(v,q), dΩ)
l(v) = 0

x,A,b = GT.linear_problem(uhd,a,l)
x .= A\b
uh = GT.solution_field(uhd,x)

eh(q) = u(q) - uh(q)
∇eh(q) = ∇(u,q) - ∇(uh,q)

el2 = ∫( q->abs2(eh(q)), dΩ) |> sum |> sqrt
@test el2 < tol

eh1 = ∫( q->∇eh(q)⋅∇eh(q), dΩ) |> sum |> sqrt
@test el2 < tol

# 3d case

n = 2
domain = (0,1,0,1,0,1)
cells = (n,n,n)
mesh = GT.cartesian_mesh(domain,cells)
Ω = GT.interior(mesh)
k = 1
V = GT.lagrange_space(Ω,k)
dΩ = GT.measure(Ω,2*k)
gradient(u) = x->ForwardDiff.gradient(u,x)
∇(u,x) = GT.call(gradient,u)(x)
a(u,v) = GT.∫( x->∇(u,x)⋅∇(v,x), dΩ)
l(v) = 0
x,A,b = GT.linear_problem(Float64,V,a,l)
A |> display

end # module
