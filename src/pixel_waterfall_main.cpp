#include "simplicity_engine.hpp"

#include <SDL3/SDL_main.h>

#include <cstdlib>
#include <cstring>
#include <iostream>

namespace {

bool parse_int(const char* value, int& output) {
    char* end = nullptr;
    const long parsed = std::strtol(value, &end, 10);
    if (end == value || *end != '\0') {
        return false;
    }
    output = static_cast<int>(parsed);
    return true;
}

bool parse_double(const char* value, double& output) {
    char* end = nullptr;
    const double parsed = std::strtod(value, &end);
    if (end == value || *end != '\0') {
        return false;
    }
    output = parsed;
    return true;
}

void print_usage(const char* executable) {
    std::cerr << "Usage: " << executable << " [--stdin-rows WIDTH HEIGHT] [--hue DEGREES] [--row-rate FPS]\n";
}

} // namespace

int main(int argc, char* argv[]) {
    bool read_stdin_rows = false;
    int width = 320;
    int height = 192;
    double hue_degrees = 210.0;
    double rows_per_second = 90.0;

    for (int index = 1; index < argc; ++index) {
        if (std::strcmp(argv[index], "--stdin-rows") == 0) {
            if (index + 2 >= argc ||
                !parse_int(argv[index + 1], width) ||
                !parse_int(argv[index + 2], height)) {
                print_usage(argv[0]);
                return 2;
            }
            read_stdin_rows = true;
            index += 2;
        } else if (std::strcmp(argv[index], "--hue") == 0) {
            if (index + 1 >= argc || !parse_double(argv[index + 1], hue_degrees)) {
                print_usage(argv[0]);
                return 2;
            }
            ++index;
        } else if (std::strcmp(argv[index], "--row-rate") == 0) {
            if (index + 1 >= argc || !parse_double(argv[index + 1], rows_per_second)) {
                print_usage(argv[0]);
                return 2;
            }
            ++index;
        } else if (std::strcmp(argv[index], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else {
            print_usage(argv[0]);
            return 2;
        }
    }

    if (read_stdin_rows) {
        return simplicity::run_pixel_waterfall_stream_app(width, height, hue_degrees, rows_per_second);
    }

    return simplicity::run_pixel_waterfall_demo_app();
}
