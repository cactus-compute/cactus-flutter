#ifndef LOGGING_H
#define LOGGING_H

#include <string>

// Log levels
enum LogLevel {
    LOG_DEBUG = 0,
    LOG_INFO = 1,
    LOG_WARNING = 2,
    LOG_ERROR = 3
};

// Cross-platform logging function
void cactus_log(LogLevel level, const char* tag, const char* message);
void cactus_log(LogLevel level, const char* tag, const std::string& message);

// Convenience macros
#define LOG_TAG "CactusUtil"
#define CACTUS_LOG_DEBUG(msg) cactus_log(LOG_DEBUG, LOG_TAG, msg)
#define CACTUS_LOG_INFO(msg) cactus_log(LOG_INFO, LOG_TAG, msg)
#define CACTUS_LOG_WARNING(msg) cactus_log(LOG_WARNING, LOG_TAG, msg)
#define CACTUS_LOG_ERROR(msg) cactus_log(LOG_ERROR, LOG_TAG, msg)

#endif
