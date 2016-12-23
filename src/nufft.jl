function nufft1_plan{T<:AbstractFloat}( x::AbstractVector{T}, ϵ::T )
(s_vec, t_idx, γ) = FindAlgorithmicParameters( x )
K = FindK(γ, ϵ)   
(u, v) = constructAK(x, K)
p( c ) = (u.*(fft(Diagonal(c)*v,1)[t_idx,:]))*ones(K)
end

function nufft2_plan{T<:AbstractFloat}( ω::AbstractVector{T}, ϵ::T )
N = size(ω, 1)
(s_vec, t_idx, γ) = FindAlgorithmicParameters( ω/N )
K = FindK(γ, ϵ) 
(u, v) = constructAK(ω/N, K) 
In = speye(eltype(c),  N, N)
p( c ) = (v.*(N*conj(ifft(In[:,t_idx]*conj(Diagonal(c)*u),1))))*ones(K)
end

nufft_plan{T<:AbstractFloat}( x::AbstractVector{T}, ϵ::T ) = nufft1_plan( x, ϵ )
nufft{T<:AbstractFloat}( c::AbstractVector, x::AbstractVector{T}, ϵ::T ) = nufft_plan(x, ϵ)(c) 
nufft1{T<:AbstractFloat}( c::AbstractVector, x::AbstractVector{T}, ϵ::T ) = nufft1_plan(x, ϵ)(c) 
nufft2{T<:AbstractFloat}( c::AbstractVector, ω::AbstractVector{T}, ϵ::T ) = nufft2_plan(ω, ϵ)(c)

FindK{T<:AbstractFloat}(γ::T, ϵ::T) = Int( ceil(5.0*γ.*exp(lambertw(log(10.0/ϵ)./γ/7.0))) )

function FindAlgorithmicParameters{T<:AbstractFloat}( x::AbstractVector{T} )
N = size(x, 1)
Nx = N*x
s_vec = round(Nx)
t_idx = mod(round(Int64, Nx), N) + 1
γ = norm(Nx - s_vec, Inf)
return (s_vec, t_idx, γ)
end

function constructAK{T<:AbstractFloat}(x::AbstractVector{T}, K::Int64) 
# Construct a low rank approximation, using Chebyshev expansions 
# for AK = exp(-2*pi*1im*(x[j]-j/N)*k): 

N = size(x, 1)
(s_vec, t_idx, γ) = FindAlgorithmicParameters( x ) 
er = N*x - s_vec

# colspace vectors:
u = Diagonal(exp(-1im*pi*er))*ChebyshevP(K-1, er/γ)*Bessel_coeffs(K, γ)

# rowspace vectors:
v = ChebyshevP(K-1, 2.0*collect(0:N-1)/N - ones(N) )

return (u, v)
end 

function Bessel_coeffs(K::Int64, γ::Float64)::Array{Complex{Float64},2}
# Calculate the Chebyshev coefficients of exp(-2*pi*1im*x*y) on [-gam,gam]x[0,1]

cfs = complex(zeros( K, K ))
arg = -γ*pi/2.0
for p = 0:K-1
 	for q = mod(p,2):2:K-1 
		cfs[p+1,q+1] = 4.0*(1im)^q*besselj((p+q)/2,arg).*besselj((q-p)/2,arg)
	end 
end
cfs[1,:] = cfs[1,:]/2.0
cfs[:,1] = cfs[:,1]/2.0
return cfs
end

function ChebyshevP{T<:AbstractFloat}(n::Int64, x::AbstractVector{T})::AbstractArray{T} 
# Evaluate Chebyshev polynomials of degree 0,...,n at x:

N = size(x, 1)
Tcheb = Array{T}(N, n+1)

# T_0(x) = 1.0
One = convert(eltype(x),1.0)
@inbounds for j = 1:N
	Tcheb[j, 1] = One
end
# T_1(x) = x
if ( n > 0 ) 
	@inbounds for j = 1:N
		Tcheb[j, 2] = x[j]
	end
end
# 3-term recurrence relation: 
twoX = 2x
@inbounds for k = 2:n
	@inbounds for j = 1:N
    		Tcheb[j, k+1] = twoX[j]*Tcheb[j, k] - Tcheb[j, k-1]
	end
end
return Tcheb
end 
