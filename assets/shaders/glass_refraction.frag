#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;         // Размер плашки
uniform float uBlurAmount;  // Сила матового размытия
uniform sampler2D uTexture; // Текстура заднего фона

out vec4 fragColor;

void main() {
    vec2 st = FlutterFragCoord().xy / uSize;

    // 1. СИММЕТРИЧНОЕ ВЫТЯГИВАНИЕ СВЕРХУ И СНИЗУ
    // Рассчитываем удаление от центральной горизонтальной оси (y = 0.5)
    float distY = abs(st.y - 0.5) * 2.0; // 0.0 в центре, 1.0 на краях (сверху и снизу)
    
    // Эффект вытягивания усиливается ближе к верхнему и нижнему краю
    float pullFactor = pow(distY, 2.0) * 0.018; 
    
    // Направление смещения: верхняя половина тянется вверх, нижняя — вниз
    float directionY = sign(st.y - 0.5);
    vec2 distortedSt = vec2(st.x, st.y + directionY * pullFactor);

    // 2. МЯГКАЯ ДИСПЕРСИЯ (Хроматическая аберрация по краям)
    float dispersion = 0.006 * distY; // Спектр проявляется ближе к верхнему/нижнему краю
    
    vec2 uvR = vec2(distortedSt.x, distortedSt.y + dispersion);
    vec2 uvG = distortedSt;
    vec2 uvB = vec2(distortedSt.x, distortedSt.y - dispersion);

    // 3. FROSTED BLUR (5x5 Сэмплинг)
    vec2 texelSize = vec2(1.0) / uSize;
    float blurRadius = max(1.0, uBlurAmount * 0.4);

    float r = 0.0, g = 0.0, b = 0.0;
    float totalWeight = 0.0;

    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * texelSize * blurRadius;
            r += texture(uTexture, uvR + offset).r;
            g += texture(uTexture, uvG + offset).g;
            b += texture(uTexture, uvB + offset).b;
            totalWeight += 1.0;
        }
    }

    vec3 sceneColor = vec3(r / totalWeight, g / totalWeight, b / totalWeight);

    // 4. МЯГКИЙ СВЕТОВОЙ БЛИК НА ВЕРХНЕЙ И НИЖНЕЙ КРОМКЕ
    float edgeHighlight = pow(distY, 3.0) * 0.08;
    sceneColor += vec3(edgeHighlight);

    fragColor = vec4(sceneColor, 1.0);
}