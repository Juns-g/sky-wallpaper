import Foundation

enum SkyShaderSource {
    static let metalSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct SkyUniforms {
        float2 resolution;       // physical pixel size (e.g. 3840x2160)
        float time;              // elapsed seconds
        float sunElevation;      // degrees (-90..90)
        float2 sunScreenPos;     // normalized [0..1] (y=0 bottom, y=1 top)
        float2 moonScreenPos;    // normalized [0..1]
        float moonElevation;     // degrees
        float moonIllumination;  // 0..1
        float moonPhase;         // 0=new, 0.5=full, 1=new
        float showMoon;          // 0=off (minimal), 1=on
        float cloudStrength;     // 0=pure, 1=fine cirrus
        float cosmosStrength;    // 0=normal, 1=deep cosmos
        float starIntensity;     // 0..1.5
        float lstRadians;        // local sidereal time in radians
        float isMorning;         // 1.0 morning, 0.0 evening
    };

    struct StarInstance {
        float2 position;    // normalized [0..1] (y=0 bottom, y=1 top)
        float3 color;       // linear-ish RGB
        float brightness;   // intensity
        float size;         // logical radius in px
        float twinkleSeed;  // phase offset
    };

    struct FullscreenOut {
        float4 position [[position]];
        float2 uv; // (0,0) bottom-left, (1,1) top-right
    };

    vertex FullscreenOut skyVertex(uint vid [[vertex_id]]) {
        const float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        FullscreenOut out;
        out.position = float4(pos[vid], 0.0, 1.0);
        out.uv = pos[vid] * 0.5 + 0.5;
        return out;
    }

    static inline float hash21(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    static inline float valueNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash21(i);
        float b = hash21(i + float2(1.0, 0.0));
        float c = hash21(i + float2(0.0, 1.0));
        float d = hash21(i + float2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    static inline float fbm6(float2 p) {
        float v = 0.0;
        float amp = 0.5;
        float2x2 rot = float2x2(0.80, 0.60, -0.60, 0.80);
        for (int i = 0; i < 6; i++) {
            v += amp * valueNoise(p);
            p = rot * p * 2.07 + float2(17.1, 31.7);
            amp *= 0.48;
        }
        return v;
    }

    struct SkyPalette {
        float3 zenith;
        float3 upper;
        float3 mid;
        float3 lower;
        float3 horizon;
        float3 sunCore;
        float3 sunGlow;
    };

    static inline SkyPalette mixPalette(SkyPalette a, SkyPalette b, float t) {
        t = clamp(t, 0.0, 1.0);
        float s = t * t * (3.0 - 2.0 * t);
        SkyPalette out;
        out.zenith  = mix(a.zenith,  b.zenith,  s);
        out.upper   = mix(a.upper,   b.upper,   s);
        out.mid     = mix(a.mid,     b.mid,     s);
        out.lower   = mix(a.lower,   b.lower,   s);
        out.horizon = mix(a.horizon, b.horizon, s);
        out.sunCore = mix(a.sunCore, b.sunCore, s);
        out.sunGlow = mix(a.sunGlow, b.sunGlow, s);
        return out;
    }

    // Luminous, clean, Apple-grade atmospheric color stops (crafted directly in perceptual sRGB
    // to completely prevent muddy grey-brown midtones during twilight & golden hour)
    static inline SkyPalette paletteForElevation(float elev, float cosmos) {
        // Translucent deep sapphire night (rich midnight blue -> luminous indigo horizon, never dead black)
        SkyPalette deepNight = {
            mix(float3(0.030, 0.056, 0.148), float3(0.016, 0.032, 0.095), cosmos),
            mix(float3(0.048, 0.088, 0.222), float3(0.028, 0.056, 0.155), cosmos),
            mix(float3(0.078, 0.132, 0.305), float3(0.050, 0.092, 0.230), cosmos),
            mix(float3(0.122, 0.192, 0.398), float3(0.088, 0.148, 0.325), cosmos),
            mix(float3(0.185, 0.268, 0.495), float3(0.142, 0.215, 0.420), cosmos),
            float3(0.70, 0.78, 0.96),
            float3(0.28, 0.38, 0.65)
        };

        // Astronomical twilight: velvety deep royal indigo
        SkyPalette astroTwilight = {
            float3(0.068, 0.108, 0.285),
            float3(0.118, 0.172, 0.405),
            float3(0.195, 0.238, 0.490),
            float3(0.320, 0.310, 0.540),
            float3(0.495, 0.395, 0.545),
            float3(0.95,  0.72,  0.65),
            float3(0.68,  0.46,  0.56)
        };

        // Civil twilight / blue hour: electric royal violet-blue -> clean lavender -> warm coral apricot
        SkyPalette civilTwilight = {
            float3(0.145, 0.205, 0.495),
            float3(0.235, 0.280, 0.580),
            float3(0.415, 0.385, 0.635),
            float3(0.710, 0.525, 0.595),
            float3(0.965, 0.675, 0.505),
            float3(1.00,  0.86,  0.68),
            float3(1.00,  0.64,  0.44)
        };

        // Sunrise / Sunset (0°..+2°): royal cobalt zenith -> crisp periwinkle -> champagne apricot gold
        SkyPalette horizonSun = {
            float3(0.165, 0.275, 0.685),
            float3(0.265, 0.395, 0.775),
            float3(0.455, 0.535, 0.815),
            float3(0.755, 0.715, 0.765),
            float3(0.998, 0.805, 0.545),
            float3(1.00,  0.96,  0.84),
            float3(1.00,  0.80,  0.52)
        };

        // Golden hour / low winter sun (+9°..+18°): deep vibrant cobalt -> airy azure -> soft warm horizon
        SkyPalette goldenHour = {
            float3(0.168, 0.335, 0.790),
            float3(0.275, 0.470, 0.875),
            float3(0.460, 0.625, 0.915),
            float3(0.715, 0.780, 0.910),
            float3(0.975, 0.855, 0.685),
            float3(1.00,  0.98,  0.90),
            float3(1.00,  0.90,  0.72)
        };

        // Crisp winter / spring midday (+30°): radiant cerulean-cobalt sky
        SkyPalette midday = {
            float3(0.145, 0.390, 0.905),
            float3(0.240, 0.515, 0.955),
            float3(0.415, 0.665, 0.980),
            float3(0.655, 0.815, 0.992),
            float3(0.855, 0.925, 0.996),
            float3(1.00,  0.995, 0.96),
            float3(0.96,  0.97,  1.00)
        };

        // Vibrant summer high noon (+58°+): electric clear blue sky
        SkyPalette highNoon = {
            float3(0.132, 0.368, 0.892),
            float3(0.220, 0.495, 0.952),
            float3(0.390, 0.650, 0.980),
            float3(0.625, 0.800, 0.992),
            float3(0.835, 0.915, 0.996),
            float3(1.00,  1.00,  0.98),
            float3(0.95,  0.98,  1.00)
        };

        if (elev <= -15.0) {
            return deepNight;
        } else if (elev <= -9.5) {
            return mixPalette(deepNight, astroTwilight, (elev + 15.0) / 5.5);
        } else if (elev <= -3.2) {
            return mixPalette(astroTwilight, civilTwilight, (elev + 9.5) / 6.3);
        } else if (elev <= 2.2) {
            return mixPalette(civilTwilight, horizonSun, (elev + 3.2) / 5.4);
        } else if (elev <= 12.0) {
            return mixPalette(horizonSun, goldenHour, (elev - 2.2) / 9.8);
        } else if (elev <= 32.0) {
            return mixPalette(goldenHour, midday, (elev - 12.0) / 20.0);
        } else {
            return mixPalette(midday, highNoon, (elev - 32.0) / 36.0);
        }
    }

    // Smooth 5-stop perceptual gradient evaluation (silky, zero-muddy transitions)
    static inline float3 sampleSkyGradient(SkyPalette pal, float y) {
        y = clamp(y, 0.0, 1.0);
        if (y < 0.16) {
            return mix(pal.horizon, pal.lower, smoothstep(0.0, 0.16, y));
        } else if (y < 0.38) {
            return mix(pal.lower, pal.mid, smoothstep(0.16, 0.38, y));
        } else if (y < 0.68) {
            return mix(pal.mid, pal.upper, smoothstep(0.38, 0.68, y));
        } else {
            return mix(pal.upper, pal.zenith, smoothstep(0.68, 1.0, y));
        }
    }

    // Soft screen-like luminous addition in perceptual space (preserves clean pastel highlights without muddy clipping)
    static inline float3 screenAdd(float3 base, float3 light) {
        return 1.0 - (1.0 - clamp(base, 0.0, 1.0)) * (1.0 - clamp(light, 0.0, 1.0));
    }

    fragment float4 skyFragment(FullscreenOut in [[stage_in]],
                                constant SkyUniforms &u [[buffer(0)]]) {
        float2 uv = in.uv;
        float aspect = u.resolution.x / max(1.0, u.resolution.y);
        float minDim = min(u.resolution.x, u.resolution.y);
        float pxAA = 1.5 / max(1.0, minDim);

        // 1. Clean 5-band perceptual atmospheric sky gradient
        SkyPalette pal = paletteForElevation(u.sunElevation, u.cosmosStrength);
        float y = clamp(uv.y, 0.0, 1.0);
        float3 col = sampleSkyGradient(pal, y);

        // 2. Aspect-corrected vector to Sun (perfect circular glow on 4K landscape, Retina & 4K portrait)
        float2 normScale = (aspect >= 1.0) ? float2(aspect, 1.0) : float2(1.0, 1.0 / aspect);
        float2 deltaSun = (uv - u.sunScreenPos) * normScale;
        float distSun = length(deltaSun);

        // Directional golden/rose horizon warmth toward the Sun's azimuth during dawn/sunrise/sunset/dusk
        float horizonProx = exp(-y * 4.5);
        float twilightBand = smoothstep(-13.0, -2.0, u.sunElevation) * (1.0 - smoothstep(10.0, 26.0, u.sunElevation));
        float azDist = abs((uv.x - clamp(u.sunScreenPos.x, -0.1, 1.1)) * min(aspect, 1.7));
        float warmWash = exp(-azDist * 1.45) * horizonProx * twilightBand;
        col = screenAdd(col, pal.sunGlow * warmWash * 0.34);

        // Delicate luminous Sun orb (small, refined, optical soft-edge — never a harsh big circle!)
        float haloVis = smoothstep(-7.5, 2.0, u.sunElevation);
        float sunVis = smoothstep(-0.8, 1.2, u.sunElevation);
        if (haloVis > 0.001) {
            float wideGlow = exp(-distSun * 2.8) * (0.14 + 0.14 * twilightBand) * haloVis;
            float midGlow  = exp(-distSun * 9.5) * 0.22 * sunVis;
            float tightBloom = exp(-distSun * 28.0) * 0.58 * sunVis;
            col = screenAdd(col, pal.sunGlow * (wideGlow + midGlow));
            col = screenAdd(col, pal.sunCore * tightBloom);

            // Refined small glowing solar nucleus (~1.0% of screen height)
            float coreRadius = 0.0095;
            float coreSoft = smoothstep(coreRadius * 1.65, coreRadius * 0.25, distSun) * sunVis;
            col = mix(col, float3(1.0, 0.992, 0.95), coreSoft * 0.92);
        }

        // 3. Subtle Milky Way dust band ONLY in Deep Cosmos mode
        float nightFactor = smoothstep(-6.0, -14.0, u.sunElevation);
        if (nightFactor > 0.005 && u.cosmosStrength > 0.01) {
            float angle = 0.58 + 0.12 * sin(u.lstRadians);
            float ca = cos(angle), sa = sin(angle);
            float2 mwUV = (uv - float2(0.5, 0.56)) * normScale;
            float2 rotUV = float2(ca * mwUV.x - sa * mwUV.y, sa * mwUV.x + ca * mwUV.y);
            float band = exp(-pow(rotUV.y * 5.2, 2.0));
            float dust = fbm6(rotUV * 7.5 + float2(u.lstRadians * 0.35, 1.7));
            float fineDust = fbm6(rotUV * 18.0 + float2(4.2, -2.1));
            float darkLane = 1.0 - 0.50 * exp(-pow((rotUV.y + (dust - 0.5) * 0.10) * 18.0, 2.0));
            float mwMask = band * smoothstep(0.32, 0.78, dust * 0.65 + fineDust * 0.35) * darkLane * smoothstep(0.10, 0.45, y) * nightFactor * min(u.starIntensity, 1.2);
            col = screenAdd(col, float3(0.08, 0.13, 0.26) * mwMask * 0.42 * u.cosmosStrength);
        }

        // 4. Optional crisp 4K Moon (OFF by default for pure minimal desktop aesthetic)
        if (u.showMoon > 0.5) {
            float moonVis = smoothstep(1.0, 10.0, u.moonElevation) * smoothstep(-2.0, -10.0, u.sunElevation);
            if (moonVis > 0.005) {
                float2 deltaMoon = (uv - u.moonScreenPos) * normScale;
                float distMoon = length(deltaMoon);
                float moonRadius = 0.0125;

                float illumGain = 0.25 + 0.75 * u.moonIllumination;
                float moonHalo = (exp(-distMoon * 14.0) * 0.09 + exp(-distMoon * 38.0) * 0.14) * moonVis * illumGain;
                col = screenAdd(col, float3(0.55, 0.68, 0.92) * moonHalo);

                float moonMask = smoothstep(moonRadius + pxAA * 1.4, moonRadius - pxAA * 1.4, distMoon);
                if (moonMask > 0.001) {
                    float2 p = deltaMoon / moonRadius;
                    float z = sqrt(max(0.0, 1.0 - dot(p, p)));
                    float3 normal = normalize(float3(p.x, p.y, z));
                    float phaseAngle = (u.moonPhase - 0.5) * 2.0 * 3.14159265;
                    float3 lightDir = normalize(float3(sin(phaseAngle), 0.12, cos(phaseAngle)));
                    float ndotl = dot(normal, lightDir);
                    float lit = smoothstep(-0.06, 0.14, ndotl);

                    float mLarge = fbm6(p * 3.4 + float2(1.8, -2.3));
                    float mFine = fbm6(p * 11.5 + float2(5.1, 2.9));
                    float albedo = mix(0.72, 1.0, smoothstep(0.34, 0.68, mLarge * 0.72 + mFine * 0.28));
                    float limb = 0.84 + 0.16 * pow(z, 0.45);
                    float3 litSurface = float3(0.92, 0.94, 0.98) * albedo * limb * (0.45 + 0.55 * max(ndotl, 0.0));
                    float3 earthshine = col * 1.15;
                    col = mix(col, mix(earthshine, litSurface, lit), moonMask * moonVis);
                }
            }
        }

        // 5. Optional crisp 4K high-altitude cirrus wisps (ONLY in Cirrus style, daytime & golden hour)
        if (u.cloudStrength > 0.005) {
            float dayLit = smoothstep(-4.0, 10.0, u.sunElevation);
            if (dayLit > 0.005) {
                float drift = u.time * 0.0045;
                float2 baseUV = float2((uv.x - 0.5) * normScale.x * 2.6 + drift, uv.y * normScale.y * 5.8 + 0.4);
                float2 warp = float2(fbm6(baseUV * 0.85 + float2(2.3, 1.1)), fbm6(baseUV * 0.85 + float2(7.4, 5.2)));
                float cirrus = fbm6(baseUV + (warp - 0.5) * 1.15);
                float fineStrands = fbm6(baseUV * 2.4 + (warp - 0.5) * 0.8);
                float wisp = smoothstep(0.52, 0.84, cirrus * 0.66 + fineStrands * 0.34);
                float verticalMask = smoothstep(0.08, 0.28, y) * smoothstep(0.96, 0.52, y);
                float cloudAlpha = wisp * verticalMask * 0.22 * dayLit * u.cloudStrength;

                float3 cloudCol = mix(pal.sunGlow, float3(0.97, 0.985, 1.0), smoothstep(4.0, 18.0, u.sunElevation));
                col = mix(col, cloudCol, cloudAlpha);
            }
        }

        // Ultra-subtle corner restraint (keeps Apple-style luminosity all the way to edges)
        float2 centered = uv - 0.5;
        col *= (1.0 - dot(centered, centered) * 0.025);

        // Triangular-distribution dithering to completely eliminate gradient banding
        float dither = (hash21(in.position.xy) + hash21(in.position.xy + 19.37) - 1.0) / 255.0;
        col = clamp(col + dither, 0.0, 1.0);

        return float4(col, 1.0);
    }

    // --- Crisp 4K Pinpoint Star Pass ---
    struct StarVertexOut {
        float4 position [[position]];
        float2 localUV;
        float3 color;
        float brightness;
    };

    vertex StarVertexOut starVertex(uint vid [[vertex_id]],
                                    uint iid [[instance_id]],
                                    constant SkyUniforms &u [[buffer(0)]],
                                    const device StarInstance *stars [[buffer(1)]]) {
        const float2 corners[6] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2(-1.0,  1.0),
            float2( 1.0, -1.0),
            float2( 1.0,  1.0)
        };

        StarInstance s = stars[iid];
        float2 corner = corners[vid];

        float minDim = min(u.resolution.x, u.resolution.y);
        float pxScale = max(1.0, minDim / 1080.0);
        float twinkle = 0.88 + 0.12 * sin(u.time * (1.0 + fract(s.twinkleSeed) * 1.2) + s.twinkleSeed * 6.2831);
        float radiusPx = max(2.4, s.size * pxScale * 1.9);

        float2 ndcCenter = s.position * 2.0 - 1.0;
        float2 ndcOffset = (corner * radiusPx) / (u.resolution * 0.5);

        StarVertexOut out;
        out.position = float4(ndcCenter + ndcOffset, 0.0, 1.0);
        out.localUV = corner;
        out.color = s.color;
        out.brightness = s.brightness * twinkle;
        return out;
    }

    fragment float4 starFragment(StarVertexOut in [[stage_in]]) {
        float r = length(in.localUV);
        if (r > 1.0) { discard_fragment(); }

        // Crisp 4K pinpoint star core + whisper-soft halo
        float core = exp(-r * r * 36.0);
        float halo = exp(-r * r * 7.5) * 0.22;
        float intensity = (core + halo) * in.brightness;

        float3 col = mix(in.color, float3(1.0), core * 0.80);
        float alpha = clamp(intensity, 0.0, 1.0);
        return float4(col * alpha, alpha);
    }
    """
}
