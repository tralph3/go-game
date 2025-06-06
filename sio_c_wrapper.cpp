#include "sio_c_wrapper.h"
#include "sio_client.h"
#include "sio_socket.h"
#include "sio_message.h"
#include <map>
#include <string>
#include <memory>
#include <mutex>

using namespace sio;

struct sio_client_c {
    client* cli;
    sio_connect_callback open_cb = nullptr;
    void* open_ud = nullptr;
    sio_fail_callback fail_cb = nullptr;
    void* fail_ud = nullptr;
    sio_close_callback close_cb = nullptr;
    void* close_ud = nullptr;
    sio_reconnect_callback reconnect_cb = nullptr;
    void* reconnect_ud = nullptr;
    sio_socket_listener_callback socket_open_cb = nullptr;
    void* socket_open_ud = nullptr;
    sio_socket_listener_callback socket_close_cb = nullptr;
    void* socket_close_ud = nullptr;
};

struct sio_socket_c {
    sio::socket::ptr sock;
    std::mutex cb_mutex;
    std::map<std::string, std::pair<sio_event_callback, void*>> event_callbacks;
};

struct sio_message_c {
    message::ptr msg;
    std::vector<sio_message_handle> children; // For arrays and objects
};

extern "C" {

sio_message_handle sio_message_create_null() {
    sio_message_c* m = new sio_message_c;
    m->msg = null_message::create();
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_string(const char* str) {
    sio_message_c* m = new sio_message_c;
    m->msg = string_message::create(str);
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_integer(int64_t value) {
    sio_message_c* m = new sio_message_c;
    m->msg = int_message::create(value);
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_double(double value) {
    sio_message_c* m = new sio_message_c;
    m->msg = double_message::create(value);
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_boolean(int value) {
    sio_message_c* m = new sio_message_c;
    m->msg = bool_message::create(value != 0);
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_array() {
    sio_message_c* m = new sio_message_c;
    m->msg = array_message::create();
    return (sio_message_handle)m;
}

sio_message_handle sio_message_create_object() {
    sio_message_c* m = new sio_message_c;
    m->msg = object_message::create();
    return (sio_message_handle)m;
}

void sio_message_destroy(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    if (m) {
        if (m->msg->get_flag() == message::flag_array || m->msg->get_flag() == message::flag_object) {
            for (auto child : m->children) {
                sio_message_destroy(child);
            }
        }
        delete m;
    }
}

sio_message_type sio_message_get_type(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    switch (m->msg->get_flag()) {
        case message::flag_null: return SIO_MESSAGE_NULL;
        case message::flag_string: return SIO_MESSAGE_STRING;
        case message::flag_integer: return SIO_MESSAGE_INTEGER;
        case message::flag_double: return SIO_MESSAGE_DOUBLE;
        case message::flag_boolean: return SIO_MESSAGE_BOOLEAN;
        case message::flag_array: return SIO_MESSAGE_ARRAY;
        case message::flag_object: return SIO_MESSAGE_OBJECT;
        case message::flag_binary: return SIO_MESSAGE_BINARY;
        default: return SIO_MESSAGE_NULL;
    }
}

const char* sio_message_get_string(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    if (m->msg->get_flag() == sio::message::flag_string) {
        static std::string str;
        str = m->msg->get_string();
        return str.c_str();
    }
    return nullptr;
}

int64_t sio_message_get_integer(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    if (m->msg->get_flag() == sio::message::flag_integer) {
        return m->msg->get_int();
    }
    return 0;
}

double sio_message_get_double(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    if (m->msg->get_flag() == sio::message::flag_double) {
        return m->msg->get_double();
    }
    return 0.0;
}

int sio_message_get_boolean(sio_message_handle msg_) {
    sio_message_c* m = (sio_message_c*)msg_;
    if (m->msg->get_flag() == sio::message::flag_boolean) {
        return m->msg->get_bool() ? 1 : 0;
    }
    return 0;
}

void sio_message_array_push(sio_message_handle array_, sio_message_handle msg_) {
    sio_message_c* array = (sio_message_c*)array_;
    sio_message_c* msg = (sio_message_c*)msg_;
    if (array->msg->get_flag() == sio::message::flag_array) {
        array->msg->get_vector().push_back(msg->msg);
        array->children.push_back(msg_);
    }
}

size_t sio_message_array_size(sio_message_handle array_) {
    sio_message_c* array = (sio_message_c*)array_;
    if (array->msg->get_flag() == sio::message::flag_array) {
        return array->msg->get_vector().size();
    }
    return 0;
}

sio_message_handle sio_message_array_get(sio_message_handle array_, size_t index) {
    sio_message_c* array = (sio_message_c*)array_;
    if (array->msg->get_flag() == sio::message::flag_array) {
        const auto& vec = array->msg->get_vector();
        if (index < vec.size()) {
            sio_message_c* m = new sio_message_c;
            m->msg = vec[index];
            return (sio_message_handle)m;
        }
    }
    return nullptr;
}

void sio_message_object_set(sio_message_handle obj_, const char* key, sio_message_handle msg_) {
    sio_message_c* obj = (sio_message_c*)obj_;
    sio_message_c* msg = (sio_message_c*)msg_;
    if (obj->msg->get_flag() == sio::message::flag_object) {
        obj->msg->get_map()[key] = msg->msg;
        obj->children.push_back(msg_);
    }
}

sio_message_handle sio_message_object_get(sio_message_handle obj_, const char* key) {
    sio_message_c* obj = (sio_message_c*)obj_;
    if (obj->msg->get_flag() == sio::message::flag_object) {
        auto& map = obj->msg->get_map();
        auto it = map.find(key);
        if (it != map.end()) {
            sio_message_c* m = new sio_message_c;
            m->msg = it->second;
            return (sio_message_handle)m;
        }
    }
    return nullptr;
}

int sio_message_object_has(sio_message_handle obj_, const char* key) {
    sio_message_c* obj = (sio_message_c*)obj_;
    if (obj->msg->get_flag() == sio::message::flag_object) {
        return obj->msg->get_map().find(key) != obj->msg->get_map().end() ? 1 : 0;
    }
    return 0;
}

sio_client_handle sio_client_create() {
    sio_client_c* c = new sio_client_c;
    c->cli = new client();
    return (sio_client_handle)c;
}

void sio_client_destroy(sio_client_handle client_) {
    sio_client_c* c = (sio_client_c*)client_;
    if (c) {
        if (c->cli) {
            delete c->cli;
        }
        delete c;
    }
}

void sio_client_connect(sio_client_handle client_, const char* uri) {
    sio_client_c* c = (sio_client_c*)client_;
    c->cli->connect(uri);
}

void sio_client_close(sio_client_handle client_) {
    sio_client_c* c = (sio_client_c*)client_;
    c->cli->close();
}

void sio_client_sync_close(sio_client_handle client_) {
    sio_client_c* c = (sio_client_c*)client_;
    c->cli->sync_close();
}

void sio_client_set_open_listener(sio_client_handle client_, sio_connect_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->open_cb = cb;
    c->open_ud = user_data;
    c->cli->set_open_listener([c]() {
        if (c->open_cb) c->open_cb(c->open_ud);
    });
}

void sio_client_set_fail_listener(sio_client_handle client_, sio_fail_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->fail_cb = cb;
    c->fail_ud = user_data;
    c->cli->set_fail_listener([c]() {
        if (c->fail_cb) c->fail_cb(c->fail_ud);
    });
}

void sio_client_set_close_listener(sio_client_handle client_, sio_close_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->close_cb = cb;
    c->close_ud = user_data;
    c->cli->set_close_listener([c](client::close_reason) {
        if (c->close_cb) c->close_cb(c->close_ud);
    });
}

void sio_client_set_reconnect_listener(sio_client_handle client_, sio_reconnect_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->reconnect_cb = cb;
    c->reconnect_ud = user_data;
    c->cli->set_reconnect_listener([c](unsigned attempt, unsigned delay) {
        if (c->reconnect_cb) c->reconnect_cb(attempt, delay, c->reconnect_ud);
    });
}

void sio_client_set_socket_open_listener(sio_client_handle client_, sio_socket_listener_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->socket_open_cb = cb;
    c->socket_open_ud = user_data;
    c->cli->set_socket_open_listener([c](const std::string& nsp) {
        if (c->socket_open_cb) c->socket_open_cb(nsp.c_str(), c->socket_open_ud);
    });
}

void sio_client_set_socket_close_listener(sio_client_handle client_, sio_socket_listener_callback cb, void* user_data) {
    sio_client_c* c = (sio_client_c*)client_;
    c->socket_close_cb = cb;
    c->socket_close_ud = user_data;
    c->cli->set_socket_close_listener([c](const std::string& nsp) {
        if (c->socket_close_cb) c->socket_close_cb(nsp.c_str(), c->socket_close_ud);
    });
}

sio_socket_handle sio_client_get_socket(sio_client_handle client_, const char* nsp) {
    sio_client_c* c = (sio_client_c*)client_;
    sio_socket_c* s = new sio_socket_c;
    s->sock = c->cli->socket(nsp);
    return (sio_socket_handle)s;
}

void sio_socket_emit(sio_socket_handle socket_, const char* event, sio_message_handle msg_) {
    sio_socket_c* s = (sio_socket_c*)socket_;
    sio_message_c* m = (sio_message_c*)msg_;
    s->sock->emit(event, message::list(m->msg));
}

void sio_socket_on(sio_socket_handle socket_, const char* event, sio_event_callback cb, void* user_data) {
    sio_socket_c* s = (sio_socket_c*)socket_;
    {
        std::lock_guard<std::mutex> lock(s->cb_mutex);
        s->event_callbacks[event] = std::make_pair(cb, user_data);
    }
    std::string event_str(event);
    s->sock->on(event, [s, event_str](sio::event& ev) {
        sio_event_callback cb = nullptr;
        void* ud = nullptr;
        {
            std::lock_guard<std::mutex> lock(s->cb_mutex);
            auto it = s->event_callbacks.find(event_str);
            if (it != s->event_callbacks.end()) {
                cb = it->second.first;
                ud = it->second.second;
            }
        }
        if (cb) {
            sio_message_c* m = new sio_message_c;
            m->msg = ev.get_message();
            cb(event_str.c_str(), (sio_message_handle)m, ud);
            delete m;
        }
    });
}

void sio_socket_off(sio_socket_handle socket_, const char* event) {
    sio_socket_c* s = (sio_socket_c*)socket_;
    {
        std::lock_guard<std::mutex> lock(s->cb_mutex);
        s->event_callbacks.erase(event);
    }
    s->sock->off(event);
}

void sio_socket_destroy(sio_socket_handle socket_) {
    sio_socket_c* s = (sio_socket_c*)socket_;
    if (s) {
        {
            std::lock_guard<std::mutex> lock(s->cb_mutex);
            s->event_callbacks.clear();
        }
        delete s;
    }
}

} // extern "C"
