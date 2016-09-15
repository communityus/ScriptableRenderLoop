#ifndef UNITY_COMMON_INCLUDED
#define UNITY_COMMON_INCLUDED

// Include platform header
#if defined(SHADER_API_XBOXONE)
#include "Platform/XboxOne.hlsl"
#endif

// Include language header
#if defined(SHADER_API_D3D11)
#include "API/D3D11.hlsl"
#endif

#endif

// ----------------------------------------------------------------------------
// Common math definition and fastmath function
// ----------------------------------------------------------------------------

#define PI			3.14159265359f
#define TWO_PI		6.28318530718f
#define FOUR_PI		12.56637061436f
#define INV_PI		0.31830988618f
#define INV_TWO_PI	0.15915494309f							
#define INV_FOUR_PI	0.07957747155f
#define HALF_PI		1.57079632679f
#define INV_HALF_PI	0.636619772367f

// Ref: https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/
float FastACos(float inX) 
{ 
    float x = abs(inX); 
    float res = -0.156583f * x + HALF_PI; 
    res *= sqrt(1.0f - x); 
    return (inX >= 0) ? res : PI - res; 
}

// Same cost as Acos + 1 FR
// Same error
// input [-1, 1] and output [-PI/2, PI/2]
float FastASin(float x)
{
    return HALF_PI - FastACos(x);
}

// max absolute error 1.3x10^-3
// Eberly's odd polynomial degree 5 - respect bounds
// 4 VGPR, 14 FR (10 FR, 1 QR), 2 scalar
// input [0, infinity] and output [0, PI/2]
float FastATanPos(float inX) 
{ 
    float t0 = (x < 1.0f) ? x : 1.0f / x;
    float t1 = t0 * t0;
    float poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

// 4 VGPR, 16 FR (12 FR, 1 QR), 2 scalar
// input [-infinity, infinity] and output [-PI/2, PI/2]
float FastATan(float x) 
{     
    float t0 = FastATanPos(abs(x));     
    return (x < 0.0f) ? -t0: t0; 
}

#endif // UNITY_COMMON_INCLUDED