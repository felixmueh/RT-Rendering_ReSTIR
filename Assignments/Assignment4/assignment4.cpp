#include "AntTweakBar.h"
#if 1

////////////////////////////////////////////////////////////
//                                                        //
//  Visual Computing & FERT Framework                     //
//                                                        //
//  This code is based on GLEW and the www.gpgpu.org      //
//  frame-buffer-object framework.                        //
//                                                        //
////////////////////////////////////////////////////////////

#include <iterator>

#include "stdafx.h"

#include "opengl_debug.h"
#include "shader/shared.h.glsl"
#include "lightlist.h"
#include "cbox.h"

#define N_ITERATIONS_SPATIAL 2

extern "C" {
#ifdef _WIN32
__declspec(dllexport) unsigned int NvOptimusEnablement = 1;
__declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
#else
__attribute__((visibility("default"))) unsigned int NvOptimusEnablement = 1;
__attribute__((
    visibility("default"))) int AmdPowerXpressRequestHighPerformance = 1;
#endif
}

char applicationTitle[128] = "Assignment4";

const char path2Demo[] = "Assignments/Assignment4/";

using namespace glm;

#ifdef USE_TWEAK_BAR
TwBar *bar = NULL; // Pointer to a tweak bar

typedef enum {
  RENDER_MODE_SHADED = 0,
  RENDER_MODE_NORMAL = 1,
  RENDER_MODE_POSITION = 2,
} RENDER_MODE;

typedef enum {
  SAMPLE_MODE_UNIFORM = 0,
  SAMPLE_MODE_RIS = 1,
  SAMPLE_MODE_STREAMING_RIS = 2,
  SAMPLE_MODE_RESTIR = 3,
} SAMPLE_MODE;

struct RenderSettings {
  RENDER_MODE renderMode = RENDER_MODE_SHADED;
  SAMPLE_MODE sampleMode = SAMPLE_MODE_RESTIR;
  bool enableAccumulation = false;
  bool resetAccumulationBuffer = false;
  float accumulationEWA = 1.0f;
  int n_samples = 2;
};

RenderSettings renderSettings;

static void CheckGLError(int idx = 0) {
  int err = 0;
  char msg[256];
  while ((err = glGetError()) != 0) {
    if (idx) {
      sprintf(msg, "GL_ERROR[%d]=0x%x\n", idx, err);
    } else {
      sprintf(msg, "GL_ERROR=0x%x\n", err);
    }
#ifdef ANT_WINDOWS
    OutputDebugString(msg);
#endif
    fprintf(stderr, msg);
  }
}

std::string
makeDefineString(const std::map<std::string, std::string> &parameters) {
  std::vector<std::string> defines;
  for (auto it = parameters.begin(); it != parameters.end(); ++it) {
    std::string currentDefine = "#define " + it->first + " " + it->second;
    defines.push_back(currentDefine);
  }
  std::stringstream result;
  std::copy(defines.begin(), defines.end(),
            std::ostream_iterator<std::string>(result, "\n"));
  return result.str();
}

void initializeTweakBar() {
  if (bar != NULL)
    TwDeleteBar(bar);
  else
    TwTerminate();
  nTweakBarVariables = 0;

  // Create a tweak bar
  TwDefine("GLOBAL fontscaling=1");
  TwInit(TW_OPENGL, NULL);
  TwDefine("GLOBAL fontsize=3");

  bar = TwNewBar("Tiny Renderer");

  TwDefine("'Tiny Renderer' position='8 30'");
  TwDefine("'Tiny Renderer' size='300 400'");
  TwDefine("'Tiny Renderer' text=light");

  // RENDERER TWBAR
  TwEnumVal twRenderModes[] = {{RENDER_MODE_SHADED, "Shaded"},
                               {RENDER_MODE_NORMAL, "GBuffer - Normal"},
                               {RENDER_MODE_POSITION, "GBuffer - Position"}};

  TwEnumVal twSampleModes[] = {{SAMPLE_MODE_UNIFORM, "Uniform"},
                               {SAMPLE_MODE_RIS, "RIS"},
                               {SAMPLE_MODE_STREAMING_RIS, "Streaming RIS"},
                               {SAMPLE_MODE_RESTIR, "ReSTIR"}};

  TwType twRenderModeTwType = TwDefineEnum("RenderMode", twRenderModes, 3);

  TwType twSampleModeTwType = TwDefineEnum("SampleMode", twSampleModes, sizeof(twSampleModes) / sizeof(twSampleModes[0]));

  TwAddVarRW(bar, "Rendermode", twRenderModeTwType, &renderSettings.renderMode,
             "group='Renderer'");
  TwAddVarRW(bar, "Accumulation", TW_TYPE_BOOLCPP,
             &renderSettings.enableAccumulation,
             " label='Accumulation' group='Renderer' ");

  TwAddVarRW(bar, "SampleMode", twSampleModeTwType, &renderSettings.sampleMode,
              "group='RIS'");
  TwAddVarRW(
      bar, "AccumulationEWA", TW_TYPE_FLOAT, &renderSettings.accumulationEWA,
      " label='Accumulation EWA' min=0.01 max=1.0 step=0.01 group='Renderer' ");
  TwAddButton(
      bar, "ClearAcc",
      [](void *data) { renderSettings.resetAccumulationBuffer = true; }, NULL,
      " label='Clear Accumulation Buffer' group='Renderer' ");

  TwAddVarRW(bar, "Samples", TW_TYPE_INT32, &renderSettings.n_samples,
             " label='Samples' min=1 max=100 step=1 group='RIS' ");


}
#endif

IMWrap *createWrapper(GLSLProgram &prg) {
  IMWrap *wrapper = new IMWrap();
  wrapper->bindShader(prg.getProgramObject(), 2, "in_position", "in_texcoord");
  wrapper->Begin(GL_TRIANGLES);
  wrapper->Attrib2f(1, 0, 0);
  wrapper->Vertex3f(-1, -1, -0.5f);
  wrapper->Attrib2f(1, 1, 0);
  wrapper->Vertex3f(1, -1, -0.5f);
  wrapper->Attrib2f(1, 1, 1);
  wrapper->Vertex3f(1, 1, -0.5f);

  wrapper->Attrib2f(1, 0, 0);
  wrapper->Vertex3f(-1, -1, -0.5f);
  wrapper->Attrib2f(1, 1, 1);
  wrapper->Vertex3f(1, 1, -0.5f);
  wrapper->Attrib2f(1, 0, 1);
  wrapper->Vertex3f(-1, 1, -0.5f);
  wrapper->End();

  CheckGLError();
  return wrapper;
}

class CRender : public CRenderBase {
protected:
  Scene *scene;  // scene for loading .obj and computing a BVH
  Camera camera; // camera (acts as trackball by default)
  EnvMap *envmap;
  GLSLProgram prgRender; // GLSL programs, each one can keep a vertex and a
                         // fragment shader
  IMWrap *wrap;          // wrapper for OpenGL immediate calls
  IMWrap *wrapReSTIRFinal;

  GLSLProgram prgPostProc; // GLSL programs, each one can keep a vertex and a
                           // fragment shader
  GLSLProgram prgDepth;    // GLSL programs, each one can keep a vertex and a
                           // fragment shader

  GLSLProgram prgReSTIRTemporal;
  GLSLProgram prgReSTIRSpatial;
  GLSLProgram prgReSTIRFinal;

  OGLTexture *tGPosition, *tGNormal, *tGColor;

  FramebufferObject pDeferredFBO;
  Renderbuffer pDeferredRenderBuffer;

	LightList lights;
  int reservoirStructSize;
  GLuint reservoirBufferA;
  GLuint reservoirBufferB;

  GLuint gBuffer;

public:
  CRender() {
    initializeOpenGLDebugCallback();
    glfwGetWindowSize(glfwWindow, &width, &height);

    enableGLDebugOutput = false;
    offScreenRenderTarget =
        true; // required for multi sampling, stereo, accumulation
    useMultisampling = false;
    stereoRendering = false;
    useAccumulationBuffer = true; // call clearAccumulationBuffer(); in
                                  // sceneFrameRender() to clear the buffer
    accumulationEWA =
        renderSettings
            .accumulationEWA; // if this value is set (to != 1.0f which is
                              // default) then accumulation buffer images will
                              // be accumulated using exponentially weighted
                              // averaging

    // called here as the initialization depends on some flags we can set in
    // CRender
    CRenderBase::CRenderBaseInit();

    // load and/or create shaders, textures, and models
    loadShaders(true);
    createTextures();
    loadModels();

    GLuint program = prgRender.getProgramObject();
    reservoirStructSize = getGPUStructSize(program, "bReservoirIn");

    // NOTE: wrong size when resizing
    // TODO: resize buffer when resizing window
    //reservoirStructSize *= 2;

    // Create two buffers by calling the function twice
    createBuffer(reservoirBufferA, reservoirStructSize, width, height);
    createBuffer(reservoirBufferB, reservoirStructSize, width, height);

    int intGbufferStructSize = getGPUStructSize(program, "bGBuffer");

    createBuffer(gBuffer, intGbufferStructSize, width, height);

    // call it here so that these textures show up at the end in the texture
    // manager
    CRenderBase::createTextures();
  }

  ~CRender() {
    if (scene)
      delete scene;

    if (envmap)
      delete envmap;

    if(wrap)
      delete wrap;

    if(wrapReSTIRFinal)
      delete wrapReSTIRFinal;

    deleteBuffer(reservoirBufferA);
    deleteBuffer(reservoirBufferB);
    deleteBuffer(gBuffer);

    TwTerminate();
  }

  //
  // load 3d models
  //
  void loadModels() {
      scene = new Scene(texMan);
      envmap = new EnvMap();
      const char* attribs[3] = { "in_position", "in_normal", "in_texcoord" };

      envmap->initialize(texMan, "data/mud_road_puresky_4k.hdr");

      scene->loadOBJ(SCENE_SMOOTH | SCENE_COLOR, prgRender.getProgramObject(), 3,
          (const char**)attribs, "cbox.obj", "./data/", false);
      scene->buildBVH(0);


      vector<CpuEmissiveTriangle> emissiveTris = generateEmissiveTrianglesForCBoxTest();
      // TODO: validate that additional lights don't darken the scene
      vector<CpuEmissiveTriangle> notSeen =
        generateEmissiveTrianglesForCBoxTest(10, 10, 0.05, 2.0);
      emissiveTris.insert(emissiveTris.end(), notSeen.begin(), notSeen.end());
      // vector<CpuEmissiveTriangle> emissiveTris;
      // addSquareLight(emissiveTris, glm::vec3(0.0, 0.0, 0.499), 0.05);

      lights.initialize(emissiveTris);
  }

  void loadShadersReSTIR(bool firstTime = false) {
    bool success = true;

    success &= prgReSTIRFinal.loadVertexShader(
        tmpStrCat(path2Demo, "shader/restir_final.vp.glsl"));
    success &= prgReSTIRFinal.loadFragmentShader(
        tmpStrCat(path2Demo, "shader/restir_final.fp.glsl"));
    success &= prgReSTIRFinal.link();

    success &= prgReSTIRTemporal.loadComputeShader(
        tmpStrCat(path2Demo, "shader/restir_temporal.comp"));
    success &= prgReSTIRTemporal.link();

    success &= prgReSTIRSpatial.loadComputeShader(
        tmpStrCat(path2Demo, "shader/restir_spatial.comp"));
    success &= prgReSTIRSpatial.link();

    if (!success) {
      if (firstTime)
        exit(1);
    }

    CheckGLError();

    wrapReSTIRFinal = createWrapper(prgReSTIRFinal);

    CheckGLError();
  }

  //
  // load vertex and fragment shaders
  //
  void loadShaders(bool firstTime = false) {
    if (!firstTime)
      CRenderBase::loadShaders(firstTime);

    // load and setup a shader
    if (!prgRender.loadVertexShader(
            tmpStrCat(path2Demo, "shader/perpixel_lighting.vp.glsl")) ||
        !prgRender.loadFragmentShader(
            tmpStrCat(path2Demo, "shader/perpixel_lighting.fp.glsl"))) {
      if (firstTime)
        exit(1);
    }

    prgRender.link();
    glBindFragDataLocation(prgRender.getProgramObject(), 0, "out_color");
    glBindFragDataLocation(prgRender.getProgramObject(), 1, "out_pos");
    glBindFragDataLocation(prgRender.getProgramObject(), 2, "out_normal");

    CheckGLError();

    loadShadersReSTIR(firstTime);

#ifdef USE_TWEAK_BAR
    if (firstTime) {
      initializeTweakBar();

      // parse the shader for UI-variables, add them to AntTweakBar in section
      // 'auto-gen variables'
      parseShaderTweakBar(bar, &prgRender, prgRender.getFragmentShaderSrc(),
                          "auto-gen variables");
    }
#endif

    // load and setup a shader
    if (!prgDepth.loadVertexShader(
            tmpStrCat(path2Demo, "shader/perpixel_lighting.vp.glsl")) ||
        !prgDepth.loadFragmentShader(
            tmpStrCat(path2Demo, "shader/noop.fp.glsl"))) {
      if (firstTime)
        exit(1);
    }

    prgDepth.link();

    CheckGLError();

    // this shows how to load a custom post processing shader and parsing its
    // source for UI-variables
    if (!prgPostProc.loadVertexShader(
            tmpStrCat(path2Demo, "shader/postprocess.vp.glsl")) ||
        !prgPostProc.loadFragmentShader(
            tmpStrCat(path2Demo, "shader/postprocess.fp.glsl"))) {
      if (firstTime)
        exit(1);
    }
    prgPostProc.link();
    glBindFragDataLocation(prgPostProc.getProgramObject(), 0, "result");

    wrap = createWrapper(prgPostProc);

#ifdef USE_TWEAK_BAR
    if (firstTime) {
      parseShaderTweakBar(bar, &prgPostProc, prgPostProc.getFragmentShaderSrc(),
                          "Post Process");
    }
#endif
  }

  //
  // create textures and render targets
  //
  void createTextures() {
    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);

    // bind the frame buffer object
    pDeferredFBO.Bind();

    // create and attach textures to framebuffer color buffer
    texMan->CreateTexture(&tGColor, w, h, GL_RGBA16F_ARB, "color");
    texMan->CreateTexture(&tGPosition, w, h, GL_RGBA32F_ARB, "position");
    texMan->CreateTexture(&tGNormal, w, h, GL_RGBA16F_ARB, "normals");
    pDeferredFBO.AttachTexture(GL_TEXTURE_2D, tGColor->getID(),
                               GL_COLOR_ATTACHMENT0);
    pDeferredFBO.AttachTexture(GL_TEXTURE_2D, tGPosition->getID(),
                               GL_COLOR_ATTACHMENT1);
    pDeferredFBO.AttachTexture(GL_TEXTURE_2D, tGNormal->getID(),
                               GL_COLOR_ATTACHMENT2);

    // initialize and attach depth renderbuffer
    pDeferredRenderBuffer.Set(GL_DEPTH24_STENCIL8, w, h);
    pDeferredFBO.AttachRenderBuffer(pDeferredRenderBuffer.GetId(),
                                    GL_DEPTH_ATTACHMENT);

    // validate the fbo after attaching textures and render buffers
    pDeferredFBO.IsValid();

    // disable fbo rendering for now
    FramebufferObject::Disable();
  }

    int getGPUStructSize(GLuint program, const char* blockName) {
      GLuint blockIndex = glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, blockName);
      GLenum enums[] = { GL_BUFFER_DATA_SIZE };
      int structSize;
      glGetProgramResourceiv(program, GL_SHADER_STORAGE_BLOCK, blockIndex, 1, enums, 1, NULL, &structSize);
      return structSize;
    }

  // Function to create a single OpenGL Shader Storage Buffer
  void createBuffer(GLuint &buffer, GLsizeiptr structSize, int width, int height) {
    GLsizeiptr bufferSize = structSize * width * height;

    glGenBuffers(1, &buffer);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, buffer);
    glBufferData(GL_SHADER_STORAGE_BUFFER, bufferSize, NULL, GL_DYNAMIC_COPY);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
  }

  // Function to delete a single OpenGL Shader Storage Buffer
  void deleteBuffer(GLuint &buffer) {
    if (buffer != 0) {
        glDeleteBuffers(1, &buffer);
        buffer = 0; // Reset to avoid dangling references
    }
  }

  void firstFramePrep() {
      scene->uploadBVH2GPU(width, height);
      scene->setBVHShaderUniforms(&prgRender);

      loadShaders();

      mat4 matM;
      camera.computeMatrices(&trackball, matM, 0);

      lights.uploadLightList2GPU();
      lights.setLightListShaderUniforms(&prgRender);
  }

  //
  // render scene to G-buffers
  //
  void sceneRenderDepth() {
    // now bind the program and set the parameters
    prgDepth.bind();
    //
    // save current render target and viewport
    //
    GLint camRenderTarget, camViewPort[4];
    glGetIntegerv(GL_DRAW_BUFFER, &camRenderTarget);
    glGetIntegerv(GL_VIEWPORT, camViewPort);

    //
    // setup viewport and OpenGL-states
    //
    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);
    glViewport(0, 0, w, h);

    pDeferredFBO.Bind();
    CheckGLError();

    // set some render states
    glEnable(GL_DEPTH_TEST);
    CheckGLError();
    glEnable(GL_CULL_FACE);
    CheckGLError();

    // clear screen
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    CheckGLError();
    // glClearColor( 0.3f, 0.3f, 0.3f, 0.2f );
    CheckGLError();
    glClear(GL_DEPTH_BUFFER_BIT);
    CheckGLError();

    CheckGLError();

    // this makro bins the texture object 'tDiffuse' to the shader program
    // 'prgRender' where the sampler is called 'tObjMapKd', and texture unit #0
    // is used (essentially this is a bind + Uniform1i)
    // BINDOGLTEX( prgRender, "tObjMapKd", tDiffuse,   GL_TEXTURE0 );
    // BINDOGLTEX( prgRender, "tObjMapNs", tNormalMap, GL_TEXTURE1 );

    // compute some matrices and set uniforms
    mat4 matM, matNrml;
    camera.computeMatrices(&trackball, matM, 0);
    matNrml = transpose(inverse(matM));

    CheckGLError();

    static int sampleIdx = 0;
    sampleIdx++;

    CheckGLError();
    prgDepth.UniformMatrix4fv((char const *)"matM", 1, false, value_ptr(matM));
    CheckGLError();
    prgDepth.UniformMatrix4fv((char const *)"matNrml", 1, false,
                              value_ptr(matNrml));
    CheckGLError();
    prgDepth.UniformMatrix4fv((char const *)"matMV", 1, false,
                              value_ptr(camera.matMV));
    CheckGLError();
    prgDepth.UniformMatrix4fv((char const *)"matVP", 1, false,
                              value_ptr(camera.matVP));
    CheckGLError();
    prgDepth.UniformMatrix4fv((char const *)"matV", 1, false,
                              value_ptr(camera.matV));
    CheckGLError();

    mat4 matMVP = camera.matMVP;
    prgDepth.UniformMatrix4fv((char *)"matMVP", 1, false, value_ptr(matMVP));
    // prgRender.UniformMatrix4fv( (char const*)"matMVP",  1, false, value_ptr(
    // camera.matMVP ) );

    CheckGLError();

    // render objects
    scene->draw(&prgDepth, RENDER_MATERIALS);

    CheckGLError();
    //
    // restore viewport and render target
    //
    pDeferredFBO.Disable();
    glViewport(camViewPort[0], camViewPort[1], camViewPort[2], camViewPort[3]);
    GLenum buffersCam[] = {(GLenum)camRenderTarget};
    glDrawBuffers(1, buffersCam);

    CheckGLError();

    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    CheckGLError();
  }

  //
  // render scene to G-buffers
  //
  void sceneRenderGBuffers(int frame) {
    //
    // save current render target and viewport
    //
    GLint camRenderTarget, camViewPort[4];
    glGetIntegerv(GL_DRAW_BUFFER, &camRenderTarget);
    glGetIntegerv(GL_VIEWPORT, camViewPort);

    //
    // setup viewport and OpenGL-states
    //
    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);
    glViewport(0, 0, w, h);

    pDeferredFBO.Bind();
    CheckGLError();

    const GLenum buffers[3] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1,
                               GL_COLOR_ATTACHMENT2};
    glDrawBuffers(3, buffers);

#ifdef USE_TWEAK_BAR
    setShaderUniformsTweakBar();
#endif
    CheckGLError();

    // set some render states
    glEnable(GL_DEPTH_TEST);
    CheckGLError();
    glEnable(GL_CULL_FACE);
    CheckGLError();

    glDepthFunc(GL_EQUAL);
    // CheckGLError();
    glDepthMask(GL_FALSE);
    // CheckGLError();

    // clear screen
    glClearColor(0.3f, 0.3f, 0.3f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // now bind the program and set the parameters
    prgRender.bind();

    envmap->bind(&prgRender);
    CheckGLError();

    // this makro bins the texture object 'tDiffuse' to the shader program
    // 'prgRender' where the sampler is called 'tObjMapKd', and texture unit #0
    // is used (essentially this is a bind + Uniform1i)
    // BINDOGLTEX( prgRender, "tObjMapKd", tDiffuse,   GL_TEXTURE0 );
    // BINDOGLTEX( prgRender, "tObjMapNs", tNormalMap, GL_TEXTURE1 );

    // compute some matrices and set uniforms
    mat4 matM, matNrml;
    camera.computeMatrices(&trackball, matM, 0);
    matNrml = transpose(inverse(matM));

    CheckGLError();

    static int sampleIdx = 0;
    sampleIdx++;

    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matM", 1, false, value_ptr(matM));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matNrml", 1, false,
                               value_ptr(matNrml));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matMV", 1, false,
                               value_ptr(camera.matMV));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matVP", 1, false,
                               value_ptr(camera.matVP));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matV", 1, false,
                               value_ptr(camera.matV));
    CheckGLError();

    CheckGLError();
    mat4 matMVP = camera.matMVP;
    prgRender.UniformMatrix4fv((char *)"matMVP", 1, false, value_ptr(matMVP));
    // prgRender.UniformMatrix4fv( (char const*)"matMVP",  1, false, value_ptr(
    // camera.matMVP ) );
    CheckGLError();

    prgRender.Uniform3fv((char const *)"camPos", 1, value_ptr(camera.camPos));
    prgRender.Uniform1f((char const *)"time", (float)frame);
    prgRender.Uniform1i((char const *)"frameIdx", frame);
    CheckGLError();

    prgRender.Uniform1i((char const *)"width", width);
    CheckGLError();
    prgRender.Uniform1i((char const *)"height", height);
    CheckGLError();

    prgRender.Uniform1i((char const *)"n_samples", renderSettings.n_samples);
    CheckGLError();

    prgRender.Uniform1i((char const *)"sample_mode",
                        (int)renderSettings.sampleMode);

    // render objects
    scene->draw(&prgRender, RENDER_MATERIALS);
    CheckGLError();

    //
    // restore viewport and render target
    //
    pDeferredFBO.Disable();
    glViewport(camViewPort[0], camViewPort[1], camViewPort[2], camViewPort[3]);
    GLenum buffersCam[] = {(GLenum)camRenderTarget};
    glDrawBuffers(1, buffersCam);


    // CheckGLError();
    glDepthMask(GL_TRUE);
    glDepthFunc(GL_LESS);

    CheckGLError();
  }

  void sceneRenderGBuffersReSTIR(int frame) {
    //
    // save current render target and viewport
    //
    GLint camRenderTarget, camViewPort[4];
    glGetIntegerv(GL_DRAW_BUFFER, &camRenderTarget);
    glGetIntegerv(GL_VIEWPORT, camViewPort);

    //
    // setup viewport and OpenGL-states
    //
    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);
    glViewport(0, 0, w, h);

    pDeferredFBO.Bind();
    CheckGLError();

    const GLenum buffers[3] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1,
                               GL_COLOR_ATTACHMENT2};
    glDrawBuffers(3, buffers);

#ifdef USE_TWEAK_BAR
    setShaderUniformsTweakBar();
#endif
    CheckGLError();

    // set some render states
    glEnable(GL_DEPTH_TEST);
    CheckGLError();
    glEnable(GL_CULL_FACE);
    CheckGLError();

    glDepthFunc(GL_EQUAL);
    // CheckGLError();
    glDepthMask(GL_FALSE);
    // CheckGLError();

    // clear screen
    glClearColor(0.3f, 0.3f, 0.3f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // now bind the program and set the parameters
    prgRender.bind();

    envmap->bind(&prgRender);
    CheckGLError();

    // this makro bins the texture object 'tDiffuse' to the shader program
    // 'prgRender' where the sampler is called 'tObjMapKd', and texture unit #0
    // is used (essentially this is a bind + Uniform1i)
    // BINDOGLTEX( prgRender, "tObjMapKd", tDiffuse,   GL_TEXTURE0 );
    // BINDOGLTEX( prgRender, "tObjMapNs", tNormalMap, GL_TEXTURE1 );

    // compute some matrices and set uniforms
    mat4 matM, matNrml;
    camera.computeMatrices(&trackball, matM, 0);
    matNrml = transpose(inverse(matM));

    CheckGLError();

    static int sampleIdx = 0;
    sampleIdx++;

    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matM", 1, false, value_ptr(matM));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matNrml", 1, false,
                               value_ptr(matNrml));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matMV", 1, false,
                               value_ptr(camera.matMV));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matVP", 1, false,
                               value_ptr(camera.matVP));
    CheckGLError();
    prgRender.UniformMatrix4fv((char const *)"matV", 1, false,
                               value_ptr(camera.matV));
    CheckGLError();

    CheckGLError();
    mat4 matMVP = camera.matMVP;
    prgRender.UniformMatrix4fv((char *)"matMVP", 1, false, value_ptr(matMVP));
    // prgRender.UniformMatrix4fv( (char const*)"matMVP",  1, false, value_ptr(
    // camera.matMVP ) );
    CheckGLError();

    prgRender.Uniform3fv((char const *)"camPos", 1, value_ptr(camera.camPos));
    prgRender.Uniform1f((char const *)"time", (float)frame);
    prgRender.Uniform1i((char const *)"frameIdx", frame);
    CheckGLError();

    prgRender.Uniform1i((char const *)"width", w);
    CheckGLError();
    prgRender.Uniform1i((char const *)"height", h);
    CheckGLError();

    prgRender.Uniform1i((char const *)"n_samples", renderSettings.n_samples);
    CheckGLError();

    prgRender.Uniform1i((char const *)"sample_mode",
                        (int)renderSettings.sampleMode);

    // write to A
    // reservoirBufferB contains the result of the previous frame
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_OUT_BINDING, reservoirBufferA);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, GBUFFER_BINDING, gBuffer);
    // render objects
    scene->draw(&prgRender, RENDER_MATERIALS);
    CheckGLError();

    //
    // restore viewport and render target
    //

    CheckGLError();
    glDepthMask(GL_TRUE);
    glDepthFunc(GL_LESS);

    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // ====================================
    // Temporal Pass
    // ====================================

    prgReSTIRTemporal.bind();

    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_IN_BINDING, reservoirBufferB);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_OUT_BINDING, reservoirBufferA);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, GBUFFER_BINDING, gBuffer);

    prgReSTIRTemporal.Uniform1i("width",  w);
    prgReSTIRTemporal.Uniform1i("height", h);

    glDispatchCompute((width + 7) / 8, (height + 7) / 8, 1);

    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // ====================================
    // Spatial Pass
    // ====================================

    for (int i = 0; i < N_ITERATIONS_SPATIAL; i++) {
      prgReSTIRSpatial.bind();

      glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_IN_BINDING, reservoirBufferA);
      glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_OUT_BINDING, reservoirBufferB);
      glBindBufferBase(GL_SHADER_STORAGE_BUFFER, GBUFFER_BINDING, gBuffer);

      prgReSTIRSpatial.Uniform1i((char const *)"width",  w);
      prgReSTIRSpatial.Uniform1i((char const *)"height", h);

      glDispatchCompute((w + 7) / 8, (h + 7) / 8, 1);
      glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
      std::swap(reservoirBufferA, reservoirBufferB);
    }
    std::swap(reservoirBufferA, reservoirBufferB);

    // ====================================
    // Render ReSTIR to screen
    // ====================================

    const GLenum finalBuffers[1] = { GL_COLOR_ATTACHMENT0 };
    glDrawBuffers(1, finalBuffers); // We only need to write one color now

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    prgReSTIRFinal.bind();

    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, RESERVOIR_BUFFER_IN_BINDING, reservoirBufferB);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, GBUFFER_BINDING, gBuffer);
    CheckGLError(-1);
    prgReSTIRFinal.Uniform1i((char const *)"width", w);
    CheckGLError(-2);
    prgReSTIRFinal.Uniform1i((char const *)"height", h);
    CheckGLError(-3);

    CheckGLError(1);
    wrapReSTIRFinal->draw();
    CheckGLError(2);

    pDeferredFBO.Disable();
    glViewport(camViewPort[0], camViewPort[1], camViewPort[2], camViewPort[3]);
    GLenum buffersCam[] = {(GLenum)camRenderTarget};
    glDrawBuffers(1, buffersCam);
    CheckGLError();
  }

  //
  // render post processing
  //
  void scenePostProc() {
    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);

    // Clear the screen with a specific color
    // glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    // glClear(GL_COLOR_BUFFER_BIT);

    // glDisable(GL_BLEND);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glEnable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    glm::mat4 mat(1);
    envmap->renderSkybox(camera.matMVP, mat, camera.camPos);

    prgPostProc.bind();


    BINDOGLTEX(prgPostProc, "tColor", tGColor, GL_TEXTURE0);
    BINDOGLTEX(prgPostProc, "tPosition", tGPosition, GL_TEXTURE1);
    BINDOGLTEX(prgPostProc, "tNormal", tGNormal, GL_TEXTURE2);

    prgPostProc.Uniform1i((char const *)"width", w);
    prgPostProc.Uniform1i((char const *)"height", h);

    prgPostProc.Uniform1i((char const *)"rendermode",
                          (int)renderSettings.renderMode);

    envmap->bind(&prgPostProc);
    prgPostProc.Uniform3fv((char *)"camPos", 1, glm::value_ptr(camera.camPos));

    wrap->draw();

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
  }

  //
  // render a frame of the scene
  //
  void sceneRender() {

    static int frame = 0;
    if (frame == 0) {
      firstFramePrep();
    }
    frame++;

    int w, h;
    glfwGetWindowSize(glfwWindow, &w, &h);
    glViewport(0, 0, w, h);

    if ((w != width) || (h != height)) {
        // window has been resized, update the attributes
        width = w;
        height = h;

        // recreate screenspace reservoir buffer size
        deleteBuffer(reservoirBufferA);
        deleteBuffer(reservoirBufferB);

        // Create two buffers by calling the function twice
        createBuffer(reservoirBufferA, reservoirStructSize, width, height);
        createBuffer(reservoirBufferB, reservoirStructSize, width, height);
    }

    useAccumulationBuffer =
        renderSettings
            .enableAccumulation; // call clearAccumulationBuffer(); in
                                 // sceneFrameRender() to clear the buffer
    accumulationEWA =
        renderSettings
            .accumulationEWA; // if this value is set (to != 1.0f which is
                              // default) then accumulation buffer images will
                              // be accumulated using exponentially weighted
                              // averaging

    if (renderSettings.resetAccumulationBuffer) {
      clearAccumulationBuffer();
      renderSettings.resetAccumulationBuffer = false;
    }

    if (trackball.hasUpdated() && accumulationEWA == 1.0f)
      clearAccumulationBuffer();

    sceneRenderDepth();

    // ReSTIR has its own pipeline / shaders
    if (renderSettings.sampleMode == SAMPLE_MODE_RESTIR) {
      sceneRenderGBuffersReSTIR(frame);
    } else {
      sceneRenderGBuffers(frame);
    }

    if (offScreenRenderTarget)
      CRenderBase::prepareOffScreenRendering();

    scenePostProc();

    if (offScreenRenderTarget)
      CRenderBase::finishOffScreenRendering();

    scenePostProcess();
  }
};

// no need to modify anything below this line

CRender *pRenderClass;

void initialize() { pRenderClass = new CRender(); }

#endif
