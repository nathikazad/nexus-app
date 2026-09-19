package com.xrz;
import android.content.Context;
import android.graphics.Canvas;
import android.view.View;
import java.util.LinkedList;
import java.util.List;
/** The runtime superclass is vendor android.view.HandwrittenView, a View.
 * Compile-only declarations for the tablet firmware. Never packaged in the APK. */
public class NoteView extends View {
    public NoteView(Context context) { super(context); }
    public FlushInfo onDraw(Canvas[] canvases, LinkedList points) { throw new UnsupportedOperationException(); }
    public int onInputTouch(int action,int x,int y,int pressure,int tool) { throw new UnsupportedOperationException(); }
    public void onInputPoint(PenPoint point) { throw new UnsupportedOperationException(); }
    public List getRecordList() { throw new UnsupportedOperationException(); }
}
