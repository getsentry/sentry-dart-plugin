package com.example.project.project

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d("MainActivity", helloSantry())
    }

    external fun helloSantry(): String

    companion object {
        init {
            System.loadLibrary("hello_santry")
        }
    }
}
