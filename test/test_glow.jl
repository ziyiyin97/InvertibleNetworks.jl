# Generative model w/ Glow architecture from Kingma & Dhariwal (2018)
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

using InvertibleNetworks, LinearAlgebra, Test

# Define network
nx = 32
ny = 32
n_in = 2
n_hidden = 4
batchsize = 2
L = 2
K = 2

###################################################################################################
# Invertibility

# Network and input
G = NetworkGlow(nx, ny, n_in, batchsize, n_hidden, L, K)
X = rand(Float32, nx, ny, n_in, batchsize)

Y = G.forward(X)[1]
X_ = G.backward(Y, Y)[2]

@test isapprox(norm(X - X_)/norm(X), 0f0; atol=1f-5)

###################################################################################################
# Test gradients are set and cleared

P = get_params(G)
gsum = 0
for p in P
    ~isnothing(p.grad) && (global gsum += 1)
end
@test isequal(gsum, L*K*10)

clear_grad!(G)
gsum = 0
for p in P
    ~isnothing(p.grad) && (global gsum += 1)
end
@test isequal(gsum, 0)


###################################################################################################
# Gradient test

function loss(G, X)
    Y, logdet = G.forward(X)
    f = .5f0/batchsize*norm(Y)^2 - logdet
    ΔX, X_ = G.backward(1f0./batchsize*Y, Y)
    return f, ΔX, G.CL[1,1].RB.W1.grad, G.CL[1,1].C.v1.grad
end

# Gradient test w.r.t. input
G = NetworkGlow(nx, ny, n_in, batchsize, n_hidden, L, K)
X = rand(Float32, nx, ny, n_in, batchsize)
X0 = rand(Float32, nx, ny, n_in, batchsize)
dX = X - X0

f0, ΔX = loss(G, X0)[1:2]
h = 0.01f0
maxiter = 6
err1 = zeros(Float32, maxiter)
err2 = zeros(Float32, maxiter)

print("\nGradient test glow: input\n")
for j=1:maxiter
    f = loss(G, X0 + h*dX,)[1]
    err1[j] = abs(f - f0)
    err2[j] = abs(f - f0 - h*dot(dX, ΔX))
    print(err1[j], "; ", err2[j], "\n")
    global h = h/2f0
end

@test isapprox(err1[end] / (err1[1]/2^(maxiter-1)), 1f0; atol=1f1)
@test isapprox(err2[end] / (err2[1]/4^(maxiter-1)), 1f0; atol=1f1)

# Gradient test w.r.t. parameters
X = rand(Float32, nx, ny, n_in, batchsize)
G = NetworkGlow(nx, ny, n_in, batchsize, n_hidden, L, K)
G0 = NetworkGlow(nx, ny, n_in, batchsize, n_hidden, L, K)
Gini = deepcopy(G0)

# Test one parameter from residual block and 1x1 conv
dW = G.CL[1,1].RB.W1.data - G0.CL[1,1].RB.W1.data
dv = G.CL[1,1].C.v1.data - G0.CL[1,1].C.v1.data

f0, ΔX, ΔW, Δv = loss(G0, X)
h = 0.01f0
maxiter = 6
err3 = zeros(Float32, maxiter)
err4 = zeros(Float32, maxiter)

print("\nGradient test glow: input\n")
for j=1:maxiter
    G0.CL[1,1].RB.W1.data = Gini.CL[1,1].RB.W1.data + h*dW
    G0.CL[1,1].C.v1.data = Gini.CL[1,1].C.v1.data + h*dv

    f = loss(G0, X)[1]
    err3[j] = abs(f - f0)
    err4[j] = abs(f - f0 - h*dot(dW, ΔW) - h*dot(dv, Δv))
    print(err3[j], "; ", err4[j], "\n")
    global h = h/2f0
end

@test isapprox(err3[end] / (err3[1]/2^(maxiter-1)), 1f0; atol=1f1)
@test isapprox(err4[end] / (err4[1]/4^(maxiter-1)), 1f0; atol=1f1)

