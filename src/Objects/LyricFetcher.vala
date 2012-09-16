/*-
 * Copyright (c) 2011-2012       Scott Ringwelski <sgringwe@mtu.edu>
 *
 * Originally Written by Scott Ringwelski for BeatBox Music Player
 * BeatBox Music Player: http://www.launchpad.net/beat-box
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

public class Noise.LyricFetcher : Object {

    public async string fetch_lyrics_async (Media m) {
        SourceFunc cb = fetch_lyrics_async.callback;
        string lyrics = "";

        try {
            new Thread<void*>.try (null, () => {
                lyrics = fetch_lyrics (m);
                Idle.add ((owned)cb);
                return null;
            });
        } catch (Error err) {
            warning ("ERROR: Could not create lyrics thread: %s \n", err.message);
        }

        yield;
        return lyrics;
    }

    private string fetch_lyrics (Media m) {
        var source = new AZLyricsFetcher ();
        return source.fetch_lyrics (m.title, m.album_artist, m.artist);
    }

}


/**
 * LYRIC SOURCES
 */

private class AZLyricsFetcher : Object {
    private const string URL_FORMAT = "http://www.azlyrics.com/lyrics/%s/%s.html";

    public string fetch_lyrics (string title, string album_artist, string artist) {
        var url = parse_url (artist, title);
        File page = File.new_for_uri (url);

        uint8[] uintcontent;
        string etag_out;
        bool load_successful = false;

        try {
            page.load_contents (null, out uintcontent, out etag_out);
            load_successful = true;
        } catch (Error err) {
            load_successful = false;
        }

        // Try again using album artist
        if (!load_successful && album_artist.length > 0) {
            try {
                url = parse_url (album_artist, title);
                page = File.new_for_uri (url);
                page.load_contents (null, out uintcontent, out etag_out);
                load_successful = true;
            } catch (Error err) {
                load_successful = false;
            }
        }

        return load_successful ? parse_lyrics (uintcontent) : "";
    }

    private string parse_url (string artist, string title) {
        return URL_FORMAT.printf (fix_string (artist), fix_string (title));
    }

    private string fix_string (string? str) {
        if (str == null)
            return "";

        var fixed_string = new StringBuilder ();
        unichar c;

        for (int i = 0; str.get_next_char (ref i, out c);) {
            c = c.tolower ();
            if ( ('a' <= c && c <= 'z') || ('0' <= c && c <= '9'))
                fixed_string.append_unichar (c);
        }

        return fixed_string.str;
    }

    private string parse_lyrics (uint8[] uintcontent) {
        string content = (string) uintcontent;
        string lyrics = "";
        var rv = new StringBuilder ();

        const string START_STRING = "<!-- start of lyrics -->";
        const string END_STRING = "<!-- end of lyrics -->";

        var start = content.index_of (START_STRING, 0) + START_STRING.length;
        var end = content.index_of (END_STRING, start);

        if (start != -1 && end != -1 && end > start)
            lyrics = content.substring (start, end - start);

        try {
            lyrics = new Regex ("<.*?>").replace (lyrics, -1, 0, "");
        } catch (RegexError err) {
            warning ("Could not parse lyrics: %s", err.message);
            return "";
        }

        rv.append (lyrics);
        rv.append ("\n");

        return rv.str;
    }
}

