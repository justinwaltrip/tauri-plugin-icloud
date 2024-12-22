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
