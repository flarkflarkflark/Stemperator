#include <clap/clap.h>
#include <stdlib.h>
#include <string.h>
#include "plugin.h"

// Plugin factory
static const struct {
    const clap_plugin_descriptor_t *desc;
    clap_plugin_t *(CLAP_ABI *create)(const clap_host_t *host);
} s_plugins[] = {
    {
        .desc = &s_plugin_desc,
        .create = audio_filter_plugin_create,
    },
};

static uint32_t plugin_factory_get_plugin_count(const clap_plugin_factory_t *factory) {
    return sizeof(s_plugins) / sizeof(s_plugins[0]);
}

static const clap_plugin_descriptor_t *plugin_factory_get_plugin_descriptor(const clap_plugin_factory_t *factory, uint32_t index) {
    if (index >= sizeof(s_plugins) / sizeof(s_plugins[0])) {
        return NULL;
    }
    return s_plugins[index].desc;
}

static const clap_plugin_t *plugin_factory_create_plugin(const clap_plugin_factory_t *factory, const clap_host_t *host, const char *plugin_id) {
    if (!clap_version_is_compatible(host->clap_version)) {
        return NULL;
    }
    
    for (size_t i = 0; i < sizeof(s_plugins) / sizeof(s_plugins[0]); ++i) {
        if (strcmp(plugin_id, s_plugins[i].desc->id) == 0) {
            return s_plugins[i].create(host);
        }
    }
    
    return NULL;
}

static const clap_plugin_factory_t s_plugin_factory = {
    .get_plugin_count = plugin_factory_get_plugin_count,
    .get_plugin_descriptor = plugin_factory_get_plugin_descriptor,
    .create_plugin = plugin_factory_create_plugin,
};

const void *clap_get_factory(const char *factory_id) {
    if (strcmp(factory_id, CLAP_PLUGIN_FACTORY_ID) == 0) {
        return &s_plugin_factory;
    }
    return NULL;
}