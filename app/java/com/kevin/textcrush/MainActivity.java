package com.kevin.textcrush;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Build;
import android.os.Bundle;
import android.util.AttributeSet;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;

/**
 * Text Crush, as an Android app: one full-screen WebView running the game bundled in this APK.
 *
 * The wrapper deliberately does as little as possible - no permissions, no network, no libraries -
 * and only compensates for what a browser gives the page for free: a secure origin
 * ({@link GameAssets}), DOM storage for the high score, and audio playback without a gesture.
 */
public class MainActivity extends Activity {

    private static final String TAG = "TextCrush";

    /** The page owns the whole screen; a phone-shaped viewport is what the game expects. */
    private static final int BACKGROUND = 0xFF221100;

    private WebView web;

    @Override
    protected void onCreate(Bundle state) {

        super.onCreate(state);

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getWindow().getAttributes().layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }

        web = new SquareWebView(this);
        web.setBackgroundColor(BACKGROUND);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setLongClickable(false);
        web.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View view) {
                return true;
            }
        });

        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        // The game starts an AudioContext while the page loads and plays notes on a tap; without
        // this the context stays suspended on Android and the game is silent.
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setSaveFormData(false);

        // Debug builds only: keeps WebView devtools (chrome://inspect, and the CDP session this
        // app was verified with) out of the published APK.
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            WebView.setWebContentsDebuggingEnabled(true);
            settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
        }

        web.setWebViewClient(new GameAssets(this));
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onConsoleMessage(ConsoleMessage message) {
                Log.i(TAG, "console " + message.messageLevel() + ": " + message.message()
                        + " (" + message.sourceId() + ":" + message.lineNumber() + ")");
                return true;
            }
        });

        // Content first: the window has no decor view until there is content, and asking it for the
        // insets controller before that throws on this platform (the first launch of this app died
        // exactly there). Hiding the bars afterwards costs nothing - the themed window is already
        // laid out full-screen, so the page still measures the whole display.
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BACKGROUND);
        root.addView(web, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_VERTICAL));
        setContentView(root);
        immersive();

        web.loadUrl(GameAssets.ORIGIN + "/web/index.html");
    }

    /**
     * The game is square - board plus its score row - and sizes itself from the smaller of the two
     * viewport dimensions. Handing it a square viewport of the full display width therefore fills
     * that square exactly and centres it, instead of leaving the board pinned to the top of a tall
     * phone with a dead half-screen underneath it.
     */
    private static final class SquareWebView extends WebView {

        SquareWebView(Context context) {
            super(context);
        }

        SquareWebView(Context context, AttributeSet attrs) {
            super(context, attrs);
        }

        @Override
        protected void onMeasure(int widthSpec, int heightSpec) {
            int width = MeasureSpec.getSize(widthSpec);
            super.onMeasure(widthSpec, MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY));
        }
    }

    /** Full screen, bars revealed only by a swipe from the edge, restored when we come back. */
    private void immersive() {

        View decor = getWindow().getDecorView();

        if (decor == null) {
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {

            getWindow().setDecorFitsSystemWindows(false);

            WindowInsetsController controller = decor.getWindowInsetsController();

            if (controller != null) {
                controller.hide(WindowInsets.Type.systemBars());
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }

            return;
        }

        decor.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    @Override
    protected void onResume() {

        super.onResume();
        immersive();

        if (web != null) {
            web.onResume();
        }
    }

    @Override
    protected void onPause() {

        if (web != null) {
            web.onPause();
        }

        super.onPause();
    }
}
