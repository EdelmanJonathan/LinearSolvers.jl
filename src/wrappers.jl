
#TODO: composed preconditioners, preconditioner setter for cache, 
#   detailed tests for wrappers

## Preconditioners

struct ScaleVector{T}
    s::T
    isleft::Bool
end

function LinearAlgebra.ldiv!(v::ScaleVector, x)
end

function LinearAlgebra.ldiv!(y, v::ScaleVector, x)
end

struct ComposePreconditioner{Ti,To}
    inner::Ti
    outer::To
    isleft::Bool
end

function LinearAlgebra.ldiv!(v::ComposePreconditioner, x)
    @unpack inner, outer, isleft = v
end

function LinearAlgebra.ldiv!(y, v::ComposePreconditioner, x)
    @unpack inner, outer, isleft = v
end

## Krylov.jl

struct KrylovJL{F,Tl,Tr,T,I,A,K} <: AbstractKrylovSubspaceMethod
    KrylovAlg::F
    Pl::Tl
    Pr::Tr
    abstol::T
    reltol::T
    maxiter::I
    ifverbose::Bool
    gmres_restart::I
    window::I
    args::A
    kwargs::K
end

function KrylovJL(args...; KrylovAlg = Krylov.gmres!, Pl=I, Pr=I,
                  abstol=0.0, reltol=0.0, maxiter=0, ifverbose=false,
                  gmres_restart=20, window=0,              # for building solver
                  kwargs...)

    return KrylovJL(KrylovAlg, Pl, Pr, abstol, reltol, maxiter, ifverbose,
                    gmres_restart, window,
                    args, kwargs)
end

KrylovJL_CG(args...;kwargs...) =
    KrylovJL(args...; KrylovAlg=Krylov.cg!, kwargs...)
KrylovJL_GMRES(args...;kwargs...) =
    KrylovJL(args...; KrylovAlg=Krylov.gmres!, kwargs...)
KrylovJL_BICGSTAB(args...;kwargs...) =
    KrylovJL(args...; KrylovAlg=Krylov.bicgstab!, kwargs...)
KrylovJL_MINRES(args...;kwargs...) =
    KrylovJL(args...; KrylovAlg=Krylov.minres!, kwargs...)

const KrylovJL_solvers = Dict(
  (Krylov.lsmr!       => Krylov.LsmrSolver          ),
  (Krylov.cgs!        => Krylov.CgsSolver           ),
  (Krylov.usymlq!     => Krylov.UsymlqSolver        ),
  (Krylov.lnlq!       => Krylov.LnlqSolver          ),
  (Krylov.bicgstab!   => Krylov.BicgstabSolver      ),
  (Krylov.crls!       => Krylov.CrlsSolver          ),
  (Krylov.lsqr!       => Krylov.LsqrSolver          ),
  (Krylov.minres!     => Krylov.MinresSolver        ),
  (Krylov.cgne!       => Krylov.CgneSolver          ),
  (Krylov.dqgmres!    => Krylov.DqgmresSolver       ),
  (Krylov.symmlq!     => Krylov.SymmlqSolver        ),
  (Krylov.trimr!      => Krylov.TrimrSolver         ),
  (Krylov.usymqr!     => Krylov.UsymqrSolver        ),
  (Krylov.bilqr!      => Krylov.BilqrSolver         ),
  (Krylov.cr!         => Krylov.CrSolver            ),
  (Krylov.craigmr!    => Krylov.CraigmrSolver       ),
  (Krylov.tricg!      => Krylov.TricgSolver         ),
  (Krylov.craig!      => Krylov.CraigSolver         ),
  (Krylov.diom!       => Krylov.DiomSolver          ),
  (Krylov.lslq!       => Krylov.LslqSolver          ),
  (Krylov.trilqr!     => Krylov.TrilqrSolver        ),
  (Krylov.crmr!       => Krylov.CrmrSolver          ),
  (Krylov.cg!         => Krylov.CgSolver            ),
  (Krylov.cg_lanczos! => Krylov.CgLanczosShiftSolver),
  (Krylov.cgls!       => Krylov.CglsSolver          ),
  (Krylov.cg_lanczos! => Krylov.CgLanczosSolver     ),
  (Krylov.bilq!       => Krylov.BilqSolver          ),
  (Krylov.minres_qlp! => Krylov.MinresQlpSolver     ),
  (Krylov.qmr!        => Krylov.QmrSolver           ),
  (Krylov.gmres!      => Krylov.GmresSolver         ),
  (Krylov.fom!        => Krylov.FomSolver           ),
 )

function init_cacheval(alg::KrylovJL, A, b, u)

    KS = KrylovJL_solvers[alg.KrylovAlg]

    solver = if(
        KS === Krylov.DqgmresSolver ||
        KS === Krylov.DiomSolver    ||
        KS === Krylov.GmresSolver   ||
        KS === Krylov.FomSolver
       )
        KS(A, b, alg.gmres_restart)
    elseif(KS === Krylov.MinresSolver ||
           KS === Krylov.SymmlqSolver ||
           KS === Krylov.LslqSolver   ||
           KS === Krylov.LsqrSolver   ||
           KS === Krylov.LsmrSolver
          )
        (alg.window != 0) ? KS(A,b; window=alg.window) : KS(A, b)
    else
        KS(A, b)
    end

    solver.x = u

    return solver
end

function SciMLBase.solve(cache::LinearCache, alg::KrylovJL; kwargs...)
    if cache.isfresh
        solver = init_cacheval(alg, cache.A, cache.b, cache.u)
        cache = set_cacheval(cache, solver)
    end

    abstol  = (alg.abstol  == 0) ? √eps(eltype(cache.b)) : alg.abstol
    reltol  = (alg.reltol  == 0) ? √eps(eltype(cache.b)) : alg.reltol
    maxiter = (alg.maxiter == 0) ? length(cache.b)       : alg.maxiter
    verbose =  alg.ifverbose     ? 1                     : 0

    args   = (cache.cacheval, cache.A, cache.b)
    kwargs = (atol=abstol, rtol=reltol, itmax=maxiter, verbose=verbose,
              alg.kwargs...)

    if cache.cacheval isa Krylov.CgSolver
        alg.Pr != LinearAlgebra.I  &&
            @warn "$(alg.KrylovAlg) doesn't support right preconditioning."
        Krylov.solve!(args...; M=alg.Pl,
                      kwargs...)
    elseif cache.cacheval isa Krylov.GmresSolver
        Krylov.solve!(args...; M=alg.Pl, N=alg.Pr,
                      kwargs...)
    elseif cache.cacheval isa Krylov.BicgstabSolver
        Krylov.solve!(args...; M=alg.Pl, N=alg.Pr,
                      kwargs...)
    elseif cache.cacheval isa Krylov.MinresSolver
        alg.Pr != LinearAlgebra.I  &&
            @warn "$(alg.KrylovAlg) doesn't support right preconditioning."
        Krylov.solve!(args...; M=alg.Pl,
                      kwargs...)
    else
        Krylov.solve!(args...; kwargs...)
    end

    return cache.u
end

## IterativeSolvers.jl

struct IterativeSolversJL{F,Tl,Tr,T,I,A,K} <: AbstractKrylovSubspaceMethod
    generate_iterator::F
    Pl::Tl
    Pr::Tr
    abstol::T
    reltol::T
    maxiter::I
    ifverbose::Bool
    gmres_restart::I
    args::A
    kwargs::K
end

function IterativeSolversJL(args...;
                            generate_iterator = IterativeSolvers.gmres_iterable!,
                            Pl=IterativeSolvers.Identity(),
                            Pr=IterativeSolvers.Identity(),
                            abstol=0.0, reltol=0.0, maxiter=0, ifverbose=true,
                            gmres_restart=0, kwargs...)
    return IterativeSolversJL(generate_iterator, Pl, Pr,
                              abstol, reltol, maxiter, ifverbose,
                              gmres_restart, args, kwargs)
end

IterativeSolversJL_CG(args...; kwargs...) =
    IterativeSolversJL(args...;
                       generate_iterator=IterativeSolvers.cg_iterator!,
                       kwargs...)
IterativeSolversJL_GMRES(args...;kwargs...) =
    IterativeSolversJL(args...;
                       generate_iterator=IterativeSolvers.gmres_iterable!,
                       kwargs...)
IterativeSolversJL_BICGSTAB(args...;kwargs...) =
    IterativeSolversJL(args...;
                       generate_iterator=IterativeSolvers.bicgstabl_iterator!,
                       kwargs...)
IterativeSolversJL_MINRES(args...;kwargs...) =
    IterativeSolversJL(args...;
                       generate_iterator=IterativeSolvers.minres_iterable!,
                       kwargs...)

function init_cacheval(alg::IterativeSolversJL, A, b, u)
    Pl = (alg.Pl == LinearAlgebra.I) ? IterativeSolvers.Identity() : alg.Pl
    Pr = (alg.Pr == LinearAlgebra.I) ? IterativeSolvers.Identity() : alg.Pr

    abstol  = (alg.abstol  == 0) ? √eps(eltype(b)) : alg.abstol
    reltol  = (alg.reltol  == 0) ? √eps(eltype(b)) : alg.reltol
    maxiter = (alg.maxiter == 0) ? length(b)       : alg.maxiter

#   args   = (u, A, b)
    kwargs = (abstol=abstol, reltol=reltol, maxiter=maxiter, alg.kwargs...)

    iterable = if alg.generate_iterator === IterativeSolvers.cg_iterator!
        Pr != IterativeSolvers.Identity() &&
          @warn "$(alg.generate_iterator) doesn't support right preconditioning"
        alg.generate_iterator(u, A, b, Pl;
                              kwargs...)
    elseif alg.generate_iterator === IterativeSolvers.gmres_iterable!
        alg.generate_iterator(u, A, b; Pl=Pl, Pr=Pr,
                              kwargs...)
    elseif alg.generate_iterator === IterativeSolvers.bicgstabl_iterator!
        Pr != IterativeSolvers.Identity() &&
          @warn "$(alg.generate_iterator) doesn't support right preconditioning"
        alg.generate_iterator(u, A, b, alg.args...; Pl=Pl,
                              abstol=abstol, reltol=reltol,
                              max_mv_products=maxiter*2,
                              alg.kwargs...)
    else # minres, qmr
        alg.generate_iterator(u, A, b, alg.args...;
                              abstol=abstol, reltol=reltol, maxiter=maxiter,
                              alg.kwargs...)
    end
    return iterable
end

function SciMLBase.solve(cache::LinearCache, alg::IterativeSolversJL; kwargs...)
    if cache.isfresh
        solver = init_cacheval(alg, cache.A, cache.b, cache.u)
        cache = set_cacheval(cache, solver)
    end

    alg.ifverbose && println("Using IterativeSolvers.$(alg.generate_iterator)")
    for iter in enumerate(cache.cacheval)
        alg.ifverbose && println("Iter: $(iter[1]), residual: $(iter[2])")
        # inject callbacks KSP into solve cb!(cache.cacheval)
    end
    alg.ifverbose && println()

    return cache.u
end
