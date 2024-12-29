use tauri::{
  plugin::{Builder, TauriPlugin},
  Manager, Runtime,
};

pub use models::*;

#[cfg(desktop)]
mod desktop;
#[cfg(mobile)]
mod mobile;

mod commands;
mod error;
mod models;

pub use error::{Error, Result};

#[cfg(desktop)]
use desktop::Icloud;
#[cfg(mobile)]
use mobile::Icloud;

/// Extensions to [`tauri::App`], [`tauri::AppHandle`] and [`tauri::Window`] to access the icloud APIs.
pub trait IcloudExt<R: Runtime> {
  fn icloud(&self) -> &Icloud<R>;
}

impl<R: Runtime, T: Manager<R>> crate::IcloudExt<R> for T {
  fn icloud(&self) -> &Icloud<R> {
    self.state::<Icloud<R>>().inner()
  }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
  Builder::new("icloud")
    .invoke_handler(tauri::generate_handler![commands::open_folder])
    .invoke_handler(tauri::generate_handler![commands::read_dir])
    .invoke_handler(tauri::generate_handler![commands::read_text_file])
    .invoke_handler(tauri::generate_handler![commands::read_image_file])
    .invoke_handler(tauri::generate_handler![commands::write_text_file])
    .invoke_handler(tauri::generate_handler![commands::exists])
    .invoke_handler(tauri::generate_handler![commands::create_folder])
    .setup(|app, api| {
      #[cfg(mobile)]
      let icloud = mobile::init(app, api)?;
      #[cfg(desktop)]
      let icloud = desktop::init(app, api)?;
      app.manage(icloud);
      Ok(())
    })
    .build()
}
