#ifndef CBOX_H_
#define CBOX_H_

#include <array>
#include <vector>
#include "stdafx.h"
#include "lightlist.h"

void addSquareLight(
    std::vector<CpuEmissiveTriangle>& emissiveTris,
    const glm::vec3& center,
    float size,
    const glm::vec3& color = glm::vec3(1.0f)
)
{
    // Half the side length
    float half = size * 0.5f;

    // Compute corners of the square in (x, y) at the given z
    glm::vec3 s1(center.x - half, center.y - half, center.z);
    glm::vec3 s2(center.x + half, center.y - half, center.z);
    glm::vec3 s3(center.x + half, center.y + half, center.z);
    glm::vec3 s4(center.x - half, center.y + half, center.z);

    // Add two triangles that form the square
    emissiveTris.push_back(CpuEmissiveTriangle(s1, s2, s3, color));
    emissiveTris.push_back(CpuEmissiveTriangle(s1, s3, s4, color));
}

std::vector<CpuEmissiveTriangle> generateEmissiveTrianglesForCBoxTest(
    int gridX = 2,
    int gridZ = 2,
    float padding = 0.1,
    float zPos = 0.40,
    float size = 0.1f
) {
    std::vector<CpuEmissiveTriangle> emissiveTris;
    float min_x = -0.5 + padding;
    float max_x = 0.5 - padding;
    float min_y = -0.5 + padding;
    float max_y = 0.5 - padding;

    for (int x = 0; x < gridX; x++) {
        for (int z = 0; z < gridZ; z++) {
            float xPos = min_x + (max_x - min_x) * x / (gridX - 1);
            float yPos = min_y + (max_y - min_y) * z / (gridZ - 1);
            addSquareLight(emissiveTris, glm::vec3(xPos, yPos, zPos), size, glm::vec3(1.0f / 0.04));
        }
    }

    return emissiveTris;
}

#endif // CBOX_H_
