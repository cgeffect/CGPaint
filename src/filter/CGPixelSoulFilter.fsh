precision highp float;

varying vec2 vTexCoord;
uniform sampler2D uTexture;
uniform float Time;

void main()
{
   float duration = 0.7;
   float maxAlpha = 0.4;
   float maxScale = 1.8;
   
   // 0~1
   float progress = mod(Time, duration) / duration;
   float alpha = maxAlpha * (1.0 - progress);
   float scale = 1.0 + (maxScale - 1.0) * progress;
   
   float weakX = 0.5 + (vTexCoord.x - 0.5) / scale;
   float weakY = 0.5 + (vTexCoord.y - 0.5) / scale;
   vec2 weakTextureCoords = vec2(weakX, weakY);
   
   vec4 weakMask = texture2D(uTexture, weakTextureCoords);
   
   vec4 mask = texture2D(uTexture, vTexCoord);
   
   gl_FragColor = mask * (1.0 - alpha) + weakMask * alpha;
}
