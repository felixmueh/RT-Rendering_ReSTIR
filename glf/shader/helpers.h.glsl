
vec2 direction2latlong( vec3 dir )
{
	vec2 uv;
	uv.x = ( atan( dir.z, -dir.x ) ) / 6.2831853071796;
	uv.y = acos( dir.y ) / 3.1415926535898;
	return uv;
}

float saturate( float x ) {
	return clamp( x, 0.0, 1.0 );
}

vec4 texture2DFadeCurve( sampler2D s, vec2 uv )
{
	ivec2 textureResolution = textureSize( s, 0 );

	uv = uv * textureResolution + vec2( 0.5 );
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );
	fuv = fuv*fuv*(3.0-2.0*fuv); 
	//fuv = fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);;
	uv = iuv + fuv;
	uv = (uv - 0.5) / textureResolution;

	return texture2D( s, uv );
}

// from http://www.java-gaming.org/index.php?topic=35123.0
// cubic B-Spline
vec4 cubic(float v){
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

// Catmull-Rom spline actually passes through control points
vec4 cubicCR(float x) // cubic_catmullrom(float x)
{
    const float s = 0.5; // potentially adjustable parameter
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =    -s*x3 +     2*s*x2 - s*x + 0;
    w.y = (2-s)*x3 +   (s-3)*x2       + 1;
    w.z = (s-2)*x3 + (3-2*s)*x2 + s*x + 0;
    w.w =     s*x3 -       s*x2       + 0;
    return w;
}
vec4 textureBicubic(sampler2D sampler, vec2 texCoords)
{
   vec2 texSize = textureSize(sampler, 0);
   vec2 invTexSize = 1.0 / texSize;

   texCoords = texCoords * texSize - 0.5;


    vec2 fxy = fract(texCoords);
    texCoords -= fxy;

    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

    offset *= invTexSize.xxyy;

    vec4 sample0 = texture(sampler, offset.xz);
    vec4 sample1 = texture(sampler, offset.yz);
    vec4 sample2 = texture(sampler, offset.xw);
    vec4 sample3 = texture(sampler, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(
       mix(sample3, sample2, sx), mix(sample1, sample0, sx)
    , sy);
}
