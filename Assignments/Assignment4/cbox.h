#ifndef CBOX_H_
#define CBOX_H_

#include <array>
#include <vector>
#include "stdafx.h"
#include "lightlist.h"

void addCircularLight(
    std::vector<CpuEmissiveTriangle>& emissiveTris,
    const glm::vec3& center,
    const glm::vec3& normal,
    float size,
    const glm::vec3& color = glm::vec3(1.0f),
    int resolution = 8
) {
    float radius = size * 0.5f;
    float angle = 2.0f * glm::pi<float>() / resolution;

    // any vector orthogonal to normal will do
    glm::vec3 tangent1 = glm::cross(normal, glm::vec3(1.0f, 0.0f, 0.0f));
    if (glm::length2(tangent1) < 1e-6f) {
        tangent1 = glm::cross(normal, glm::vec3(0.0f, 1.0f, 0.0f));
    }
    tangent1 = normalize(tangent1);

    glm::vec3 tangent2 = normalize(glm::cross(normal, tangent1));

    for (int i = 0; i < resolution; i++) {
        glm::vec3 p1 = center + radius * (tangent1 * cos(i * angle) + tangent2 * sin(i * angle));
        glm::vec3 p2 = center + radius * (tangent1 * cos((i + 1) * angle) + tangent2 * sin((i + 1) * angle));
        emissiveTris.push_back(CpuEmissiveTriangle(center, p1, p2, color));
    }
}

std::vector<glm::vec3> rectanglePattern(
    const glm::vec3& corner,
    const glm::vec3& u,
    const glm::vec3& v,
    int gridX,
    int gridY
) {
    // u and v define the plane of the rectangle
    std::vector<glm::vec3> points;
    for (int x = 0; x < gridX; x++) {
        for (int y = 0; y < gridY; y++) {
            float xPos = x / (gridX - 1.0f);
            float yPos = y / (gridY - 1.0f);
            points.push_back(corner + xPos * u + yPos * v);
        }
    }
    return points;
}

std::vector<CpuEmissiveTriangle> generateEmissiveTrianglesForCBoxTest(
) {
      vector<CpuEmissiveTriangle> emissiveTris;

      vector<glm::vec3> points = rectanglePattern(
        glm::vec3(-0.4, -0.4, 0.4),
        glm::vec3(0.8, 0, 0),
        glm::vec3(0, 0.8, 0),
        3, 3
      );

      for (auto p : points) {
        addCircularLight(emissiveTris, p, glm::vec3(0, 0, 1), 0.05, glm::vec3(8.0));
      }

      points = rectanglePattern(
        glm::vec3(-0.4, -0.4, -0.4),
        glm::vec3(0, 0, 0.8),
        glm::vec3(0, 0.8, 0),
        2, 2
      );

      for (auto p : points) {
        addCircularLight(emissiveTris, p, glm::vec3(1, 0, 0), 0.05, glm::vec3(8.0));
      }

      return emissiveTris;
}

#endif // CBOX_H_
