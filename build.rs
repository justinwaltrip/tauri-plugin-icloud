const COMMANDS: &[&str] = &["open_folder", "read_dir", "read_text_file", "bulk_read_text_file", "read_image_file", "write_text_file", "exists", "create_folder", "rename"];

fn main() {
  tauri_plugin::Builder::new(COMMANDS)
    .android_path("android")
    .ios_path("ios")
    .build();
}
