# Flutter WebRTC Rules
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-keep class com.fasterxml.jackson.databind.ext.** { *; }
-keep class java.beans.ConstructorProperties { *; }
-keep class java.beans.Transient { *; }
-keep class org.w3c.dom.bootstrap.DOMImplementationRegistry { *; }

# General Flutter Wrapper Rules (Good safety measure)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# -- FIX FOR R8 ERRORS (Deferred Components) --
# The Flutter engine includes code for dynamic features.
# Since we aren't using them, we tell R8 to ignore the missing libraries.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**