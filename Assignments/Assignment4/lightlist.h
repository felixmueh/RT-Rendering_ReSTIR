#ifndef LIGHTLIST_H
#define LIGHTLIST_H

#include "shader/shared.h.glsl"
#include "stdafx.h"

#include <vector>


using namespace std;
using namespace glm;

class CpuEmissiveTriangle {
public:
	CpuEmissiveTriangle(vec3 _p1, vec3 _p2, vec3 _p3, vec3 _emission);
	GpuEmissiveTriangle compress();
	float computeArea() const;

private:
	vec3 p1, p2, p3;
	vec3 emission;
};

class LightList {

public:
	LightList();
	void initialize(const vector<CpuEmissiveTriangle>& _triangles);
	void uploadLightList2GPU();
	void setLightListShaderUniforms(GLSLProgram* prg);

private:
	GLuint createShaderStorageBuffer(int size, GLenum usage = GL_STATIC_DRAW);
	void copyMem2StorageBuffer(GLuint name, void* data, int size);
	
private:
	vector<CpuEmissiveTriangle> triangles;	// list of emissive triangles
	vector<float> aliasProb;				// alias probabilities for discrete sampling
	vector<float> aliasIndex;				// alias indices for discrete sampling
	float totalArea;						// total area of the triangles
	GLuint csTriangles;						// gpu memory of traingles
	GLuint csCdf;							// gpu memory of cumulative areas
	GLuint csAliasProb;						// gpu memory of alias probabilities
	GLuint csAliasIndex;					// gpu memory of alias indices

};

#endif // LIGHTLIST_H
