function cjt(c::AbstractVector,plan::ChebyshevJacobiPlan)
    α,β = getplanαβ(plan)
    N = length(c)
    N ≤ 1 && return c
    if modαβ(α) == 0.5 && modαβ(β) == 0.5
        ret = copy(c)
        if α == -0.5 && β == 0.5
            decrementβ!(ret,α,β)
        elseif α == 0.5 && β == -0.5
            decrementα!(ret,α,β)
        elseif α == 0.5 && β == 0.5
            decrementαβ!(ret,α,β)
        else
            tosquare!(ret,α,β)
        end
        for i=1:N ret[i] *= Λ(i-1.0)/sqrtpi end
        return ret
    else
        # General half-open square
        ret = tosquare!(copy(c),α,β)
        ret = jac2cheb(ret,modαβ(α),modαβ(β),plan)
        return ret
    end
end

function cjt(c::AbstractVector,plan::ChebyshevUltrasphericalPlan)
    λ = getplanλ(plan)
    N = length(c)
    N ≤ 1 && return c
    if modλ(λ) == 0
        ret = toline!(copy(c),λ-one(λ)/2,λ-one(λ)/2)
        for i=1:N ret[i] *= Λ(i-1.0)/sqrtpi end
        return ret
    else
        # Ultraspherical line
        ret = toline!(copy(c),λ-one(λ)/2,λ-one(λ)/2)
        ret = ultra2cheb(ret,modλ(λ),plan)
        return ret
    end
end

function icjt(c::AbstractVector,plan::ChebyshevJacobiPlan)
    α,β = getplanαβ(plan)
    N = length(c)
    N ≤ 1 && return c
    if modαβ(α) == 0.5 && modαβ(β) == 0.5
        ret = copy(c)
        for i=1:N ret[i] *= sqrtpi/Λ(i-1.0) end
        if α == -0.5 && β == 0.5
            incrementβ!(ret,α,β-1)
            return ret
        elseif α == 0.5 && β == -0.5
            incrementα!(ret,α-1,β)
            return ret
        elseif α == 0.5 && β == 0.5
            incrementαβ!(ret,α-1,β-1)
            return ret
        else
            return fromsquare!(ret,α,β)
        end
    else
        # General half-open square
        ret = cheb2jac(c,modαβ(α),modαβ(β),plan)
        fromsquare!(ret,α,β)
        return ret
    end
end

function icjt(c::AbstractVector,plan::ChebyshevUltrasphericalPlan)
    λ = getplanλ(plan)
    N = length(c)
    N ≤ 1 && return c
    if modλ(λ) == 0
        ret = copy(c)
        for i=1:N ret[i] *= sqrtpi/Λ(i-1.0) end
        fromline!(ret,λ-one(λ)/2,λ-one(λ)/2)
        return ret
    else
        # Ultraspherical line
        ret = cheb2ultra(c,modλ(λ),plan)
        fromline!(ret,λ-one(λ)/2,λ-one(λ)/2)
        return ret
    end
end


function plan_cjt(c::AbstractVector,λ;M::Int=7)
    P = ForwardChebyshevUltrasphericalPlan(c,modλ(λ),M)
    P.CUC.λ = λ
    P
end
function plan_icjt(c::AbstractVector,λ;M::Int=7)
    P = BackwardChebyshevUltrasphericalPlan(c,modλ(λ),M)
    P.CUC.λ = λ
    P
end

for (op,plan_op,D) in ((:cjt,:plan_cjt,:FORWARD),(:icjt,:plan_icjt,:BACKWARD))
    @eval begin
        $op(c,λ) = $plan_op(c,λ)*c
        *{T<:AbstractFloat}(p::FastTransformPlan{$D,T},c::AbstractVector{T}) = $op(c,p)
        $plan_op{T<:AbstractFloat}(c::AbstractVector{Complex{T}},α,β;M::Int=7) = $plan_op(real(c),α,β;M=M)
        $plan_op{T<:AbstractFloat}(c::AbstractVector{Complex{T}},λ;M::Int=7) = $plan_op(real(c),λ;M=M)
        $plan_op(c::AbstractMatrix,α,β;M::Int=7) = $plan_op(slice(c,1:size(c,1)),α,β;M=M)
        $plan_op(c::AbstractMatrix,λ;M::Int=7) = $plan_op(slice(c,1:size(c,1)),λ;M=M)
    end
end

function *{D,T<:AbstractFloat}(p::FastTransformPlan{D,T},c::AbstractVector{Complex{T}})
    cr,ci = reim(c)
    complex(p*cr,p*ci)
end

function *(p::FastTransformPlan,c::AbstractMatrix)
    m,n = size(c)
    ret = zero(c)
    for j=1:n ret[:,j] = p*slice(c,1:m,j) end
    ret
end


"""
Computes the Chebyshev expansion coefficients
given the Jacobi expansion coefficients ``c`` with parameters ``α`` and ``β``.

See also [`icjt`](#method__icjt.1) and [`jjt`](#method__jjt.1).
"""
cjt(c,α,β) = plan_cjt(c,α,β)*c

"""
Computes the Jacobi expansion coefficients with parameters ``α`` and ``β``
given the Chebyshev expansion coefficients ``c``.

See also [`cjt`](#method__cjt.1) and [`jjt`](#method__jjt.1).
"""
icjt(c,α,β) = plan_icjt(c,α,β)*c

"""
Computes the Jacobi expansion coefficients with parameters ``γ`` and ``δ``
given the Jacobi expansion coefficients ``c`` with parameters ``α`` and ``β``.

See also [`cjt`](#method__cjt.1) and [`icjt`](#method__icjt.1).
"""
function jjt(c,α,β,γ,δ)
    if isapprox(α,γ) && isapprox(β,δ)
        copy(c)
    else
        icjt(cjt(c,α,β),γ,δ)
    end
end


"""
Pre-plan optimized DCT-I and DST-I plans and pre-allocate the necessary
arrays, normalization constants, and recurrence coefficients for a forward Chebyshev—Jacobi transform.

``c`` is the vector of coefficients; and,

``α`` and ``β`` are the Jacobi parameters.

Optionally:

``M`` determines the number of terms in Hahn's asymptotic expansion.
"""
function plan_cjt(c::AbstractVector,α,β;M::Int=7)
    α == β && return plan_cjt(c,α+one(α)/2;M=M)
    P = ForwardChebyshevJacobiPlan(c,modαβ(α),modαβ(β),M)
    P.CJC.α,P.CJC.β = α,β
    P
end

"""
Pre-plan optimized DCT-I and DST-I plans and pre-allocate the necessary
arrays, normalization constants, and recurrence coefficients for an inverse Chebyshev—Jacobi transform.

``c`` is the vector of coefficients; and,

``α`` and ``β`` are the Jacobi parameters.

Optionally:

``M`` determines the number of terms in Hahn's asymptotic expansion.
"""
function plan_icjt(c::AbstractVector,α,β;M::Int=7)
    α == β && return plan_icjt(c,α+one(α)/2;M=M)
    P = BackwardChebyshevJacobiPlan(c,modαβ(α),modαβ(β),M)
    P.CJC.α,P.CJC.β = α,β
    P
end
