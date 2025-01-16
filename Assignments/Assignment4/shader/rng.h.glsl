#ifndef GLSL_RNG
#define GLSL_RNG

struct Rng {
    uint64_t state;
    uint64_t inc;
};

uint rngRnd(inout Rng rng) {
    uint64_t oldstate = rng.state;
    // Advance internal state
    rng.state = oldstate * 6364136223846793005UL + (rng.inc|1UL);
    // Calculate output function (XSH RR), uses old state for max ILP
    uint xorshifted = uint(((oldstate >> 18u) ^ oldstate) >> 27u);
    uint rot = uint(oldstate >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31U));
}

void rngInit(out Rng rng, uint64_t initstate, uint64_t initseq) {
    rng.state = 0U;
    rng.inc = (initseq << 1ul) | 1ul;
    rngRnd(rng);
    rng.state += initstate;
    rngRnd(rng);
}


float rngRndFloat(inout Rng rng) {
    // Construct a float with half-open range [0:1] using low 23 bits.
    // All zeroes yields 0.0, all ones yields the next smallest representable value below 1.0.
    const uint ieeeMantissa = 0x007FFFFFu; // binary32 mantissa bitmask
    const uint ieeeOne      = 0x3F800000u; // 1.0 in IEEE binary32

    uint m = rngRnd(rng);
    m &= ieeeMantissa;                     // Keep only mantissa bits (fractional part)
    m |= ieeeOne;                          // Add fractional part to 1.0

    float  f = uintBitsToFloat( m );       // Range [1:2]
    return f - 1.0;                        // Range [0:1]
}

vec2 rngRndVec2(inout Rng rng) {
    return vec2(rngRndFloat(rng), rngRndFloat(rng));
}

vec3 rngRndVec3(inout Rng rng) {
    return vec3(rngRndFloat(rng), rngRndFloat(rng), rngRndFloat(rng));
}

#endif
