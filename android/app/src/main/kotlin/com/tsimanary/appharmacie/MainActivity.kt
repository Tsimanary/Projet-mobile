package com.tsimanary.appharmacie

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (et non FlutterActivity) : `local_auth` affiche
// l'invite biométrique du système, qui est un fragment AndroidX.
class MainActivity : FlutterFragmentActivity() {

    private companion object {
        const val CANAL_SECURITE = "appharmacie/securite_ecran"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // FLAG_SECURE : captures d'écran noires, pas de miniature dans le
        // sélecteur d'applications, pas d'enregistrement d'écran du contenu.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_SECURITE)
            .setMethodCallHandler { appel, reponse ->
                when (appel.method) {
                    "activer" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        reponse.success(true)
                    }
                    "desactiver" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        reponse.success(true)
                    }
                    else -> reponse.notImplemented()
                }
            }
    }
}
