#ifndef IOS_UTILS_H
#define IOS_UTILS_H

#include <string>

#ifdef __APPLE__
// Function to get iOS Documents directory path
std::string get_ios_documents_path();
#endif

#endif // IOS_UTILS_H
