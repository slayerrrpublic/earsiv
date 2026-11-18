package android.print;

import android.content.Context;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

public class EfaturaPdfWriter {
    public interface Result {
        void onSuccess(byte[] bytes);
        void onError(String code, String message);
    }

    public static void write(
            final Context context,
            final PrintDocumentAdapter adapter,
            final PrintAttributes attributes,
            final Result result
    ) {
        adapter.onLayout(null, attributes, null, new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                File outputFile;
                try {
                    outputFile = File.createTempFile("efatura_", ".pdf", context.getCacheDir());
                } catch (IOException e) {
                    result.onError("TEMP_FILE_FAILED", e.getMessage());
                    return;
                }

                try {
                    final File finalOutputFile = outputFile;
                    final ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(
                            outputFile,
                            ParcelFileDescriptor.MODE_READ_WRITE
                    );
                    adapter.onWrite(
                            new PageRange[]{PageRange.ALL_PAGES},
                            descriptor,
                            new CancellationSignal(),
                            new PrintDocumentAdapter.WriteResultCallback() {
                                @Override
                                public void onWriteFinished(PageRange[] pages) {
                                    try {
                                        descriptor.close();
                                        byte[] bytes = readBytes(finalOutputFile);
                                        finalOutputFile.delete();
                                        if (bytes.length == 0) {
                                            result.onError("EMPTY_PDF", "PDF oluşturuldu ama dosya boş geldi.");
                                        } else {
                                            result.onSuccess(bytes);
                                        }
                                    } catch (IOException e) {
                                        finalOutputFile.delete();
                                        result.onError("READ_FAILED", e.getMessage());
                                    }
                                }

                                @Override
                                public void onWriteFailed(CharSequence error) {
                                    try {
                                        descriptor.close();
                                    } catch (IOException ignored) {
                                    }
                                    finalOutputFile.delete();
                                    result.onError("WRITE_FAILED", error == null ? "PDF yazılamadı." : error.toString());
                                }
                            }
                    );
                } catch (IOException e) {
                    outputFile.delete();
                    result.onError("WRITE_START_FAILED", e.getMessage());
                }
            }

            @Override
            public void onLayoutFailed(CharSequence error) {
                result.onError("LAYOUT_FAILED", error == null ? "PDF düzeni oluşturulamadı." : error.toString());
            }
        }, null);
    }

    private static byte[] readBytes(File file) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        FileInputStream input = new FileInputStream(file);
        try {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) {
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        } finally {
            input.close();
            output.close();
        }
    }
}
