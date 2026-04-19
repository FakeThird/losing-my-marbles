shader_type canvas_item;

uniform vec4 chroma_key : source_color = vec4(0.733, 0.871, 0.984, 1.0);
uniform float precision : hint_range(0.0, 1.0) = 0.05;

void fragment() {
    vec4 rgba = texture(TEXTURE, UV);
    // Calculate how close the current pixel is to our background color
    float diff = distance(rgba.rgb, chroma_key.rgb);
    
    if (diff < precision) {
        discard; // This removes the pixel entirely
    }
    
    COLOR = rgba;
}