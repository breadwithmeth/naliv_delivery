package kz.gradusy24.app

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.window.SplashScreenView
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var launchChannel: MethodChannel? = null
  private var windowWaiter: MethodChannel.Result? = null
  private var flutterUiDisplayed = false
  private var entranceReady = false
  private var fallbackScheduled = false
  private var waitingForDraw = false

  private val entranceFallback = Runnable {
    // An already-visible window may not get an enter-complete callback on relaunch.
    entranceReady = true
    awaitVisibleDraw()
  }
  private val afterDraw = Runnable(::onVisibleWindowDrawn)
  private val visibleDrawListener = ViewTreeObserver.OnDrawListener {
    val decor = window.decorView
    if (!hasSplashOverlay(decor)) decor.postOnAnimation(afterDraw)
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      splashScreen.setOnExitAnimationListener { splash ->
        splash.remove()
        awaitVisibleDraw()
      }
    }
  }

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    launchChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger, "kz.gradusy24.app/launch"
    ).also { channel ->
      channel.setMethodCallHandler { call, result ->
        when {
          call.method != "waitForVisibleWindow" -> result.notImplemented()
          windowWaiter != null -> result.error("launch_wait_pending", null, null)
          else -> {
            windowWaiter = result
            fallbackScheduled = false
            awaitVisibleDraw()
          }
        }
      }
    }
  }

  override fun onFlutterUiDisplayed() {
    super.onFlutterUiDisplayed()
    flutterUiDisplayed = true
    awaitVisibleDraw()
  }

  override fun onFlutterUiNoLongerDisplayed() {
    super.onFlutterUiNoLongerDisplayed()
    flutterUiDisplayed = false
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (hasFocus) awaitVisibleDraw()
  }

  override fun onEnterAnimationComplete() {
    super.onEnterAnimationComplete()
    entranceReady = true
    window.peekDecorView()?.removeCallbacks(entranceFallback)
    awaitVisibleDraw()
  }

  private fun awaitVisibleDraw() {
    if (windowWaiter == null) return
    val decor = window.decorView
    if (!canSeeFlutter(decor)) return
    if (!entranceReady) {
      if (!fallbackScheduled) {
        fallbackScheduled = true
        decor.postDelayed(entranceFallback, 3_000L)
      }
      return
    }
    if (waitingForDraw || hasSplashOverlay(decor)) return

    // Flutter can raster before the Android window draws. Wait for a window draw after
    // the entrance/exit signals; window focus alone can precede splash removal.
    waitingForDraw = true
    decor.viewTreeObserver.addOnDrawListener(visibleDrawListener)
    decor.invalidate()
  }

  private fun onVisibleWindowDrawn() {
    val decor = window.decorView
    stopWaitingForDraw(decor)
    val result = windowWaiter ?: return
    if (!canSeeFlutter(decor) || hasSplashOverlay(decor)) return

    windowWaiter = null
    result.success(null)
  }

  private fun canSeeFlutter(decor: View): Boolean =
    flutterUiDisplayed && decor.hasWindowFocus() && decor.windowVisibility == View.VISIBLE

  private fun hasSplashOverlay(decor: View): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || decor !is ViewGroup) return false
    // The platform attaches the transferred splash to the decor before the exit callback.
    for (index in 0 until decor.childCount) {
      if (decor.getChildAt(index) is SplashScreenView) return true
    }
    return false
  }

  private fun stopWaitingForDraw(decor: View) {
    if (!waitingForDraw) return
    val observer = decor.viewTreeObserver
    if (observer.isAlive) observer.removeOnDrawListener(visibleDrawListener)
    decor.removeCallbacks(afterDraw)
    waitingForDraw = false
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    launchChannel?.setMethodCallHandler(null)
    launchChannel = null
    window.peekDecorView()?.let { decor ->
      decor.removeCallbacks(entranceFallback)
      stopWaitingForDraw(decor)
    }
    windowWaiter?.error("launch_window_detached", null, null)
    windowWaiter = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onDestroy() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      splashScreen.clearOnExitAnimationListener()
    }
    super.onDestroy()
  }
}
