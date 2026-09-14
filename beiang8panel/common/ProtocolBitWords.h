#ifndef PROTOCOLBITWORDS_H
#define PROTOCOLBITWORDS_H

#include <cstdint>

namespace ProtocolData {

static inline void bit_word_set(uint16_t* words, uint16_t bit, uint8_t value)
{
    const uint16_t mask = static_cast<uint16_t>(1u << (bit & 15u));
    uint16_t* word = &words[bit >> 4];
    *word = value != 0
        ? static_cast<uint16_t>(*word | mask)
        : static_cast<uint16_t>(*word & static_cast<uint16_t>(~mask));
}

static inline uint8_t bit_word_get(const uint16_t* words, uint16_t bit)
{
    return static_cast<uint8_t>((words[bit >> 4] >> (bit & 15u)) & 1u);
}

} // namespace ProtocolData

#endif // PROTOCOLBITWORDS_H
