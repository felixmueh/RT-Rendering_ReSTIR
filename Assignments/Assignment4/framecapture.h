#ifndef FRAMECAPTURE_H
#define FRAMECAPTURE_H

#include "stdafx.h"

#include <memory>
#include <vector>
#include <unordered_set>
#include <filesystem>

using namespace std;

class FrameCapture {
	enum Format {
		PNG, PFM
	};
	
private:
	shared_ptr<FramebufferObject> fbo;
	string location;
	uint width, height;
	unordered_set<Format> formats;

public:
	explicit FrameCapture(shared_ptr<FramebufferObject> _fbo, uint _width, uint _height, string _location = "captures", unordered_set<Format> _formats = {});
	void saveImage(string name = "screenshot");

private:
	void savePNG(string name);
	void savePFM(string name);
};
#endif // !FRAMECAPTURE_H
