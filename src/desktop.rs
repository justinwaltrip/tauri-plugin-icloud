use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::*;

pub fn init<R: Runtime, C: DeserializeOwned>(
  app: &AppHandle<R>,
  _api: PluginApi<R, C>,
) -> crate::Result<Icloud<R>> {
  Ok(Icloud(app.clone()))
}

/// Access to the icloud APIs.
pub struct Icloud<R: Runtime>(AppHandle<R>);

impl<R: Runtime> Icloud<R> {
    pub fn open_folder(&self, _payload: OpenFolderRequest) -> crate::Result<OpenFolderResponse> {
        Ok(OpenFolderResponse {
            relative_path: Some("fake-relative-path".to_string()),
            absolute_path: Some("fake-absolute-path".to_string()),
            url: Some("fake-url".to_string()),
        })
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn read_dir(&self, _payload: ReadDirRequest) -> crate::Result<ReadDirResponse> {
        Ok(ReadDirResponse {
            entries: vec![ReadDirEntry {
                name: "fake-name".to_string(),
            }],
        })
    }
}