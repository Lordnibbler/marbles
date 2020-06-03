void main() {
    // how fast to make background effect
    float speed = u_time * u_speed * 0.05; // current time value, speed passed in by swift
    
    // how strong to make bulging effect on screen
    float strength = u_strength / 100.0;
    
    // get current coordinate; dot we're modifying currently
    vec2 coord = v_tex_coord; // x and y coord of pixel in whole texture
    
    // modify pixel coordinate; move pixels around on screen to create ripple
    // circle effect smoothing using sine and cosine
    coord.x += sin((coord.x + speed) * u_frequency) * strength;
    coord.y += cos((coord.y + speed) * u_frequency) * strength;
    
    
    // read pixel in our texture at modifier position
    // then modify it by v_color_mix.a (keep it transparent)
    gl_FragColor = texture2D(u_texture, coord) * v_color_mix.a;
}
