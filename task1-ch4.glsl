struct Ray {
    vec3 origin;
    vec3 direction;
};

vec4 ray_color(Ray r) {
    vec3 unit_direction = normalize(r.direction);
    float a = 0.5 * (unit_direction.y + 1.0);
    return vec4((1.0 - a) * vec3(1.0, 1.0, 1.0) + a * vec3(0.5, 0.7, 1.0), 1.0);
}

void main() {
    // Image
    float image_width = iResolution.x;
    float image_height = iResolution.y;
    float aspect_ratio = image_width / image_height;

    // Camera
    float focal_length = 1.0;
    float viewport_height = 2.0;
    float viewport_width = aspect_ratio * viewport_height;
    vec3 camera_center = vec3(0.0, 0.0, 0.0);

    vec3 viewport_u = vec3(viewport_width, 0.0, 0.0);
    vec3 viewport_v = vec3(0.0, -viewport_height, 0.0);

    vec3 pixel_delta_u = viewport_u / image_width;
    vec3 pixel_delta_v = viewport_v / image_height;

    vec3 viewport_upper_left = camera_center - vec3(0.0, 0.0, focal_length) - viewport_u / 2.0 - viewport_v / 2.0;
    vec3 pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

    // Render
    vec3 pixel_center = pixel00_loc + gl_FragCoord.x * pixel_delta_u + (image_height - gl_FragCoord.y) * pixel_delta_v;
    vec3 ray_direction = pixel_center - camera_center;
    Ray ray = Ray(camera_center, ray_direction);

    gl_FragColor = ray_color(ray);
}