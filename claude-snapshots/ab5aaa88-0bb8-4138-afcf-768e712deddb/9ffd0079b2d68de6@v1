#include <clap/clap.h>
#include <stdlib.h>
#include <string.h>

#ifdef CLAP_HAS_THREADS
#include <threads.h>
#endif

// Global plugin entry state
static int g_entry_init_counter = 0;

#ifdef CLAP_HAS_THREADS
static mtx_t g_entry_lock;
static once_flag g_entry_once = ONCE_FLAG_INIT;

static void entry_init_guard_init(void) {
    mtx_init(&g_entry_lock, mtx_plain);
}
#endif

// Plugin initialization
static bool entry_init(const char *plugin_path) {
    // Initialize any global resources needed by the plugin
    return true;
}

static void entry_deinit(void) {
    // Cleanup any global resources
}

// Thread-safe initialization
static bool entry_init_guard(const char *plugin_path) {
#ifdef CLAP_HAS_THREADS
    call_once(&g_entry_once, entry_init_guard_init);
    mtx_lock(&g_entry_lock);
#endif
    
    const int cnt = ++g_entry_init_counter;
    
    bool success = true;
    if (cnt == 1) {
        success = entry_init(plugin_path);
        if (!success) {
            g_entry_init_counter = 0;
        }
    }
    
#ifdef CLAP_HAS_THREADS
    mtx_unlock(&g_entry_lock);
#endif
    
    return success;
}

// Thread-safe deinitialization
static void entry_deinit_guard(void) {
#ifdef CLAP_HAS_THREADS
    call_once(&g_entry_once, entry_init_guard_init);
    mtx_lock(&g_entry_lock);
#endif
    
    const int cnt = --g_entry_init_counter;
    
    if (cnt == 0) {
        entry_deinit();
    }
    
#ifdef CLAP_HAS_THREADS
    mtx_unlock(&g_entry_lock);
#endif
}

// Get factory interface
static const void *entry_get_factory(const char *factory_id) {
#ifdef CLAP_HAS_THREADS
    call_once(&g_entry_once, entry_init_guard_init);
#endif
    
    if (g_entry_init_counter <= 0) {
        return NULL;
    }
    
    if (strcmp(factory_id, CLAP_PLUGIN_FACTORY_ID) == 0) {
        return clap_get_factory(factory_id);
    }
    
    return NULL;
}

// Plugin entry point structure
const clap_plugin_entry_t clap_entry = {
    .clap_version = CLAP_VERSION_INIT,
    .init = entry_init_guard,
    .deinit = entry_deinit_guard,
    .get_factory = entry_get_factory,
};