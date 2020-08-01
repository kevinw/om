Builtin_Shaders :: struct { // TODO: #load should be allowed to be namespaced!?

color2d_v :: #string END
    in vec2 vert;
    uniform vs_uniforms {
        mat4 P, MV;
    };
    void main() {
        gl_Position = P * MV * vec4(vert, 0.0, 1.0);
    }
END;

color_f :: #string END
    uniform fs_uniforms {
        uniform vec4 color;
    };
    out vec4 fragColor;
    void main() {
        fragColor = color;
    }
END;

texture2d_v :: #string END
    in vec2 vert;
    in vec2 uv;
    uniform vs_uniforms {
        mat4 P, MV;
    };
    out vec2 v_uv;
    void main() {
        v_uv = uv;
        gl_Position = P * MV * vec4(vert, 0.0, 1.0);
    }
END;

texture_f :: #string END
    uniform sampler2D tex;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        color = texture(tex, v_uv);
    }
END;

}