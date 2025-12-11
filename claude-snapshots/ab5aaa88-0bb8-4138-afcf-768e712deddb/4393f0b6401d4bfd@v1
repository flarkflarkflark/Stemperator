#include "plugin.cpp"
#include <clap/ext/params.h>
#include <clap/ext/state.h>
#include <clap/ext/latency.h>
#include <clap/ext/audio-ports.h>

// Parameter extension implementation
static uint32_t audio_filter_count_params(const clap_plugin_t *plugin) {
    return sizeof(s_param_info) / sizeof(s_param_info[0]);
}

static bool audio_filter_get_param_info(const clap_plugin_t *plugin, uint32_t param_index, clap_param_info_t *info) {
    if (param_index >= sizeof(s_param_info) / sizeof(s_param_info[0])) {
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
            update_filter_parameters(p);
            return true;
        case PARAM_RESONANCE:
            p->resonance = (float)value;
            update_filter_parameters(p);
            return true;
        case PARAM_GAIN:
            p->gain = (float)value;
            update_filter_parameters(p);
            return true;
        case PARAM_TYPE:
            p->filter_type = (filter_type_t)value;
            update_filter_parameters(p);
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

static const clap_plugin_params_t s_plugin_params = {
    .count = audio_filter_count_params,
    .get_info = audio_filter_get_param_info,
    .get_value = audio_filter_get_param_value,
    .set_value = audio_filter_set_param_value,
    .format_value = audio_filter_format_param_value,
    .parse_value = audio_filter_parse_param_value,
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
    update_filter_parameters(p);
    
    return true;
}

static const clap_plugin_state_t s_plugin_state = {
    .save = audio_filter_save,
    .load = audio_filter_load,
};

// Latency extension implementation
static uint32_t audio_filter_get_latency(const clap_plugin_t *plugin) {
    // This filter has no latency
    return 0;
}

static const clap_plugin_latency_t s_plugin_latency = {
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

static const clap_plugin_audio_ports_t s_plugin_audio_ports = {
    .count = audio_filter_count_audio_ports,
    .get = audio_filter_get_audio_port_info,
};

// Surround extension (simplified implementation)
static uint32_t audio_filter_count_surround_channels(const clap_plugin_t *plugin, clap_id port_id) {
    return 2; // Stereo
}

static bool audio_filter_get_surround_channel_map(const clap_plugin_t *plugin, clap_id port_id, bool is_input, uint8_t *channel_map, uint32_t channel_map_size) {
    if (channel_map_size < 2) return false;
    
    // Stereo mapping: L, R
    channel_map[0] = CLAP_SURROUND_CHANNEL_L;
    channel_map[1] = CLAP_SURROUND_CHANNEL_R;
    return true;
}

static const clap_plugin_surround_t s_plugin_surround = {
    .count = audio_filter_count_surround_channels,
    .get_channel_map = audio_filter_get_surround_channel_map,
};

// Ambisonic extension (simplified implementation)
static bool audio_filter_is_supported_ambisonic_order(const clap_plugin_t *plugin, bool is_input, uint8_t order) {
    return order == 1; // First-order ambisonic only
}

static uint32_t audio_filter_get_ambisonic_channel_count(const clap_plugin_t *plugin, bool is_input, uint8_t order) {
    return (order + 1) * (order + 1); // Ambisonic channel count
}

static bool audio_filter_get_ambisonic_channel_map(const clap_plugin_t *plugin, bool is_input, uint8_t order, clap_id *channel_map, uint32_t channel_map_size) {
    // Simple channel mapping
    for (uint32_t i = 0; i < channel_map_size && i < 4; ++i) {
        channel_map[i] = i;
    }
    return true;
}

static const clap_plugin_ambisonic_t s_plugin_ambisonic = {
    .is_supported_order = audio_filter_is_supported_ambisonic_order,
    .get_channel_count = audio_filter_get_ambisonic_channel_count,
    .get_channel_map = audio_filter_get_ambisonic_channel_map,
};