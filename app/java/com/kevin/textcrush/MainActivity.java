package com.kevin.textcrush;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.util.AttributeSet;
import android.util.Log;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.json.JSONException;
import org.json.JSONObject;

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

    /** the native header: the game's score line as real text, plus the sound button */
    private TextView scoreView;
    private TextView turnsView;
    private TextView bestView;
    private TextView soundView;

    /** mirrored from the page, so the sound button knows which way to toggle */
    private boolean muted = false;

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

        // The game asks for a tap to be felt through window.TextCrush.tick() and hands its state to
        // window.TextCrush.state(json); a browser has neither. No permission is needed for the
        // feedback, and the interface is only reachable from the bundled page.
        web.addJavascriptInterface(new GameBridge(), "TextCrush");

        // Content first: the window has no decor view until there is content, and asking it for the
        // insets controller before that throws on this platform (the first launch of this app died
        // exactly there). Hiding the bars afterwards costs nothing - the themed window is already
        // laid out full-screen, so the page still measures the whole display.
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BACKGROUND);
        root.addView(buildHeader(), new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP));
        root.addView(web, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER));
        setContentView(root);
        immersive();

        // hud=off: the game keeps no room for a score line of its own, and the board takes the whole
        // square while this header owns the numbers.
        web.loadUrl(GameAssets.ORIGIN + "/web/index.html?hud=off");
    }

    /**
     * Score, turns, best and the sound button as real Android views.
     *
     * The game draws its own score line for the browser, but on a phone that text was the weakest
     * thing on screen: 11 dp tall, rasterised at 1x, and a fill colour that measured 1.45:1 against
     * the board. Native text is crisp at the screen's density, scales with the system font setting,
     * and a screen reader can read it - none of which was true of pixels inside a canvas.
     */
    private View buildHeader() {

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(22), dp(18), dp(14), dp(8));

        scoreView = label("0", 40, 0xFFFFEECC, Typeface.BOLD);
        scoreView.setContentDescription("Score 0");

        turnsView = label("20 turns", 15, 0xFFB9A489, Typeface.NORMAL);
        bestView = label("best 0", 15, 0xFFB9A489, Typeface.NORMAL);

        LinearLayout counters = new LinearLayout(this);
        counters.setOrientation(LinearLayout.VERTICAL);
        counters.setPadding(dp(12), 0, 0, 0);
        counters.addView(turnsView);
        counters.addView(bestView);

        soundView = label("Sound on", 15, 0xFFFFEECC, Typeface.NORMAL);
        soundView.setPadding(dp(16), dp(16), dp(16), dp(16));
        soundView.setClickable(true);
        soundView.setFocusable(true);
        soundView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                web.evaluateJavascript(
                        "window.setTextCrushMuted(" + (!muted) + ")", null);
            }
        });

        // A bare View with WRAP_CONTENT height measures to the whole available height (getDefaultSize
        // returns the AT_MOST size), which would inflate the header to fill the screen and centre its
        // contents vertically. A fixed 1px keeps it a spacer.
        LinearLayout.LayoutParams grow =
                new LinearLayout.LayoutParams(0, 1, 1f);

        header.addView(scoreView);
        header.addView(counters);
        header.addView(new View(this), grow);
        header.addView(soundView);

        return header;
    }

    private TextView label(String text, int size, int colour, int style) {

        TextView view = new TextView(this);

        view.setText(text);
        view.setTextSize(size);
        view.setTextColor(colour);
        view.setTypeface(Typeface.DEFAULT, style);
        view.setIncludeFontPadding(false);

        return view;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    /**
     * The two calls the page makes back into the app: a short tick when a run is cleared, and the
     * state behind the header - score, turns left, best and whether the sound is on.
     *
     * Both have to touch views on the UI thread, so they are posted there rather than run on the
     * JavaScript bridge thread.
     */
    private final class GameBridge {

        @JavascriptInterface
        public void tick() {

            WebView view = web;

            if (view == null) {
                return;
            }

            view.post(new Runnable() {
                @Override
                public void run() {
                    web.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                }
            });
        }

        @JavascriptInterface
        public void state(String json) {

            try {
                final JSONObject payload = new JSONObject(json);

                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        applyState(payload);
                    }
                });

            } catch (JSONException malformed) {
                Log.i(TAG, "state bridge could not read " + json);
            }
        }
    }

    private void applyState(JSONObject state) {

        int score = state.optInt("score", 0);
        int turns = state.optInt("turns", 0);
        int best = state.optInt("best", 0);

        muted = state.optBoolean("muted", muted);

        if (scoreView == null) {
            return;
        }

        scoreView.setText(Format.withCommas(Integer.toString(score)));
        scoreView.setContentDescription("Score " + score);
        turnsView.setText(turns + (turns == 1 ? " turn" : " turns"));
        bestView.setText("best " + best);
        soundView.setText(muted ? "Sound off" : "Sound on");
    }

    /** the header reads its numbers the way the game writes them */
    private static final class Format {

        static String withCommas(String value) {

            String out = "";

            for (int i = value.length() - 1; i >= 0; i--) {
                out = value.charAt(i) + out;

                if (i > 0 && (((value.length() - i) % 3) == 0)) {
                    out = "," + out;
                }
            }

            return out;
        }
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
