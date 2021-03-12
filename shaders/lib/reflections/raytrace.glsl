vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*1.95;
}

vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, float alternative) {
	vec3 pos = vec3(0.0);
	float dist = 0.0;

	#if AA > 1
		dither = fract(dither + frameTimeCounter);
	#endif

	vec3 start = viewPos;

    vec3 vector = 0.5 * reflect(normalize(viewPos), normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

    int sr = 0;

    for(int i = 0; i < 30; i++) {
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) break;

		vec3 rfragpos = vec3(pos.xy, texture2D(depthtex,pos.xy).r);
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = length(start - rfragpos);

        float err = length(viewPos - rfragpos);
		if(err < pow(length(vector), 1.1 + alternative)) {
                sr++;
                if(sr >= 6) break;
				tvector -= vector;
                vector *= 0.1;
		}
        vector *= 2.0;
        tvector += vector * (dither * 0.05 + 1.0);
		viewPos = start + tvector;
    }

	return vec4(pos, dist);
}
vec4 Pathtrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, vec3 noise) {

	vec3 pos = vec3(0.0);
	//pos.z = GetLinearDepth(pos.z);
	float dist = 0.0;
	//float pi = 3.14;
	#if AA > 1
		dither = 0.1 * fract(dither + frameTimeCounter);
	#endif
//	vec3 noise = vec3(sin(normal.x * 1000), sin(normal.y * 1000), sin(normal.z * 1000));
	noise *= 2;
	noise -= 1;
	vec3 start = viewPos;

    vec3 vector = 0.1 * normalize(normalize(normal) + normalize(noise));
	viewPos += vector;
	vec3 tvector = vector;
	int sr = 0;
    for(int i = 0; i < 40; i++) {
		pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0) break;

		vec3 rfragpos = vec3(pos.xy, texture2D(depthtex,pos.xy).r);
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = length(start - rfragpos);

		float err = length(viewPos - rfragpos);
		if(err < pow(length(vector), 1.1)) {
                sr++;
                if(sr >= 6) break;
				tvector -= vector;
                vector *= 0.1;
		}
        vector *= 2.0;
        tvector += vector * (dither * 0.05 + 1.0);
		viewPos = start + tvector;
    }

	return vec4(pos, dist);
}
