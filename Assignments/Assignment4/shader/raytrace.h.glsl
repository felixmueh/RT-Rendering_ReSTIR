#ifndef GLSL_RAYTRACE
#define GLSL_RAYTRACE

#include "common.h.glsl"

// Ray struct
struct Ray {
    vec3 origin, dir, invDir;
	float t, baryU, baryV;
	float mint, maxt;
	uint hitId;
};

// Intersection struct holding necessary information to process a hit point
struct Intersection {
	vec3 p, n;
	vec3 albedo;
};

struct MaterialISPC {
	// BxDF index in data[15]
	// textureIdx in data[14]
	float	data[ 16 ];			// payload, depends on BxDF
};

struct LightISPC {
	float emission[3];
	uint triangleID;
	float invArea;
	uint pad[3];
};

struct TriangleISPC {
	float p0[3];
	uint material;
	float p1[3];
	uint pad0;
	float p2[3];
	uint pad1;
};

struct TriangleDataISPC {
	float uv[ 6 ];
};


struct LinearBVHNodeISPC {
	float aabb[ 2 * 2 * 3 ];
	uint firstTriangle_idxLeft;
	uint flags_axis_and_nTriangles_idxRight;
	uint idxParent, idxSibling;
		// (1<<31 isChild), 
		// (1<<30 hasLeftChild), 
		// (1<<29 hasRightChild), 
		// axis, 2x 8 for nTriangles
};

layout (std430, binding = 0) buffer blinearBVH
{ 
  LinearBVHNodeISPC linearBVH[];
};

layout (std430, binding = 1) buffer blinearTriangles
{ 
  TriangleISPC linearTriangles[];
};

layout (std430, binding = 2) buffer blinearTriangleData
{ 
  TriangleDataISPC linearTriangleData[];
};

layout (std430, binding = 3) buffer bmatList
{ 
  MaterialISPC matList[];
};

layout (std430, binding = 4) buffer blightList
{ 
  LightISPC lightList[];
};

layout (std430, binding = 5) buffer bRandomNumbers
{ 
  float prng[];
};

uniform float raster2camera[16], camera2world[16];
uniform int nMaterials, nLights;

// use this function to create rays
Ray createRay(vec3 origin, vec3 dir, float mint, float maxt) {
	Ray ray;

	ray.origin = origin;
	ray.dir = dir;
	ray.mint = mint;
	ray.maxt = maxt;

	ray.invDir = 1.0 / ray.dir;
	ray.t = ray.maxt;
	ray.baryU = ray.baryV = 0.0;
	ray.hitId = 0;

	return ray;
}

bool BBoxIntersect( float bounds[2*3], 
                          Ray ray) {
    vec3 bounds0 = { bounds[0*3+0], bounds[0*3+1], bounds[0*3+2] };
    vec3 bounds1 = { bounds[1*3+0], bounds[1*3+1], bounds[1*3+2] };
    float t0 = ray.mint, t1 = ray.maxt;

    // Check all three axis-aligned slabs.  Don't try to early out; it's
    // not worth the trouble
    vec3 tNear = (bounds0 - ray.origin) * ray.invDir;
    vec3 tFar  = (bounds1 - ray.origin) * ray.invDir;
    if (tNear.x > tFar.x) {
        float tmp = tNear.x;
        tNear.x = tFar.x;
        tFar.x = tmp;
    }
    t0 = max(tNear.x, t0);
    t1 = min(tFar.x, t1);

    if (tNear.y > tFar.y) {
        float tmp = tNear.y;
        tNear.y = tFar.y;
        tFar.y = tmp;
    }
    t0 = max(tNear.y, t0);
    t1 = min(tFar.y, t1);

    if (tNear.z > tFar.z) {
        float tmp = tNear.z;
        tNear.z = tFar.z;
        tFar.z = tmp;
    }
    t0 = max(tNear.z, t0);
    t1 = min(tFar.z, t1);
    
    return (t0 <= t1);
}

float BBoxIntersectDistanceLeft( in uint node, in Ray ray) 
{
    vec3 bounds0 = { linearBVH[node].aabb[0*3+0], linearBVH[node].aabb[0*3+1], linearBVH[node].aabb[0*3+2] };
    vec3 bounds1 = { linearBVH[node].aabb[1*3+0], linearBVH[node].aabb[1*3+1], linearBVH[node].aabb[1*3+2] };
    float t0 = ray.mint, t1 = ray.maxt;

    // Check all three axis-aligned slabs.  Don't try to early out; it's
    // not worth the trouble
    vec3 tNear = (bounds0 - ray.origin) * ray.invDir;
    vec3 tFar  = (bounds1 - ray.origin) * ray.invDir;
    if (tNear.x > tFar.x) {
        float tmp = tNear.x;
        tNear.x = tFar.x;
        tFar.x = tmp;
    }
    t0 = max(tNear.x, t0);
    t1 = min(tFar.x, t1);

    if (tNear.y > tFar.y) {
        float tmp = tNear.y;
        tNear.y = tFar.y;
        tFar.y = tmp;
    }
    t0 = max(tNear.y, t0);
    t1 = min(tFar.y, t1);

    if (tNear.z > tFar.z) {
        float tmp = tNear.z;
        tNear.z = tFar.z;
        tFar.z = tmp;
    }
    t0 = max(tNear.z, t0);
    t1 = min(tFar.z, t1);
    
	if ( t0 <= t1 ) return max( 1e-7, t0 ); else return -1.0;
}


float BBoxIntersectDistanceRight( in uint node, in Ray ray) 
{
    vec3 bounds0 = { linearBVH[node].aabb[6+0*3+0], linearBVH[node].aabb[6+0*3+1], linearBVH[node].aabb[6+0*3+2] };
    vec3 bounds1 = { linearBVH[node].aabb[6+1*3+0], linearBVH[node].aabb[6+1*3+1], linearBVH[node].aabb[6+1*3+2] };
    float t0 = ray.mint, t1 = ray.maxt;

    // Check all three axis-aligned slabs.  Don't try to early out; it's
    // not worth the trouble
    vec3 tNear = (bounds0 - ray.origin) * ray.invDir;
    vec3 tFar  = (bounds1 - ray.origin) * ray.invDir;
    if (tNear.x > tFar.x) {
        float tmp = tNear.x;
        tNear.x = tFar.x;
        tFar.x = tmp;
    }
    t0 = max(tNear.x, t0);
    t1 = min(tFar.x, t1);

    if (tNear.y > tFar.y) {
        float tmp = tNear.y;
        tNear.y = tFar.y;
        tFar.y = tmp;
    }
    t0 = max(tNear.y, t0);
    t1 = min(tFar.y, t1);

    if (tNear.z > tFar.z) {
        float tmp = tNear.z;
        tNear.z = tFar.z;
        tFar.z = tmp;
    }
    t0 = max(tNear.z, t0);
    t1 = min(tFar.z, t1);
    
	if ( t0 <= t1 ) return max( 1e-7, t0 ); else return -1.0;
}

bool BBoxIntersectLeft( in uint node, in Ray ray) {
	if ( BBoxIntersectDistanceLeft( node, ray ) < 0.0 )
		return false;
	return true;
}

bool BBoxIntersectRight( in uint node, in Ray ray) {
	if ( BBoxIntersectDistanceRight( node, ray ) < 0.0 )
		return false;
	return true;
}


float TriIntersect2( Ray ray, uint triIdx, out float bu, out float bv ) {
	vec3  tVec, pVec, qVec;
	float det, invDet, u, v, tVal;

	TriangleISPC tri = linearTriangles[ triIdx ];

    vec3 p0 = { tri.p0[0], tri.p0[1], tri.p0[2] };
    vec3 p1 = { tri.p1[0], tri.p1[1], tri.p1[2] };
    vec3 p2 = { tri.p2[0], tri.p2[1], tri.p2[2] };

    vec3 e1 = p1 - p0;
    vec3 e2 = p2 - p0;

	pVec = cross( ray.dir, e2 );
	det = dot( e1, pVec );
	if ( det > -1e-7 && det < 1e-7 ) 
		return -1.0f;
	invDet = 1.0f / det;

	tVec = ray.origin - p0;

	//if ( det > 0.0f ) 
	{
		u = dot( tVec, pVec ) * invDet;
		if (u < 0.0f || u > 1.0f)
			return -1.0f;
		qVec = cross( tVec, e1 );
		v = dot( ray.dir, qVec ) * invDet;
		if (v < 0.0f || u + v > 1.0f)
			return -1.0f;
	} //else
		//return -1.0f;
	tVal = dot( e2, qVec) * invDet;
	if (tVal >= 0.0001f) 
	{
		bu = u;
		bv = v;
		return tVal;
	}
	return -1.0f;
}


bool castLinearStackless( inout Ray ray, float maxDist ) 
{
	uint curNode = 0;
	uint bitstack = 0;

	float tval;

	bool retval = false;
	while ( true )
	{
		vec3 minV, maxV;

		// inner node?
		if ( ( linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<31) )==0 )
		{
			float distLeftBB = -1.0, distRightBB = -1.0;

			if ( (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<30))>0 )
				distLeftBB = BBoxIntersectDistanceLeft( curNode, ray );

			if ( (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<29))>0 )
				distRightBB = BBoxIntersectDistanceRight( curNode, ray );

			if ( distLeftBB > 0.0 && distRightBB > 0.0 )
			{
				bitstack = bitstack << 1;
				if ( distLeftBB < distRightBB )
					curNode = linearBVH[ curNode ].firstTriangle_idxLeft & ((1<<24)-1); else
					curNode = linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & ((1<<24)-1);
				bitstack |= 1;
			} else
			if ( distLeftBB > 0.0 ) 
			{
				bitstack = bitstack << 1;
				curNode = linearBVH[ curNode ].firstTriangle_idxLeft & ((1<<24)-1);
			} else
			if ( distRightBB > 0.0 ) 
			{
				bitstack = bitstack << 1;
				curNode = linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & ((1<<24)-1);
			} 

			if ( distLeftBB > 0.0 || distRightBB > 0.0 )
			{
				//if ( bitstack == 0 )
					//return retval;

				continue;
			}
		} else
		{
			// leaf node -> intersect triangles
			for ( int i = 0; i < (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & uint(0x00ffffff)); i++ ) 
			{
				uint tidx = linearBVH[ curNode ].firstTriangle_idxLeft+i;
				float u, v;
				//float tval = TriIntersect2( ray, linearTriangles[ tidx ], u, v );
				float tval = TriIntersect2( ray, tidx, u, v );

				if (tval > 0 && tval < maxDist ) {
					return true;
				}
			}
		} 

		// backtrack
		while ( (bitstack & 1) == 0 )
		{
			if ( bitstack == 0 )
				return retval;

			curNode = linearBVH[ curNode ].idxParent;
			bitstack = bitstack >> 1;
		}

		curNode = linearBVH[ curNode ].idxSibling;
		bitstack = bitstack ^ 1;

	}

}


bool traceLinearStackless( inout Ray ray ) 
{
	uint curNode = 0;
	uint bitstack = 0;

	float tval;
	
	bool retval = false;
	while ( true )
	{
		vec3 minV, maxV;

		// inner node?
		if ( ( linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<31) )==0 )
		{
			float distLeftBB = -1.0, distRightBB = -1.0;

			if ( (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<30))>0 )
				distLeftBB = BBoxIntersectDistanceLeft( curNode, ray );

			if ( (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & (1<<29))>0 )
				distRightBB = BBoxIntersectDistanceRight( curNode, ray );

			if ( distLeftBB > 0.0 && distRightBB > 0.0 )
			{
				bitstack = bitstack << 1;
				if ( distLeftBB < distRightBB )
					curNode = linearBVH[ curNode ].firstTriangle_idxLeft & ((1<<24)-1); else
					curNode = linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & ((1<<24)-1);
				bitstack |= 1;
			} else
			if ( distLeftBB > 0.0 ) 
			{
				bitstack = bitstack << 1;
				curNode = linearBVH[ curNode ].firstTriangle_idxLeft & ((1<<24)-1);
			} else
			if ( distRightBB > 0.0 ) 
			{
				bitstack = bitstack << 1;
				curNode = linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & ((1<<24)-1);
			} 

			if ( distLeftBB > 0.0 || distRightBB > 0.0 )
			{
				//if ( bitstack == 0 )
					//return retval;

				continue;
			}
		} else
		{
			// leaf node -> intersect triangles
			for ( uint i = 0; i < (linearBVH[ curNode ].flags_axis_and_nTriangles_idxRight & uint(0x00ffffff)); i++ ) {

				uint tidx = linearBVH[ curNode ].firstTriangle_idxLeft+i;
				float u, v;
				tval = TriIntersect2( ray, tidx, u, v );
				if (tval > 0 && tval < ray.t) {
					ray.t = tval;
					ray.maxt = tval;
					ray.baryU = u;
					ray.baryV = v;
					ray.hitId = linearBVH[ curNode ].firstTriangle_idxLeft+i;

					retval = true;
				}
			}
		} 

		// backtrack
		while ( (bitstack & 1) == 0 )
		{
			if ( bitstack == 0 )
				return retval;

			curNode = linearBVH[ curNode ].idxParent;
			bitstack = bitstack >> 1;
		}

		curNode = linearBVH[ curNode ].idxSibling;
		bitstack = bitstack ^ 1;

	}

}

// Use this function to get closest intersection
bool traceRay( inout Ray ray ) 
{
	return traceLinearStackless( ray );
}

// Use this function to perform visibility test
bool castRay( inout Ray ray ) 
{
	return castLinearStackless( ray, ray.maxt );
}

vec3 decodeNormal( uint code ) 
{
	const int bits = 10;
	float scale = float( 1 << bits );
	vec3 r;
	r.x = float( code & ( (1<<bits)-1 ) ) / (scale*0.5f) - 1.0f;
	r.y = float( code >> bits ) / (scale*0.5f) - 1.0f;
	r.z = 1.0f - abs( r.x ) - abs( r.y );
	if ( r.z < 0.0f )
	{
		float sign_x = r.x >= 0.0f ? 1.0f : -1.0f;
		float sign_y = r.y >= 0.0f ? 1.0f : -1.0f;
		float x1 = r.x, y1 = r.y;
		r.x = ( 1.0f - abs( y1 ) ) * sign_x;
		r.y = ( 1.0f - abs( x1 ) ) * sign_y;
	}

	r = normalize( r );
	return r;
}

// Use this function to extract intersection from ray
// ray must have been passt to traceRay with a succefull return
Intersection getIntersection(Ray ray) {
	TriangleISPC tri = linearTriangles[ray.hitId];
	TriangleDataISPC data = linearTriangleData[ray.hitId];
	MaterialISPC mat = matList[bitfieldExtract(tri.material, 0, 16)];

	float u = ray.baryU, v = ray.baryV, w = 1 - u - v;

	vec3 p0 = unpack(tri.p0);
	vec3 p1 = unpack(tri.p1);
	vec3 p2 = unpack(tri.p2);

	vec3 n0 = decodeNormal(bitfieldExtract(tri.pad0, 0, 20));
	vec3 n1 = decodeNormal(bitfieldExtract(tri.pad1, 0, 10) << 10 | bitfieldExtract(tri.pad0, 20, 10));
	vec3 n2 = decodeNormal(bitfieldExtract(tri.pad1, 10, 20));

	vec2 uv0 = vec2(data.uv[0], data.uv[1]);
	vec2 uv1 = vec2(data.uv[2], data.uv[3]);
	vec2 uv2 = vec2(data.uv[4], data.uv[5]);

	vec2 uv = u * uv0 + v * uv1 + w * uv2;

	Intersection isect;

	isect.p = w * p0 + u * p1 + v * p2;
	isect.n = normalize(u * n0 + v * n1 + w * n2);
	isect.albedo = vec3(mat.data[1], mat.data[2], mat.data[3]);

	return isect;
}

#endif
