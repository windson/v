module embed_file

import os

pub const (
	is_used = 1
)

// https://github.com/vlang/rfcs/blob/master/embedding_resources.md
// EmbedFileData encapsulates functionality for the `$embed_file()` compile time call.
pub struct EmbedFileData {
	apath string
mut:
	compressed        &byte
	uncompressed      &byte
	free_compressed   bool
	free_uncompressed bool
pub:
	len  int
	path string
}

pub fn (ed EmbedFileData) str() string {
	return 'embed_file.EmbedFileData{ len: $ed.len, path: "$ed.path", apath: "$ed.apath", uncompressed: ${ptr_str(ed.uncompressed)} }'
}

[unsafe]
pub fn (mut ed EmbedFileData) free() {
	unsafe {
		ed.path.free()
		ed.apath.free()
		if ed.free_compressed {
			free(ed.compressed)
			ed.compressed = &byte(0)
		}
		if ed.free_uncompressed {
			free(ed.uncompressed)
			ed.uncompressed = &byte(0)
		}
	}
}

pub fn (original &EmbedFileData) to_string() string {
	unsafe {
		mut ed := &EmbedFileData(original)
		the_copy := &byte(memdup(ed.data(), ed.len))
		return the_copy.vstring_with_len(ed.len)
	}
}

pub fn (original &EmbedFileData) to_bytes() []byte {
	unsafe {
		mut ed := &EmbedFileData(original)
		the_copy := memdup(ed.data(), ed.len)
		return the_copy.vbytes(ed.len)
	}
}

pub fn (mut ed EmbedFileData) data() &byte {
	if !isnil(ed.uncompressed) {
		return ed.uncompressed
	} else {
		if isnil(ed.uncompressed) && !isnil(ed.compressed) {
			// TODO implement uncompression
			// See also C Gen.gen_embedded_data() where the compression should occur.
			ed.uncompressed = ed.compressed
		} else {
			mut path := os.resource_abs_path(ed.path)
			if !os.is_file(path) {
				path = ed.apath
				if !os.is_file(path) {
					panic('EmbedFileData error: files "$ed.path" and "$ed.apath" do not exist')
				}
			}
			bytes := os.read_bytes(path) or {
				panic('EmbedFileData error: "$path" could not be read: $err')
			}
			ed.uncompressed = bytes.data
			ed.free_uncompressed = true
		}
	}
	return ed.uncompressed
}

//////////////////////////////////////////////////////////////////////////////
// EmbedFileIndexEntry is used internally by the V compiler when you compile a
// program that uses $embed_file('file.bin') in -prod mode.
// V will generate a static index of all embedded files, and will call the
// find_index_entry_by_path over the index and the relative paths of the embeds.
// NB: these are public on purpose, to help -usecache.
pub struct EmbedFileIndexEntry {
	id   int
	path string
	data &byte
}

// find_index_entry_by_path is used internally by the V compiler:
pub fn find_index_entry_by_path(start voidptr, path string) &EmbedFileIndexEntry {
	mut x := &EmbedFileIndexEntry(start)
	for !(x.path == path || isnil(x.data)) {
		unsafe {
			x++
		}
	}
	$if debug_embed_file_in_prod ? {
		eprintln('>> v.embed_file find_index_entry_by_path ${ptr_str(start)}, path: "$path" => ${ptr_str(x)}')
	}
	return x
}
