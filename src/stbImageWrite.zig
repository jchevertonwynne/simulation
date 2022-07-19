pub extern fn stbi_write_png(filename: [*]const u8, w: c_int, h: c_int, comp: c_int, data: [*]const u8, stride_in_bytes: c_int) c_int;
