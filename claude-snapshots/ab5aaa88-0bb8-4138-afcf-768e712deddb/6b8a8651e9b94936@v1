#include "gui.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Matrix initialization
void matrix_init(gui_context_t *gui) {
    srand((unsigned int)time(NULL));
    
    for (int i = 0; i < MATRIX_WIDTH; ++i) {
        gui->columns[i].x = i;
        gui->columns[i].y = -rand() % MATRIX_HEIGHT;
        gui->columns[i].speed = 0.5f + (rand() % 100) / 100.0f;
        gui->columns[i].current_char = MATRIX_CHARS[rand() % (sizeof(MATRIX_CHARS) - 1)];
        gui->columns[i].brightness = 0.0f;
        gui->columns[i].target_brightness = 0.0f;
    }
    
    gui->time_accumulator = 0.0f;
}

// Update matrix animation
void matrix_update(gui_context_t *gui, float delta_time) {
    gui->time_accumulator += delta_time;
    
    for (int i = 0; i < MATRIX_WIDTH; ++i) {
        matrix_column_t *col = &gui->columns[i];
        
        // Update position
        col->y += col->speed * delta_time * 60.0f; // Normalize to 60fps
        
        // Reset when off screen
        if (col->y >= MATRIX_HEIGHT) {
            col->y = -1;
            col->speed = 0.5f + (rand() % 100) / 100.0f;
            col->current_char = MATRIX_CHARS[rand() % (sizeof(MATRIX_CHARS) - 1)];
        }
        
        // Update brightness based on spectrum data
        if (gui->spectrum.spectrum[0] > 0.01f) {
            float normalized_freq = (float)i / (float)MATRIX_WIDTH;
            uint32_t spectrum_index = (uint32_t)(normalized_freq * (MAX_FREQUENCY_BINS - 1));
            col->target_brightness = gui->spectrum.spectrum[spectrum_index] * 2.0f;
        } else {
            col->target_brightness = 0.0f;
        }
        
        // Smooth brightness transition
        col->brightness += (col->target_brightness - col->brightness) * 0.1f;
        
        // Change character occasionally
        if (col->brightness > 0.5f && ((rand() % 1000) == 0)) {
            col->current_char = MATRIX_CHARS[rand() % (sizeof(MATRIX_CHARS) - 1)];
        }
    }
}

// Spectrum analyzer initialization
void spectrum_init(spectrum_analyzer_t *spectrum) {
    memset(spectrum, 0, sizeof(spectrum_analyzer_t));
    spectrum->sample_count = 0;
}

// Simple FFT (Fast Fourier Transform) implementation
static void fft_r2(float *real, float *imag, int n) {
    if (n <= 1) return;
    
    // Bit reversal
    for (int i = 1, j = 0; i < n; i++) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) {
            j ^= bit;
        }
        j ^= bit;
        
        if (i < j) {
            float temp = real[i];
            real[i] = real[j];
            real[j] = temp;
            temp = imag[i];
            imag[i] = imag[j];
            imag[j] = temp;
        }
    }
    
    // FFT computation
    for (int len = 2; len <= n; len <<= 1) {
        float ang = -2.0f * M_PI / len;
        float wlen_real = cosf(ang);
        float wlen_imag = sinf(ang);
        
        for (int i = 0; i < n; i += len) {
            float w_real = 1.0f;
            float w_imag = 0.0f;
            
            for (int j = 0; j < len / 2; j++) {
                float u_real = real[i + j];
                float u_imag = imag[i + j];
                float v_real = real[i + j + len / 2] * w_real - imag[i + j + len / 2] * w_imag;
                float v_imag = real[i + j + len / 2] * w_imag + imag[i + j + len / 2] * w_real;
                
                real[i + j] = u_real + v_real;
                imag[i + j] = u_imag + v_imag;
                real[i + j + len / 2] = u_real - v_real;
                imag[i + j + len / 2] = u_imag - v_imag;
                
                float temp_real = w_real * wlen_real - w_imag * wlen_imag;
                float temp_imag = w_real * wlen_imag + w_imag * wlen_real;
                w_real = temp_real;
                w_imag = temp_imag;
            }
        }
    }
}

// Analyze audio spectrum
void spectrum_analyze(spectrum_analyzer_t *spectrum, const float *audio_data, uint32_t frames) {
    if (frames < MAX_FREQUENCY_BINS) return;
    
    // Use Hamming window
    static float window[MAX_FREQUENCY_BINS];
    static bool window_initialized = false;
    
    if (!window_initialized) {
        for (int i = 0; i < MAX_FREQUENCY_BINS; i++) {
            window[i] = 0.54f - 0.46f * cosf(2.0f * M_PI * i / (MAX_FREQUENCY_BINS - 1));
        }
        window_initialized = true;
    }
    
    // Prepare data for FFT
    float real[MAX_FREQUENCY_BINS];
    float imag[MAX_FREQUENCY_BINS];
    
    for (int i = 0; i < MAX_FREQUENCY_BINS; i++) {
        real[i] = audio_data[i] * window[i];
        imag[i] = 0.0f;
    }
    
    // Perform FFT
    fft_r2(real, imag, MAX_FREQUENCY_BINS);
    
    // Calculate magnitude spectrum
    for (int i = 0; i < MAX_FREQUENCY_BINS / 2; i++) {
        float magnitude = sqrtf(real[i] * real[i] + imag[i] * imag[i]) / MAX_FREQUENCY_BINS;
        spectrum->spectrum[i] = magnitude;
    }
    
    // Apply some smoothing
    for (int i = 0; i < MAX_FREQUENCY_BINS / 2; i++) {
        if (i > 0) {
            spectrum->spectrum[i] = (spectrum->spectrum[i] * 0.7f) + (spectrum->spectrum[i-1] * 0.3f);
        }
    }
}

// Update peak values for decay effect
void spectrum_update_peaks(spectrum_analyzer_t *spectrum) {
    for (int i = 0; i < MAX_FREQUENCY_BINS / 2; i++) {
        if (spectrum->spectrum[i] > spectrum->peak_values[i]) {
            spectrum->peak_values[i] = spectrum->spectrum[i];
        } else {
            spectrum->peak_values[i] *= 0.95f; // Decay
        }
    }
}

// Handle audio data from plugin
void gui_handle_audio_data(gui_context_t *gui, const float *audio_data, uint32_t frames) {
    pthread_mutex_lock(&gui->mutex);
    
    if (frames >= MAX_FREQUENCY_BINS) {
        spectrum_analyze(&gui->spectrum, audio_data, frames);
        spectrum_update_peaks(&gui->spectrum);
    }
    
    pthread_mutex_unlock(&gui->mutex);
}

// OpenGL initialization
void opengl_init() {
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

// Setup orthographic projection
void opengl_setup_projection(uint32_t width, uint32_t height) {
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, MATRIX_WIDTH, 0, MATRIX_HEIGHT, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glViewport(0, 0, width, height);
}

// Clear screen with dark background
void opengl_clear_screen() {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
}

// Draw a single character in matrix style
void opengl_draw_character(float x, float y, float size, char c, float brightness) {
    if (brightness <= 0.01f) return;
    
    // Matrix green color with brightness
    float alpha = brightness;
    float r = 0.0f, g = alpha, b = 0.0f;
    
    glColor4f(r, g, b, alpha);
    
    // Simple bitmap font rendering
    glBegin(GL_QUADS);
    glVertex2f(x, y);
    glVertex2f(x + size, y);
    glVertex2f(x + size, y + size);
    glVertex2f(x, y + size);
    glEnd();
    
    // Add glow effect
    if (brightness > 0.3f) {
        glColor4f(r * 0.5f, g * 0.5f, b * 0.5f, alpha * 0.3f);
        for (int i = 1; i <= 2; i++) {
            glBegin(GL_QUADS);
            glVertex2f(x - i*0.1f, y - i*0.1f);
            glVertex2f(x + size + i*0.1f, y - i*0.1f);
            glVertex2f(x + size + i*0.1f, y + size + i*0.1f);
            glVertex2f(x - i*0.1f, y + size + i*0.1f);
            glEnd();
        }
    }
}

// Render the matrix visualization
void matrix_render(gui_context_t *gui) {
    opengl_clear_screen();
    
    float cell_size = 1.0f;
    
    for (int i = 0; i < MATRIX_WIDTH; ++i) {
        matrix_column_t *col = &gui->columns[i];
        
        if (col->y >= 0 && col->y < MATRIX_HEIGHT) {
            int y_pos = (int)col->y;
            
            // Draw trailing characters for glow effect
            for (int trail = 0; trail < 5; trail++) {
                float trail_y = y_pos - trail * 0.8f;
                float trail_brightness = col->brightness * (1.0f - trail * 0.2f);
                
                if (trail_y >= 0 && trail_y < MATRIX_HEIGHT) {
                    opengl_draw_character(col->x, trail_y, cell_size * 0.8f, 
                                        col->current_char, trail_brightness);
                }
            }
        }
    }
}

// GUI creation
bool gui_create(gui_context_t *gui, const clap_plugin_t *plugin, uint32_t width, uint32_t height) {
    memset(gui, 0, sizeof(gui_context_t));
    
    gui->width = width;
    gui->height = height;
    gui->plugin = plugin;
    
    if (pthread_mutex_init(&gui->mutex, NULL) != 0) {
        return false;
    }
    
    // Initialize components
    matrix_init(gui);
    spectrum_init(&gui->spectrum);
    
    gui->running = true;
    
    printf("GUI created: %dx%d\n", width, height);
    return true;
}

// GUI destruction
void gui_destroy(gui_context_t *gui) {
    gui->running = false;
    pthread_mutex_destroy(&gui->mutex);
}

// Update GUI with audio buffer
void gui_update(gui_context_t *gui, const float *audio_buffer, uint32_t frames, double sample_rate) {
    if (!gui->running) return;
    
    // Update matrix animation
    matrix_update(gui, 1.0f / 60.0f); // Assume 60fps
    
    // Store audio data for processing
    if (audio_buffer && frames > 0) {
        static float *audio_copy = NULL;
        static uint32_t audio_copy_size = 0;
        
        if (audio_copy_size < frames) {
            if (audio_copy) free(audio_copy);
            audio_copy = (float *)malloc(frames * sizeof(float));
            audio_copy_size = frames;
        }
        
        if (audio_copy) {
            memcpy(audio_copy, audio_buffer, frames * sizeof(float));
            gui_handle_audio_data(gui, audio_copy, frames);
        }
    }
}

// Render GUI
void gui_render(gui_context_t *gui) {
    matrix_render(gui);
}