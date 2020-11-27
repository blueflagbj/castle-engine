/* Bump mapping shader effect.
   Included by EnableShaderBumpMapping in ../castlerendererinternalshader.pas unit.
*/

attribute vec3 castle_tangent;
attribute vec3 castle_bitangent;
varying mat3 castle_tangent_to_eye_space;

// avoid redeclaring variables when no "separate compilation units" available (OpenGLES)
#ifndef GL_ES
uniform mat3 castle_NormalMatrix;
attribute vec3 castle_Normal;
#endif

void PLUG_vertex_eye_space(const in vec4 vertex_eye, const in vec3 normal_eye)
{
  mat3 castle_tangent_to_object_space = mat3(
    castle_tangent,
    castle_bitangent,
    castle_Normal
  );
  castle_tangent_to_eye_space = castle_NormalMatrix * castle_tangent_to_object_space;
  /* PLUG: bump_mapping_tangent_space_calculations (vertex_eye, castle_tangent_to_object_space) */
}
