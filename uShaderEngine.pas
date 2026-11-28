unit uShaderEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math, GL, GLExt;

type
  TShaderTextureData = record
    Width: Integer;
    Height: Integer;
    RGB: TBytes;
  end;

procedure InitShaderEngine(AWidth, AHeight: Integer; const AShaderDir: string = '');
procedure UpdateShaderViewport(AWidth, AHeight: Integer);
procedure SelectActiveShader(const AName: string);
procedure UploadTextureDataA(const ATex: TShaderTextureData);
procedure UploadTextureDataB(const ATex: TShaderTextureData);
procedure PromoteTextureBToA;
function HasTextureA: Boolean;
procedure RenderStaticWallpaper;
procedure RenderWallpaperFrame(AProgress, ATimeSec: Single);
procedure ShutdownShaderEngine;

implementation

const
  EMBED_VERT_SRC =
    '#version 330 core' + #10 +
    'layout (location = 0) in vec2 a_pos;' + #10 +
    'out vec2 v_uv;' + #10 +
    'void main() {' + #10 +
    '  v_uv = a_pos * 0.5 + 0.5;' + #10 +
    '  v_uv.y = 1.0 - v_uv.y;' + #10 +
    '  gl_Position = vec4(a_pos, 0.0, 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_FADE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  vec3 colA = texture(u_texA, coverUv(v_uv, u_res, u_texResA)).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, coverUv(v_uv, u_res, u_texResB)).rgb;' + #10 +
    '  float t = smoothstep(0.0, 1.0, u_progress);' + #10 +
    '  fragColor = vec4(mix(colA, colB, t), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_WIPE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  vec3 colA = texture(u_texA, coverUv(v_uv, u_res, u_texResA)).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, coverUv(v_uv, u_res, u_texResB)).rgb;' + #10 +
    '  float edge = mix(-0.04, 1.04, smoothstep(0.0, 1.0, u_progress));' + #10 +
    '  float mask = smoothstep(edge + 0.025, edge - 0.025, v_uv.x);' + #10 +
    '  fragColor = vec4(mix(colA, colB, mask), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_LEFT_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float t = smoothstep(0.0, 1.0, u_progress);' + #10 +
    '  if (v_uv.x < 1.0 - t) {' + #10 +
    '    vec2 uvA = coverUv(vec2(v_uv.x + t, v_uv.y), u_res, u_texResA);' + #10 +
    '    fragColor = vec4(texture(u_texA, uvA).rgb, 1.0);' + #10 +
    '  } else {' + #10 +
    '    vec2 uvB = coverUv(vec2(v_uv.x - (1.0 - t), v_uv.y), u_res, u_texResB);' + #10 +
    '    fragColor = vec4(texture(u_texB, uvB).rgb, 1.0);' + #10 +
    '  }' + #10 +
    '}' + #10 +
    '';

  EMBED_RIGHT_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float t = smoothstep(0.0, 1.0, u_progress);' + #10 +
    '  if (v_uv.x < t) {' + #10 +
    '    vec2 uvB = coverUv(vec2(v_uv.x + (1.0 - t), v_uv.y), u_res, u_texResB);' + #10 +
    '    fragColor = vec4(texture(u_texB, uvB).rgb, 1.0);' + #10 +
    '  } else {' + #10 +
    '    vec2 uvA = coverUv(vec2(v_uv.x - t, v_uv.y), u_res, u_texResA);' + #10 +
    '    fragColor = vec4(texture(u_texA, uvA).rgb, 1.0);' + #10 +
    '  }' + #10 +
    '}' + #10 +
    '';

  EMBED_CENTER_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  vec3 colA = texture(u_texA, coverUv(v_uv, u_res, u_texResA)).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, coverUv(v_uv, u_res, u_texResB)).rgb;' + #10 +
    '  vec2 d = abs(v_uv - 0.5) * 2.0;' + #10 +
    '  float boxDist = max(d.x, d.y);' + #10 +
    '  float r = mix(-0.03, 1.04, smoothstep(0.0, 1.0, u_progress));' + #10 +
    '  float mask = smoothstep(r + 0.025, r - 0.025, boxDist);' + #10 +
    '  fragColor = vec4(mix(colA, colB, mask), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_FILM_BURN_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 p = vec2(v_uv.x * aspect, v_uv.y);' + #10 +
    '' + #10 +
    '  // Nuclei di perforazione organici + turbolenza della celluloide' + #10 +
    '  float coarse = fbm(p * 3.2 + vec2(1.7, 3.1));' + #10 +
    '  float detail = fbm(p * 11.5 - vec2(u_time * 0.12, u_time * 0.08));' + #10 +
    '  float grain = hash21(v_uv * u_res + fract(u_time) * 100.0) * 0.04;' + #10 +
    '' + #10 +
    '  // Tre focolai principali che si fondono mentre la pellicola fonde' + #10 +
    '  float hole1 = length(p - vec2(0.32 * aspect, 0.42)) * 0.68;' + #10 +
    '  float hole2 = length(p - vec2(0.74 * aspect, 0.63)) * 0.76;' + #10 +
    '  float hole3 = length(p - vec2(0.55 * aspect, 0.24)) * 0.88;' + #10 +
    '  float nuclei = min(min(hole1, hole2), hole3);' + #10 +
    '' + #10 +
    '  float burnField = mix(coarse, nuclei, 0.42) + detail * 0.28 + grain;' + #10 +
    '  float threshold = mix(0.20, 0.91, clamp(u_progress, 0.0, 1.0));' + #10 +
    '  float dist = burnField - threshold;' + #10 +
    '' + #10 +
    '  // Distorsione termica prima della perforazione' + #10 +
    '  float heatMask = smoothstep(0.18, 0.0, dist) * step(0.0, dist);' + #10 +
    '  vec2 heatOffset = vec2(' + #10 +
    '    fbm(p * 18.0 + u_time * 1.4) - 0.5,' + #10 +
    '    fbm(p * 18.0 - u_time * 1.1) - 0.5' + #10 +
    '  ) * 0.028 * heatMask;' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv + heatOffset, u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  // Annerimento da fuliggine e carbonizzazione' + #10 +
    '  float charZone = smoothstep(0.11, 0.012, dist);' + #10 +
    '  colA = mix(colA, colA * vec3(0.16, 0.10, 0.07), charZone * 0.92);' + #10 +
    '' + #10 +
    '  // Fronte incandescente della brace' + #10 +
    '  float emberCore = smoothstep(0.036, 0.0, abs(dist - 0.012));' + #10 +
    '  float emberFlicker = 0.78 + 0.45 * noise2D(p * 26.0 + u_time * 4.2);' + #10 +
    '  vec3 emberColor = mix(vec3(0.95, 0.22, 0.03), vec3(1.0, 0.86, 0.38), emberCore * emberFlicker);' + #10 +
    '' + #10 +
    '  // Perforazione netta che lascia trasparire il nuovo fotogramma' + #10 +
    '  float holeMask = smoothstep(0.008, -0.010, dist);' + #10 +
    '  vec3 outCol = mix(colA, colB, holeMask);' + #10 +
    '' + #10 +
    '  // Scia luminosa di brace attorno al bordo bruciato' + #10 +
    '  float activeMask = smoothstep(0.0, 0.04, u_progress) * smoothstep(1.0, 0.94, u_progress);' + #10 +
    '  outCol += emberColor * emberCore * 1.45 * emberFlicker * activeMask;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_NATURAL_WAVE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 p = vec2(v_uv.x * aspect, v_uv.y);' + #10 +
    '' + #10 +
    '  // Avanzamento diagonale naturale dell''onda con curvatura organica' + #10 +
    '  float sweepCoord = v_uv.x * 0.78 + v_uv.y * 0.22;' + #10 +
    '  float swell = sin(v_uv.y * 6.5 - u_time * 1.6) * 0.032' + #10 +
    '              + sin(v_uv.y * 13.0 + u_time * 2.3) * 0.014;' + #10 +
    '  float turbulence = (fbm(p * 5.2 + vec2(-u_time * 0.45, u_time * 0.22)) - 0.5) * 0.14;' + #10 +
    '' + #10 +
    '  float frontPos = mix(-0.07, 1.07, clamp(u_progress, 0.0, 1.0));' + #10 +
    '  float waveEdge = frontPos + swell + turbulence;' + #10 +
    '  float delta = sweepCoord - waveEdge;' + #10 +
    '' + #10 +
    '  // Rifrazione liquida davanti e sotto la massa d''acqua' + #10 +
    '  float rippleBand = exp(-pow(delta / 0.11, 2.0));' + #10 +
    '  vec2 waterNormal = vec2(' + #10 +
    '    fbm(p * 14.0 + vec2(u_time * 0.9, 0.0)) - 0.5,' + #10 +
    '    fbm(p * 14.0 + vec2(0.0, u_time * 0.9)) - 0.5' + #10 +
    '  );' + #10 +
    '  vec2 refractUvA = coverUv(v_uv + waterNormal * 0.045 * rippleBand, u_res, u_texResA);' + #10 +
    '  vec2 refractUvB = coverUv(v_uv - waterNormal * 0.018 * rippleBand, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  vec3 colA = texture(u_texA, refractUvA).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, refractUvB).rgb;' + #10 +
    '' + #10 +
    '  // Transizione morbida dietro l''onda' + #10 +
    '  float washedMask = smoothstep(0.035, -0.045, delta);' + #10 +
    '' + #10 +
    '  // Tinta profonda dell''acqua nella zona di cresta' + #10 +
    '  float waterDepth = smoothstep(0.10, 0.0, abs(delta)) * 0.45;' + #10 +
    '  vec3 waterTint = vec3(0.06, 0.28, 0.42);' + #10 +
    '  vec3 blended = mix(colA, colB, washedMask);' + #10 +
    '  blended = mix(blended, mix(blended, waterTint, 0.55), waterDepth);' + #10 +
    '' + #10 +
    '  // Schiuma organica sulla cresta dell''onda' + #10 +
    '  float foamNoise = fbm(p * 24.0 + vec2(-u_time * 1.3, u_time * 0.5));' + #10 +
    '  float crestBand = smoothstep(0.048, 0.002, abs(delta));' + #10 +
    '  float foamBubbles = smoothstep(0.36, 0.76, foamNoise + crestBand * 0.42) * crestBand;' + #10 +
    '  float activeMask = smoothstep(0.0, 0.05, u_progress) * smoothstep(1.0, 0.93, u_progress);' + #10 +
    '' + #10 +
    '  vec3 foamColor = vec3(0.90, 0.96, 1.0);' + #10 +
    '  blended = mix(blended, foamColor, clamp(foamBubbles * 0.88 * activeMask, 0.0, 1.0));' + #10 +
    '' + #10 +
    '  // Riflesso speculare umido sulla cresta' + #10 +
    '  float spec = pow(max(0.0, crestBand * foamNoise), 2.0) * 0.35 * activeMask;' + #10 +
    '  blended += vec3(0.75, 0.90, 1.0) * spec;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(blended, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_RAIN_MELT_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 p = vec2(v_uv.x * aspect, v_uv.y);' + #10 +
    '' + #10 +
    '  // Rivoli verticali di pioggia che scendono e sciolgono il pigmento' + #10 +
    '  float streakCoarse = fbm(vec2(p.x * 16.0, p.y * 1.4 - u_time * 0.55));' + #10 +
    '  float streakFine = fbm(vec2(p.x * 42.0, p.y * 2.8 - u_time * 1.15));' + #10 +
    '  float streaks = streakCoarse * 0.65 + streakFine * 0.35;' + #10 +
    '' + #10 +
    '  // Gocce d''impatto circolari distribuite su una griglia sfalsata' + #10 +
    '  vec2 dropGrid = p * vec2(7.5, 6.0) + vec2(0.0, -u_time * 0.18);' + #10 +
    '  vec2 cell = floor(dropGrid);' + #10 +
    '  vec2 local = fract(dropGrid) - 0.5;' + #10 +
    '  float cellRand = hash21(cell);' + #10 +
    '  vec2 dropCenter = vec2(hash21(cell + 7.3) - 0.5, hash21(cell + 19.1) - 0.5) * 0.55;' + #10 +
    '  float dropDist = length(local - dropCenter);' + #10 +
    '  float splash = smoothstep(0.45, 0.0, dropDist) * (0.35 + 0.65 * cellRand);' + #10 +
    '' + #10 +
    '  // Campo di dissolvimento: rivoli verticali + colata dall''alto + impatti gocce' + #10 +
    '  float gravityBias = v_uv.y * 0.22;' + #10 +
    '  float meltField = streaks * 0.62 + gravityBias + (1.0 - splash) * 0.18;' + #10 +
    '' + #10 +
    '  float threshold = mix(0.22, 0.85, clamp(u_progress, 0.0, 1.0));' + #10 +
    '  float dist = meltField - threshold;' + #10 +
    '' + #10 +
    '  float activeMask = smoothstep(0.0, 0.04, u_progress) * smoothstep(1.0, 0.94, u_progress);' + #10 +
    '' + #10 +
    '  // Scioglimento del colore verso il basso (v_uv.y=0 e'' in alto, quindi +y scende verso il basso)' + #10 +
    '  float meltBand = smoothstep(0.24, 0.0, dist) * step(-0.02, dist);' + #10 +
    '  float dripAmt = (0.015 + 0.075 * streakFine) * meltBand * (0.4 + 0.6 * u_progress);' + #10 +
    '  float smearWobble = (fbm(p * 18.0 + vec2(0.0, -u_time * 1.6)) - 0.5) * 0.016 * meltBand;' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv + vec2(smearWobble, -dripAmt), u_res, u_texResA);' + #10 +
    '  vec2 uvA2 = coverUv(v_uv + vec2(-smearWobble * 0.5, -dripAmt * 1.65), u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  // Media morbida di due campioni scolati per simulare il pigmento diluito nell''acqua' + #10 +
    '  vec3 paintA = mix(texture(u_texA, uvA).rgb, texture(u_texA, uvA2).rgb, 0.45);' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  // Bordo bagnato con leggera saturazione del colore che cola prima di lavarsi via' + #10 +
    '  float wetEdge = smoothstep(0.055, 0.0, abs(dist)) * activeMask;' + #10 +
    '  float lumA = dot(paintA, vec3(0.2126, 0.7152, 0.0722));' + #10 +
    '  vec3 saturatedPaint = mix(vec3(lumA), paintA, 1.38) * 0.88;' + #10 +
    '  paintA = mix(paintA, saturatedPaint, wetEdge * 0.8);' + #10 +
    '' + #10 +
    '  float revealMask = smoothstep(0.022, -0.022, dist);' + #10 +
    '  vec3 outCol = mix(paintA, colB, revealMask);' + #10 +
    '' + #10 +
    '  // Riflessi sottili di gocce e scie d''acqua lungo il fronte di lavaggio' + #10 +
    '  float rainSheen = pow(max(0.0, streakFine * wetEdge), 1.6) * 0.42;' + #10 +
    '  outCol += vec3(0.78, 0.86, 0.95) * rainSheen;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_INK_DISSOLVE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 p = vec2(v_uv.x * aspect, v_uv.y);' + #10 +
    '' + #10 +
    '  float fiber = fbm(p * 6.0);' + #10 +
    '  float fineGrain = fbm(p * 28.0);' + #10 +
    '  float bleedMap = fiber * 0.72 + fineGrain * 0.28;' + #10 +
    '' + #10 +
    '  float threshold = mix(0.12, 0.83, clamp(u_progress, 0.0, 1.0));' + #10 +
    '  float delta = bleedMap - threshold;' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv, u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  float inkRing = smoothstep(0.05, 0.0, abs(delta)) * 0.65;' + #10 +
    '  float activeMask = smoothstep(0.0, 0.04, u_progress) * smoothstep(1.0, 0.95, u_progress);' + #10 +
    '' + #10 +
    '  float reveal = smoothstep(0.025, -0.025, delta);' + #10 +
    '  vec3 outCol = mix(colA, colB, reveal);' + #10 +
    '  outCol = mix(outCol, vec3(0.04, 0.05, 0.07), inkRing * activeMask);' + #10 +
    '' + #10 +
    '  fragColor = vec4(outCol, 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_PRISM_WIPE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float diag = v_uv.x * 0.72 + v_uv.y * 0.28;' + #10 +
    '  float front = mix(-0.05, 1.05, clamp(u_progress, 0.0, 1.0));' + #10 +
    '  float dist = diag - front;' + #10 +
    '' + #10 +
    '  float glassBand = exp(-pow(dist / 0.065, 2.0));' + #10 +
    '  float activeMask = smoothstep(0.0, 0.05, u_progress) * smoothstep(1.0, 0.94, u_progress);' + #10 +
    '  float shift = 0.024 * glassBand * activeMask;' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv, u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  vec3 colA = vec3(' + #10 +
    '    texture(u_texA, uvA + vec2(shift, 0.0)).r,' + #10 +
    '    texture(u_texA, uvA).g,' + #10 +
    '    texture(u_texA, uvA - vec2(shift, 0.0)).b' + #10 +
    '  );' + #10 +
    '  vec3 colB = vec3(' + #10 +
    '    texture(u_texB, uvB + vec2(shift * 0.6, 0.0)).r,' + #10 +
    '    texture(u_texB, uvB).g,' + #10 +
    '    texture(u_texB, uvB - vec2(shift * 0.6, 0.0)).b' + #10 +
    '  );' + #10 +
    '' + #10 +
    '  float reveal = smoothstep(0.02, -0.02, dist);' + #10 +
    '  vec3 outCol = mix(colA, colB, reveal);' + #10 +
    '  outCol += vec3(0.16, 0.22, 0.30) * glassBand * 0.35 * activeMask;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_EARTHQUAKE_COLLAPSE_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'vec2 eqSlabCenter(vec2 cid) {' + #10 +
    '  return cid + vec2(' + #10 +
    '    0.18 + 0.64 * hash21(cid + vec2(11.3, 27.9)),' + #10 +
    '    0.18 + 0.64 * hash21(cid + vec2(53.1, 7.4))' + #10 +
    '  );' + #10 +
    '}' + #10 +
    '' + #10 +
    'void eqVoronoi(vec2 pt, out vec2 bestCell, out float edgeDist) {' + #10 +
    '  vec2 wp = pt + vec2(' + #10 +
    '    fbm(pt * 2.3 + vec2(3.1, 1.4)) - 0.5,' + #10 +
    '    fbm(pt * 2.3 + vec2(9.7, 5.2)) - 0.5' + #10 +
    '  ) * 0.28;' + #10 +
    '  vec2 n = floor(wp);' + #10 +
    '  vec2 f = fract(wp);' + #10 +
    '  float d1 = 8.0;' + #10 +
    '  float d2 = 8.0;' + #10 +
    '  bestCell = n;' + #10 +
    '  for (int dy = -1; dy <= 1; dy++) {' + #10 +
    '    for (int dx = -1; dx <= 1; dx++) {' + #10 +
    '      vec2 g = vec2(float(dx), float(dy));' + #10 +
    '      vec2 cid = n + g;' + #10 +
    '      vec2 c = eqSlabCenter(cid) - n;' + #10 +
    '      vec2 r = c - f;' + #10 +
    '      float d = dot(r, r);' + #10 +
    '      if (d < d1) {' + #10 +
    '        d2 = d1;' + #10 +
    '        d1 = d;' + #10 +
    '        bestCell = cid;' + #10 +
    '      } else if (d < d2) {' + #10 +
    '        d2 = d;' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '  edgeDist = (sqrt(d2) - sqrt(d1)) * 0.72;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 grid = vec2(max(5.0, floor(5.0 * aspect + 0.5)), 5.0);' + #10 +
    '  float p = clamp(u_progress, 0.0, 1.0);' + #10 +
    '' + #10 +
    '  float activeMask = smoothstep(0.0, 0.04, p) * smoothstep(1.0, 0.94, p);' + #10 +
    '  float shakeEnv = sin(clamp(p / 0.65, 0.0, 1.0) * 3.14159265) * activeMask;' + #10 +
    '  vec2 shakeOffset = vec2(' + #10 +
    '    sin(u_time * 47.0) * 0.011 + cos(u_time * 79.0) * 0.005,' + #10 +
    '    cos(u_time * 57.0) * 0.009 + sin(u_time * 83.0) * 0.004' + #10 +
    '  ) * shakeEnv;' + #10 +
    '' + #10 +
    '  vec2 q = v_uv * grid;' + #10 +
    '  vec2 baseCell = floor(q);' + #10 +
    '' + #10 +
    '  bool hitSlab = false;' + #10 +
    '  float bestDepth = -99.0;' + #10 +
    '  vec2 bestOrigUv = v_uv;' + #10 +
    '  float bestEdge = 1.0;' + #10 +
    '  float bestFallT = 0.0;' + #10 +
    '  float bestCrackBuild = 0.0;' + #10 +
    '  float crackShadow = 0.0;' + #10 +
    '' + #10 +
    '  for (int dy = -6; dy <= 1; dy++) {' + #10 +
    '    for (int dx = -1; dx <= 1; dx++) {' + #10 +
    '      vec2 cid = baseCell + vec2(float(dx), float(dy));' + #10 +
    '      if (cid.x < -1.0 || cid.x > grid.x || cid.y < -1.0 || cid.y > grid.y) continue;' + #10 +
    '' + #10 +
    '      float rnd = hash21(cid + vec2(4.2, 19.8));' + #10 +
    '      float rowNorm = clamp(cid.y / grid.y, 0.0, 1.0);' + #10 +
    '      float trigger = mix(0.08, 0.56, (1.0 - rowNorm) * 0.58 + rnd * 0.42);' + #10 +
    '      float fallT = clamp((p - trigger) / 0.40, 0.0, 1.0);' + #10 +
    '      if (fallT >= 1.0) continue;' + #10 +
    '' + #10 +
    '      float dropY = pow(fallT, 1.85) * (grid.y + 1.35);' + #10 +
    '      float driftX = (hash21(cid + vec2(31.7, 8.3)) - 0.5) * 0.55 * fallT;' + #10 +
    '      float tilt = (hash21(cid + vec2(71.1, 13.5)) - 0.5) * 0.46 * fallT;' + #10 +
    '' + #10 +
    '      vec2 center = eqSlabCenter(cid);' + #10 +
    '      vec2 rel = q - (center + vec2(driftX, dropY));' + #10 +
    '      float cs = cos(-tilt);' + #10 +
    '      float sn = sin(-tilt);' + #10 +
    '      vec2 origQ = center + vec2(rel.x * cs - rel.y * sn, rel.x * sn + rel.y * cs);' + #10 +
    '      vec2 origUv = origQ / grid;' + #10 +
    '' + #10 +
    '      if (origUv.x < 0.0 || origUv.x > 1.0 || origUv.y < 0.0 || origUv.y > 1.0) continue;' + #10 +
    '      if (dot(origQ - center, origQ - center) > 1.45) continue;' + #10 +
    '' + #10 +
    '      vec2 owner;' + #10 +
    '      float edgeDist;' + #10 +
    '      eqVoronoi(origQ, owner, edgeDist);' + #10 +
    '      if (length(owner - cid) < 0.1) {' + #10 +
    '        float crackBuild = smoothstep(0.0, max(0.08, trigger), p) * smoothstep(0.0, 0.03, p);' + #10 +
    '        float crackGap = mix(0.0, 0.036, crackBuild) + fallT * 0.025;' + #10 +
    '        if (edgeDist > crackGap) {' + #10 +
    '          float depth = (1.0 - fallT) * 2.0 + rnd * 0.5;' + #10 +
    '          if (!hitSlab || depth > bestDepth) {' + #10 +
    '            hitSlab = true;' + #10 +
    '            bestDepth = depth;' + #10 +
    '            bestOrigUv = origUv + shakeOffset * (1.0 - fallT * 0.6);' + #10 +
    '            bestEdge = edgeDist - crackGap;' + #10 +
    '            bestFallT = fallT;' + #10 +
    '            bestCrackBuild = crackBuild;' + #10 +
    '          }' + #10 +
    '        } else {' + #10 +
    '          crackShadow = max(crackShadow, crackBuild);' + #10 +
    '        }' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  vec2 uvB = coverUv(v_uv + shakeOffset * 0.12, u_res, u_texResB);' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  // Polvere sismica e ombra nelle fessure che scoprono il nuovo sfondo' + #10 +
    '  float dustField = fbm(vec2(v_uv.x * aspect, v_uv.y) * 7.5 + vec2(0.0, -u_time * 0.35));' + #10 +
    '  float dustBand = clamp(crackShadow * 0.75 + dustField * 0.45, 0.0, 1.0) * activeMask;' + #10 +
    '  vec3 dustCol = mix(colB, vec3(0.42, 0.38, 0.34), dustBand * 0.30);' + #10 +
    '  dustCol *= (1.0 - crackShadow * 0.38 * activeMask);' + #10 +
    '' + #10 +
    '  vec3 outCol = dustCol;' + #10 +
    '  if (hitSlab) {' + #10 +
    '    vec2 uvA = coverUv(clamp(bestOrigUv, 0.0, 1.0), u_res, u_texResA);' + #10 +
    '    vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '    float edgeBevel = smoothstep(0.045, 0.0, bestEdge) * bestCrackBuild;' + #10 +
    '    colA = mix(colA, colA * 0.45 + vec3(0.08, 0.07, 0.06), edgeBevel * 0.85);' + #10 +
    '    colA *= mix(1.0, 0.72, bestFallT * 0.65);' + #10 +
    '    outCol = colA;' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_PUZZLE_BUILD_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float jigsawEdgeContrib(float t, float n, float dir) {' + #10 +
    '  vec2 kp = vec2(t, n * dir);' + #10 +
    '  float neck = max(abs(kp.x) - 0.058, max(-kp.y - 0.02, kp.y - 0.16));' + #10 +
    '  float head = length(kp - vec2(0.0, 0.165)) - 0.128;' + #10 +
    '  return min(neck, head);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float jigsawPieceDist(vec2 q, vec2 cid, vec2 grid) {' + #10 +
    '  vec2 lp = q - cid;' + #10 +
    '  vec2 b = abs(lp - 0.5) - 0.5;' + #10 +
    '  float d = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0);' + #10 +
    '' + #10 +
    '  if (cid.x < grid.x - 0.5) {' + #10 +
    '    float dir = hash21(vec2(cid.x + 1.0, cid.y) + vec2(17.3, 41.9)) > 0.5 ? 1.0 : -1.0;' + #10 +
    '    float knob = jigsawEdgeContrib(lp.y - 0.5, lp.x - 1.0, dir);' + #10 +
    '    d = dir > 0.0 ? min(d, knob) : max(d, -knob);' + #10 +
    '  }' + #10 +
    '  if (cid.x > 0.5) {' + #10 +
    '    float dir = hash21(vec2(cid.x, cid.y) + vec2(17.3, 41.9)) > 0.5 ? -1.0 : 1.0;' + #10 +
    '    float knob = jigsawEdgeContrib(lp.y - 0.5, -lp.x, dir);' + #10 +
    '    d = dir > 0.0 ? min(d, knob) : max(d, -knob);' + #10 +
    '  }' + #10 +
    '  if (cid.y < grid.y - 0.5) {' + #10 +
    '    float dir = hash21(vec2(cid.x, cid.y + 1.0) + vec2(83.7, 19.4)) > 0.5 ? 1.0 : -1.0;' + #10 +
    '    float knob = jigsawEdgeContrib(lp.x - 0.5, lp.y - 1.0, dir);' + #10 +
    '    d = dir > 0.0 ? min(d, knob) : max(d, -knob);' + #10 +
    '  }' + #10 +
    '  if (cid.y > 0.5) {' + #10 +
    '    float dir = hash21(vec2(cid.x, cid.y) + vec2(83.7, 19.4)) > 0.5 ? -1.0 : 1.0;' + #10 +
    '    float knob = jigsawEdgeContrib(lp.x - 0.5, -lp.y, dir);' + #10 +
    '    d = dir > 0.0 ? min(d, knob) : max(d, -knob);' + #10 +
    '  }' + #10 +
    '  return d;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 grid = vec2(max(5.0, floor(5.0 * aspect + 0.5)), 5.0);' + #10 +
    '  float p = clamp(u_progress, 0.0, 1.0);' + #10 +
    '' + #10 +
    '  vec2 q = v_uv * grid;' + #10 +
    '  vec2 baseCell = floor(q);' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv, u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '  vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  // Traccia del reticolo puzzle mantenuta attiva finche'' la nuova immagine non e'' completata,' + #10 +
    '  // poi svanisce completamente lasciando lo sfondo finale pulito' + #10 +
    '  float traceLife = smoothstep(0.0, 0.04, p) * smoothstep(0.95, 0.78, p);' + #10 +
    '' + #10 +
    '  float staticMinAbs = 10.0;' + #10 +
    '  float lockedCoverage = 0.0;' + #10 +
    '  bool hasPlaced = false;' + #10 +
    '  float bestPlacedOrder = -1.0;' + #10 +
    '  vec2 bestSampleUv = uvB;' + #10 +
    '  float bestPieceDist = 1.0;' + #10 +
    '  float bestLocalT = 1.0;' + #10 +
    '  float dropShadow = 0.0;' + #10 +
    '' + #10 +
    '  for (int dy = -1; dy <= 1; dy++) {' + #10 +
    '    for (int dx = -1; dx <= 1; dx++) {' + #10 +
    '      vec2 cid = baseCell + vec2(float(dx), float(dy));' + #10 +
    '      if (cid.x < 0.0 || cid.x >= grid.x || cid.y < 0.0 || cid.y >= grid.y) continue;' + #10 +
    '' + #10 +
    '      float staticD = jigsawPieceDist(q, cid, grid);' + #10 +
    '      staticMinAbs = min(staticMinAbs, abs(staticD));' + #10 +
    '' + #10 +
    '      float wave = (cid.x / grid.x) * 0.30 + (cid.y / grid.y) * 0.19;' + #10 +
    '      float delay = 0.02 + wave + hash21(cid + vec2(5.1, 23.7)) * 0.24;' + #10 +
    '      float localT = clamp((p - delay) / 0.15, 0.0, 1.0);' + #10 +
    '' + #10 +
    '      if (localT > 0.0) {' + #10 +
    '        // Evita che le giunzioni tra due tessere gia'' posate lascino trapelare lo sfondo vecchio' + #10 +
    '        lockedCoverage += smoothstep(0.006, -0.004, staticD) * smoothstep(0.92, 1.0, localT);' + #10 +
    '' + #10 +
    '        // Effetto atterraggio morbido della tessera che si incastra sopra il vecchio sfondo' + #10 +
    '        float ease = 1.0 - pow(1.0 - localT, 3.0);' + #10 +
    '        float flyScale = mix(1.16, 1.0, ease);' + #10 +
    '        vec2 liftOffset = vec2(' + #10 +
    '          (hash21(cid + vec2(9.2, 3.4)) - 0.5) * 0.12,' + #10 +
    '          -0.16' + #10 +
    '        ) * (1.0 - ease);' + #10 +
    '' + #10 +
    '        vec2 center = cid + 0.5;' + #10 +
    '        vec2 pieceQ = (q - center - liftOffset) / flyScale + center;' + #10 +
    '        float pieceD = jigsawPieceDist(pieceQ, cid, grid);' + #10 +
    '' + #10 +
    '        // Ombra proiettata sotto la tessera in fase di posa' + #10 +
    '        vec2 shadowQ = (q - center - liftOffset - vec2(0.05, 0.06) * (1.0 - ease)) / flyScale + center;' + #10 +
    '        float shadowD = jigsawPieceDist(shadowQ, cid, grid);' + #10 +
    '        float softSh = smoothstep(0.09, -0.02, shadowD) * (1.0 - ease * 0.72);' + #10 +
    '        dropShadow = max(dropShadow, softSh * 0.52);' + #10 +
    '' + #10 +
    '        if (pieceD <= 0.002) {' + #10 +
    '          // Le tessere in volo stanno sopra a quelle gia'' posate' + #10 +
    '          float zOrder = (localT < 1.0) ? (2.0 + localT) : 1.0;' + #10 +
    '          if (!hasPlaced || zOrder > bestPlacedOrder || (zOrder == bestPlacedOrder && pieceD < bestPieceDist)) {' + #10 +
    '            hasPlaced = true;' + #10 +
    '            bestPlacedOrder = zOrder;' + #10 +
    '            bestPieceDist = pieceD;' + #10 +
    '            bestLocalT = localT;' + #10 +
    '            bestSampleUv = coverUv(pieceQ / grid, u_res, u_texResB);' + #10 +
    '          }' + #10 +
    '        }' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  // Vecchio sfondo con lieve traccia guida dei solchi puzzle (e copertura completa sotto le tessere bloccate)' + #10 +
    '  vec3 baseCol = colA * (1.0 - dropShadow);' + #10 +
    '  float guideGroove = smoothstep(0.026, 0.004, staticMinAbs) * traceLife * 0.24;' + #10 +
    '  baseCol = mix(baseCol, baseCol * 0.45 + vec3(0.18, 0.16, 0.13), guideGroove);' + #10 +
    '  baseCol = mix(baseCol, colB, clamp(lockedCoverage, 0.0, 1.0));' + #10 +
    '' + #10 +
    '  vec3 outCol = baseCol;' + #10 +
    '  if (hasPlaced) {' + #10 +
    '    vec3 tileCol = texture(u_texB, bestSampleUv).rgb;' + #10 +
    '    float edgeAbs = abs(bestPieceDist);' + #10 +
    '' + #10 +
    '    // Solco netto ed evidenziatura smussata lungo il contorno ad incastro finche'' non e'' completato' + #10 +
    '    float slotGroove = smoothstep(0.028, 0.004, edgeAbs) * traceLife;' + #10 +
    '    float bevelGlow = smoothstep(0.055, 0.015, edgeAbs) * (1.0 - slotGroove) * traceLife;' + #10 +
    '    tileCol = mix(tileCol, vec3(0.06, 0.07, 0.09), slotGroove * 0.82);' + #10 +
    '    tileCol += vec3(0.18, 0.15, 0.10) * bevelGlow * 0.45;' + #10 +
    '' + #10 +
    '    float antiAlias = (bestLocalT < 0.999) ? smoothstep(0.002, -0.008, bestPieceDist) : 1.0;' + #10 +
    '    float settleFlash = sin(bestLocalT * 3.14159265) * 0.08 * (1.0 - step(0.99, bestLocalT));' + #10 +
    '    outCol = mix(baseCol, tileCol + vec3(0.12, 0.10, 0.06) * settleFlash, antiAlias);' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  // Assicura la scomparsa totale di qualsiasi traccia delle giunzioni a completamento' + #10 +
    '  outCol = mix(outCol, colB, smoothstep(0.88, 0.96, p));' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_KALEIDO_PRISM_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  float p = clamp(u_progress, 0.0, 1.0);' + #10 +
    '  float activeMask = smoothstep(0.0, 0.06, p) * smoothstep(1.0, 0.92, p);' + #10 +
    '' + #10 +
    '  vec2 centered = (v_uv - 0.5) * vec2(aspect, 1.0);' + #10 +
    '  float r = length(centered);' + #10 +
    '  float ang = atan(centered.y, centered.x);' + #10 +
    '' + #10 +
    '  // Specchio caleidoscopico a 8 settori con torsione morbida' + #10 +
    '  float twist = sin(p * 3.14159265) * 0.72;' + #10 +
    '  float sectors = 8.0;' + #10 +
    '  float sectorAngle = 6.2831853 / sectors;' + #10 +
    '  float folded = mod(ang + twist, sectorAngle);' + #10 +
    '  folded = abs(folded - sectorAngle * 0.5);' + #10 +
    '' + #10 +
    '  float facetRing = floor(r * 6.5) * 0.12;' + #10 +
    '  vec2 kaleidoP = vec2(cos(folded + facetRing), sin(folded + facetRing)) * r;' + #10 +
    '  vec2 kaleidoUv = vec2(kaleidoP.x / aspect, kaleidoP.y) + 0.5;' + #10 +
    '' + #10 +
    '  float kStrength = pow(sin(p * 3.14159265), 1.35) * 0.85;' + #10 +
    '  vec2 sampleUvA = mix(v_uv, kaleidoUv, kStrength * 0.75);' + #10 +
    '  vec2 sampleUvB = mix(v_uv, kaleidoUv, kStrength * 0.62);' + #10 +
    '' + #10 +
    '  float chroma = 0.014 * activeMask * sin(p * 3.14159265);' + #10 +
    '  vec2 dir = normalize(centered + vec2(0.0001));' + #10 +
    '' + #10 +
    '  vec3 colA = vec3(' + #10 +
    '    texture(u_texA, coverUv(sampleUvA + dir * chroma, u_res, u_texResA)).r,' + #10 +
    '    texture(u_texA, coverUv(sampleUvA, u_res, u_texResA)).g,' + #10 +
    '    texture(u_texA, coverUv(sampleUvA - dir * chroma, u_res, u_texResA)).b' + #10 +
    '  );' + #10 +
    '  vec3 colB = vec3(' + #10 +
    '    texture(u_texB, coverUv(sampleUvB + dir * chroma, u_res, u_texResB)).r,' + #10 +
    '    texture(u_texB, coverUv(sampleUvB, u_res, u_texResB)).g,' + #10 +
    '    texture(u_texB, coverUv(sampleUvB - dir * chroma, u_res, u_texResB)).b' + #10 +
    '  );' + #10 +
    '' + #10 +
    '  // Onda radiale sfaccettata dal centro verso i bordi' + #10 +
    '  float crystalWave = r * 0.72 + abs(sin(ang * 4.0)) * 0.14 + fbm(centered * 5.0) * 0.14;' + #10 +
    '  float front = mix(-0.08, 1.12, p);' + #10 +
    '  float reveal = smoothstep(front + 0.09, front - 0.09, crystalWave);' + #10 +
    '' + #10 +
    '  float seam = smoothstep(0.025, 0.0, abs(folded - sectorAngle * 0.25)) * 0.35' + #10 +
    '             + smoothstep(0.09, 0.0, abs(crystalWave - front)) * 0.85;' + #10 +
    '' + #10 +
    '  vec3 outCol = mix(colA, colB, reveal);' + #10 +
    '  vec3 goldGlint = mix(vec3(0.96, 0.62, 0.14), vec3(0.24, 0.82, 0.86), 0.35);' + #10 +
    '  outCol += goldGlint * seam * 0.48 * activeMask;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_BIOLUMINESCENT_SPORES_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  vec2 p = vec2(v_uv.x * aspect, v_uv.y);' + #10 +
    '  float prog = clamp(u_progress, 0.0, 1.0);' + #10 +
    '  float activeMask = smoothstep(0.0, 0.05, prog) * smoothstep(1.0, 0.93, prog);' + #10 +
    '' + #10 +
    '  // Campo organico cellulare + turbolenza fluida' + #10 +
    '  vec2 swirl = vec2(' + #10 +
    '    fbm(p * 3.4 + vec2(u_time * 0.18, -u_time * 0.12)) - 0.5,' + #10 +
    '    fbm(p * 3.4 + vec2(-u_time * 0.14, u_time * 0.21)) - 0.5' + #10 +
    '  );' + #10 +
    '  vec2 cellPos = p * 3.6 + swirl * 0.75;' + #10 +
    '  vec2 n = floor(cellPos);' + #10 +
    '  vec2 f = fract(cellPos);' + #10 +
    '' + #10 +
    '  float minDist = 8.0;' + #10 +
    '  float cellRand = 0.0;' + #10 +
    '  for (int dy = -1; dy <= 1; dy++) {' + #10 +
    '    for (int dx = -1; dx <= 1; dx++) {' + #10 +
    '      vec2 g = vec2(float(dx), float(dy));' + #10 +
    '      vec2 id = n + g;' + #10 +
    '      vec2 pt = vec2(' + #10 +
    '        0.2 + 0.6 * hash21(id + vec2(3.1, 17.2)),' + #10 +
    '        0.2 + 0.6 * hash21(id + vec2(41.7, 9.5))' + #10 +
    '      );' + #10 +
    '      float d = length(g + pt - f);' + #10 +
    '      if (d < minDist) {' + #10 +
    '        minDist = d;' + #10 +
    '        cellRand = hash21(id);' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  float portalField = minDist * 0.72 + cellRand * 0.28 + (fbm(p * 8.0) - 0.5) * 0.14;' + #10 +
    '  float threshold = mix(0.08, 1.06, prog);' + #10 +
    '  float delta = portalField - threshold;' + #10 +
    '' + #10 +
    '  vec2 uvA = coverUv(v_uv + swirl * 0.025 * smoothstep(0.15, 0.0, delta) * activeMask, u_res, u_texResA);' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '' + #10 +
    '  vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '  vec3 colB = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  float reveal = smoothstep(0.035, -0.035, delta);' + #10 +
    '  vec3 outCol = mix(colA, colB, reveal);' + #10 +
    '' + #10 +
    '  // Alone bioluminescente e micro-spore attorno al bordo dei portali' + #10 +
    '  float halo = smoothstep(0.095, 0.0, abs(delta)) * activeMask;' + #10 +
    '  float sparkles = smoothstep(0.74, 0.96, noise2D(p * 28.0 + vec2(u_time * 0.6, -u_time * 0.9))) * halo;' + #10 +
    '  vec3 bioCol = mix(vec3(0.12, 0.88, 0.76), vec3(0.98, 0.72, 0.18), cellRand);' + #10 +
    '  outCol += bioCol * (halo * 0.55 + sparkles * 1.15);' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

  EMBED_SHATTERED_GLASS_FRAG =
    '#version 330 core' + #10 +
    'in vec2 v_uv;' + #10 +
    'out vec4 fragColor;' + #10 +
    '' + #10 +
    'uniform sampler2D u_texA;' + #10 +
    'uniform sampler2D u_texB;' + #10 +
    'uniform float u_progress;' + #10 +
    'uniform float u_time;' + #10 +
    'uniform vec2 u_res;' + #10 +
    'uniform vec2 u_texResA;' + #10 +
    'uniform vec2 u_texResB;' + #10 +
    '' + #10 +
    'vec2 coverUv(vec2 uv, vec2 screenRes, vec2 texRes) {' + #10 +
    '  float sRatio = screenRes.x / max(screenRes.y, 1.0);' + #10 +
    '  float tRatio = texRes.x / max(texRes.y, 1.0);' + #10 +
    '  vec2 scale = vec2(1.0);' + #10 +
    '  if (sRatio > tRatio) {' + #10 +
    '    scale.y = tRatio / sRatio;' + #10 +
    '  } else {' + #10 +
    '    scale.x = sRatio / tRatio;' + #10 +
    '  }' + #10 +
    '  return (uv - 0.5) * scale + 0.5;' + #10 +
    '}' + #10 +
    '' + #10 +
    'float hash21(vec2 p) {' + #10 +
    '  p = fract(p * vec2(123.34, 456.21));' + #10 +
    '  p += dot(p, p + 45.32);' + #10 +
    '  return fract(p.x * p.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float noise2D(vec2 p) {' + #10 +
    '  vec2 i = floor(p);' + #10 +
    '  vec2 f = fract(p);' + #10 +
    '  f = f * f * (3.0 - 2.0 * f);' + #10 +
    '  float a = hash21(i);' + #10 +
    '  float b = hash21(i + vec2(1.0, 0.0));' + #10 +
    '  float c = hash21(i + vec2(0.0, 1.0));' + #10 +
    '  float d = hash21(i + vec2(1.0, 1.0));' + #10 +
    '  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);' + #10 +
    '}' + #10 +
    '' + #10 +
    'float fbm(vec2 p) {' + #10 +
    '  float v = 0.0;' + #10 +
    '  float amp = 0.5;' + #10 +
    '  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);' + #10 +
    '  for (int i = 0; i < 5; i++) {' + #10 +
    '    v += amp * noise2D(p);' + #10 +
    '    p = rot * p * 2.04 + vec2(13.1, 7.7);' + #10 +
    '    amp *= 0.5;' + #10 +
    '  }' + #10 +
    '  return v;' + #10 +
    '}' + #10 +
    '' + #10 +
    'void sgCobwebCell(vec2 pt, out vec2 cellId, out float edgeDist) {' + #10 +
    '  float r = length(pt);' + #10 +
    '  float ang = atan(pt.y, pt.x);' + #10 +
    '  float pi2 = 6.2831853;' + #10 +
    '  float a01 = mod(ang + 3.14159265, pi2) / pi2;' + #10 +
    '' + #10 +
    '  float nRadial = (fbm(pt * 4.5 + vec2(2.3, 7.1)) - 0.5) * 0.042;' + #10 +
    '  float nSpoke = (fbm(pt * 5.2 + vec2(11.4, 3.8)) - 0.5) * 0.036;' + #10 +
    '' + #10 +
    '  float rWarp = max(r + nRadial, 0.0001);' + #10 +
    '  float ringCoord = pow(rWarp, 0.66) * 4.8;' + #10 +
    '  float ir = floor(ringCoord);' + #10 +
    '  float rf = fract(ringCoord);' + #10 +
    '' + #10 +
    '  float sectors = 14.0;' + #10 +
    '  float spokeRaw = a01 * sectors + (nSpoke / max(rWarp, 0.08)) * 0.45 + hash21(vec2(ir, 3.7)) * 0.18;' + #10 +
    '  float is = mod(floor(spokeRaw), sectors);' + #10 +
    '  float sf = fract(spokeRaw);' + #10 +
    '' + #10 +
    '  float ringScale = max(0.06, 0.30 * pow(rWarp, 0.34));' + #10 +
    '  float dRing = min(rf, 1.0 - rf) * ringScale;' + #10 +
    '  float dSpoke = min(sf, 1.0 - sf) * max(rWarp, 0.035) * (pi2 / sectors);' + #10 +
    '' + #10 +
    '  edgeDist = min(dRing, dSpoke);' + #10 +
    '  cellId = vec2(ir, is);' + #10 +
    '}' + #10 +
    '' + #10 +
    'void main() {' + #10 +
    '  float aspect = u_res.x / max(u_res.y, 1.0);' + #10 +
    '  float p = clamp(u_progress, 0.0, 1.0);' + #10 +
    '  float activeMask = smoothstep(0.0, 0.03, p) * smoothstep(1.0, 0.94, p);' + #10 +
    '' + #10 +
    '  vec2 q = (v_uv - 0.5) * vec2(aspect, 1.0);' + #10 +
    '  float radialSpread = smoothstep(0.0, 0.22, p) * 1.45;' + #10 +
    '  float impactShake = sin(clamp(p / 0.28, 0.0, 1.0) * 3.14159265) * activeMask;' + #10 +
    '  vec2 shakeOff = vec2(sin(u_time * 61.0), cos(u_time * 73.0)) * 0.006 * impactShake;' + #10 +
    '' + #10 +
    '  bool hitShard = false;' + #10 +
    '  float bestDepth = -99.0;' + #10 +
    '  vec2 bestOrigUv = v_uv;' + #10 +
    '  float bestEdge = 1.0;' + #10 +
    '  float bestFallT = 0.0;' + #10 +
    '  float bestCrackFront = 0.0;' + #10 +
    '  float crackShadow = 0.0;' + #10 +
    '' + #10 +
    '  for (int ir = 0; ir < 6; ir++) {' + #10 +
    '    float rIn = pow(float(ir) / 4.8, 1.515);' + #10 +
    '    float rOut = pow(float(ir + 1) / 4.8, 1.515);' + #10 +
    '    float rMid = 0.5 * (rIn + rOut);' + #10 +
    '    float maxBox = 0.24 + (rOut - rIn) * 0.75 + rOut * 0.28;' + #10 +
    '    float spokeShift = hash21(vec2(float(ir), 3.7)) * 0.18;' + #10 +
    '' + #10 +
    '    for (int is = 0; is < 14; is++) {' + #10 +
    '      vec2 cid = vec2(float(ir), float(is));' + #10 +
    '      float aMid = ((float(is) + 0.5 - spokeShift) / 14.0) * 6.2831853 - 3.14159265;' + #10 +
    '      vec2 center = vec2(cos(aMid), sin(aMid)) * rMid;' + #10 +
    '' + #10 +
    '      float rnd = hash21(cid + vec2(12.7, 39.1));' + #10 +
    '      float ringNorm = clamp(float(ir) / 5.0, 0.0, 1.0);' + #10 +
    '      float trigger = mix(0.10, 0.55, ringNorm * 0.62 + rnd * 0.38);' + #10 +
    '      float fallT = clamp((p - trigger) / 0.41, 0.0, 1.0);' + #10 +
    '      if (fallT >= 1.0) continue;' + #10 +
    '' + #10 +
    '      float dropY = pow(fallT, 1.85) * 1.45;' + #10 +
    '      float driftX = cos(aMid) * 0.16 * fallT + (rnd - 0.5) * 0.14 * fallT;' + #10 +
    '      float tilt = (rnd - 0.5) * 0.68 * fallT;' + #10 +
    '' + #10 +
    '      vec2 curCenter = center + vec2(driftX, dropY);' + #10 +
    '      if (abs(q.x - curCenter.x) > maxBox || abs(q.y - curCenter.y) > maxBox) continue;' + #10 +
    '' + #10 +
    '      vec2 rel = q - curCenter;' + #10 +
    '      float cs = cos(-tilt);' + #10 +
    '      float sn = sin(-tilt);' + #10 +
    '      vec2 origQ = center + vec2(rel.x * cs - rel.y * sn, rel.x * sn + rel.y * cs);' + #10 +
    '      vec2 origUv = vec2(origQ.x / aspect, origQ.y) + 0.5;' + #10 +
    '      if (origUv.x < 0.0 || origUv.x > 1.0 || origUv.y < 0.0 || origUv.y > 1.0) continue;' + #10 +
    '' + #10 +
    '      vec2 owner;' + #10 +
    '      float edgeDist;' + #10 +
    '      sgCobwebCell(origQ, owner, edgeDist);' + #10 +
    '      if (abs(owner.x - float(ir)) < 0.1 && abs(owner.y - float(is)) < 0.1) {' + #10 +
    '        float crackFront = smoothstep(radialSpread, radialSpread - 0.12, rMid) * smoothstep(0.0, 0.025, p);' + #10 +
    '        float crackGap = mix(0.0, 0.0085, crackFront) + fallT * 0.006;' + #10 +
    '        if (edgeDist > crackGap) {' + #10 +
    '          float depth = (1.0 - fallT) * 2.0 + rnd * 0.4;' + #10 +
    '          if (!hitShard || depth > bestDepth) {' + #10 +
    '            hitShard = true;' + #10 +
    '            bestDepth = depth;' + #10 +
    '            bestOrigUv = origUv + shakeOff * (1.0 - fallT * 0.7);' + #10 +
    '            bestEdge = edgeDist - crackGap;' + #10 +
    '            bestFallT = fallT;' + #10 +
    '            bestCrackFront = crackFront;' + #10 +
    '          }' + #10 +
    '        } else {' + #10 +
    '          crackShadow = max(crackShadow, crackFront);' + #10 +
    '        }' + #10 +
    '      }' + #10 +
    '    }' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  vec2 uvB = coverUv(v_uv, u_res, u_texResB);' + #10 +
    '  vec3 outCol = texture(u_texB, uvB).rgb;' + #10 +
    '' + #10 +
    '  // Brillio bianco-azzurro lungo le linee di frattura aperte sul nuovo sfondo' + #10 +
    '  outCol += vec3(0.82, 0.93, 1.0) * crackShadow * 0.55 * activeMask;' + #10 +
    '' + #10 +
    '  if (hitShard) {' + #10 +
    '    vec2 uvA = coverUv(clamp(bestOrigUv, 0.0, 1.0), u_res, u_texResA);' + #10 +
    '    vec3 colA = texture(u_texA, uvA).rgb;' + #10 +
    '' + #10 +
    '    // Bordo vetroso speculare sui frammenti crepati e in caduta' + #10 +
    '    float glassBevel = smoothstep(0.016, 0.0, bestEdge) * bestCrackFront;' + #10 +
    '    colA = mix(colA, vec3(0.86, 0.95, 1.0), glassBevel * 0.72 * activeMask);' + #10 +
    '    colA *= mix(1.0, 0.80, bestFallT * 0.55);' + #10 +
    '    outCol = colA;' + #10 +
    '  }' + #10 +
    '' + #10 +
    '  // Lampo dell''impatto della martellata al centro' + #10 +
    '  float centerImpact = exp(-length(q) * 11.0) * sin(clamp(p / 0.14, 0.0, 1.0) * 3.14159265) * activeMask;' + #10 +
    '  outCol += vec3(0.92, 0.97, 1.0) * centerImpact * 0.85;' + #10 +
    '' + #10 +
    '  fragColor = vec4(clamp(outCol, 0.0, 1.0), 1.0);' + #10 +
    '}' + #10 +
    '';

type
  TShaderEntry = record
    Name: string;
    ProgramId: GLuint;
  end;

var
  GShaders: array of TShaderEntry;
  GActiveShaderIdx: Integer = 0;
  GFadeShaderIdx: Integer = 0;
  GInitialized: Boolean = False;
  GHasTexA: Boolean = False;
  GHasTexB: Boolean = False;
  GVAO, GVBO: GLuint;
  GTexA, GTexB: GLuint;
  GTexW_A, GTexH_A, GTexW_B, GTexH_B: Single;
  GScreenW, GScreenH: Single;

function LoadOptionalOverride(const APath, AFallback: string): string;
var
  SL: TStringList;
begin
  if (APath <> '') and FileExists(APath) then
  begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(APath);
      Result := SL.Text;
      Exit;
    finally
      SL.Free;
    end;
  end;
  Result := AFallback;
end;

function CompileStage(AType: GLenum; const ASrc: string): GLuint;
var
  P: PChar;
  Ok: GLint;
begin
  Result := glCreateShader(AType);
  if Result = 0 then Exit;
  P := PChar(ASrc);
  glShaderSource(Result, 1, @P, nil);
  glCompileShader(Result);
  Ok := 0;
  glGetShaderiv(Result, GL_COMPILE_STATUS, @Ok);
  if Ok = 0 then
    WriteLn(StdErr, '[WallCycle GL] Shader compile warning/error for stage ', Ord(AType));
end;

function LinkProgramFromSource(const AVertSrc, AFragSrc: string): GLuint;
var
  VS, FS: GLuint;
begin
  VS := CompileStage(GL_VERTEX_SHADER, AVertSrc);
  FS := CompileStage(GL_FRAGMENT_SHADER, AFragSrc);
  Result := glCreateProgram();
  if (Result <> 0) and (VS <> 0) and (FS <> 0) then
  begin
    glAttachShader(Result, VS);
    glAttachShader(Result, FS);
    glLinkProgram(Result);
  end;
  if VS <> 0 then glDeleteShader(VS);
  if FS <> 0 then glDeleteShader(FS);
end;

procedure UploadBytesToTexture(const ATex: TShaderTextureData; ATexId: GLuint;
  out OW, OH: Single; out AHasTex: Boolean);
begin
  if (ATex.Width <= 0) or (ATex.Height <= 0) or (Length(ATex.RGB) < ATex.Width * ATex.Height * 3) then
    Exit;

  OW := ATex.Width;
  OH := ATex.Height;
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glBindTexture(GL_TEXTURE_2D, ATexId);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, ATex.Width, ATex.Height, 0,
    GL_RGB, GL_UNSIGNED_BYTE, @ATex.RGB[0]);
  AHasTex := True;
end;

procedure InitShaderEngine(AWidth, AHeight: Integer; const AShaderDir: string);
const
  Quad: array[0..7] of Single = (-1, -1,  1, -1,  -1, 1,  1, 1);
  Names: array[0..14] of string = (
    'fade', 'wipe', 'left', 'right', 'center',
    'film_burn', 'natural_wave', 'rain_melt', 'ink_dissolve', 'prism_wipe',
    'earthquake_collapse', 'puzzle_build', 'kaleido_prism', 'bioluminescent_spores',
    'shattered_glass'
  );
var
  I: Integer;
  VertSrc, FragSrc, BaseDir, VertOverride, FragOverride: string;
  Fallbacks: array[0..14] of string;
begin
  GScreenW := Max(1, AWidth);
  GScreenH := Max(1, AHeight);
  GHasTexA := False;
  GHasTexB := False;
  GTexW_A := GScreenW;
  GTexH_A := GScreenH;
  GTexW_B := GScreenW;
  GTexH_B := GScreenH;

  Fallbacks[0] := EMBED_FADE_FRAG;
  Fallbacks[1] := EMBED_WIPE_FRAG;
  Fallbacks[2] := EMBED_LEFT_FRAG;
  Fallbacks[3] := EMBED_RIGHT_FRAG;
  Fallbacks[4] := EMBED_CENTER_FRAG;
  Fallbacks[5] := EMBED_FILM_BURN_FRAG;
  Fallbacks[6] := EMBED_NATURAL_WAVE_FRAG;
  Fallbacks[7] := EMBED_RAIN_MELT_FRAG;
  Fallbacks[8] := EMBED_INK_DISSOLVE_FRAG;
  Fallbacks[9] := EMBED_PRISM_WIPE_FRAG;
  Fallbacks[10] := EMBED_EARTHQUAKE_COLLAPSE_FRAG;
  Fallbacks[11] := EMBED_PUZZLE_BUILD_FRAG;
  Fallbacks[12] := EMBED_KALEIDO_PRISM_FRAG;
  Fallbacks[13] := EMBED_BIOLUMINESCENT_SPORES_FRAG;
  Fallbacks[14] := EMBED_SHATTERED_GLASS_FRAG;

  glGenVertexArrays(1, @GVAO);
  glGenBuffers(1, @GVBO);
  glBindVertexArray(GVAO);
  glBindBuffer(GL_ARRAY_BUFFER, GVBO);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(Quad), @Quad[0], GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GLboolean(GL_FALSE), 2 * SizeOf(Single), nil);

  glGenTextures(1, @GTexA);
  glGenTextures(1, @GTexB);

  BaseDir := '';
  if AShaderDir <> '' then
    BaseDir := IncludeTrailingPathDelimiter(AShaderDir);

  if BaseDir <> '' then
    VertOverride := BaseDir + 'fullscreen.vert'
  else
    VertOverride := '';
  VertSrc := LoadOptionalOverride(VertOverride, EMBED_VERT_SRC);

  SetLength(GShaders, Length(Names));
  for I := 0 to High(Names) do
  begin
    GShaders[I].Name := Names[I];
    if BaseDir <> '' then
      FragOverride := BaseDir + Names[I] + '.frag'
    else
      FragOverride := '';
    FragSrc := LoadOptionalOverride(FragOverride, Fallbacks[I]);
    GShaders[I].ProgramId := LinkProgramFromSource(VertSrc, FragSrc);
  end;

  GFadeShaderIdx := 0;
  GActiveShaderIdx := 0;
  GInitialized := True;
end;

procedure UpdateShaderViewport(AWidth, AHeight: Integer);
begin
  GScreenW := Max(1, AWidth);
  GScreenH := Max(1, AHeight);
  if GInitialized then
    glViewport(0, 0, Round(GScreenW), Round(GScreenH));
end;

procedure SelectActiveShader(const AName: string);
var
  I: Integer;
begin
  for I := 0 to High(GShaders) do
    if GShaders[I].Name = AName then
    begin
      GActiveShaderIdx := I;
      Exit;
    end;
  GActiveShaderIdx := GFadeShaderIdx;
end;

procedure UploadTextureDataA(const ATex: TShaderTextureData);
begin
  if not GInitialized then Exit;
  UploadBytesToTexture(ATex, GTexA, GTexW_A, GTexH_A, GHasTexA);
  if not GHasTexB then
    UploadBytesToTexture(ATex, GTexB, GTexW_B, GTexH_B, GHasTexB);
end;

procedure UploadTextureDataB(const ATex: TShaderTextureData);
begin
  if not GInitialized then Exit;
  UploadBytesToTexture(ATex, GTexB, GTexW_B, GTexH_B, GHasTexB);
  if not GHasTexA then
    UploadBytesToTexture(ATex, GTexA, GTexW_A, GTexH_A, GHasTexA);
end;

procedure PromoteTextureBToA;
var
  TmpId: GLuint;
  TmpW, TmpH: Single;
begin
  if (not GInitialized) or (not GHasTexB) then Exit;
  TmpId := GTexA;
  GTexA := GTexB;
  GTexB := TmpId;

  TmpW := GTexW_A;
  GTexW_A := GTexW_B;
  GTexW_B := TmpW;

  TmpH := GTexH_A;
  GTexH_A := GTexH_B;
  GTexH_B := TmpH;

  GHasTexA := True;
end;

function HasTextureA: Boolean;
begin
  Result := GInitialized and GHasTexA;
end;

procedure DrawWithProgram(Prog: GLuint; AProgress, ATimeSec: Single);
begin
  if (not GInitialized) or (Prog = 0) or (not GHasTexA) then Exit;
  glUseProgram(Prog);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, GTexA);
  glUniform1i(glGetUniformLocation(Prog, 'u_texA'), 0);

  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, GTexB);
  glUniform1i(glGetUniformLocation(Prog, 'u_texB'), 1);

  glUniform1f(glGetUniformLocation(Prog, 'u_progress'), AProgress);
  glUniform1f(glGetUniformLocation(Prog, 'u_time'), ATimeSec);
  glUniform2f(glGetUniformLocation(Prog, 'u_res'), GScreenW, GScreenH);
  glUniform2f(glGetUniformLocation(Prog, 'u_texResA'), GTexW_A, GTexH_A);
  glUniform2f(glGetUniformLocation(Prog, 'u_texResB'), GTexW_B, GTexH_B);

  glBindVertexArray(GVAO);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
end;

procedure RenderStaticWallpaper;
begin
  if (not GInitialized) or (Length(GShaders) = 0) then Exit;
  DrawWithProgram(GShaders[GFadeShaderIdx].ProgramId, 0.0, 0.0);
end;

procedure RenderWallpaperFrame(AProgress, ATimeSec: Single);
begin
  if (not GInitialized) or (Length(GShaders) = 0) then Exit;
  DrawWithProgram(GShaders[GActiveShaderIdx].ProgramId, AProgress, ATimeSec);
end;

procedure ShutdownShaderEngine;
var
  I: Integer;
begin
  if not GInitialized then Exit;
  for I := 0 to High(GShaders) do
    if GShaders[I].ProgramId <> 0 then
      glDeleteProgram(GShaders[I].ProgramId);
  SetLength(GShaders, 0);
  if GTexA <> 0 then glDeleteTextures(1, @GTexA);
  if GTexB <> 0 then glDeleteTextures(1, @GTexB);
  if GVBO <> 0 then glDeleteBuffers(1, @GVBO);
  if GVAO <> 0 then glDeleteVertexArrays(1, @GVAO);
  GTexA := 0;
  GTexB := 0;
  GVBO := 0;
  GVAO := 0;
  GHasTexA := False;
  GHasTexB := False;
  GInitialized := False;
end;

end.
