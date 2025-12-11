#include <clap/clap.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "dsp.h"

#ifdef __cplusplus
extern "C" {
#endif

// Plugin features array (static to avoid MSVC compound literal issues)
static const char *s_plugin_features[] = {
    CLAP_PLUGIN_FEATURE_FILTER,
    CLAP_PLUGIN_FEATURE_AUDIO_EFFECT,
    CLAP_PLUGIN_FEATURE_STEREO,
    NULL
};

// Plugin descriptor
clap_plugin_descriptor_t s_plugin_desc = {
    .clap_version = CLAP_VERSION_INIT,
    .id = "com.flark.matrixfilter",
    .name = "flark's MatrixFilter",
    .vendor = "flark",
    .url = "https://flark.dev/matrixfilter",
    .manual_url = "https://flark.dev/matrixfilter/manual",
    .support_url = "https://flark.dev/matrixfilter/support",
    .version = "1.0.0",
    .description = "A versatile audio filter plugin supporting multiple filter types including low-pass, high-pass, band-pass, notch, peaking, and shelf filters.",
    .features = s_plugin_features,
};

// Parameter IDs
enum {
    PARAM_CUTOFF = 0,
    PARAM_RESONANCE = 1,
    PARAM_GAIN = 2,
    PARAM_TYPE = 3,
    PARAM_ENABLED = 4
};

// Plugin structure
typedef struct {
    clap_plugin_t plugin;
    const clap_host_t *host;
    
    // Host extensions
    const clap_host_log_t *host_log;
    const clap_host_thread_check_t *host_thread_check;
    const clap_host_params_t *host_params;
    const clap_host_state_t *host_state;
    const clap_host_latency_t *host_latency;
    
    // Plugin state
    filter_t filter;
    bool enabled;
    
    // Parameter values
    float cutoff_freq;
    float resonance;
    float gain;
    filter_type_t filter_type;
    
    // Sample rate
    float sample_rate;
    
    // Temporary buffers
    float *temp_buffer;
    uint32_t temp_buffer_size;
} audio_filter_plugin_t;

// Plugin extensions (defined in plugin-extensions.cpp)
extern clap_plugin_params_t s_plugin_params;
extern clap_plugin_state_t s_plugin_state;
extern clap_plugin_latency_t s_plugin_latency;
extern clap_plugin_audio_ports_t s_plugin_audio_ports;
extern clap_plugin_ambisonic_t s_plugin_ambisonic;
extern clap_plugin_surround_t s_plugin_surround;
extern clap_plugin_gui_t s_plugin_gui;

// Forward declarations
static void destroy(audio_filter_plugin_t *plugin);
static bool init(audio_filter_plugin_t *plugin);
static void deactivate(audio_filter_plugin_t *plugin);
static bool start_processing(audio_filter_plugin_t *plugin);
static void stop_processing(audio_filter_plugin_t *plugin);
static void reset(audio_filter_plugin_t *plugin);
static clap_process_status process(audio_filter_plugin_t *plugin, const clap_process_t *process_data);
static const void *get_extension(const audio_filter_plugin_t *plugin, const char *id);
static void on_main_thread(audio_filter_plugin_t *plugin);
static void update_filter_parameters(audio_filter_plugin_t *plugin);

// Plugin wrapper function declarations
static bool audio_filter_activate(const clap_plugin_t *plugin, double sample_rate, uint32_t min_frames_count, uint32_t max_frames_count);

// Plugin methods
static void audio_filter_destroy(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    destroy(p);
}

static bool audio_filter_init(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    return init(p);
}

static void audio_filter_deactivate(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    deactivate(p);
}

static bool audio_filter_start_processing(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    return start_processing(p);
}

static void audio_filter_stop_processing(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    stop_processing(p);
}

static void audio_filter_reset(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    reset(p);
}

static clap_process_status audio_filter_process(const clap_plugin_t *plugin, const clap_process_t *process_data) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    return process(p, process_data);
}

static const void *audio_filter_get_extension(const clap_plugin_t *plugin, const char *id) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    return get_extension(p, id);
}

static void audio_filter_on_main_thread(const clap_plugin_t *plugin) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    on_main_thread(p);
}

// Plugin implementation
static void destroy(audio_filter_plugin_t *plugin) {
    if (plugin->temp_buffer) {
        free(plugin->temp_buffer);
        plugin->temp_buffer = NULL;
    }
    free(plugin);
}

static bool init(audio_filter_plugin_t *plugin) {
    // Initialize DSP
    filter_init(&plugin->filter, plugin->filter_type, plugin->cutoff_freq, plugin->resonance, plugin->gain, plugin->sample_rate);
    
    // Allocate temporary buffer for processing
    plugin->temp_buffer_size = 0;
    plugin->temp_buffer = NULL;
    
    return true;
}

static void deactivate(audio_filter_plugin_t *plugin) {
    // Clean up any allocated resources
    if (plugin->temp_buffer) {
        free(plugin->temp_buffer);
        plugin->temp_buffer = NULL;
        plugin->temp_buffer_size = 0;
    }
}

static bool start_processing(audio_filter_plugin_t *plugin) {
    return true;
}

static void stop_processing(audio_filter_plugin_t *plugin) {
    // Nothing to do
}

static void reset(audio_filter_plugin_t *plugin) {
    filter_reset(&plugin->filter);
}

static void update_filter_parameters(audio_filter_plugin_t *plugin) {
    filter_set_parameters(&plugin->filter, plugin->filter_type, plugin->cutoff_freq, plugin->resonance, plugin->gain);
    filter_set_sample_rate(&plugin->filter, plugin->sample_rate);
}

static clap_process_status process(audio_filter_plugin_t *plugin, const clap_process_t *process_data) {
    const uint32_t nframes = process_data->frames_count;

    // Handle events
    uint32_t num_events = process_data->in_events->size(process_data->in_events);
    for (uint32_t i = 0; i < num_events; ++i) {
        const clap_event_header_t *event = process_data->in_events->get(process_data->in_events, i);
        
        if (event->type == CLAP_EVENT_PARAM_VALUE) {
            const clap_event_param_value_t *param_event = (const clap_event_param_value_t *)event;
            switch (param_event->param_id) {
                case PARAM_CUTOFF:
                    plugin->cutoff_freq = param_event->value;
                    update_filter_parameters(plugin);
                    break;
                case PARAM_RESONANCE:
                    plugin->resonance = param_event->value;
                    update_filter_parameters(plugin);
                    break;
                case PARAM_GAIN:
                    plugin->gain = param_event->value;
                    update_filter_parameters(plugin);
                    break;
                case PARAM_TYPE:
                    plugin->filter_type = (filter_type_t)param_event->value;
                    update_filter_parameters(plugin);
                    break;
                case PARAM_ENABLED:
                    plugin->enabled = param_event->value > 0.5f;
                    break;
            }
        }
    }
    
    // Process audio
    if (process_data->audio_inputs_count >= 1 && process_data->audio_outputs_count >= 1) {
        const clap_audio_buffer_t *input = &process_data->audio_inputs[0];
        clap_audio_buffer_t *output = &process_data->audio_outputs[0];
        
        // Ensure we have enough buffer space
        if (plugin->temp_buffer_size < nframes) {
            if (plugin->temp_buffer) {
                free(plugin->temp_buffer);
            }
            plugin->temp_buffer = (float *)malloc(nframes * sizeof(float));
            plugin->temp_buffer_size = nframes;
        }
        
        if (plugin->enabled && input->data32 && output->data32) {
            // Process each channel
            for (uint32_t ch = 0; ch < output->channel_count; ++ch) {
                if (ch < input->channel_count && input->data32[ch] && output->data32[ch]) {
                    if (plugin->filter.initialized) {
                        filter_process_block(&plugin->filter, input->data32[ch], output->data32[ch], nframes);
                    } else {
                        // Just copy if filter not initialized
                        memcpy(output->data32[ch], input->data32[ch], nframes * sizeof(float));
                    }
                }
            }
            
            // Copy first channel audio for visualization (if not already copied)
            if (input->data32[0] && plugin->temp_buffer) {
                memcpy(plugin->temp_buffer, input->data32[0], nframes * sizeof(float));
            }
        } else if (!plugin->enabled && input->data32 && output->data32) {
            // Bypass - copy input to output
            for (uint32_t ch = 0; ch < output->channel_count; ++ch) {
                if (ch < input->channel_count && input->data32[ch] && output->data32[ch]) {
                    memcpy(output->data32[ch], input->data32[ch], nframes * sizeof(float));
                }
            }
            
            // Copy first channel audio for visualization (if not already copied)
            if (input->data32[0] && plugin->temp_buffer) {
                memcpy(plugin->temp_buffer, input->data32[0], nframes * sizeof(float));
            }
        }
    }
    
    return CLAP_PROCESS_CONTINUE;
}

static const void *get_extension(const audio_filter_plugin_t *plugin, const char *id) {
    if (!strcmp(id, CLAP_EXT_PARAMS)) {
        return &s_plugin_params;
    }
    if (!strcmp(id, CLAP_EXT_STATE)) {
        return &s_plugin_state;
    }
    if (!strcmp(id, CLAP_EXT_LATENCY)) {
        return &s_plugin_latency;
    }
    if (!strcmp(id, CLAP_EXT_AUDIO_PORTS)) {
        return &s_plugin_audio_ports;
    }
    if (!strcmp(id, CLAP_EXT_SURROUND)) {
        return &s_plugin_surround;
    }
    if (!strcmp(id, CLAP_EXT_AMBISONIC)) {
        return &s_plugin_ambisonic;
    }
    if (!strcmp(id, CLAP_EXT_GUI)) {
        return &s_plugin_gui;
    }
    
    return NULL;
}

static void on_main_thread(audio_filter_plugin_t *plugin) {
    // Main thread callback - can be used for GUI updates or deferred operations
    // Sample rate is set via the activate() callback
    (void)plugin; // Unused for now
}

// Export plugin functions
clap_plugin_t *audio_filter_plugin_create(const clap_host_t *host) {
    audio_filter_plugin_t *plugin = (audio_filter_plugin_t *)calloc(1, sizeof(audio_filter_plugin_t));
    if (!plugin) {
        return NULL;
    }
    
    // Initialize default parameters
    plugin->host = host;
    plugin->cutoff_freq = 1000.0f;      // 1 kHz
    plugin->resonance = 1.0f;           // Q = 1
    plugin->gain = 0.0f;                // 0 dB
    plugin->filter_type = FILTER_TYPE_LOWPASS;
    plugin->enabled = true;
    plugin->sample_rate = 44100.0f;     // Default sample rate
    
    // Initialize filter
    filter_init(&plugin->filter, plugin->filter_type, plugin->cutoff_freq, plugin->resonance, plugin->gain, plugin->sample_rate);
    
    // Set plugin structure
    plugin->plugin.desc = &s_plugin_desc;
    plugin->plugin.plugin_data = plugin;
    plugin->plugin.init = audio_filter_init;
    plugin->plugin.destroy = audio_filter_destroy;
    plugin->plugin.activate = audio_filter_activate;
    plugin->plugin.deactivate = audio_filter_deactivate;
    plugin->plugin.start_processing = audio_filter_start_processing;
    plugin->plugin.stop_processing = audio_filter_stop_processing;
    plugin->plugin.reset = audio_filter_reset;
    plugin->plugin.process = audio_filter_process;
    plugin->plugin.get_extension = audio_filter_get_extension;
    plugin->plugin.on_main_thread = audio_filter_on_main_thread;
    
    return &plugin->plugin;
}

// Activation function
static bool audio_filter_activate(const clap_plugin_t *plugin, double sample_rate, uint32_t min_frames_count, uint32_t max_frames_count) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    p->sample_rate = (float)sample_rate;
    update_filter_parameters(p);
    return true;
}

// Parameter information
clap_param_info_t s_param_info[] = {
    {
        .id = PARAM_CUTOFF,
        .flags = CLAP_PARAM_IS_AUTOMATABLE,
        .cookie = NULL,
        .name = "Cutoff Frequency",
        .module = "",
        .min_value = 20.0,
        .max_value = 20000.0,
        .default_value = 1000.0,
    },
    {
        .id = PARAM_RESONANCE,
        .flags = CLAP_PARAM_IS_AUTOMATABLE,
        .cookie = NULL,
        .name = "Resonance",
        .module = "",
        .min_value = 0.1,
        .max_value = 10.0,
        .default_value = 1.0,
    },
    {
        .id = PARAM_GAIN,
        .flags = CLAP_PARAM_IS_AUTOMATABLE,
        .cookie = NULL,
        .name = "Gain",
        .module = "",
        .min_value = -60.0,
        .max_value = 60.0,
        .default_value = 0.0,
    },
    {
        .id = PARAM_TYPE,
        .flags = CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_STEPPED,
        .cookie = NULL,
        .name = "Filter Type",
        .module = "",
        .min_value = 0.0,
        .max_value = 6.0,
        .default_value = 0.0,
    },
    {
        .id = PARAM_ENABLED,
        .flags = CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_STEPPED,
        .cookie = NULL,
        .name = "Enabled",
        .module = "",
        .min_value = 0.0,
        .max_value = 1.0,
        .default_value = 1.0,
    }
};

#ifdef __cplusplus
}
#endif
