// Ray tracing in one weekend basecode for Dartmouth CS 77/177
// by Wojciech Jarosz, 2019

#define EPSILON 1e-3
#define MAX_FLOAT 3.402823466e+38
#define MAX_RECURSION 50
#define PI 3.1415926535897932384626433832795

//
// Hash functions by Nimitz:
// https://www.shadertoy.com/view/Xt3cDn
//

float g_seed = 0.;

uint base_hash(uvec2 p)
{
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

void init_rand(in vec2 frag_coord, in float time)
{
    g_seed = float(base_hash(floatBitsToUint(frag_coord))) / float(0xffffffffU) + time;
}

float rand1(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += .1, seed += .1)));
    return float(n) / float(0xffffffffU);
}

vec2 rand2(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += .1, seed += .1)));
    uvec2 rz = uvec2(n, n * 48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU)) / float(0x7fffffff);
}

vec3 rand3(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += .1, seed += .1)));
    uvec3 rz = uvec3(n, n * 16807U, n * 48271U);
    return vec3(rz & uvec3(0x7fffffffU)) / float(0x7fffffff);
}

vec2 random_in_unit_disk(inout float seed)
{
    vec2 h = rand2(seed) * vec2(1., 6.28318530718);
    float phi = h.y;
    float r = sqrt(h.x);
    return r * vec2(sin(phi), cos(phi));
}

vec3 random_in_unit_sphere(inout float seed)
{
    vec3 h = rand3(seed) * vec3(2., 6.28318530718, 1.) - vec3(1, 0, 0);
    float phi = h.y;
    float r = pow(h.z, 1. / 3.);
    return r * vec3(sqrt(1. - h.x * h.x) * vec2(sin(phi), cos(phi)), h.x);
}
