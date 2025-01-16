#include <optional>
#include "stdafx.h"

template<typename T>
class OGlBuffer {
public:
    GLenum target;
    GLuint bufferId;
    GLsizeiptr size;

    explicit OGlBuffer(const GLenum target, size_t elements, GLbitfield flags = 0): size(elements * sizeof(T)) {
        this->target = target;
        this->bufferId = 0;
        if (glIsBuffer(this->bufferId)) {
            glDeleteBuffers(1, &this->bufferId);
        }
        glGenBuffers(1, &this->bufferId);
        bind();
        glBufferStorage(target, size, NULL, flags);
        unbind();
    }

    ~OGlBuffer() {
        if (glIsBuffer(this->bufferId) == GL_TRUE) {
            glDeleteBuffers(1, &this->bufferId);
        }
    }

    void bind(const std::optional<GLenum>& target = std::nullopt) const {
        glBindBuffer(target.value_or(this->target), this->bufferId);
    }

    void bindBase(const GLuint index, const std::optional<GLenum>& target = std::nullopt) const {
        glBindBufferBase(target.value_or(this->target), index, this->bufferId);
    }

    void unbind() const {
        glBindBuffer(target, 0);
    }

    void unbindBase(const GLuint index) const {
        glBindBufferBase(target, index, 0);
    }

    void upload(const void* data, const GLsizeiptr size) {
        this->size = size;
        this->bind();
        glBufferSubData(target, 0, size, data);
        this->unbind();
    }

    void upload(const std::vector<T>& data) {
        this->upload(data.data(), data.size() * sizeof(T));
    }

    void zero() {
        bind();
        unsigned char zero = 0;
        glClearBufferData(target, GL_R8, GL_RED, GL_UNSIGNED_BYTE, &zero);
    }

    [[nodiscard]] std::vector<T> download() const {
        this->bind();

        void* rawBufferData = malloc(this->size);
        memset(rawBufferData, 0, this->size);
        glGetBufferSubData(target, 0, this->size, rawBufferData);

        T* data = static_cast<T*>(rawBufferData);
        std::vector<T> result(data, data + this->size / sizeof(T));
        free(rawBufferData);

        this->unbind();

        return result;
    }
};
