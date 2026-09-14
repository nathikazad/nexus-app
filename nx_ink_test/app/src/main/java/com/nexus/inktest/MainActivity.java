package com.nexus.inktest;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.List;

/** The entire experiment: host the firmware's own drawing widget, untouched.
 * No custom renderer, event forwarding, bitmap copies, scheduling, or saving.
 */
public final class MainActivity extends Activity {
    private View ink;
    private Class<?> inkClass;
    private TextView status;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(Color.WHITE);
        LinearLayout tools = new LinearLayout(this);
        tools.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = new TextView(this);
        title.setText("NX Ink Test"); title.setTextSize(18);
        title.setPadding(16, 8, 12, 8);
        tools.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        Button clear = new Button(this); clear.setText("Clear");
        Button info = new Button(this); info.setText("Info");
        tools.addView(clear); tools.addView(info);
        page.addView(tools);
        status = new TextView(this);
        status.setText("Opening device handwriting…");
        status.setPadding(16, 4, 16, 8);
        page.addView(status);
        setContentView(page);
        try {
            inkClass = Class.forName("com.xrz.NoteView");
            ink = (View) inkClass.getConstructor(Context.class).newInstance(this);
            // Its constructor selects SimplePen and owns input/refresh threads.
            page.addView(ink, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
            Object pen = inkClass.getMethod("getPen").invoke(ink);
            pen.getClass().getMethod("setStrokeWidth", int.class).invoke(pen, 6);
            inkClass.getMethod("setInputEnabled", boolean.class).invoke(ink, true);
            status.setText("Device NoteView · no saving · write below");
            Log.i("NxInkTest", "Firmware widget loaded: " + ink.getClass().getName());
            clear.setOnClickListener(v -> {
                try {
                    inkClass.getMethod("clear", boolean.class).invoke(ink, false);
                } catch (Throwable error) { report(error); }
            });
            info.setOnClickListener(v -> {
                try {
                    Object records = inkClass.getMethod("getRecordList").invoke(ink);
                    String version = String.valueOf(inkClass.getMethod("getVersion").invoke(ink));
                    String message = "NoteView " + version + " · " + ((List<?>) records).size() + " records";
                    status.setText(message); Log.i("NxInkTest", message);
                } catch (Throwable error) { report(error); }
            });
        } catch (Throwable error) {
            clear.setEnabled(false); info.setEnabled(false); report(error);
        }
    }

    private void report(Throwable error) {
        Throwable cause = error.getCause() == null ? error : error.getCause();
        Log.e("NxInkTest", "Native widget failure", cause);
        status.setText("Native widget unavailable: " + cause.getClass().getSimpleName() + ": " + cause.getMessage());
    }

    @Override public void onResume() {
        super.onResume();
        if (ink != null) try { inkClass.getMethod("setInputEnabled", boolean.class).invoke(ink, true); }
        catch (Throwable error) { report(error); }
    }

    @Override public void onPause() {
        if (ink != null) try { inkClass.getMethod("setInputEnabled", boolean.class).invoke(ink, false); }
        catch (Throwable error) { Log.w("NxInkTest", "Pause", error); }
        super.onPause();
    }
}
