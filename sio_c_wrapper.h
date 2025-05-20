#ifndef SIO_C_WRAPPER_H
#define SIO_C_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

// Opaque handles for C API
typedef void* sio_client_handle;
typedef void* sio_socket_handle;
typedef void* sio_message_handle;

// Message types
typedef enum {
    SIO_MESSAGE_NULL,
    SIO_MESSAGE_STRING,
    SIO_MESSAGE_INTEGER,
    SIO_MESSAGE_DOUBLE,
    SIO_MESSAGE_BOOLEAN,
    SIO_MESSAGE_ARRAY,
    SIO_MESSAGE_OBJECT,
    SIO_MESSAGE_BINARY
} sio_message_type;

// Message creation functions
sio_message_handle sio_message_create_null();
sio_message_handle sio_message_create_string(const char* str);
sio_message_handle sio_message_create_integer(int64_t value);
sio_message_handle sio_message_create_double(double value);
sio_message_handle sio_message_create_boolean(int value);
sio_message_handle sio_message_create_array();
sio_message_handle sio_message_create_object();

// Message manipulation functions
void sio_message_destroy(sio_message_handle msg);
sio_message_type sio_message_get_type(sio_message_handle msg);
const char* sio_message_get_string(sio_message_handle msg);
int64_t sio_message_get_integer(sio_message_handle msg);
double sio_message_get_double(sio_message_handle msg);
int sio_message_get_boolean(sio_message_handle msg);

// Array manipulation
void sio_message_array_push(sio_message_handle array, sio_message_handle msg);
size_t sio_message_array_size(sio_message_handle array);
sio_message_handle sio_message_array_get(sio_message_handle array, size_t index);

// Object manipulation
void sio_message_object_set(sio_message_handle obj, const char* key, sio_message_handle msg);
sio_message_handle sio_message_object_get(sio_message_handle obj, const char* key);
int sio_message_object_has(sio_message_handle obj, const char* key);

// Callback types
typedef void (*sio_connect_callback)(void* user_data);
typedef void (*sio_close_callback)(void* user_data);
typedef void (*sio_event_callback)(const char* event, sio_message_handle msg, void* user_data);

typedef void (*sio_fail_callback)(void* user_data);

typedef void (*sio_reconnect_callback)(unsigned attempt, unsigned delay, void* user_data);

typedef void (*sio_socket_listener_callback)(const char* nsp, void* user_data);

typedef void (*sio_error_callback)(const char* error, void* user_data);

// Client management
sio_client_handle sio_client_create();
void sio_client_destroy(sio_client_handle client);

// Connection management
void sio_client_connect(sio_client_handle client, const char* uri);
void sio_client_close(sio_client_handle client);
void sio_client_sync_close(sio_client_handle client);

// Event/callback registration
void sio_client_set_open_listener(sio_client_handle client, sio_connect_callback cb, void* user_data);
void sio_client_set_fail_listener(sio_client_handle client, sio_fail_callback cb, void* user_data);
void sio_client_set_close_listener(sio_client_handle client, sio_close_callback cb, void* user_data);
void sio_client_set_reconnect_listener(sio_client_handle client, sio_reconnect_callback cb, void* user_data);
void sio_client_set_socket_open_listener(sio_client_handle client, sio_socket_listener_callback cb, void* user_data);
void sio_client_set_socket_close_listener(sio_client_handle client, sio_socket_listener_callback cb, void* user_data);

// Socket management
sio_socket_handle sio_client_get_socket(sio_client_handle client, const char* nsp);
void sio_socket_destroy(sio_socket_handle socket);

// Event emission and listening
void sio_socket_emit(sio_socket_handle socket, const char* event, sio_message_handle msg);
void sio_socket_on(sio_socket_handle socket, const char* event, sio_event_callback cb, void* user_data);
void sio_socket_off(sio_socket_handle socket, const char* event);

#ifdef __cplusplus
}
#endif

#endif // SIO_C_WRAPPER_H 