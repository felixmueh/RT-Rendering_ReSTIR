#include "framecapture.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

FrameCapture::FrameCapture(shared_ptr<FramebufferObject> _fbo, uint _width, uint _height, string _location, unordered_set<Format> _formats) 
    : fbo(_fbo), width(_width), height(_height), location(_location), formats(_formats)
{
    // ensure the destination location for captured frames exists!
    filesystem::path path_to_location(location);
    if (!filesystem::exists(path_to_location)) {
        if (filesystem::create_directories(path_to_location)) {
            cout << "[FC]:  Directory created: '" + location + "'" << endl;
        } else {
            cerr << "[FC]:  Failed to create directory: '" + location + "'" << endl;
        }
    }
}

void FrameCapture::saveImage(string name)
{
    string file = (filesystem::path(location) / (name)).string();
    if (formats.empty() || formats.count(Format::PNG) > 0) {
        savePNG(file);
    }
    if (formats.empty() || formats.count(Format::PFM) > 0) {
        savePFM(file);
    }
}

void FrameCapture::savePNG(string path)
{
    string file = path + ".png";

    unsigned char *pixels = new unsigned char[width * height * 3];
    glBindFramebuffer(GL_FRAMEBUFFER, fbo->getID());
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // Flip image vertically (OpenGL's origin is bottom-left)
    unsigned char *flippedPixels = new unsigned char[width * height * 3];
    for (int y = 0; y < height; y++) {
        memcpy(flippedPixels + (height - 1 - y) * width * 3, pixels + y * width * 3, width * 3);
    }

    stbi_write_png(file.c_str(), width, height, 3, flippedPixels, width * 3);
    delete[] pixels;
    delete[] flippedPixels;

    cout << "[FC]:  Captured frame to: '" + file + "'" << endl;
}

void FrameCapture::savePFM(string name)
{
    string filename = name + ".pfm";
    std::ofstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "[FC]:  Error: Could not open " << filename << " for writing." << endl;
        return;
    }

    // Write header: PFM format, width, height, and scale (negative for little-endian)
    file << "PF\n" << width << " " << height << "\n-1.0\n";

    std::vector<float> imageData(width * height * 3); // RGB data from OpenGL
    glBindFramebuffer(GL_FRAMEBUFFER, fbo->getID());
    glReadPixels(0, 0, width, height, GL_RGB, GL_FLOAT, imageData.data());
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    for (int y = 0; y < height; y++) {
        file.write(reinterpret_cast<const char*>(&imageData[y * width * 3]), width * 3 * sizeof(float));
    }

    file.close();
    cout << "[FC]:  Captured frame to: '" + filename + "'" << endl;
}
