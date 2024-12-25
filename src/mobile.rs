use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::models::*;

#[cfg(target_os = "ios")]
tauri::ios_plugin_binding!(init_plugin_icloud);

// initializes the Kotlin or Swift plugin classes
pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<Icloud<R>> {
    #[cfg(target_os = "android")]
    let handle = api.register_android_plugin("", "iCloudPlugin")?;
    #[cfg(target_os = "ios")]
    let handle = api.register_ios_plugin(init_plugin_icloud)?;
    Ok(Icloud(handle))
}

/// Access to the icloud APIs.
pub struct Icloud<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> Icloud<R> {
    pub fn open_folder(&self, payload: OpenFolderRequest) -> crate::Result<OpenFolderResponse> {
        self.0
            .run_mobile_plugin("openFolder", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn read_dir(&self, payload: ReadDirRequest) -> crate::Result<ReadDirResponse> {
        self.0
            .run_mobile_plugin("readDir", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn read_text_file(&self, payload: ReadTextFileRequest) -> crate::Result<ReadTextFileResponse> {
        self.0
            .run_mobile_plugin("readTextFile", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn read_image_file(&self, payload: ReadImageFileRequest) -> crate::Result<ReadImageFileResponse> {
        self.0
            .run_mobile_plugin("readImageFile", payload)
            .map_err(Into::into)
    }
}