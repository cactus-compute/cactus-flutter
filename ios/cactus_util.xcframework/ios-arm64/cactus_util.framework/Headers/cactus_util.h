#ifndef cactus_util_H
#define cactus_util_H

#ifdef __cplusplus
extern "C" {
#endif
int register_app(const char* telemetry_token, const char* enterprise_key, const char* device_metadata);

int update_token(const char* enterprise_key);

char* get_all_entries(void);

void free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif
