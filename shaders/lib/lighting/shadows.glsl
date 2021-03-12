uniform sampler2DShadow shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

vec2 shadowoffsets[8] = vec2[8](    vec2( 0.0   , 1.0   ),
                                    vec2( 0.7071, 0.7071),
                                    vec2( 1.0   , 0.0   ),
                                    vec2( 0.7071,-0.7071),
                                    vec2( 0.0   ,-1.0   ),
                                    vec2(-0.7071,-0.7071),
                                    vec2(-1.0   , 0.0   ),
                                    vec2(-0.7071, 0.7071));

vec2 offsetDist(float x, float s){
	float n = fract(x * 1.414) * 3.1415;
    return vec2(cos(n), sin(n)) * 1.4 * x / s;
}

vec3 SampleBasicShadow(vec3 shadowPos){
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    #ifdef SHADOW_COLOR
        vec3 shadowcol = vec3(0.0);
        if (shadow0 < 1.0) {
            float shadow1 = shadow2D(shadowtex1, vec3(shadowPos.st, shadowPos.z)).x;
            if (shadow1 > 0.0)
                shadowcol = texture2D(shadowcolor0, shadowPos.st).rgb * shadow1;
        }

        return shadowcol * (1.0 - shadow0) + shadow0;
    #else
        return vec3(shadow0);
    #endif

    
}

vec3 SampleFilteredShadow(vec3 shadowPos, float offset){
    vec3 shadow = SampleBasicShadow(vec3(shadowPos.st, shadowPos.z)) * 2.0;

    for(int i = 0; i < 8; i++){
        shadow+= SampleBasicShadow(vec3(offset * 1.2 * shadowoffsets[i] + shadowPos.st, shadowPos.z));
    }

    return shadow * 0.1;
}

vec3 SampleTAAFilteredShadow(vec3 shadowPos, float offset){
    float noise = InterleavedGradientNoise();
    vec3 shadow = vec3(0.0);
    offset = offset * (2.0 - 0.5 * (0.85 + 0.25 * (3072.0 / shadowMapResolution)));
    if (shadowMapResolution < 400.0) offset *= 30.0;

    for(int i = 0; i < 2; i++){
        vec2 offset = offsetDist(noise + i, 2.0) * offset;
        shadow += SampleBasicShadow(vec3(shadowPos.st + offset, shadowPos.z));
        shadow += SampleBasicShadow(vec3(shadowPos.st - offset, shadowPos.z));
    }
    
    return shadow * 0.25;
}

vec3 GetShadow(vec3 shadowPos, float bias, float offset){
    shadowPos.z -= bias;

    #ifdef SHADOW_FILTER
        #if AA > 1
            vec3 shadow = SampleTAAFilteredShadow(shadowPos, offset);
        #else
            vec3 shadow = SampleFilteredShadow(shadowPos, offset);
        #endif
    #else
       vec3 shadow = SampleBasicShadow(shadowPos);
    #endif

    return shadow;
}