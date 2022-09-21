# [Linear System Solvers](@id linearsystemsolvers)

`solve(prob::LinearProlem,alg;kwargs)`

Solves for ``Au=b`` in the problem defined by `prob` using the algorithm
`alg`. If no algorithm is given, a default algorithm will be chosen.

## Recommended Methods

The default algorithm `nothing` is good for choosing an algorithm that will work,
but one may need to change this to receive more performance or precision. If
more precision is necessary, `QRFactorization()` and `SVDFactorization()` are
the best choices, with SVD being the slowest but most precise.

For efficiency, `RFLUFactorization` is the fastest for dense LU-factorizations.
`FastLUFactorization` will be faster than `LUFactorization` which is the Base.LinearAlgebra
(`\` default) implementation of LU factorization. `SimpleLUFactorization` will be fast
on very small matrices.

For sparse LU-factorizations, `KLUFactorization` if there is less structure
to the sparsity pattern and `UMFPACKFactorization` if there is more structure.
Pardiso.jl's methods are also known to be very efficient sparse linear solvers.

As sparse matrices get larger, iterative solvers tend to get more efficient than
factorization methods if a lower tolerance of the solution is required.

Krylov.jl generally outperforms IterativeSolvers.jl and KrylovKit.jl, and is compatible
with CPUs and GPUs, and thus is the generally preferred form for Krylov methods.

Many linear system have custom inverses defined. If `Base.\`, or `LinearAlgebra.ldiv!` are
overloaded for `A`, then the user can choose the algorithms `ApplyLdiv`, or `ApplyLdiv!` to
use that. Alternatively, `LinearSolve` will automatically use `Base.\` or
`LinearAlgebra.ldiv!` if `SciMLOperators.has_ldiv(A)` or `SciMLOperators.has_ldiv!(A)`
evaluates to `true`.

Finally, a user can pass a custom function for handling the linear solve using
`LinearSolveFunction()` if existing solvers are not optimally suited for their application.
The interface is detailed [here](#passing-in-a-custom-linear-solver)

## Full List of Methods

### RecursiveFactorization.jl

- `RFLUFactorization()`: a fast pure Julia LU-factorization implementation
  using RecursiveFactorization.jl. This is by far the fastest LU-factorization
  implementation, usually outperforming OpenBLAS and MKL, but currently optimized
  only for Base `Array` with `Float32` or `Float64`.  Additional optimization for 
  complex matrices is in the works.

### Base.LinearAlgebra

These overloads tend to work for many array types, such as `CuArrays` for GPU-accelerated
solving, using the overloads provided by the respective packages. Given that this can be
customized per-package, details given below describe a subset of important arrays
(`Matrix`, `SparseMatrixCSC`, `CuMatrix`, etc.)

- `LUFactorization(pivot=LinearAlgebra.RowMaximum())`: Julia's built in `lu`.
  - On dense matrices this uses the current BLAS implementation of the user's computer
    which by default is OpenBLAS but will use MKL if the user does `using MKL` in their
    system.
  - On sparse matrices this will use UMFPACK from SuiteSparse. Note that this will not
    cache the symbolic factorization.
  - On CuMatrix it will use a CUDA-accelerated LU from CuSolver.
  - On BandedMatrix and BlockBandedMatrix it will use a banded LU.
- `QRFactorization(pivot=LinearAlgebra.NoPivot(),blocksize=16)`: Julia's built in `qr`.
  - On dense matrices this uses the current BLAS implementation of the user's computer
    which by default is OpenBLAS but will use MKL if the user does `using MKL` in their
    system.
  - On sparse matrices this will use SPQR from SuiteSparse
  - On CuMatrix it will use a CUDA-accelerated QR from CuSolver.
  - On BandedMatrix and BlockBandedMatrix it will use a banded QR.
- `SVDFactorization(full=false,alg=LinearAlgebra.DivideAndConquer())`: Julia's built in `svd`.
  - On dense matrices this uses the current BLAS implementation of the user's computer
    which by default is OpenBLAS but will use MKL if the user does `using MKL` in their
    system.
- `GenericFactorization(fact_alg)`: Constructs a linear solver from a generic
  factorization algorithm `fact_alg` which complies with the Base.LinearAlgebra
  factorization API. Quoting from Base:
    - If `A` is upper or lower triangular (or diagonal), no factorization of `A` is
      required and the system is solved with either forward or backward substitution.
      For non-triangular square matrices, an LU factorization is used.
      For rectangular `A` the result is the minimum-norm least squares solution computed by a
      pivoted QR factorization of `A` and a rank estimate of `A` based on the R factor.
      When `A` is sparse, a similar polyalgorithm is used. For indefinite matrices, the `LDLt`
      factorization does not use pivoting during the numerical factorization and therefore the
      procedure can fail even for invertible matrices.

### LinearSolve.jl

LinearSolve.jl contains some linear solvers built in.

- `SimpleLUFactorization`: a simple LU-factorization implementation without BLAS. Fast for small matrices.

### FastLapackInterface.jl

FastLapackInterface.jl is a package that allows for a lower-level interface to the LAPACK
calls to allow for preallocating workspaces to decrease the overhead of the wrappers.
LinearSolve.jl provides a wrapper to these routines in a way where an initialized solver
has a non-allocating LU factorization. In theory, this post-initialized solve should always
be faster than the Base.LinearAlgebra version.

- `FastLUFactorization` the `FastLapackInterface` version of the LU factorizaiton. Notably,
  this version does not allow for choice of pivoting method.
- `FastQRFactorization(pivot=NoPivot(),blocksize=32)`, the `FastLapackInterface` version of
  the QR factorizaiton.

### SuiteSparse.jl

By default, the SuiteSparse.jl are implemented for efficiency by caching the
symbolic factorization. I.e. if `set_A` is used, it is expected that the new
`A` has the same sparsity pattern as the previous `A`. If this algorithm is to
be used in a context where that assumption does not hold, set `reuse_symbolic=false`.

- `KLUFactorization(;reuse_symbolic=true)`: A fast sparse LU-factorization which
  specializes on sparsity patterns with "less structure".
- `UMFPACKFactorization(;reuse_symbolic=true)`: A fast sparse multithreaded
  LU-factorization which specializes on sparsity patterns that are more
  structured.

### Pardiso.jl

!!! note

    Using this solver requires adding the package LinearSolvePardiso.jl

The following algorithms are pre-specified:

- `MKLPardisoFactorize(;kwargs...)`: A sparse factorization method.
- `MKLPardisoIterate(;kwargs...)`: A mixed factorization+iterative method.

Those algorithms are defined via:

```julia
MKLPardisoFactorize(;kwargs...) = PardisoJL(;fact_phase=Pardiso.NUM_FACT,
                                             solve_phase=Pardiso.SOLVE_ITERATIVE_REFINE,
                                             kwargs...)
MKLPardisoIterate(;kwargs...) = PardisoJL(;solve_phase=Pardiso.NUM_FACT_SOLVE_REFINE,
                                           kwargs...)
```

The full set of keyword arguments for `PardisoJL` are:

```julia
Base.@kwdef struct PardisoJL <: SciMLLinearSolveAlgorithm
    nprocs::Union{Int, Nothing} = nothing
    solver_type::Union{Int, Pardiso.Solver, Nothing} = nothing
    matrix_type::Union{Int, Pardiso.MatrixType, Nothing} = nothing
    fact_phase::Union{Int, Pardiso.Phase, Nothing} = nothing
    solve_phase::Union{Int, Pardiso.Phase, Nothing} = nothing
    release_phase::Union{Int, Nothing} = nothing
    iparm::Union{Vector{Tuple{Int,Int}}, Nothing} = nothing
    dparm::Union{Vector{Tuple{Int,Int}}, Nothing} = nothing
end
```

### CUDA.jl

Note that `CuArrays` are supported by `GenericFactorization` in the "normal" way.
The following are non-standard GPU factorization routines.

!!! note

    Using this solver requires adding the package LinearSolveCUDA.jl

- `CudaOffloadFactorization()`: An offloading technique used to GPU-accelerate CPU-based
  computations. Requires a sufficiently large `A` to overcome the data transfer
  costs.

### IterativeSolvers.jl

- `IterativeSolversJL_CG(args...;kwargs...)`: A generic CG implementation
- `IterativeSolversJL_GMRES(args...;kwargs...)`: A generic GMRES implementation
- `IterativeSolversJL_BICGSTAB(args...;kwargs...)`: A generic BICGSTAB implementation
- `IterativeSolversJL_MINRES(args...;kwargs...)`: A generic MINRES implementation

The general algorithm is:

```julia
IterativeSolversJL(args...;
                   generate_iterator = IterativeSolvers.gmres_iterable!,
                   Pl=nothing, Pr=nothing,
                   gmres_restart=0, kwargs...)
```

### Krylov.jl

- `KrylovJL_CG(args...;kwargs...)`: A generic CG implementation
- `KrylovJL_GMRES(args...;kwargs...)`: A generic GMRES implementation
- `KrylovJL_BICGSTAB(args...;kwargs...)`: A generic BICGSTAB implementation
- `KrylovJL_MINRES(args...;kwargs...)`: A generic MINRES implementation

The general algorithm is:

```julia
KrylovJL(args...; KrylovAlg = Krylov.gmres!,
                  Pl=nothing, Pr=nothing,
                  gmres_restart=0, window=0,
                  kwargs...)
```

### KrylovKit.jl

- `KrylovKitJL_CG(args...;kwargs...)`: A generic CG implementation
- `KrylovKitJL_GMRES(args...;kwargs...)`: A generic GMRES implementation

The general algorithm is:

```julia
function KrylovKitJL(args...;
                     KrylovAlg = KrylovKit.GMRES, gmres_restart = 0,
                     kwargs...)
```
