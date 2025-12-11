#include <stdio.h>
#include <string.h>
#include <math.h>
#include "plugin.h"
#include "dsp.h"
#include <clap/ext/params.h>
#include <clap/ext/state.h>
#include <clap/ext/latency.h>
#include <clap/ext/audio-ports.h>
#include <clap/ext/surround.h>
#include <clap/ext/ambisonic.h>
#include <clap/ext/gui.h>

// Windows compatibility
#ifdef _WIN32
#define strcasecmp _stricmp
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Parameter IDs (from plugin.cpp)
enum {
    PARAM_CUTOFF = 0,
    PARAM_RESONANCE = 1,
    PARAM_GAIN = 2,
    PARAM_TYPE = 3,
    PARAM_ENABLED = 4
};

// Plugin structure (from plugin.cpp)
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

#define PARAM_COUNT 5

// Parameter extension implementation
static uint32_t audio_filter_count_params(const clap_plugin_t *plugin) {
    return PARAM_COUNT;
}

static bool audio_filter_get_param_info(const clap_plugin_t *plugin, uint32_t param_index, clap_param_info_t *info) {
    if (param_index >= PARAM_COUNT) {
        return false;
    }

    memcpy(info, &s_param_info[param_index], sizeof(clap_param_info_t));
    return true;
}

static bool audio_filter_get_param_value(const clap_plugin_t *plugin, clap_id param_id, double *value) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    
    switch (param_id) {
        case PARAM_CUTOFF:
            *value = p->cutoff_freq;
            return true;
        case PARAM_RESONANCE:
            *value = p->resonance;
            return true;
        case PARAM_GAIN:
            *value = p->gain;
            return true;
        case PARAM_TYPE:
            *value = p->filter_type;
            return true;
        case PARAM_ENABLED:
            *value = p->enabled ? 1.0 : 0.0;
            return true;
        default:
            return false;
    }
}

static bool audio_filter_set_param_value(const clap_plugin_t *plugin, clap_id param_id, double value) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;

    switch (param_id) {
        case PARAM_CUTOFF:
            p->cutoff_freq = (float)value;
            filter_set_parameters(&p->filter, p->filter_type, p->cutoff_freq, p->resonance, p->gain);
            return true;
        case PARAM_RESONANCE:
            p->resonance = (float)value;
            filter_set_parameters(&p->filter, p->filter_type, p->cutoff_freq, p->resonance, p->gain);
            return true;
        case PARAM_GAIN:
            p->gain = (float)value;
            filter_set_parameters(&p->filter, p->filter_type, p->cutoff_freq, p->resonance, p->gain);
            return true;
        case PARAM_TYPE:
            p->filter_type = (filter_type_t)value;
            filter_set_parameters(&p->filter, p->filter_type, p->cutoff_freq, p->resonance, p->gain);
            return true;
        case PARAM_ENABLED:
            p->enabled = value > 0.5;
            return true;
        default:
            return false;
    }
}

static bool audio_filter_format_param_value(const clap_plugin_t *plugin, clap_id param_id, double value, char *out_buffer, uint32_t out_buffer_size) {
    switch (param_id) {
        case PARAM_CUTOFF:
            snprintf(out_buffer, out_buffer_size, "%.1f Hz", value);
            return true;
        case PARAM_RESONANCE:
            snprintf(out_buffer, out_buffer_size, "%.2f", value);
            return true;
        case PARAM_GAIN:
            snprintf(out_buffer, out_buffer_size, "%.1f dB", value);
            return true;
        case PARAM_TYPE: {
            const char *filter_names[] = {
                "Low-Pass", "High-Pass", "Band-Pass", "Notch", 
                "Peaking", "Low Shelf", "High Shelf"
            };
            uint32_t type_index = (uint32_t)value;
            if (type_index < sizeof(filter_names) / sizeof(filter_names[0])) {
                snprintf(out_buffer, out_buffer_size, "%s", filter_names[type_index]);
                return true;
            }
            break;
        }
        case PARAM_ENABLED:
            snprintf(out_buffer, out_buffer_size, "%s", value > 0.5 ? "On" : "Off");
            return true;
        default:
            return false;
    }
    return false;
}

static bool audio_filter_parse_param_value(const clap_plugin_t *plugin, clap_id param_id, const char *value, double *out_value) {
    // This is a simplified parser - in practice you'd want more sophisticated parsing
    if (!value || !out_value) {
        return false;
    }
    
    switch (param_id) {
        case PARAM_CUTOFF:
            // Extract frequency value (assume format like "1000.0 Hz")
            {
                double freq;
                if (sscanf(value, "%lf Hz", &freq) == 1) {
                    *out_value = freq;
                    return true;
                }
            }
            break;
        case PARAM_ENABLED:
            if (strcasecmp(value, "on") == 0 || strcmp(value, "1") == 0) {
                *out_value = 1.0;
                return true;
            }
            if (strcasecmp(value, "off") == 0 || strcmp(value, "0") == 0) {
                *out_value = 0.0;
                return true;
            }
            break;
        default:
            // Try direct double parsing
            if (sscanf(value, "%lf", out_value) == 1) {
                return true;
            }
            break;
    }
    
    return false;
}

clap_plugin_params_t s_plugin_params = {
    .count = audio_filter_count_params,
    .get_info = audio_filter_get_param_info,
    .get_value = audio_filter_get_param_value,
    .value_to_text = audio_filter_format_param_value,
    .text_to_value = audio_filter_parse_param_value,
    .flush = NULL,
};

// State extension implementation
static bool audio_filter_save(const clap_plugin_t *plugin, const clap_ostream_t *stream) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;
    
    // Write plugin state
    if (!stream->write(stream, &p->cutoff_freq, sizeof(float))) return false;
    if (!stream->write(stream, &p->resonance, sizeof(float))) return false;
    if (!stream->write(stream, &p->gain, sizeof(float))) return false;
    if (!stream->write(stream, &p->filter_type, sizeof(filter_type_t))) return false;
    if (!stream->write(stream, &p->enabled, sizeof(bool))) return false;
    
    return true;
}

static bool audio_filter_load(const clap_plugin_t *plugin, const clap_istream_t *stream) {
    audio_filter_plugin_t *p = (audio_filter_plugin_t *)plugin->plugin_data;

    // Read plugin state
    if (!stream->read(stream, &p->cutoff_freq, sizeof(float))) return false;
    if (!stream->read(stream, &p->resonance, sizeof(float))) return false;
    if (!stream->read(stream, &p->gain, sizeof(float))) return false;
    if (!stream->read(stream, &p->filter_type, sizeof(filter_type_t))) return false;
    if (!stream->read(stream, &p->enabled, sizeof(bool))) return false;

    // Update filter parameters
    filter_set_parameters(&p->filter, p->filter_type, p->cutoff_freq, p->resonance, p->gain);
    filter_set_sample_rate(&p->filter, p->sample_rate);

    return true;
}

clap_plugin_state_t s_plugin_state = {
    .save = audio_filter_save,
    .load = audio_filter_load,
};

// Latency extension implementation
static uint32_t audio_filter_get_latency(const clap_plugin_t *plugin) {
    // This filter has no latency
    return 0;
}

clap_plugin_latency_t s_plugin_latency = {
    .get = audio_filter_get_latency,
};

// Audio ports extension implementation
static uint32_t audio_filter_count_audio_ports(const clap_plugin_t *plugin, bool is_input) {
    return 1; // 1 input, 1 output
}

static bool audio_filter_get_audio_port_info(const clap_plugin_t *plugin, uint32_t index, bool is_input, clap_audio_port_info_t *info) {
    if (index != 0) return false;

    info->id = 0;
    snprintf(info->name, sizeof(info->name), "%s", is_input ? "Audio Input" : "Audio Output");
    info->channel_count = 2; // Stereo
    info->flags = CLAP_AUDIO_PORT_IS_MAIN;
    info->port_type = CLAP_PORT_STEREO;
    info->in_place_pair = CLAP_INVALID_ID; // Not in-place capable

    return true;
}

clap_plugin_audio_ports_t s_plugin_audio_ports = {
    .count = audio_filter_count_audio_ports,
    .get = audio_filter_get_audio_port_info,
};

// Surround extension - stub (not implemented)
clap_plugin_surround_t s_plugin_surround = {
    .get_channel_map = NULL,
};

// Ambisonic extension - stub (not implemented)
clap_plugin_ambisonic_t s_plugin_ambisonic = {
    .is_config_supported = NULL,
    .get_config = NULL,
};

// GUI extension - stub (not implemented)
clap_plugin_gui_t s_plugin_gui = {
    .is_api_supported = NULL,
    .get_preferred_api = NULL,
    .create = NULL,
    .destroy = NULL,
    .set_scale = NULL,
    .get_size = NULL,
    .can_resize = NULL,
    .get_resize_hints = NULL,
    .adjust_size = NULL,
    .set_size = NULL,
    .set_parent = NULL,
    .set_transient = NULL,
    .suggest_title = NULL,
    .show = NULL,
    .hide = NULL,
};


#ifdef __cplusplus
}
#endif
