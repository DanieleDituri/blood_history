package com.danieledituri.esami_tracker

import android.app.Activity
import android.util.Base64
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.regex.Pattern

class MainActivity : FlutterFragmentActivity() {

    private companion object {
        const val CANALE_IMPORT = "com.danieledituri.esami_tracker/android_import"
        const val CANALE_DOWNLOAD = "com.danieledituri.esami_tracker/download_modello"
        const val NOME_FILE_MODELLO = "gemma-2b-it-cpu-int4.bin"

        val PAROLE_DA_IGNORARE = setOf(
            "esame", "parametro", "valore", "risultato", "unità", "unita",
            "riferimento", "note", "data", "firma", "medico", "paziente",
            "cognome", "nome", "sesso", "età", "nato", "referto", "laboratorio",
            "codice", "accettazione", "richiesta", "campione", "metodo",
        )
    }

    private var pendingResult: MethodChannel.Result? = null
    private var downloadEventSink: EventChannel.EventSink? = null
    private var llmInference: LlmInference? = null

    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { activityResult ->
        val result = pendingResult ?: return@registerForActivityResult
        pendingResult = null

        if (activityResult.resultCode != Activity.RESULT_OK) {
            result.success(null)
            return@registerForActivityResult
        }

        val scanning = GmsDocumentScanningResult.fromActivityResultIntent(activityResult.data)
        val base64 = (scanning?.pages ?: emptyList()).mapNotNull { page ->
            try {
                contentResolver.openInputStream(page.imageUri)?.use { stream ->
                    Base64.encodeToString(stream.readBytes(), Base64.NO_WRAP)
                }
            } catch (_: Exception) { null }
        }
        result.success(base64)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel per il progresso del download
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CANALE_DOWNLOAD)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    downloadEventSink = sink
                }
                override fun onCancel(args: Any?) {
                    downloadEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANALE_IMPORT)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isLlmDisponibile"  -> result.success(isLlmDisponibile())
                    "scaricaModello"    -> {
                        val token = call.argument<String>("token") ?: ""
                        val url   = call.argument<String>("url")   ?: ""
                        scaricaModello(url, token, result)
                    }
                    "cancellaModello"   -> { cancellaModello(); result.success(null) }
                    "avviaScanner"      -> avviaDocumentScanner(result)
                    "estraiConOcr"      -> {
                        val imgs = call.argument<List<String>>("immagini") ?: emptyList()
                        estraiConOcr(imgs, result)
                    }
                    "estraiConLlm"      -> {
                        val imgs = call.argument<List<String>>("immagini") ?: emptyList()
                        estraiConLlm(imgs, result)
                    }
                    "estraiTestoConLlm" -> {
                        val testo = call.argument<String>("testo") ?: ""
                        estraiTestoConLlm(testo, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        llmInference?.close()
        llmInference = null
    }

    // ---- LLM: disponibilità / cancellazione ------------------------------------

    private fun percorsoModello() = File(filesDir, NOME_FILE_MODELLO)

    private fun isLlmDisponibile(): Boolean =
        percorsoModello().exists() && percorsoModello().length() > 100_000_000L

    private fun cancellaModello() {
        percorsoModello().delete()
        llmInference?.close()
        llmInference = null
    }

    // ---- Download modello ------------------------------------------------------

    private fun scaricaModello(url: String, token: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val dest = percorsoModello()
            val tmp  = File(filesDir, "$NOME_FILE_MODELLO.tmp")
            try {
                val client = OkHttpClient()
                val req = Request.Builder().url(url).apply {
                    if (token.isNotBlank()) header("Authorization", "Bearer $token")
                }.build()

                client.newCall(req).execute().use { resp ->
                    if (!resp.isSuccessful) {
                        withContext(Dispatchers.Main) {
                            result.error("DOWNLOAD_ERROR", "HTTP ${resp.code}", null)
                        }
                        return@launch
                    }
                    val body = resp.body ?: run {
                        withContext(Dispatchers.Main) {
                            result.error("DOWNLOAD_ERROR", "Risposta vuota", null)
                        }
                        return@launch
                    }
                    val totale = body.contentLength()
                    var scaricato = 0L
                    var ultimoPercento = -1

                    tmp.outputStream().use { out ->
                        body.byteStream().use { input ->
                            val buf = ByteArray(8192)
                            var n: Int
                            while (input.read(buf).also { n = it } != -1) {
                                out.write(buf, 0, n)
                                scaricato += n
                                val pct = if (totale > 0) (scaricato * 100 / totale).toInt() else 0
                                if (pct != ultimoPercento) {
                                    ultimoPercento = pct
                                    val payload = mapOf(
                                        "percentuale" to pct,
                                        "scaricato"   to scaricato,
                                        "totale"      to totale,
                                    )
                                    withContext(Dispatchers.Main) {
                                        downloadEventSink?.success(payload)
                                    }
                                }
                            }
                        }
                    }
                }

                tmp.renameTo(dest)
                withContext(Dispatchers.Main) {
                    downloadEventSink?.success(
                        mapOf("percentuale" to 100, "scaricato" to dest.length(), "totale" to dest.length())
                    )
                    result.success(true)
                }
            } catch (e: Exception) {
                tmp.delete()
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_ERROR", e.message ?: "Errore download", null)
                }
            }
        }
    }

    // ---- Estrazione con LLM (MediaPipe Gemma 2B) --------------------------------

    private fun estraiConLlm(base64Images: List<String>, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val testoOcr = estraiTestoOcr(base64Images)
                val llm = ottieniLlm()
                val prompt = buildPrompt(testoOcr)
                val json = llm.generateResponse(prompt)
                withContext(Dispatchers.Main) { result.success(json) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("LLM_ERROR", e.message ?: "Errore LLM", null)
                }
            }
        }
    }

    /** Inizializza (o riusa) il modello LLM. Thread-safe: chiamato da IO. */
    @Synchronized
    private fun ottieniLlm(): LlmInference {
        llmInference?.let { return it }
        val opts = LlmInference.LlmInferenceOptions.builder()
            .setModelPath(percorsoModello().absolutePath)
            .setMaxTokens(2048)
            .setTemperature(0f)
            .setTopK(1)
            .build()
        return LlmInference.createFromOptions(this, opts).also { llmInference = it }
    }

    private fun buildPrompt(testoReferto: String): String = buildString {
        append("Sei un sistema di estrazione dati da referti medici.\n")
        append("Analizza il seguente testo estratto da un referto di esami del sangue e\n")
        append("restituisci SOLO un oggetto JSON valido con questa struttura:\n")
        append("""{"data":"YYYY-MM-DD","valori":[{"nome":"parametro","valore":numero,""")
        append(""""unita":"unita","range_min":numero_o_null,"range_max":numero_o_null}]}""")
        append("\n\nRegole:\n")
        append("- data: data del prelievo ISO 8601, null se assente\n")
        append("- valore: usa il punto decimale, non la virgola\n")
        append("- Includi TUTTI i parametri presenti\n")
        append("- Restituisci SOLO il JSON, senza markdown\n\n")
        append("Testo referto:\n")
        append(testoReferto)
    }

    /** Invia testo grezzo estratto da PDF a Gemma 2B (senza OCR). */
    private fun estraiTestoConLlm(testo: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val llm = ottieniLlm()
                val prompt = buildPrompt(testo)
                val json = llm.generateResponse(prompt)
                withContext(Dispatchers.Main) { result.success(json) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("LLM_ERROR", e.message ?: "Errore LLM", null)
                }
            }
        }
    }

    // ---- Estrazione con OCR + regex (fallback senza LLM) -----------------------

    private fun estraiConOcr(base64Images: List<String>, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val testo = estraiTestoOcr(base64Images)
                val json  = struttura(testo)
                withContext(Dispatchers.Main) { result.success(json) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OCR_ERROR", e.message ?: "Errore OCR", null)
                }
            }
        }
    }

    private suspend fun estraiTestoOcr(base64Images: List<String>): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val sb = StringBuilder()
        for (b64 in base64Images) {
            try {
                val bytes = Base64.decode(b64, Base64.DEFAULT)
                val bmp = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: continue
                val text = recognizer.process(InputImage.fromBitmap(bmp, 0)).await()
                if (sb.isNotEmpty()) sb.append("\n")
                sb.append(text.text)
            } catch (_: Exception) {}
        }
        recognizer.close()
        return sb.toString()
    }

    private fun struttura(testo: String): String {
        val dataIso = estraiData(testo)
        val valori  = JSONArray()
        val pValore = Pattern.compile(
            """^([A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ0-9\s\(\)/\-\.]{1,50?}?)\s+""" +
            """(\d{1,5}[.,]?\d{0,3})\s*""" +
            """([A-Za-zµ%/\^0-9]{1,12})?\s*""" +
            """(?:[<>≤≥]?\s*(\d+[.,]?\d*)\s*[-–]\s*(\d+[.,]?\d*))?""",
            Pattern.MULTILINE,
        )
        for (riga in testo.lines()) {
            val r = riga.trim()
            if (r.length < 4) continue
            val prima = r.split(Regex("\\s+")).firstOrNull()?.lowercase() ?: continue
            if (PAROLE_DA_IGNORARE.any { prima.startsWith(it) }) continue
            val m = pValore.matcher(r)
            if (!m.find()) continue
            val nome    = m.group(1)?.trim() ?: continue
            if (nome.split(Regex("\\s+")).size > 6) continue
            val valore  = m.group(2)?.replace(',', '.') ?: continue
            val valNum  = valore.toDoubleOrNull() ?: continue
            if (valNum < 0.001 || valNum > 50_000) continue
            val unita    = m.group(3)?.takeIf { it.isNotBlank() } ?: ""
            val rangeMin = m.group(4)?.replace(',', '.')?.toDoubleOrNull()
            val rangeMax = m.group(5)?.replace(',', '.')?.toDoubleOrNull()
            val obj = JSONObject()
            obj.put("nome", normalizzaNome(nome))
            obj.put("valore", valNum)
            obj.put("unita", unita)
            obj.put("range_min", rangeMin ?: JSONObject.NULL)
            obj.put("range_max", rangeMax ?: JSONObject.NULL)
            valori.put(obj)
        }
        val root = JSONObject()
        if (dataIso != null) root.put("data", dataIso)
        root.put("valori", valori)
        return root.toString()
    }

    private fun estraiData(testo: String): String? {
        val m = Pattern.compile("""(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})""").matcher(testo)
        return if (m.find()) {
            "${m.group(3)}-${m.group(2)!!.padStart(2,'0')}-${m.group(1)!!.padStart(2,'0')}"
        } else null
    }

    private fun normalizzaNome(raw: String): String =
        raw.replace(Regex("""\s{2,}"""), " ")
           .trim()
           .replaceFirstChar { it.uppercase() }

    // ---- ML Kit Document Scanner -----------------------------------------------

    private fun avviaDocumentScanner(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("SCANNER_BUSY", "Scanner già in uso", null)
            return
        }
        pendingResult = result
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(10)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options)
            .getStartScanIntent(this)
            .addOnSuccessListener { sender ->
                scannerLauncher.launch(IntentSenderRequest.Builder(sender).build())
            }
            .addOnFailureListener { e ->
                pendingResult = null
                result.error("SCANNER_ERROR", e.message ?: "Avvio scanner fallito", null)
            }
    }
}
