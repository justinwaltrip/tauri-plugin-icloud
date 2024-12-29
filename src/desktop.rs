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

impl<R: Runtime> Icloud<R> {
    pub fn read_text_file(&self, _payload: ReadTextFileRequest) -> crate::Result<ReadTextFileResponse> {
        Ok(ReadTextFileResponse {
            content: "fake-content".to_string(),
        })
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn read_image_file(&self, _payload: ReadImageFileRequest) -> crate::Result<ReadImageFileResponse> {
        Ok(ReadImageFileResponse {
            content: "fake-content".to_string(),
        })
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn write_text_file(&self, _payload: WriteTextFileRequest) -> crate::Result<WriteTextFileResponse> {
        Ok(WriteTextFileResponse {
            success: true,
            path: _payload.path,
        })
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn exists(&self, _payload: ExistsRequest) -> crate::Result<ExistsResponse> {
        Ok(ExistsResponse {
            exists: true,
        })
    }
}

impl<R: Runtime> Icloud<R> {
    pub fn create_folder(&self, _payload: CreateFolderRequest) -> crate::Result<CreateFolderResponse> {
        Ok(CreateFolderResponse {
            success: true,
            path: _payload.path,
        })
    }
}
