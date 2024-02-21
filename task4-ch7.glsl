#include "common.glsl"

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Interval {
    float min;
    float max;
};

bool interval_contains(Interval i, float x) {
    return i.min <= x && x <= i.max;
}

bool interval_surrounds(Interval i, float x) {
    return i.min < x && x < i.max;
}

struct Sphere {
    vec3 center;
    float radius;
};

struct HitRecord {
    vec3 p;
    vec3 normal;
    float t;
    bool front_face;
};

const int MAX_SPHERES = 10;
Sphere spheres[MAX_SPHERES];
int num_spheres = 0;

bool hit_sphere(Sphere s, Ray r, Interval ray_t, out HitRecord rec) {
    vec3 oc = r.origin - s.center;
    float a = dot(r.direction, r.direction);
    float half_b = dot(oc, r.direction);
    float c = dot(oc, oc) - s.radius * s.radius;

    float discriminant = half_b * half_b - a * c;
    if (discriminant < 0.0) {
        return false;
    }
    float sqrtd = sqrt(discriminant);

    float root = (-half_b - sqrtd) / a;
    if (!interval_surrounds(ray_t, root)) {
        root = (-half_b + sqrtd) / a;
        if (!interval_surrounds(ray_t, root)) {
            return false;
        }
    }

    rec.t = root;
    rec.p = r.origin + rec.t * r.direction;
    vec3 outward_normal = (rec.p - s.center) / s.radius;
    rec.front_face = dot(r.direction, outward_normal) < 0.0;
    rec.normal = rec.front_face ? outward_normal : -outward_normal;

    return true;
}

bool hit_world(Ray r, Interval ray_t, out HitRecord rec) {
    HitRecord temp_rec;
    bool hit_anything = false;
    float closest_so_far = ray_t.max;

    for (int i = 0; i < num_spheres; i++) {
        if (hit_sphere(spheres[i], r, Interval(ray_t.min, closest_so_far), temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }

    return hit_anything;
}

////////////////////////////////////////////// 
//                  TASK 4                  //
struct Camera {
    float image_width;
    float image_height;
    float aspect_ratio;
    vec3 center;
    vec3 pixel00_loc;
    vec3 pixel_delta_u;
    vec3 pixel_delta_v;
    int samples_per_pixel;
};

void initialize_camera(out Camera cam) {
    cam.image_width = iResolution.x;
    cam.image_height = iResolution.y;
    cam.aspect_ratio = cam.image_width / cam.image_height;

    cam.center = vec3(0.0, 0.0, 0.0);

    float focal_length = 1.0;
    float viewport_height = 2.0;
    float viewport_width = cam.aspect_ratio * viewport_height;

    vec3 viewport_u = vec3(viewport_width, 0.0, 0.0);
    vec3 viewport_v = vec3(0.0, -viewport_height, 0.0);

    cam.pixel_delta_u = viewport_u / cam.image_width;
    cam.pixel_delta_v = viewport_v / cam.image_height;

    vec3 viewport_upper_left = cam.center - vec3(0.0, 0.0, focal_length) - viewport_u / 2.0 - viewport_v / 2.0;
    cam.pixel00_loc = viewport_upper_left + 0.5 * (cam.pixel_delta_u + cam.pixel_delta_v);
}

vec3 ray_color(Ray r) {
    HitRecord rec;
    if (hit_world(r, Interval(0.0, 1.0 / 0.0), rec)) {
        return 0.5 * (rec.normal + vec3(1.0, 1.0, 1.0));
    }

    vec3 unit_direction = normalize(r.direction);
    float a = 0.5 * (unit_direction.y + 1.0);
    return (1.0 - a) * vec3(1.0, 1.0, 1.0) + a * vec3(0.5, 0.7, 1.0);
}

vec3 pixel_sample_square(Camera cam) {
    float px = -0.5 + rand1(g_seed);
    float py = -0.5 + rand1(g_seed);
    return px * cam.pixel_delta_u + py * cam.pixel_delta_v;
}

Ray get_ray(Camera cam, float i, float j) {
    vec3 pixel_center = cam.pixel00_loc + i * cam.pixel_delta_u + j * cam.pixel_delta_v;
    vec3 pixel_sample = pixel_center + pixel_sample_square(cam);

    vec3 ray_origin = cam.center;
    vec3 ray_direction = pixel_sample - ray_origin;
    return Ray(ray_origin, ray_direction);
}

void render_camera(Camera cam) {
    initialize_camera(cam);

    vec3 pixel_color = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < cam.samples_per_pixel; i++) {
        Ray ray = get_ray(cam, gl_FragCoord.x, cam.image_height - gl_FragCoord.y);
        pixel_color += ray_color(ray);
    }

    pixel_color /= float(cam.samples_per_pixel);
    gl_FragColor = vec4(pixel_color, 1.0);
}

void main() {
    init_rand(gl_FragCoord.xy, iTime);

    // World
    spheres[0] = Sphere(vec3(0.0, 0.0, -1.0), 0.5);
    spheres[1] = Sphere(vec3(0.0, -100.5, -1.0), 100.0);
    num_spheres = 2;

    // Camera
    Camera cam;
    cam.samples_per_pixel = 100;

    // Render
    render_camera(cam);
}
//                                          //
//////////////////////////////////////////////