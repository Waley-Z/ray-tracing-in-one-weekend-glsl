#include "common.glsl"

#iChannel0 "self"

#define LAMBERTIAN 0
#define METAL 1
#define DIELECTRIC 2

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

struct Material {
    vec3 albedo;
    int type;
    float var;  // For metal: fuzziness, for dielectric: refraction index
};

struct Sphere {
    vec3 center;
    float radius;
    Material mat;
};

struct HitRecord {
    vec3 p;
    vec3 normal;
    float t;
    bool front_face;
    Material mat;
};

bool near_zero(vec3 v) {
    const float s = 1e-8;
    return (abs(v.x) < s) && (abs(v.y) < s) && (abs(v.z) < s);
}

vec3 random_unit_vector() {
    return normalize(random_in_unit_sphere(g_seed));
}

float reflectance(float cosine, float ref_idx) {
    float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow((1.0 - cosine), 5.0);
}

bool material_scatter(Material mat, Ray r_in, HitRecord rec, out vec3 attenuation, out Ray scattered) {
    switch (mat.type) {
        case LAMBERTIAN: {
            vec3 scatter_direction = rec.normal + random_unit_vector();
            if (near_zero(scatter_direction))
                scatter_direction = rec.normal;

            scattered = Ray(rec.p, scatter_direction);
            attenuation = mat.albedo;
            return true;
        }
        case METAL: {
            vec3 reflected = reflect(normalize(r_in.direction), rec.normal);
            scattered = Ray(rec.p, reflected + mat.var * random_unit_vector());
            attenuation = mat.albedo;
            return dot(scattered.direction, rec.normal) > 0.0;
        }
        case DIELECTRIC: {
            attenuation = vec3(1.0);
            float refraction_ratio = rec.front_face ? (1.0 / mat.var) : mat.var;

            vec3 unit_direction = normalize(r_in.direction);
            float cos_theta = min(dot(-unit_direction, rec.normal), 1.0);
            float sin_theta = sqrt(1.0 - cos_theta * cos_theta);

            bool cannot_refract = refraction_ratio * sin_theta > 1.0 - 1e-7;
            vec3 direction;

            if (cannot_refract || reflectance(cos_theta, refraction_ratio) > rand1(g_seed))
                direction = reflect(unit_direction, rec.normal);
            else
                direction = refract(unit_direction, rec.normal, refraction_ratio);

            scattered = Ray(rec.p, direction);
            return true;
        }
        default: {
            return false;
        }
    }
}

const int MAX_SPHERES = 150;
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
    rec.mat = s.mat;

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

struct Camera {
    float image_width;
    float image_height;
    float aspect_ratio;
    vec3 center;
    vec3 pixel00_loc;
    vec3 pixel_delta_u;
    vec3 pixel_delta_v;
    int samples_per_pixel;
    int max_depth;
    float vfov;
    vec3 lookfrom;
    vec3 lookat;
    vec3 vup;
    vec3 u, v, w;
    float defocus_angle;
    float focus_dist;
    vec3 defocus_disk_u;
    vec3 defocus_disk_v;
};

void initialize_camera(out Camera cam) {
    cam.image_width = iResolution.x;
    cam.image_height = iResolution.y;
    cam.aspect_ratio = cam.image_width / cam.image_height;

    cam.center = cam.lookfrom;

    float theta = radians(cam.vfov);
    float h = tan(theta / 2.0);
    float viewport_height = 2.0 * h * cam.focus_dist;
    float viewport_width = cam.aspect_ratio * viewport_height;

    cam.w = normalize(cam.lookfrom - cam.lookat);
    cam.u = normalize(cross(cam.vup, cam.w));
    cam.v = cross(cam.w, cam.u);

    vec3 viewport_u = viewport_width * cam.u;
    vec3 viewport_v = viewport_height * (-cam.v);

    cam.pixel_delta_u = viewport_u / cam.image_width;
    cam.pixel_delta_v = viewport_v / cam.image_height;

    vec3 viewport_upper_left = cam.center - cam.focus_dist * cam.w - viewport_u / 2.0 - viewport_v / 2.0;
    cam.pixel00_loc = viewport_upper_left + 0.5 * (cam.pixel_delta_u + cam.pixel_delta_v);

    float defocus_radius = cam.focus_dist * tan(radians(cam.defocus_angle) / 2.0);
    cam.defocus_disk_u = cam.u * defocus_radius;
    cam.defocus_disk_v = cam.v * defocus_radius;
}

vec3 ray_color(Ray r, int max_depth) {
    vec3 accumulated_color = vec3(0.0);
    vec3 attenuation = vec3(1.0);

    for (int i = 0; i < max_depth; i++) {
        HitRecord rec;
        if (hit_world(r, Interval(0.001, 1.0 / 0.0), rec)) {
            Ray scattered;
            vec3 attenuation_out;
            if (material_scatter(rec.mat, r, rec, attenuation_out, scattered)) {
                attenuation *= attenuation_out;
                r = scattered;
            } else {
                break;
            }
        } else {
            // Background color
            vec3 unit_direction = normalize(r.direction);
            float a = 0.5 * (unit_direction.y + 1.0);
            vec3 background_color = (1.0 - a) * vec3(1.0, 1.0, 1.0) + a * vec3(0.5, 0.7, 1.0);
            accumulated_color += attenuation * background_color;
            break;
        }
    }
    return accumulated_color;
}

vec3 pixel_sample_square(Camera cam) {
    float px = -0.5 + rand1(g_seed);
    float py = -0.5 + rand1(g_seed);
    return px * cam.pixel_delta_u + py * cam.pixel_delta_v;
}

vec3 defocus_disk_sample(Camera cam) {
    vec2 p = random_in_unit_disk(g_seed);
    return cam.center + p.x * cam.defocus_disk_u + p.y * cam.defocus_disk_v;
}

Ray get_ray(Camera cam, float i, float j) {
    vec3 pixel_center = cam.pixel00_loc + i * cam.pixel_delta_u + j * cam.pixel_delta_v;
    vec3 pixel_sample = pixel_center + pixel_sample_square(cam);

    vec3 ray_origin = cam.defocus_angle <= 0.0 ? cam.center : defocus_disk_sample(cam);
    vec3 ray_direction = pixel_sample - ray_origin;
    return Ray(ray_origin, ray_direction);
}

void render_camera(Camera cam) {
    initialize_camera(cam);

    Ray ray = get_ray(cam, gl_FragCoord.x, cam.image_height - gl_FragCoord.y);
    vec3 pixel_color = ray_color(ray, cam.max_depth);

    vec3 pixel_color_buffer = texture(iChannel0, gl_FragCoord.xy / iResolution.xy).rgb;
    pixel_color_buffer = pow(pixel_color_buffer, vec3(2.2));
    float frame = float(iFrame) + 1.0;
    pixel_color = (pixel_color_buffer * (frame - 1.0) + pixel_color) / frame;
    pixel_color = clamp(pixel_color, 0.0, 1.0);

    pixel_color = pow(pixel_color, vec3(1.0 / 2.2));
    gl_FragColor = vec4(pixel_color, 1.0);
}

void main() {
////////////////////////////////////////////// 
//                  TASK 11                 //
    Material ground_material = Material(vec3(0.5), LAMBERTIAN, 0.0);
    spheres[num_spheres++] = Sphere(vec3(0.0, -1000.0, 0.0), 1000.0, ground_material);

    for (int a = -6; a < 6; a ++) {
        for (int b = -6; b < 6; b ++) {
            float choose_mat = rand1(g_seed);
            vec3 center = vec3(float(a) + 0.9 * rand1(g_seed), 0.2, float(b) + 0.9 * rand1(g_seed));

            if (length(center - vec3(4.0, 0.2, 0.0)) > 0.9) {
                Material sphere_material;

                if (choose_mat < 0.8) {
                    // Diffuse
                    vec3 albedo = vec3(rand1(g_seed) * rand1(g_seed), rand1(g_seed) * rand1(g_seed), rand1(g_seed) * rand1(g_seed));
                    sphere_material = Material(albedo, LAMBERTIAN, 0.0);
                } else if (choose_mat < 0.95) {
                    // Metal
                    vec3 albedo = vec3(0.5 * (1.0 + rand1(g_seed)), 0.5 * (1.0 + rand1(g_seed)), 0.5 * (1.0 + rand1(g_seed)));
                    float fuzz = 0.5 * rand1(g_seed);
                    sphere_material = Material(albedo, METAL, fuzz);
                } else {
                    // Glass
                    sphere_material = Material(vec3(1.0), DIELECTRIC, 1.5);
                }

                spheres[num_spheres++] = Sphere(center, 0.2, sphere_material);
            }
        }
    }

    Material material1 = Material(vec3(1.0), DIELECTRIC, 1.5);
    spheres[num_spheres++] = Sphere(vec3(0.0, 1.0, 0.0), 1.0, material1);

    Material material2 = Material(vec3(0.4, 0.2, 0.1), LAMBERTIAN, 0.0);
    spheres[num_spheres++] = Sphere(vec3(-4.0, 1.0, 0.0), 1.0, material2);

    Material material3 = Material(vec3(0.7, 0.6, 0.5), METAL, 0.0);
    spheres[num_spheres++] = Sphere(vec3(4.0, 1.0, 0.0), 1.0, material3);

    // Camera
    Camera cam;
    cam.samples_per_pixel = 100;
    cam.max_depth = 50;

    cam.vfov = 20.0;
    cam.lookfrom = vec3(13.0, 2.0, 3.0);
    cam.lookat = vec3(0.0, 0.0, 0.0);
    cam.vup = vec3(0.0, 1.0, 0.0);

    cam.defocus_angle = 0.6;
    cam.focus_dist = 10.0;

    // Render
    init_rand(gl_FragCoord.xy, iTime);
//                                          //
//////////////////////////////////////////////
    render_camera(cam);
}