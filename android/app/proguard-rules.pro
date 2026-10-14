# google_mlkit_text_recognition references every script recognizer; the app
# only uses Latin (TextRecognizer()), so the others are never loaded.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
