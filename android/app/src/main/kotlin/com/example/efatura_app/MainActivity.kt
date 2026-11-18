package com.example.efatura_app

import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.EfaturaPdfWriter
import android.print.PrintAttributes
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "efatura_app/html_pdf"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "renderHtmlToPdf" -> {
                    val html = call.argument<String>("html").orEmpty()
                    if (html.isBlank()) {
                        result.error("EMPTY_HTML", "PDF oluşturulacak HTML boş.", null)
                        return@setMethodCallHandler
                    }
                    renderHtmlToPdf(html, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun renderHtmlToPdf(html: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error("UNSUPPORTED_ANDROID", "PDF oluşturma için Android 5.0 veya üzeri gerekiyor.", null)
            return
        }

        val configuration = Configuration(resources.configuration)
        configuration.fontScale = 1f
        val webContext = createConfigurationContext(configuration)
        val webView = WebView(webContext)
        var completed = false

        fun finishWithError(code: String, message: String) {
            if (completed) return
            completed = true
            webView.destroy()
            result.error(code, message, null)
        }

        fun finishWithBytes(bytes: ByteArray) {
            if (completed) return
            completed = true
            webView.destroy()
            result.success(bytes)
        }

        fun writePdf() {
            if (completed) return
            val adapter = webView.createPrintDocumentAdapter("fatura")
            val attributes = PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
                .setMinMargins(PrintAttributes.Margins(40, 40, 40, 40))
                .build()

            EfaturaPdfWriter.write(this, adapter, attributes, object : EfaturaPdfWriter.Result {
                override fun onSuccess(bytes: ByteArray) {
                    finishWithBytes(bytes)
                }

                override fun onError(code: String, message: String) {
                    finishWithError(code, message)
                }
            })
        }

        webView.settings.javaScriptEnabled = true
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                mainHandler.postDelayed({ writePdf() }, 500)
            }
        }

        mainHandler.postDelayed({ writePdf() }, 5000)
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
    }
}
