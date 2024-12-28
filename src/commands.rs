use tauri::{AppHandle, command, Runtime};

use crate::models::*;
use crate::Result;
use crate::IcloudExt;

#[command]
pub(crate) async fn open_folder<R: Runtime>(
    app: AppHandle<R>,
    payload: OpenFolderRequest,
) -> Result<OpenFolderResponse> {
    app.icloud().open_folder(payload)
}

#[command]
pub(crate) async fn read_dir<R: Runtime>(
    app: AppHandle<R>,
    payload: ReadDirRequest,
) -> Result<ReadDirResponse> {
    app.icloud().read_dir(payload)
}

#[command]
pub(crate) async fn read_text_file<R: Runtime>(
    app: AppHandle<R>,
    payload: ReadTextFileRequest,
) -> Result<ReadTextFileResponse> {
    app.icloud().read_text_file(payload)
}

#[command]
pub(crate) async fn read_image_file<R: Runtime>(
    app: AppHandle<R>,
    payload: ReadImageFileRequest,
) -> Result<ReadImageFileResponse> {
    app.icloud().read_image_file(payload)
}

#[command]
pub(crate) async fn write_text_file<R: Runtime>(
    app: AppHandle<R>,
    payload: WriteTextFileRequest,
) -> Result<()> {
    app.icloud().write_text_file(payload)
}
