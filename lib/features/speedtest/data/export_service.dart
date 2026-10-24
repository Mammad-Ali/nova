/// Saving results as an image or CSV.
///
/// The app writes the file wherever the user points the system save dialog;
/// a browser has no such dialog and no file system, so there the file is
/// handed over as a download. Both expose the same `ExportService`.
library;

export 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart';
