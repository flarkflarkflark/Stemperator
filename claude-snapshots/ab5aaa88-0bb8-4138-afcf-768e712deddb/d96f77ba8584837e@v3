#include "plugin.cpp"
#include "gui.cpp"
#include <clap/ext/gui.h>

// GUI extension implementation for CLAP
static const clap_plugin_gui_t s_plugin_gui;

// GUI context for the plugin
static gui_context_t *s_gui_context = NULL;

// GUI extension methods
static bool gui_is_api_supported(const clap_plugin_t *plugin, const char *api, bool is_floating) {
    if (strcmp(api, CLAP_WINDOW_API_WIN32) == 0) {
        return true; // Windows GUI supported
    }
    if (strcmp(api, CLAP_WINDOW_API_COCOA) == 0) {
        return true; // macOS GUI supported  
    }
    if (strcmp(api, CLAP_WINDOW_API_X11) == 0) {
        return true; // Linux GUI supported
    }
    return false;
}

static bool gui_create(const clap_plugin_t *plugin, const char *api, bool is_floating, uint32_t width, uint32_t height) {
    if (s_gui_context) {
        return false; // GUI already exists
    }
    
    s_gui_context = (gui_context_t *)malloc(sizeof(gui_context_t));
    if (!s_gui_context) {
        return false;
    }
    
    if (!gui_create(s_gui_context, plugin, width, height)) {
        free(s_gui_context);
        s_gui_context = NULL;
        return false;
    }
    
    printf("CLAP GUI created successfully\n");
    return true;
}

static void gui_destroy(const clap_plugin_t *plugin) {
    if (s_gui_context) {
        gui_destroy(s_gui_context);
        free(s_gui_context);
        s_gui_context = NULL;
    }
}

static bool gui_set_scale(const clap_plugin_t *plugin, double scale) {
    // Handle DPI scaling if needed
    printf("GUI scale set to: %.2f\n", scale);
    return true;
}

static bool gui_get_size(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height) {
    if (!s_gui_context) return false;
    
    *width = s_gui_context->width;
    *height = s_gui_context->height;
    return true;
}

static bool gui_can_resize(const clap_plugin_t *plugin) {
    return true;
}

static bool gui_set_size(const clap_plugin_t *plugin, uint32_t width, uint32_t height) {
    if (!s_gui_context) return false;
    
    s_gui_context->width = width;
    s_gui_context->height = height;
    printf("GUI resized to: %dx%d\n", width, height);
    return true;
}

static void gui_attach(const clap_plugin_t *plugin, const void *native_window) {
    printf("GUI attached to native window\n");
}

static void gui_detach(const clap_plugin_t *plugin) {
    printf("GUI detached from native window\n");
}

static void gui_set_parent(const clap_plugin_t *plugin, const void *native_window) {
    printf("GUI parent set\n");
}

static bool gui_set_transient(const clap_plugin_t *plugin, const void *native_window) {
    printf("GUI transient window set\n");
    return true;
}

static void gui_suggest_title(const clap_plugin_t *plugin, const char *title) {
    printf("GUI title: %s\n", title);
}

static bool gui_show(const clap_plugin_t *plugin) {
    printf("GUI shown\n");
    return true;
}

static bool gui_hide(const clap_plugin_t *plugin) {
    printf("GUI hidden\n");
    return true;
}

// Update GUI extension
static void update_gui_extension(audio_filter_plugin_t *plugin) {
    if (s_gui_context && plugin->host) {
        // Get audio input data for visualization
        const clap_host_t *host = plugin->host;
        
        // Access audio processing if available
        if (plugin->temp_buffer && plugin->temp_buffer_size > 0) {
            gui_update(s_gui_context, plugin->temp_buffer, plugin->temp_buffer_size, plugin->sample_rate);
        }
    }
}

static const clap_plugin_gui_t s_plugin_gui = {
    .is_api_supported = gui_is_api_supported,
    .create = gui_create,
    .destroy = gui_destroy,
    .set_scale = gui_set_scale,
    .get_size = gui_get_size,
    .can_resize = gui_can_resize,
    .set_size = gui_set_size,
    .attach = gui_attach,
    .detach = gui_detach,
    .set_parent = gui_set_parent,
    .set_transient = gui_set_transient,
    .suggest_title = gui_suggest_title,
    .show = gui_show,
    .hide = gui_hide,
};