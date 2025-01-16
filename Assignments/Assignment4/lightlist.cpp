#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"
#include "lightlist.h"

CpuEmissiveTriangle::CpuEmissiveTriangle(vec3 _p1, vec3 _p2, vec3 _p3, vec3 _emission)
	: p1(_p1), p2(_p2), p3(_p3), emission(_emission) { }

GpuEmissiveTriangle CpuEmissiveTriangle::compress()
{
	return { p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, emission.x, emission.y, emission.z };
}

float CpuEmissiveTriangle::computeArea() const
{
	return 0.5 * length(cross(p2-p1, p3-p1));
}

LightList::LightList() : totalArea(0.0f), csCdf(0), csTriangles(0) { }

void LightList::initialize(const vector<CpuEmissiveTriangle>& _triangles)
{
    triangles.clear();
    triangles = _triangles;

    totalArea = 0.0f;
    cdf.clear();
    cdf.reserve(triangles.size());

    // Compute total area
    for (const auto& tri : triangles) {
        totalArea += tri.computeArea();
    }

    // Compute CDF
    float cumulativeSum = 0.0f;
    for (const auto& tri : triangles) {
        cumulativeSum += tri.computeArea();
        cdf.push_back(cumulativeSum / totalArea); // Normalize by total area
    }
    std::cout << cdf.back();
    assert(cdf.back() >= (1.0 - 1e-10));
}

void LightList::uploadLightList2GPU()
{
    // prepare EmissiveTriangles for upload to gpu by compressing them
    vector<GpuEmissiveTriangle> gpuTriangles;
    gpuTriangles.reserve(triangles.size());
    for (auto& tri : triangles) {
        gpuTriangles.push_back(tri.compress());
    }

    // upload emissive triangles
    csTriangles = createShaderStorageBuffer(sizeof(GpuEmissiveTriangle) * gpuTriangles.size());
    copyMem2StorageBuffer(csTriangles, gpuTriangles.data(), sizeof(GpuEmissiveTriangle) * gpuTriangles.size());

    // upload cdf for sampling
    csCdf = createShaderStorageBuffer(sizeof(float) * cdf.size());
    copyMem2StorageBuffer(csCdf, cdf.data(),
        sizeof(float) * cdf.size());
}

void LightList::setLightListShaderUniforms(GLSLProgram* prg)
{
    prg->bind();
    prg->Uniform1f("totalArea", totalArea);
    prg->Uniform1i("nEmissiveTriangles", (int)triangles.size());

    GLint block_index;
    GLuint binding_point_index;

    block_index = glGetProgramResourceIndex(prg->getProgramObject(), GL_SHADER_STORAGE_BLOCK, "bEmissiveTriangles");
    binding_point_index = 6;
    glShaderStorageBlockBinding(prg->getProgramObject(), block_index, binding_point_index);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding_point_index, csTriangles);

    block_index = glGetProgramResourceIndex(prg->getProgramObject(), GL_SHADER_STORAGE_BLOCK, "bEmissiveCDF");
    binding_point_index = 7;
    glShaderStorageBlockBinding(prg->getProgramObject(), block_index, binding_point_index);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding_point_index, csCdf);
}

GLuint LightList::createShaderStorageBuffer(int size, GLenum usage)
{
    GLuint name;
    glGenBuffers(1, &name);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, name);
    glBufferData(GL_SHADER_STORAGE_BUFFER, size, NULL, usage);
    //glBufferStorage( GL_SHADER_STORAGE_BUFFER, size, NULL, GL_MAP_WRITE_BIT);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
    return name;
}

void LightList::copyMem2StorageBuffer(GLuint name, void* data, int size)
{
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, name);
    glBufferData(GL_SHADER_STORAGE_BUFFER, size, data, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}
