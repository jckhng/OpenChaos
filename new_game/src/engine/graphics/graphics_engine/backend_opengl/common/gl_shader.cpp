// Shader compilation and program linking utilities for OpenGL 4.1 core profile.

#include "engine/graphics/graphics_engine/backend_opengl/common/gl_shader.h"
#include "engine/graphics/graphics_engine/backend_opengl/common/glad/include/glad/gl.h"
#include <stdio.h>
#ifdef OPENCHAOS_GLES
#include <cstring>
#include <string>
#endif

#ifdef OPENCHAOS_GLES
static std::string gl_shader_prepare_source_for_gles(const char* source)
{
    std::string adjusted(source ? source : "");
    const char* desktop_version = "#version 410 core";
    const size_t version_pos = adjusted.find(desktop_version);
    if (version_pos != std::string::npos) {
        const size_t first_non_ws = adjusted.find_first_not_of(" \t\r\n");
        if (first_non_ws == version_pos && version_pos > 0) {
            adjusted.erase(0, version_pos);
        }
        adjusted.replace(0, strlen(desktop_version),
            "#version 300 es\n"
            "precision highp float;\n"
            "precision highp int;\n");
    }
    return adjusted;
}
#endif

uint32_t gl_shader_compile(uint32_t type, const char* source)
{
    GLuint shader = glCreateShader(type);
#ifdef OPENCHAOS_GLES
    std::string adjusted_source = gl_shader_prepare_source_for_gles(source);
    const char* shader_source = adjusted_source.c_str();
#else
    const char* shader_source = source;
#endif
    glShaderSource(shader, 1, &shader_source, nullptr);
    glCompileShader(shader);

    GLint success = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        const char* type_name = (type == GL_VERTEX_SHADER) ? "vertex" : "fragment";
        fprintf(stderr, "OpenGL %s shader compile error:\n%s\n", type_name, log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

uint32_t gl_shader_link(uint32_t vert, uint32_t frag)
{
    GLuint program = glCreateProgram();
    glAttachShader(program, vert);
    glAttachShader(program, frag);
    glLinkProgram(program);

    GLint success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char log[512];
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        fprintf(stderr, "OpenGL shader link error:\n%s\n", log);
        glDeleteProgram(program);
        program = 0;
    }

    glDeleteShader(vert);
    glDeleteShader(frag);
    return program;
}

uint32_t gl_shader_create_program(const char* vert_source, const char* frag_source)
{
    uint32_t vert = gl_shader_compile(GL_VERTEX_SHADER, vert_source);
    if (!vert)
        return 0;

    uint32_t frag = gl_shader_compile(GL_FRAGMENT_SHADER, frag_source);
    if (!frag) {
        glDeleteShader(vert);
        return 0;
    }

    return gl_shader_link(vert, frag);
}
