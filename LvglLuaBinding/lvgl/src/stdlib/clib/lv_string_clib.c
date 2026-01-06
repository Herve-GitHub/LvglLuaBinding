/**
 * @file lv_string_clib.c
 */

/*********************
 *      INCLUDES
 *********************/
#include "../../lv_conf_internal.h"
#if LV_USE_STDLIB_STRING == LV_STDLIB_CLIB
#include "../lv_string.h"
#include "../lv_mem.h" /*Need lv_malloc*/
#include <string.h>

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 *  STATIC PROTOTYPES
 **********************/

/**********************
 *  STATIC VARIABLES
 **********************/

/**********************
 *      MACROS
 **********************/

/**********************
 *   GLOBAL FUNCTIONS
 **********************/

void * LV_ATTRIBUTE_FAST_MEM lv_memcpy(void * dst, const void * src, size_t len)
{
    return memcpy(dst, src, len);
}

void LV_ATTRIBUTE_FAST_MEM lv_memset(void * dst, uint8_t v, size_t len)
{
    memset(dst, v, len);
}

void * LV_ATTRIBUTE_FAST_MEM lv_memmove(void * dst, const void * src, size_t len)
{
    return memmove(dst, src, len);
}

int lv_memcmp(const void * p1, const void * p2, size_t len)
{
    return memcmp(p1, p2, len);
}

size_t lv_strlen(const char * str)
{
    return strlen(str);
}

size_t lv_strnlen(const char * str, size_t max_len)
{
    return strnlen(str, max_len);
}

size_t lv_strlcpy(char * dst, const char * src, size_t dst_size)
{
    size_t src_len = strlen(src);
    if(dst_size > 0) {
        size_t copy_size = src_len < dst_size ? src_len : dst_size - 1;
        memcpy(dst, src, copy_size);
        dst[copy_size] = '\0';
    }
    return src_len;
}

char * lv_strncpy(char * dst, const char * src, size_t dest_size)
{
#if defined(_MSC_VER)
    /* Use strncpy_s for MSVC to avoid C4996 warning */
    if (strncpy_s(dst, dest_size, src, _TRUNCATE) == 0) {
        return dst;
    } else {
        if (dest_size > 0) dst[0] = '\0';
        return dst;
    }
#else
    return strncpy(dst, src, dest_size);
#endif
}

char * lv_strcpy(char * dst, const char * src)
{
    /* 使用安全的 strcpy_s 替代 strcpy */
    if(dst == NULL || src == NULL) return NULL;
    size_t src_len = strlen(src) + 1;
    errno_t err = strcpy_s(dst, src_len, src);
    if(err != 0) return NULL;
    return dst;
}

int lv_strcmp(const char * s1, const char * s2)
{
    return strcmp(s1, s2);
}

int lv_strncmp(const char * s1, const char * s2, size_t len)
{
    return strncmp(s1, s2, len);
}

char * lv_strdup(const char * src)
{
    /*strdup uses malloc, so use the lv_malloc when LV_USE_STDLIB_MALLOC is not LV_STDLIB_CLIB */
    size_t len = lv_strlen(src) + 1;
    char * dst = lv_malloc(len);
    if(dst == NULL) return NULL;

    lv_memcpy(dst, src, len); /*do memcpy is faster than strncpy when length is known*/
    return dst;
}

char * lv_strndup(const char * src, size_t max_len)
{
    size_t len = lv_strnlen(src, max_len);
    char * dst = lv_malloc(len + 1);
    if(dst == NULL) return NULL;

    lv_memcpy(dst, src, len);
    dst[len] = '\0';
    return dst;
}

char * lv_strcat(char * dst, const char * src)
{
#if defined(_MSC_VER)
    /* 使用安全的 strcat_s 替代 strcat，避免 C4996 警告 */
    if(dst == NULL || src == NULL) return NULL;
    size_t dst_len = strlen(dst);
    size_t src_len = strlen(src);
    size_t dst_size = dst_len + src_len + 1;
    errno_t err = strcat_s(dst, dst_size, src);
    if(err != 0) return NULL;
    return dst;
#else
    return strcat(dst, src);
#endif
}

char * lv_strncat(char * dst, const char * src, size_t src_len)
{
#if defined(_MSC_VER)
    /* 使用安全的 strncat_s 替代 strncat 以避免 C4996 警告 */
    if (strncat_s(dst, src_len + strlen(dst) + 1, src, src_len) == 0) {
        return dst;
    } else {
        return NULL;
    }
#else
    return strncat(dst, src, src_len);
#endif
}

char * lv_strchr(const char * str, int c)
{
    return strchr(str, c);
}

/**********************
 *   STATIC FUNCTIONS
 **********************/

#endif /*LV_STDLIB_CLIB*/
