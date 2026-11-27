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
    '  float threshold = mix(-0.14, 1.18, smoothstep(0.0, 1.0, u_progress));' + #10 +
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
    '  float frontPos = mix(-0.18, 1.20, smoothstep(0.0, 1.0, u_progress));' + #10 +
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
    '  float threshold = mix(-0.10, 1.12, smoothstep(0.0, 1.0, u_progress));' + #10 +
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
    '  float threshold = mix(-0.08, 1.08, smoothstep(0.0, 1.0, u_progress));' + #10 +
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
    '  float front = mix(-0.12, 1.12, smoothstep(0.0, 1.0, u_progress));' + #10 +
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
  Names: array[0..9] of string = (
    'fade', 'wipe', 'left', 'right', 'center',
    'film_burn', 'natural_wave', 'rain_melt', 'ink_dissolve', 'prism_wipe'
  );
var
  I: Integer;
  VertSrc, FragSrc, BaseDir, VertOverride, FragOverride: string;
  Fallbacks: array[0..9] of string;
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
