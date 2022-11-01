module LinearSolve

using ArrayInterfaceCore
using RecursiveFactorization
using Base: cache_dependencies, Bool
import Base: eltype, adjoint, inv
using LinearAlgebra
using IterativeSolvers: Identity
using SparseArrays
using SciMLBase: AbstractLinearAlgorithm
using SciMLOperators
using SciMLOperators: AbstractSciMLOperator
using Setfield
using UnPack
using SuiteSparse
using KLU
using FastLapackInterface
using DocStringExtensions
import GPUArraysCore

# wrap
import Krylov
import KrylovKit
import IterativeSolvers

using Reexport
@reexport using SciMLBase

@deprecate InvPreconditioner SciMLOperators.InvertedOperator

abstract type SciMLLinearSolveAlgorithm <: SciMLBase.AbstractLinearAlgorithm end
abstract type AbstractFactorization <: SciMLLinearSolveAlgorithm end
abstract type AbstractKrylovSubspaceMethod <: SciMLLinearSolveAlgorithm end
abstract type AbstractSolveFunction <: SciMLLinearSolveAlgorithm end

# Traits

needs_concrete_A(alg::AbstractFactorization) = true
needs_concrete_A(alg::AbstractKrylovSubspaceMethod) = false
needs_concrete_A(alg::AbstractSolveFunction) = false

# Is Identity

isidentity(A) = A === I
isidentity(A::UniformScaling) = isone(A.λ)
isidentity(::IterativeSolvers.Identity) = true
isidentity(::SciMLOperators.IdentityOperator) = true

# Code

include("common.jl")
include("factorization.jl")
include("simplelu.jl")
include("iterative_wrappers.jl")
include("preconditioners.jl")
include("solve_function.jl")
include("default.jl")
include("init.jl")

const IS_OPENBLAS = Ref(true)
isopenblas() = IS_OPENBLAS[]

import SnoopPrecompile

SnoopPrecompile.@precompile_all_calls begin
    A = rand(4, 4)
    b = rand(4)
    prob = LinearProblem(A, b)
    sol = solve(prob)
    sol = solve(prob, LUFactorization())
    sol = solve(prob, RFLUFactorization())
    sol = solve(prob, KrylovJL_GMRES())

    A = sprand(4, 4, 0.9)
    prob = LinearProblem(A, b)
    sol = solve(prob)
    sol = solve(prob, KLUFactorization())
    sol = solve(prob, UMFPACKFactorization())
end

export LUFactorization, SVDFactorization, QRFactorization, GenericFactorization,
       GenericLUFactorization, SimpleLUFactorization, RFLUFactorization,
       UMFPACKFactorization, KLUFactorization, FastLUFactorization, FastQRFactorization

export LinearSolveFunction, DirectLdiv

export KrylovJL, KrylovJL_CG, KrylovJL_GMRES, KrylovJL_BICGSTAB, KrylovJL_MINRES,
       IterativeSolversJL, IterativeSolversJL_CG, IterativeSolversJL_GMRES,
       IterativeSolversJL_BICGSTAB, IterativeSolversJL_MINRES,
       KrylovKitJL, KrylovKitJL_CG, KrylovKitJL_GMRES, KrylovJL_LSMR

end
