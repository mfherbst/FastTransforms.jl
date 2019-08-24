# This file shows how to call `libfasttransforms` from Julia.

# Step 1: In this repository, `git clone -b v0.2.1 https://github.com/MikaelSlevinsky/FastTransforms.git deps/FastTransforms`

# Step 2: use a version of gcc that supports OpenMP: on OS X, this means using a
# version of `gcc` from Homebrew, `brew install gcc`; on linux, `gcc-4.6` and up should work.
# `export CC=gcc-"the-right-version"`.

# Step 3: get the remaining dependencies: On OS X, either `brew install openblas`
# or change the Make.inc to use `BLAS=APPLEBLAS` instead of `BLAS=OPENBLAS`.
# Furthermore, `brew install fftw mpfr`. For linux, see the `Travis.yml` file.
# For Windows, see the `Appveyor.yml` file.

# Step 4: run `make` and check the tests by running `./test_drivers 3 3 0`.
# All the errors should be roughly on the order of machine precision.

const libfasttransforms = joinpath(dirname(@__DIR__), "deps/FastTransforms", "libfasttransforms")

if !(find_library(libfasttransforms) ≡ libfasttransforms)
    error("FastTransforms is not properly installed. Please run Pkg.build(\"FastTransforms\") ",
          "and restart Julia.")
end

"""
    mpfr_t <: AbstractFloat

A Julia struct that exactly matches `mpfr_t`.
"""
struct mpfr_t <: AbstractFloat
    prec::Clong
    sign::Cint
    exp::Clong
    d::Ptr{Limb}
end

mpfr_t(x::BigFloat) = mpfr_t(x.prec, x.sign, x.exp, x.d)

function BigFloat(x::mpfr_t)
    nb = ccall((:mpfr_custom_get_size,:libmpfr), Csize_t, (Clong,), precision(BigFloat))
    nb = (nb + Core.sizeof(Limb) - 1) ÷ Core.sizeof(Limb) # align to number of Limb allocations required for this
    str = unsafe_string(Ptr{UInt8}(x.d), nb * Core.sizeof(Limb))
    _BigFloat(x.prec, x.sign, x.exp, str)
end

set_num_threads(n::Integer) = ccall((:ft_set_num_threads, libfasttransforms), Cvoid, (Cint, ), n)

const LEG2CHEB           = 0
const CHEB2LEG           = 1
const ULTRA2ULTRA        = 2
const JAC2JAC            = 3
const LAG2LAG            = 4
const JAC2ULTRA          = 5
const ULTRA2JAC          = 6
const JAC2CHEB           = 7
const CHEB2JAC           = 8
const ULTRA2CHEB         = 9
const CHEB2ULTRA        = 10
const SPHERE            = 11
const SPHEREV           = 12
const DISK              = 13
const TRIANGLE          = 14
const SPHERESYNTHESIS   = 15
const SPHEREANALYSIS    = 16
const SPHEREVSYNTHESIS  = 17
const SPHEREVANALYSIS   = 18
const DISKSYNTHESIS     = 19
const DISKANALYSIS      = 20
const TRIANGLESYNTHESIS = 21
const TRIANGLEANALYSIS  = 22

let k2s = Dict(LEG2CHEB          => "Legendre--Chebyshev",
               CHEB2LEG          => "Chebyshev--Legendre",
               ULTRA2ULTRA       => "ultraspherical--ultraspherical",
               JAC2JAC           => "Jacobi--Jacobi",
               LAG2LAG           => "Laguerre--Laguerre",
               JAC2ULTRA         => "Jacobi--ultraspherical",
               ULTRA2JAC         => "ultraspherical--Jacobi",
               JAC2CHEB          => "Jacobi--Chebyshev",
               CHEB2JAC          => "Chebyshev--Jacobi",
               ULTRA2CHEB        => "ultraspherical--Chebyshev",
               CHEB2ULTRA        => "Chebyshev--ultraspherical",
               SPHERE            => "Spherical harmonic--Fourier",
               SPHEREV           => "Spherical vector field--Fourier",
               DISK              => "Zernike--Chebyshev×Fourier",
               TRIANGLE          => "Proriol--Chebyshev",
               SPHERESYNTHESIS   => "FFTW Fourier synthesis on the sphere",
               SPHEREANALYSIS    => "FFTW Fourier analysis on the sphere",
               SPHEREVSYNTHESIS  => "FFTW Fourier synthesis on the sphere (vector field)",
               SPHEREVANALYSIS   => "FFTW Fourier analysis on the sphere (vector field)",
               DISKSYNTHESIS     => "FFTW Chebyshev×Fourier synthesis on the disk",
               DISKANALYSIS      => "FFTW Chebyshev×Fourier analysis on the disk",
               TRIANGLESYNTHESIS => "FFTW Chebyshev synthesis on the triangle",
               TRIANGLEANALYSIS  => "FFTW Chebyshev analysis on the triangle")
    global kind2string
    kind2string(k::Integer) = k2s[Int(k)]
end

struct ft_plan_struct end

mutable struct FTPlan{T, N, K}
    plan::Ptr{ft_plan_struct}
    n::Int
    m::Int
    function FTPlan{T, N, K}(plan::Ptr{ft_plan_struct}, n::Int) where {T, N, K}
        p = new(plan, n)
        finalizer(destroy_plan, p)
        p
    end
    function FTPlan{T, N, K}(plan::Ptr{ft_plan_struct}, n::Int, m::Int) where {T, N, K}
        p = new(plan, n, m)
        finalizer(destroy_plan, p)
        p
    end
end

eltype(p::FTPlan{T}) where {T} = T
ndims(p::FTPlan{T, N}) where {T, N} = N
show(io::IO, p::FTPlan{T, 1, K}) where {T, K} = print(io, "FastTransforms ", kind2string(K), " plan for $(p.n)-element array of ", T)
show(io::IO, p::FTPlan{T, 2, SPHERE}) where T = print(io, "FastTransforms ", kind2string(SPHERE), " plan for $(p.n)×$(2p.n-1)-element array of ", T)
show(io::IO, p::FTPlan{T, 2, SPHEREV}) where T = print(io, "FastTransforms ", kind2string(SPHEREV), " plan for $(p.n)×$(2p.n-1)-element array of ", T)
show(io::IO, p::FTPlan{T, 2, DISK}) where T = print(io, "FastTransforms ", kind2string(DISK), " plan for $(p.n)×$(4p.n-3)-element array of ", T)
show(io::IO, p::FTPlan{T, 2, TRIANGLE}) where T = print(io, "FastTransforms ", kind2string(TRIANGLE), " plan for $(p.n)×$(p.n)-element array of ", T)
show(io::IO, p::FTPlan{T, 2, K}) where {T, K} = print(io, "FastTransforms plan for ", kind2string(K), " for $(p.n)×$(p.m)-element array of ", T)

function checksize(p::FTPlan{T}, x::Array{T}) where T
    if p.n != size(x, 1)
        throw(DimensionMismatch("FTPlan has dimensions $(p.n) × $(p.n), x has leading dimension $(size(x, 1))"))
    end
end

unsafe_convert(::Type{Ptr{ft_plan_struct}}, p::FTPlan) = p.plan
unsafe_convert(::Type{Ptr{mpfr_t}}, p::FTPlan) = unsafe_convert(Ptr{mpfr_t}, p.plan)

destroy_plan(p::FTPlan{Float32, 1}) = ccall((:ft_destroy_tb_eigen_FMMf, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 1}) = ccall((:ft_destroy_tb_eigen_FMM, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{BigFloat, 1}) = ccall((:ft_mpfr_destroy_plan, libfasttransforms), Cvoid, (Ptr{mpfr_t}, Cint), p, p.n)
destroy_plan(p::FTPlan{Float64, 2}) = ccall((:ft_destroy_harmonic_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, SPHERESYNTHESIS}) = ccall((:ft_destroy_sphere_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, SPHEREANALYSIS}) = ccall((:ft_destroy_sphere_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, SPHEREVSYNTHESIS}) = ccall((:ft_destroy_sphere_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, SPHEREVANALYSIS}) = ccall((:ft_destroy_sphere_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, DISKSYNTHESIS}) = ccall((:ft_destroy_disk_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, DISKANALYSIS}) = ccall((:ft_destroy_disk_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, TRIANGLESYNTHESIS}) = ccall((:ft_destroy_triangle_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)
destroy_plan(p::FTPlan{Float64, 2, TRIANGLEANALYSIS}) = ccall((:ft_destroy_triangle_fftw_plan, libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, ), p)

struct AdjointFTPlan{T, S}
    parent::S
end

AdjointFTPlan(p::FTPlan) = AdjointFTPlan{eltype(p), typeof(p)}(p)

adjoint(p::FTPlan) = AdjointFTPlan(p)
adjoint(p::AdjointFTPlan) = p.parent

eltype(p::AdjointFTPlan{T, S}) where {T, S} = T
ndims(p::AdjointFTPlan{T, S}) where {T, S} = ndims(p.parent)
function show(io::IO, p::AdjointFTPlan{T, S}) where {T, S}
    print(io, "Adjoint ")
    show(io, p.parent)
end

checksize(p::AdjointFTPlan, x) = checksize(p.parent, x)

unsafe_convert(::Type{Ptr{ft_plan_struct}}, p::AdjointFTPlan{T, FTPlan{T, N, K}}) where {T, N, K} = unsafe_convert(Ptr{ft_plan_struct}, p.parent)
unsafe_convert(::Type{Ptr{mpfr_t}}, p::AdjointFTPlan{T, FTPlan{T, N, K}}) where {T, N, K} = unsafe_convert(Ptr{mpfr_t}, p.parent)

struct TransposeFTPlan{T, S}
    parent::S
end

TransposeFTPlan(p::FTPlan) = TransposeFTPlan{eltype(p), typeof(p)}(p)

transpose(p::FTPlan) = TransposeFTPlan(p)
transpose(p::TransposeFTPlan) = p.parent

eltype(p::TransposeFTPlan{T, S}) where {T, S} = T
ndims(p::TransposeFTPlan{T, S}) where {T, S} = ndims(p.parent)
function show(io::IO, p::TransposeFTPlan{T, S}) where {T, S}
    print(io, "Transpose ")
    show(io, p.parent)
end

checksize(p::TransposeFTPlan, x) = checksize(p.parent, x)

unsafe_convert(::Type{Ptr{ft_plan_struct}}, p::TransposeFTPlan{T, FTPlan{T, N, K}}) where {T, N, K} = unsafe_convert(Ptr{ft_plan_struct}, p.parent)
unsafe_convert(::Type{Ptr{mpfr_t}}, p::TransposeFTPlan{T, FTPlan{T, N, K}}) where {T, N, K} = unsafe_convert(Ptr{mpfr_t}, p.parent)

function plan_leg2cheb(::Type{Float32}, n::Integer; normleg::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_legendre_to_chebyshevf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint), normleg, normcheb, n)
    return FTPlan{Float32, 1, LEG2CHEB}(plan, n)
end

function plan_cheb2leg(::Type{Float32}, n::Integer; normcheb::Bool=false, normleg::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_legendref, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint), normcheb, normleg, n)
    return FTPlan{Float32, 1, CHEB2LEG}(plan, n)
end

function plan_ultra2ultra(::Type{Float32}, n::Integer, λ::Float32, μ::Float32; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_ultrasphericalf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32), norm1, norm2, n, λ, μ)
    return FTPlan{Float32, 1, ULTRA2ULTRA}(plan, n)
end

function plan_jac2jac(::Type{Float32}, n::Integer, α::Float32, β::Float32, γ::Float32, δ::Float32; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_jacobif, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32, Float32, Float32), norm1, norm2, n, α, β, γ, δ)
    return FTPlan{Float32, 1, JAC2JAC}(plan, n)
end

function plan_lag2lag(::Type{Float32}, n::Integer, α::Float32, β::Float32; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_laguerre_to_laguerref, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32), norm1, norm2, n, α, β)
    return FTPlan{Float32, 1, LAG2LAG}(plan, n)
end

function plan_jac2ultra(::Type{Float32}, n::Integer, α::Float32, β::Float32, λ::Float32; normjac::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_ultrasphericalf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32, Float32), normjac, normultra, n, α, β, λ)
    return FTPlan{Float32, 1, JAC2ULTRA}(plan, n)
end

function plan_ultra2jac(::Type{Float32}, n::Integer, λ::Float32, α::Float32, β::Float32; normultra::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_jacobif, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32, Float32), normultra, normjac, n, λ, α, β)
    return FTPlan{Float32, 1, ULTRA2JAC}(plan, n)
end

function plan_jac2cheb(::Type{Float32}, n::Integer, α::Float32, β::Float32; normjac::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_chebyshevf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32), normjac, normcheb, n, α, β)
    return FTPlan{Float32, 1, JAC2CHEB}(plan, n)
end

function plan_cheb2jac(::Type{Float32}, n::Integer, α::Float32, β::Float32; normcheb::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_jacobif, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32, Float32), normcheb, normjac, n, α, β)
    return FTPlan{Float32, 1, CHEB2JAC}(plan, n)
end

function plan_ultra2cheb(::Type{Float32}, n::Integer, λ::Float32; normultra::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_chebyshevf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32), normultra, normcheb, n, λ)
    return FTPlan{Float32, 1, ULTRA2CHEB}(plan, n)
end

function plan_cheb2ultra(::Type{Float32}, n::Integer, λ::Float32; normcheb::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_ultrasphericalf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float32), normcheb, normultra, n, λ)
    return FTPlan{Float32, 1, CHEB2ULTRA}(plan, n)
end


function plan_leg2cheb(::Type{Float64}, n::Integer; normleg::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_legendre_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint), normleg, normcheb, n)
    return FTPlan{Float64, 1, LEG2CHEB}(plan, n)
end

function plan_cheb2leg(::Type{Float64}, n::Integer; normcheb::Bool=false, normleg::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_legendre, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint), normcheb, normleg, n)
    return FTPlan{Float64, 1, CHEB2LEG}(plan, n)
end

function plan_ultra2ultra(::Type{Float64}, n::Integer, λ::Float64, μ::Float64; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64), norm1, norm2, n, λ, μ)
    return FTPlan{Float64, 1, ULTRA2ULTRA}(plan, n)
end

function plan_jac2jac(::Type{Float64}, n::Integer, α::Float64, β::Float64, γ::Float64, δ::Float64; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64, Float64, Float64), norm1, norm2, n, α, β, γ, δ)
    return FTPlan{Float64, 1, JAC2JAC}(plan, n)
end

function plan_lag2lag(::Type{Float64}, n::Integer, α::Float64, β::Float64; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_plan_laguerre_to_laguerre, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64), norm1, norm2, n, α, β)
    return FTPlan{Float64, 1, LAG2LAG}(plan, n)
end

function plan_jac2ultra(::Type{Float64}, n::Integer, α::Float64, β::Float64, λ::Float64; normjac::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64, Float64), normjac, normultra, n, α, β, λ)
    return FTPlan{Float64, 1, JAC2ULTRA}(plan, n)
end

function plan_ultra2jac(::Type{Float64}, n::Integer, λ::Float64, α::Float64, β::Float64; normultra::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64, Float64), normultra, normjac, n, λ, α, β)
    return FTPlan{Float64, 1, ULTRA2JAC}(plan, n)
end

function plan_jac2cheb(::Type{Float64}, n::Integer, α::Float64, β::Float64; normjac::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_jacobi_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64), normjac, normcheb, n, α, β)
    return FTPlan{Float64, 1, JAC2CHEB}(plan, n)
end

function plan_cheb2jac(::Type{Float64}, n::Integer, α::Float64, β::Float64; normcheb::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64, Float64), normcheb, normjac, n, α, β)
    return FTPlan{Float64, 1, CHEB2JAC}(plan, n)
end

function plan_ultra2cheb(::Type{Float64}, n::Integer, λ::Float64; normultra::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_plan_ultraspherical_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64), normultra, normcheb, n, λ)
    return FTPlan{Float64, 1, ULTRA2CHEB}(plan, n)
end

function plan_cheb2ultra(::Type{Float64}, n::Integer, λ::Float64; normcheb::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_plan_chebyshev_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Float64), normcheb, normultra, n, λ)
    return FTPlan{Float64, 1, CHEB2ULTRA}(plan, n)
end


function plan_leg2cheb(::Type{BigFloat}, n::Integer; normleg::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_mpfr_plan_legendre_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Clong, Int32), normleg, normcheb, n, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, LEG2CHEB}(plan, n)
end

function plan_cheb2leg(::Type{BigFloat}, n::Integer; normcheb::Bool=false, normleg::Bool=false)
    plan = ccall((:ft_mpfr_plan_chebyshev_to_legendre, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Clong, Int32), normcheb, normleg, n, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, CHEB2LEG}(plan, n)
end

function plan_ultra2ultra(::Type{BigFloat}, n::Integer, λ::BigFloat, μ::BigFloat; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_mpfr_plan_ultraspherical_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), norm1, norm2, n, λ, μ, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, ULTRA2ULTRA}(plan, n)
end

function plan_jac2jac(::Type{BigFloat}, n::Integer, α::BigFloat, β::BigFloat, γ::BigFloat, δ::BigFloat; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_mpfr_plan_jacobi_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), norm1, norm2, n, α, β, γ, δ, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, JAC2JAC}(plan, n)
end

function plan_lag2lag(::Type{BigFloat}, n::Integer, α::BigFloat, β::BigFloat; norm1::Bool=false, norm2::Bool=false)
    plan = ccall((:ft_mpfr_plan_laguerre_to_laguerre, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), norm1, norm2, n, α, β, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, LAG2LAG}(plan, n)
end

function plan_jac2ultra(::Type{BigFloat}, n::Integer, α::BigFloat, β::BigFloat, λ::BigFloat; normjac::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_mpfr_plan_jacobi_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), normjac, normultra, n, α, β, λ, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, JAC2ULTRA}(plan, n)
end

function plan_ultra2jac(::Type{BigFloat}, n::Integer, λ::BigFloat, α::BigFloat, β::BigFloat; normultra::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_mpfr_plan_ultraspherical_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), normultra, normjac, n, λ, α, β, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, ULTRA2JAC}(plan, n)
end

function plan_jac2cheb(::Type{BigFloat}, n::Integer, α::BigFloat, β::BigFloat; normjac::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_mpfr_plan_jacobi_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), normjac, normcheb, n, α, β, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, JAC2CHEB}(plan, n)
end

function plan_cheb2jac(::Type{BigFloat}, n::Integer, α::BigFloat, β::BigFloat; normcheb::Bool=false, normjac::Bool=false)
    plan = ccall((:ft_mpfr_plan_chebyshev_to_jacobi, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Ref{BigFloat}, Clong, Int32), normcheb, normjac, n, α, β, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, CHEB2JAC}(plan, n)
end

function plan_ultra2cheb(::Type{BigFloat}, n::Integer, λ::BigFloat; normultra::Bool=false, normcheb::Bool=false)
    plan = ccall((:ft_mpfr_plan_ultraspherical_to_chebyshev, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Clong, Int32), normultra, normcheb, n, λ, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, ULTRA2CHEB}(plan, n)
end

function plan_cheb2ultra(::Type{BigFloat}, n::Integer, λ::BigFloat; normcheb::Bool=false, normultra::Bool=false)
    plan = ccall((:ft_mpfr_plan_chebyshev_to_ultraspherical, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint, Cint, Ref{BigFloat}, Clong, Int32), normcheb, normultra, n, λ, precision(BigFloat), Base.MPFR.ROUNDING_MODE[])
    return FTPlan{BigFloat, 1, CHEB2ULTRA}(plan, n)
end


function plan_sph2fourier(::Type{Float64}, n::Integer)
    plan = ccall((:ft_plan_sph2fourier, libfasttransforms), Ptr{ft_plan_struct}, (Cint, ), n)
    return FTPlan{Float64, 2, SPHERE}(plan, n)
end

function plan_sphv2fourier(::Type{Float64}, n::Integer)
    plan = ccall((:ft_plan_sph2fourier, libfasttransforms), Ptr{ft_plan_struct}, (Cint, ), n)
    return FTPlan{Float64, 2, SPHEREV}(plan, n)
end

function plan_disk2cxf(::Type{Float64}, n::Integer)
    plan = ccall((:ft_plan_disk2cxf, libfasttransforms), Ptr{ft_plan_struct}, (Cint, ), n)
    return FTPlan{Float64, 2, DISK}(plan, n)
end

function plan_tri2cheb(::Type{Float64}, n::Integer, α::Float64, β::Float64, γ::Float64)
    plan = ccall((:ft_plan_tri2cheb, libfasttransforms), Ptr{ft_plan_struct}, (Cint, Float64, Float64, Float64), n, α, β, γ)
    return FTPlan{Float64, 2, TRIANGLE}(plan, n)
end

for (fJ, fC, fE, K) in ((:plan_sph_synthesis, :ft_plan_sph_synthesis, :ft_execute_sph_synthesis, SPHERESYNTHESIS),
                    (:plan_sph_analysis, :ft_plan_sph_analysis, :ft_execute_sph_analysis, SPHEREANALYSIS),
                    (:plan_sphv_synthesis, :ft_plan_sphv_synthesis, :ft_execute_sphv_synthesis, SPHEREVSYNTHESIS),
                    (:plan_sphv_analysis, :ft_plan_sphv_analysis, :ft_execute_sphv_analysis, SPHEREVANALYSIS),
                    (:plan_disk_synthesis, :ft_plan_disk_synthesis, :ft_execute_disk_synthesis, DISKSYNTHESIS),
                    (:plan_disk_analysis, :ft_plan_disk_analysis, :ft_execute_disk_analysis, DISKANALYSIS),
                    (:plan_tri_synthesis, :ft_plan_tri_synthesis, :ft_execute_tri_synthesis, TRIANGLESYNTHESIS),
                    (:plan_tri_analysis, :ft_plan_tri_analysis, :ft_execute_tri_analysis, TRIANGLEANALYSIS))
    @eval begin
        function $fJ(::Type{Float64}, n::Integer, m::Integer)
            plan = ccall(($(string(fC)), libfasttransforms), Ptr{ft_plan_struct}, (Cint, Cint), n, m)
            return FTPlan{Float64, 2, $K}(plan, n, m)
        end
        function lmul!(p::FTPlan{Float64, 2, $K}, x::Matrix{Float64})
            if p.n != size(x, 1) || p.m != size(x, 2)
                throw(DimensionMismatch("FTPlan has dimensions $(p.n) × $(p.m), x has dimensions $(size(x, 1)) × $(size(x, 2))"))
            end
            ccall(($(string(fE)), libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, Ptr{Float64}, Cint, Cint), p, x, size(x, 1), size(x, 2))
            return x
        end
    end
end

*(p::FTPlan{T}, x::VecOrMat{T}) where T = lmul!(p, deepcopy(x))
*(p::AdjointFTPlan{T}, x::VecOrMat{T}) where T = lmul!(p, deepcopy(x))
*(p::TransposeFTPlan{T}, x::VecOrMat{T}) where T = lmul!(p, deepcopy(x))
\(p::FTPlan{T}, x::VecOrMat{T}) where T = ldiv!(p, deepcopy(x))
\(p::AdjointFTPlan{T}, x::VecOrMat{T}) where T = ldiv!(p, deepcopy(x))
\(p::TransposeFTPlan{T}, x::VecOrMat{T}) where T = ldiv!(p, deepcopy(x))

for (fJ, fC, elty) in ((:lmul!, :ft_bfmvf, :Float32),
                       (:ldiv!, :ft_bfsvf, :Float32),
                       (:lmul!, :ft_bfmv , :Float64),
                       (:ldiv!, :ft_bfsv , :Float64))
    @eval begin
        function $fJ(p::FTPlan{$elty, 1}, x::Vector{$elty})
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}), 'N', p, x)
            return x
        end
        function $fJ(p::AdjointFTPlan{$elty, FTPlan{$elty, 1, K}}, x::Vector{$elty}) where K
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}), 'T', p, x)
            return x
        end
        function $fJ(p::TransposeFTPlan{$elty, FTPlan{$elty, 1, K}}, x::Vector{$elty}) where K
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}), 'T', p, x)
            return x
        end
    end
end

for (fJ, fC) in ((:lmul!, :ft_mpfr_trmv),
                 (:ldiv!, :ft_mpfr_trsv))
    @eval begin
        function $fJ(p::FTPlan{BigFloat, 1}, x::Vector{BigFloat})
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Int32), 'N', p.n, p, p.n, xc, Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
        function $fJ(p::AdjointFTPlan{BigFloat, FTPlan{BigFloat, 1, K}}, x::Vector{BigFloat}) where K
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Int32), 'T', p.parent.n, p, p.parent.n, xc, Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
        function $fJ(p::TransposeFTPlan{BigFloat, FTPlan{BigFloat, 1, K}}, x::Vector{BigFloat}) where K
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Int32), 'T', p.parent.n, p, p.parent.n, xc, Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
    end
end

for (fJ, fC, elty) in ((:lmul!, :ft_bfmmf, :Float32),
                       (:ldiv!, :ft_bfsmf, :Float32),
                       (:lmul!, :ft_bfmm , :Float64),
                       (:ldiv!, :ft_bfsm , :Float64))
    @eval begin
        function $fJ(p::FTPlan{$elty, 1}, x::Matrix{$elty})
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}, Cint, Cint), 'N', p, x, size(x, 1), size(x, 2))
            return x
        end
        function $fJ(p::AdjointFTPlan{$elty, FTPlan{$elty, 1, K}}, x::Matrix{$elty}) where K
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}, Cint, Cint), 'T', p, x, size(x, 1), size(x, 2))
            return x
        end
        function $fJ(p::TransposeFTPlan{$elty, FTPlan{$elty, 1, K}}, x::Matrix{$elty}) where K
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Ptr{ft_plan_struct}, Ptr{$elty}, Cint, Cint), 'T', p, x, size(x, 1), size(x, 2))
            return x
        end
    end
end

for (fJ, fC) in ((:lmul!, :ft_mpfr_trmm),
                 (:ldiv!, :ft_mpfr_trsm))
    @eval begin
        function $fJ(p::FTPlan{BigFloat, 1}, x::Matrix{BigFloat})
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Cint, Cint, Int32), 'N', p.n, p, p.n, xc, size(x, 1), size(x, 2), Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
        function $fJ(p::AdjointFTPlan{BigFloat, FTPlan{BigFloat, 1, K}}, x::Matrix{BigFloat}) where K
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Cint, Cint, Int32), 'T', p.parent.n, p, p.parent.n, xc, size(x, 1), size(x, 2), Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
        function $fJ(p::TransposeFTPlan{BigFloat, FTPlan{BigFloat, 1, K}}, x::Matrix{BigFloat}) where K
            checksize(p, x)
            xt = deepcopy.(x)
            xc = mpfr_t.(xt)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Cint, Cint, Ptr{mpfr_t}, Cint, Ptr{mpfr_t}, Cint, Cint, Int32), 'T', p.parent.n, p, p.parent.n, xc, size(x, 1), size(x, 2), Base.MPFR.ROUNDING_MODE[])
            x .= BigFloat.(xc)
            return x
        end
    end
end

for (fJ, fC, K) in ((:lmul!, :ft_execute_sph2fourier, SPHERE),
                    (:ldiv!, :ft_execute_fourier2sph, SPHERE),
                    (:lmul!, :ft_execute_sphv2fourier, SPHEREV),
                    (:ldiv!, :ft_execute_fourier2sphv, SPHEREV),
                    (:lmul!, :ft_execute_disk2cxf, DISK),
                    (:ldiv!, :ft_execute_cxf2disk, DISK),
                    (:lmul!, :ft_execute_tri2cheb, TRIANGLE),
                    (:ldiv!, :ft_execute_cheb2tri, TRIANGLE))
    @eval begin
        function $fJ(p::FTPlan{Float64, 2, $K}, x::Matrix{Float64})
            checksize(p, x)
            ccall(($(string(fC)), libfasttransforms), Cvoid, (Ptr{ft_plan_struct}, Ptr{Float64}, Cint, Cint), p, x, size(x, 1), size(x, 2))
            return x
        end
    end
end
