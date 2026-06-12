package com.danieledituri.esami_tracker

import android.app.Activity
import android.util.Base64
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.ai.edge.aicore.AvailabilityStatus
import com.google.ai.edge.aicore.GenerativeModel
import com.google.ai.edge.aicore.generationConfig
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {

    private companion object {
        const val CANALE = "com.danieledituri.esami_tracker/android_import"
    }

    // Risultato in attesa quando il launcher del Document Scanner è attivo.
    private var pendingResult: MethodChannel.Result? = null

    // Registriamo il launcher come proprietà della classe: deve avvenire
    // prima di onStart() per rispettare il ciclo di vita di ComponentActivity.
    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { activityResult ->
        val result = pendingResult ?: return@registerForActivityResult
        pendingResult = null

        if (activityResult.resultCode != Activity.RESULT_OK) {
            // Annullato dall'utente → null (non è un errore)
            result.success(null)
            return@registerForActivityResult
        }

        val scanning = GmsDocumentScanningResult.fromActivityResultIntent(activityResult.data)
        val pages = scanning?.pages ?: emptyList()
        val base64 = pages.mapNotNull { page ->
            try {
                contentResolver.openInputStream(page.imageUri)?.use { stream ->
                    Base64.encodeToString(stream.readBytes(), Base64.NO_WRAP)
                }
            } catch (e: Exception) {
                null
            }
        }
        result.success(base64)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANALE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAiCoreSupported" -> verificaSupportoAiCore(result)
                    "avviaScanner"      -> avviaDocumentScanner(result)
                    "estraiTesto" -> {
                        val immagini = call.argument<List<String>>("immagini") ?: emptyList()
                        estraiConGeminiNano(immagini, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---- AICore ----------------------------------------------------------------

    private fun verificaSupportoAiCore(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val supportato = try {
                val model = creaModello()
                model.checkAvailability() == AvailabilityStatus.AVAILABLE
            } catch (e: Exception) {
                false
            }
            withContext(Dispatchers.Main) { result.success(supportato) }
        }
    }

    private fun estraiConGeminiNano(base64Images: List<String>, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Passo 1: OCR on-device con ML Kit Text Recognition
                val testoGrezzo = estraiTestoOcr(base64Images)

                // Passo 2: Gemini Nano converte il testo grezzo in JSON strutturato
                val model = creaModello()
                val prompt = buildPromptEstrazione(testoGrezzo)
                val response = model.generateContent(prompt)
                val json = response.text ?: ""

                withContext(Dispatchers.Main) { result.success(json) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("AICORE_ERROR", e.message ?: "Errore Gemini Nano", null)
                }
            }
        }
    }

    private fun creaModello() = GenerativeModel(
        generationConfig = generationConfig {
            context = applicationContext
            temperature = 0f
            topK = 16
            maxOutputTokens = 2048
        }
    )

    private fun buildPromptEstrazione(testoReferto: String): String = buildString {
        appendLine("Sei un sistema di estrazione dati da referti medici.")
        appendLine("Analizza il seguente testo estratto da un referto di esami del sangue e")
        appendLine("restituisci SOLO un oggetto JSON valido con questa struttura:")
        appendLine("""{"data":"YYYY-MM-DD","laboratorio":"nome lab o null","valori":[{"nome":"parametro","valore":numerico,"unita":"unita","range_min":numerico_o_null,"range_max":numerico_o_null}]}""")
        appendLine()
        appendLine("Regole:")
        appendLine("- data: data del prelievo in formato ISO 8601 (YYYY-MM-DD), null se assente")
        appendLine("- valore: usa il punto decimale, non la virgola")
        appendLine("- range_min/range_max: valori numerici dal campo di riferimento, null se assenti")
        appendLine("- Includi TUTTI i parametri presenti nel testo")
        appendLine("- Restituisci SOLO il JSON, senza spiegazioni né markdown")
        appendLine()
        appendLine("Testo referto:")
        append(testoReferto)
    }

    // ---- ML Kit Text Recognition -----------------------------------------------

    private suspend fun estraiTestoOcr(base64Images: List<String>): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val sb = StringBuilder()
        for (b64 in base64Images) {
            try {
                val bytes = Base64.decode(b64, Base64.DEFAULT)
                val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: continue
                val inputImage = InputImage.fromBitmap(bitmap, 0)
                val text = recognizer.process(inputImage).await()
                if (sb.isNotEmpty()) sb.append("\n--- pagina ---\n")
                sb.append(text.text)
            } catch (e: Exception) {
                // Ignora pagine non leggibili
            }
        }
        recognizer.close()
        return sb.toString()
    }

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
