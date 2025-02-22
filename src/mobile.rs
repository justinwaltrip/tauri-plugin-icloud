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
    pub fn bulk_read_text_file(&self, payload: BulkReadTextFileRequest) -> crate::Result<BulkReadTextFileResponse> {
        self.0
            .run_mobile_plugin("bulkReadTextFile", payload)
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

impl<R: Runtime> Icloud<R> {
    pub fn write_text_file(&self, payload: WriteTextFileRequest) -> crate::Result<WriteTextFileResponse> {
        self.0
            .run_mobile_plugin("writeTextFile", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn exists(&self, payload: ExistsRequest) -> crate::Result<ExistsResponse> {
        self.0
            .run_mobile_plugin("exists", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn create_folder(&self, payload: CreateFolderRequest) -> crate::Result<CreateFolderResponse> {
        self.0
            .run_mobile_plugin("createFolder", payload)
            .map_err(Into::into)
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn rename(&self, payload: RenameRequest) -> crate::Result<RenameResponse> {
        self.0
            .run_mobile_plugin("rename", payload)
            .map_err(Into::into)
    }
}
