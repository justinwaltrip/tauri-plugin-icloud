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
