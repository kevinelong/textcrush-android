package com.kevin.textcrush;

import android.content.Context;
import android.content.res.AssetManager;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Serves the bundled web build to the WebView, straight out of the APK.
 *
 * The page is loaded from {@link #ORIGIN} and every request under it is answered here, before the
 * network stack is reached. That has three consequences worth the ten lines it costs:
 *
 *  - the page gets a normal secure origin instead of file://, so localStorage - the high score -
 *    is stored per origin and survives restarts. A random loopback port would have moved the origin
 *    on every launch and silently reset the score;
 *  - no ServerSocket, no port to collide with, no cleartext traffic to allow;
 *  - the app declares no permissions at all, and the game runs entirely offline.
 */
class GameAssets extends WebViewClient {

    static final String ORIGIN = "https://appassets.textcrush.local";

    /** Asset directory holding the staged web build: web/index.html plus ../game/classes/*.js. */
    private static final String ROOT = "www";

    private static final Map<String, String> TYPES = new HashMap<String, String>();

    static {
        TYPES.put("html", "text/html");
        TYPES.put("js", "application/javascript");
        TYPES.put("map", "application/json");
        TYPES.put("css", "text/css");
        TYPES.put("json", "application/json");
        TYPES.put("png", "image/png");
        TYPES.put("webp", "image/webp");
        TYPES.put("jpg", "image/jpeg");
        TYPES.put("jpeg", "image/jpeg");
        TYPES.put("svg", "image/svg+xml");
        TYPES.put("wav", "audio/wav");
        TYPES.put("mp3", "audio/mpeg");
    }

    private final AssetManager assets;

    GameAssets(Context context) {
        this.assets = context.getAssets();
    }

    @Override
    public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {

        Uri url = request.getUrl();

        if (url == null || !ORIGIN.equals(url.getScheme() + "://" + url.getHost())) {
            return null;
        }

        return respond(url.getPath());
    }

    private WebResourceResponse respond(String path) {

        String asset = ROOT + ((path == null || path.isEmpty() || "/".equals(path))
                ? "/web/index.html"
                : path);

        if (asset.contains("..")) {
            return notFound(asset);
        }

        try {
            InputStream body = assets.open(asset);
            return new WebResourceResponse(type(asset), null, 200, "OK", headers(), body);
        } catch (IOException missing) {
            return notFound(asset);
        }
    }

    private WebResourceResponse notFound(String asset) {

        byte[] body = ("not bundled: " + asset).getBytes();

        return new WebResourceResponse(
                "text/plain",
                "utf-8",
                404,
                "Not Found",
                headers(),
                new ByteArrayInputStream(body)
        );
    }

    /** The page is a local file that changes with the APK, so nothing under ORIGIN may be cached. */
    private static Map<String, String> headers() {

        Map<String, String> headers = new HashMap<String, String>();
        headers.put("Cache-Control", "no-store");

        return headers;
    }

    private static String type(String asset) {

        int dot = asset.lastIndexOf('.');
        String extension = dot < 0 ? "" : asset.substring(dot + 1).toLowerCase();
        String type = TYPES.get(extension);

        if (type != null) {
            return type;
        }

        String guessed = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);

        return guessed == null ? "application/octet-stream" : guessed;
    }
}
