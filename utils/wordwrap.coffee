wordwrap = (long_text, max_length) ->
    all_words = long_text.split(' ')
    wrapped = []
    current_chunk = ''
    next_chunk = ''
    i = 0
    next_chunk = all_words[i]
    while i < all_words.length
        if (current_chunk + next_chunk).length <= max_length
            current_chunk += next_chunk + ' '
            i += 1
            next_chunk = all_words[i]
        else
            if !current_chunk.length
                # fill in part of word
                current_chunk = next_chunk[..max_length-2] + '-'
                next_chunk = next_chunk[max_length-1..]
            else
                # chunk complete
                wrapped.push current_chunk.trim()
                current_chunk = ''
    if current_chunk.length
        wrapped.push current_chunk.trim()
    return wrapped

module.exports = wordwrap
