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

LightList::LightList() : totalArea(0.0f), csCdf(0), csTriangles(0), csAliasProb(0), csAliasIndex(0) { }

void LightList::initialize(const vector<CpuEmissiveTriangle>& _triangles)
{
    triangles.clear();
    triangles = _triangles;

    // Compute total area
    totalArea = 0.0f;
    for (const auto& tri : triangles) {
        totalArea += tri.computeArea();
    }

    // Prepare local arrays for building alias table
    size_t N = triangles.size();
    std::vector<float> p(N);
    for (size_t i = 0; i < N; i++) {
        p[i] = triangles[i].computeArea() / totalArea;
    }

    aliasProb.clear();
    aliasIndex.clear();

    aliasProb.resize(N);
    aliasIndex.resize(N);

    // Temporary stacks
    std::vector<size_t> small, large;
    small.reserve(N);
    large.reserve(N);

    // Scale probabilities by N
    for (size_t i = 0; i < N; i++) {
        aliasProb[i] = p[i] * float(N);
        if (aliasProb[i] < 1.f)
            small.push_back(i);
        else
            large.push_back(i);
    }

    // Walker's method
    while (!small.empty() && !large.empty()) {
        auto s = small.back();
        small.pop_back();
        auto l = large.back();
        large.pop_back();
        aliasIndex[s] = uint32_t(l);
        aliasProb[l] = (aliasProb[l] + aliasProb[s]) - 1.f;
        if (aliasProb[l] < 1.f)
            small.push_back(l);
        else
            large.push_back(l);
    }

    // Anything remaining is either all small or all large
    while (!large.empty()) {
        auto l = large.back();
        large.pop_back();
        aliasProb[l] = 1.f;
        aliasIndex[l] = uint32_t(l);
    }

    while (!small.empty()) {
        auto s = small.back();
        small.pop_back();
        aliasProb[s] = 1.f;
        aliasIndex[s] = uint32_t(s);
    }
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

    //Upload alias table
    csAliasProb = createShaderStorageBuffer(sizeof(float) * aliasProb.size());
    copyMem2StorageBuffer(csAliasProb,
        aliasProb.data(),
        sizeof(float) * aliasProb.size()
    );

    // 3) Upload aliasIndex
    csAliasIndex = createShaderStorageBuffer(sizeof(uint32_t) * aliasIndex.size());
    copyMem2StorageBuffer(csAliasIndex,
        aliasIndex.data(),
        sizeof(uint32_t) * aliasIndex.size()
    );
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

    block_index = glGetProgramResourceIndex(prg->getProgramObject(), GL_SHADER_STORAGE_BLOCK, "bAliasProb");
    binding_point_index = ALIAS_PROB_BINDING;
    glShaderStorageBlockBinding(prg->getProgramObject(), block_index, binding_point_index);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding_point_index, csAliasProb);

    block_index = glGetProgramResourceIndex(prg->getProgramObject(), GL_SHADER_STORAGE_BLOCK, "bAliasIndex");
    binding_point_index = ALIAS_IDX_BINDING;
    glShaderStorageBlockBinding(prg->getProgramObject(), block_index, binding_point_index);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding_point_index, csAliasIndex);
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
