#language slang 2026

import kitty_custom_shader_types;

// Fraction of the original color retained outside the active window (1.0 = unchanged, 0.0 = blend target).
static const float INACTIVE_DIM = 0.85;
// Blend target in linear RGB; black preserves the original dimming behavior.
static const float3 INACTIVE_DIM_COLOR = float3(0.0);
// Fraction of the way inactive pixels move toward the background color before
// dimming, like inactive_text_alpha: text loses contrast while the background
// keeps its brightness.
static const float INACTIVE_TEXT_FADE = 0.15;
// Progress at or above this counts as a finished fade, so APPLY shows the
// target directly and layout changes between fades still dim correctly.
static const float FADE_DONE = 0.95;

// Group indices in dim-inactive-windows.pipeline. STEP and STORE run only while
// the focus animation is active, so t.animation_progress follows the pipeline's
// animation_stop and animation_curve. Each pixel keeps its state in t.persist:
// r = dim level (0 = bright, 1 = dimmed), g = level when the current fade
// started, b = progress on the last frame. A group can't read the texture it
// writes, so STEP writes the new state to t.a and STORE copies it into t.persist.
static const int GROUP_STEP = 0;
static const int GROUP_STORE = 1;

float
dim_target(float2 pos, KittyCustomShaderData d) {
    // Keep the tab bar outside the effect.
    if (any(pos < d.central_area.xy) || any(pos > d.central_area.xy + d.central_area.zw)) return 0.0;
    float4 g = d.active_window_geometry;
    // Leave everything bright if no active window geometry is known.
    if (g.z <= 0.0 || g.w <= 0.0) return 0.0;
    // Include the active window's title bar and padding.
    g.xy -= d.active_window_padding.xy;
    g.zw += d.active_window_padding.xy + d.active_window_padding.zw;
    bool inWindow = all(pos >= g.xy) && all(pos <= g.xy + g.zw);
    return inWindow ? 0.0 : 1.0;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    if (t.group == GROUP_STEP) {
        float4 prev = saturate(t.persist.Sample(t.pos));
        float progress = t.animation_progress;
        // Progress going backwards means a new fade began: start it from the level shown now.
        float start = progress < prev.b ? prev.r : prev.g;
        float level = lerp(start, dim_target(t.pos, d), progress);
        return float4(level, start, progress, 1.0);
    }

    if (t.group == GROUP_STORE) return t.a.Sample(t.pos);

    float4 state = t.persist.Sample(t.pos);
    float level = state.b >= FADE_DONE ? dim_target(t.pos, d) : state.r;
    float3 faded = lerp(color.rgb, d.background.rgb, level * INACTIVE_TEXT_FADE);
    float dim = lerp(1.0, INACTIVE_DIM, level);
    return float4(lerp(INACTIVE_DIM_COLOR, faded, dim), color.a);
}
